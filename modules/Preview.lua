local _, NS = ...
-- modules/Preview.lua — test mode's data swap (preview-mode, plan Task 5.2): while test mode is on,
-- every surface draws the sample character of defaults/Preview_Forever.lua instead of the live one,
-- through the same render path. The models are built by the live pipelines (NS.SkillData.Build,
-- NS.StatData.Build, NS.Bonuses.Compute) from the fixture, so the preview exercises the real
-- classification, references, markers and bonus attribution.
--
-- The swap: NS.Blocks.source (the window and the detached frames), NS.Bonuses.source (the bars'
-- bonus segments, the row tooltip's Bonuses), NS.Broker.source (the four feeds and their tooltips),
-- and the readers below, which the Journal, the row tooltip, the summary strip and the broker ask
-- at call time: P.Log() (the session log), P.Alts() (the alt grid), P.Skill(key) and
-- P.Character() (the "Lv 22 · Dwarf Hunter" line and every level read a display makes). Apply(false)
-- clears every source, so each surface reads the live data again on its next render. The live
-- data modules keep running underneath; nothing of the live state is written while the preview
-- shows.

NS.Preview = {}
local P = NS.Preview
local L = NS.L

local data   -- the built sample, or nil while test mode is off

function P.IsOn() return data ~= nil end

local function fixture() return NS.Preview_Forever end

-- ── the sample models ────────────────────────────────────────────────────────────────────────

--- The fixture's Skills tab as the client's records (NS.Compat.SkillLineInfo's shape), in order.
--- The simulator answers its seam from a copy of these.
function P.SkillLines()
    local out = {}
    for _, l in ipairs(fixture().lines) do
        if l.header then
            out[#out + 1] = { name = L[l.header], isHeader = true, isExpanded = true, rank = 0,
                              tempPoints = 0, modifier = 0, max = 0 }
        else
            out[#out + 1] = { name = L[l[1]], isHeader = false, isExpanded = false, rank = l[2],
                              tempPoints = 0, modifier = l.modifier or 0, max = l[3] }
        end
    end
    return out
end

--- Records -> the { rec, header } lines SkillData.Build reads.
function P.ToLines(records)
    local lines, header = {}, nil
    for _, r in ipairs(records) do
        if r.isHeader then header = r.name else lines[#lines + 1] = { rec = r, header = header } end
    end
    return lines
end

local function buildSkills(c)
    return NS.SkillData.Build(P.ToLines(P.SkillLines()), { classFile = c.classFile, level = c.level })
end

--- The fixture's temporary bonuses as the breakdown's candidates, their timers from `now`.
local function buildCandidates(now)
    local out = {}
    for _, t in ipairs(fixture().temp or {}) do
        out[#out + 1] = { name = NS.Bonuses.Norm(L[t.skill]), amount = t.amount, label = L[t.label],
                          kind = "temp", source = t.source or "buff", expires = now + (t.seconds or 0) }
    end
    return out
end

local function keyOf(name) return NS.SkillNameToKey[L[name]] end

local function buildLog(skills, now)
    local fx, entries = fixture(), {}
    for i = #fx.log, 1, -1 do
        local e = fx.log[i]
        entries[#entries + 1] = { t = now - e.ago, key = keyOf(e.skill), old = e.old, new = e.new, zone = L[e.zone] }
    end
    return NS.SessionLog.View(entries, now - (fx.sessionAgo or 0), function(key) return skills.byKey[key] end)
end

local function catalogSkill(key, rank, max)
    local cat = NS.SkillCatalog[key]
    return { name = cat and L[cat.name] or key, category = cat and cat.category or "other", rank = rank, max = max }
end

local function ownRecord(c, skills, now)
    local mine = {}
    for key, e in pairs(skills.byKey) do
        if e.learned then mine[key] = { name = e.name, category = e.category, rank = e.rank, max = e.max } end
    end
    return { name = c.name, class = c.classFile, className = L[c.class], race = L[c.race], level = c.level,
             faction = c.faction, updated = now, skills = mine }
end

local function buildAlts(c, skills, now)
    local list = { { key = c.realm .. "-" .. c.name, record = ownRecord(c, skills, now), isCurrent = true } }
    local others = {}
    for _, a in ipairs(fixture().alts or {}) do
        local s = {}
        for key, v in pairs(a.skills) do s[key] = catalogSkill(key, v[1], v[2]) end
        others[#others + 1] = { key = c.realm .. "-" .. a.name, isCurrent = false,
            record = { name = a.name, class = a.class, className = L[a.className], race = L[a.race],
                       level = a.level, faction = a.faction, updated = now - (a.updatedAgo or 0), skills = s } }
    end
    table.sort(others, function(x, y) return x.record.name < y.record.name end)
    for _, o in ipairs(others) do list[#list + 1] = o end
    return NS.Alts.View(list)
end

local function buildBroker(d)
    local total, byKey = d.log:Gains()
    local last = fixture().last
    local fx = fixture()
    return { model = d.skills, statsModel = d.stats, statIndex = d.statIndex,
             gains = { total = total, byKey = byKey },
             last = last and { key = keyOf(last.skill), new = last.new } or nil,
             -- {pinned} and {equippedWeapon}: the sample's, never this character's store or gear
             pinned = fx.pinned and keyOf(fx.pinned) or nil,
             mainHand = fx.mainHand and keyOf(fx.mainHand) or nil }
end

--- Build the whole sample once, its timers counted from now.
function P.Build()
    local c = fixture().character
    local now, clock = time(), GetTime()
    local d = { character = c }
    d.skills = buildSkills(c)
    d.stats, d.statIndex = NS.StatData.Build(fixture().stats, c.level)
    d.candidates = buildCandidates(clock)
    d.log = buildLog(d.skills, now)
    d.alts = buildAlts(c, d.skills, now)
    d.broker = buildBroker(d)
    return d
end

-- ── the readers every display asks ───────────────────────────────────────────────────────────

--- The sample's breakdown for `key` (NS.Bonuses.source while test mode is on).
function P.Breakdown(key)
    local c = data and data.character or fixture().character
    local skills = data and data.skills or buildSkills(c)
    return NS.Bonuses.Compute(skills.byKey[key], data and data.candidates or {}, L[c.race], c.raceFile)
end

--- The session log the displays read: the sample's while test mode is on, else the live one.
function P.Log() return data and data.log or NS.SessionLog end

--- The alt list the Journal reads: the sample's while test mode is on, else the live one.
function P.Alts() return data and data.alts or NS.Alts end

--- One skill's model entry, from whichever model the displays draw.
function P.Skill(key)
    if data then return data.skills.byKey[key] end
    return NS.SkillData and NS.SkillData:Get(key) or nil
end

--- { level, race, class, name, classFile } of the character the displays draw. Live reads go
--- through NS.Compat, so a running simulation answers them too.
function P.Character()
    if data then
        local c = data.character
        return { level = c.level, race = L[c.race], class = L[c.class], name = c.name, classFile = c.classFile }
    end
    local race = NS.Compat.PlayerRace()
    local class, classFile = NS.Compat.PlayerClass()
    return { level = NS.Compat.PlayerLevel(), race = race or "", class = class or "",
             name = NS.Compat.PlayerName() or "", classFile = classFile }
end

-- ── the switch ───────────────────────────────────────────────────────────────────────────────

local function blocksSource() return data.skills, data.stats end
local function brokerSource() return data.broker end

local function repaint()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if NS.MainWindow then NS.MainWindow.Refresh(true) end
    if NS.Detached then NS.Detached.Refresh() end
    if NS.Broker then NS.Broker.Refresh() end
    if NS.Journal then NS.Journal.Refresh() end
end

--- Turn the sample on (built afresh) or off (every source cleared), then repaint every surface.
--- NS.ToggleTestMode, combat and the stand-down call this; nothing else does.
function P.Apply(on)
    if on then
        data = P.Build()
        NS.Blocks.source, NS.Bonuses.source, NS.Broker.source = blocksSource, P.Breakdown, brokerSource
    else
        if data == nil then return end
        data = nil
        NS.Blocks.source, NS.Bonuses.source, NS.Broker.source = nil, nil, nil
    end
    NS.Debug("Test", "preview data %s", on and "on" or "off")
    repaint()
end
