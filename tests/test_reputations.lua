-- tests/test_reputations.lua — the Reputations window (GitHub issue #6; item SMW-08 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md): RepData's panel grouping and standing bars, the
-- expand-read-restore first read (never in combat, never while the panel shows, a re-entry latch), the refresh
-- by id, the tree rows and their addon-side folds, the tooltip's own folds, the pins, the Journal's session
-- changes and the Alts sub-tab.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local RD = NS.RepData

-- The panel's list: Alliance (Stormwind, Ironforge), Steamwheedle Cartel (a sub-header with its own bar,
-- collapsed: Booty Bay, Gadgetzan), then Other (collapsed: Thorium Brotherhood, Exalted).
local function factions()
    return {
        { id = 469, name = "Alliance", header = true, kids = {
            { id = 72, name = "Stormwind", reaction = 6, lo = 9000, hi = 21000, cur = 12672 },
            { id = 47, name = "Ironforge", reaction = 5, lo = 3000, hi = 9000, cur = 4000, atWar = true },
            { id = 169, name = "Steamwheedle Cartel", header = true, child = true, withRep = true, collapsed = true,
              reaction = 4, lo = 0, hi = 3000, cur = 1500, kids = {
                { id = 21, name = "Booty Bay", child = true, reaction = 5, lo = 3000, hi = 9000, cur = 6000 },
                { id = 369, name = "Gadgetzan", child = true, reaction = 4, lo = 0, hi = 3000, cur = 300 },
            } },
        } },
        { id = 1169, name = "Other", header = true, collapsed = true, kids = {
            { id = 59, name = "Thorium Brotherhood", reaction = 8, lo = 42000, hi = 42999, cur = 42999 },
        } },
    }
end

local function flat(tree)
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

local function data(n)
    return { factionID = n.id, name = n.name, isHeader = n.header or false, isChild = n.child or false,
             isHeaderWithRep = n.withRep or false, isCollapsed = n.collapsed or false, reaction = n.reaction or 4,
             currentReactionThreshold = n.lo or 0, nextReactionThreshold = n.hi or 0, currentStanding = n.cur or 0,
             atWarWith = n.atWar or false, description = n.name .. "'s description" }
end

-- A fake C_Reputation over `tree`; answers the spy: toggles counted, the nodes by id, and an `onToggle` hook.
local function install(tree)
    local spy, byID = { expand = 0, collapse = 0 }, {}
    local function index(nodes)
        for _, n in ipairs(nodes) do byID[n.id] = n; if n.kids then index(n.kids) end end
    end
    index(tree)
    spy.byID = byID
    M.C_Reputation = {
        GetNumFactions = function() return #flat(tree) end,
        GetFactionDataByIndex = function(i) local n = flat(tree)[i]; return n and data(n) end,
        GetFactionDataByID = function(id) local n = byID[id]; return n and data(n) end,
        ExpandFactionHeader = function(i)
            spy.expand = spy.expand + 1
            flat(tree)[i].collapsed = false
            if spy.onToggle then spy.onToggle() end
        end,
        CollapseFactionHeader = function(i) spy.collapse = spy.collapse + 1; flat(tree)[i].collapsed = true end,
    }
    return spy
end

local function withClient(fn)
    local saved = { M.C_Reputation, M.ReputationFrame, M.InCombatLockdown, M.FACTION_BAR_COLORS, M.GetText, M.UnitSex }
    local savedFold, savedPins, savedLog = NS.db.char.fold, NS.db.char.pins, NS.db.char.log
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = {}, {}, {}
    M.FACTION_BAR_COLORS = { [4] = { r = 1, g = 1, b = 0 }, [5] = { r = 0, g = 0.6, b = 0.1 },
                             [6] = { r = 0, g = 0.7, b = 0.2 }, [8] = { r = 0, g = 0.8, b = 0.8 } }
    local labels = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }
    M.GetText = function(key) return labels[tonumber(key:match("(%d+)$"))] end   -- the client's GetText(token, sex)
    M.UnitSex = function() return 2 end
    M.InCombatLockdown = function() return false end
    RD:Reset()
    local ok, err = pcall(fn)
    M.C_Reputation, M.ReputationFrame, M.InCombatLockdown, M.FACTION_BAR_COLORS, M.GetText, M.UnitSex = unpack(saved, 1, 6)
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = savedFold, savedPins, savedLog
    RD:Reset()
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end

local function names(m)
    local out = {}
    for i, e in ipairs(m.order) do out[i] = ("%s%d"):format(e.name, e.depth) end
    return table.concat(out, ",")
