-- tests/test_ldb_tooltip.lua — the LDB tooltip's one interaction (item SMW-07 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md; the owner: "In the LDB tooltip, clicking on a
-- category's expand/collapse button does nothing - allow only this interaction"). A section's chevron folds it
-- in the tooltip alone (tooltips.ldb.folds), the tooltip redraws in place keeping its scroll, both styles carry
-- the chevrons, rows take no click and keep their hover. (The rows' inertness, the overlay and Open a row
-- from's retirement: tests/test_round7.lua and tests/test_round8.lua; the window-collapse split:
-- tests/test_round6.lua.)
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, BP = NS.Broker, NS.BrokerPanel

local function skill(key, name, category, rank, max)
    return { key = key, name = name, category = category, rank = rank, max = max, modifier = 0,
             tempPoints = 0, learned = true }
end

local function source()
    local byKey = {
        tailoring = skill("tailoring", "Tailoring", "primary", 120, 150),
        mining = skill("mining", "Mining", "primary", 90, 150),
        cooking = skill("cooking", "Cooking", "secondary", 60, 75),
        fishing = skill("fishing", "Fishing", "secondary", 70, 75),
    }
    return { model = { byKey = byKey, order = { primary = { "tailoring", "mining" },
                       secondary = { "cooking", "fishing" }, weapon = {}, other = {} } },
             statsModel = { base = {}, spell = {}, defense = {}, utility = {} }, statIndex = {},
             gains = { total = 0, byKey = {} } }
end

--- `fn` with the feed's tooltip in `style` over the fixture source; folds, style and height put back.
local function withTip(style, fn)
    local p = NS.db.profile
    local ldb = p.tooltips.ldb
    local saved = { source = B.source, style = ldb.style, height = ldb.height, folds = ldb.folds,
                    collapsed = p.layout.blocks.secondary.collapsed }
    local v = source()
    B.source = function() return v end
    ldb.style, ldb.folds = style, { blocks = {}, nodes = {} }
    local ok, err = pcall(fn)
    B.HideTooltip()
    if BP.Frame() then BP.Frame():__fire("OnHide") end
    B.source, ldb.style, ldb.height, ldb.folds = saved.source, saved.style, saved.height, saved.folds
    p.layout.blocks.secondary.collapsed = saved.collapsed
    B.SetFeed(B.DEFAULT_FEED)
    if not ok then error(err, 0) end
end

local function header(id)
    for _, h in ipairs(BP.Headers()) do if h.id == id then return h end end
end

local function panelRow(key)
    for _, r in ipairs(BP.Rows()) do if r.entry and r.entry.key == key then return r end end
end

test("ldb tooltip: a section's chevron folds it in the tooltip alone, and the tooltip redraws in place", function()
    withTip("window", function()
        B.OnEnter(M.UIParent)
        local f = BP.Frame()
        assertTrue(panelRow("cooking") ~= nil, "Secondary Professions open to start")
        local h = header("secondary")
        h.chevron:__fire("OnClick", "LeftButton")
        assertTrue(f:IsShown(), "the tooltip stays up")
        assertEqual(B.Feed(), "professions", "the same feed")
        assertTrue(panelRow("cooking") == nil and panelRow("fishing") == nil, "its rows go")
        assertTrue(panelRow("tailoring") ~= nil, "the other section keeps its")
        h = header("secondary")
        assertTrue(h.collapsed == true, "the chevron says folded")
        assertTrue(B.TipFolded("secondary"), "stored as the tooltip's own fold")
        assertTrue(NS.db.profile.tooltips.ldb.folds.blocks.secondary == true, "under tooltips.ldb.folds")
        assertFalse(NS.db.profile.layout.blocks.secondary.collapsed == true, "the window's block stays open")
        h.chevron:__fire("OnClick", "LeftButton")
        assertTrue(panelRow("cooking") ~= nil, "a second click opens it again")
        assertFalse(B.TipFolded("secondary"))
    end)
end)

