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
--   Compat.SpellTexture(spellID)           the spell's icon texture (C_Spell first), or nil
--   Compat.PlayerName()                    UnitName("player"), or nil
--   Compat.ClassIcon(classFile)            { atlas } or { file, coords } for a class's icon, or nil
--   Compat.OpenTradeSkill(skillLineID)     open a profession's window by its line; true when it ran
--   Compat.SelectSkillLine(i)              select line i in Character -> Skills; the call's name or nil
--   Compat.MapWorldPos(mapID, x, y)        a map point's (0..1) world position: instance, x, y; or nil
--   Compat.PlayerWorldPos()                the player's world position: instance, x, y; or nil
--   Compat.TomTom()                        the real TomTom addon's table (loaded by name), or nil
--   Compat.NumFactions() / FactionDataByIndex(i) / FactionDataByID(id) / SetFactionHeaderExpanded(i, open)
--     / CanToggleFactionHeaders() / FactionStandingLabel(reaction) / FactionBarColor(reaction)  the faction
--     list (SMW-08, C_Reputation); Compat.PanelShown(frame)  a character panel tab shown
--   Compat.NumCurrencies() / CurrencyListInfo(i) / CurrencyInfo(id) / SetCurrencyHeaderExpanded(i, open)
--     / CanToggleCurrencyHeaders()  the currency list (SMW-09, C_CurrencyInfo); gold is never in it
--   Compat.StatisticsCategories() / StatisticsCategoryInfo(id) / NumStatistics(categoryID) / Statistic(categoryID,
--     index) / StatisticName(statID)  the Statistics tab (SMW-10): GetStatistic in Forever's two-argument form
-- PlayerLevel to SpellName (T5.2), and PlayerName (FB-17), exist so the simulator's seam (core/SimSetup.lua, LibKa0s-Sim-1.0) can answer
-- every client read a simulated character needs (preview-mode, H1): a module reads them as
-- `NS.Compat.Member(...)` at call time and never captures one in a local.
-- The skill list (T2.1): the kit's Forever API set lists it as C_SkillInfo.* and not as the 1.12
-- globals, so C_SkillInfo is read first and the 1.12 globals second, until `/sm probe` settles
-- which the client carries (docs/forever-quirks.md, the assumed-API table). The bare
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

--- Open the profession window of skill line `skillLineID` (C_TradeSkillUI.OpenTradeSkill, the
--- Retail-era call; WoW Forever draws Retail's ProfessionsFrame). Not a protected call on Retail;
--- UNVERIFIED on WoW Forever (owner feedback round 3).
--- @return boolean true when the client took the call and did not answer false
function Compat.OpenTradeSkill(skillLineID)
    local ns = C_TradeSkillUI
    if not (skillLineID and type(ns) == "table" and type(ns.OpenTradeSkill) == "function") then return false end
    local ok, res = pcall(ns.OpenTradeSkill, skillLineID)
    return ok and res ~= false
end

-- The calls that select a line in Character -> Skills, first that exists wins. The 1.12 global and
-- its C_SkillInfo twin take the line's index; the stock frame's own helper redraws the detail pane.
-- Which of them WoW Forever's Skills tab answers is UNVERIFIED (`/sm probe` lists them).
local SELECTORS = {
    { "C_SkillInfo.SetSelectedSkill", function() return C_SkillInfo and C_SkillInfo.SetSelectedSkill end },
    { "SetSelectedSkill", function() return SetSelectedSkill end },
}
Compat.SKILL_SELECTORS = SELECTORS

--- Select line `i` in Character -> Skills, then let the frame redraw (SkillFrame_SetSelection or
--- SkillFrame_UpdateSkills when the client has them).
--- @return string|nil the name of the call that ran
function Compat.SelectSkillLine(i)
    local ran
    for _, s in ipairs(SELECTORS) do
        local fn = s[2]()
        if type(fn) == "function" and pcall(fn, i) then ran = s[1] break end
    end
    if type(SkillFrame_SetSelection) == "function" and pcall(SkillFrame_SetSelection, i) then
        ran = ran or "SkillFrame_SetSelection"
    end
    if type(SkillFrame_UpdateSkills) == "function" then pcall(SkillFrame_UpdateSkills) end
    return ran
end

--- WoW Forever's Skills tab (Camelot CharacterFrame: its sub-frame is SkillsFrame, not 1.12's
--- SkillFrame; owner feedback round 4): redraw the detail pane and the list's highlight after a
--- selection made outside it, as its own entry's click does (SkillsFrame.lua: the
--- "SkillsFrame.NewSkillLineSelected" event, each entry's RefreshHighlightVisuals). The detail pane
--- opens when collapsed. A no-op on a client without it.
function Compat.RefreshSkillsTab()
    local frame = SkillsFrame
    if type(frame) ~= "table" then return false end
    local CF = CharacterFrame
    if type(CF) == "table" and type(CF.IsRightPaneCollapsed) == "function" and CF:IsRightPaneCollapsed()
        and type(CF.SetRightPaneCollapsed) == "function" then
        pcall(CF.SetRightPaneCollapsed, CF, false)
    end
    local ER = EventRegistry
    if type(ER) == "table" and type(ER.TriggerEvent) == "function" then
        pcall(ER.TriggerEvent, ER, "SkillsFrame.NewSkillLineSelected")
    end
    local box = frame.ScrollBox
    if type(box) == "table" and type(box.ForEachFrame) == "function" then
        pcall(box.ForEachFrame, box, function(f)
            if type(f.RefreshHighlightVisuals) == "function" then f:RefreshHighlightVisuals() end
        end)
    end
    return true
