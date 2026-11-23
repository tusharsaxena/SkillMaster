local _, NS = ...
-- defaults/Trainers_Forever.lua — the trainer DB (design §8): every vanilla weapon master, the
-- profession trainers of each capital by rank, the out-of-city Expert and Artisan teachers, and one
-- riding trainer per race. Read by modules/Trainers.lua.
--
-- A record: { id, name, npcID, faction = "Alliance"|"Horde"|"Neutral", city, subzone, mapName, mapID,
-- x, y, cost (copper), teaches = { skill keys }, ranks = { caps it trains }|nil, race = <token>|nil,
-- costByKey, minLevelByKey, learn = { kind = "book", itemID, item }|{ kind = "quest", questID,
-- quest }|nil, verified = <probe tag>|false, unverified = <reason>|nil, source }.
--
-- `learn` says the rank is not trained but learned from a book this NPC sells or a quest it gives
-- (GitHub issue #3, the owner's books comment); the popup, the chat directions and the row tooltip
-- say so.
--
-- Provenance (issue #3): the offline trainer probe (tools/trainer_probe.lua) checks every record
-- against QuestieDB's Forever NPC table and writes defaults/TrainerProvenance_Forever.lua. A record
-- it confirmed carries `verified` = the run's tag (NS.DataMeta.Trainers_Forever.verified); every
-- other record is `verified = false` with the probe's `unverified` reason, and the popup marks it.
-- Coordinates are given only where a source printed them: since the probe, QuestieDB's spawn (one
-- standing point, rounded to 0.1 map-%), which replaced the weapon masters' Era-frame points; a
-- record with no single point keeps x and y nil and the waypoint falls back to chat. npcID is the
-- creature id the probe matched. The names below are enUS: the trainer popup prints them as the
-- client's own NPC names would read on an enUS client.

local SRC_TOUR = "Blizzard WoW Classic City Tour: %s (worldofwarcraft.blizzard.com/en-us/news/%s)"
local SRC_WM = "warcrafttavern.com/wow-classic/guides/weapon-skill-trainers-and-locations; warcraft.wiki.gg/wiki/Weapon_master"
local SRC_RECALL = "vanilla 1.12 data (recalled, not cross-checked)"
local SRC_MASTER = "CMaNGOS classic-db 1.12 trainer rows (ItemTree's method); Method.gg WoW Forever guides; "
    .. "wow-professions.com/forever; games.gg WoW Forever professions guide (read 2026-11-23)"
local SRC_PROBE = "; npcID, name and coordinates: the trainer probe (NS.DataMeta.Trainers_Forever)"

-- How a rank is learned where no trainer trains it (QuestieDB data/Forever: the book's vendors and
-- the quest's starter; the CMaNGOS 1.12 dump agrees, docs/trainer-probe/2026-11-23-r2/report.md).
local EXPERT_COOKBOOK = { kind = "book", itemID = 16072, item = "Expert Cookbook" }
local EXPERT_FIRST_AID = { kind = "book", itemID = 16084, item = "Expert First Aid - Under Wraps" }
local EXPERT_FISHING = { kind = "book", itemID = 16083, item = "Expert Fishing - The Bass and You" }
local CLAMLETTE_SURPRISE = { kind = "quest", questID = 6610, quest = "Clamlette Surprise" }
local ANGLER_EXTREME = { kind = "quest", questID = 6607, quest = "Nat Pagle, Angler Extreme" }
local TRIAGE_ALLIANCE = { kind = "quest", questID = 6624, quest = "Triage" }
local TRIAGE_HORDE = { kind = "quest", questID = 6622, quest = "Triage" }

-- Ranks a trainer trains, by the title the source printed. Journeyman <X> trains to 150, Expert
-- <X> to 225, the gathering "<X> Trainer" to 300, a secondary-skill trainer to 150. A capital's
-- Artisan <X> trains to 225 too: Artisan in a craft is the Master trainers' outside the capitals
-- (round 2, the owner's report; the spec's research table, docs/superpowers/specs/
-- 2026-11-23-trainer-probe-design.md).
local J, E, A = { 75, 150 }, { 75, 150, 225 }, { 75, 150, 225, 300 }
local G, S = A, J

local list = {}
NS.Trainers_Forever = list

local function slug(name)
    return (name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

-- The probe's provenance (defaults/TrainerProvenance_Forever.lua, loaded first): the run's tag and
-- each record's confirmation or reason. A record it lists in neither is left without a reason, which
-- tests/test_trainers.lua refuses.
local PROV = NS.TrainerProvenance_Forever or { confirmed = {}, unverified = {} }
local META = NS.DataMeta and NS.DataMeta.Trainers_Forever

local function add(rec)
    rec.id = rec.id or slug(rec.name)
    rec.source = rec.source .. SRC_PROBE
    if PROV.confirmed[rec.id] and META and META.verified then
        rec.verified = META.verified
    else
        rec.verified, rec.unverified = false, PROV.unverified[rec.id]
    end
    list[#list + 1] = rec
end

-- One capital's profession trainers, from that city's tour. Rows: { name, subzone, key, ranks,
-- npcID, x, y }.
local function city(c, rows)
    local source = SRC_TOUR:format(c.name, c.news)
    for _, r in ipairs(rows) do
        add{ name = r[1], faction = c.faction, city = c.name, subzone = r[2], mapName = c.name,
             mapID = c.mapID, teaches = { r[3] }, ranks = r[4], npcID = r[5], x = r[6], y = r[7], source = source }
    end
end

city({ name = "Stormwind", faction = "Alliance", mapID = 1453, news = "23149291" }, {
    { "Tel'Athir", "Mage Quarter", "alchemy", J, 5500, 55.5, 85.7 },
    { "Lilyssia Nightbreeze", "Mage Quarter", "alchemy", E, 5499, 55.7, 86.1 },
    { "Dane Lindgren", "Dwarven District", "blacksmithing", J, 957, 64.1, 37.0 },
    { "Therum Deepforge", "Dwarven District", "blacksmithing", E, 5511, 63.7, 37.0 },
    { "Betty Quin", "Mage Quarter", "enchanting", J, 11068, 53.0, 73.7 },
    { "Lucan Cordell", "Mage Quarter", "enchanting", E, 1317, 52.9, 74.5 },
    { "Sprite Jumpsprocket", "Dwarven District", "engineering", J, 11026, 61.9, 30.6 },
    { "Lilliam Sparkspindle", "Dwarven District", "engineering", E, 5518, 62.1, 30.3 },
    { "Tannysa", "Mage Quarter", "herbalism", G, 5566, 54.3, 84.1 },
    { "Shylamiir", "The Park", "herbalism", G, 5502, 31.5, 62.6 },
    { "Randal Worth", "Old Town", "leatherworking", J, 11096, 72.1, 62.9 },
    { "Simon Tanner", "Old Town", "leatherworking", E, 5564, 71.7, 63.0 },
    { "Gelman Stonehand", "Dwarven District", "mining", G, 5513, 59.3, 37.8 },
    { "Maris Granger", "Old Town", "skinning", G, 1292, 72.1, 62.2 },
    { "Lawrence Schneider", "Mage Quarter", "tailoring", J, 1300, 53.5, 81.5 },
    { "Sellandus", "Mage Quarter", "tailoring", E, 5567, 52.2, 83.1 },
    { "Georgio Bolero", "Mage Quarter", "tailoring", E, 1346, 53.1, 81.4 },
    { "Stephen Ryback", "Old Town", "cooking", S, 5482, 78.2, 53.1 },
    { "Shaina Fuller", "Cathedral Square", "firstAid", S, 2327, 53.0, 44.7 },
    { "Arnold Leland", "Trade District", "fishing", S, 5493, 55.0, 69.7 },
})

city({ name = "Ironforge", faction = "Alliance", mapID = 1455, news = "23149294" }, {
    { "Vosur Brakthel", "Tinker Town", "alchemy", J, 1246, 66.3, 55.7 },
    { "Tally Berryfizz", "Tinker Town", "alchemy", E, 5177, 66.6, 55.7 },
    { "Groum Stonebeard", "The Great Forge", "blacksmithing", J, 10277, 52.3, 41.9 },
    { "Rotgath Stonebeard", "The Great Forge", "blacksmithing", E, 10276, 52.4, 42.6 },
    { "Bengus Deepforge", "The Great Forge", "blacksmithing", E, 4258, 52.6, 41.5 },
    { "Thonys Pillarstone", "The Great Forge", "enchanting", J, 11065, 60.3, 45.4 },
    { "Gimble Thistlefuzz", "The Great Forge", "enchanting", E, 5157, 59.8, 45.5 },
    { "Jemma Quikswitch", "Tinker Town", "engineering", J, 11028, 67.7, 44.2 },
    { "Trixie Quikswitch", "Tinker Town", "engineering", E, 11029, 67.5, 42.9 },
    { "Springspindle Fizzlegear", "Tinker Town", "engineering", E, 5174, 68.5, 43.5 },
    { "Reyna Stonebranch", "The Great Forge", "herbalism", G, 5137, 55.9, 59.1 },
    { "Gretta Finespindle", "The Great Forge", "leatherworking", J, 1466, 38.8, 32.9 },
    { "Fimble Finespindle", "The Great Forge", "leatherworking", E, 5127, 40.2, 33.7 },
    { "Geofram Bouldertoe", "The Great Forge", "mining", G, 4254, 50.0, 26.3 },
    { "Balthus Stoneflayer", "The Great Forge", "skinning", G, 6291, 39.9, 32.5 },
    { "Uthrar Threx", "The Great Forge", "tailoring", J, 1703, 43.8, 27.9 },
    { "Jormund Stonebrow", "The Great Forge", "tailoring", E, 5153, 43.2, 29.4 },
    { "Daryl Riknussun", "The Great Forge", "cooking", S, 5159, 60.1, 36.4 },
    { "Nissa Firestone", "The Great Forge", "firstAid", S, 5150, 55.1, 58.3 },
    { "Grimnur Stonebrand", "The Forlorn Cavern", "fishing", S, 5161, 48.1, 6.9 },
})

city({ name = "Darnassus", faction = "Alliance", mapID = 1457, news = "23149531" }, {
    { "Milla Fairancora", "Craftsmen's Terrace", "alchemy", J, 11041, 55.4, 22.7 },
    { "Sylvanna Forestmoon", "Craftsmen's Terrace", "alchemy", E, 11042, 56.4, 24.2 },
    { "Ainethil", "Craftsmen's Terrace", "alchemy", E, 4160, 54.9, 24.0 },
    { "Lalina Summermoon", "Craftsmen's Terrace", "enchanting", J, 11070, 58.8, 12.7 },
    { "Taladan", "Craftsmen's Terrace", "enchanting", E, 4213, 58.4, 13.1 },
    { "Firodren Mooncaller", "The Temple Gardens", "herbalism", G, 4204, 48.0, 68.0 },
    { "Darianna", "Craftsmen's Terrace", "leatherworking", J, 11083, 64.4, 20.9 },
    { "Faldron", "Craftsmen's Terrace", "leatherworking", E, 11081, 64.8, 21.8 },
    { "Telonis", "Craftsmen's Terrace", "leatherworking", E, 4212, 64.4, 21.5 },
    { "Eladriel", "Craftsmen's Terrace", "skinning", G, 6292, 64.1, 22.3 },
    { "Trianna", "Craftsmen's Terrace", "tailoring", J, 11050, 63.6, 21.2 },
    { "Me'lynn", "Craftsmen's Terrace", "tailoring", E, 4159, 63.4, 22.4 },
    { "Alegorn", "Craftsmen's Terrace", "cooking", S, 4210, 49.0, 21.2 },
    { "Dannelor", "Craftsmen's Terrace", "firstAid", S, 4211, 51.7, 12.2 },
})

city({ name = "Orgrimmar", faction = "Horde", mapID = 1454, news = "23156369" }, {
    { "Whuut", "The Drag", "alchemy", J, 11046, 55.8, 32.9 },
    { "Yelmak", "The Drag", "alchemy", E, 3347, 56.8, 33.0 },
    { "Ug'thok", "Valley of Honor", "blacksmithing", J, 10266, 80.8, 23.7 },
    { "Snarl", "Valley of Honor", "blacksmithing", E, 1383, 79.6, 23.3 },
    { "Saru Steelfury", "Valley of Honor", "blacksmithing", E, 3355, 82.4, 23.0 },
    { "Jhag", "The Drag", "enchanting", J, 11066, 53.5, 38.6 },
    { "Godan", "The Drag", "enchanting", E, 3345, 53.9, 38.7 },
    { "Thund", "Valley of Honor", "engineering", J, 2857, 76.0, 24.2 },
    { "Nogg", "Valley of Honor", "engineering", E, 3412, 76.0, 25.4 },
    { "Roxxik", "Valley of Honor", "engineering", E, 11017, 76.2, 25.2 },
    { "Jandi", "The Drag", "herbalism", G, 3404, 55.6, 39.5 },
    { "Kamari", "The Drag", "leatherworking", J, 5811, 63.3, 44.8 },
    { "Karolek", "The Drag", "leatherworking", E, 3365, 62.8, 44.2 },
    { "Makaru", "Valley of Honor", "mining", G, 3357, 73.1, 26.1 },
    { "Thuwd", "The Drag", "skinning", G, 7088, 63.4, 45.4 },
    { "Snang", "The Drag", "tailoring", J, 2855, 62.9, 49.2 },
    { "Magar", "The Drag", "tailoring", E, 3363, 63.7, 49.9 },
    { "Zamja", "The Drag", "cooking", S, 3399, 57.4, 54.0 },
    { "Arnok", "Valley of Spirits", "firstAid", S, 3373, 34.2, 84.6 },
    { "Lumak", "Valley of Honor", "fishing", S, 3332, 69.8, 29.2 },
})

city({ name = "Thunder Bluff", faction = "Horde", mapID = 1456, news = "23178672" }, {
    { "Kray", "Middle Rise", "alchemy", J, 11047, 46.7, 34.4 },
    { "Bena Winterhoof", "Middle Rise", "alchemy", E, 3009, 46.6, 33.2 },
    { "Thrag Stonehoof", "Lower Rise", "blacksmithing", J, 10278, 39.4, 56.7 },
    { "Karn Stonehoof", "Lower Rise", "blacksmithing", E, 2998, 39.4, 55.1 },
    { "Mot Dawnstrider", "Middle Rise", "enchanting", J, 11071, 44.6, 38.5 },
    { "Teg Dawnstrider", "Middle Rise", "enchanting", E, 3011, 44.9, 37.5 },
    { "Komin Winterhoof", "Middle Rise", "herbalism", G, 3013, 50.0, 40.4 },
    { "Mak", "Middle Rise", "leatherworking", J, 3008, 42.1, 43.5 },
    { "Tarn", "Middle Rise", "leatherworking", E, 11084, 42.3, 42.6 },
    { "Una", "Middle Rise", "leatherworking", E, 3007, 41.5, 42.6 },
    { "Brek Stonehoof", "Lower Rise", "mining", G, 3001, 34.4, 57.9 },
    { "Mooranta", "Middle Rise", "skinning", G, 7089, 44.4, 43.2 },
    { "Vhan", "Middle Rise", "tailoring", J, 11051, 44.3, 44.3 },
    { "Tepa", "Middle Rise", "tailoring", E, 3004, 44.5, 45.4 },
    { "Aska Mistrunner", "High Rise", "cooking", S, 3026, 50.7, 53.1 },
    { "Pand Stonebinder", "Spirit Rise", "firstAid", S, 2798, 29.7, 21.2 },
    { "Kah Mistrunner", "High Rise", "fishing", S, 3028, 56.1, 46.4 },
})

city({ name = "Undercity", faction = "Horde", mapID = 1458, news = "23149528" }, {
    { "Doctor Martin Felben", "The Apothecarium", "alchemy", J, 11044, 46.6, 74.1 },
    { "Doctor Marsh", "The Apothecarium", "alchemy", E, 4609, 50.9, 74.6 },
    { "Doctor Herbert Halsey", "The Apothecarium", "alchemy", E, 4611, 47.8, 73.3 },
    { "Basil Frye", "The War Quarter", "blacksmithing", J, 4605, 60.2, 29.1 },
    { "James Van Brunt", "The War Quarter", "blacksmithing", E, 4596, 61.3, 30.6 },
    { "Malcomb Wynn", "The Apothecarium", "enchanting", J, 11067, 62.5, 60.4 },
    { "Lavinia Crowe", "The Apothecarium", "enchanting", E, 4616, 62.5, 61.8 },
    { "Graham Van Talen", "The Rogues' Quarter", "engineering", J, 4586, 75.3, 73.1 },
    { "Franklin Lloyd", "The Rogues' Quarter", "engineering", E, 11031, 76.1, 74.0 },
    { "Martha Alliestar", "The Apothecarium", "herbalism", G, 4614, 54.0, 49.6 },
    { "Dan Golthas", "The Rogues' Quarter", "leatherworking", J, 223, 70.9, 58.4 },
    { "Brom Killian", "The War Quarter", "mining", G, 4598, 56.0, 37.5 },
    { "Killian Hagey", "The Rogues' Quarter", "skinning", G, 7087, 70.2, 59.2 },
    { "Victor Ward", "The Magic Quarter", "tailoring", J, 11048, 70.1, 29.8 },
    { "Rhiannon Davis", "The Magic Quarter", "tailoring", E, 11049, 70.0, 30.6 },
    { "Josef Gregorian", "The Magic Quarter", "tailoring", E, 4576, 70.8, 30.7 },
    { "Eunice Burch", "The Trade Quarter", "cooking", S, 4552, 62.1, 44.9 },
    { "Mary Edras", "The Rogues' Quarter", "firstAid", S, 4591, 73.2, 55.2 },
    { "Armand Cromwell", "The Magic Quarter", "fishing", S, 4573, 80.7, 31.3 },
})

-- The Expert and Artisan teachers outside the capitals. Expert Cooking, First Aid and Fishing are
-- books these NPCs sell, and Artisan Cooking, First Aid and Fishing quests they give (learn).
-- Rows: { name, faction, city, mapName, mapID, key, ranks, npcID, x, y, learn }.
for _, r in ipairs({
    { "Brikk Keencraft", "Neutral", "Booty Bay", "Stranglethorn Vale", 1434, "blacksmithing", { 300 }, 2836, 29.0, 75.6 },
    { "Annora", "Neutral", "Uldaman", "Badlands", 1418, "enchanting", { 300 }, 11073, nil, nil },
    { "Shandrina", "Alliance", "Ashenvale", "Ashenvale", 1440, "cooking", { 225 }, 3955, 49.5, 67.1, EXPERT_COOKBOOK },
    { "Wulan", "Horde", "Shadowprey Village", "Desolace", 1443, "cooking", { 225 }, 12033, 26.2, 69.7, EXPERT_COOKBOOK },
    { "Dirge Quikcleave", "Neutral", "Gadgetzan", "Tanaris", 1446, "cooking", { 300 }, 8125, 52.6, 28.1, CLAMLETTE_SURPRISE },
    { "Deneb Walker", "Alliance", "Stromgarde Keep", "Arathi Highlands", 1417, "firstAid", { 225 }, 2805, 27.0, 58.8, EXPERT_FIRST_AID },
    { "Balai Lok'Wein", "Horde", "Brackenwall Village", "Dustwallow Marsh", 1445, "firstAid", { 225 }, 13476, 36.5, 30.4, EXPERT_FIRST_AID },
    { "Doctor Gustaf VanHowzen", "Alliance", "Theramore Isle", "Dustwallow Marsh", 1445, "firstAid", { 300 }, 12939, 67.8, 49.0, TRIAGE_ALLIANCE },
    { "Doctor Gregory Victor", "Horde", "Hammerfall", "Arathi Highlands", 1417, "firstAid", { 300 }, 12920, 73.4, 36.9, TRIAGE_HORDE },
    { "Old Man Heming", "Neutral", "Booty Bay", "Stranglethorn Vale", 1434, "fishing", { 225 }, 2626, 27.4, 77.2, EXPERT_FISHING },
    { "Nat Pagle", "Neutral", "Dustwallow Marsh", "Dustwallow Marsh", 1445, "fishing", { 300 }, 12919, 58.6, 60.1, ANGLER_EXTREME },
}) do
    add{ name = r[1], faction = r[2], city = r[3], mapName = r[4], mapID = r[5], teaches = { r[6] },
         ranks = r[7], npcID = r[8], x = r[9], y = r[10], learn = r[11], source = SRC_RECALL }
end

-- The Master trainers who train a craft to Artisan (round 2): one per side, or one for both (Brikk
-- Keencraft and Annora, above). Rows as above, without `learn`.
for _, r in ipairs({
    { "Kylanna Windwhisper", "Alliance", "Feathermoon Stronghold", "Feralas", 1444, "alchemy", { 300 }, 7948, 32.6, 43.8 },
    { "Rogvar", "Horde", "Stonard", "Swamp of Sorrows", 1435, "alchemy", { 300 }, 1386, 48.5, 55.9 },
    { "Buzzek Bracketswing", "Neutral", "Gadgetzan", "Tanaris", 1446, "engineering", { 300 }, 8736, 52.3, 27.7 },
    { "Drakk Stonehand", "Alliance", "Aerie Peak", "The Hinterlands", 1425, "leatherworking", { 300 }, 11097, 13.4, 43.5 },
    { "Hahrana Ironhide", "Horde", "Camp Mojache", "Feralas", 1444, "leatherworking", { 300 }, 11098, 74.4, 43.1 },
    { "Timothy Worthington", "Alliance", "Theramore Isle", "Dustwallow Marsh", 1445, "tailoring", { 300 }, 11052, 66.2, 51.8 },
    { "Daryl Stack", "Horde", "Tarren Mill", "Hillsbrad Foothills", 1424, "tailoring", { 300 }, 2399, 63.8, 20.8 },
}) do
    add{ name = r[1], faction = r[2], city = r[3], mapName = r[4], mapID = r[5], teaches = { r[6] },
         ranks = r[7], npcID = r[8], x = r[9], y = r[10], source = SRC_MASTER }
end

-- The weapon masters. Every skill costs 10s at level 1, Polearms 1g at level 20.
-- Rows: { name, faction, city, subzone, mapID, x, y, npcID, teaches }.
local POLEARMS_COST, POLEARMS_LEVEL = { polearms = 10000 }, { polearms = 20 }
for _, r in ipairs({
    { "Woo Ping", "Alliance", "Stormwind", "Trade District", 1453, 63.9, 69.1, 11867,
      { "swords", "twoHandedSwords", "crossbows", "daggers", "polearms", "staves" } },
    { "Buliwyf Stonehand", "Alliance", "Ironforge", "The Military Ward", 1455, 61.2, 89.5, 11865,
      { "axes", "twoHandedAxes", "maces", "twoHandedMaces", "fistWeapons", "guns" } },
    { "Bixi Wobblebonk", "Alliance", "Ironforge", "The Military Ward", 1455, 62.2, 89.6, 13084,
      { "crossbows", "daggers", "thrown" } },
    { "Ilyenia Moonfire", "Alliance", "Darnassus", "Warrior's Terrace", 1457, 57.6, 46.7, 11866,
      { "bows", "daggers", "fistWeapons", "staves", "thrown" } },
    { "Sayoc", "Horde", "Orgrimmar", "Valley of Honor", 1454, 81.7, 19.6, 11868,
      { "axes", "twoHandedAxes", "bows", "daggers", "fistWeapons", "staves", "thrown" } },
    { "Hanashi", "Horde", "Orgrimmar", "Valley of Honor", 1454, 81.5, 19.6, 2704,
      { "axes", "twoHandedAxes", "bows", "staves", "thrown" } },
    { "Ansekhwa", "Horde", "Thunder Bluff", "Lower Rise", 1456, 40.9, 62.7, 11869,
      { "maces", "twoHandedMaces", "guns", "staves" } },
    { "Archibald", "Horde", "Undercity", "The War Quarter", 1458, 57.3, 32.8, 11870,
      { "swords", "twoHandedSwords", "crossbows", "daggers", "polearms" } },
}) do
    local polearms = false
    for _, k in ipairs(r[9]) do polearms = polearms or k == "polearms" end
    add{ name = r[1], faction = r[2], city = r[3], subzone = r[4], mapName = r[3], mapID = r[5],
         x = r[6], y = r[7], npcID = r[8], cost = 1000, teaches = r[9], source = SRC_WM,
         costByKey = polearms and POLEARMS_COST or nil, minLevelByKey = polearms and POLEARMS_LEVEL or nil }
end

-- Riding: each race trains at its own instructor (another race's needs Exalted with that race).
-- Rows: { name, faction, race token, city, mapName, mapID, npcID, x, y }.
for _, r in ipairs({
    { "Randal Hunter", "Alliance", "Human", "Eastvale Logging Camp", "Elwynn Forest", 1429, 4732, 84.3, 64.9 },
    { "Ultham Ironhorn", "Alliance", "Dwarf", "Amberstill Ranch", "Dun Morogh", 1426, 4772, 63.9, 50.1 },
    { "Binjy Featherwhistle", "Alliance", "Gnome", "Steelgrill's Depot", "Dun Morogh", 1426, 7954, 49.2, 48.1 },
    { "Jartsam", "Alliance", "NightElf", "Darnassus", "Darnassus", 1457, 4753, 38.7, 15.8 },
    { "Kildar", "Horde", "Orc", "Orgrimmar", "Orgrimmar", 1454, 4752, 69.4, 13.1 },
    { "Xar'Ti", "Horde", "Troll", "Sen'jin Village", "Durotar", 1411, 7953, 55.3, 75.5 },
    { "Kar Stormsinger", "Horde", "Tauren", "Bloodhoof Village", "Mulgore", 1412, 3690, 46.8, 62.0 },
    { "Velma Warnam", "Horde", "Scourge", "Brill", "Tirisfal Glades", 1420, 4773, 60.1, 52.6 },
}) do
    add{ name = r[1], faction = r[2], race = r[3], city = r[4], mapName = r[5], mapID = r[6],
         npcID = r[7], x = r[8], y = r[9], cost = 900000, teaches = { "riding" }, ranks = { 75, 150 }, source = SRC_RECALL }
end

-- The Forever-only trainers (round 2; the owner, 2026-11-23: "Go ahead and ship these 55 forever only
-- trainers"): NPCs QuestieDB's Forever table holds and the CMaNGOS 1.12 dump does not, so nothing
-- but QuestieDB places them. Each is unverified (`hold`: the probe never confirms one) until seen in
-- game. npcID, name, title, side and spawn are QuestieDB's, the spawn rounded to 0.1. The side on
-- Zephras Isle (2521) and in Riverglades (2548) is Neutral, the owner's ruling (2026-11-23: "new
-- zones are reachable by both alliance and horde"). Ranks from the title: Junior = Apprentice, a
-- Journeyman or Expert title its rank, a plain gathering or secondary title as the capitals' (to 300,
-- to 150), a plain craft title Journeyman (an untitled village trainer's reach in the 1.12 dump),
-- Expert for Alard Schmied and Vanessa Sellers (Method.gg's Forever guides). Melbin Powderfuse,
-- "Master Goblin Engineer", trains the Goblin specialization, which the data does not model: he is
-- read as a plain Engineering trainer (Journeyman), not an Artisan one. Norzsh, "Weaponsmith", is
-- read as a Blacksmithing trainer (Journeyman). Rows: { name, faction, mapName, mapID, key, ranks,
-- npcID, x, y } (city = the zone: QuestieDB names no subzone).
local FOREVER_ONLY = "Forever-only, from QuestieDB spawn, not yet seen in game"
local SRC_FOREVER = "QuestieDB data/Forever (NS.DataMeta.Trainers_Forever); Zephras Isle and Riverglades sides: "
    .. "the owner, 2026-11-23"
local JR = { 75 }
for _, r in ipairs({
    { "Alard Schmied", "Alliance", "Alterac Mountains", 1416, "blacksmithing", E, 28694, 19.8, 63.4 },   -- Blacksmith
    { "Linzy Blackbolt", "Alliance", "Alterac Mountains", 1416, "alchemy", J, 246795, 18.5, 62.4 },   -- Alchemist
    { "Nancy Songflower", "Alliance", "Elwynn Forest", 1429, "herbalism", JR, 247223, 52.4, 43.9 },   -- Junior Herbalism Trainer
    { "Kelsey Fargo", "Alliance", "Elwynn Forest", 1429, "mining", JR, 247226, 47.2, 32.2 },   -- Junior Mining Trainer
    { "Riley Peltskinner", "Alliance", "Elwynn Forest", 1429, "skinning", JR, 247227, 47.0, 39.9 },   -- Junior Skinning Trainer
    { "Zerril Softbreeze", "Neutral", "Zephras Isle", 2521, "cooking", S, 251905, 43.9, 43.8 },   -- Cook
    { "Aedi Thriceforged", "Neutral", "Zephras Isle", 2521, "mining", G, 251913, 44.9, 44.4 },   -- Miner
    { "Charles Worth", "Alliance", "Alterac Mountains", 1416, "tailoring", E, 251972, 17.7, 60.3 },   -- Expert Tailor
    { "Angelique Butler", "Neutral", "Alterac Mountains", 1416, "firstAid", S, 251977, 17.2, 61.1 },   -- First Aid Trainer
    { "Vanessa Sellers", "Alliance", "Alterac Mountains", 1416, "enchanting", E, 251978, 16.8, 62.3 },   -- Enchanting Trainer
    { "Fenn Fairweather", "Neutral", "Zephras Isle", 2521, "fishing", S, 251992, 45.0, 48.4 },   -- Fisherman
    { "Indari Sunseam", "Neutral", "Zephras Isle", 2521, "leatherworking", J, 251993, 44.7, 44.5 },   -- Leatherworker
    { "Katherine Lee", "Alliance", "Alterac Mountains", 1416, "cooking", S, 252084, 12.6, 65.8 },   -- Cooking Trainer
    { "Emerii Tallgust", "Neutral", "Zephras Isle", 2521, "leatherworking", J, 252376, 63.7, 80.7 },   -- Leatherworker
    { "Othesia Evengale", "Neutral", "Zephras Isle", 2521, "tailoring", J, 252380, 64.4, 81.2 },   -- Tailor
    { "Halavuul Cragwind", "Neutral", "Zephras Isle", 2521, "mining", G, 252388, 65.4, 80.5 },   -- Mining Trainer
    { "Daeann Steelwind", "Neutral", "Zephras Isle", 2521, "blacksmithing", J, 252479, 65.5, 80.3 },   -- Blacksmith
    { "Iaadaria Bitterwind", "Neutral", "Zephras Isle", 2521, "alchemy", J, 253004, 66.3, 79.5 },   -- Alchemist
    { "Miriaan Mistblade", "Neutral", "Zephras Isle", 2521, "skinning", G, 254087, 43.2, 43.3 },   -- Skinner
    { "Syriel Nightrain", "Neutral", "Zephras Isle", 2521, "herbalism", G, 254345, 57.9, 75.5 },   -- Herbalist
    { "Hunter Moore", "Alliance", "Hillsbrad Foothills", 1424, "fishing", S, 255877, 54.2, 80.3 },   -- Fisherman
    { "Grungle", "Neutral", "Riverglades", 2548, "mining", G, 255891, 77.7, 51.9 },   -- Miner
    { "Gorg", "Neutral", "Riverglades", 2548, "cooking", S, 256655, 58.7, 44.6 },   -- Cook
    { "Gur'dok", "Neutral", "Riverglades", 2548, "blacksmithing", J, 256658, 60.0, 46.3 },   -- Journeyman Blacksmith
    { "Ishlee Breezewhisper", "Neutral", "Zephras Isle", 2521, "skinning", G, 257003, 59.6, 76.1 },   -- Skinner
    { "Eaysaa Brightgust", "Neutral", "Zephras Isle", 2521, "alchemy", J, 257004, 59.2, 76.4 },   -- Alchemist
    { "Nyalah Brightfire", "Neutral", "Zephras Isle", 2521, "cooking", S, 257006, 60.6, 72.7 },   -- Cook
    { "Nyassa Swiftdraught", "Neutral", "Zephras Isle", 2521, "alchemy", J, 257019, 43.7, 43.4 },   -- Alchemist
    { "Nasalanna Windsinger", "Neutral", "Zephras Isle", 2521, "skinning", G, 257020, 43.2, 43.2 },   -- Skinner
    { "Halassa Fernbreeze", "Neutral", "Zephras Isle", 2521, "herbalism", G, 257021, 43.0, 43.5 },   -- Herbalist
    { "Messana Crestwind", "Neutral", "Zephras Isle", 2521, "leatherworking", J, 257022, 44.8, 44.6 },   -- Leatherworker
    { "Mendalass Tattermend", "Neutral", "Zephras Isle", 2521, "skinning", G, 257024, 43.3, 43.4 },   -- Skinner
    { "Alphonse Dumas", "Neutral", "Riverglades", 2548, "blacksmithing", J, 259250, 64.5, 82.0 },   -- Journeyman Blacksmith
    { "Krix", "Neutral", "Riverglades", 2548, "fishing", S, 260558, 79.3, 54.8 },   -- Superior Fisherman
    { "Melbin Powderfuse", "Neutral", "Riverglades", 2548, "engineering", J, 260562, 77.8, 50.9 },   -- Master Goblin Engineer
    { "William Pickman", "Horde", "Tirisfal Glades", 1420, "cooking", S, 265944, 61.8, 51.4 },   -- Cooking Trainer
    { "Pa'zula", "Horde", "Durotar", 1411, "enchanting", J, 266881, 56.7, 73.7 },   -- Journeyman Enchanter
    { "Margaret Weaver", "Horde", "Tirisfal Glades", 1420, "skinning", JR, 267324, 32.6, 65.8 },   -- Junior Skinning Trainer
    { "Walter Mason", "Horde", "Tirisfal Glades", 1420, "mining", JR, 267325, 32.2, 65.8 },   -- Junior Mining Trainer
    { "Florence Nightshade", "Horde", "Tirisfal Glades", 1420, "herbalism", JR, 267326, 32.5, 65.1 },   -- Junior Herbalism Trainer
    { "Norzsh", "Horde", "Durotar", 1411, "blacksmithing", J, 267328, 40.5, 68.1 },   -- Weaponsmith
    { "Nawka Wildsong", "Horde", "Mulgore", 1412, "skinning", JR, 267330, 44.5, 76.7 },   -- Junior Skinning Trainer
    { "Vartha Rockmane", "Horde", "Mulgore", 1412, "mining", JR, 267331, 44.3, 78.4 },   -- Junior Mining Trainer
    { "Garan Sunstrider", "Horde", "Mulgore", 1412, "herbalism", JR, 267332, 44.1, 78.0 },   -- Junior Herbalism Trainer
    { "Terunne Bearshaper", "Alliance", "Teldrassil", 1438, "skinning", JR, 267333, 59.4, 38.6 },   -- Junior Skinning Trainer
    { "Fanorran Stilloak", "Alliance", "Teldrassil", 1438, "mining", JR, 267334, 58.2, 41.4 },   -- Junior Mining Trainer
    { "Eleyna Duskbreeze", "Alliance", "Teldrassil", 1438, "herbalism", JR, 267335, 59.9, 41.3 },   -- Junior Herbalism Trainer
    { "Brighid Stormflayer", "Alliance", "Dun Morogh", 1426, "skinning", JR, 267336, 29.2, 67.7 },   -- Junior Skinning Trainer
    { "Sally Swiftwrench", "Alliance", "Dun Morogh", 1426, "mining", JR, 267337, 28.9, 67.7 },   -- Junior Mining Trainer
    { "Emrys Flintbeard", "Alliance", "Dun Morogh", 1426, "herbalism", JR, 267338, 29.0, 66.6 },   -- Junior Herbalism Trainer
    { "Edward Egan", "Alliance", "Alterac Mountains", 1416, "herbalism", G, 275321, 18.4, 63.2 },   -- Herbalist
    { "Patricia Egan", "Alliance", "Alterac Mountains", 1416, "alchemy", J, 275322, 18.5, 62.4 },   -- Alchemist
    { "Angus Hammerhand", "Horde", "Tirisfal Glades", 1420, "blacksmithing", J, 276067, 21.2, 45.7 },   -- Blacksmith
}) do
    add{ name = r[1], faction = r[2], city = r[3], mapName = r[3], mapID = r[4], teaches = { r[5] },
         ranks = r[6], npcID = r[7], x = r[8], y = r[9], hold = FOREVER_ONLY, source = SRC_FOREVER }
end
-- Forever's riding instructors: Shari Stilwell (Undead Horse Riding Instructor, Tirisfal Glades, beside
-- Velma Warnam's spot) and Genn Fairweather (Stablemaster and Riding Trainer, Zephras Isle, both sides,
-- Apprentice riding per Method.gg's Forever guide; no race: QuestieDB names none).
add{ name = "Shari Stilwell", faction = "Horde", race = "Scourge", city = "Tirisfal Glades", mapName = "Tirisfal Glades",
     mapID = 1420, npcID = 246152, x = 60.2, y = 52.7, cost = 900000, teaches = { "riding" }, ranks = { 75, 150 },
     hold = FOREVER_ONLY, source = SRC_FOREVER }
add{ name = "Genn Fairweather", faction = "Neutral", city = "Zephras Isle", mapName = "Zephras Isle", mapID = 2521,
     npcID = 265756, x = 53.8, y = 81.3, cost = 900000, teaches = { "riding" }, ranks = { 75 },
     hold = FOREVER_ONLY, source = SRC_FOREVER }
