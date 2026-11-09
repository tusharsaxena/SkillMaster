local _, NS = ...
-- modules/Helpers.lua — the gathering and fishing helpers (design §12 item 4): the highest
-- skinnable mob level, the nodes a Mining or Herbalism rank can gather, the fishing skill a zone
-- wants, the weapon-skill cap and the equipped weapons' skills. Tooltip lines on the Skinning,
-- Mining, Herbalism, Fishing and weapon rows, the rows' one-line hint, the broker and the detached
-- weapon block read these.
--
-- Published as NS.SkillHelpers: NS.Helpers is the LibKa0s-Options-1.0 instance
-- (settings/OptionsSetup.lua), assigned after this file loads, and would replace it.

NS.SkillHelpers = {}
local H = NS.SkillHelpers

local floor = math.floor

--- The highest mob level a Skinning rank can skin: rank / 5 from 100 up, rank / 10 + 10 below.
function H.SkinnableLevel(rank)
    rank = rank or 0
    if rank >= 100 then return floor(rank / 5) end
    return floor(rank / 10) + 10
end

--- A weapon skill's cap at `level`: five per level.
function H.WeaponCap(level)
    return 5 * (level or 0)
end

local byMap, byName
local function fishingIndex()
    if byMap then return byMap, byName end
    byMap, byName = {}, {}
    local data = NS.Fishing_Forever
    for _, z in ipairs(data and data.zones or {}) do
        local need = z[3] + data.getawayMargin
        byName[z[1]] = need
        byMap[z[2]] = need
    end
    return byMap, byName
end

--- The fishing skill that lands every cast in a zone, by uiMapID first and the (localized) zone
--- name second; nil for a zone the table lacks.
function H.FishingNeed(zoneName, mapID)
    local maps, names = fishingIndex()
    if mapID and maps[mapID] then return maps[mapID] end
    if zoneName then return names[zoneName] end
    return nil
end

--- FishingNeed for where the player stands: C_Map's map ID when it answers, else the zone text.
function H.FishingNeedHere()
    local mapID
    if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
        mapID = C_Map.GetBestMapForUnit("player")
    end
    local zone = type(GetZoneText) == "function" and GetZoneText() or nil
    return H.FishingNeed(zone, mapID)
end

--- What a Mining or Herbalism `rank` can gather and the next node up: { gatherable = { node... },
--- next = { name, need }|nil }, nodes ascending by need. Nil for any other key.
function H.Nodes(key, rank)
    local nodes = NS.Gathering_Forever and NS.Gathering_Forever[key]
    if not nodes then return nil end
    rank = rank or 0
    local out = { gatherable = {} }
    for _, node in ipairs(nodes) do
        if node.need <= rank then
            out.gatherable[#out.gatherable + 1] = node
        elseif not out.next then
            out.next = { name = node.name, need = node.need }
        end
    end
    return out
end

-- -----------------------------------------------------------------------------------------------
-- The equipped weapons (the broker's {equippedWeapon}, the detached weapon block's marker)
-- -----------------------------------------------------------------------------------------------

-- Enum.ItemWeaponSubclass -> skill key: an equipped weapon's class names its weapon skill.
local WEAPON_SUBCLASS = {
    [0] = "axes", [1] = "twoHandedAxes", [2] = "bows", [3] = "guns", [4] = "maces", [5] = "twoHandedMaces",
    [6] = "polearms", [7] = "swords", [8] = "twoHandedSwords", [10] = "staves", [13] = "fistWeapons",
    [15] = "daggers", [16] = "thrown", [18] = "crossbows", [19] = "wands",
}
local ITEM_CLASS_WEAPON = 2
local MAIN_HAND, OFF_HAND, RANGED = 16, 17, 18
H.WEAPON_SLOTS = { MAIN_HAND, OFF_HAND, RANGED }

local function itemInfoInstant()
    if type(GetItemInfoInstant) == "function" then return GetItemInfoInstant end
    local C = C_Item
    if type(C) == "table" and type(C.GetItemInfoInstant) == "function" then return C.GetItemInfoInstant end
    return nil
end

--- The weapon skill of the item in inventory `slot`: nil for an empty slot or a non-weapon, and
--- "unarmed" for an empty main hand.
function H.WeaponSkillInSlot(slot)
    local link = type(GetInventoryItemLink) == "function" and GetInventoryItemLink("player", slot) or nil
    if not link then return slot == MAIN_HAND and "unarmed" or nil end
    local info = itemInfoInstant()
    if not info then return nil end
    local ok, _, _, _, _, _, classID, subclassID = pcall(info, link)
    if not ok or classID ~= ITEM_CLASS_WEAPON then return nil end
    return WEAPON_SUBCLASS[subclassID]
end

--- The weapon skills the player has equipped (main hand, off hand, ranged): { [key] = true }.
function H.EquippedWeaponSkills()
    local out = {}
    for _, slot in ipairs(H.WEAPON_SLOTS) do
        local key = H.WeaponSkillInSlot(slot)
        if key then out[key] = true end
    end
    return out
end
