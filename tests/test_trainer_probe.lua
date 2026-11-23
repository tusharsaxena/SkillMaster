-- tests/test_trainer_probe.lua — the offline trainer probe's checks (GitHub issue #3), driven on
-- small hand-made inputs: one case per error class the first report found (#2's four: a misspelled
-- name, a vendor stored as a trainer, a point in the Era frame, two NPCs on one point), plus the
-- book and quest roles, the SQL tuple reader and the provenance writer. No external source is read.
local T = _G.SKM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local HERE = "tools/trainer_probe"
local C = loadfile(HERE .. "/checks.lua")(HERE)
local CM = loadfile(HERE .. "/cmangos.lua")(HERE)
local R = loadfile(HERE .. "/report.lua")(HERE)
local IO = loadfile(HERE .. "/io.lua")(HERE)

-- A tiny source in the readers' shape (tools/trainer_probe/questiedb.lua Q.Read).
local function source()
    local npcs = {
        [1] = { id = 1, name = "Doctor Martin Felben", subName = "Journeyman Alchemist Trainer", flags = 19, faction = "H",
                spawns = { [1497] = { { 46.61, 74.09 } } }, questStarts = {} },
        [2] = { id = 2, name = "Gorina", subName = "Mining Supplier", flags = 4, faction = "H",
                spawns = { [1637] = { { 73.31, 26.6 } } }, questStarts = {} },
        [3] = { id = 3, name = "Woo Ping", subName = "Weapon Master", flags = 17, faction = "A",
                spawns = { [1519] = { { 63.88, 69.09 } } }, questStarts = {} },
        [4] = { id = 4, name = "Shandrina", subName = "Trade Goods", flags = 6, faction = "A",
                spawns = { [331] = { { 49.48, 67.09 } } }, questStarts = {} },
        [5] = { id = 5, name = "Nat Pagle", flags = 7, faction = "AH", spawns = { [15] = { { 58.61, 60.06 } } },
                questStarts = { 6607 } },
        [6] = { id = 6, name = "Annora", subName = "Master Enchanter", flags = 17, faction = "AH",
                spawns = { [1337] = { { -1, -1 } } }, questStarts = {} },
        [7] = { id = 7, name = "Wanderer", subName = "Mining Trainer", flags = 17, faction = "A",
                spawns = { [12] = { { 10, 10 }, { 60, 60 } } }, questStarts = {} },
    }
    local byName = {}
    for _, n in pairs(npcs) do byName[n.name] = { n } end
    return {
        npcs = npcs, byName = byName,
        areaToUiMap = { [1497] = 1458, [1637] = 1454, [1519] = 1453, [331] = 1440, [15] = 1445, [12] = 1429 },
        items = { [16072] = { name = "Expert Cookbook", vendors = { 4 } } },
    }
end

test("trainer probe: a misspelled name finds no NPC and names the near miss", function()
    local r = C.Name({ name = "Doctor Martin Felbin", faction = "Horde" }, source())
    assertTrue(not r.ok, "Felbin matched")
    assertTrue(r.msg:find("Doctor Martin Felben (1", 1, true) ~= nil, r.msg)
    local fixed = C.Name({ name = "Doctor Martin Felben", faction = "Horde" }, source())
    assertTrue(fixed.ok, "Felben")
    assertEqual(fixed.suggest.npcID, 1)
end)

test("trainer probe: a record's npcID must carry its name", function()
    local r = C.Name({ name = "Doctor Martin Felbin", faction = "Horde", npcID = 1 }, source())
    assertTrue(not r.ok)
    assertEqual(r.suggest.name, "Doctor Martin Felben")
end)

test("trainer probe: the side must serve the record's faction (Neutral wants both)", function()
    assertTrue(C.SideOK("Alliance", "A") and C.SideOK("Horde", "AH") and C.SideOK("Neutral", "AH"))
    assertTrue(not C.SideOK("Horde", "A") and not C.SideOK("Neutral", "H") and not C.SideOK("Alliance", nil))
    local r = C.Name({ name = "Woo Ping", faction = "Horde" }, source())
    assertTrue(not r.ok, "an Alliance NPC answered a Horde record")
end)

test("trainer probe: a vendor stored as a trainer fails the role check (Gorina)", function()
    local db = source()
    local r = C.Role({ name = "Gorina", teaches = { "mining" }, ranks = { 75, 150, 225, 300 } }, db.npcs[2], db)
    assertTrue(not r.ok, "Gorina passed")
    assertTrue(r.msg:find("no trainer flag", 1, true) ~= nil, r.msg)
end)

