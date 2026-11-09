local _, NS = ...
-- defaults/Fishing_Forever.lua — each zone's fishing level (design §8). The skill that lands every
-- cast with no "your fish got away" is level + 95 (modules/Helpers.lua's FishingNeed), so a level of
-- -70 is 25 skill, -20 is 75, 55 is 150, 130 is 225, 205 is 300 and 330 is 425.
--
-- Unverified until the owner's smoke pass. Rows: { zone (enUS, localized through NS.L), uiMapID
-- (the Classic map IDs, used first when C_Map answers), level }.

local L = NS.L

NS.Fishing_Forever = {
    verified = false,
    source = "vanilla 1.12 data (zone fishing levels, recalled, not cross-checked)",
    getawayMargin = 95,
    zones = {
        { L["Elwynn Forest"], 1429, -70 }, { L["Dun Morogh"], 1426, -70 }, { L["Teldrassil"], 1438, -70 },
        { L["Durotar"], 1411, -70 }, { L["Mulgore"], 1412, -70 }, { L["Tirisfal Glades"], 1420, -70 },
        { L["Stormwind City"], 1453, -70 }, { L["Ironforge"], 1455, -70 }, { L["Darnassus"], 1457, -70 },
        { L["Orgrimmar"], 1454, -70 }, { L["Thunder Bluff"], 1456, -70 }, { L["Undercity"], 1458, -70 },
        { L["Westfall"], 1436, -20 }, { L["Loch Modan"], 1432, -20 }, { L["Darkshore"], 1439, -20 },
        { L["The Barrens"], 1413, -20 }, { L["Silverpine Forest"], 1421, -20 },
        { L["Redridge Mountains"], 1433, 55 }, { L["Duskwood"], 1431, 55 }, { L["Wetlands"], 1437, 55 },
        { L["Ashenvale"], 1440, 55 }, { L["Stonetalon Mountains"], 1442, 55 },
        { L["Hillsbrad Foothills"], 1424, 55 },
        { L["Stranglethorn Vale"], 1434, 130 }, { L["Arathi Highlands"], 1417, 130 },
        { L["Alterac Mountains"], 1416, 130 }, { L["Desolace"], 1443, 130 },
        { L["Dustwallow Marsh"], 1445, 130 }, { L["Swamp of Sorrows"], 1435, 130 },
        { L["Thousand Needles"], 1441, 130 },
        { L["Feralas"], 1444, 205 }, { L["Tanaris"], 1446, 205 }, { L["Azshara"], 1447, 205 },
        { L["The Hinterlands"], 1425, 205 }, { L["Western Plaguelands"], 1422, 205 },
        { L["Felwood"], 1448, 205 }, { L["Un'Goro Crater"], 1449, 205 }, { L["Moonglade"], 1450, 205 },
        { L["Eastern Plaguelands"], 1423, 330 }, { L["Winterspring"], 1452, 330 },
        { L["Silithus"], 1451, 330 }, { L["Deadwind Pass"], 1430, 330 },
        { L["Burning Steppes"], 1428, 330 },
    },
}
