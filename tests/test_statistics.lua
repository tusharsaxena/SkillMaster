-- tests/test_statistics.lua — the Statistics window (item SMW-10 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md, the spec's "Statistics (new)"): StatisticsData's
-- category tree in Forever's form GetStatistic(categoryID, index), the lazy fold-driven reads (a category's
-- rows only once it unfolds), CRITERIA_UPDATE registered only while the Statistics show or one is pinned and
-- debounced to one re-read, pins, the tooltip's own folds, no Alts sub-tab, and the perf bucket.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SD = NS.StatisticsData
local fx = dofile("tests/fixture_statistics.lua")

local function withClient(fn, tree)
    local savedFold, savedPins = NS.db.char.fold, NS.db.char.pins
    NS.db.char.fold, NS.db.char.pins = {}, {}
    local ldb = NS.db.profile.tooltips.ldb
    local savedNodes = ldb.folds and ldb.folds.nodes and ldb.folds.nodes.statistics
    SD:Reset()
    M.__fireTimers()
    local spy, restore = fx.install(M, tree)
    local ok, err = pcall(fn, spy)
    NS.Broker.HideTooltip()
    NS.Broker.SetFeed(NS.Broker.DEFAULT_FEED)
    NS.Windows.HideAll()
    restore()
    NS.db.char.fold, NS.db.char.pins = savedFold, savedPins
    if ldb.folds and ldb.folds.nodes then ldb.folds.nodes.statistics = savedNodes end
    SD:Reset()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function calls(spy, name) return spy.calls[name] or 0 end

local function names(rows)
    local out = {}
    for i, r in ipairs(rows) do
        local e = r.entry
        out[i] = e.header and ("[" .. e.name .. "]") or (e.name .. "=" .. SD.ValueText(e))
    end
    return table.concat(out, ",")
end

local function windowRows()
    local W = NS.Windows.Get("statistics")
    W.Refresh(true)
    return W.Rows()
end

local function open(key, store)
    NS.Tree.SetFolded("statistics", key, false, store)
end

test("statistics: the category tree is depth first, a parent of -1 or one the list lacks a root, a cycle survives", function()
    local tree = SD.BuildTree({
        { id = 1, name = "A", parent = -1 }, { id = 2, name = "B", parent = 1 }, { id = 3, name = "C", parent = 9 },
        { id = 4, name = "D", parent = 2 }, { id = 5, name = "E", parent = 6 }, { id = 6, name = "F", parent = 5 },
    })
    local out = {}
    for i, n in ipairs(tree) do out[i] = n.name .. n.depth end
    assertEqual(table.concat(out, ","), "A0,B1,D2,C0,E0,F1")
end)

test("statistics: a value shows as the tab shows it: the number, -- for none, a string verbatim", function()
    assertEqual(SD.Display(58), "58")
    assertEqual(SD.Display(123456), "123,456")
    assertEqual(SD.Display(0), "--")
    assertEqual(SD.Display(nil), "--")
    assertEqual(SD.Display("12"), "12")
    assertEqual(SD.Display("0"), "--")
    assertEqual(SD.Display("1g 20s"), "1g 20s")
end)

test("statistics: the first look reads the category tree only; every category starts folded", function()
    withClient(function(spy)
        assertEqual(SD:Model(), nil, "nothing read before first use")
        assertEqual(calls(spy, "GetCategoryInfo"), 0, "no read at load")
        NS.Windows.Get("statistics").Show()
        assertEqual(names(windowRows()), "[Character],[Combat]")
        assertEqual(calls(spy, "GetCategoryInfo"), 4, "one GetCategoryInfo per category")
        assertEqual(calls(spy, "GetStatistic"), 0, "no row read while every category is folded")
        assertEqual(calls(spy, "GetStatisticsCategoryList"), 1, "the tree is built once")
        windowRows()
        assertEqual(calls(spy, "GetStatisticsCategoryList"), 1)
    end)
end)

