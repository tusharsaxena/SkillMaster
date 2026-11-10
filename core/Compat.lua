local _, NS = ...
-- core/Compat.lua — NS.Compat, the compat family's root and only file (compat): every
-- version-variant client call the addon makes. No other family file exists.
--
-- Hand-written shims (no LibKa0s-Compat-1.0 member covers them):
--   Compat.NumSkillLines()                 the visible skill-line count, 0 without an API
--   Compat.SkillLineInfo(i)                ONE normalized record for line i, or nil
--   Compat.SetSkillHeaderExpanded(i, open) expand / collapse header i; true when a call ran
--   Compat.PlayerLevel()                   the player's level (0 without the API)
--   Compat.PlayerClass() / PlayerRace()    UnitClass / UnitRace for the player: localized, file
--   Compat.WeaponEnchantInfo()             the weapon temp-enchant returns (C_Item first)
--   Compat.InventoryTooltipData(slot)      C_TooltipInfo.GetInventoryItem's data, and whether it ran
--   Compat.UnitSpeed(unit)                 GetUnitSpeed's returns (current, run, flight, swim)
--   Compat.SpellName(spellID)              the spell's localized name (C_Spell first), or nil
-- The last six (T5.2) exist so the simulator's seam (core/SimSetup.lua, LibKa0s-Sim-1.0) can answer
-- every client read a simulated character needs (preview-mode, H1): a module reads them as
-- `NS.Compat.Member(...)` at call time and never captures one in a local.
-- The skill list (T2.1): the kit's Forever API set lists it as C_SkillInfo.* and not as the 1.12
-- globals, so C_SkillInfo is read first and the 1.12 globals second, until `/skm probe` settles
-- which the client carries (docs/midnight-quirks.md, the assumed-API table). The bare
-- GetSkillLineInfo rung stays because the Forever set is best-effort, not measured.
--
-- modules/Probe.lua reads the same APIs raw on purpose: its job is the unnormalized return.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- ---------------------------------------------------------------------------------------------
-- T2.1: the skill list
-- ---------------------------------------------------------------------------------------------

--- The skill-list API this client has: C_SkillInfo first, then the 1.12 globals; nil for neither.
local function skillApi()
    local ns = C_SkillInfo
    if type(ns) == "table" and type(ns.GetSkillLineInfo) == "function" then
        return ns.GetNumSkillLines, ns.GetSkillLineInfo, ns.ExpandSkillHeader, ns.CollapseSkillHeader
    end
    if type(GetSkillLineInfo) == "function" then
        return GetNumSkillLines, GetSkillLineInfo, ExpandSkillHeader, CollapseSkillHeader
    end
    return nil
end

--- The modern struct (skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier,
--- skillMaxRank, ...) as the one record shape.
local function fromStruct(t)
    return {
        name       = t.skillName or t.name,
        isHeader   = t.isHeader and true or false,
        isExpanded = t.isExpanded and true or false,
        rank       = t.skillRank or 0,
        tempPoints = t.numTempPoints or 0,
        modifier   = t.skillModifier or 0,
        max        = t.skillMaxRank or 0,
        -- The struct's ID, under whichever name the client uses (assumed until `/skm probe`).
        skillLineID = tonumber(t.skillLineID or t.skillID),
    }
end

--- The 1.12 positional list (name, isHeader, isExpanded, rank, tempPoints, modifier, maxRank, ...)
--- as the one record shape. 1.12 answers 1 / nil for its flags; both read as booleans here.
local function fromList(name, isHeader, isExpanded, rank, tempPoints, modifier, max)
    if name == nil then return nil end
    return {
        name       = name,
        isHeader   = isHeader and true or false,
        isExpanded = isExpanded and true or false,
        rank       = rank or 0,
        tempPoints = tempPoints or 0,
        modifier   = modifier or 0,
        max        = max or 0,
    }
end

--- @return number the visible line count, headers included, collapsed children excluded
function Compat.NumSkillLines()
    local count = skillApi()
    if type(count) ~= "function" then return 0 end
    return tonumber(count()) or 0
end

--- @return table|nil { name, isHeader, isExpanded, rank, tempPoints, modifier, max }, whichever
--- shape the client answered; nil past the end or without an API
function Compat.SkillLineInfo(i)
    local _, info = skillApi()
    if not info then return nil end
    local first, isHeader, isExpanded, rank, tempPoints, modifier, max = info(i)
    if type(first) == "table" then return fromStruct(first) end
    return fromList(first, isHeader, isExpanded, rank, tempPoints, modifier, max)
end

--- Expand (open = true) or collapse header i. The children below shift the indices.
--- @return boolean true when the client was asked
function Compat.SetSkillHeaderExpanded(i, open)
    local _, _, expand, collapse = skillApi()
    local fn = open and expand or collapse
    if type(fn) ~= "function" then return false end
    fn(i)
    return true
end

-- ---------------------------------------------------------------------------------------------
-- T5.2: the player and the reads the simulator answers (preview-mode, H1)
-- ---------------------------------------------------------------------------------------------

--- @return number the player's level, 0 without the API
function Compat.PlayerLevel()
    if type(UnitLevel) ~= "function" then return 0 end
    return tonumber(UnitLevel("player")) or 0
end

--- @return string|nil, string|nil the localized class name and the class file ("HUNTER")
function Compat.PlayerClass()
    if type(UnitClass) ~= "function" then return nil, nil end
    return UnitClass("player")
end

--- @return string|nil, string|nil the localized race name and the race file ("Dwarf")
function Compat.PlayerRace()
    if type(UnitRace) ~= "function" then return nil, nil end
    return UnitRace("player")
end

--- The weapon temp-enchant returns (hasMain, mainExpirationMs, ...), C_Item first; nil without
--- either API. Assumed shape: 1.12's (docs/midnight-quirks.md).
function Compat.WeaponEnchantInfo()
    local fn = (C_Item and C_Item.GetWeaponEnchantInfo) or GetWeaponEnchantInfo
    if type(fn) ~= "function" then return nil end
    return fn()
end

--- An equipped slot's tooltip data through C_TooltipInfo.
--- @return table|nil the data table, boolean whether the API exists (false: use a scanning tooltip)
function Compat.InventoryTooltipData(slot)
    local get = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    if type(get) ~= "function" then return nil, false end
    return get("player", slot), true
end

--- A spell's localized name from its ID (localization-§4: IDs flow to names), C_Spell first.
--- @return string|nil the name, nil for an unknown ID or without either API
function Compat.SpellName(spellID)
    local CS = C_Spell
    if type(CS) == "table" and type(CS.GetSpellName) == "function" then return CS.GetSpellName(spellID) end
    if type(GetSpellInfo) == "function" then return (GetSpellInfo(spellID)) end
    return nil
end

--- GetUnitSpeed(unit): current, run, flight, swim (yards/s); nil without the API.
function Compat.UnitSpeed(unit)
    if type(GetUnitSpeed) ~= "function" then return nil end
    return GetUnitSpeed(unit)
end
