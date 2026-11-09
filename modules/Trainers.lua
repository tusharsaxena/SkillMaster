local _, NS = ...
-- modules/Trainers.lua — "where do I learn X" and "where do I train X's next rank" for the player's
-- faction (design §5.2), over defaults/Trainers_Forever.lua and defaults/Ranks_Forever.lua.
--
-- Pure lookups: no events, no frames. Reads the player's faction, race and level only when the
-- caller passes none, so the display, the alerts and the tests drive it the same way.

NS.Trainers = {}
local Trainers = NS.Trainers

-- Each race's capital (UnitRace's second return): its trainers sort first.
local HOME_CITY = {
    Human = "Stormwind", Dwarf = "Ironforge", Gnome = "Ironforge", NightElf = "Darnassus",
    Orc = "Orgrimmar", Troll = "Orgrimmar", Tauren = "Thunder Bluff", Scourge = "Undercity",
}
local CAPITAL = {
    Stormwind = true, Ironforge = true, Darnassus = true,
    Orgrimmar = true, ["Thunder Bluff"] = true, Undercity = true,
}

local function playerFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    return (UnitFactionGroup("player"))
end

local function playerRace()
    if type(UnitRace) ~= "function" then return nil end
    local _, token = UnitRace("player")
    return token
end

local function playerLevel()
    if type(UnitLevel) ~= "function" then return 0 end
    return UnitLevel("player") or 0
end

local function contains(list, value)
    if not list then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function servesFaction(rec, faction)
    return faction == nil or rec.faction == "Neutral" or rec.faction == faction
end

-- A trainer with no rank list teaches the skill itself (a weapon master); one with a list trains
-- only the caps it names.
local function trainsCap(rec, cap)
    return cap == nil or rec.ranks == nil or contains(rec.ranks, cap)
end

-- 0: the race's own trainer or home city; 1: another capital; 2: anywhere else.
local function tier(rec, race)
    if rec.race then return rec.race == race and 0 or 2 end
    if race and rec.city == HOME_CITY[race] then return 0 end
    return CAPITAL[rec.city] and 1 or 2
end

local function sorted(found, race)
    local keyed = {}
    for i, rec in ipairs(found) do keyed[i] = { rec = rec, tier = tier(rec, race) } end
    table.sort(keyed, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.rec.city ~= b.rec.city then return a.rec.city < b.rec.city end
        return a.rec.name < b.rec.name
    end)
    local out = {}
    for i, k in ipairs(keyed) do out[i] = k.rec end
    return out
end

local function collect(key, faction, race, cap)
    local found = {}
    for _, rec in ipairs(NS.Trainers_Forever or {}) do
        if contains(rec.teaches, key) and servesFaction(rec, faction) and trainsCap(rec, cap) then
            found[#found + 1] = rec
        end
    end
    return sorted(found, race)
end

--- The trainers who teach skill `key` to `faction` (default: the player's), the home city of
--- `race` (a UnitRace token, default: the player's) first. Neutral trainers serve both factions.
--- An unknown key answers an empty list.
function Trainers:For(key, faction, race)
    return collect(key, faction or playerFaction(), race or playerRace())
end

local function ladderFor(key)
    local name = NS.RankLadderFor_Forever and NS.RankLadderFor_Forever[key]
    return name and NS.Ranks_Forever and NS.Ranks_Forever[name]
end

--- The rank above the skill's current cap `max`, or nil when there is none (top rank reached, or a
--- skill with no ranks: weapons, Lockpicking). Answers { rankName, cap, minLevel, minSkill, cost,
--- canTrain, trainers }, where canTrain says `level` and `rank` meet the rank's gates.
function Trainers:NextRank(key, rank, max, level, faction, race)
    local ladder = ladderFor(key)
    if not ladder then return nil end
    for _, step in ipairs(ladder) do
        if step.cap > (max or 0) then
            level = level or playerLevel()
            return {
                rankName = step.rankName, cap = step.cap, minLevel = step.minLevel,
                minSkill = step.minSkill, cost = step.cost,
                canTrain = level >= step.minLevel and (rank or 0) >= step.minSkill,
                trainers = collect(key, faction or playerFaction(), race or playerRace(), step.cap),
            }
        end
    end
    return nil
end