test("statistics: unfolding a category reads its rows alone, in Forever's two-argument form; names are cached", function()
    withClient(function(spy)
        NS.Windows.Get("statistics").Show()
        windowRows()
        open(130)
        assertEqual(names(windowRows()),
            "[Character],Times camped=58,Talent tree respecs=--,[Wealth],[Consumables],[Combat]",
            "Character's rows first, then its folded sub-categories; a skipped row left out")
        assertEqual(calls(spy, "GetStatistic"), 3, "Character's three rows, read by (categoryID, index)")
        assertEqual(calls(spy, "GetAchievementInfo"), 2, "a name per shown row")
        open(140)
        assertEqual(names(windowRows()),
            "[Character],Times camped=58,Talent tree respecs=--,[Wealth],Total gold acquired=123,456,"
            .. "Auctions posted=33,[Consumables],[Combat]", "multi-level folding: Wealth under Character")
        assertEqual(calls(spy, "GetStatistic"), 5, "only Wealth's two more")
        NS.Tree.SetFolded("statistics", 130, true)
        assertEqual(names(windowRows()), "[Character],[Combat]", "folding the parent hides the open child")
        assertEqual(calls(spy, "GetStatistic"), 5, "a fold reads nothing")
        NS.Tree.SetFolded("statistics", 130, false)
        assertEqual(names(windowRows()):find("Total gold acquired", 1, true) ~= nil, true, "Wealth kept its own fold")
        assertEqual(NS.db.char.fold.statistics["140"], false, "the fold is this addon's own (char.fold)")
    end)
end)

test("statistics: CRITERIA_UPDATE is registered only while the window or its tooltip shows, or one is pinned", function()
    withClient(function()
        assertFalse(SD:Watch(), "nothing shows, nothing pinned")
        local W = NS.Windows.Get("statistics")
        W.Show()
        assertTrue(SD:IsWatching(), "the window shows")
        W.Hide()
        assertFalse(SD:IsWatching(), "the window hid")
        NS.Broker.TooltipToggled("statistics")
        assertTrue(SD:IsWatching(), "its tooltip is up")
        assertTrue(SD:Model() ~= nil, "the tooltip's first use built the tree before the fill")
        NS.Broker.TooltipToggled(nil)
        assertFalse(SD:IsWatching(), "the tooltip went")
        NS.Broker.TooltipToggled("reputations")
        assertFalse(SD:IsWatching(), "another feed's tooltip is not the Statistics'")
        NS.Broker.TooltipToggled(nil)
        NS.Pins.Toggle("statistics", "130:9001")
        assertTrue(SD:IsWatching(), "a pinned statistic keeps it while nothing shows")
        NS.Pins.Toggle("statistics", "130:9001")
        assertFalse(SD:IsWatching(), "unpinned")
    end)
end)

test("statistics: a burst of CRITERIA_UPDATE is one re-read a second later, of the unfolded categories only", function()
    withClient(function(spy)
        local W = NS.Windows.Get("statistics")
        W.Show()
        windowRows()
        open(130)
        open(140)
        windowRows()
        NS.Tree.SetFolded("statistics", 140, true)
        windowRows()
        local seen = 0
        local target = NS.NewBusTarget()
        target:RegisterMessage(NS.MSG.STATISTICS_UPDATED, function() seen = seen + 1 end)
        spy.stat[9001] = 59
        spy.stat[9101] = 200000
        local before, names0 = calls(spy, "GetStatistic"), calls(spy, "GetAchievementInfo")
        for _ = 1, 5 do M.__fireEvent("CRITERIA_UPDATE") end
        assertEqual(calls(spy, "GetStatistic"), before, "no read on the event itself")
        M.__fireTimers()
        target:UnregisterAllMessages()
        assertEqual(seen, 1, "one re-read for the burst")
        assertEqual(calls(spy, "GetStatistic") - before, 3, "Character's rows; Wealth folded, not read")
        assertEqual(calls(spy, "GetAchievementInfo"), names0, "the names came from the session's cache")
        assertEqual(SD:Get("130:9001").text, "59")
        assertEqual(SD:Get("140:9101").text, "123,456", "the folded Wealth kept its last value")
        open(140)
        windowRows()
        assertEqual(SD:Get("140:9101").text, "200,000", "a stale category reads again as it unfolds")
    end)
end)

