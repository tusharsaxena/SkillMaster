local addonName, NS = ...
-- modules/Probe.lua — `/sm probe`: a one-shot report of the WoW Forever API shapes the data
-- modules depend on (design §5.4). The owner runs it once in game and sends the JSON back; it
-- corrects the "assumed (1.12)" rows in docs/midnight-quirks.md.
--
-- Read-only apart from one restored change: a collapsed header in the stock Skills tab hides its
-- lines from GetSkillLineInfo, so the probe expands it, reads, and collapses it again.

NS.Probe = {}
local P = NS.Probe
local L = NS.L

-- Every API the data modules (T2.x) and the waypoints (T3.3) would feature-detect, each read as a
-- bare global (never called here) so its presence is reported without touching it.
P.APIS = {
    -- The skill list. The kit's generated Forever API set (Ketho/BlizzardInterfaceResources) lists
    -- it as C_SkillInfo.* and not as the 1.12 globals; the probe reports both and settles it.
    { "C_SkillInfo.GetNumSkillLines",     function() return C_SkillInfo and C_SkillInfo.GetNumSkillLines end },
    { "C_SkillInfo.GetSkillLineInfo",     function() return C_SkillInfo and C_SkillInfo.GetSkillLineInfo end },
    { "C_SkillInfo.GetSkillLineInfoByID", function() return C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID end },
    { "C_SkillInfo.ExpandSkillHeader",    function() return C_SkillInfo and C_SkillInfo.ExpandSkillHeader end },
    { "C_SkillInfo.CollapseSkillHeader",  function() return C_SkillInfo and C_SkillInfo.CollapseSkillHeader end },
    { "C_Item.GetWeaponEnchantInfo",      function() return C_Item and C_Item.GetWeaponEnchantInfo end },
    { "GetNumSkillLines",        function() return GetNumSkillLines end },
    { "GetSkillLineInfo",        function() return GetSkillLineInfo end },
    { "ExpandSkillHeader",       function() return ExpandSkillHeader end },
    { "CollapseSkillHeader",     function() return CollapseSkillHeader end },
    { "GetUnitSpeed",            function() return GetUnitSpeed end },
    { "GetSpellBonusDamage",     function() return GetSpellBonusDamage end },
    { "GetSpellCritChance",      function() return GetSpellCritChance end },
    { "GetHitModifier",          function() return GetHitModifier end },
    { "GetSpellHitModifier",     function() return GetSpellHitModifier end },
    { "GetCombatRating",         function() return GetCombatRating end },
    { "GetWeaponEnchantInfo",    function() return GetWeaponEnchantInfo end },
    { "GetCritChance",           function() return GetCritChance end },
    { "GetRangedCritChance",     function() return GetRangedCritChance end },
    { "GetDodgeChance",          function() return GetDodgeChance end },
    { "GetParryChance",          function() return GetParryChance end },
    { "GetBlockChance",          function() return GetBlockChance end },
    { "UnitResistance",          function() return UnitResistance end },
    { "C_Map.SetUserWaypoint",   function() return C_Map and C_Map.SetUserWaypoint end },
    { "C_Map.GetBestMapForUnit", function() return C_Map and C_Map.GetBestMapForUnit end },
    { "CastSpellByName",         function() return CastSpellByName end },
}
local TOMTOM = 'IsAddOnLoaded("TomTom")'

-- A nil inside a return list cannot travel through a JSON array, so it is written as this string.
P.NIL = "<nil>"

local function pack(...)
    local n, out = select("#", ...), {}
    for i = 1, n do
        local v = select(i, ...)
        if v == nil then v = P.NIL end
        out[i] = v
    end
    return out
end

local function addonLoaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(fn) ~= "function" then return false end
    return fn(name) and true or false
end

--- The skill-list API this client has: the C_SkillInfo namespace the kit's Forever API set lists,
--- else the 1.12 globals. Answers nil when neither carries the line reader.
local function skillApi()
    local ns = C_SkillInfo
    if type(ns) == "table" and type(ns.GetSkillLineInfo) == "function" then
        return { source = "C_SkillInfo", count = ns.GetNumSkillLines, info = ns.GetSkillLineInfo,
                 expand = ns.ExpandSkillHeader, collapse = ns.CollapseSkillHeader }
    end
    if type(GetSkillLineInfo) == "function" then
        return { source = "global", count = GetNumSkillLines, info = GetSkillLineInfo,
                 expand = ExpandSkillHeader, collapse = CollapseSkillHeader }
    end
    return nil
end

local function lineCount(api)
    if type(api.count) ~= "function" then return 0 end
    return api.count() or 0
end

--- name, isHeader, isExpanded of line i, from either shape: a table return (a C_ API) or the
--- 1.12 positional list.
local function headerOf(api, i)
    local first, isHeader, isExpanded = api.info(i)
    if type(first) == "table" then
        return first.skillName or first.name, first.isHeader, first.isExpanded
    end
    return first, isHeader, isExpanded
end

