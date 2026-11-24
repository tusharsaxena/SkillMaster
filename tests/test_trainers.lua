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

test("trainers: every record names its source, its side and what it teaches, under a unique id", function()
    assertTrue(#NS.Trainers_Forever > 50, "the DB is populated: " .. #NS.Trainers_Forever)
    local ids = {}
    for _, t in ipairs(NS.Trainers_Forever) do
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
    -- The owner's ruling (2026-11-23): Stormwind's Expert-titled trainer trains Journeyman only, so
    -- Expert Leatherworking for Alliance is Telonis, Darnassus.
    assertEqual(nxt.trainers[1].name, "Telonis", names(nxt.trainers))
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
            -- Two Forever-only alchemists QuestieDB puts 0.02 map-% apart (Linzy Blackbolt, Patricia Egan,
            -- Alterac Mountains): an in-game look settles which stands there (SM-TPROBE-11).
            local pair = (at[k] == "Linzy Blackbolt" and t.name == "Patricia Egan")
            assertTrue(at[k] == nil or at[k] == t.name or pair, ("%s shares %s with %s"):format(t.name, k, tostring(at[k])))
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

-- ---------------------------------------------------------------------------------------------
-- Provenance (GitHub issue #3): a probe confirmation or an explicit reason, for every record
-- ---------------------------------------------------------------------------------------------

test("trainer provenance: every record carries the probe's confirmation or an explicit unverified reason", function()
    local meta = NS.DataMeta.Trainers_Forever
    assertTrue(meta ~= nil and type(meta.verified) == "string" and meta.verified:match("^questiedb@%x+$") ~= nil,
        "NS.DataMeta.Trainers_Forever names the QuestieDB commit")
    assertEqual(type(meta.source), "string", "the probe is named")
    assertTrue(type(meta.sources) == "table" and #meta.sources > 0, "the sources and their pins")
    local P = NS.TrainerProvenance_Forever
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.verified ~= false then
            assertEqual(t.verified, meta.verified, t.id .. ": a confirmation is the run's tag")
            assertTrue(P.confirmed[t.id] ~= nil, t.id .. ": confirmed by the probe")
            assertNil(t.unverified, t.id .. ": a confirmed record has no reason")
        else
            assertEqual(type(t.unverified), "string", t.id .. ": an unverified record says why")
            assertTrue(#t.unverified > 0, t.id .. ": an empty reason")
        end
    end
end)

test("trainer provenance: a confirmed record still holds the values the probe confirmed", function()
    local byId = {}
    for _, t in ipairs(NS.Trainers_Forever) do byId[t.id] = t end
    for id, c in pairs(NS.TrainerProvenance_Forever.confirmed) do
        local t = byId[id]
        assertTrue(t ~= nil, id .. ": the probe confirmed a record that no longer ships")
        for _, field in ipairs({ "npcID", "name", "mapID", "x", "y" }) do
            assertEqual(t[field], c[field], id .. "." .. field .. " changed since the probe: re-run tools/trainer_probe.lua")
        end
    end
    for id in pairs(NS.TrainerProvenance_Forever.unverified) do
        assertTrue(byId[id] ~= nil, id .. ": a reason for a record that no longer ships")
    end
end)

test("trainer provenance: no trainer is shown as unverified (the owner, 2026-11-25)", function()
    local open
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.verified == false then open = open or t end
    end
    assertTrue(open ~= nil, "the data still records unverified trainers")
    assertNil(NS.Waypoints.UnverifiedMark, "no mark helper ships")
    assertTrue(NS.Waypoints:Directions(open):find("unverified", 1, true) == nil, "chat names no mark")
    assertNil(NS.GetSetting and NS.GetSetting("trainers.unverified"), "no setting turns a mark on")
end)

-- The popup on `key`, learned at `rank` / `max` for an Alliance Human at level 40 (the blocks'
-- model), then everything back (tests/test_round6.lua withRankPopup's shape).
local function withRankPopup(key, rank, max, fn)
    local TP, Bl = NS.TrainerPopup, NS.Blocks
    local savedSource, savedFaction, savedRace, savedLevel = Bl.source, M.UnitFactionGroup, M.UnitRace, M.UnitLevel
    local skills = { byKey = { [key] = { key = key, rank = rank, max = max, learned = true, category = "secondary" } },
                     order = { primary = {}, secondary = { key }, weapon = {}, other = {} } }
    Bl.source = function() return skills, { base = {}, spell = {}, defense = {}, utility = {} } end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.UnitRace = function() return "Human", "Human" end
    M.UnitLevel = function() return 40 end
    TP.Show(key)
    local ok, err = pcall(fn, TP.Frame())
    TP.Hide()
    Bl.source, M.UnitFactionGroup, M.UnitRace, M.UnitLevel = savedSource, savedFaction, savedRace, savedLevel
    if not ok then error(err, 0) end
end

test("trainer probe books: a card for a book vendor or a rank quest's giver says how the rank is learned (#3)", function()
    withRankPopup("fishing", 150, 150, function()
        local by = {}
        for _, c in ipairs(NS.TrainerPopup.Cards()) do by[c.trainer.name] = c end
        assertEqual(by["Old Man Heming"].alsoText, "Sells Expert Fishing - The Bass and You")
        assertEqual(by["Nat Pagle"].alsoText, "Quest: Nat Pagle, Angler Extreme")
        assertEqual(by["Nat Pagle"].also:GetText(), "Quest: Nat Pagle, Angler Extreme", "the card's second line")
    end)
    withRankPopup("firstAid", 150, 150, function()
        for _, c in ipairs(NS.TrainerPopup.Cards()) do
            if c.trainer.name == "Deneb Walker" then
                assertEqual(c.alsoText, "Sells Expert First Aid - Under Wraps")
            end
        end
    end)
    local heming
    for _, t in ipairs(NS.Trainers_Forever) do if t.name == "Old Man Heming" then heming = t end end
    assertTrue(NS.Waypoints:Directions(heming):find("(27.4, 77.2) \194\183 Sells Expert Fishing - The Bass and You", 1, true) ~= nil,
        NS.Waypoints:Directions(heming))
    assertEqual(NS.Trainers.LearnNote({ name = "A trainer" }), nil, "a trainer has no learn note")
    assertEqual(NS.Trainers.WithLearn({ name = "A trainer" }, "Also teaches: Daggers"), "Also teaches: Daggers")
    assertEqual(NS.Trainers.WithLearn(heming, "Also teaches: Daggers"),
        "Sells Expert Fishing - The Bass and You \194\183 Also teaches: Daggers")
end)

-- ---------------------------------------------------------------------------------------------
-- Round 2 (the owner's Leatherworking report, 2026-11-23): who trains Artisan
-- ---------------------------------------------------------------------------------------------

local CRAFTS = { "alchemy", "blacksmithing", "enchanting", "engineering", "leatherworking", "tailoring" }
local CAPITALS = { Stormwind = true, Ironforge = true, Darnassus = true, Orgrimmar = true,
                   ["Thunder Bluff"] = true, Undercity = true }

test("round2 artisan: Alliance Artisan Leatherworking is Drakk Stonehand in the Hinterlands, not Telonis", function()
    local nxt = NS.Trainers:NextRank("leatherworking", 155, 225, 40, "Alliance", "NightElf")
    assertEqual(nxt.rankName, "Artisan")
    assertEqual(names(nxt.trainers), "Drakk Stonehand@Aerie Peak")
    local horde = NS.Trainers:NextRank("leatherworking", 155, 225, 40, "Horde", "Tauren")
    assertEqual(names(horde.trainers), "Hahrana Ironhide@Camp Mojache")
end)

test("round2 artisan: no capital trainer trains a craft to Artisan; each side has a Master who does", function()
    for _, key in ipairs(CRAFTS) do
        for _, faction in ipairs({ "Alliance", "Horde" }) do
            local nxt = NS.Trainers:NextRank(key, 210, 225, 40, faction, faction == "Alliance" and "Human" or "Orc")
            assertTrue(#nxt.trainers > 0, key .. " Artisan for " .. faction)
            for _, t in ipairs(nxt.trainers) do
                assertTrue(not CAPITALS[t.city], ("%s trains %s to Artisan in %s"):format(t.name, key, t.city))
            end
        end
    end
end)

test("round2 artisan: the capitals' Artisan-titled trainers train Expert (225)", function()
    for _, name in ipairs({ "Telonis", "Una", "Ainethil", "Doctor Herbert Halsey", "Bengus Deepforge", "Saru Steelfury",
                            "Springspindle Fizzlegear", "Roxxik", "Georgio Bolero", "Josef Gregorian" }) do
        local t = record(name)
        assertTrue(t ~= nil, name)
        local top = 0
        for _, c in ipairs(t.ranks) do top = math.max(top, c) end
        assertEqual(top, 225, name)
    end
end)

test("round2 note: Artisan Cooking at 225 says no trainer teaches it and names Clamlette Surprise and Dirge", function()
    withRankPopup("cooking", 225, 225, function()
        local TP = NS.TrainerPopup
        local notes = TP.Notes()
        assertEqual(#notes, 1)
        assertEqual(notes[1]:GetText(), "No trainer teaches Artisan Cooking. Artisan Cooking is learned from a quest: "
            .. "Clamlette Surprise, given by Dirge Quikcleave, Gadgetzan, Tanaris.")
        local heads = {}
        for i, h in ipairs(TP.Headings()) do heads[i] = h:GetText() end
        -- The owner's feedback (2026-11-24): with Show all trainers off, the quest giver alone, no
        -- "Trainers who teach Cooking" group below.
        assertEqual(table.concat(heads, ","), "Artisan (300)")
        assertEqual(TP.Trainers()[1].name, "Dirge Quikcleave", "the giver's card, for its waypoint")
        assertEqual(#TP.Trainers(), 1, "the skill's other trainers are not listed")
    end)
end)

test("round2 note: a book rank and a quest rank say so; a trained rank has no note", function()
    local Tr = NS.Trainers
    local shandrina = record("Shandrina")
    assertEqual(Tr.NoTrainerNote("Cooking", "Expert", { shandrina }),
        "No trainer teaches Expert Cooking. Expert Cooking is learned from a book: Expert Cookbook, sold by Shandrina, Ashenvale.")
    assertEqual(Tr.NoTrainerNote("First Aid", "Artisan", { record("Doctor Gustaf VanHowzen") }),
        "No trainer teaches Artisan First Aid. Artisan First Aid is learned from a quest: Triage, given by "
            .. "Doctor Gustaf VanHowzen, Theramore Isle, Dustwallow Marsh.")
    assertNil(Tr.NoTrainerNote("Leatherworking", "Artisan", { record("Drakk Stonehand") }), "a trainer trains it")
    assertNil(Tr.NoTrainerNote("Cooking", "Expert", { shandrina, record("Stephen Ryback") }), "one trainer is enough")
    assertNil(Tr.NoTrainerNote("Cooking", "Expert", {}), "an empty rank")
    withRankPopup("leatherworking", 155, 225, function()
        assertEqual(#NS.TrainerPopup.Notes(), 0, "Artisan Leatherworking is trained")
        assertEqual(NS.TrainerPopup.Trainers()[1].name, "Drakk Stonehand")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- Round 2: Show all trainers (the owner's feedback, 2026-11-23)
-- ---------------------------------------------------------------------------------------------

local function headTexts()
    local out = {}
    for i, h in ipairs(NS.TrainerPopup.Headings()) do out[i] = h:GetText() end
    return table.concat(out, ",")
end

local function withShowAll(on, fn)
    local saved = NS.TrainerPopup.ShowAll()
    NS.SetByPath("trainers.showAll", on)
    local ok, err = pcall(fn)
    NS.SetByPath("trainers.showAll", saved)
    if not ok then error(err, 0) end
end

test("round2 show all: AllRanks lists every rank, Artisan first, each trainer once under its highest", function()
    local groups = NS.Trainers:AllRanks("leatherworking", "Alliance", "Human")
    local heads, seen = {}, {}
    for i, g in ipairs(groups) do
        heads[i] = g.rankName
        for _, t in ipairs(g.trainers) do
            assertTrue(not seen[t], t.name .. " listed once")
            seen[t] = true
        end
    end
    assertEqual(table.concat(heads, ","), "Artisan,Expert,Journeyman,Apprentice")
    assertEqual(groups[1].trainers[1].name, "Drakk Stonehand")
    assertNil(NS.Trainers:AllRanks("swords"), "a weapon skill has no ranks")
end)

test("round2 show all: the popup's check box lists every rank and marks the next rank's trainers", function()
    withShowAll(false, function()
        withRankPopup("leatherworking", 155, 225, function(f)
            local TP = NS.TrainerPopup
            assertTrue(f.showAll:IsShown(), "a profession shows the check box")
            assertEqual(headTexts(), "Artisan (300)", "off: the next rank only")
            TP.SetShowAll(true)
            assertTrue(NS.db.profile.trainers.showAll, "the check box writes the profile")
            assertEqual(headTexts(), "Artisan (300),Expert (225),Journeyman (150),Apprentice (75)")
            for _, c in ipairs(TP.Cards()) do
                local artisan = c.trainer.name == "Drakk Stonehand"
                assertEqual(c.mark:IsShown(), artisan, c.trainer.name .. ": the mark is the next rank's only")
            end
            assertEqual(TP.MarkTip(), "Your next rank: Artisan (300)")
            TP.SetShowAll(false)
            assertEqual(headTexts(), "Artisan (300)", "off again")
            for _, c in ipairs(TP.Cards()) do assertTrue(not c.mark:IsShown(), "no mark when off") end
        end)
    end)
end)

test("round2 show all: quest givers sit in their rank's group, an unlearned skill marks Apprentice", function()
    withShowAll(true, function()
        withRankPopup("cooking", 225, 225, function()
            local TP = NS.TrainerPopup
            assertEqual(headTexts(), "Artisan (300),Expert (225),Journeyman (150)")
            assertEqual(TP.Groups()[1].list[1].name, "Dirge Quikcleave", "the quest giver under Artisan")
            assertTrue(TP.Groups()[1].note ~= nil, "Artisan Cooking's note")
            assertTrue(TP.Marked(TP.Groups()[1].list[1]), "Dirge trains the next rank")
        end)
    end)
    withShowAll(true, function()
        local savedFaction = M.UnitFactionGroup
        M.UnitFactionGroup = function() return "Alliance", "Alliance" end
        local TP = NS.TrainerPopup
        TP.Show("alchemy")
        local ok, err = pcall(function()
            local marked = 0
            for _, t in ipairs(TP.Trainers()) do if TP.Marked(t) then marked = marked + 1 end end
            assertTrue(marked > 0, "Apprentice trainers are marked for an unlearned skill")
        end)
        TP.Hide()
        M.UnitFactionGroup = savedFaction
        assertTrue(ok, tostring(err))
    end)
    withShowAll(true, function()
        NS.TrainerPopup.Show("swords")
        local shown = NS.TrainerPopup.Frame().showAll:IsShown()
        NS.TrainerPopup.Hide()
        assertTrue(not shown, "a weapon skill has no check box")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- Round 2: the 55 Forever-only trainers (the owner, 2026-11-23: "Go ahead and ship these 55 forever
-- only trainers"), unverified until seen in game
-- ---------------------------------------------------------------------------------------------

local FOREVER_ONLY = "Forever-only, from QuestieDB spawn, not yet seen in game"

test("round2 forever-only: the 55 ship, each unverified with its reason, an npcID and a point", function()
    local n = 0
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.unverified == FOREVER_ONLY then
            n = n + 1
            assertEqual(t.verified, false, t.id)
            assertTrue(type(t.npcID) == "number" and t.x and t.y and t.mapID, t.id .. " npcID and point")
            assertTrue(#t.teaches == 1 and type(t.ranks) == "table" and #t.ranks > 0, t.id .. " skill and ranks")
        end
    end
    assertEqual(n, 55)
end)

test("round2 forever-only: Zephras Isle and Riverglades trainers serve both factions (the owner's ruling)", function()
    local zephras, riverglades = 0, 0
    for _, t in ipairs(NS.Trainers_Forever) do
        if t.mapID == 2521 or t.mapID == 2548 then
            assertEqual(t.faction, "Neutral", t.id)
            if t.mapID == 2521 then zephras = zephras + 1 else riverglades = riverglades + 1 end
        end
    end
    assertTrue(zephras > 0 and riverglades > 0, "both new zones have trainers")
    assertTrue(has(NS.Trainers:For("alchemy", "Alliance", "Human"), "Nyassa Swiftdraught"), "Alliance list")
    assertTrue(has(NS.Trainers:For("alchemy", "Horde", "Orc"), "Nyassa Swiftdraught"), "Horde list")
    assertTrue(has(NS.Trainers:For("mining", "Horde", "Orc"), "Grungle"), "Riverglades on the Horde list")
    assertTrue(not has(NS.Trainers:For("mining", "Horde", "Orc"), "Kelsey Fargo"), "an Alliance village trainer stays Alliance")
end)

test("round2 forever-only: a Junior trainer trains Apprentice only; riding's Forever instructors join", function()
    local kelsey = record("Kelsey Fargo")
    assertEqual(table.concat(kelsey.ranks, ","), "75")
    assertEqual(kelsey.teaches[1], "mining")
    assertEqual(record("Shari Stilwell").race, "Scourge")
    assertEqual(record("Genn Fairweather").teaches[1], "riding")
end)

-- ---------------------------------------------------------------------------------------------
-- The owner's ruling (2026-11-23, "trust the source not my smoke test")
-- ---------------------------------------------------------------------------------------------

test("source ranks: a capital's titled craft trainer trains one rank below its title (Wowhead: Fimble Finespindle)", function()
    local function top(t) local m = 0 for _, c in ipairs(t.ranks) do m = math.max(m, c) end return m end
    assertEqual(top(record("Fimble Finespindle")), 150, "an Expert Leatherworker trains Journeyman")
    assertEqual(top(record("Gretta Finespindle")), 75, "a Journeyman Leatherworker trains Apprentice")
    assertEqual(top(record("Telonis")), 225, "an Artisan Leatherworker trains Expert")
    assertEqual(top(record("Drakk Stonehand")), 300, "the Master trains Artisan")
    assertEqual(top(record("Bena Winterhoof")), 75, "Bena Winterhoof trains Apprentice in the 1.12 dump")
end)

test("source ranks: every profession's every rank has a teacher for each faction", function()
    local keys = { "alchemy", "blacksmithing", "enchanting", "engineering", "herbalism", "leatherworking", "mining",
                   "skinning", "tailoring", "cooking", "firstAid", "fishing" }
    for _, key in ipairs(keys) do
        for _, faction in ipairs({ "Alliance", "Horde" }) do
            for _, max in ipairs({ 0, 75, 150, 225 }) do
                local race = faction == "Alliance" and "Human" or "Orc"
                local nxt = NS.Trainers:NextRank(key, max, max, 60, faction, race)
                assertTrue(nxt and #nxt.trainers > 0, ("%s %s past %d: no teacher"):format(faction, key, max))
            end
        end
    end
end)