test("statistics: with nothing showing, CRITERIA_UPDATE reads nothing and the registration goes", function()
    withClient(function(spy)
        local W = NS.Windows.Get("statistics")
        W.Show()
        windowRows()
        M.__fireEvent("CRITERIA_UPDATE")
        W.Hide()
        local before = calls(spy, "GetStatistic")
        M.__fireTimers()
        M.__fireEvent("CRITERIA_UPDATE")
        M.__fireTimers()
        assertEqual(calls(spy, "GetStatistic"), before, "no read once hidden")
        assertFalse(SD:IsWatching())
    end)
end)

test("statistics: a pinned statistic shows in its broker's text and is read alone, by its index, while hidden", function()
    withClient(function(spy)
        local W = NS.Windows.Get("statistics")
        W.Show()
        windowRows()
        open(130)
        local row
        for _, r in ipairs(windowRows()) do if r.entry.key == "130:9001" then row = r end end
        assertTrue(row ~= nil, "Times camped's row")
        local pin
        for _, r in ipairs(NS.Interact.MenuRows(row)) do if r.value == "pin" then pin = r end end
        assertTrue(pin ~= nil, "a statistic is pinnable")
        assertEqual(pin.label, "Pin to the Statistics broker")
        pin.onClick()
        assertTrue(NS.Pins.Has("statistics", "130:9001"))
        assertEqual(NS.Broker.FeedText("statistics"), "Times camped 58")
        assertEqual(NS.Interact.LinkText(row), "[Times camped: 58]")
        local hasPin = false
        for _, r in ipairs(NS.Interact.MenuRows(windowRows()[1])) do if r.value == "pin" then hasPin = true end end
        assertFalse(hasPin, "a category pins nothing")
        NS.Tree.SetFolded("statistics", 130, true)
        W.Hide()
        assertTrue(SD:IsWatching(), "pinned: still watching")
        spy.stat[9001] = 60
        local before = calls(spy, "GetStatistic")
        M.__fireEvent("CRITERIA_UPDATE")
        M.__fireTimers()
        assertEqual(calls(spy, "GetStatistic") - before, 1, "the pinned row alone, by its index")
        assertEqual(NS.Broker.FeedText("statistics"), "Times camped 60")
        -- The row moved: the client lists a new one first; the pin is found again by its statID.
        table.insert(spy.byId[130].rows, 1, { statID = 9004, name = "Deaths", quantity = 3 })
        M.__fireEvent("CRITERIA_UPDATE")
        M.__fireTimers()
        assertEqual(SD:Get("130:9001").index, 2, "re-resolved by statID")
        assertEqual(NS.Broker.FeedText("statistics"), "Times camped 60")
    end)
end)

test("statistics: at login a pinned statistic's category is read for the feed, and nothing else", function()
    withClient(function(spy)
        NS.db.char.pins = { statistics = { "140:9102" } }
        M.__fireEvent("PLAYER_ENTERING_WORLD")
        assertEqual(calls(spy, "GetStatistic"), 2, "Wealth's rows only")
        assertEqual(NS.Broker.FeedText("statistics"), "Auctions posted 33")
        assertTrue(SD:IsWatching())
    end)
end)