test("trainer probe: a title's rank must be the record's top rank", function()
    local db = source()
    local journeyman = { name = "Doctor Martin Felben", teaches = { "alchemy" }, ranks = { 75, 150 } }
    assertTrue(C.Role(journeyman, db.npcs[1], db).ok, "Journeyman trains to 150")
    local expert = { name = "Doctor Martin Felben", teaches = { "alchemy" }, ranks = { 75, 150, 225 } }
    assertTrue(not C.Role(expert, db.npcs[1], db).ok, "a Journeyman title passed as Expert")
    local wrongSkill = { name = "Doctor Martin Felben", teaches = { "tailoring" }, ranks = { 75, 150 } }
    assertTrue(not C.Role(wrongSkill, db.npcs[1], db).ok, "an alchemist passed as a tailor")
end)

test("trainer probe: a book vendor passes when it sells the book that trains the record's rank", function()
    local db = source()
    local rec = { name = "Shandrina", teaches = { "cooking" }, ranks = { 225 },
                  learn = { kind = "book", itemID = 16072, item = "Expert Cookbook" } }
    assertTrue(C.Role(rec, db.npcs[4], db).ok, "the cookbook vendor")
    local noLearn = { name = "Shandrina", teaches = { "cooking" }, ranks = { 225 } }
    assertTrue(not C.Role(noLearn, db.npcs[4], db).ok, "a vendor without a learn passed as a trainer")
    local wrongRank = { name = "Shandrina", teaches = { "cooking" }, ranks = { 300 }, learn = rec.learn }
    assertTrue(not C.Role(wrongRank, db.npcs[4], db).ok, "an Expert book passed as Artisan")
    local otherVendor = { name = "Gorina", teaches = { "cooking" }, ranks = { 225 }, learn = rec.learn }
    assertTrue(not C.Role(otherVendor, db.npcs[2], db).ok, "a vendor that does not sell the book passed")
end)

test("trainer probe: a rank quest's giver passes when it starts that quest", function()
    local db = source()
    local rec = { name = "Nat Pagle", teaches = { "fishing" }, ranks = { 300 },
                  learn = { kind = "quest", questID = 6607, quest = "Nat Pagle, Angler Extreme" } }
    assertTrue(C.Role(rec, db.npcs[5], db).ok)
    rec.learn.questID = 1
    assertTrue(not C.Role(rec, db.npcs[5], db).ok, "a quest the NPC does not start passed")
end)

test("trainer probe: a point in the Era frame fails the place check and the patch has Forever's (Woo Ping)", function()
    local db = source()
    local rec = { name = "Woo Ping", mapID = 1453, x = 57.1, y = 57.7 }
    local r = C.Place(rec, db.npcs[3], db)
    assertTrue(not r.ok, "57.1, 57.7 passed")
    assertEqual(r.suggest.x, 63.9)
    assertEqual(r.suggest.y, 69.1)
    rec.x, rec.y = 63.9, 69.1
    assertTrue(C.Place(rec, db.npcs[3], db).ok, "the corrected point")
    rec.mapID = 1455
    assertTrue(not C.Place(rec, db.npcs[3], db).ok, "the wrong uiMap passed")
end)

test("trainer probe: a record with no point gets the one standing point; spread spawns and instances give none", function()
    local db = source()
    local r = C.Place({ mapID = 1458 }, db.npcs[1], db)
    assertTrue(not r.ok and r.suggest.x == 46.6 and r.suggest.y == 74.1, r.msg)
    local inside = C.Place({ mapID = 1418 }, db.npcs[6], db)
    assertTrue(not inside.ok and inside.suggest == nil and inside.msg:find("instance", 1, true) ~= nil, inside.msg)
    local spread = C.Place({ mapID = 1429 }, db.npcs[7], db)
    assertTrue(not spread.ok and spread.suggest == nil, spread.msg)
end)

test("trainer probe: two NPCs on one point are both flagged (Bixi and Buliwyf)", function()
    local recs = {
        { id = "a", name = "Buliwyf Stonehand", mapID = 1455, x = 62.2, y = 89.6 },
        { id = "b", name = "Bixi Wobblebonk", mapID = 1455, x = 62.2, y = 89.6 },
        { id = "c", name = "Somebody", mapID = 1455, x = 61.2, y = 89.5 },
    }
    local d = C.Duplicates(recs)
    assertEqual(d.a[1], "b")
    assertEqual(d.b[1], "a")
    assertTrue(d.c == nil)
    recs[1].x, recs[1].y = 61.2, 89.5
    assertTrue(C.Duplicates(recs).b == nil, "a moved point still flagged")
end)