--- Expand every collapsed header so its lines are readable; answers the names expanded.
local function expandAll(api)
    local expanded = {}
    if type(api.expand) ~= "function" then return expanded end
    local i = 1
    while i <= lineCount(api) do
        local name, isHeader, isExpanded = headerOf(api, i)
        if isHeader and not isExpanded then
            api.expand(i)
            expanded[name] = true
        end
        i = i + 1
    end
    return expanded
end

--- Collapse again what expandAll opened, bottom up so earlier indices do not move.
local function collapseAgain(api, expanded)
    if type(api.collapse) ~= "function" or next(expanded) == nil then return end
    for i = lineCount(api), 1, -1 do
        local name, isHeader = headerOf(api, i)
        if isHeader and expanded[name] then api.collapse(i) end
    end
end

local function readSkills(report)
    local api = skillApi()
    if not api then return end   -- `apis` says which reader is missing
    report.skillSource = api.source
    local expanded = expandAll(api)
    for i = 1, lineCount(api) do
        report.skillLines[i] = pack(api.info(i))
        local name, isHeader = headerOf(api, i)
        if isHeader then report.headers[#report.headers + 1] = name end
    end
    collapseAgain(api, expanded)
end

--- The weapon enchant's raw returns: C_Item's (the kit's Forever API set) first, then the global.
--- On WoW Forever the C_Item call takes a weapon slot and errors without one (measured 2026-11-10),
--- so each candidate slot is tried under pcall and recorded: the argument, whether it errored, and
--- the raw returns or the error text. `enchant` stays the first call that worked, for the old reader.
local function readEnchant(report)
    local cItem = C_Item and C_Item.GetWeaponEnchantInfo
    if type(cItem) == "function" then
        report.enchantSlotEnum = type(Enum) == "table" and Enum.WeaponSlot or P.NIL
        for _, slot in ipairs(NS.Compat.WeaponSlotCandidates()) do
            local r = pack(pcall(cItem, slot))
            local entry = { slot = slot, ok = r[1] and true or false }
            if r[1] then
                entry.returns = { unpack(r, 2) }
                if report.enchant[1] == nil then report.enchant = entry.returns end
            else
                entry.error = tostring(r[2])
            end
            report.enchantTries[#report.enchantTries + 1] = entry
        end
        return
    end
    if type(GetWeaponEnchantInfo) == "function" then
        local r = pack(pcall(GetWeaponEnchantInfo))
        if r[1] then report.enchant = { unpack(r, 2) } end
    end
end

--- Build the report. Every value comes from the client; nothing is interpreted.
--- @return table { client, build, skillLines, headers, apis, enchant, enchantTries, enchantSlotEnum }
function P.Run()
    local version, build, date, interface = GetBuildInfo()
    local report = {
        client     = { version = version or P.NIL, locale = GetLocale() or P.NIL },
        build      = { version = version or P.NIL, build = build or P.NIL, date = date or P.NIL,
                       interface = interface or P.NIL },
        skillSource = P.NIL,   -- "C_SkillInfo" or "global": which skill-list API was read
        skillLines = {},
        headers    = {},
        apis       = {},
        enchant    = {},
        enchantTries = {},   -- one { slot, ok, returns | error } per slot argument tried
    }
    readSkills(report)
    for _, api in ipairs(P.APIS) do report.apis[api[1]] = type(api[2]()) == "function" end
    report.apis[TOMTOM] = addonLoaded("TomTom")
    readEnchant(report)
    NS.Debug("Probe", "%d skill lines, %d headers", #report.skillLines, #report.headers)
    return report
end

--- A read-only summary for the diagnostics report (modules/Diagnostics.lua): which skill-list API
--- this client has and its visible line count, and which probed globals are present. Unlike Run()
--- it never expands a header, so it touches no client state.
--- @return table { source = "C_SkillInfo"|"global"|"none", lines = n, present = n, total = n,
---   missing = { names }, tomtom = bool }
function P.Summary()
    local api = skillApi()
    local out = { source = api and api.source or "none", lines = api and lineCount(api) or 0,
                  present = 0, total = #P.APIS, missing = {}, tomtom = addonLoaded("TomTom") }
    for _, entry in ipairs(P.APIS) do
        if type(entry[2]()) == "function" then out.present = out.present + 1
        else out.missing[#out.missing + 1] = entry[1] end
    end
    return out
end

-- The copy window the verb shows the JSON in (LibKa0s-Widgets-1.0, lazy until the first Show).
P.__copy = NS.Widgets.CopyWindow({
    addonName = addonName,
    name      = "SkillMasterProbeCopy",
    title     = L["Skill Master probe: copy this and send it to the author"],
    font      = NS.Constants.FONT_MONO,
})

--- The `probe` verb: run the report and show it as JSON, ready to copy.
function P.Verb()
    local encode = NS.PerfEncodeJSON   -- through core/PerfSetup.lua (library-stack-§7)
    if not (encode and P.__copy) then
        NS.Print(L["%s is unavailable: the LibKa0s library did not load."]:format("/sm probe"))
        return nil
    end
    local json = encode(P.Run())
    P.__copy:Show(json)
    NS.Print(L["Probe report ready: press Ctrl+C to copy it."])
    return json
end
