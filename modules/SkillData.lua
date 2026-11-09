local _, NS = ...
-- modules/SkillData.lua — the skills model: scans the skill list through NS.Compat, classifies each
-- line by the catalog's localized-name map, synthesizes the unlearned weapon and riding rows the
-- class can train, and publishes SKILLS_UPDATED (every pass) and SKILL_UP (a rank that rose).
--
-- model = { byKey = { [key] = entry }, order = { primary = { keys }, secondary, weapon, other } }
-- entry = { key, name, category, kind, rank, max, tempPoints, modifier, learned }
-- A line the catalog does not know lands in "other" under the key "other:<name>" (Review Focus 5);
-- a line under an excluded header (armor, languages, class spell lines) is left out (design §3).
--
-- Read-only apart from one restored change: a collapsed header hides its lines, so the scan opens
-- it, reads, and closes it again (Review Focus 2).

NS.SkillData = {}
local SD = NS.SkillData
local L = NS.L
local Compat = NS.Compat

SD.CATEGORIES = { "primary", "secondary", "weapon", "other" }
SD.EVENTS = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_LEVEL_UP" }
SD.DEBOUNCE = 0.1      -- seconds: one scan per burst of events (data-flow)
SD.ECHO_WINDOW = 0.2   -- seconds: SKILL_LINES_CHANGED the scan's own header toggles cause is ignored
SD.UNKNOWN_PREFIX = "other:"

-- ---------------------------------------------------------------------------------------------
-- The localized-name maps, built once from the catalog through NS.L
-- ---------------------------------------------------------------------------------------------

local function buildNameMap()
    local map = {}
    for key, e in pairs(NS.SkillCatalog) do
        map[L[e.name]] = key
        for _, alias in ipairs(e.aliases or {}) do map[L[alias]] = key end
    end
    return map
end
NS.SkillNameToKey = buildNameMap()

local EXCLUDED = {}
for _, header in ipairs(NS.SkillExcludedHeaders) do EXCLUDED[L[header]] = true end

-- ---------------------------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------------------------

local function emptyModel()
    local order = {}
    for _, c in ipairs(SD.CATEGORIES) do order[c] = {} end
    return { byKey = {}, order = order }
end

local model = emptyModel()
local pending, levelHint, echoUntil, toggling

--- Back to the before-the-first-scan state: an empty model, nothing pending.
function SD:Reset()
    model = emptyModel()
    pending, levelHint, echoUntil, toggling = nil, nil, nil, false
end

function SD:Model() return model end
function SD:Get(key) return model.byKey[key] end

-- ---------------------------------------------------------------------------------------------
-- Reading the list
-- ---------------------------------------------------------------------------------------------

local function setExpanded(i, open)
    toggling = true
    local ran = Compat.SetSkillHeaderExpanded(i, open)
    toggling = false
    return ran
end

--- Open every collapsed header; answers the names opened.
local function expandCollapsed()
    local opened, any, i = {}, false, 1
    while i <= Compat.NumSkillLines() do
        local r = Compat.SkillLineInfo(i)
        if r and r.isHeader and not r.isExpanded and setExpanded(i, true) then
            opened[r.name], any = true, true
        end
        i = i + 1
    end
    return opened, any
end

--- Close again what expandCollapsed opened, bottom up so earlier indices do not move.
local function collapseAgain(opened)
    for i = Compat.NumSkillLines(), 1, -1 do
        local r = Compat.SkillLineInfo(i)
        if r and r.isHeader and opened[r.name] then setExpanded(i, false) end
    end
end

