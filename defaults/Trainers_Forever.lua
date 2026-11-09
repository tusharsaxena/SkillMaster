local _, NS = ...
-- defaults/Trainers_Forever.lua — the trainer DB (design §8): every vanilla weapon master, the
-- profession trainers of each capital by rank, the out-of-city Expert and Artisan teachers, and one
-- riding trainer per race. Read by modules/Trainers.lua.
--
-- A record: { id, name, faction = "Alliance"|"Horde"|"Neutral", city, subzone, mapName, mapID, x, y,
-- cost (copper), teaches = { skill keys }, ranks = { caps it trains }|nil, race = <token>|nil,
-- costByKey, minLevelByKey, verified = false, source }.
--
-- Every record is unverified until the owner's smoke pass. Coordinates are given only where a
-- source printed them (the weapon masters); everywhere else x and y are nil and the waypoint falls
-- back to the subzone in chat, rather than a guessed pin. The names below are enUS: the trainer
-- popup prints them as the client's own NPC names would read on an enUS client.

local SRC_TOUR = "Blizzard WoW Classic City Tour: %s (worldofwarcraft.blizzard.com/en-us/news/%s)"
local SRC_WM = "warcrafttavern.com/wow-classic/guides/weapon-skill-trainers-and-locations; warcraft.wiki.gg/wiki/Weapon_master"
local SRC_RECALL = "vanilla 1.12 data (recalled, not cross-checked)"

-- Ranks a trainer trains, by the title the source printed. Journeyman <X> trains to 150, Expert
-- <X> to 225, Artisan <X> and the gathering "<X> Trainer" to 300, a secondary-skill trainer to 150.
local J, E, A = { 75, 150 }, { 75, 150, 225 }, { 75, 150, 225, 300 }
local G, S = A, J

local list = {}
NS.Trainers_Forever = list

