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
