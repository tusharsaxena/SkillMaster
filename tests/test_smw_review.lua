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
