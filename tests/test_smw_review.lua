-- tests/test_smw_review.lua — the fix pass on the six-windows run's independent review (SMW-REV, item list in
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md): each case pins one finding the review raised and
-- the run fixed. Its own small client fixtures, so it leans on no other suite's locals.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ---------------------------------------------------------------------------------------------
-- A Currency tab: Player vs. Player (Honor Points, capped), Miscellaneous (collapsed: Darkmoon Prize Ticket, no
-- cap)
-- ---------------------------------------------------------------------------------------------

local CD = NS.CurrencyData

local function currencies()
    return {
        { name = "Player vs. Player", header = true, depth = 0, kids = {
            { id = 1901, name = "Honor Points", quantity = 1200, max = 75000, depth = 1 },
        } },
        { name = "Miscellaneous", header = true, depth = 0, collapsed = true, kids = {
            { id = 515, name = "Darkmoon Prize Ticket", quantity = 12, max = 0, depth = 1 },
        } },
    }
end

local function flatCurrencies(tree)
    local out = {}
    for _, top in ipairs(tree) do
        out[#out + 1] = top
        if not top.collapsed then for _, k in ipairs(top.kids) do out[#out + 1] = k end end
    end
    return out
end

local function currencyInfo(n)
    return { name = n.name, currencyID = n.id or 0, isHeader = n.header or false,
             isHeaderExpanded = n.header and not n.collapsed or false, currencyListDepth = n.depth,
             quantity = n.quantity or 0, maxQuantity = n.max or 0 }
end

local function installCurrencies(tree)
    local spy, byID = { expand = 0, collapse = 0 }, {}
    for _, top in ipairs(tree) do for _, k in ipairs(top.kids) do byID[k.id] = k end end
    M.C_CurrencyInfo = {
        GetCurrencyListSize = function() return #flatCurrencies(tree) end,
        GetCurrencyListInfo = function(i) local n = flatCurrencies(tree)[i]; return n and currencyInfo(n) end,
        ExpandCurrencyList = function(i, open)
            local n = flatCurrencies(tree)[i]
            if open then spy.expand = spy.expand + 1 else spy.collapse = spy.collapse + 1 end
            n.collapsed = not open
        end,
        GetCurrencyInfo = function(id) local n = byID[id]; return n and currencyInfo(n) end,
    }
    return spy
end

local function withCurrencies(fn)
    local saved = { M.C_CurrencyInfo, M.TokenFrame, M.InCombatLockdown }
    local savedFold, savedPins, savedLog = NS.db.char.fold, NS.db.char.pins, NS.db.char.log
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = {}, {}, {}
    M.InCombatLockdown = function() return false end
    CD:Reset()
    local ok, err = pcall(fn)
    M.C_CurrencyInfo, M.TokenFrame, M.InCombatLockdown = unpack(saved, 1, 3)
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = savedFold, savedPins, savedLog
    CD:Reset()
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end

local function windowRow(fid, key)
    local W = NS.Windows.Get(fid)
    W.Show()
    W.Refresh(true)
    for _, r in ipairs(W.Rows()) do if r.entry and r.entry.key == key then return r end end
    return nil
end

local function pinRowOf(row)
    for _, r in ipairs(NS.Interact.MenuRows(row)) do if r.value == "pin" then return r end end
    return nil
end

test("smw-rev: a currency with no cap is pinnable from its row's menu; a header is not", function()
    withCurrencies(function()
        installCurrencies(currencies())
        CD:Read()
        local ticket = windowRow("currencies", "515")
        assertTrue(ticket ~= nil, "Darkmoon Prize Ticket's row")
        assertFalse(ticket.entry.hasBar, "no cap, no bar")
        local pin = pinRowOf(ticket)
        assertTrue(pin ~= nil, "an uncapped currency still pins")
        assertEqual(pin.label, "Pin to the Currencies broker")
        local honor = windowRow("currencies", "1901")
        assertTrue(pinRowOf(honor) ~= nil, "a capped one too")
        local header = windowRow("currencies", "h:Miscellaneous#0")
        assertTrue(header ~= nil, "the Miscellaneous header's row")
        assertEqual(pinRowOf(header), nil, "a header pins nothing")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- A Reputation tab: Alliance (Stormwind), then Other (collapsed: Thorium Brotherhood)
-- ---------------------------------------------------------------------------------------------

local RD = NS.RepData

local function factions()
    return {
        { id = 469, name = "Alliance", header = true, kids = {
            { id = 72, name = "Stormwind", reaction = 6, lo = 9000, hi = 21000, cur = 12672 },
        } },
        { id = 1169, name = "Other", header = true, collapsed = true, kids = {
            { id = 59, name = "Thorium Brotherhood", reaction = 5, lo = 3000, hi = 9000, cur = 4000 },
        } },
    }
end

local function flatFactions(tree)
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

local function factionData(n)
    return { factionID = n.id, name = n.name, isHeader = n.header or false, isChild = false,
             isHeaderWithRep = false, isCollapsed = n.collapsed or false, reaction = n.reaction or 4,
             currentReactionThreshold = n.lo or 0, nextReactionThreshold = n.hi or 0, currentStanding = n.cur or 0 }
end

local function installFactions(tree)
    local spy, byID = { expand = 0, collapse = 0 }, {}
    local function index(nodes)
        for _, n in ipairs(nodes) do byID[n.id] = n; if n.kids then index(n.kids) end end
    end
    index(tree)
    spy.byID = byID
    M.C_Reputation = {
        GetNumFactions = function() return #flatFactions(tree) end,
        GetFactionDataByIndex = function(i) local n = flatFactions(tree)[i]; return n and factionData(n) end,
        GetFactionDataByID = function(id) local n = byID[id]; return n and factionData(n) end,
        ExpandFactionHeader = function(i)
            spy.expand = spy.expand + 1
            flatFactions(tree)[i].collapsed = false
        end,
        CollapseFactionHeader = function(i) spy.collapse = spy.collapse + 1; flatFactions(tree)[i].collapsed = true end,
    }
    return spy
end

local function withFactions(fn)
    local saved = { M.C_Reputation, M.ReputationFrame, M.InCombatLockdown, M.GetText, M.UnitSex }
    local savedFold, savedPins, savedLog = NS.db.char.fold, NS.db.char.pins, NS.db.char.log
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = {}, {}, {}
    M.GetText = function() return "Friendly" end
    M.UnitSex = function() return 2 end
    M.InCombatLockdown = function() return false end
    RD:Reset()
    local ok, err = pcall(fn)
    M.C_Reputation, M.ReputationFrame, M.InCombatLockdown, M.GetText, M.UnitSex = unpack(saved, 1, 5)
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = savedFold, savedPins, savedLog
    RD:Reset()
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end

-- A panel tab the character panel last showed, then closed: its own shown flag stays up, but it is not visible.
local function closedPanelTab()
    return { IsShown = function() return true end, IsVisible = function() return false end,
             HookScript = function() end }
end

test("smw-rev: a Reputation or Currency tab left selected in a closed character panel does not block the full read", function()
    withFactions(function()
        local spy = installFactions(factions())
        M.ReputationFrame = closedPanelTab()
        assertEqual(NS.SharedList.Blocked(RD.LIST), nil, "the panel is closed: nothing blocks")
        local m = RD:Read()
        assertTrue(m.complete, "read in full")
        assertEqual(spy.expand, 1, "the collapsed Other opened")
        assertTrue(RD:Get(59) ~= nil, "Thorium Brotherhood, under it, is in")
        M.ReputationFrame = { IsShown = function() return true end, IsVisible = function() return true end,
                              HookScript = function() end }
        assertEqual(NS.SharedList.Blocked(RD.LIST), "panel shown", "a tab on screen still blocks")
    end)
    withCurrencies(function()
        local spy = installCurrencies(currencies())
        M.TokenFrame = closedPanelTab()
        local m = CD:Read()
        assertTrue(m.complete, "the currencies read in full too")
        assertEqual(spy.expand, 1)
    end)
end)

test("smw-rev: a new faction met in combat keeps every faction under a collapsed header; combat's end reads in full", function()
    withFactions(function()
        local tree = factions()
        local spy = installFactions(tree)
        RD:Read()
        assertTrue(RD:Get(59) ~= nil, "the full read has Thorium Brotherhood, under the collapsed Other")
        M.InCombatLockdown = function() return true end
        table.insert(tree[1].kids, { id = 930, name = "Exodar", reaction = 4, lo = 0, hi = 3000, cur = 10 })
        spy.byID[930] = tree[1].kids[2]
        local expands = spy.expand
        RD:Refresh()
        assertTrue(RD:Get(59) ~= nil, "Thorium Brotherhood is still in the model")
        assertTrue(RD:Get(72) ~= nil, "and Stormwind")
        assertFalse(RD:Model().complete, "the model waits for the full read")
        assertEqual(spy.expand, expands, "no header opened in combat")
        M.InCombatLockdown = function() return false end
        M.__fireTimers()
        RD.OnEvent("PLAYER_REGEN_ENABLED")
        M.__fireTimers()
        assertTrue(RD:Model().complete, "read in full as combat ends")
        assertTrue(RD:Get(930) ~= nil and RD:Get(59) ~= nil, "the new faction and the collapsed one both")
    end)
end)

test("smw-rev: a new currency met in combat keeps every currency under a collapsed header; combat's end reads in full", function()
    withCurrencies(function()
        local tree = currencies()
        installCurrencies(tree)
        CD:Read()
        assertTrue(CD:Get(515) ~= nil, "Darkmoon Prize Ticket, under the collapsed Miscellaneous")
        M.InCombatLockdown = function() return true end
        table.insert(tree[1].kids, { id = 1792, name = "Marks of Honor", quantity = 3, max = 0, depth = 1 })
        CD:Refresh()
        assertTrue(CD:Get(515) ~= nil, "Darkmoon Prize Ticket is still in the model")
        assertFalse(CD:Model().complete, "the model waits for the full read")
        M.InCombatLockdown = function() return false end
        M.__fireTimers()
        CD.OnEvent("PLAYER_REGEN_ENABLED")
        M.__fireTimers()
        assertTrue(CD:Model().complete, "read in full as combat ends")
        assertTrue(CD:Get(1792) ~= nil and CD:Get(515) ~= nil, "the new currency and the collapsed one both")
    end)
end)

test("smw-rev: a list read that raises after opening a header still closes what it opened, then raises", function()
    local rows = {
        { key = "A", isHeader = true, closed = true },
        { key = "a1" },
        { key = "B", isHeader = true, closed = true },
    }
    local shown = { rows[1], rows[3] }   -- A and B, both collapsed
    local opens, closes, raised = 0, 0, false
    local list = {
        name = "smw-rev-raise",
        count = function() return #shown end,
        row = function(i)
            if opens == 1 and not raised and shown[i] == rows[3] then
                raised = true
                error("an odd row")
            end
            return shown[i]
        end,
        isClosed = function(r) return r.isHeader == true and r.closed == true end,
        key = function(r) return r.key end,
        toggle = function(i, open)
            local r = shown[i]
            if open then
                opens = opens + 1
                r.closed = false
                if r == rows[1] then table.insert(shown, i + 1, rows[2]) end
            else
                closes = closes + 1
                r.closed = true
                if r == rows[1] then table.remove(shown, i + 1) end
            end
            return true
        end,
        canToggle = function() return true end,
    }
    local saved = M.InCombatLockdown
    M.InCombatLockdown = function() return false end
    local ok, err = pcall(NS.SharedList.Read, list)
    M.InCombatLockdown = saved
    assertFalse(ok, "the error still reaches the caller")
    assertTrue(tostring(err):find("an odd row", 1, true) ~= nil, tostring(err))
    assertEqual(opens, 1, "A opened before the raise")
    assertEqual(closes, opens, "and closed again: the panel's collapse is as it was")
    assertTrue(rows[1].closed, "A is collapsed")
    assertFalse(NS.SharedList.Busy(list.name), "the latch is down")
end)

-- ---------------------------------------------------------------------------------------------
-- The Statistics tab (tests/fixture_statistics.lua's small tree: Character 130 > Wealth 140, Combat 150)
-- ---------------------------------------------------------------------------------------------

local SD = NS.StatisticsData
local fx = dofile("tests/fixture_statistics.lua")

local function withStatistics(fn)
    local savedFold, savedPins = NS.db.char.fold, NS.db.char.pins
    NS.db.char.fold, NS.db.char.pins = {}, {}
    SD:Reset()
    M.__fireTimers()
    local spy, restore = fx.install(M)
    local ok, err = pcall(fn, spy)
    NS.Broker.HideTooltip()
    NS.Broker.SetFeed(NS.Broker.DEFAULT_FEED)
    NS.Windows.HideAll()
    restore()
    NS.db.char.fold, NS.db.char.pins = savedFold, savedPins
    SD:Reset()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function statisticsRows()
    local W = NS.Windows.Get("statistics")
    W.Refresh(true)
    return W.Rows()
end

test("smw-rev: the Statistics window reopened reads its unfolded categories afresh, not as it last saw them", function()
    withStatistics(function(spy)
        local W = NS.Windows.Get("statistics")
        W.Show()
        statisticsRows()
        NS.Tree.SetFolded("statistics", 130, false)
        statisticsRows()
        assertEqual(SD:Get("130:9001").text, "58")
        W.Hide()
        assertFalse(SD:IsWatching(), "closed: nothing kept it current")
        spy.stat[9001] = 61
        W.Show()
        statisticsRows()
        assertEqual(SD:Get("130:9001").text, "61", "the value read again as the window came back")
        local reads = spy.calls.GetStatistic
        statisticsRows()
        assertEqual(spy.calls.GetStatistic, reads, "a redraw while it shows reads nothing more")
    end)
end)

test("smw-rev: the Statistics tooltip shown again reads what it unfolds afresh", function()
    withStatistics(function(spy)
        NS.Broker.TooltipToggled("statistics")
        SD:Open(NS.Broker.TipNodeStore("statistics"))
        NS.Tree.SetFolded("statistics", 150, false, NS.Broker.TipNodeStore("statistics"))
        SD:Open(NS.Broker.TipNodeStore("statistics"))
        assertEqual(SD:Get("150:9301").text, "1,200")
        NS.Broker.TooltipToggled(nil)
        spy.stat[9301] = 1300
        NS.Broker.TooltipToggled("statistics")
        SD:Open(NS.Broker.TipNodeStore("statistics"))
        assertEqual(SD:Get("150:9301").text, "1,300", "the tooltip's unfolded Combat read again")
        NS.Broker.TooltipToggled(nil)
        local ldb = NS.db.profile.tooltips.ldb
        if ldb.folds and ldb.folds.nodes then ldb.folds.nodes.statistics = nil end
    end)
end)

test("smw-rev: with the window hidden and one statistic pinned, CRITERIA_UPDATE reads the pinned row alone", function()
    withStatistics(function(spy)
        local W = NS.Windows.Get("statistics")
        W.Show()
        statisticsRows()
        NS.Tree.SetFolded("statistics", 130, false)
        NS.Tree.SetFolded("statistics", 150, false)
        statisticsRows()
        NS.Pins.Toggle("statistics", "150:9301")
        W.Hide()
        assertTrue(SD:IsWatching(), "pinned: still watching")
        local before = spy.calls.GetStatistic
        spy.stat[9301] = 1250
        M.__fireEvent("CRITERIA_UPDATE")
        M.__fireTimers()
        assertEqual(spy.calls.GetStatistic - before, 1, "Total kills alone; Character, unfolded in the hidden window, not")
        assertEqual(NS.Broker.FeedText("statistics"), "Total kills 1,250")
        spy.stat[9001] = 70
        W.Show()
        statisticsRows()
        assertEqual(SD:Get("130:9001").text, "70", "the hidden window's categories read as it comes back")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- The session log
-- ---------------------------------------------------------------------------------------------

test("smw-rev: a reputation's later change moves its one Log line to the end, so the Log stays in time order", function()
    local SL = NS.SessionLog
    local savedLog, savedStart = NS.db.char.log, SL:SessionStart()
    NS.db.char.log = {}
    SL:ResetFloor()
    SL:NewSession(1000)
    local ok, err = pcall(function()
        SL:AddChange("reputation", "21", "Booty Bay", 6000, 6100, 1000)
        SL:Add("fishing", 50, 51, 1100)
        local e = SL:AddChange("reputation", "21", "Booty Bay", 6100, 6250, 1200)
        local log = SL:Entries()
        assertEqual(#log, 2, "still one line for the faction")
        assertEqual(log[1].key, "fishing", "the skill-up first")
        assertEqual(log[2], e, "the faction's line last")
        assertEqual(e.t, 1200, "at its latest change")
        assertEqual(e.old .. ">" .. e.new, "6000>6250", "the session's whole change")
        for i = 2, #log do assertTrue(log[i - 1].t <= log[i].t, "in time order") end
        assertEqual(SL:KindGainsFor("reputation", "21"), 250)
    end)
    NS.db.char.log = savedLog
    SL:NewSession(savedStart)
    SL:ResetFloor()
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- The broker feeds' context
-- ---------------------------------------------------------------------------------------------

test("smw-rev: the feeds read the main hand and the level only for a template that shows them", function()
    local H, P = NS.SkillHelpers, NS.Preview
    local realSlot, realChar = H.WeaponSkillInSlot, P.Character
    local slots, chars = 0, 0
    H.WeaponSkillInSlot = function(...) slots = slots + 1 return realSlot(...) end
    P.Character = function(...) chars = chars + 1 return realChar(...) end
    local tpl = NS.db.profile.broker.feeds.professions
    local saved = tpl.template
    local ok, err = pcall(function()
        NS.Broker.Refresh()
        assertEqual(slots, 0, "no feed's template shows {equippedWeapon}: the main hand is not read")
        assertEqual(chars, 0, "nor {level}: the level is not read")
        tpl.template = "{equippedWeapon} {level}"
        NS.Broker.Refresh()
        assertEqual(slots, 1, "the one feed that shows the weapon reads it once")
        assertEqual(chars, 1, "and the level once")
        assertEqual(NS.Broker.Context().level ~= nil, true, "a context still answers its level when asked")
    end)
    tpl.template = saved
    H.WeaponSkillInSlot, P.Character = realSlot, realChar
    NS.Broker.Refresh()
    if not ok then error(err, 0) end
end)
