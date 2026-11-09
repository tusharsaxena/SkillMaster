-- tests/test_trainers.lua — the trainer DB and its lookups: where to learn a skill and where to
-- train its next rank (plan Task 2.4, design §5.2 Trainers).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

local function names(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = t.name .. "@" .. t.city end
    return table.concat(out, ",")
end

local function has(list, name, city)
    for _, t in ipairs(list) do
        if t.name == name and (city == nil or t.city == city) then return true end
    end
    return false
end

test("test_trainers_fist_alliance: Alliance fist weapons are taught in Ironforge and Darnassus", function()
    local list = NS.Trainers:For("fistWeapons", "Alliance", "Dwarf")
    -- The plan named Bixi Wobblebonk here; every Classic source (the Blizzard Ironforge city tour,
    -- warcraft.wiki.gg) has her teaching Crossbows, Daggers and Thrown only. Buliwyf Stonehand,
    -- in the same shop, is the Ironforge fist-weapon master.
    assertTrue(has(list, "Buliwyf Stonehand", "Ironforge"), names(list))
    assertTrue(has(list, "Ilyenia Moonfire", "Darnassus"), names(list))
    assertTrue(not has(list, "Bixi Wobblebonk"), "Bixi does not teach fist weapons: " .. names(list))
    assertTrue(not has(list, "Sayoc"), "no Horde trainer on the Alliance list: " .. names(list))
    assertEqual(list[1].city, "Ironforge", "a Dwarf's home city sorts first")
end)

test("test_trainers_fist_alliance: the home city of the player's race sorts first", function()
    local list = NS.Trainers:For("fistWeapons", "Alliance", "NightElf")
    assertEqual(list[1].name, "Ilyenia Moonfire", names(list))
end)

test("trainers: Horde fist weapons come from Sayoc in Orgrimmar only", function()
    local list = NS.Trainers:For("fistWeapons", "Horde", "Orc")
    assertEqual(names(list), "Sayoc@Orgrimmar")
end)

test("trainers: For reads the player's faction and race when none is passed", function()
    M.UnitFactionGroup = function() return "Horde", "Horde" end
    M.UnitRace = function() return "Undead", "Scourge" end
    local list = NS.Trainers:For("polearms")
    assertEqual(list[1].name, "Archibald", names(list))
    assertEqual(#list, 1, names(list))
    M.UnitFactionGroup, M.UnitRace = nil, nil
end)

test("trainers: Neutral trainers are on both factions' lists", function()
    assertTrue(has(NS.Trainers:For("cooking", "Alliance", "Human"), "Dirge Quikcleave"), "Alliance")
    assertTrue(has(NS.Trainers:For("cooking", "Horde", "Orc"), "Dirge Quikcleave"), "Horde")
end)

test("trainers: an unknown key answers an empty list, never an error", function()
    assertEqual(#NS.Trainers:For("noSuchSkill", "Alliance", "Human"), 0)
end)

test("trainers: every record is unverified and names its source", function()
    assertTrue(#NS.Trainers_Forever > 50, "the DB is populated: " .. #NS.Trainers_Forever)
    local ids = {}
    for _, t in ipairs(NS.Trainers_Forever) do
        assertTrue(t.verified == false, t.id .. " verified")
        assertEqual(type(t.source), "string", t.id .. " source")
        assertTrue(t.faction == "Alliance" or t.faction == "Horde" or t.faction == "Neutral", t.id)
        assertTrue(type(t.teaches) == "table" and #t.teaches > 0, t.id .. " teaches")
        assertTrue(ids[t.id] == nil, "duplicate id " .. t.id)
        ids[t.id] = true
    end
end)

test("test_trainers_next_rank_at_cap: Leatherworking 150/150 at level 22 trains Expert", function()
    local nxt = NS.Trainers:NextRank("leatherworking", 150, 150, 22, "Alliance", "Human")
    assertEqual(nxt.rankName, "Expert")
    assertEqual(nxt.cap, 225)
    assertEqual(nxt.minLevel, 20)
    assertTrue(nxt.canTrain, "level 22 and skill 150 meet Expert's gate")
    assertTrue(#nxt.trainers > 0, "an Expert trainer is listed")
    assertEqual(nxt.trainers[1].city, "Stormwind", names(nxt.trainers))
end)

test("trainers: NextRank answers nil at Artisan and for a skill with no ranks", function()
    assertNil(NS.Trainers:NextRank("leatherworking", 300, 300, 60, "Alliance", "Human"))
    assertNil(NS.Trainers:NextRank("bows", 80, 110, 22, "Alliance", "Dwarf"))
end)

test("trainers: NextRank's skill gate (Journeyman wants 50)", function()
    local nxt = NS.Trainers:NextRank("tailoring", 40, 75, 30, "Horde", "Orc")
    assertEqual(nxt.rankName, "Journeyman")
    assertEqual(nxt.minSkill, 50)
    assertTrue(not nxt.canTrain, "skill 40 is below Journeyman's 50")
end)

test("test_trainers_riding_level_gate: riding 75 opens at 40, 150 at 60", function()
    local at35 = NS.Trainers:NextRank("riding", 0, 0, 35, "Alliance", "Dwarf")
    assertEqual(at35.cap, 75)
    assertEqual(at35.minLevel, 40)
    assertEqual(at35.cost, 900000)
    assertTrue(not at35.canTrain, "level 35 is below the riding gate")
    assertTrue(NS.Trainers:NextRank("riding", 0, 0, 40, "Alliance", "Dwarf").canTrain, "level 40 trains")
    local at59 = NS.Trainers:NextRank("riding", 75, 75, 59, "Alliance", "Dwarf")
    assertEqual(at59.cap, 150)
    assertEqual(at59.minLevel, 60)
    assertEqual(at59.cost, 9000000)
    assertTrue(not at59.canTrain, "level 59 is below the epic gate")
    assertNil(NS.Trainers:NextRank("riding", 150, 150, 60, "Alliance", "Dwarf"))
end)

test("test_trainers_riding_level_gate: the race's own riding trainer sorts first", function()
    local nxt = NS.Trainers:NextRank("riding", 0, 0, 40, "Alliance", "Dwarf")
    assertEqual(nxt.trainers[1].name, "Ultham Ironhorn", names(nxt.trainers))
end)