end

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

--- The trade link ("[First Aid]", clickable to view the recipes) of the first spellbook spell named
--- one of `names`, as a shift-click on its spellbook icon inserts it (Forever's SpellBookItem:
--- C_SpellBook.GetSpellBookItemTradeSkillLink by slot and bank; owner feedback round 4). Matched by
--- name because the book holds one rank's spell ID, whichever the character trained. nil when the
--- book has no such spell, it is no trade skill, or the API is absent.
--- @param names table localized spell names, e.g. { "First Aid" }
--- @return string|nil
Compat.PAST_LINES, Compat.MAX_BOOK_SLOT = 8, 1000   -- TradeSkillLink's scan: the gap that ends it, its hard stop
function Compat.TradeSkillLink(names)
    local SB = C_SpellBook
    if type(SB) ~= "table" or type(SB.GetSpellBookItemTradeSkillLink) ~= "function"
        or type(SB.GetNumSpellBookSkillLines) ~= "function" or type(SB.GetSpellBookSkillLineInfo) ~= "function"
        or type(SB.GetSpellBookItemName) ~= "function" then
        return nil
    end
    local want = {}
    for _, n in ipairs(names or {}) do want[n] = true end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    -- Forever keeps the professions PAST the skill lines (measured 2026-11-13: lines 1-4 end at slot
    -- 60, First Aid / Leatherworking / Cooking at 61-66), so the scan runs from slot 1 through the
    -- lines' end and on until PAST_LINES empty slots in a row.
    local last = 0
    for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
        local info = SB.GetSpellBookSkillLineInfo(line)
        local first, n = info and tonumber(info.itemIndexOffset), info and tonumber(info.numSpellBookItems)
        if first and n and first + n > last then last = first + n end
    end
    local slot, empty = 0, 0
    while slot < last or empty < Compat.PAST_LINES do
        slot = slot + 1
        local name = SB.GetSpellBookItemName(slot, bank)
        if name == nil then empty = empty + 1 else empty = 0 end
        if name and want[name] then
            local link = SB.GetSpellBookItemTradeSkillLink(slot, bank)
            if link then return link end
        end
        if slot >= Compat.MAX_BOOK_SLOT then break end
    end
    return nil
end

--- A spell's icon texture (a file ID or a path) from its ID, C_Spell first (FB-14: a profession
--- row draws its own spell's icon). nil for an unknown ID or without either API.
function Compat.SpellTexture(spellID)
    local CS = C_Spell
    if type(CS) == "table" and type(CS.GetSpellTexture) == "function" then return CS.GetSpellTexture(spellID) end
    if type(GetSpellTexture) == "function" then return GetSpellTexture(spellID) end
    return nil
end

