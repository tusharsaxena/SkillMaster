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
    local savedFaction, savedRace = M.UnitFactionGroup, M.UnitRace
    M.UnitFactionGroup = function() return "Horde", "Horde" end
    M.UnitRace = function() return "Undead", "Scourge" end
    local list = NS.Trainers:For("polearms")
    assertEqual(list[1].name, "Archibald", names(list))
    assertEqual(#list, 1, names(list))
    M.UnitFactionGroup, M.UnitRace = savedFaction, savedRace
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

-- ---------------------------------------------------------------------------------------------
-- The trainer probe's fixes (GitHub issue #3; the four errors #2 found, each red on the old rows)
-- ---------------------------------------------------------------------------------------------

local function record(name)
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.name == name then return t end
    end
    return nil
end

local function near(t, x, y)
    return t and t.x and math.sqrt((t.x - x) ^ 2 + (t.y - y) ^ 2) <= 1.0
end

test("trainer probe fix: Woo Ping stands in Forever's re-bounded Stormwind frame, not the Era one", function()
    local t = record("Woo Ping")
    assertTrue(near(t, 63.88, 69.09), ("Woo Ping at %s, %s"):format(tostring(t and t.x), tostring(t and t.y)))
    assertTrue(not near(t, 57.1, 57.7), "the Era-frame point is gone")
end)

test("trainer probe fix: Undercity's Journeyman Alchemy trainer is Doctor Martin Felben (npc 11044)", function()
    assertNil(record("Doctor Martin Felbin"), "the misspelled name matches no NPC")
    local t = record("Doctor Martin Felben")
    assertTrue(t ~= nil and t.npcID == 11044 and t.city == "Undercity", "Felben")
end)

test("trainer probe fix: Gorina, a Mining Supplier, is no Mining trainer; Makaru still trains Orgrimmar", function()
    assertNil(record("Gorina"), "Gorina is a vendor (npcFlags 4)")
    local list = NS.Trainers:For("mining", "Horde", "Orc")
    assertTrue(has(list, "Makaru", "Orgrimmar"), names(list))
end)

test("trainer probe fix: no two NPCs share one shipped point (Bixi and Buliwyf, Sayoc and Hanashi)", function()
    local at = {}
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.x then
            local k = ("%d:%.1f:%.1f"):format(t.mapID, t.x, t.y)
            assertTrue(at[k] == nil or at[k] == t.name, ("%s shares %s with %s"):format(t.name, k, tostring(at[k])))
            at[k] = t.name
        end
    end
    assertTrue(near(record("Buliwyf Stonehand"), 61.17, 89.52), "Buliwyf at his own spawn")
end)

test("trainer probe: every record carries its NPC id, once, and a point inside the map or none", function()
    local seen = {}
    for _, t in ipairs(NS.Trainers_Forever) do
        assertEqual(type(t.npcID), "number", t.id .. " npcID")
        assertTrue(seen[t.npcID] == nil, "npc " .. t.npcID .. " twice")
        seen[t.npcID] = true
        assertEqual(t.x == nil, t.y == nil, t.id .. " x and y together")
        if t.x then
            assertTrue(t.x > 0 and t.x < 100 and t.y > 0 and t.y < 100, t.id .. " in percent, 0..100")
        end
    end
end)

test("trainer probe: a rank learned from a book or a quest names it (the owner's books comment on #3)", function()
    local want = {
        Shandrina = 16072, Wulan = 16072, ["Deneb Walker"] = 16084, ["Balai Lok'Wein"] = 16084,
        ["Old Man Heming"] = 16083,
    }
    for name, item in pairs(want) do
        local t = record(name)
        assertTrue(t and t.learn and t.learn.kind == "book" and t.learn.itemID == item, name)
    end
    local quests = { ["Dirge Quikcleave"] = 6610, ["Nat Pagle"] = 6607, ["Doctor Gustaf VanHowzen"] = 6624,
                     ["Doctor Gregory Victor"] = 6622 }
    for name, q in pairs(quests) do
        local t = record(name)
        assertTrue(t and t.learn and t.learn.kind == "quest" and t.learn.questID == q, name)
    end
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.learn then assertTrue(type(t.learn.item or t.learn.quest) == "string", t.id .. " learn names it") end
    end
end)
