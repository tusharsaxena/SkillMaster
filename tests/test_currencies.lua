-- tests/test_currencies.lua — the Currencies window (GitHub issue #7; item SMW-09 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md): CurrencyData's panel headers, capped bars and plain
-- value rows, no gold (the owner's ruling), the expand-read-restore first read, the by-id refresh
-- CURRENCY_DISPLAY_UPDATE drives, the Journal's session gains, the Alts sub-tab and the optional cap alert.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local CD = NS.CurrencyData

-- The Currency tab: Player vs. Player (Honor Points, capped and weekly), Miscellaneous (collapsed: Darkmoon Prize
-- Ticket, no cap).
local function currencies()
    return {
        { name = "Player vs. Player", header = true, depth = 0, kids = {
            { id = 1901, name = "Honor Points", quantity = 1200, max = 75000, depth = 1, weekly = 10000, earned = 800,
              icon = 1455894 },
        } },
        { name = "Miscellaneous", header = true, depth = 0, collapsed = true, kids = {
            { id = 515, name = "Darkmoon Prize Ticket", quantity = 12, max = 0, depth = 1, icon = 134481 },
        } },
    }
end

local function flat(tree)
    local out = {}
    for _, top in ipairs(tree) do
        out[#out + 1] = top
        if not top.collapsed then for _, k in ipairs(top.kids) do out[#out + 1] = k end end
    end
    return out
end

local function info(n)
    return { name = n.name, currencyID = n.id or 0, isHeader = n.header or false,
             isHeaderExpanded = n.header and not n.collapsed or false, currencyListDepth = n.depth,
             quantity = n.quantity or 0, maxQuantity = n.max or 0, canEarnPerWeek = n.weekly ~= nil,
             maxWeeklyQuantity = n.weekly or 0, quantityEarnedThisWeek = n.earned or 0, iconFileID = n.icon,
             description = n.name and (n.name .. ", earned by playing") }
end

local function install(tree)
    local spy, byID = { expand = 0, collapse = 0, byID = {}, info = {} }, {}
    for _, top in ipairs(tree) do for _, k in ipairs(top.kids) do byID[k.id] = k end end
    spy.nodes = byID
    M.C_CurrencyInfo = {
        GetCurrencyListSize = function() return #flat(tree) end,
        GetCurrencyListInfo = function(i) local n = flat(tree)[i]; return n and info(n) end,
        ExpandCurrencyList = function(i, open)
            local n = flat(tree)[i]
            if open then spy.expand = spy.expand + 1 else spy.collapse = spy.collapse + 1 end
            n.collapsed = not open
        end,
        GetCurrencyInfo = function(id)
            spy.info[#spy.info + 1] = id
            local n = byID[id]
            return n and info(n)
        end,
    }
    return spy
end

local function withClient(fn)
    local saved = { M.C_CurrencyInfo, M.TokenFrame, M.InCombatLockdown, M.GetMoney }
    local savedFold, savedPins, savedLog = NS.db.char.fold, NS.db.char.pins, NS.db.char.log
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = {}, {}, {}
    M.InCombatLockdown = function() return false end
    local money = 0
    M.GetMoney = function() money = money + 1 return 123456 end
    CD:Reset()
    local ok, err = pcall(fn, function() return money end)
    M.C_CurrencyInfo, M.TokenFrame, M.InCombatLockdown, M.GetMoney = unpack(saved, 1, 4)
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = savedFold, savedPins, savedLog
    CD:Reset()
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end

local function names(m)
    local out = {}
    for i, e in ipairs(m.order) do out[i] = ("%s%d"):format(e.name, e.depth) end
    return table.concat(out, ",")
end

test("currencies: the first read opens every collapsed header, reads, closes it again, and never reads gold", function()
    withClient(function(moneyReads)
        local tree = currencies()
        local spy = install(tree)
        local m = CD:Read()
        assertEqual(names(m), "Player vs. Player0,Honor Points1,Miscellaneous0,Darkmoon Prize Ticket1")
        assertTrue(m.complete)
        assertEqual(spy.expand, 1)
        assertEqual(spy.collapse, 1)
        assertTrue(tree[2].collapsed, "the Currency tab's collapse is as it was")
        assertEqual(moneyReads(), 0, "gold is never read (the owner's ruling)")
        for _, e in ipairs(m.order) do assertTrue(e.name ~= "Gold" and e.name ~= "Money", "no gold row") end
        assertEqual(m.byKey["h:Miscellaneous#0"].nodeKey, "Miscellaneous#0", "a header folds by its name and depth")
    end)
end)

test("currencies: a capped currency is a bar, one without a cap a plain value; the tooltip says the week's cap", function()
    withClient(function()
        install(currencies())
        CD:Read()
        local honor, ticket = CD:Get(1901), CD:Get(515)
        assertTrue(honor.hasBar)
        assertEqual(CD.ValueText(honor), "1,200 / 75,000")
        assertEqual(CD.BarValues(honor).max, 75000)
        assertFalse(ticket.hasBar)
        assertEqual(CD.BarValues(ticket), nil, "no bar without a cap")
        assertEqual(CD.ValueText(ticket), "12")
        local lines = NS.RowTooltip.Lines(honor, "currency")
        local text = {}
        for _, l in ipairs(lines) do text[#text + 1] = (l.left or "") .. "=" .. (l.right or "") end
        text = table.concat(text, ";")
        assertTrue(text:find("Amount=1,200", 1, true) ~= nil, text)
        assertTrue(text:find("Cap=75,000", 1, true) ~= nil, text)
        assertTrue(text:find("This week=800 / 10,000", 1, true) ~= nil, text)
        assertTrue(text:find("Honor Points, earned by playing", 1, true) ~= nil, "the description")
    end)
end)

test("currencies: CURRENCY_DISPLAY_UPDATE with an id reads that one by id, touching no header, and logs the gain", function()
    withClient(function()
        local spy = install(currencies())
        CD:Read()
        local toggles = spy.expand + spy.collapse
        local seen = {}
        local target = NS.NewBusTarget()
        target:RegisterMessage(NS.MSG.CURRENCY_CHANGED, function(_, key, old, new)
            seen[#seen + 1] = ("%s %d>%d"):format(key, old, new)
        end)
        spy.info = {}
        spy.nodes[515].quantity = 15
        assertEqual(CD.OnEvent("CURRENCY_DISPLAY_UPDATE", 515, 15, 3), 1)
        M.__fireTimers()
        target:UnregisterAllMessages()
        assertEqual(spy.expand + spy.collapse, toggles, "no header touched")
        assertEqual(CD:Get(515).quantity, 15, "under the collapsed header, read by id")
        assertEqual(table.concat(spy.info, ","), "515", "only the currency the event named")
        assertEqual(table.concat(seen, ";"), "515 12>15")
        assertEqual(NS.SessionLog:KindGainsFor("currency", "515"), 3, "the Journal's session gain")
        assertEqual((NS.SessionLog:Gains()), 0, "no skill point")
    end)
end)

test("currencies: a nil currencyType reads every known one again; an unknown id asks for the full read", function()
    withClient(function()
        local tree = currencies()
        local spy = install(tree)
        CD:Read()
        spy.info = {}
        CD.OnEvent("CURRENCY_DISPLAY_UPDATE", nil)
        M.__fireTimers()
        assertEqual(#spy.info, 1, "the collapsed one by id; the listed one from its row")
        local before = spy.expand
        table.insert(tree[1].kids, { id = 1900, name = "Arena Points", quantity = 5, max = 5000, depth = 1 })
        spy.nodes[1900] = tree[1].kids[2]
        CD.OnEvent("CURRENCY_DISPLAY_UPDATE", 1900, 5, 5)
        M.__fireTimers()
        assertTrue(CD:Get(1900) ~= nil, "the new currency is in")
        assertTrue(spy.expand > before, "by a full read")
    end)
end)

test("currencies: in combat or with the Currency tab up the read opens nothing; the latch holds its own echo", function()
    withClient(function()
        local spy = install(currencies())
        M.InCombatLockdown = function() return true end
        local m = CD:Read()
        assertEqual(spy.expand, 0)
        assertFalse(m.complete)
        M.InCombatLockdown = function() return false end
        CD.OnEvent("PLAYER_REGEN_ENABLED")
        M.__fireTimers()
        assertTrue(CD:Model().complete, "read in full as combat ends")
        CD:Reset()
        spy = install(currencies())
        M.TokenFrame = { IsShown = function() return true end, HookScript = function() end }
        CD:Read()
        assertEqual(spy.expand, 0, "never while the Currency tab shows")
        M.TokenFrame = nil
        CD:Reset()
        local tree = currencies()
        spy = install(tree)
        local busy
        local open = M.C_CurrencyInfo.ExpandCurrencyList
        M.C_CurrencyInfo.ExpandCurrencyList = function(i, o)
            busy = NS.SharedList.Busy("currencies")
            CD.OnEvent("CURRENCY_DISPLAY_UPDATE", nil)
            return open(i, o)
        end
        M.__fireTimers()
        CD:Read()
        assertTrue(busy, "the latch is up while the read toggles")
        local n = spy.expand
        M.__fireTimers()
        assertEqual(spy.expand, n, "its echo asked for no read")
    end)
end)

test("currencies: an empty list is the window's empty line; the window draws icons, bars and plain values", function()
    withClient(function()
        M.C_CurrencyInfo = { GetCurrencyListSize = function() return 0 end, GetCurrencyListInfo = function() end }
        CD:Read()
        assertEqual(CD:Model(), nil, "no model for an empty list")
        local W = NS.Windows.Get("currencies")
        W.Show()
        W.Refresh(true)
        assertTrue(W.Frame().empty:IsShown())
        assertEqual(W.Frame().empty:GetText(), "No currencies to show yet.")
        install(currencies())
        CD:Read()
        W.Refresh(true)
        local rows = W.Rows()
        assertEqual(#rows, 4)
        assertTrue(rows[1].treeHeader, "a header")
        assertTrue(rows[2].iconFrame:IsShown(), "a currency's icon")
        assertTrue(rows[2].bar:IsShown(), "a capped currency's bar")
        assertFalse(rows[4].bar:IsShown(), "a plain value row has no bar")
        assertEqual(rows[4].where:GetText(), "12")
        NS.Rows.Fold(rows[3])
        W.Refresh(true)
        assertEqual(#W.Rows(), 3, "Miscellaneous folded")
        assertEqual(NS.db.char.fold.currencies["Miscellaneous#0"], true)
    end)
end)

test("currencies: the cap alert is off by default; on, it toasts once as a currency reaches its cap", function()
    withClient(function()
        local tree = currencies()
        install(tree)
        CD:Read()
        NS.Alerts.Reset()
        assertEqual(NS.defaults.profile.alerts.currencyCap, false, "off by default")
        assertFalse(NS.Alerts.CheckCurrencyCap("1901", 74000, 75000), "off: no toast")
        NS.db.profile.alerts.currencyCap = true
        local realToast, shown = NS.Alerts.toast, {}
        NS.Alerts.toast = setmetatable({ Show = function(_, p, o) shown[#shown + 1] = o.key .. " " .. p.title end },
                                       { __index = realToast })
        local ok, err = pcall(function()
            tree[1].kids[1].quantity = 75000
            CD:Refresh()   -- CURRENCY_CHANGED 1200 > 75000 reaches the alert
            assertEqual(table.concat(shown, ";"), "currency:1901 Honor Points 75000 / 75000", "on: a toast at the cap")
            assertFalse(NS.Alerts.CheckCurrencyCap("1901", 74000, 75000), "once per session")
            assertFalse(NS.Alerts.CheckCurrencyCap("515", 1, 20), "a currency with no cap never")
        end)
        NS.Alerts.toast = realToast
        NS.db.profile.alerts.currencyCap = false
        NS.Alerts.Reset()
        if not ok then error(err, 0) end
    end)
end)

test("currencies: a pin shows its amount; the Alts snapshot and the Journal's Currencies sub-tab", function()
    withClient(function()
        install(currencies())
        CD:Read()
        assertEqual(NS.Pins.Toggle("currencies", "1901"), true)
        assertEqual(NS.Broker.FeedText("currencies"), "Honor Points 1,200 / 75,000")
        local cur = NS.Alts.CurrenciesOf(CD:Model())
        assertEqual(cur["515"].quantity, 12)
        assertEqual(cur["h:Miscellaneous#0"], nil, "a header is no currency")
        local keys, nm, kind = NS.Journal.AltRows({ { key = "a", record = { currencies = cur } } }, "currencies")
        assertEqual(kind, "currency")
        assertEqual(nm[keys[1]], "Darkmoon Prize Ticket", "by name")
        assertEqual(NS.Journal.FilterLabel("currencies"), "Currencies")
        NS.Journal.Show()
        NS.Journal.SelectTab("alts")
        NS.Journal.SelectFilter("currencies")
        NS.Journal.Render()
        NS.Journal.SelectFilter("primary")
        NS.Journal.SelectTab("log")
        NS.Journal.Hide()
    end)
end)

test("currencies: a simulation never toggles the client's headers (the seam guards the toggle)", function()
    local saved = M.C_CurrencyInfo
    local toggled = 0
    M.C_CurrencyInfo = { GetCurrencyListSize = function() return 0 end, GetCurrencyListInfo = function() end,
                         ExpandCurrencyList = function() toggled = toggled + 1 end }
    local ok, err = pcall(function()
        assertTrue(NS.Compat.SetCurrencyHeaderExpanded(1, true), "live, the toggle runs")
        assertTrue(NS.Sim:Start({ scenario = NS.SimHost.SCENARIO }), "a simulation starts")
        M.__fireTimers()
        assertFalse(NS.Compat.SetCurrencyHeaderExpanded(1, true), "guarded while it runs")
        assertEqual(toggled, 1)
    end)
    if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
    NS.Sim:HidePanel()
    M.__fireTimers()
    M.C_CurrencyInfo = saved
    if not ok then error(err, 0) end
end)
