-- tests/test_round2_layout.lua — the owner's second round-2 follow-up: the window's scroll gutter,
-- the rows' Go (map-marker) and Open (book) marks, the detached block's centered title and row
-- padding, Block order as a boxed list (settings/BoxList.lua, after
-- ConsumableMaster's Priority list), and the Marks defaults (Spark off, no tier ticks).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local W, D, B = NS.MainWindow, NS.Detached, NS.Blocks

local function aceGUI() return M.__libs["AceGUI-3.0"] end

local function withWorld(fn)
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(fn)
    if B.Settings("weapon").docked == false then B:Dock("weapon") end
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function windowRow(key)
    for _, row in ipairs(W.Rows()) do
        if row.entry and row.entry.key == key then return row end
    end
end

local function schemaRow(path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

-- ── the window ──────────────────────────────────────────────────────────────────────────────

test("round2 layout: the window is wide enough for its body and the scroll bar's whole gutter", function()
    withWorld(function()
        local f = W.Frame()
        local width, found
        rawset(f, "SetWidth", function(_, v) width = v end)
        rawset(f.scroll, "SetPoint", function(_, point, _, _, x) if point == "BOTTOMRIGHT" then found = x end end)
        NS.Blocks:SetCollapsed("weapon", true)   -- a new row set: a full layout runs
        M.__fireTimers()
        NS.Blocks:SetCollapsed("weapon", false)
        M.__fireTimers()
        rawset(f, "SetWidth", nil)
        rawset(f.scroll, "SetPoint", nil)
        -- 4 px of edges, then the template's 6 px offset, the 16 px bar and 4 px clear of the border.
        assertEqual(width, W.ContentWidth() + 4 + 26, "the window grows by the gutter")
        assertEqual(found, -(2 + 26), "the scroll frame stops short of the gutter")
    end)
end)

-- ── the rows' marks ─────────────────────────────────────────────────────────────────────────

test("round3 marks: every row carries the one action mark (ph:sign-in), a stat row too (round 4)", function()
    withWorld(function()
        local lw, fish, axes = windowRow("leatherworking"), windowRow("fishing"), windowRow("axes")
        assertTrue(lw and fish and axes, "the sample rows are drawn")
        assertTrue(NS.Icon("ph:sign-in") ~= nil, "declared and shipped")
        local unlearned, stat
        for _, row in ipairs(W.Rows()) do
            if row.entry and row.entry.learned == false then unlearned = unlearned or row end
            if row.kind == "stat" then stat = stat or row end
        end
        assertTrue(unlearned ~= nil, "an unlearned row is drawn")
        assertTrue(stat ~= nil, "a stat row is drawn")
        for _, row in ipairs({ lw, fish, axes, unlearned, stat }) do
            assertTrue(row.act:IsShown(), row.entry.key .. ": the action mark shows")
            assertEqual(row.act.icon:GetTexture(), NS.Icon("ph:sign-in"), row.entry.key .. ": one look")
            assertTrue(row.act:GetScript("OnClick") ~= nil, "the mark is the action (owner feedback round 4)")
        end
    end)
end)

-- ── the detached block ──────────────────────────────────────────────────────────────────────

test("round2 layout: a detached block's body starts under the skin's band, its rows padded above and below", function()
    withWorld(function()
        B:Detach("weapon")
        M.__fireTimers()
        local f = D.Frame("weapon")
        local top = D.TitleHeight(f)
        assertTrue(top >= D.TITLE_H, "never under the old title height")
        local y, h
        rawset(f.body, "SetPoint", function(_, point, _, _, _, oy) if point == "TOPLEFT" then y = oy end end)
        rawset(f, "SetHeight", function(_, v) h = v end)
        D.Render("weapon")
        rawset(f.body, "SetPoint", nil)
        assertEqual(y, -top, "the body starts below the band")
        local rows = D.Rows("weapon")
        assertTrue(#rows > 0, "the block draws rows")
        assertEqual(rows[1].layY, D.ROW_PAD, "the first row sits ROW_PAD below the band")
        local sum = 0
        for _, r in ipairs(rows) do sum = sum + r:GetHeight() end
        assertEqual(h, top + D.ROW_PAD + sum + D.ROW_PAD + D.PAD, "and ROW_PAD more under the last")
        B:SetCollapsed("weapon", true)
        M.__fireTimers()
        D.Render("weapon")
        assertEqual(h, top + D.PAD, "collapsed: the header alone")
        rawset(f, "SetHeight", nil)
        B:SetCollapsed("weapon", false)
    end)
end)

-- ── the Marks defaults ──────────────────────────────────────────────────────────────────────

test("round2 layout: Spark is off by default, the tier ticks are gone, Rank tier colors is a Marks row", function()
    local P = NS.defaults.profile.bars
    assertFalse(P.spark, "Spark off")
    assertTrue(P.ticks == nil and schemaRow("bars.ticks") == nil, "no tier ticks")
    assertFalse(P.tierColors, "Rank tier colors off until the player turns it on")
    local r = schemaRow("bars.tierColors")
    assertTrue(r ~= nil and r.group == NS.L["Marks"], "on the Marks tab")
    for i = 1, 4 do
        assertTrue(schemaRow("bars.colors.tier" .. i) == nil, "no tier swatch: the tiers are the category's shades")
    end
    assertTrue(r.desc:find("By category", 1, true) ~= nil, "the tooltip says it works under By category only")
end)

-- ── the boxed lists ─────────────────────────────────────────────────────────────────────────

local function created(from, wtype)
    local out = {}
    local list = aceGUI().__created
    for i = from + 1, #list do
        local w = list[i]
        if w.type == wtype and not w.__released then out[#out + 1] = w end
    end
    return out
end

local function showTab(page, name, tab)
    local panel = M.__subcategories[name]
    panel:Show()
    panel:__fire("OnShow")
    local from = #aceGUI().__created
    assertTrue(NS.Helpers.SelectTab(page, tab), "the tab is selected")
    M.__fireTimers()
    return panel, from
end

local function hide(panel)
    panel:Hide()
    panel:__fire("OnHide")
    M.__fireTimers()
end

test("round2 layout: Layout > Block order draws one boxed row per block in order, its eye showing or hiding it", function()
    local panel, from = showTab("layout", "Layout", NS.L["Block order"])
    local labels = created(from, "SkillMasterListLabel")
    local ordered = B.Ordered()
    assertEqual(#labels, #ordered, "one row per block")
    for i, id in ipairs(ordered) do assertEqual(labels[i].text, NS.BlockDefs[id].title, "row " .. i) end
    local eyes = created(from, "Icon")
    local first = ordered[1]
    eyes[1].callbacks.OnClick()
    M.__fireTimers()
    assertFalse(B.Settings(first).shown, "the eye hides the block")
    NS.SetByPath("layout.blocks." .. first .. ".shown", true)
    M.__fireTimers()
    hide(panel)
end)

-- ── owner feedback round 4: show hidden rows again from the window ─────────────────────────

local function headerFor(id)
    for _, h in ipairs(W.Headers()) do if h.id == id then return h end end
end

test("round4 restore: a block hiding rows shows an eye mark that brings them back; none otherwise", function()
    -- red under: a hidden row that only the settings page could show again
    withWorld(function()
        local h = headerFor("weapon")
        assertFalse(h.restore:IsShown(), "nothing hidden: no mark")
        NS.SetByPath("skills.hidden.axes", true)
        NS.SetByPath("skills.hidden.bows", true)
        NS.SetByPath("skills.hidden.fishing", true)   -- another block's
        M.__fireTimers()
        h = headerFor("weapon")
        assertTrue(windowRow("axes") == nil and windowRow("bows") == nil, "both hidden")
        assertTrue(h.restore:IsShown(), "the mark shows while the block hides rows")
        assertEqual(h.restore.icon:GetTexture(), NS.Icon("eye"))
        assertEqual(h.restore.tip, "2 hidden rows. Click to show them again.")
        assertTrue(headerFor("secondary").restore:IsShown(), "Secondary hides Fishing: its own mark")
        h.restore:GetScript("OnClick")(h.restore, "LeftButton")
        M.__fireTimers()
        assertTrue(windowRow("axes") ~= nil and windowRow("bows") ~= nil, "both back")
        assertFalse(headerFor("weapon").restore:IsShown(), "and the mark gone")
        assertTrue(NS.db.profile.skills.hidden.fishing, "another block's hidden row stays hidden")
        assertEqual(B.RestoreHidden("secondary"), 1)
        M.__fireTimers()
        assertTrue(windowRow("fishing") ~= nil)
    end)
end)

test("round4 restore: a stat block's mark brings back its own stats", function()
    withWorld(function()
        NS.SetByPath("stats.hidden.strength", true)
        M.__fireTimers()
        local keys, kind = B.HiddenKeys("stats_base")
        assertEqual(kind, "stats")
        assertEqual(table.concat(keys, ","), "strength")
        assertEqual(#B.HiddenKeys("stats_spell"), 0, "not another stat block's")
        assertEqual(B.RestoreHidden("stats_base"), 1)
        assertTrue(NS.db.profile.stats.hidden.strength ~= true, "shown again")
    end)
end)