test("statistics: the tooltip folds in its own folds and reads what it unfolds; the window's folds stay", function()
    withClient(function(spy)
        local ldb = NS.db.profile.tooltips.ldb
        local style = ldb.style
        ldb.style = "window"
        local ok, err = pcall(function()
            NS.Broker.OnEnter(M.UIParent, "statistics")
            local P = NS.BrokerPanel
            local first
            for _, r in ipairs(P.Rows()) do if r.treeHeader then first = first or r end end
            assertTrue(first ~= nil, "a category in the tooltip")
            assertEqual(calls(spy, "GetStatistic"), 0, "folded in the tooltip too")
            local n = #P.Rows()
            NS.Rows.Fold(first)
            assertTrue(#P.Rows() > n, "the tooltip redrew Character open")
            assertEqual(calls(spy, "GetStatistic"), 3, "and read its rows")
            assertTrue(NS.Tree.IsFolded("statistics", "130"), "the window's fold untouched")
            assertTrue(SD:IsWatching(), "watching while the tooltip is up")
        end)
        NS.Broker.HideTooltip()
        ldb.style = style
        if not ok then error(err, 0) end
        assertFalse(SD:IsWatching(), "the tooltip went")
    end)
end)

test("statistics: the Classic tooltip lists the categories, each a chevron line", function()
    withClient(function()
        NS.Broker.TooltipToggled("statistics")
        local lines = {}
        local tip = { lines = lines }
        function tip:AddLine(t) lines[#lines + 1] = t end
        function tip:AddDoubleLine(a, b) lines[#lines + 1] = a .. " | " .. b end
        function tip:NumLines() return #lines end
        local rows = NS.Broker.FillTooltip(tip, "statistics")
        local nodes = 0
        for _, r in ipairs(rows) do if r.node then nodes = nodes + 1 end end
        assertEqual(nodes, 2, "Character and Combat, folded")
        NS.Broker.TooltipToggled(nil)
    end)
end)

test("statistics: a row's tooltip says its value and category; no Alts sub-tab; the empty window says so", function()
    withClient(function()
        NS.Windows.Get("statistics").Show()
        windowRows()
        open(130)
        windowRows()
        local text = {}
        for _, l in ipairs(NS.RowTooltip.Lines(SD:Get("130:9001"), "statistic")) do
            text[#text + 1] = (l.left or "") .. "=" .. (l.right or "")
        end
        assertEqual(table.concat(text, ";"), "Times camped=;Value=58;Category=Character")
        assertEqual(NS.Journal.FILTERS.statistics, nil, "Statistics has no Alts sub-tab (the spec's call)")
        for _, id in ipairs(NS.Journal.FILTER_ORDER) do assertTrue(id ~= "statistics") end
    end)
    withClient(function()
        NS.Windows.Get("statistics").Show()
        assertEqual(#windowRows(), 0)
        assertEqual(NS.Windows.EmptyText("statistics"), "No statistics to show yet.")
    end, {})
end)

test("statistics: test mode reads nothing of the live tab", function()
    withClient(function(spy)
        NS.State.testMode = true
        local ok, err = pcall(function()
            assertFalse(SD.Live(nil), "no live model while test mode runs")
            NS.Blocks.EntriesFrom("statistics", {})
            assertEqual(calls(spy, "GetCategoryInfo"), 0)
        end)
        NS.State.testMode = false
        if not ok then error(err, 0) end
    end)
end)

test("statistics: about 1000 rows read once each at two calls a row; a re-read costs one a row", function()
    withClient(function(spy)
        NS.Windows.Get("statistics").Show()
        windowRows()
        NS.Tree.SetAll("statistics", SD:Model().order, false)
        windowRows()
        assertEqual(calls(spy, "GetStatistic"), 1000)
        assertEqual(calls(spy, "GetAchievementInfo"), 1000)
        assertEqual(calls(spy, "GetCategoryNumAchievements"), 40)
        M.__fireEvent("CRITERIA_UPDATE")
        M.__fireTimers()
        assertEqual(calls(spy, "GetStatistic"), 2000, "one GetStatistic a row")
        assertEqual(calls(spy, "GetAchievementInfo"), 1000, "no name read again")
    end, fx.large(40, 25))
end)

test("statistics: the statisticsRead perf bucket is noted while a capture is on, and nothing while off", function()
    withClient(function()
        local P = NS.Perf
        local realNote, seen = P.Note, {}
        P.Note = function(key) seen[key] = (seen[key] or 0) + 1 end
        local ok, err = pcall(function()
            P.on = false
            SD:Open()
            assertEqual(seen.statisticsRead, nil, "noted with capture off")
            SD:Reset()
            P.on = true
            SD:Open()
        end)
        P.on = false
        P.Note = realNote
        if not ok then error(err, 0) end
        assertTrue((seen.statisticsRead or 0) >= 1, "statisticsRead was never reached")
    end)
end)