--- @return string|nil the player's name, nil without the API
function Compat.PlayerName()
    if type(UnitName) ~= "function" then return nil end
    return (UnitName("player"))
end

-- The class sheet the 1.x character-create screen draws from, cut by CLASS_ICON_TCOORDS.
Compat.CLASS_SHEET = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

--- A class's icon (FB-17), feature-detected: the modern atlas `classicon-<class>` where the client
--- carries it (C_Texture.GetAtlasInfo answers it), else the class sheet cut by CLASS_ICON_TCOORDS.
--- Neither is measured on WoW Forever yet (docs/forever-quirks.md).
--- @param classFile string|nil the class file token ("HUNTER")
--- @return table|nil { atlas = name } or { file = path, coords = { l, r, t, b } }; nil for neither
function Compat.ClassIcon(classFile)
    if type(classFile) ~= "string" or classFile == "" then return nil end
    local CT = C_Texture
    local atlas = "classicon-" .. classFile:lower()
    if type(CT) == "table" and type(CT.GetAtlasInfo) == "function" and CT.GetAtlasInfo(atlas) then
        return { atlas = atlas }
    end
    local coords = type(CLASS_ICON_TCOORDS) == "table" and CLASS_ICON_TCOORDS[classFile]
    if type(coords) == "table" then
        return { file = Compat.CLASS_SHEET, coords = { coords[1], coords[2], coords[3], coords[4] } }
    end
    return nil
end

--- GetUnitSpeed(unit): current, run, flight, swim (yards/s); nil without the API.
function Compat.UnitSpeed(unit)
    if type(GetUnitSpeed) ~= "function" then return nil end
    return GetUnitSpeed(unit)
end

-- ---------------------------------------------------------------------------------------------
-- Round 5, R5-15: world positions for the trainer popup's distances. Every C_Map call and
-- CreateVector2D is feature-detected and run under pcall; a position the client answers secret, or
-- not at all (inside an instance), reads as unknown.
-- ---------------------------------------------------------------------------------------------

local function plainNumber(v) return not isSecret(v) and type(v) == "number" end

--- The world position GetWorldPosFromMapPos gives a map point (x, y as 0..1 fractions).
--- @return number|nil instanceID, number|nil x, number|nil y (yards); nil when unknown
function Compat.MapWorldPos(mapID, x, y)
    local api = C_Map
    if not (plainNumber(mapID) and plainNumber(x) and plainNumber(y)) then return nil end
    if type(api) ~= "table" or type(api.GetWorldPosFromMapPos) ~= "function"
        or type(CreateVector2D) ~= "function" then return nil end
    local ok, instance, pos = pcall(api.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if not ok or not plainNumber(instance) or isSecret(pos) or type(pos) ~= "table"
        or type(pos.GetXY) ~= "function" then return nil end
    local okXY, wx, wy = pcall(pos.GetXY, pos)
    if not okXY or not (plainNumber(wx) and plainNumber(wy)) then return nil end
    return instance, wx, wy
end

--- The player's world position: their best map, their place on it, and that point's world position.
--- @return number|nil instanceID, number|nil x, number|nil y (yards); nil when unknown
function Compat.PlayerWorldPos()
    local api = C_Map
    if type(api) ~= "table" or type(api.GetBestMapForUnit) ~= "function"
        or type(api.GetPlayerMapPosition) ~= "function" then return nil end
    local okMap, mapID = pcall(api.GetBestMapForUnit, "player")
    if not okMap or not plainNumber(mapID) then return nil end
    local okPos, pos = pcall(api.GetPlayerMapPosition, mapID, "player")
    if not okPos or isSecret(pos) or type(pos) ~= "table" or type(pos.GetXY) ~= "function" then return nil end
    local okXY, x, y = pcall(pos.GetXY, pos)
    if not okXY or not (plainNumber(x) and plainNumber(y)) then return nil end
    return Compat.MapWorldPos(mapID, x, y)
end

-- ---------------------------------------------------------------------------------------------
-- AF-SM-TOMTOM (owner img-19, 2026-11-19): the real TomTom. Round 7 (R7-7) dropped TomTom because
-- another addon answered TomTom's API (a `TomTom` global with an AddWaypoint), so the addon is told
-- by its folder name, C_AddOns.IsAddOnLoaded("TomTom"), before its global is used. The bare
-- IsAddOnLoaded is in neither client's name set (docs/forever-quirks.md, the assumed-API table), so
-- no fallback to it.
-- ---------------------------------------------------------------------------------------------

--- The TomTom addon's table when the addon named TomTom is loaded and answers AddWaypoint, else nil.
function Compat.TomTom()
    local api = C_AddOns
    if type(api) ~= "table" or type(api.IsAddOnLoaded) ~= "function" then return nil end
    local ok, loaded = pcall(api.IsAddOnLoaded, "TomTom")
    if not (ok and loaded) then return nil end
    local tt = TomTom
    if type(tt) ~= "table" or type(tt.AddWaypoint) ~= "function" then return nil end
    return tt
end

-- ---------------------------------------------------------------------------------------------
-- SMW-08 / SMW-09: the reputation and currency lists (docs/forever-quirks.md, "Reputations, currencies
-- and Statistics": Blizzard's Forever source, C_Reputation and C_CurrencyInfo only; the bare 1.12 globals
-- are absent). Each read is feature-detected and runs under pcall; a missing API reads as an empty list.
-- The two header toggles act on the client's own list, the character panel's, so the simulator's seam
-- guards them (core/SimSetup.lua) and modules/SharedList.lua is their one caller.
-- ---------------------------------------------------------------------------------------------

local function repApi()
    local api = C_Reputation
    if type(api) == "table" and type(api.GetNumFactions) == "function"
        and type(api.GetFactionDataByIndex) == "function" then return api end
    return nil
end

local function guarded(fn, ...)
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

--- The listed faction rows' count (only expanded headers' children are listed), 0 without the API.
function Compat.NumFactions()
    local api = repApi()
    return api and tonumber(guarded(api.GetNumFactions)) or 0