end

test("reputations: the first read opens every collapsed header, reads, and closes them again bottom up", function()
    withClient(function()
        local tree = factions()
        local spy = install(tree)
        local m = RD:Read()
        assertEqual(names(m), "Alliance0,Stormwind1,Ironforge1,Steamwheedle Cartel1,Booty Bay2,Gadgetzan2,"
            .. "Other0,Thorium Brotherhood1", "the panel's own grouping, every depth")
        assertTrue(m.complete, "the whole list")
        assertEqual(spy.expand, 2, "the two collapsed headers opened")
        assertEqual(spy.collapse, 2, "and closed again")
        assertTrue(spy.byID[169].collapsed and spy.byID[1169].collapsed, "the panel's collapse is as it was")
        assertEqual(RD:Model(), m)
    end)
end)

test("reputations: a standing bar runs from the current threshold to the next, labeled and colored by the client", function()
    withClient(function()
        install(factions())
        RD:Read()
        local sw = RD:Get(72)
        assertEqual(sw.standing, "Honored")
        assertEqual(sw.value, 3672)
        assertEqual(sw.max, 12000)
        assertEqual(RD.ValueText(sw), "Honored 3,672 / 12,000")
        local v = RD.BarValues(sw)
        assertEqual(v.color[2], 0.7, "FACTION_BAR_COLORS[reaction]")
        local tb = RD:Get(59)
        assertTrue(tb.exalted, "Exalted")
        assertEqual(RD.ValueText(tb), "Exalted", "Exalted shows its name alone")
        assertEqual(tb.value, tb.max, "a full bar")
        assertTrue(RD:Get(169).hasBar, "a sub-header with its own bar")
        assertFalse(RD:Get(469).hasBar, "a plain header has none")
        assertEqual(RD.BarValues(RD:Get(469)), nil)
    end)
end)

test("reputations: in combat or with the Reputation tab up the read opens nothing; combat's end reads in full", function()
    withClient(function()
        local spy = install(factions())
        M.InCombatLockdown = function() return true end
        local m = RD:Read()
        assertEqual(spy.expand, 0, "no header opened in combat")
        assertFalse(m.complete, "a partial read")
        assertEqual(names(m), "Alliance0,Stormwind1,Ironforge1,Steamwheedle Cartel1,Other0", "the rows as listed")
        M.InCombatLockdown = function() return false end
        M.__fireTimers()
        assertEqual(RD.OnEvent("PLAYER_REGEN_ENABLED"), 1)
        M.__fireTimers()
        assertTrue(RD:Model().complete, "read in full as combat ends")
        assertEqual(spy.expand, 2)
        RD:Reset()
        spy = install(factions())
        M.ReputationFrame = { IsShown = function() return true end, HookScript = function() end }
        RD:Read()
        assertEqual(spy.expand, 0, "never while the panel's Reputation tab shows")
    end)
end)

