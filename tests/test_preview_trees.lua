-- tests/test_preview_trees.lua — test mode, the preview and the simulator for the three tree families (item
-- SMW-11 of docs/superpowers/plans/2026-11-26-skillmaster-windows.md, the spec's "Test mode, preview and the
-- simulator"): the sample character's reputations (the panel's headers), currencies and Statistics tab drawn
-- through the live builders, their feeds and pins, the Alts record; the simulator's world read through the
-- seam, a reputation and a currency raised by its steps, and the live state back at the stop.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local H = NS.SimHost

-- The client's standing names (GetText(FACTION_STANDING_LABELn, sex)), as tests/test_reputations.lua mocks them;
-- every case runs inside this.
local LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
local function case(name, fn)
    test(name, function()
        local saved = { M.GetText, M.UnitSex }
        M.GetText = function(key) return LABELS[tonumber(key:match("(%d+)$"))] end
        M.UnitSex = function() return 2 end
        local ok, err = pcall(fn)
        M.GetText, M.UnitSex = saved[1], saved[2]
        if not ok then error(err, 0) end
    end)
end

local function testModeOff()
    if NS.IsTestMode() then NS.ToggleTestMode() end
end

local function stopAll()
    if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
    NS.Sim:HidePanel()
    testModeOff()
    M.__fireTimers()
end

local function names(rows)
    local out = {}
    for i, r in ipairs(rows) do
        local e = r.entry
        local spec = NS.Tree.Kind(r.kind)
        local value = spec and spec.valueText(e) or ""
        out[i] = e.header and ("[" .. e.name .. "]") or (value ~= "" and (e.name .. "=" .. value) or e.name)
    end
    return table.concat(out, ",")
end

local function windowRows(fid)
    local W = NS.Windows.Get(fid)
    W.Show()
    W.Refresh(true)
    return W.Rows()
end

-- The live tab's APIs, counted: test mode must read none of them.
local function countLive()
    local n = { calls = 0 }
    local saved = { M.GetStatisticsCategoryList, M.C_Reputation, M.C_CurrencyInfo }
    M.GetStatisticsCategoryList = function() n.calls = n.calls + 1 return {} end
    M.C_Reputation = { GetNumFactions = function() n.calls = n.calls + 1 return 0 end,
                       GetFactionDataByIndex = function() n.calls = n.calls + 1 end }
    M.C_CurrencyInfo = { GetCurrencyListSize = function() n.calls = n.calls + 1 return 0 end,
                         GetCurrencyListInfo = function() n.calls = n.calls + 1 end }
    function n.restore() M.GetStatisticsCategoryList, M.C_Reputation, M.C_CurrencyInfo = unpack(saved, 1, 3) end
    return n
end

case("preview trees: the sample's records come in the panels' shapes, built by the live builders", function()
    local rows = NS.Preview.FactionRows()
    assertEqual(rows[1].name, "Alliance")
    assertTrue(rows[1].isHeader and not rows[1].isChild, "a top header")
    local m = NS.RepData.Build(rows)
    assertEqual(m.byKey["72"].name, "Stormwind")
    assertEqual(NS.RepData.ValueText(m.byKey["72"]), "Honored 3,672 / 12,000", "the owner's screenshot's bar")
    assertEqual(m.byKey["72"].depth, 1)
    local cur = NS.CurrencyData.Build(NS.Preview.CurrencyRows())
    assertEqual(NS.CurrencyData.ValueText(cur.byKey["1901"]), "1,200 / 75,000")
    assertEqual(NS.CurrencyData.ValueText(cur.byKey["515"]), "12")
    for _, e in ipairs(cur.order) do assertTrue(e.name ~= "Gold", "no gold (the owner's ruling)") end
    local st = NS.StatisticsData.Build(NS.Preview.StatisticsList())
    local order = {}
    for i, e in ipairs(st.order) do order[i] = e.name .. e.depth end
    assertEqual(table.concat(order, ","), "Character0,Times camped1,Talent tree respecs1,Wealth1,Total gold acquired2,"
        .. "Auctions posted2,Consumables1,Beverages consumed2,Bandages used2,Combat0,Total kills1,Deaths0,Total deaths1")
    assertEqual(st.byKey["130:1533"].text, "--")
    assertEqual(st.byKey["140:328"].category, "Wealth")
end)

case("preview trees: test mode draws the sample in the three windows, reading nothing of the live client", function()
    stopAll()
    local live = countLive()
    local savedFold = NS.db.char.fold
    NS.db.char.fold = {}
    local ok, err = pcall(function()
        assertTrue(NS.ToggleTestMode(), "test mode on")
        -- The session's folds outlive a case (they last until the UI reloads): start from the defaults' look.
        local _, _, models = NS.Blocks.Data()
        NS.Tree.SetAll("reputations", models.reputations.order, false)
        NS.Tree.SetAll("currencies", models.currencies.order, false)
        NS.Tree.SetAll("statistics", models.statistics.order, true)
        local reps = names(windowRows("reputations"))
        assertTrue(reps:find("[Alliance],Ironforge=Revered 4,300 / 21,000,Stormwind=Honored 3,672 / 12,000", 1, true)
            ~= nil, reps)
        assertTrue(reps:find("[Steamwheedle Cartel],Booty Bay=", 1, true) ~= nil, "the panel's headers: " .. reps)
        local cur = names(windowRows("currencies"))
        assertEqual(cur, "[Player vs. Player],Honor Points=1,200 / 75,000,[Miscellaneous],Darkmoon Prize Ticket=12")
        assertEqual(names(windowRows("statistics")), "[Character],[Combat],[Deaths]", "every category folded")
        NS.Tree.SetFolded("statistics", 130, false)
        local st = names(windowRows("statistics"))
        assertTrue(st:find("[Character],Times camped=58,Talent tree respecs=--,[Wealth],[Consumables]", 1, true)
            ~= nil, st)
        assertEqual(next(NS.db.char.fold), nil, "a test-mode fold is the session's, never char.fold")
        assertEqual(live.calls, 0, "no live read for a sample")
    end)
    NS.Windows.HideAll()
    testModeOff()
    live.restore()
    NS.db.char.fold = savedFold
    if not ok then error(err, 0) end
end)

case("preview trees: the tree feeds draw the sample's own pins and tree, never this character's store", function()
    stopAll()
    local savedPins = NS.db.char.pins
    NS.db.char.pins = {}
    local ok, err = pcall(function()
        NS.ToggleTestMode()
        assertEqual(NS.Broker.FeedText("reputations"), "Stormwind Honored 3,672 / 12,000")
        assertEqual(NS.Broker.FeedText("currencies"), "Honor Points 1,200 / 75,000")
        assertEqual(NS.Broker.FeedText("statistics"), "Times camped 58")
        local lines = {}
        local tip = { lines = lines }
        function tip:AddLine(t) lines[#lines + 1] = t end
        function tip:AddDoubleLine(a, b) lines[#lines + 1] = a .. " | " .. b end
        function tip:NumLines() return #lines end
        local rows = NS.Broker.FillTooltip(tip, "statistics")
        local nodes = 0
        for _, r in ipairs(rows) do if r.node then nodes = nodes + 1 end end
        assertEqual(nodes, 3, "the sample's categories in the Classic tooltip")
        assertTrue(table.concat(lines, "\n"):find("Times camped", 1, true) ~= nil, "the Pinned section")
        assertEqual(next(NS.db.char.pins), nil, "nothing written to char.pins")
    end)
    testModeOff()
    NS.Broker.SetFeed(NS.Broker.DEFAULT_FEED)
    NS.db.char.pins = savedPins
    if not ok then error(err, 0) end
end)

case("preview trees: the sample's Alts record carries its standings and currencies", function()
    stopAll()
    NS.ToggleTestMode()
    local ok, err = pcall(function()
        local own
        for _, a in ipairs(NS.Preview.Alts():List()) do if a.isCurrent then own = a.record end end
        assertTrue(own ~= nil, "the sample's own record")
        assertEqual(own.reps["72"].standing, "Honored")
        assertEqual(own.currencies["1901"].quantity, 1200)
    end)
    testModeOff()
    if not ok then error(err, 0) end
end)

case("preview trees: the simulator's world is read through the seam; its steps raise a reputation and a currency", function()
    stopAll()
    local liveReps, liveCur = NS.RepData:Model(), NS.CurrencyData:Model()
    local liveLog = #NS.db.char.log
    local live = countLive()
    local ok, err = pcall(function()
        assertTrue(NS.Sim:Start({ scenario = H.SCENARIO }), "started")
        M.__fireTimers()
        assertEqual(NS.RepData:Get(72).current, 12672, "the world's Stormwind")
        assertEqual(NS.CurrencyData:Get(1901).quantity, 1200, "the world's Honor Points")
        NS.Tree.SetFolded("statistics", 130, true)   -- the session's folds outlive a case
        assertEqual(names(windowRows("statistics")), "[Character],[Combat],[Deaths]", "the world's Statistics tab")
        NS.Tree.SetFolded("statistics", 130, false)
        local st = names(windowRows("statistics"))
        assertTrue(st:find("[Character],Times camped=58", 1, true) ~= nil, "read through the seam: " .. st)
        local steps = NS.Sim:Steps()
        local labels = {}
        for _, s in ipairs(steps) do labels[#labels + 1] = H.StepLabel(s) end
        local text = table.concat(labels, ";")
        assertTrue(text:find("Reputation: Stormwind +250", 1, true) ~= nil, text)
        assertTrue(text:find("Currency: Honor Points +150", 1, true) ~= nil, text)
        for _ = 1, #steps do
            NS.Sim:Step()
            M.__fireTimers()
        end
        assertEqual(NS.RepData:Get(72).current, 12922, "UPDATE_FACTION read the raised standing")
        assertEqual(NS.CurrencyData:Get(1901).quantity, 1350, "CURRENCY_DISPLAY_UPDATE read the raised amount")
        local kinds = {}
        for _, e in ipairs(NS.SessionLog:Since(nil)) do if e.kind then kinds[e.kind] = e.new end end
        assertEqual(kinds.reputation, 12922, "the session log's line")
        assertEqual(kinds.currency, 1350)
        assertEqual(live.calls, 0, "the client's own lists never read while the world answers")
        NS.Sim:Stop("stop")
        M.__fireTimers()
        assertTrue(NS.RepData:Model() == liveReps, "the live reputations back")
        assertTrue(NS.CurrencyData:Model() == liveCur, "the live currencies back")
        assertEqual(#NS.db.char.log, liveLog, "nothing written to the saved log")
    end)
    NS.Windows.HideAll()
    live.restore()
    stopAll()
    if not ok then error(err, 0) end
end)

case("preview trees: a simulated currency at its cap never silences a real one (the alerts' state)", function()
    NS.Alerts.Reset()
    local s = NS.Alerts.State()
    assertTrue(type(s.currency) == "table", "the currency cap state is part of it")
    NS.Alerts.RestoreState({ currency = { ["1901"] = true } })
    assertTrue(NS.Alerts.State().currency["1901"])
    NS.Alerts.RestoreState(s)
    assertEqual(next(NS.Alerts.State().currency), nil)
end)