end

--- Listed faction row `i`: one FactionData table, or nil.
function Compat.FactionDataByIndex(i)
    local api = repApi()
    local t = api and guarded(api.GetFactionDataByIndex, i)
    return type(t) == "table" and t or nil
end

--- One faction by its id, touching no list state: a FactionData table, or nil.
function Compat.FactionDataByID(id)
    local api = repApi()
    if not (api and type(api.GetFactionDataByID) == "function") then return nil end
    local t = guarded(api.GetFactionDataByID, id)
    return type(t) == "table" and t or nil
end

--- Open (true) or close faction header row `i`. Answers whether a call ran.
function Compat.SetFactionHeaderExpanded(i, open)
    local api = repApi()
    local fn = api and (open and api.ExpandFactionHeader or api.CollapseFactionHeader)
    if type(fn) ~= "function" then return false end
    return (pcall(fn, i))
end

--- Whether the client can open and close faction headers (the full read needs both).
function Compat.CanToggleFactionHeaders()
    local api = repApi()
    return api ~= nil and type(api.ExpandFactionHeader) == "function" and type(api.CollapseFactionHeader) == "function"
end

--- The client's standing name for reaction `reaction` (1..8): GetText("FACTION_STANDING_LABELn", sex) where
--- the client has it, else the bare global, else nil.
function Compat.FactionStandingLabel(reaction)
    local n = tonumber(reaction)
    if not n then return nil end
    local key = "FACTION_STANDING_LABEL" .. math.floor(n)
    if type(GetText) == "function" and type(UnitSex) == "function" then
        local ok, s = pcall(GetText, key, UnitSex("player"))
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    local s = _G[key]
    return type(s) == "string" and s or nil
end

--- The client's bar color for reaction `reaction`: { r, g, b } from FACTION_BAR_COLORS, or nil.
function Compat.FactionBarColor(reaction)
    local colors = FACTION_BAR_COLORS
    local c = type(colors) == "table" and colors[tonumber(reaction) or -1]
    if type(c) ~= "table" or type(c.r) ~= "number" then return nil end
    return { c.r, c.g, c.b, 1 }
end

local function currencyApi()
    local api = C_CurrencyInfo
    if type(api) == "table" and type(api.GetCurrencyListSize) == "function"
        and type(api.GetCurrencyListInfo) == "function" then return api end
    return nil
