-- tests/test_skilldata.lua — the skill catalog, the skill-line adapter and SkillData's model
-- (plan Task 2.1; Review Focus 1, 2 and 5).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ---------------------------------------------------------------------------------------------
-- The fixture: a skill list of headers, each with its lines, in the shape `shape` names:
--   "table"  C_SkillInfo.GetSkillLineInfo answering the modern struct (the default)
--   "multi"  C_SkillInfo.GetSkillLineInfo answering the 1.12 positional list
--   "global" only the 1.12 globals (GetNumSkillLines, GetSkillLineInfo, ...)
-- A line is { name, rank, tempPoints, modifier, max }. A collapsed header hides its lines, as the
-- stock Skills tab does, and Expand/Collapse change what the indices answer.
-- ---------------------------------------------------------------------------------------------

local SAVED = { "C_SkillInfo", "GetNumSkillLines", "GetSkillLineInfo", "ExpandSkillHeader", "CollapseSkillHeader" }

local function visible(spec)
    local out = {}
    for _, h in ipairs(spec) do
        out[#out + 1] = { header = h }
        if h.expanded then
            for _, l in ipairs(h.lines) do out[#out + 1] = { line = l } end
        end
    end
    return out
end

local function positional(v)
    if v.header then return v.header.name, true, v.header.expanded and true or false, 0, 0, 0, 0 end
    local l = v.line
    return l[1], nil, nil, l[2], l[3] or 0, l[4] or 0, l[5]
end

local function struct(v)
    if v.header then
        return { skillName = v.header.name, isHeader = true, isExpanded = v.header.expanded and true or false }
    end
    local l = v.line
    return { skillName = l[1], isHeader = false, isExpanded = false, skillRank = l[2],
             numTempPoints = l[3] or 0, skillModifier = l[4] or 0, skillMaxRank = l[5] }
end

local function api(spec, shape, probe)
    local reader = shape == "table" and struct or positional
    local function toggle(open)
        return function(i)
            local v = visible(spec)[i]
            if v and v.header then
                v.header.expanded = open
                probe.toggles = probe.toggles + 1
                if probe.onToggle then probe.onToggle() end
            end
        end
    end
    return {
        GetNumSkillLines = function() return #visible(spec) end,
        GetSkillLineInfo = function(i)
            local v = visible(spec)[i]
            if v then return reader(v) end
        end,
        ExpandSkillHeader = toggle(true),
        CollapseSkillHeader = toggle(false),
    }
end

--- Run fn with the skill list installed; everything it touched is restored, pass or fail.
local function withSkills(spec, shape, fn, context)
    local saved, ctx = {}, {}
    for _, k in ipairs(SAVED) do saved[k] = M[k] end
    for k, v in pairs(context or {}) do ctx[k] = M.__context[k]; M.__context[k] = v end
    local probe = { toggles = 0 }
    local a = api(spec, shape or "table", probe)
    if shape == "global" then
        M.C_SkillInfo = nil
        M.GetNumSkillLines, M.GetSkillLineInfo = a.GetNumSkillLines, a.GetSkillLineInfo
        M.ExpandSkillHeader, M.CollapseSkillHeader = a.ExpandSkillHeader, a.CollapseSkillHeader
    else
        M.C_SkillInfo = a
        M.GetNumSkillLines, M.GetSkillLineInfo, M.ExpandSkillHeader, M.CollapseSkillHeader = nil, nil, nil, nil
    end
    local ok, err = pcall(fn, probe)
    for _, k in ipairs(SAVED) do M[k] = saved[k] end
    for k, v in pairs(ctx) do M.__context[k] = v end
    NS.SkillData:Reset()
    if not ok then error(err, 0) end
end

--- Count the bus messages sent while fn runs.
local function listen(fn)
    local target = NS.NewBusTarget()
    local got = { updated = 0, ups = {} }
    target:RegisterMessage(NS.MSG.SKILLS_UPDATED, function(_, model) got.updated = got.updated + 1; got.model = model end)
    target:RegisterMessage(NS.MSG.SKILL_UP, function(_, key, old, new)
        got.ups[#got.ups + 1] = ("%s,%s,%s"):format(key, tostring(old), tostring(new))
    end)
    local ok, err = pcall(fn)
    target:UnregisterAllMessages()
    if not ok then error(err, 0) end
    return got
end

local function hunterSpec(bows)
    return {
        { name = "Class Skills", expanded = true, lines = { { "Marksmanship", 1, 0, 0, 1 } } },
        { name = "Professions", expanded = true, lines = { { "Leatherworking", 146, 0, 0, 150 } } },
        { name = "Secondary Skills", expanded = true, lines = { { "Fishing", 107, 0, 25, 150 } } },
        { name = "Weapon Skills", expanded = true, lines = {
            { "Axes", 98, 0, 0, 110 }, { "Bows", bows or 80, 0, 0, 110 }, { "Daggers", 40, 0, 0, 110 },
            { "Defense", 100, 0, 0, 110 }, { "Guns", 105, 0, 5, 110 }, { "Unarmed", 30, 0, 0, 110 },
        } },
        { name = "Armor Proficiencies", expanded = true, lines = { { "Leather", 1, 0, 0, 1 } } },
        { name = "Languages", expanded = true, lines = { { "Language: Dwarven", 300, 0, 0, 300 } } },
    }
end
local DWARF_HUNTER = { class = "Hunter", classToken = "HUNTER", level = 22 }

local function liveTimers()
    local out = {}
    -- The pending queue; each case empties it first, so nothing in it was taken back.
    for _, t in ipairs(M.__timers) do out[#out + 1] = t end
    return out
end

local function contains(list, value)
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- The catalog
-- ---------------------------------------------------------------------------------------------

test("skillcatalog: every vanilla profession, the 16 weapon lines, Defense, Lockpicking and Riding", function()
    local want = {
        primary = { "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "leatherworking",
                    "mining", "skinning", "tailoring" },
        secondary = { "cooking", "firstAid", "fishing" },
        weapon = { "axes", "twoHandedAxes", "bows", "crossbows", "daggers", "fistWeapons", "guns", "maces",
                   "twoHandedMaces", "polearms", "staves", "swords", "twoHandedSwords", "thrown", "unarmed", "wands" },
        other = { "defense", "lockpicking", "riding" },
    }
    local n = 0
    for category, keys in pairs(want) do
        for _, key in ipairs(keys) do
            local e = NS.SkillCatalog[key]
            assertTrue(e ~= nil, "missing catalog key " .. key)
            assertEqual(e.category, category, key)
            n = n + 1
        end
    end
    local total = 0
    for _ in pairs(NS.SkillCatalog) do total = total + 1 end
    assertEqual(total, n, "the catalog holds exactly the listed keys")
    assertEqual(#want.weapon, 16)
end)

test("skillcatalog: kinds, tiers and the window each row opens", function()
    local C = NS.SkillCatalog
    assertEqual(C.leatherworking.kind, "craft")
    assertEqual(table.concat(C.leatherworking.tiers, ","), "75,150,225,300")
    assertEqual(C.leatherworking.openSpell, "Leatherworking")
    assertFalse(C.leatherworking.opensSkillsTab)
    assertEqual(C.mining.kind, "gather")
    assertEqual(C.mining.openSpell, "Smelting", "Mining opens the Smelting window")
    assertEqual(C.skinning.openSpell, nil)
    assertTrue(C.skinning.opensSkillsTab)
    assertEqual(C.fishing.kind, "gather")
    assertEqual(C.cooking.kind, "craft")
    assertEqual(C.fistWeapons.kind, "weapon")
    assertEqual(C.fistWeapons.tiers, nil)
    assertTrue(C.fistWeapons.opensSkillsTab)
    assertEqual(C.defense.kind, "defense")
    assertEqual(C.lockpicking.kind, "lockpicking")
    assertEqual(C.riding.kind, "riding")
    assertEqual(table.concat(C.riding.tiers, ","), "75,150")
end)

test("skillcatalog: the localized-name map answers each enUS name and the racial riding names", function()
    assertEqual(NS.SkillNameToKey["Two-Handed Axes"], "twoHandedAxes")
    assertEqual(NS.SkillNameToKey["Fist Weapons"], "fistWeapons")
    assertEqual(NS.SkillNameToKey["First Aid"], "firstAid")
    assertEqual(NS.SkillNameToKey["Ram Riding"], "riding")
    assertEqual(NS.SkillNameToKey["Mechanostrider Piloting"], "riding")
    assertEqual(NS.SkillNameToKey["Language: Dwarven"], nil)
end)

test("skillcatalog: both data tables record a source and stay unverified until the smoke pass", function()
    for _, name in ipairs({ "SkillCatalog_Forever", "ClassWeapons_Forever" }) do
        local meta = NS.DataMeta[name]
        assertTrue(meta ~= nil, name)
        assertEqual(type(meta.source), "string", name)
        assertEqual(meta.verified, false, name)
    end
end)

test("classweapons: every class lists only catalog keys", function()
    local classes = 0
    for classFile, keys in pairs(NS.ClassWeapons_Forever) do
        classes = classes + 1
        for _, key in ipairs(keys) do
            assertTrue(NS.SkillCatalog[key] ~= nil, classFile .. ": " .. key)
        end
    end
    assertEqual(classes, 9, "the nine vanilla classes")
    assertFalse(contains(NS.ClassWeapons_Forever.HUNTER, "maces"), "a hunter cannot train maces")
    assertTrue(contains(NS.ClassWeapons_Forever.PRIEST, "wands"))
end)

-- ---------------------------------------------------------------------------------------------
-- The adapter: one normalized record from either return shape
-- ---------------------------------------------------------------------------------------------

for _, shape in ipairs({ "table", "multi", "global" }) do
    test("compat: SkillLineInfo normalizes the " .. shape .. " shape", function()
        withSkills(hunterSpec(), shape, function()
            assertEqual(NS.Compat.NumSkillLines(), 17)
            local h = NS.Compat.SkillLineInfo(1)
            assertEqual(h.name, "Class Skills")
            assertTrue(h.isHeader == true and h.isExpanded == true, "header flags are booleans")
            local g = NS.Compat.SkillLineInfo(12)
            assertEqual(g.name, "Guns")
            assertTrue(g.isHeader == false, "a line is not a header")
            assertEqual(g.rank, 105)
            assertEqual(g.tempPoints, 0)
            assertEqual(g.modifier, 5)
            assertEqual(g.max, 110)
            assertEqual(NS.Compat.SkillLineInfo(99), nil, "past the end answers nil")
        end)
    end)
end

test("compat: no skill-list API at all answers 0 lines and nil, never an error", function()
    withSkills({}, "global", function()
        M.GetNumSkillLines, M.GetSkillLineInfo = nil, nil
        assertEqual(NS.Compat.NumSkillLines(), 0)
        assertEqual(NS.Compat.SkillLineInfo(1), nil)
        assertFalse(NS.Compat.SetSkillHeaderExpanded(1, true))
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- SkillData
-- ---------------------------------------------------------------------------------------------

test("skilldata: classifies categories (Leatherworking, Fishing + lure, Guns + racial, Defense)", function()
    withSkills(hunterSpec(), "table", function()
        local m = NS.SkillData:Scan()
        local lw, fi, gu, de = m.byKey.leatherworking, m.byKey.fishing, m.byKey.guns, m.byKey.defense
        assertEqual(lw.category, "primary")
        assertEqual(lw.rank, 146); assertEqual(lw.max, 150)
        assertEqual(fi.category, "secondary")
        assertEqual(fi.rank, 107); assertEqual(fi.modifier, 25); assertEqual(fi.max, 150)
        assertEqual(gu.category, "weapon")
        assertEqual(gu.rank, 105); assertEqual(gu.modifier, 5); assertEqual(gu.max, 110)
        assertEqual(de.category, "other")
        assertEqual(de.rank, 100); assertEqual(de.max, 110)
        for _, e in ipairs({ lw, fi, gu, de }) do
            assertTrue(e.learned == true, e.key)
            assertEqual(e.tempPoints, 0, e.key)
            assertEqual(NS.SkillData:Get(e.key), e)
        end
        assertEqual(gu.name, "Guns", "the client's own name")
        assertEqual(m.order.primary[1], "leatherworking")
        assertEqual(m.order.secondary[1], "fishing")
        assertEqual(m.order.other[1], "defense")
        assertEqual(m.order.weapon[1], "axes", "learned lines keep the client's order")
        assertEqual(NS.SkillData:Model(), m)
    end, DWARF_HUNTER)
end)

test("skilldata: armor, languages and class spell lines are left out (design §3)", function()
    withSkills(hunterSpec(), "table", function()
        local m = NS.SkillData:Scan()
        for key, e in pairs(m.byKey) do
            assertTrue(e.name ~= "Leather" and e.name ~= "Marksmanship" and e.name ~= "Language: Dwarven", key)
        end
        assertEqual(#m.order.other, 2, "Defense and the unlearned Riding row")
    end, DWARF_HUNTER)
end)

test("skilldata: an empty or half-loaded list gives empty-state rows and no error", function()
    withSkills({}, "table", function()
        local got = listen(function() NS.SkillData:Scan() end)
        local m = got.model
        assertEqual(got.updated, 1, "SKILLS_UPDATED still goes out")
        for _, category in ipairs({ "primary", "secondary", "weapon", "other" }) do
            assertEqual(type(m.order[category]), "table", category)
            assertEqual(#m.order[category], 0, category .. ": nothing synthesized from an unloaded list")
        end
        assertEqual(next(m.byKey), nil)
        assertEqual(#got.ups, 0)
    end, DWARF_HUNTER)
    withSkills({}, "global", function()
        M.GetNumSkillLines, M.GetSkillLineInfo = nil, nil
        local m = NS.SkillData:Scan()
        assertEqual(next(m.byKey), nil, "no API at all is the same empty model")
    end, DWARF_HUNTER)
end)

test("skilldata: the model exists before the first scan, empty", function()
    NS.SkillData:Reset()
    local m = NS.SkillData:Model()
    assertEqual(#m.order.weapon, 0)
    assertEqual(NS.SkillData:Get("bows"), nil)
end)

test("skilldata: collapsed headers are expanded for the scan and restored after it", function()
    local spec = hunterSpec()
    spec[2].expanded = false   -- Professions, collapsed by the player
    spec[4].expanded = false   -- Weapon Skills, collapsed by the player
    withSkills(spec, "table", function(probe)
        local m = NS.SkillData:Scan()
        assertTrue(m.byKey.leatherworking ~= nil and m.byKey.leatherworking.learned, "child of a collapsed header read")
        assertTrue(m.byKey.bows ~= nil and m.byKey.bows.learned, "child of a collapsed header read")
        assertFalse(spec[2].expanded, "Professions is collapsed again")
        assertFalse(spec[4].expanded, "Weapon Skills is collapsed again")
        assertTrue(spec[3].expanded, "a header the player left open stays open")
        assertEqual(probe.toggles, 4, "two expands, two collapses, nothing else touched")
    end, DWARF_HUNTER)
end)

test("skilldata: an unknown (localized) name lands in Other, never an error", function()
    local spec = {
        { name = "Berufe", expanded = true, lines = { { "Lederverarbeitung", 12, 0, 0, 75 } } },
        { name = "Waffenfertigkeiten", expanded = true, lines = { { "Bows", 80, 0, 0, 110 } } },
    }
    withSkills(spec, "table", function()
        local m = NS.SkillData:Scan()
        local key = m.order.other[1]
        local e = m.byKey[key]
        assertTrue(e ~= nil, "the unknown line is in Other")
        assertEqual(e.name, "Lederverarbeitung")
        assertEqual(e.category, "other")
        assertEqual(e.rank, 12); assertEqual(e.max, 75)
        assertTrue(e.learned == true)
        assertEqual(m.byKey.bows.category, "weapon", "a name the map knows is classified by it, whatever its header")
    end, DWARF_HUNTER)
end)

test("skilldata: a rank rising 80 -> 81 sends SKILL_UP(\"bows\", 80, 81) once", function()
    local spec = hunterSpec(80)
    withSkills(spec, "table", function()
        local got = listen(function()
            NS.SkillData:Scan()
            spec[4].lines[2][2] = 81
            NS.SkillData:Scan()
            NS.SkillData:Scan()
        end)
        assertEqual(table.concat(got.ups, ";"), "bows,80,81")
        assertEqual(got.updated, 3, "SKILLS_UPDATED on every pass")
    end, DWARF_HUNTER)
end)

test("skilldata: the first scan sends no SKILL_UP", function()
    withSkills(hunterSpec(), "table", function()
        local got = listen(function() NS.SkillData:Scan() end)
        assertEqual(#got.ups, 0)
    end, DWARF_HUNTER)
end)

test("skilldata: unlearned weapon and riding rows are synthesized for a Dwarf Hunter", function()
    withSkills(hunterSpec(), "table", function()
        local m = NS.SkillData:Scan()
        for _, key in ipairs({ "fistWeapons", "polearms", "thrown", "riding" }) do
            local e = m.byKey[key]
            assertTrue(e ~= nil, key .. " synthesized")
            assertTrue(e.learned == false, key)
            assertEqual(e.category, NS.SkillCatalog[key].category, key)
            assertEqual(e.rank, 0, key)
            assertTrue(contains(m.order[e.category], key), key .. " is in its category's order")
        end
        assertEqual(m.byKey.fistWeapons.name, "Fist Weapons", "the localized catalog name")
        assertEqual(m.byKey.maces, nil, "a hunter cannot train maces")
        assertEqual(m.byKey.wands, nil, "nor wands")
        assertTrue(m.byKey.guns.learned, "a learned line is not duplicated")
        local weapons = m.order.weapon
        assertEqual(weapons[#weapons], "thrown", "unlearned rows follow the learned ones, catalog order")
    end, DWARF_HUNTER)
end)

test("skilldata: the 1.12 global shape scans the same model", function()
    withSkills(hunterSpec(), "global", function()
        local m = NS.SkillData:Scan()
        assertEqual(m.byKey.guns.rank, 105)
        assertEqual(m.byKey.guns.modifier, 5)
        assertEqual(m.byKey.fishing.category, "secondary")
    end, DWARF_HUNTER)
end)

test("skilldata: the three events are debounced into one scan 0.1 s later", function()
    withSkills(hunterSpec(), "table", function()
        for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
        NS.SkillData:RegisterEvents()
        local got = listen(function()
            for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
            M.__fireEvent("SKILL_LINES_CHANGED")
            M.__fireEvent("CHAT_MSG_SKILL", "Your skill in Bows has increased to 81.")
            M.__fireEvent("PLAYER_LEVEL_UP", 23)
            local live = liveTimers()
            assertEqual(#live, 1, "one pending scan for three events")
            assertTrue(math.abs(live[1].delay - 0.1) < 1e-9, "debounced 0.1 s: " .. tostring(live[1].delay))
            M.__fireTimers()
        end)
        NS.SkillData:UnregisterEvents()
        assertEqual(got.updated, 1, "one scan, one message")
    end, DWARF_HUNTER)
end)

test("skilldata: PLAYER_LEVEL_UP lifts the weapon cap to 5 x the new level before the list catches up", function()
    withSkills(hunterSpec(), "table", function()
        NS.SkillData:RegisterEvents()
        M.__fireEvent("PLAYER_LEVEL_UP", 23)
        M.__fireTimers()
        NS.SkillData:UnregisterEvents()
        local m = NS.SkillData:Model()
        assertEqual(m.byKey.guns.max, 115, "5 x 23")
        assertEqual(m.byKey.defense.max, 115, "Defense follows the level too")
        assertEqual(m.byKey.leatherworking.max, 150, "a profession cap does not move")
    end, DWARF_HUNTER)
end)

test("skilldata: the scan's own header toggles do not schedule another scan", function()
    local spec = hunterSpec()
    spec[4].expanded = false
    withSkills(spec, "table", function(probe)
        NS.SkillData:RegisterEvents()
        probe.onToggle = function() M.__fireEvent("SKILL_LINES_CHANGED") end
        for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
        NS.SkillData:Scan()
        local queued = #liveTimers()
        NS.SkillData:UnregisterEvents()
        assertEqual(queued, 0, "the expand/collapse echo was ignored")
    end, DWARF_HUNTER)
end)