test("ldb tooltip: a fold's redraw keeps the body's scroll offset, clamped to the new overflow", function()
    withTip("window", function()
        NS.db.profile.tooltips.ldb.height = 90
        B.OnEnter(M.UIParent)
        local _, most = BP.Scroll()
        assertTrue(most > 10, "the fixture overflows a short tooltip: " .. tostring(most))
        BP.SetScroll(10)
        B.ToggleTipFold("primary")
        local off, most2 = BP.Scroll()
        assertEqual(off, math.min(10, most2), "kept where it was (clamped)")
        B.ToggleTipFold("primary")
        assertEqual((BP.Scroll()), math.min(10, select(2, BP.Scroll())), "and again on the way back")
        B.OnEnter(M.UIParent)
        assertEqual((BP.Scroll()), 0, "a fresh hover starts at the top")
    end)
end)

test("ldb tooltip: Classic sections carry chevrons that fold them, and its rows take no click", function()
    withTip("classic", function()
        B.OnEnter(M.UIParent)
        local chevrons = B.Chevrons()
        assertEqual(#chevrons, 2, "one chevron per section: Primary, Secondary")
        local secondary
        for _, c in ipairs(chevrons) do if c.row.fold == "secondary" then secondary = c end end
        assertTrue(secondary ~= nil, "Secondary Professions' chevron")
        local before = #B.Hits()
        assertEqual(before, 4, "a hover area per row")
        for _, hit in ipairs(B.Hits()) do
            assertTrue(hit:GetScript("OnClick") == nil, "a row's area has no click")
            assertTrue(hit:GetScript("OnEnter") ~= nil, "it keeps its hover wash")
        end
        secondary:__fire("OnClick", "LeftButton")
        assertTrue(B.TipFolded("secondary"), "folded")
        assertTrue(B.Tip():IsShown(), "the tooltip stays up")
        assertEqual(#B.Hits(), 2, "redrawn in place: Secondary's rows are gone")
        assertEqual(#B.Chevrons(), 2, "both chevrons still drawn")
        for _, c in ipairs(B.Chevrons()) do
            if c.row.fold == "secondary" then c:__fire("OnClick", "LeftButton") end
        end
        assertEqual(#B.Hits(), 4, "unfolded again")
    end)
end)

test("ldb tooltip: the Classic header line shows the chevron's state", function()
    withTip("classic", function()
        local lines = {}
        local tip = M.CreateFrame("GameTooltip", "SkillMasterLdbFoldTip", M.UIParent)
        function tip:AddLine(t) lines[#lines + 1] = t end
        function tip:AddDoubleLine(l, r) lines[#lines + 1] = l .. " " .. tostring(r) end
        function tip:NumLines() return #lines end
        B.SetTipFolded("primary", true)
        B.FillTooltip(tip, "professions")
        local text = table.concat(lines, "\n")
        local right, down = NS.Icon("chevron-right"), NS.Icon("chevron-down")
        assertTrue(text:find(right, 1, true) ~= nil, "a folded section's chevron points right")
        assertTrue(text:find(down, 1, true) ~= nil, "an open one's points down")
        assertTrue(text:find("Tailoring", 1, true) == nil, "a folded section draws no rows")
        assertTrue(text:find("Cooking", 1, true) ~= nil)
        assertTrue(text:find("Click a header to fold", 1, true) ~= nil, "the footer says so")
    end)
end)

test("ldb tooltip: a tree header's tooltip fold is the tooltip's own, never the window's", function()
    withTip("window", function()
        local char = NS.db.char
        local savedFold = char.fold
        char.fold = {}
        local ok, err = pcall(function()
            assertTrue(NS.Tree.IsFolded("statistics", "42", B.TipNodeStore("statistics")),
                "a Statistics category starts folded in the tooltip too")
            assertEqual(B.ToggleTipNode("statistics", 42), false, "opened in the tooltip")
            assertFalse(NS.Tree.IsFolded("statistics", "42", B.TipNodeStore("statistics")))
            assertTrue(NS.Tree.IsFolded("statistics", "42"), "the window's fold is untouched")
            assertTrue(char.fold.statistics == nil or char.fold.statistics["42"] == nil, "nothing written to char.fold")
            assertEqual(NS.db.profile.tooltips.ldb.folds.nodes.statistics["42"], false)
        end)
        char.fold = savedFold
        if not ok then error(err, 0) end
    end)
end)

test("ldb tooltip: a redraw with no tooltip up does nothing", function()
    B.HideTooltip()
    assertFalse(B.RedrawTooltip(), "nothing to redraw")
end)