end

--- The listed currency rows' count (only expanded headers' children are listed), 0 without the API.
function Compat.NumCurrencies()
    local api = currencyApi()
    return api and tonumber(guarded(api.GetCurrencyListSize)) or 0
end

--- Listed currency row `i`: one CurrencyInfo table, or nil.
function Compat.CurrencyListInfo(i)
    local api = currencyApi()
    local t = api and guarded(api.GetCurrencyListInfo, i)
    return type(t) == "table" and t or nil
end

--- One currency by its id, touching no list state: a CurrencyInfo table, or nil.
function Compat.CurrencyInfo(id)
    local api = C_CurrencyInfo
    if type(api) ~= "table" or type(api.GetCurrencyInfo) ~= "function" then return nil end
    local t = guarded(api.GetCurrencyInfo, id)
    return type(t) == "table" and t or nil
end

--- Open (true) or close currency header row `i`. Answers whether a call ran.
function Compat.SetCurrencyHeaderExpanded(i, open)
    local api = currencyApi()
    if not (api and type(api.ExpandCurrencyList) == "function") then return false end
    return (pcall(api.ExpandCurrencyList, i, open and true or false))
end

--- Whether the client can open and close currency headers.
function Compat.CanToggleCurrencyHeaders()
    local api = currencyApi()
    return api ~= nil and type(api.ExpandCurrencyList) == "function"
end

--- Whether `frame` (ReputationFrame, TokenFrame: the panel tab that shares the list's collapse) is shown.
function Compat.PanelShown(frame)
    return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() == true
end

-- ---------------------------------------------------------------------------------------------
-- SMW-10: the Statistics tab (docs/forever-quirks.md, "Reputations, currencies and Statistics"). Blizzard's
-- Forever StatisticsFrame reads GetStatisticsCategoryList, GetCategoryInfo (name, parent; -1 a root),
-- GetCategoryNumAchievements and GetStatistic(categoryID, index) -> quantity, skip, statID, which is Forever's
-- form and not Retail's GetStatistic(achievementID); a row's name is GetAchievementInfo(statID)'s second
-- answer. Nothing here is shared with the panel (no collapse trap) and nothing acts on the client. Each read is
-- feature-detected and runs under pcall; a missing API reads as an empty tree.
-- ---------------------------------------------------------------------------------------------

--- The Statistics categories' ids in the client's order (its list ordered by numeric key: the keys may be
--- sparse); an empty table without the API.
function Compat.StatisticsCategories()
    if type(GetStatisticsCategoryList) ~= "function" then return {} end
    local list = guarded(GetStatisticsCategoryList)
    if type(list) ~= "table" then return {} end
    local keys, out = {}, {}
    for k in pairs(list) do if type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local id = tonumber(list[k])
        if id then out[#out + 1] = id end
    end
    return out
end

--- Category `id`'s name and parent id (-1, or nil, for a root); nil without the API.
function Compat.StatisticsCategoryInfo(id)
    if type(GetCategoryInfo) ~= "function" then return nil end
    local ok, name, parent = pcall(GetCategoryInfo, id)
    if not ok then return nil end
    return name, tonumber(parent)
end

--- How many rows category `categoryID` lists (GetCategoryNumAchievements), 0 without the API.
function Compat.NumStatistics(categoryID)
    if type(GetCategoryNumAchievements) ~= "function" then return 0 end
    return tonumber(guarded(GetCategoryNumAchievements, categoryID)) or 0
end

--- Row `index` of category `categoryID`, in Forever's form: quantity, skip, statID; nil without the API.
function Compat.Statistic(categoryID, index)
    if type(GetStatistic) ~= "function" then return nil end
    local ok, quantity, skip, statID = pcall(GetStatistic, categoryID, index)
    if not ok then return nil end
    return quantity, skip, statID
end

--- Statistic `statID`'s name (GetAchievementInfo's second answer), or nil.
function Compat.StatisticName(statID)
    if type(GetAchievementInfo) ~= "function" then return nil end
    local ok, _, name = pcall(GetAchievementInfo, statID)
    if not ok or type(name) ~= "string" then return nil end
    return name
end
