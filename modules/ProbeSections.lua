local _, NS = ...
-- modules/ProbeSections.lua — `/cl probe`'s factions, currencies and statistics sections (item SMW-01 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md). Each dumps the client's raw answers so the owner's
-- run settles the shapes the Reputations, Currencies and Statistics windows are built on (the spec's "The probe
-- and the client notes"); docs/forever-quirks.md carries what Blizzard's Forever source already says.
--
-- Reputation and currency headers are client state shared with the character panel, and the index API lists
-- only expanded rows. So a section expands the collapsed headers, reads, and collapses them again bottom up,
-- as the skill read does, but never in combat and never while that panel is shown (then it reads the rows as
-- listed and says why). Statistics has no shared state and is read as is.

local P = NS.Probe

local NIL = P.NIL
local MAX_FACTIONS = 60    -- the first 60 faction rows
local STAT_ROWS = 3        -- rows read per statistics category

--- A shallow copy of a table return, so the JSON holds plain values; a nil scalar becomes the nil marker.
local function copy(v)
    if type(v) ~= "table" then return v == nil and NIL or v end
    local out = {}
    for k, x in pairs(v) do out[k] = x end
    return out
end

local function call(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if ok then return true, a, b, c end
    return false, tostring(a)
end

local function shown(frame)
    return type(frame) == "table" and type(frame.IsShown) == "function" and frame:IsShown() and true or false
end

--- Why a header may not be opened now, or nil when it may.
local function blocked(panel)
    if InCombatLockdown() then return "combat" end
    if shown(panel) then return "panel shown" end
    return nil
end

-- One shared-collapse list (factions or currencies): count(), row(i) -> table, isClosed(row), key(row),
-- open(i), close(i). Opens every collapsed header top down (children appear below and are visited in turn)
-- and answers the keys it opened.
local function openAll(list)
    local opened, i = {}, 1
    while i <= list.count() do
        local ok, row = call(list.row, i)
        if ok and type(row) == "table" and list.isClosed(row) then
            list.open(i)
            opened[list.key(row)] = true
        end
        i = i + 1
    end
    return opened
end

--- Closes what openAll opened, bottom up so the earlier indices do not move.
local function closeAgain(list, opened)
    if next(opened) == nil then return end
    for i = list.count(), 1, -1 do
        local ok, row = call(list.row, i)
        if ok and type(row) == "table" and row.isHeader and opened[list.key(row)] then list.close(i) end
    end
end

--- Reads `limit` rows of a shared-collapse list into `out`, opening its headers first when it has the
--- expand API (`canOpen`) and the moment allows. Answers the keys it opened; the caller closes them again.
local function readList(list, out, limit, panel, canOpen)
    if canOpen then out.skipped = blocked(panel) else out.skipped = "no expand API" end
    local opened = {}
    if not out.skipped then opened = openAll(list) end
    out.expanded = next(opened) ~= nil
    out.count = list.count()
    for i = 1, math.min(out.count, limit) do
        local ok, row = call(list.row, i)
        out.rows[i] = ok and copy(row) or { error = row }
    end
    return opened
end

-- ── factions ─────────────────────────────────────────────────────────────────────────────────────

local function factionList(ns)
    return {
        count = function() return ns.GetNumFactions() or 0 end,
        row = ns.GetFactionDataByIndex,
        isClosed = function(r) return r.isHeader and r.isCollapsed end,
        key = function(r) return r.factionID or r.name end,
        open = ns.ExpandFactionHeader,
        close = ns.CollapseFactionHeader,
    }
end

--- The first faction under a header the read opened, read by id once that header is closed again:
--- does GetFactionDataByID answer for it (the refresh-by-id plan depends on it)?
local function byIDCheck(ns, rows, opened)
    local header
    for _, row in ipairs(rows) do
        if row.isHeader and opened[row.factionID or row.name] and not header then
            header = row
        elseif header and not row.isHeader and row.factionID then
            local ok, data = call(ns.GetFactionDataByID, row.factionID)
            return { header = header.name, factionID = row.factionID, ok = ok,
                     answered = ok and type(data) == "table" or false, data = ok and copy(data) or data }
        end
    end
    return { reason = "no collapsed header with a faction under it" }
end

local function readFactions(report)
    local ns = C_Reputation
    local out = { source = "none", rows = {} }
    report.factions = out
    if type(ns) ~= "table" or type(ns.GetFactionDataByIndex) ~= "function"
        or type(ns.GetNumFactions) ~= "function" then return end
    out.source = "C_Reputation"
    local list = factionList(ns)
    local canOpen = type(list.open) == "function" and type(list.close) == "function"
    local opened = readList(list, out, MAX_FACTIONS, ReputationFrame, canOpen)
    closeAgain(list, opened)
    if type(ns.GetFactionDataByID) == "function" then out.byIDCollapsed = byIDCheck(ns, out.rows, opened) end
end

-- ── currencies ───────────────────────────────────────────────────────────────────────────────────

local function currencyList(ns)
    return {
        count = function() return ns.GetCurrencyListSize() or 0 end,
        row = ns.GetCurrencyListInfo,
        isClosed = function(r) return r.isHeader and not r.isHeaderExpanded end,
        key = function(r) return tostring(r.name) .. "#" .. tostring(r.currencyListDepth) end,
        open = function(i) ns.ExpandCurrencyList(i, true) end,
        close = function(i) ns.ExpandCurrencyList(i, false) end,
    }
end

local function readCurrencies(report)
    local ns = C_CurrencyInfo
    local out = { source = "none", rows = {} }
    report.currencies = out
    if type(ns) ~= "table" or type(ns.GetCurrencyListInfo) ~= "function"
        or type(ns.GetCurrencyListSize) ~= "function" then return end
    out.source = "C_CurrencyInfo"
    local list = currencyList(ns)
    local opened = readList(list, out, math.huge, TokenFrame, type(ns.ExpandCurrencyList) == "function")
    closeAgain(list, opened)
    if type(ns.GetCurrencyInfo) ~= "function" then return end
    for _, row in ipairs(out.rows) do
        if not row.isHeader and type(row.currencyID) == "number" and row.currencyID > 0 then
            local ok, data = call(ns.GetCurrencyInfo, row.currencyID)
            out.byID = { currencyID = row.currencyID, ok = ok, data = ok and copy(data) or data }
            return
        end
    end
end

-- ── statistics ───────────────────────────────────────────────────────────────────────────────────

--- Up to STAT_ROWS rows of one category, in Forever's form GetStatistic(categoryID, index) -> quantity,
--- skip, statID, each with its name from GetAchievementInfo(statID). The values are the client's, raw.
local function statRows(id, n)
    local rows = {}
    for i = 1, math.min(n, STAT_ROWS) do
        local ok, quantity, skip, statID = call(GetStatistic, id, i)
        local row = ok and { quantity = copy(quantity), skip = copy(skip), statID = copy(statID) }
            or { error = quantity }
        if ok and statID ~= nil and type(GetAchievementInfo) == "function" then
            local okName, _, name = call(GetAchievementInfo, statID)
            row.name = okName and copy(name) or NIL
        end
        rows[i] = row
    end
    return rows
end

local function category(id)
    local entry = { id = id }
    local ok, name, parent = call(GetCategoryInfo, id)
    entry.name, entry.parent = ok and copy(name) or NIL, ok and copy(parent) or NIL
    local okN, n = call(GetCategoryNumAchievements, id)
    entry.numRows = okN and type(n) == "number" and n or 0
    entry.rows = statRows(id, entry.numRows)
    return entry
end

--- Whether the Retail one-argument form GetStatistic(statID) answers on this client.
local function retailForm(categories)
    for _, c in ipairs(categories) do
        for _, row in ipairs(c.rows) do
            if type(row.statID) == "number" then
                local ok, v = call(GetStatistic, row.statID)
                return { statID = row.statID, ok = ok, value = ok and copy(v) or nil, error = not ok and v or nil }
            end
        end
    end
    return { reason = "no statID read" }
end

local function readStatistics(report)
    local out = { source = "none", categories = {} }
    report.statistics = out
    local need = { GetStatisticsCategoryList, GetCategoryInfo, GetCategoryNumAchievements, GetStatistic }
    for i = 1, 4 do   -- not ipairs: a nil (an absent API) would end the walk early
        if type(need[i]) ~= "function" then return end
    end
    out.source = "GetStatisticsCategoryList"
    local ok, list = call(GetStatisticsCategoryList)
    if not ok or type(list) ~= "table" then out.error = ok and "not a table" or list; return end
    local keys = {}
    for k in pairs(list) do if type(k) == "number" then keys[#keys + 1] = k end end
    table.sort(keys)   -- Blizzard orders the list by numeric key, which allows sparse keys
    for _, k in ipairs(keys) do out.categories[#out.categories + 1] = category(list[k]) end
    out.retailForm = retailForm(out.categories)
end

--- Adds the three sections to a P.Run report. Called by P.Run; each section stands alone.
function P.Sections(report)
    readFactions(report)
    readCurrencies(report)
    readStatistics(report)
end
