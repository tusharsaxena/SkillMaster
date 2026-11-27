-- tests/test_tree.lua — the tree row model and the addon-side folds (item SMW-03 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md; the spec's "Tree blocks and folding"). One
-- model serves Reputations, Currencies and Statistics: entries carry { depth, header, nodeKey }, and the
-- children of a folded node are skipped. A fold is this addon's own state, char.fold[family][nodeKey],
-- and never the client's Expand or Collapse.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Tree = NS.Tree

-- Statistics-shaped: Character > Wealth (nested) > rows, Character > Consumables, then Combat.
local function statisticsEntries()
    return {
        { depth = 0, header = true, nodeKey = 130, name = "Character" },
        { depth = 1, name = "Times camped" },
        { depth = 1, header = true, nodeKey = 140, name = "Wealth" },
        { depth = 2, name = "Total gold acquired" },
        { depth = 2, name = "Auctions posted" },
        { depth = 1, header = true, nodeKey = 141, name = "Consumables" },
        { depth = 2, name = "Potions consumed" },
        { depth = 0, header = true, nodeKey = 122, name = "Combat" },
        { depth = 1, name = "Total kills" },
    }
end

local function names(rows)
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.entry.name end
    return table.concat(out, ",")
end

local function withFolds(fn)
    local saved = NS.db.char.fold
    NS.db.char.fold = {}
    local ok, err = pcall(fn)
    NS.db.char.fold = saved
    if not ok then error(err, 0) end
end

test("tree: char.fold defaults to an empty store", function()
    assertEqual(type(NS.defaults.char.fold), "table")
    assertEqual(next(NS.defaults.char.fold), nil)
end)

test("tree: Statistics categories start folded; reputation and currency headers start open", function()
    withFolds(function()
        assertTrue(Tree.IsFolded("statistics", 130), "a Statistics category starts folded")
        assertTrue(not Tree.IsFolded("reputations", 469), "a reputation header starts open")
        assertTrue(not Tree.IsFolded("currencies", "Miscellaneous#0"), "a currency header starts open")
    end)
end)

test("tree: Visible skips the children of a folded node, at every depth", function()
    withFolds(function()
        local e = statisticsEntries()
        assertEqual(names(Tree.Visible(e, "statistics")), "Character,Combat", "every category folded")
        Tree.SetFolded("statistics", 130, false)
        assertEqual(names(Tree.Visible(e, "statistics")), "Character,Times camped,Wealth,Consumables,Combat",
            "Character open, its sub-categories still folded")
        Tree.SetFolded("statistics", 140, false)
        assertEqual(names(Tree.Visible(e, "statistics")),
            "Character,Times camped,Wealth,Total gold acquired,Auctions posted,Consumables,Combat")
        Tree.SetFolded("statistics", 130, true)
        assertEqual(names(Tree.Visible(e, "statistics")), "Character,Combat",
            "folding the parent hides an open child and its rows")
        Tree.SetFolded("statistics", 130, false)
        assertEqual(names(Tree.Visible(e, "statistics")),
            "Character,Times camped,Wealth,Total gold acquired,Auctions posted,Consumables,Combat",
            "the child's own fold is kept under its parent's")
    end)
end)

test("tree: a visible row carries its depth, indent, header flag and chevron", function()
    withFolds(function()
        Tree.SetFolded("statistics", 130, false)
        local rows = Tree.Visible(statisticsEntries(), "statistics")
        assertEqual(rows[1].header, true); assertEqual(rows[1].folded, false)
        assertEqual(rows[1].chevron, "chevron-down")
        assertEqual(rows[1].indent, 0)
        assertEqual(rows[2].header, false); assertEqual(rows[2].chevron, nil)
        assertEqual(rows[2].indent, Tree.INDENT)
        assertEqual(rows[3].folded, true); assertEqual(rows[3].chevron, "chevron-right")
        assertEqual(rows[3].depth, 1)
    end)
end)

test("tree: Toggle flips one node and answers the new state", function()
    withFolds(function()
        assertEqual(Tree.Toggle("reputations", 469), true, "open by default, so the first toggle folds")
        assertTrue(Tree.IsFolded("reputations", 469))
        assertEqual(Tree.Toggle("reputations", 469), false)
        assertTrue(not Tree.IsFolded("reputations", 469))
        assertEqual(NS.db.char.fold.reputations["469"], false, "stored under the family, keyed as a string")
    end)
end)

test("tree: a fold never calls the client's Expand or Collapse", function()
    withFolds(function()
        local savedRep, savedCur = M.C_Reputation, M.C_CurrencyInfo
        local touched = {}
        local function spy(name) return function() touched[#touched + 1] = name end end
        M.C_Reputation = { ExpandFactionHeader = spy("ExpandFactionHeader"),
                           CollapseFactionHeader = spy("CollapseFactionHeader"),
                           ExpandAllFactionHeaders = spy("ExpandAll"), CollapseAllFactionHeaders = spy("CollapseAll") }
        M.C_CurrencyInfo = { ExpandCurrencyList = spy("ExpandCurrencyList") }
        Tree.Toggle("reputations", 469)
        Tree.Toggle("currencies", "Miscellaneous#0")
        Tree.SetAll("reputations", { { depth = 0, header = true, nodeKey = 1 } }, true)
        M.C_Reputation, M.C_CurrencyInfo = savedRep, savedCur
        assertEqual(#touched, 0, "client state untouched: " .. table.concat(touched, ","))
    end)
end)

test("tree: SetAll folds or opens every header it is given", function()
    withFolds(function()
        local e = statisticsEntries()
        Tree.SetAll("statistics", e, false)
        assertEqual(#Tree.Visible(e, "statistics"), #e, "everything open")
        Tree.SetAll("statistics", e, true)
        assertEqual(names(Tree.Visible(e, "statistics")), "Character,Combat")
    end)
end)

test("tree: the node keys the spec names, per family", function()
    assertEqual(Tree.NodeKey("reputations", { factionID = 469, name = "Alliance" }), "469")
    assertEqual(Tree.NodeKey("currencies", { name = "Miscellaneous", currencyListDepth = 0 }), "Miscellaneous#0")
    assertEqual(Tree.NodeKey("statistics", { categoryID = 140, name = "Wealth" }), "140")
    assertEqual(Tree.NodeKey("reputations", { name = "No id" }), nil, "no key, no fold")
end)

test("tree: a header with no key is drawn open and never stored", function()
    withFolds(function()
        local rows = Tree.Visible({ { depth = 0, header = true, name = "Keyless" }, { depth = 1, name = "Row" } },
            "statistics")
        assertEqual(names(rows), "Keyless,Row")
        assertEqual(Tree.Toggle("statistics", nil), nil)
        assertEqual(next(NS.db.char.fold), nil, "nothing written")
    end)
end)

test("tree: while test mode runs, folds go to a session store and the character's stay as they were", function()
    withFolds(function()
        NS.State.testMode = true
        local ok, err = pcall(function()
            Tree.Toggle("reputations", 469)
            assertTrue(Tree.IsFolded("reputations", 469), "the fold works on the sample")
        end)
        NS.State.testMode = false
        assertTrue(ok, tostring(err))
        assertEqual(next(NS.db.char.fold), nil, "nothing of the live state written")
        assertTrue(not Tree.IsFolded("reputations", 469), "the live fold is as it was")
    end)
end)

test("tree: an explicit store is used as given (the LDB tooltip's own folds)", function()
    withFolds(function()
        local store = {}
        Tree.Toggle("statistics", 130, store)
        assertEqual(store["130"], false, "unfolded in the given store")
        assertTrue(Tree.IsFolded("statistics", 130), "the window's fold is untouched")
        assertEqual(names(Tree.Visible(statisticsEntries(), "statistics", store)),
            "Character,Times camped,Wealth,Consumables,Combat")
    end)
end)
