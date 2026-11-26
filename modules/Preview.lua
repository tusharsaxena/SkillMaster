local _, NS = ...
-- modules/Preview.lua — test mode's data swap (preview-mode, plan Task 5.2): while test mode is on,
-- every surface draws the sample character of defaults/Preview_Forever.lua instead of the live one,
-- through the same render path. The models are built by the live pipelines (NS.SkillData.Build,
-- NS.StatData.Build, NS.Bonuses.Compute) from the fixture, so the preview exercises the real
-- classification, references, markers and bonus attribution.
--
-- The tree families (SMW-11): the sample's reputations, currencies and Statistics tab are the client's own
-- records built from the fixture (P.FactionRows, P.CurrencyRows, P.StatisticsList; the simulator's world
-- reads the same) and modeled by the live builders (RepData.Build, CurrencyData.Build, StatisticsData.Build).
--
-- The swap: NS.Blocks.source (the window and the detached frames), NS.Bonuses.source (the bars'
-- bonus segments, the row tooltip's Bonuses), NS.Broker.source (the feed and its tooltip),
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

-- ── the sample people (LibKa0s#87) ───────────────────────────────────────────────────────────

local SimLib = LibStub and LibStub("LibKa0s-Sim-1.0", true)

--- The collection's Forever sample people: Sim.Sample("forever"), the one source of sample names
--- (LibKa0s#104: no addon keeps its own list). A library-absent load answers none.
function P.People()
    if SimLib and type(SimLib.Sample) == "function" then return SimLib.Sample("forever") end
    return {}
end

--- A fixture entry with its shared row's name (the whole two-word name, as Forever's store keys
--- it, forever-quirks-§4) and realm; the fixture's own fields are kept.
local function person(entry, people)
    local row = people[entry.sample] or people[1]
    if not row then return nil end
    local out = {}
    for k, v in pairs(entry) do out[k] = v end
    out.name, out.realm = row.fullName, row.realm
    return out
end

--- Test mode's sample character, its name and realm from the shared people; a library-absent load
--- draws it nameless ("Sample character", no realm), never with an invented name.
function P.SampleCharacter()
    local entry = fixture().character
    local c = person(entry, P.People())
    if c then return c end
    c = {}
    for k, v in pairs(entry) do c[k] = v end
    c.name, c.realm = L["Sample character"], ""
    return c
end

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

-- ── the tree families' sample records (SMW-11) ───────────────────────────────────────────────

-- The standard thresholds per reaction (1 Hated .. 8 Exalted): the bar runs from one to the next.
local THRESHOLD = { -42000, -6000, -3000, 0, 3000, 9000, 21000, 42000, 42999 }

local function faction(n, child)
    local r = n.reaction or 4
    return { factionID = n.id, name = n.name or n.header, isHeader = n.header ~= nil, isChild = child == true,
             isHeaderWithRep = n.withRep == true, isCollapsed = false, reaction = r,
             currentReactionThreshold = THRESHOLD[r], nextReactionThreshold = THRESHOLD[r + 1],
             currentStanding = n.standing or THRESHOLD[r], description = n.description }
end

--- The fixture's Reputation tab as FactionData records, in the panel's order, every header open (a fresh copy:
--- the simulator's world changes its own).
function P.FactionRows()
    local out = {}
    for _, top in ipairs(fixture().reputations or {}) do
        out[#out + 1] = faction(top, false)                -- a top header: Alliance, Other
        for _, k in ipairs(top.kids or {}) do
            local sub = k.header ~= nil                    -- a sub-header (isHeader and isChild), its kids children
            out[#out + 1] = faction(k, sub)
            for _, kk in ipairs(sub and k.kids or {}) do out[#out + 1] = faction(kk, true) end
        end
    end
    return out
end

--- The fixture's Currency tab as CurrencyInfo records, in order, every header open (a fresh copy). No gold.
function P.CurrencyRows()
    local out = {}
    for _, h in ipairs(fixture().currencies or {}) do
        out[#out + 1] = { name = h.header, currencyID = 0, isHeader = true, isHeaderExpanded = true,
                          currencyListDepth = 0, quantity = 0, maxQuantity = 0 }
        for _, c in ipairs(h.kids or {}) do
            out[#out + 1] = { name = c.name, currencyID = c.id, isHeader = false, currencyListDepth = 1,
                              quantity = c.quantity or 0, maxQuantity = c.max or 0, canEarnPerWeek = c.weekly ~= nil,
                              maxWeeklyQuantity = c.weekly or 0, quantityEarnedThisWeek = c.earned or 0,
                              iconFileID = c.icon, description = c.description }
        end
    end
    return out
end

--- The fixture's Statistics tab: { { id, name, parent, rows = { { statID, name, quantity } } } } (a fresh copy).
function P.StatisticsList()
    local out = {}
    for i, c in ipairs(fixture().statistics or {}) do
        local rows = {}
        for j, r in ipairs(c.rows or {}) do rows[j] = { statID = r.statID, name = r.name, quantity = r.quantity } end
        out[i] = { id = c.id, name = c.name, parent = c.parent, rows = rows }
    end
    return out
end

local function buildTrees()
    return { reputations = NS.RepData.Build(P.FactionRows()), currencies = NS.CurrencyData.Build(P.CurrencyRows()),
             statistics = NS.StatisticsData.Build(P.StatisticsList()) }
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

local function ownRecord(c, skills, now, stats, trees)
    local mine = {}
    for key, e in pairs(skills.byKey) do
        if e.learned then mine[key] = { name = e.name, category = e.category, rank = e.rank, max = e.max } end
    end
    return { name = c.name, class = c.classFile, className = L[c.class], race = L[c.race], level = c.level,
             faction = c.faction, updated = now, skills = mine, stats = NS.Alts.StatsOf(stats),
             reps = NS.Alts.RepsOf(trees.reputations), currencies = NS.Alts.CurrenciesOf(trees.currencies) }
end

local function buildAlts(c, skills, now, stats, trees)
    local list = { { key = c.realm .. "-" .. c.name, record = ownRecord(c, skills, now, stats, trees),
                     isCurrent = true } }
    local others, people = {}, P.People()
    for _, entry in ipairs(fixture().alts or {}) do
        local a = person(entry, people)   -- nil without the library: no invented alt
        if a then
            local s = {}
            for key, v in pairs(a.skills) do s[key] = catalogSkill(key, v[1], v[2]) end
            others[#others + 1] = { key = a.realm .. "-" .. a.name, isCurrent = false,
                record = { name = a.name, class = a.class, className = L[a.className], race = L[a.race],
                           level = a.level, faction = a.faction, updated = now - (a.updatedAgo or 0), skills = s } }
        end
    end
    table.sort(others, function(x, y) return x.record.name < y.record.name end)
    for _, o in ipairs(others) do list[#list + 1] = o end
    return NS.Alts.View(list)
end

local function samplePins(key)
    local fid = key and NS.Pins.FamilyOfSkill(key)
    local out = fid and { [fid] = { key } } or {}
    for family, k in pairs(fixture().treePins or {}) do out[family] = { k } end   -- the tree feeds' (SMW-11)
    return out
end

local function buildBroker(d)
    local total, byKey = d.log:Gains()
    local last = fixture().last
    local fx = fixture()
    return { model = d.skills, statsModel = d.stats, statIndex = d.statIndex,
             gains = { total = total, byKey = byKey }, models = d.trees,
             last = last and { key = keyOf(last.skill), new = last.new } or nil,
             -- {pinned} and {equippedWeapon}: the sample's, never this character's store or gear (its
             -- one pinned skill on its own family's broker, SMW-06)
             pins = samplePins(fx.pinned and keyOf(fx.pinned)),
             mainHand = fx.mainHand and keyOf(fx.mainHand) or nil }
end

--- Build the whole sample once, its timers counted from now.
function P.Build()
    local c = P.SampleCharacter()
    local now, clock = time(), GetTime()
    local d = { character = c }
    d.skills = buildSkills(c)
    d.stats, d.statIndex = NS.StatData.Build(fixture().stats, c.level)
    d.trees = buildTrees()
    d.candidates = buildCandidates(clock)
    d.log = buildLog(d.skills, now)
    d.alts = buildAlts(c, d.skills, now, d.stats, d.trees)   -- the others carry no stats: a dash each (FB-33)
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

local function blocksSource() return data.skills, data.stats, data.trees end
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