test("reputations: the read's own header toggles are latched: an UPDATE_FACTION meanwhile reads nothing", function()
    withClient(function()
        local spy = install(factions())
        local inside = {}
        spy.onToggle = function()
            inside[#inside + 1] = NS.SharedList.Busy("reputations")
            inside.nested = NS.SharedList.Read(RD.LIST)
            RD.OnEvent("UPDATE_FACTION")
        end
        M.__fireTimers()
        RD:Read()
        assertTrue(inside[1] == true, "the latch is up while the read toggles")
        assertEqual(inside.nested, nil, "a nested read is refused")
        local before = spy.expand
        M.__fireTimers()
        assertEqual(spy.expand, before, "the latched event asked for no read")
    end)
end)

test("reputations: later reads go by id, touch no header, and announce a moved standing", function()
    withClient(function()
        local spy = install(factions())
        RD:Read()
        local toggles = spy.expand + spy.collapse
        local seen = {}
        local target = NS.NewBusTarget()
        target:RegisterMessage(NS.MSG.REP_CHANGED, function(_, key, old, new, name)
            seen[#seen + 1] = ("%s %s %d>%d"):format(key, name, old, new)
        end)
        spy.byID[21].cur = 6250   -- Booty Bay, under the collapsed Steamwheedle Cartel
        RD:Refresh()
        assertEqual(spy.expand + spy.collapse, toggles, "no header touched")
        assertEqual(RD:Get(21).value, 3250, "the collapsed child read by id")
        assertEqual(table.concat(seen, ";"), "21 Booty Bay 6000>6250")
        spy.byID[21].cur = 6400
        RD:Refresh()
        target:UnregisterAllMessages()
        local log = NS.SessionLog:Since(nil)
        local mine = {}
        for _, e in ipairs(log) do if e.kind == "reputation" then mine[#mine + 1] = e end end
        assertEqual(#mine, 2, "a Log row per change (R5-SM-10)")
        assertEqual(mine[1].old .. ">" .. mine[1].new, "6000>6250")
        assertEqual(mine[2].old .. ">" .. mine[2].new, "6250>6400")
        assertEqual(NS.SessionLog:KindGainsFor("reputation", "21"), 400)
        assertEqual((NS.SessionLog:Gains()), 0, "a standing is no skill point")
        assertEqual(NS.Journal.ChangeText(mine[2]), "+150")
    end)
end)

test("reputations: a faction the model does not know asks for the full read again", function()
    withClient(function()
        local tree = factions()
        local spy = install(tree)
        RD:Read()
        local before = spy.expand
        table.insert(tree[1].kids, 1, { id = 930, name = "Exodar", reaction = 4, lo = 0, hi = 3000, cur = 10 })
        spy.byID[930] = tree[1].kids[1]
        RD:Refresh()
        assertTrue(RD:Get(930) ~= nil, "the new faction is in")
        assertTrue(spy.expand > before, "by a full read")
    end)
end)

test("reputations: the window draws the tree, and a fold is this addon's own, never the client's", function()
    withClient(function()
        local spy = install(factions())
        RD:Read()
        local W = NS.Windows.Get("reputations")
        W.Show()
        W.Refresh(true)
        local rows = W.Rows()
        assertEqual(#rows, 8, "every faction and header")
        local header, leaf = rows[1], rows[2]
        assertTrue(header.treeHeader and header.fold:IsShown(), "a header's chevron")
        assertFalse(leaf.fold ~= nil and leaf.fold:IsShown(), "a leaf has none")
        assertTrue(leaf.bar:IsShown(), "a leaf's bar")
        assertFalse(leaf.act:IsShown(), "no action mark on a tree row")
        assertEqual(NS.Interact.Target(leaf), "none", "a leaf opens no panel")
        assertEqual(NS.SecureOverlay.KindFor(leaf), nil, "and arms no secure overlay")
        local toggles = spy.expand + spy.collapse
        NS.Rows.Fold(header)   -- Alliance folds
        W.Refresh(true)
        assertEqual(#W.Rows(), 3, "Alliance, Other, Thorium Brotherhood")
        assertEqual(NS.db.char.fold.reputations["469"], true, "char.fold")
        assertEqual(spy.expand + spy.collapse, toggles, "no client Expand or Collapse")
        assertTrue(spy.byID[169].collapsed, "the panel's own collapse untouched")
    end)
end)

test("reputations: the tooltip folds a header in its own folds; the window's stay", function()
    withClient(function()
        install(factions())
        RD:Read()
        local ldb = NS.db.profile.tooltips.ldb
        local style = ldb.style
        ldb.style = "window"
        local ok, err = pcall(function()
            NS.Broker.OnEnter(M.UIParent, "reputations")
            local P = NS.BrokerPanel
            local first
            for _, row in ipairs(P.Rows()) do if row.treeHeader then first = first or row end end
            assertTrue(first ~= nil, "a header row in the tooltip")
            local n = #P.Rows()
            NS.Rows.Fold(first)
            assertTrue(#P.Rows() < n, "the tooltip redrew folded")
            assertEqual(NS.db.char.fold.reputations, nil, "the window's folds untouched")
            assertEqual(NS.db.profile.tooltips.ldb.folds.nodes.reputations["469"], true, "the tooltip's own")
            NS.db.profile.tooltips.ldb.folds.nodes.reputations = nil
        end)
        NS.Broker.HideTooltip()
        ldb.style = style
        NS.Broker.SetFeed(NS.Broker.DEFAULT_FEED)
        if not ok then error(err, 0) end
    end)
end)

test("reputations: the Classic tooltip lists the tree, each header a chevron line", function()
    withClient(function()
        install(factions())
        RD:Read()
        local lines = {}
        local tip = { lines = lines }
        function tip:AddLine(t) lines[#lines + 1] = t end
        function tip:AddDoubleLine(a, b) lines[#lines + 1] = a .. " | " .. b end
        function tip:NumLines() return #lines end
        local rows = NS.Broker.FillTooltip(tip, "reputations")
        local nodes, leaves = 0, 0
        for _, r in ipairs(rows) do
            if r.node then nodes = nodes + 1 elseif r.kind == "reputation" then leaves = leaves + 1 end
        end
        assertEqual(nodes, 3, "Alliance, Steamwheedle Cartel, Other")
        assertEqual(leaves, 5)
        local text = table.concat(lines, "\n")
        assertTrue(text:find("Honored 3,672 / 12,000", 1, true) ~= nil, text)
        NS.Broker.SetFeed(NS.Broker.DEFAULT_FEED)
    end)
end)

test("reputations: a row's menu pins it to the Reputations broker, whose text shows its standing", function()
    withClient(function()
        install(factions())
        RD:Read()
        local W = NS.Windows.Get("reputations")
        W.Show()
        W.Refresh(true)
        local row = W.Rows()[2]   -- Stormwind
        local pin
        for _, r in ipairs(NS.Interact.MenuRows(row)) do if r.value == "pin" then pin = r end end
        assertTrue(pin ~= nil, "a Pin row")
        assertEqual(pin.label, "Pin to the Reputations broker")
        pin.onClick()
        assertTrue(NS.Pins.Has("reputations", "72"))
        assertEqual(NS.Broker.FeedText("reputations"), "Stormwind Honored 3,672 / 12,000")
        assertEqual(NS.Interact.LinkText(row), "[Stormwind: Honored 3,672 / 12,000]")
        local header = W.Rows()[1]
        local hasPin = false
        for _, r in ipairs(NS.Interact.MenuRows(header)) do if r.value == "pin" then hasPin = true end end
        assertFalse(hasPin, "a header with no bar pins nothing")
    end)
end)

test("reputations: the Alts snapshot keeps each standing; the Journal has a Reputations sub-tab", function()
    withClient(function()
        install(factions())
        RD:Read()
        local reps = NS.Alts.RepsOf(RD:Model())
        assertEqual(reps["72"].standing, "Honored")
        assertEqual(reps["469"], nil, "a plain header is no standing")
        local list = { { key = "a", record = { reps = reps } }, { key = "b", record = { reps = { ["930"] = { name = "Exodar" } } } } }
        local keys, nm, kind = NS.Journal.AltRows(list, "reputations")
        assertEqual(kind, "reputation")
        assertEqual(nm[keys[1]], "Booty Bay", "by name")
        assertEqual(#keys, 7)
        assertEqual(NS.Journal.FilterLabel("reputations"), "Reputations")
    end)
end)

test("reputations: a simulation never toggles the client's headers (the seam guards the toggle)", function()
    local saved = M.C_Reputation
    local toggled = 0
    M.C_Reputation = { GetNumFactions = function() return 0 end, GetFactionDataByIndex = function() end,
                       ExpandFactionHeader = function() toggled = toggled + 1 end, CollapseFactionHeader = function() end }
    local ok, err = pcall(function()
        assertTrue(NS.Compat.SetFactionHeaderExpanded(1, true), "live, the toggle runs")
        assertEqual(toggled, 1)
        assertTrue(NS.Sim:Start({ scenario = NS.SimHost.SCENARIO }), "a simulation starts")
        M.__fireTimers()
        assertFalse(NS.Compat.SetFactionHeaderExpanded(1, true), "guarded while it runs")
        assertEqual(toggled, 1, "the client's header never moved")
    end)
    if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
    NS.Sim:HidePanel()
    M.__fireTimers()
    M.C_Reputation = saved
    if not ok then error(err, 0) end
end)

test("reputations: a detached Reputations block draws the same tree, and the Journal's sub-tab draws its standings", function()
    withClient(function()
        install(factions())
        RD:Read()
        local b = NS.db.profile.layout.blocks.reputations
        b.docked = false
        local ok, err = pcall(function()
            NS.Detached.Refresh()
            local rows = NS.Detached.Rows("reputations")
            assertEqual(#rows, 8, "the detached frame's rows")
            assertTrue(rows[1].treeHeader, "its headers fold there too")
            NS.Rows.Fold(rows[1])
            NS.Detached.Refresh()
            assertEqual(#NS.Detached.Rows("reputations"), 3, "folded in the window's folds")
        end)
        b.docked = true
        NS.Detached.Refresh()
        if not ok then error(err, 0) end
        local key = NS.Alts:Key()
        if key then
            NS.Alts:Snapshot()
            assertEqual(NS.db.global.characters[key].reps["72"].standing, "Honored", "the snapshot's standing")
        end
        NS.Journal.Show()
        NS.Journal.SelectTab("alts")
        NS.Journal.SelectFilter("reputations")
        NS.Journal.Render()
        NS.Journal.SelectFilter("primary")
        NS.Journal.SelectTab("log")
        NS.Journal.Hide()
    end)
end)
