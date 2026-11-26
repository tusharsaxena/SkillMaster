-- tests/test_r5_feedback.lua — the owner's round 5 feedback on the six windows and brokers (items R5-SM-01..07
-- of Ka0sAddonsCommonTasks docs/2026-11-26-OWNER_FEEDBACK_ROUND5/00_PLAN.md): no hint tooltip on a fold chevron,
-- the whole header row folds, a pin mark on each pinned row, an icon per display broker, `/sm toggle` showing
-- or hiding every window, no profession listed twice, and a session with every window open raising nothing.
-- Test mode's sample fills every window and feed, so each case reads no live client state.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Br, BP = NS.Broker, NS.BrokerPanel

-- The client's standing names, as tests/test_reputations.lua mocks them.
local LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

--- `fn` with test mode on (the sample character in every window and feed); everything put back after.
local function withSample(fn)
    local saved = { M.GetText, M.UnitSex, M.UnitFactionGroup }
    M.GetText = function(key) return LABELS[tonumber(tostring(key):match("(%d+)$"))] end
    M.UnitSex = function() return 2 end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    local folds, char = NS.db.profile.tooltips.ldb.folds, NS.db.char.fold
    NS.db.profile.tooltips.ldb.folds, NS.db.char.fold = { blocks = {}, nodes = {} }, {}
    if not NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    -- Test mode's folds are the session's (modules/Tree.lua): each case starts from the defaults.
    for _, fid in ipairs({ "currencies", "reputations", "statistics" }) do
        local store = NS.Tree.Store(fid)
        for k in pairs(store) do store[k] = nil end
    end
    local ok, err = pcall(fn)
    Br.HideTooltip()
    Br.SetFeed(Br.DEFAULT_FEED)
    NS.Windows.HideAll()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    NS.db.profile.tooltips.ldb.folds, NS.db.char.fold = folds, char
    M.GetText, M.UnitSex, M.UnitFactionGroup = saved[1], saved[2], saved[3]
    M.__fireTimers()
    if not ok then error(err, 0) end
end

--- `fn` with the LDB tooltip in `style` ("window" or "classic"); the style put back after.
local function withStyle(style, fn)
    local ldb = NS.db.profile.tooltips.ldb
    local saved = ldb.style
    ldb.style = style
    local ok, err = pcall(fn)
    Br.HideTooltip()
    ldb.style = saved
    if not ok then error(err, 0) end
end

local function shownWindow(fid)
    local W = NS.Windows.Get(fid)
    W.Show()
    W.Refresh(true)
    return W
end