--- Every non-header line with the header it sits under.
local function readLines()
    local opened, any = expandCollapsed()
    local lines, header = {}, nil
    for i = 1, Compat.NumSkillLines() do
        local r = Compat.SkillLineInfo(i)
        if r and r.isHeader then
            header = r.name
        elseif r and r.name then
            lines[#lines + 1] = { rec = r, header = header }
        end
    end
    if any then
        collapseAgain(opened)
        echoUntil = GetTime() + SD.ECHO_WINDOW
    end
    return lines
end

-- ---------------------------------------------------------------------------------------------
-- Building the model
-- ---------------------------------------------------------------------------------------------

--- key and catalog entry for a line; nil when the line is left out.
local function classify(name, header)
    local key = NS.SkillNameToKey[name]
    if key then return key, NS.SkillCatalog[key] end
    if header and EXCLUDED[header] then return nil end
    return SD.UNKNOWN_PREFIX .. name, nil
end

--- The weapon cap is 5 x level; after PLAYER_LEVEL_UP the list can still answer the old one, so the
--- level is the larger of the client's and the event's (ctx.level).
local function capFloor(cat, ctx)
    if not (cat and (cat.kind == "weapon" or cat.kind == "defense")) then return 0 end
    return 5 * (ctx.level or 0)
end

local function learnedEntry(key, cat, r, ctx)
    return {
        key = key, name = r.name, category = cat and cat.category or "other", kind = cat and cat.kind,
        rank = r.rank, max = math.max(r.max, capFloor(cat, ctx)), tempPoints = r.tempPoints,
        modifier = r.modifier, learned = true,
    }
end

local function unlearnedEntry(key, cat)
    return { key = key, name = L[cat.name], category = cat.category, kind = cat.kind,
             rank = 0, max = 0, tempPoints = 0, modifier = 0, learned = false }
end

--- One row per key: two lines on one key (a second racial riding line) keep the higher rank.
local function addLearned(m, lines, ctx)
    for _, line in ipairs(lines) do
        local key, cat = classify(line.rec.name, line.header)
        local had = key and m.byKey[key]
        if key and not had then
            local e = learnedEntry(key, cat, line.rec, ctx)
            m.byKey[key] = e
            local list = m.order[e.category]
            list[#list + 1] = key
        elseif had and line.rec.rank > had.rank then
            m.byKey[key] = learnedEntry(key, cat, line.rec, ctx)
        end
    end
end

--- The rows the class can train and the character has not learned, in catalog order.
local function addUnlearned(m, ctx)
    local classFile = ctx.classFile
    local keys = classFile and NS.ClassWeapons_Forever[classFile]
    if not keys then return end
    local missing = {}
    for _, key in ipairs(keys) do
        local cat = NS.SkillCatalog[key]
        if cat and not m.byKey[key] then missing[#missing + 1] = key end
    end
    table.sort(missing, function(a, b) return NS.SkillCatalog[a].order < NS.SkillCatalog[b].order end)
    for _, key in ipairs(missing) do
        local e = unlearnedEntry(key, NS.SkillCatalog[key])
        m.byKey[key] = e
        local list = m.order[e.category]
        list[#list + 1] = key
    end
end

--- Every learned rank that rose since the previous model, in display order.
local function skillUps(old, new)
    local ups = {}
    for _, c in ipairs(SD.CATEGORIES) do
        for _, key in ipairs(new.order[c]) do
            local was, now = old.byKey[key], new.byKey[key]
            if was and was.learned and now.learned and now.rank > was.rank then
                ups[#ups + 1] = { key, was.rank, now.rank }
            end
        end
    end
    return ups
end

--- Read the list, build the model, publish it. An empty (not yet loaded) list is an empty model:
--- nothing is synthesized from it (Review Focus 1).
--- @return table the model
--- The model for `lines` ({ rec, header } in list order) of a `ctx.classFile` character at
--- `ctx.level`. Pure: Scan feeds it the client's list, test mode its sample character's.
function SD.Build(lines, ctx)
    local m = emptyModel()
    if #lines > 0 then
        addLearned(m, lines, ctx)
        addUnlearned(m, ctx)
    end
    return m
end

--- The class and level the live scan builds with, read through NS.Compat (the simulator's seam).
local function liveContext()
    local _, classFile = Compat.PlayerClass()
    return { classFile = classFile, level = math.max(Compat.PlayerLevel(), levelHint or 0) }
end

function SD:Scan()
    local lines = readLines()
    local m = SD.Build(lines, liveContext())
    local old = model
    model = m
    for _, up in ipairs(skillUps(old, m)) do NS.bus:SendMessage(NS.MSG.SKILL_UP, up[1], up[2], up[3]) end
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, m)
    NS.Debug("Skills", "%d lines, %d rows", #lines, #m.order.primary + #m.order.secondary
        + #m.order.weapon + #m.order.other)
    return m
end

-- ---------------------------------------------------------------------------------------------
-- Events: debounced into one scan
-- ---------------------------------------------------------------------------------------------

--- Schedule one scan SD.DEBOUNCE from now, unless one is already waiting.
function SD:RequestScan()
    if pending then return end
    pending = NS.addon:ScheduleTimer(function()
        pending = nil
        SD:Scan()
    end, SD.DEBOUNCE)
end

local function onSkillLines()
    if toggling or (echoUntil and GetTime() < echoUntil) then return end
    SD:RequestScan()
end

local HANDLERS = {
    SKILL_LINES_CHANGED = onSkillLines,
    CHAT_MSG_SKILL = function() SD:RequestScan() end,
    PLAYER_LEVEL_UP = function(_, level)
        levelHint = tonumber(level) or levelHint
        SD:RequestScan()
    end,
}

--- Deliver one game event to the handler its registration names (the simulator's `deliver`).
--- Answers how many handlers ran.
function SD.OnEvent(event, ...)
    local fn = HANDLERS[event]
    if not fn then return 0 end
    fn(event, ...)
    return 1
end

--- Put `m` in place as the model with no message (the simulator: a session starts from an empty
--- model so its first pass sends no SKILL_UP, and the stop puts the live one back). Answers the
--- model it replaced.
function SD:Adopt(m)
    local was = model
    model = type(m) == "table" and m or emptyModel()
    return was
end

function SD:RegisterEvents()
    for _, event in ipairs(SD.EVENTS) do
        NS.SafeRegisterEvent(NS.addon, event, HANDLERS[event], NS.rejectedEvents)
    end
end

function SD:UnregisterEvents()
    for _, event in ipairs(SD.EVENTS) do NS.addon:UnregisterEvent(event) end
end

--- Stand-up (NS.RegisterRuntime): register, and rescan from current state. A stand-down canceled
--- every timer (NS.StandDown), so a handle left from before it is dropped first.
function SD:Enable()
    pending = nil
    SD:RegisterEvents()
    SD:RequestScan()
end
