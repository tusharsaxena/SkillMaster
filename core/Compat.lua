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
-- globals, so C_SkillInfo is read first and the 1.12 globals second, until `/sm probe` settles
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

--- Whether a struct's header is open: WoW Forever answers isCollapsed (measured), other builds
--- isExpanded.
local function expandedOf(t)
    if t.isCollapsed ~= nil then return not t.isCollapsed end
    return t.isExpanded and true or false
end

--- The C_SkillInfo struct as the one record shape. Measured on WoW Forever 1.60.1 (build 70862,
--- `/sm probe` 2026-11-10): name, isHeader, isCollapsed, rank, maxRank, modifier, tempPoints,
--- skillID, parentSkillLineID. The retail-style names (skillName, skillRank, ...) stay as fallbacks.
local function fromStruct(t)
    return {
        name       = t.name or t.skillName,
        isHeader   = t.isHeader and true or false,
        isExpanded = expandedOf(t),
        rank       = tonumber(t.rank or t.skillRank) or 0,
        tempPoints = tonumber(t.tempPoints or t.numTempPoints) or 0,
        modifier   = tonumber(t.modifier or t.skillModifier) or 0,
        max        = tonumber(t.maxRank or t.skillMaxRank) or 0,
        skillLineID = tonumber(t.skillID or t.skillLineID),
        -- Forever lists a profession twice: the vanilla line and a child line (Leatherworking 165 and
        -- 2945, whose parentSkillLineID is 165). The parent ID maps the child to the same skill.
        parentSkillLineID = tonumber(t.parentSkillLineID),
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

-- The weapon temp enchant. Measured in game on WoW Forever 1.60.1 (2026-11-10): the call is
-- `local enchants = C_Item.GetWeaponEnchantInfo(weaponSlot)`. It takes a slot and errors without
-- one, and it answers one value, not 1.12's positional list. Neither the slot's encoding nor the
-- record's fields are measured yet (`/sm probe` records both), so the shim tries the plausible slot
-- arguments under pcall, remembers the first that does not error, and reads the record by any
-- plausible field name. The 1.12 global keeps its own positional shape.

--- The main-hand slot arguments to try, in order: the client's enum if it has one, then the
--- inventory slot (16), then a 0- and 1-based weapon index.
function Compat.WeaponSlotCandidates()
    local out = {}
    local enum = type(Enum) == "table" and Enum.WeaponSlot
    if type(enum) == "table" then
        local v = enum.MainHand or enum.Mainhand or enum.Main
        if v ~= nil then out[#out + 1] = v end
    end
    out[#out + 1] = INVSLOT_MAINHAND or 16
    out[#out + 1] = 0
    out[#out + 1] = 1
    return out
end

local EXPIRY_KEYS = { "expiration", "expirationTime", "expirationMs", "timeRemaining", "remaining",
                      "timeLeft", "duration" }
local CHARGE_KEYS = { "charges", "numCharges", "count" }
local ID_KEYS     = { "enchantID", "enchantId", "id", "spellID" }

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) and true or false end

--- The first of `keys` the record carries plainly; a secret field reads as absent.
local function firstField(rec, keys)
    for _, k in ipairs(keys) do
        local v = rec[k]
        if v ~= nil and not isSecret(v) then return v, k end
    end
    return nil
end

--- Milliseconds left from a record's time field. A field named for ms, or a value too large to be
--- seconds of a temp enchant (they last an hour at most), is ms; anything else is seconds.
local function msLeft(value, key)
    local n = tonumber(value)
    if not n then return 0 end
    if (key and key:find("Ms")) or n > 7200 then return n end
    return n * 1000
end

--- One enchant record (or an array of them, or the 1.12 positional list) in the 1.12 shape.
--- @return boolean|nil hasMain, number|nil msLeft, number|nil charges, number|nil enchantID
function Compat.NormalizeEnchant(first, ...)
    if isSecret(first) then return nil end
    if type(first) ~= "table" then return first, ... end   -- positional (1.12 / an older build)
    local rec = first[1] ~= nil and first[1] or first
    if type(rec) ~= "table" or next(rec) == nil then return false end
    if rec.hasEnchant == false or rec.hasMainHandEnchant == false then return false end
    local t, key = firstField(rec, EXPIRY_KEYS)
    return true, msLeft(t, key), firstField(rec, CHARGE_KEYS), firstField(rec, ID_KEYS)
end

local function pack(...) return { n = select("#", ...), ... } end

--- The C_Item call with whichever slot argument this client accepts; the one that worked is kept.
--- @return table|nil every return of the call, packed with its count `n`; nil when every slot errors
local function callCItem(fn)
    local tries = Compat.WeaponSlotCandidates()
    if Compat.__enchantSlot ~= nil then table.insert(tries, 1, Compat.__enchantSlot) end
    for _, slot in ipairs(tries) do
        local r = pack(pcall(fn, slot))
        if r[1] then
            Compat.__enchantSlot = slot
            return r
        end
    end
    return nil
end

--- The main-hand temp enchant in the 1.12 shape (hasMain, mainExpirationMs, charges, enchantID),
--- C_Item first; nil without either API, false when there is no enchant. Never errors.
function Compat.WeaponEnchantInfo()
    local cItem = C_Item and C_Item.GetWeaponEnchantInfo
    if type(cItem) == "function" then
        local r = callCItem(cItem)
        if r then return Compat.NormalizeEnchant(unpack(r, 2, r.n)) end
    end
    if type(GetWeaponEnchantInfo) == "function" then
        local ok, a, b, c, d = pcall(GetWeaponEnchantInfo)
        if ok then return a, b, c, d end
    end
    return nil
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