local function treeHeaders(rows)
    local out = {}
    for _, row in ipairs(rows) do if row.treeHeader then out[#out + 1] = row end end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- R5-SM-01: a fold chevron has no hint tooltip, in the windows and in the LDB tooltip
-- ---------------------------------------------------------------------------------------------

test("r5 sm-01: no fold chevron carries a hint tooltip, in any window or in the LDB tooltip", function()
    withSample(function()
        local seenTree = 0
        for _, fid in ipairs(NS.FAMILY_ORDER) do
            local W = shownWindow(fid)
            assertTrue(#W.Headers() > 0, fid .. ": a block header drawn")
            for _, h in ipairs(W.Headers()) do
                assertEqual(h.chevron.tip, nil, fid .. ": the block header's chevron says nothing on hover")
            end
            for _, row in ipairs(treeHeaders(W.Rows())) do
                seenTree = seenTree + 1
                assertEqual(row.fold.tip, nil, fid .. ": a tree header's chevron says nothing on hover")
            end
            W.Hide()
        end
        assertTrue(seenTree > 0, "the tree windows drew their headers")
        withStyle("window", function()
            local panelTree = 0
            for _, fid in ipairs(NS.FAMILY_ORDER) do
                Br.OnEnter(M.UIParent, fid)
                for _, h in ipairs(BP.Headers()) do
                    if h.id then assertEqual(h.chevron.tip, nil, fid .. ": the tooltip's section chevron") end
                end
                for _, row in ipairs(treeHeaders(BP.Rows())) do
                    panelTree = panelTree + 1
                    assertEqual(row.fold.tip, nil, fid .. ": the tooltip's tree chevron")
                end
            end
            assertTrue(panelTree > 0, "the tooltip drew tree headers")
        end)
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-02: a click anywhere on a collapsible header folds and unfolds it
-- ---------------------------------------------------------------------------------------------

local function headerFor(headers, id)
    for _, h in ipairs(headers) do if h.id == id then return h end end
    return nil
end

local function treeHeaderRow(rows, depth)
    for _, row in ipairs(rows) do
        if row.treeHeader and (row.tree.depth or 0) == depth then return row end
    end
    return nil
end

test("r5 sm-02: in a window, a click on a block header's body and on a tree header's row folds it, at every depth", function()
    withSample(function()
        local W = shownWindow("professions")
        local h = headerFor(W.Headers(), "primary")
        h:__fire("OnClick", "LeftButton")
        assertTrue(NS.Blocks.Settings("primary").collapsed, "the header's body collapsed the block")
        h = headerFor(W.Headers(), "primary")
        h:__fire("OnClick", "LeftButton")
        assertTrue(not NS.Blocks.Settings("primary").collapsed, "and opened it again")
        W.Hide()
        local S = shownWindow("statistics")
        local top = treeHeaderRow(S.Rows(), 0)
        local key = top.entry.nodeKey
        assertTrue(NS.Tree.IsFolded("statistics", key), "a category starts folded")
        top:__fire("OnClick", "LeftButton")
        assertTrue(not NS.Tree.IsFolded("statistics", key), "a click on its row unfolded it")
        S.Refresh(true)
        local child = treeHeaderRow(S.Rows(), 1)
        assertTrue(child ~= nil, "a sub-category header under it")
        local ckey = child.entry.nodeKey
        local was = NS.Tree.IsFolded("statistics", ckey)
        child:__fire("OnClick", "LeftButton")
        assertEqual(NS.Tree.IsFolded("statistics", ckey), not was, "one level in, the row folds too")
    end)
end)

test("r5 sm-02: in the Main window style LDB tooltip, a click on a section header's body or a tree header's row folds it", function()
    withSample(function()
        withStyle("window", function()
            Br.OnEnter(M.UIParent, "professions")
            local h = headerFor(BP.Headers(), "primary")
            local calls = {}
            rawset(h, "EnableMouse", function(_, on) calls[#calls + 1] = on end)
            Br.OnEnter(M.UIParent, "professions")
            rawset(h, "EnableMouse", nil)
            assertEqual(calls[#calls], true, "the header's body takes the pointer")
            h = headerFor(BP.Headers(), "primary")
            h:__fire("OnClick", "LeftButton")
            assertTrue(Br.TipFolded("primary"), "a click on the header folded the section in the tooltip")
            assertTrue(not NS.Blocks.Settings("primary").collapsed, "the window's collapse untouched")
            for _, k in ipairs({ "detach", "sort", "filter", "restore" }) do
                assertTrue(not h[k]:IsShown(), "no " .. k .. " mark in the tooltip")
            end
            Br.OnEnter(M.UIParent, "statistics")
            local top = treeHeaderRow(BP.Rows(), 0)
            local key = top.entry.nodeKey
            local store = Br.TipNodeStore("statistics")
            assertTrue(NS.Tree.IsFolded("statistics", key, store), "a category starts folded in the tooltip")
            local windowFold = NS.Tree.IsFolded("statistics", key)
            top:__fire("OnClick", "LeftButton")
            assertTrue(not NS.Tree.IsFolded("statistics", key, store), "a click on its row unfolded it")
            assertEqual(NS.Tree.IsFolded("statistics", key), windowFold, "the window's fold untouched")
            local child = treeHeaderRow(BP.Rows(), 1)
            assertTrue(child ~= nil, "the redraw lists a sub-category header")
            local ckey = child.entry.nodeKey
            local was = NS.Tree.IsFolded("statistics", ckey, store)
            child:__fire("OnClick", "LeftButton")
            assertEqual(NS.Tree.IsFolded("statistics", ckey, store), not was, "one level in, the row folds too")
            -- A leaf row still opens nothing.
            for _, row in ipairs(BP.Rows()) do
                if not row.treeHeader then
                    assertTrue(row:GetScript("OnClick") == nil, "a leaf row takes no click")
                end
            end
        end)
    end)
end)

--- The feed's own tooltip dressed as tests/test_broker.lua dresses it: a global name, its lines, and a
--- TextLeftN / TextRightN region per line (the addon finds a line by the frame's name, as in the client).
local function dressOwnTip()
    local tip = Br.Tip()
    if tip.GetName and tip:GetName() == Br.TIP_NAME and type(tip:NumLines()) == "number" then return tip end
    local name = Br.TIP_NAME
    tip.lines = {}
    rawset(tip, "GetName", function() return name end)
    rawset(tip, "NumLines", function(self) return #self.lines end)
    rawset(tip, "ClearLines", function(self) self.lines = {} end)
    rawset(tip, "SetOwner", function(self, o) self.lines, self.__owner = {}, o end)
    rawset(tip, "GetOwner", function(self) return self.__owner end)
    local function region(n)
        for _, side in ipairs({ "Left", "Right" }) do
            local key = name .. "Text" .. side .. n
            _G[key] = _G[key] or tip:CreateFontString()
        end
    end
    rawset(tip, "AddLine", function(self, text) self.lines[#self.lines + 1] = { text } region(#self.lines) end)
    rawset(tip, "AddDoubleLine", function(self, l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end)
    return tip
end

test("r5 sm-02: in the Classic LDB tooltip, a header line's hit spans the whole line, at every depth", function()
    withSample(function()
        withStyle("classic", function()
            dressOwnTip()
            for _ = 1, 2 do   -- the top categories open, then the ones under them
                Br.OnEnter(M.UIParent, "statistics")
                for _, c in ipairs(Br.Chevrons()) do
                    if c.row.node ~= nil then
                        NS.Tree.SetFolded("statistics", c.row.node, false, Br.TipNodeStore("statistics"))
                    end
                end
            end
            Br.OnEnter(M.UIParent, "statistics")
            local points, buttons = {}, {}
            for _, c in ipairs(Br.Chevrons()) do
                buttons[#buttons + 1] = c
                rawset(c, "SetPoint", function(self, p, rel, rp, x)
                    points[self] = points[self] or {}
                    points[self][p] = { rel = rel, rp = rp, x = x }
                end)
            end
            Br.OnEnter(M.UIParent, "statistics")
            for _, c in ipairs(buttons) do rawset(c, "SetPoint", nil) end
            local depths = {}
            for c, p in pairs(points) do
                depths[c.row.depth or 0] = true
                assertTrue(p.LEFT and p.LEFT.x == -2, "the hit starts at the line's left edge")
                assertTrue(p.RIGHT and p.RIGHT.rel == Br.Tip() and p.RIGHT.x == -4,
                    "and runs to the tooltip's right inset")
            end
            local seen = {}
            for d in pairs(depths) do seen[#seen + 1] = d end
            assertTrue(depths[0] and depths[1], "top and nested headers both measured: " .. table.concat(seen, ","))
        end)
    end)
end)