test("trainer probe: the SQL tuple reader keeps quotes, escapes, NULL and numbers", function()
    local rows = {}
    CM.Tuples([[INSERT INTO `t` VALUES (1,'It''s','a\'b',NULL,-2.5),(2,'x,y)','',0,3);]],
        function(row) rows[#rows + 1] = row end)
    assertEqual(#rows, 2)
    assertEqual(rows[1][2], "It's")
    assertEqual(rows[1][3], "a'b")
    assertTrue(rows[1][4] == nil)
    assertEqual(rows[1][5], -2.5)
    assertEqual(rows[2][2], "x,y)")
    assertEqual(rows[2][3], "")
    assertEqual(rows[2][5], 3)
end)

test("trainer probe: the sandbox gives a source no library", function()
    local ok, err = IO.sandbox("return io.open('x')", "t", {})
    assertTrue(not ok and tostring(err):find("io", 1, true) ~= nil, tostring(err))
    local ok2, v = IO.sandbox("return { 1, 2 }", "t", {})
    assertTrue(ok2 and v[2] == 2)
end)

test("trainer probe: the provenance file loads and holds each record's confirmation or reason", function()
    local run = { tag = "questiedb@0123456789ab", reportDir = "docs/trainer-probe/x", date = "2026-11-23",
                  sources = { { name = "QuestieDB", pin = "commit 0123" } }, results = {
        { id = "a", name = "Tel'Athir", npcID = 5500, mapID = 1453, x = 55.5, y = 85.7, confirmed = true },
        { id = "b", name = "Annora", confirmed = false, reason = "place: inside an instance" },
    } }
    local NS = {}
    local ok, err = IO.sandbox(R.Provenance(run), "prov", {}, "SkillMaster", NS)
    assertTrue(ok, tostring(err))
    assertEqual(NS.DataMeta.Trainers_Forever.verified, "questiedb@0123456789ab")
    assertEqual(NS.TrainerProvenance_Forever.confirmed.a.name, "Tel'Athir")
    assertEqual(NS.TrainerProvenance_Forever.confirmed.a.x, 55.5)
    assertEqual(NS.TrainerProvenance_Forever.unverified.b, "place: inside an instance")
end)

test("trainer probe: the JSON writer escapes and sorts", function()
    assertEqual(R.JSON({ b = 1, a = "x\"y" }), '{\n  "a": "x\\"y",\n  "b": 1\n}\n')
    assertEqual(R.JSON({ 1.5, true }), "[\n  1.5,\n  true\n]\n")
end)

test("trainer probe: the command line wants the QuestieDB path and reads the options", function()
    local Probe = loadfile("tools/trainer_probe.lua")()
    local o = Probe.Args({ "/q", "--cmangos", "/d.sql", "--date", "2026-11-23", "--write-provenance" })
    assertEqual(o.questiedb, "/q")
    assertEqual(o.cmangos, "/d.sql")
    assertTrue(o.provenance)
    assertTrue(not pcall(Probe.Args, {}), "no path accepted")
    assertTrue(not pcall(Probe.Args, { "/q", "--bogus" }), "an unknown flag accepted")
end)

test("trainer probe: an Artisan title trains to 225 and a Master title to 300 (round 2)", function()
    local db = source()
    local npc = { id = 9, name = "Telonis", subName = "Artisan Leatherworker", flags = 19, faction = "A", spawns = {} }
    assertTrue(C.Role({ teaches = { "leatherworking" }, ranks = { 75, 150, 225 } }, npc, db).ok, "Artisan title to 225")
    assertTrue(not C.Role({ teaches = { "leatherworking" }, ranks = { 75, 150, 225, 300 } }, npc, db).ok,
        "an Artisan-titled trainer passed as training Artisan")
    npc.subName = "Master Leatherworking Trainer"
    assertTrue(C.Role({ teaches = { "leatherworking" }, ranks = { 300 } }, npc, db).ok, "a Master trains Artisan")
end)

test("trainer probe: a Junior title trains Apprentice and a plain craft title Journeyman (round 2)", function()
    local db = source()
    local npc = { id = 9, name = "Kelsey Fargo", subName = "Junior Mining Trainer", flags = 20, faction = "A", spawns = {} }
    assertTrue(C.Role({ teaches = { "mining" }, ranks = { 75 } }, npc, db).ok, "Junior to 75")
    assertTrue(not C.Role({ teaches = { "mining" }, ranks = { 75, 150, 225, 300 } }, npc, db).ok, "a Junior passed as full")
    npc.subName = "Alchemist"
    assertTrue(C.Role({ teaches = { "alchemy" }, ranks = { 75, 150 } }, npc, db).ok, "a plain craft title to 150")
end)

test("trainer probe: a held record is never confirmed, and its reason is the hold", function()
    local Probe = loadfile("tools/trainer_probe.lua")()
    local db = source()
    db.coefficients, db.changedAreas = {}, {}
    local rec = { id = "woo", name = "Woo Ping", faction = "Alliance", mapID = 1453, x = 63.9, y = 69.1, npcID = 3,
                  teaches = { "swords" }, hold = "Forever-only, from QuestieDB spawn, not yet seen in game" }
    local run = Probe.Run({ rec }, { qdb = db, list = {} }, { date = "2026-11-23" })
    assertEqual(run.confirmed, 0)
    assertEqual(run.results[1].reason, rec.hold)
    rec.hold = nil
    assertEqual(Probe.Run({ rec }, { qdb = db, list = {} }, { date = "2026-11-23" }).confirmed, 1, "the same record unheld")
end)