local function slug(name)
    return (name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

local function add(rec)
    rec.id = rec.id or slug(rec.name)
    rec.verified = false
    list[#list + 1] = rec
end

-- One capital's profession trainers, from that city's tour. Rows: { name, subzone, key, ranks }.
local function city(c, rows)
    local source = SRC_TOUR:format(c.name, c.news)
    for _, r in ipairs(rows) do
        add{ name = r[1], faction = c.faction, city = c.name, subzone = r[2], mapName = c.name,
             mapID = c.mapID, teaches = { r[3] }, ranks = r[4], source = source }
    end
end

city({ name = "Stormwind", faction = "Alliance", mapID = 1453, news = "23149291" }, {
    { "Tel'Athir", "Mage Quarter", "alchemy", J },
    { "Lilyssia Nightbreeze", "Mage Quarter", "alchemy", E },
    { "Dane Lindgren", "Dwarven District", "blacksmithing", J },
    { "Therum Deepforge", "Dwarven District", "blacksmithing", E },
    { "Betty Quin", "Mage Quarter", "enchanting", J },
    { "Lucan Cordell", "Mage Quarter", "enchanting", E },
    { "Sprite Jumpsprocket", "Dwarven District", "engineering", J },
    { "Lilliam Sparkspindle", "Dwarven District", "engineering", E },
    { "Tannysa", "Mage Quarter", "herbalism", G },
    { "Shylamiir", "The Park", "herbalism", G },
    { "Randal Worth", "Old Town", "leatherworking", J },
    { "Simon Tanner", "Old Town", "leatherworking", E },
    { "Gelman Stonehand", "Dwarven District", "mining", G },
    { "Maris Granger", "Old Town", "skinning", G },
    { "Lawrence Schneider", "Mage Quarter", "tailoring", J },
    { "Sellandus", "Mage Quarter", "tailoring", E },
    { "Georgio Bolero", "Mage Quarter", "tailoring", A },
    { "Stephen Ryback", "Old Town", "cooking", S },
    { "Shaina Fuller", "Cathedral Square", "firstAid", S },
    { "Arnold Leland", "Trade District", "fishing", S },
})

city({ name = "Ironforge", faction = "Alliance", mapID = 1455, news = "23149294" }, {
    { "Vosur Brakthel", "Tinker Town", "alchemy", J },
    { "Tally Berryfizz", "Tinker Town", "alchemy", E },
    { "Groum Stonebeard", "The Great Forge", "blacksmithing", J },
    { "Rotgath Stonebeard", "The Great Forge", "blacksmithing", E },
    { "Bengus Deepforge", "The Great Forge", "blacksmithing", A },
    { "Thonys Pillarstone", "The Great Forge", "enchanting", J },
    { "Gimble Thistlefuzz", "The Great Forge", "enchanting", E },
    { "Jemma Quikswitch", "Tinker Town", "engineering", J },
    { "Trixie Quikswitch", "Tinker Town", "engineering", E },
    { "Springspindle Fizzlegear", "Tinker Town", "engineering", A },
    { "Reyna Stonebranch", "The Great Forge", "herbalism", G },
    { "Gretta Finespindle", "The Great Forge", "leatherworking", J },
    { "Fimble Finespindle", "The Great Forge", "leatherworking", E },
    { "Geofram Bouldertoe", "The Great Forge", "mining", G },
    { "Balthus Stoneflayer", "The Great Forge", "skinning", G },
    { "Uthrar Threx", "The Great Forge", "tailoring", J },
    { "Jormund Stonebrow", "The Great Forge", "tailoring", E },
    { "Daryl Riknussun", "The Great Forge", "cooking", S },
    { "Nissa Firestone", "The Great Forge", "firstAid", S },
    { "Grimnur Stonebrand", "The Forlorn Cavern", "fishing", S },
})

city({ name = "Darnassus", faction = "Alliance", mapID = 1457, news = "23149531" }, {
    { "Milla Fairancora", "Craftsmen's Terrace", "alchemy", J },
    { "Sylvanna Forestmoon", "Craftsmen's Terrace", "alchemy", E },
    { "Ainethil", "Craftsmen's Terrace", "alchemy", A },
    { "Lalina Summermoon", "Craftsmen's Terrace", "enchanting", J },
    { "Taladan", "Craftsmen's Terrace", "enchanting", E },
    { "Firodren Mooncaller", "The Temple Gardens", "herbalism", G },
    { "Darianna", "Craftsmen's Terrace", "leatherworking", J },
    { "Faldron", "Craftsmen's Terrace", "leatherworking", E },
    { "Telonis", "Craftsmen's Terrace", "leatherworking", A },
    { "Eladriel", "Craftsmen's Terrace", "skinning", G },
    { "Trianna", "Craftsmen's Terrace", "tailoring", J },
    { "Me'lynn", "Craftsmen's Terrace", "tailoring", E },
    { "Alegorn", "Craftsmen's Terrace", "cooking", S },
    { "Dannelor", "Craftsmen's Terrace", "firstAid", S },
})

city({ name = "Orgrimmar", faction = "Horde", mapID = 1454, news = "23156369" }, {
    { "Whuut", "The Drag", "alchemy", J },
    { "Yelmak", "The Drag", "alchemy", E },
    { "Ug'thok", "Valley of Honor", "blacksmithing", J },
    { "Snarl", "Valley of Honor", "blacksmithing", E },
    { "Saru Steelfury", "Valley of Honor", "blacksmithing", A },
    { "Jhag", "The Drag", "enchanting", J },
    { "Godan", "The Drag", "enchanting", E },
    { "Thund", "Valley of Honor", "engineering", J },
    { "Nogg", "Valley of Honor", "engineering", E },
    { "Roxxik", "Valley of Honor", "engineering", A },
    { "Jandi", "The Drag", "herbalism", G },
    { "Kamari", "The Drag", "leatherworking", J },
    { "Karolek", "The Drag", "leatherworking", E },
    { "Makaru", "Valley of Honor", "mining", G },
    { "Gorina", "Valley of Honor", "mining", G },
    { "Thuwd", "The Drag", "skinning", G },
    { "Snang", "The Drag", "tailoring", J },
    { "Magar", "The Drag", "tailoring", E },
    { "Zamja", "The Drag", "cooking", S },
    { "Arnok", "Valley of Spirits", "firstAid", S },
    { "Lumak", "Valley of Honor", "fishing", S },
})

city({ name = "Thunder Bluff", faction = "Horde", mapID = 1456, news = "23178672" }, {
    { "Kray", "Middle Rise", "alchemy", J },
    { "Bena Winterhoof", "Middle Rise", "alchemy", E },
    { "Thrag Stonehoof", "Lower Rise", "blacksmithing", J },
    { "Karn Stonehoof", "Lower Rise", "blacksmithing", E },
    { "Mot Dawnstrider", "Middle Rise", "enchanting", J },
    { "Teg Dawnstrider", "Middle Rise", "enchanting", E },
    { "Komin Winterhoof", "Middle Rise", "herbalism", G },
    { "Mak", "Middle Rise", "leatherworking", J },
    { "Tarn", "Middle Rise", "leatherworking", E },
    { "Una", "Middle Rise", "leatherworking", A },
    { "Brek Stonehoof", "Lower Rise", "mining", G },
    { "Mooranta", "Middle Rise", "skinning", G },
    { "Vhan", "Middle Rise", "tailoring", J },
    { "Tepa", "Middle Rise", "tailoring", E },
    { "Aska Mistrunner", "High Rise", "cooking", S },
    { "Pand Stonebinder", "Spirit Rise", "firstAid", S },
    { "Kah Mistrunner", "High Rise", "fishing", S },
})

city({ name = "Undercity", faction = "Horde", mapID = 1458, news = "23149528" }, {
    { "Doctor Martin Felbin", "The Apothecarium", "alchemy", J },
    { "Doctor Marsh", "The Apothecarium", "alchemy", E },
    { "Doctor Herbert Halsey", "The Apothecarium", "alchemy", A },
    { "Basil Frye", "The War Quarter", "blacksmithing", J },
    { "James Van Brunt", "The War Quarter", "blacksmithing", E },
    { "Malcomb Wynn", "The Apothecarium", "enchanting", J },
    { "Lavinia Crowe", "The Apothecarium", "enchanting", E },
    { "Graham Van Talen", "The Rogues' Quarter", "engineering", J },
    { "Franklin Lloyd", "The Rogues' Quarter", "engineering", E },
    { "Martha Alliestar", "The Apothecarium", "herbalism", G },
    { "Dan Golthas", "The Rogues' Quarter", "leatherworking", J },
    { "Brom Killian", "The War Quarter", "mining", G },
    { "Killian Hagey", "The Rogues' Quarter", "skinning", G },
    { "Victor Ward", "The Magic Quarter", "tailoring", J },
    { "Rhiannon Davis", "The Magic Quarter", "tailoring", E },
    { "Josef Gregorian", "The Magic Quarter", "tailoring", A },
    { "Eunice Burch", "The Trade Quarter", "cooking", S },
    { "Mary Edras", "The Rogues' Quarter", "firstAid", S },
    { "Armand Cromwell", "The Magic Quarter", "fishing", S },
})

-- The Expert and Artisan teachers outside the capitals (Expert Cooking, First Aid and Fishing are
-- books or quests sold or given by these NPCs). Rows: { name, faction, city, mapName, mapID, key, ranks }.
for _, r in ipairs({
    { "Brikk Keencraft", "Neutral", "Booty Bay", "Stranglethorn Vale", 1434, "blacksmithing", { 300 } },
    { "Annora", "Neutral", "Uldaman", "Badlands", 1418, "enchanting", { 300 } },
    { "Shandrina", "Alliance", "Ashenvale", "Ashenvale", 1440, "cooking", { 225 } },
    { "Wulan", "Horde", "Shadowprey Village", "Desolace", 1443, "cooking", { 225 } },
    { "Dirge Quikcleave", "Neutral", "Gadgetzan", "Tanaris", 1446, "cooking", { 300 } },
    { "Deneb Walker", "Alliance", "Stromgarde Keep", "Arathi Highlands", 1417, "firstAid", { 225 } },
    { "Balai Lok'Wein", "Horde", "Brackenwall Village", "Dustwallow Marsh", 1445, "firstAid", { 225 } },
    { "Doctor Gustaf VanHowzen", "Alliance", "Theramore Isle", "Dustwallow Marsh", 1445, "firstAid", { 300 } },
    { "Doctor Gregory Victor", "Horde", "Hammerfall", "Arathi Highlands", 1417, "firstAid", { 300 } },
    { "Old Man Heming", "Neutral", "Booty Bay", "Stranglethorn Vale", 1434, "fishing", { 225 } },
    { "Nat Pagle", "Neutral", "Dustwallow Marsh", "Dustwallow Marsh", 1445, "fishing", { 300 } },
}) do
    add{ name = r[1], faction = r[2], city = r[3], mapName = r[4], mapID = r[5], teaches = { r[6] },
         ranks = r[7], source = SRC_RECALL }
end

-- The weapon masters. Every skill costs 10s at level 1, Polearms 1g at level 20.
local POLEARMS_COST, POLEARMS_LEVEL = { polearms = 10000 }, { polearms = 20 }
for _, r in ipairs({
    { "Woo Ping", "Alliance", "Stormwind", "Trade District", 1453, 57.1, 57.7,
      { "swords", "twoHandedSwords", "crossbows", "daggers", "polearms", "staves" } },
    { "Buliwyf Stonehand", "Alliance", "Ironforge", "The Military Ward", 1455, 62.2, 89.6,
      { "axes", "twoHandedAxes", "maces", "twoHandedMaces", "fistWeapons", "guns" } },
    { "Bixi Wobblebonk", "Alliance", "Ironforge", "The Military Ward", 1455, 62.2, 89.6,
      { "crossbows", "daggers", "thrown" } },
    { "Ilyenia Moonfire", "Alliance", "Darnassus", "Warrior's Terrace", 1457, 57.6, 46.7,
      { "bows", "daggers", "fistWeapons", "staves", "thrown" } },
    { "Sayoc", "Horde", "Orgrimmar", "Valley of Honor", 1454, 81.5, 19.6,
      { "axes", "twoHandedAxes", "bows", "daggers", "fistWeapons", "staves", "thrown" } },
    { "Hanashi", "Horde", "Orgrimmar", "Valley of Honor", 1454, 81.5, 19.6,
      { "axes", "twoHandedAxes", "bows", "staves", "thrown" } },
    { "Ansekhwa", "Horde", "Thunder Bluff", "Lower Rise", 1456, 40.9, 62.7,
      { "maces", "twoHandedMaces", "guns", "staves" } },
    { "Archibald", "Horde", "Undercity", "The War Quarter", 1458, 57.3, 32.8,
      { "swords", "twoHandedSwords", "crossbows", "daggers", "polearms" } },
}) do
    local polearms = false
    for _, k in ipairs(r[8]) do polearms = polearms or k == "polearms" end
    add{ name = r[1], faction = r[2], city = r[3], subzone = r[4], mapName = r[3], mapID = r[5],
         x = r[6], y = r[7], cost = 1000, teaches = r[8], source = SRC_WM,
         costByKey = polearms and POLEARMS_COST or nil, minLevelByKey = polearms and POLEARMS_LEVEL or nil }
end

-- Riding: each race trains at its own instructor (another race's needs Exalted with that race).
-- Rows: { name, faction, race token, city, mapName, mapID }.
for _, r in ipairs({
    { "Randal Hunter", "Alliance", "Human", "Eastvale Logging Camp", "Elwynn Forest", 1429 },
    { "Ultham Ironhorn", "Alliance", "Dwarf", "Amberstill Ranch", "Dun Morogh", 1426 },
    { "Binjy Featherwhistle", "Alliance", "Gnome", "Steelgrill's Depot", "Dun Morogh", 1426 },
    { "Jartsam", "Alliance", "NightElf", "Darnassus", "Darnassus", 1457 },
    { "Kildar", "Horde", "Orc", "Orgrimmar", "Orgrimmar", 1454 },
    { "Xar'Ti", "Horde", "Troll", "Sen'jin Village", "Durotar", 1411 },
    { "Kar Stormsinger", "Horde", "Tauren", "Bloodhoof Village", "Mulgore", 1412 },
    { "Velma Warnam", "Horde", "Scourge", "Brill", "Tirisfal Glades", 1420 },
}) do
    add{ name = r[1], faction = r[2], race = r[3], city = r[4], mapName = r[5], mapID = r[6],
         cost = 900000, teaches = { "riding" }, ranks = { 75, 150 }, source = SRC_RECALL }
end
