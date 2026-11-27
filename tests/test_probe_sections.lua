-- tests/test_probe_sections.lua — `/cl probe`'s factions, currencies and statistics sections (item SMW-01 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md; the spec's "The probe and the client notes"). The
-- fakes follow Blizzard's Forever UI source (the recon's API findings): one FactionData or CurrencyInfo table
-- per row, an index range that lists only expanded rows, and GetStatistic(categoryID, index).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- A tree flattened in panel order; `kids` of a collapsed header are hidden from the index range.
local function flatList(tree)
    local function visible()
        local out = {}
        local function walk(nodes)
            for _, n in ipairs(nodes) do
                out[#out + 1] = n
                if n.kids and not n.collapsed then walk(n.kids) end
            end
        end
        walk(tree)
        return out
    end
    return visible
end

local function repTree()
    return {
        { id = 469, name = "Alliance", header = true, kids = {
            { id = 72, name = "Stormwind", standing = 3672 },
            { id = 169, name = "Steamwheedle Cartel", header = true, child = true, withRep = true, kids = {
                { id = 21, name = "Booty Bay", child = true },
            } },
        } },
        { id = 1169, name = "Other", header = true, collapsed = true, kids = {
            { id = 59, name = "Thorium Brotherhood", child = true },
        } },
    }
end

-- Installs a fake C_Reputation over `tree`; answers a spy with the calls made and a byID switch.
local function installReps(tree, opts)
    opts = opts or {}
    local visible = flatList(tree)
    local byID, spy = {}, { expand = 0, collapse = 0 }
    local function index(nodes)
        for _, n in ipairs(nodes) do byID[n.id] = n; if n.kids then index(n.kids) end end
    end
    index(tree)
    local function data(n)
        return { factionID = n.id, name = n.name, isHeader = n.header or false, isChild = n.child or false,
                 isHeaderWithRep = n.withRep or false, isCollapsed = n.collapsed or false, reaction = 6,
                 currentReactionThreshold = 9000, nextReactionThreshold = 21000, currentStanding = n.standing or 0 }
    end
    M.C_Reputation = {
        GetNumFactions = function() return #visible() end,
        GetFactionDataByIndex = function(i) local n = visible()[i]; return n and data(n) end,
        GetFactionDataByID = function(id)
            local n = byID[id]
            if not n then return nil end
            if opts.byIDHidesCollapsed then
                for _, v in ipairs(visible()) do if v == n then return data(n) end end
                return nil
            end
            return data(n)
        end,
        ExpandFactionHeader = function(i) spy.expand = spy.expand + 1; visible()[i].collapsed = false end,
        CollapseFactionHeader = function(i) spy.collapse = spy.collapse + 1; visible()[i].collapsed = true end,
    }
    return spy
end

local function currencyTree()
    return {
        { name = "Player vs. Player", header = true, depth = 0, kids = {
            { id = 1901, name = "Honor Points", quantity = 1200, max = 75000, depth = 1 },
        } },
        { name = "Miscellaneous", header = true, depth = 0, collapsed = true, kids = {
            { id = 515, name = "Darkmoon Prize Ticket", quantity = 12, max = 0, depth = 1 },
        } },
    }
end

local function installCurrencies(tree)
    local visible = flatList(tree)
    local spy = { expand = 0 }
    M.C_CurrencyInfo = {
        GetCurrencyListSize = function() return #visible() end,
        GetCurrencyListInfo = function(i)
            local n = visible()[i]
            if not n then return nil end
            return { name = n.name, currencyID = n.id or 0, isHeader = n.header or false,
                     isHeaderExpanded = n.header and not n.collapsed or false, currencyListDepth = n.depth,
                     quantity = n.quantity or 0, maxQuantity = n.max or 0 }
        end,
        ExpandCurrencyList = function(i, expand)
            local n = visible()[i]
            if expand then spy.expand = spy.expand + 1 end
            n.collapsed = not expand
        end,
        GetCurrencyInfo = function(id)
            for _, top in ipairs(tree) do
                for _, k in ipairs(top.kids) do
                    if k.id == id then return { name = k.name, currencyID = k.id, quantity = k.quantity } end
                end
            end
        end,
    }
    return spy
end

local CATS = {
    [130] = { name = "Character", parent = -1, rows = { { 58, false, 1 }, { "--", false, 2 } } },
    [140] = { name = "Wealth", parent = 130, rows = { { 1234567, false, 3 }, { 0, true, 4 }, { 33, false, nil },
                                                      { 7, false, 5 }, { 8, false, 6 } } },
    [141] = { name = "Consumables", parent = 130, rows = {} },
}
local NAMES = { "Times camped", "Talent tree respecs", "Total gold acquired", "Hidden", "Auctions posted", "Ninth" }

local function installStatistics()
    local saved = { M.GetStatisticsCategoryList, M.GetCategoryInfo, M.GetCategoryNumAchievements,
                    M.GetStatistic, M.GetAchievementInfo }
    M.GetStatisticsCategoryList = function() return { 130, 140, 141 } end
    M.GetCategoryInfo = function(id) local c = CATS[id]; if c then return c.name, c.parent, 0 end end
    M.GetCategoryNumAchievements = function(id) local c = CATS[id]; return c and #c.rows or 0, 0, 0 end
    M.GetStatistic = function(cat, i)
        local c = CATS[cat]
        if i == nil then error("Usage: GetStatistic(categoryID, index)") end
        local r = c and c.rows[i]
        if r then return r[1], r[2], r[3] end
    end
    M.GetAchievementInfo = function(id) return id, NAMES[id] end
    return function()
        M.GetStatisticsCategoryList, M.GetCategoryInfo, M.GetCategoryNumAchievements,
            M.GetStatistic, M.GetAchievementInfo = unpack(saved, 1, 5)
    end
end

local function withClient(fn)
    local saved = { M.C_Reputation, M.C_CurrencyInfo, M.ReputationFrame, M.TokenFrame }
    local ok, err = pcall(fn)
    M.C_Reputation, M.C_CurrencyInfo, M.ReputationFrame, M.TokenFrame = unpack(saved, 1, 4)
    if not ok then error(err, 0) end
end

test("probe sections: the report carries factions, currencies and statistics", function()
    withClient(function()
        installReps(repTree()); installCurrencies(currencyTree())
        local restore = installStatistics()
        local r = NS.Probe.Run()
        restore()
        for _, key in ipairs({ "factions", "currencies", "statistics" }) do
            assertTrue(type(r[key]) == "table", "missing section " .. key)
        end
    end)
end)

test("probe sections: the new API presence rows are reported, the absent legacy globals false", function()
    withClient(function()
        installReps(repTree())
        local r = NS.Probe.Run()
        for _, name in ipairs({ "C_Reputation.GetFactionDataByIndex", "C_Reputation.GetFactionDataByID",
                                "C_Reputation.ExpandFactionHeader", "C_Reputation.CollapseFactionHeader",
                                "C_CurrencyInfo.GetCurrencyListInfo", "C_CurrencyInfo.ExpandCurrencyList",
                                "GetStatisticsCategoryList", "GetStatistic", "GetFactionInfo" }) do
            assertEqual(type(r.apis[name]), "boolean", name)
        end
        assertTrue(r.apis["C_Reputation.GetFactionDataByIndex"], "present")
        assertTrue(r.apis.GetFactionInfo == false, "the 1.12 global is absent")
    end)
end)

test("probe sections: factions lists every row with collapsed headers opened, then restores them", function()
    withClient(function()
        local tree = repTree()
        local spy = installReps(tree)
        local f = NS.Probe.Run().factions
        assertEqual(f.source, "C_Reputation")
        assertEqual(f.count, 6, "every row, the collapsed header's child included")
        assertEqual(#f.rows, 6)
        assertEqual(f.rows[6].name, "Thorium Brotherhood")
        assertEqual(f.rows[3].isHeaderWithRep, true, "the raw table is kept whole")
        assertTrue(f.expanded, "the read expanded the collapsed header")
        assertEqual(spy.expand, 1); assertEqual(spy.collapse, 1)
        assertTrue(tree[2].collapsed, "the player's collapsed header is collapsed again")
    end)
end)

test("probe sections: at most 60 faction rows are written", function()
    withClient(function()
        local kids = {}
        for i = 1, 80 do kids[i] = { id = 1000 + i, name = "F" .. i, child = true } end
        installReps({ { id = 1, name = "Big", header = true, kids = kids } })
        local f = NS.Probe.Run().factions
        assertEqual(f.count, 81)
        assertEqual(#f.rows, 60, "the first 60 rows")
    end)
end)

test("probe sections: GetFactionDataByID is asked for a child of a collapsed header", function()
    withClient(function()
        installReps(repTree())
        local check = NS.Probe.Run().factions.byIDCollapsed
        assertEqual(check.header, "Other")
        assertEqual(check.factionID, 59)
        assertEqual(check.answered, true)
        assertEqual(check.data.name, "Thorium Brotherhood")
        installReps(repTree(), { byIDHidesCollapsed = true })
        check = NS.Probe.Run().factions.byIDCollapsed
        assertEqual(check.answered, false, "a client that hides it is reported, not raised")
    end)
end)

test("probe sections: never expands while the Reputation panel is shown or in combat", function()
    withClient(function()
        local tree = repTree()
        local spy = installReps(tree)
        M.ReputationFrame = { IsShown = function() return true end }
        local f = NS.Probe.Run().factions
        assertEqual(spy.expand, 0, "no header opened")
        assertEqual(f.expanded, false)
        assertEqual(f.skipped, "panel shown")
        assertEqual(f.count, 5, "the rows as listed")
        M.ReputationFrame = nil
        local realCombat = M.InCombatLockdown
        M.InCombatLockdown = function() return true end
        f = NS.Probe.Run().factions
        M.InCombatLockdown = realCombat
        assertEqual(spy.expand, 0)
        assertEqual(f.skipped, "combat")
    end)
end)

test("probe sections: currencies lists the whole list, opened and restored, with a by-id read", function()
    withClient(function()
        local tree = currencyTree()
        local spy = installCurrencies(tree)
        local c = NS.Probe.Run().currencies
        assertEqual(c.source, "C_CurrencyInfo")
        assertEqual(c.count, 4)
        assertEqual(#c.rows, 4)
        assertEqual(c.rows[4].name, "Darkmoon Prize Ticket")
        assertEqual(c.rows[1].currencyListDepth, 0)
        assertEqual(spy.expand, 1)
        assertTrue(tree[2].collapsed, "collapsed again")
        assertEqual(c.byID.currencyID, 1901, "the first currency read by id")
        assertEqual(c.byID.data.quantity, 1200)
    end)
end)

test("probe sections: never opens the currency list while the Currency tab is shown", function()
    withClient(function()
        local spy = installCurrencies(currencyTree())
        M.TokenFrame = { IsShown = function() return true end }
        local c = NS.Probe.Run().currencies
        assertEqual(spy.expand, 0)
        assertEqual(c.skipped, "panel shown")
        assertEqual(c.count, 3)
    end)
end)

test("probe sections: an absent API answers its section's source as none, never raises", function()
    withClient(function()
        M.C_Reputation, M.C_CurrencyInfo = nil, nil
        local restore = installStatistics()
        M.GetStatisticsCategoryList = nil
        local ok, r = pcall(NS.Probe.Run)
        restore()
        assertTrue(ok, tostring(r))
        assertEqual(r.factions.source, "none")
        assertEqual(r.currencies.source, "none")
        assertEqual(r.statistics.source, "none")
    end)
end)

test("probe sections: statistics is the category tree with up to 3 raw rows each", function()
    withClient(function()
        local restore = installStatistics()
        local s = NS.Probe.Run().statistics
        restore()
        assertEqual(s.source, "GetStatisticsCategoryList")
        assertEqual(#s.categories, 3)
        local wealth = s.categories[2]
        assertEqual(wealth.id, 140); assertEqual(wealth.name, "Wealth"); assertEqual(wealth.parent, 130)
        assertEqual(wealth.numRows, 5)
        assertEqual(#wealth.rows, 3, "three rows per category")
        assertEqual(wealth.rows[1].quantity, 1234567)
        assertEqual(wealth.rows[1].name, "Total gold acquired")
        assertEqual(wealth.rows[2].skip, true, "skip kept as the client answered it")
        assertEqual(wealth.rows[3].statID, NS.Probe.NIL, "a nil statID is written as the nil marker")
        assertEqual(s.categories[1].rows[2].quantity, "--", "a string quantity kept verbatim")
        assertEqual(#s.categories[3].rows, 0)
    end)
end)

test("probe sections: statistics records whether the Retail form GetStatistic(statID) answers, under pcall", function()
    withClient(function()
        local restore = installStatistics()
        local s = NS.Probe.Run().statistics
        restore()
        assertEqual(s.retailForm.statID, 1)
        assertEqual(s.retailForm.ok, false, "the fake raises on the one-argument form")
        assertTrue(s.retailForm.error:find("Usage", 1, true) ~= nil, "the error text is kept")
    end)
end)
