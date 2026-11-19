-- tests/test_header_buttons.lua — AD-86-SM, LibKa0s#86 (Ka0sAddonsCommonTasks
-- docs/2026-11-17-LIBKA0S_V1_105_ADOPTION, wave B; WowAddonStandards v2.113.0, standalone-windows,
-- *Title-bar controls*): every window this addon owns builds its title-bar marks with LibKa0s
-- Widgets' HeaderButtons, right-aligned, left to right the window's own extras, then settings, then
-- close, one 18 px slot, PAD (6) from the corner and GAP (6) apart, and the settings mark opens this
-- addon's settings through the opener its launcher registered:
--   the main window (lock, journal, expand / collapse all, settings, close),
--   the Journal (lock, settings, close),
--   the trainer popup (settings, close; it sits a strata over the settings panel, so it hides first),
--   a detached block's band and a merged window's band (their block-header marks, then settings;
--     no close, as before).
-- The library-absent rung builds the same strip from this addon's own marks.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local W, J, B, D, G, TP = NS.MainWindow, NS.Journal, NS.Blocks, NS.Detached, NS.Groups, NS.TrainerPopup
local Widgets = M.LibStub("LibKa0s-Widgets-1.0")

--- Count NS.OpenOptionsPanel calls while `fn` runs (the launcher's registered opener calls it).
local function countOpens(fn)
    local saved, n = NS.OpenOptionsPanel, 0
    NS.OpenOptionsPanel = function() n = n + 1 end
    local ok, err = pcall(fn)
    NS.OpenOptionsPanel = saved
    if not ok then error(err, 0) end
    return n
end

local function click(b) b:GetScript("OnClick")(b, "LeftButton") end

local function join(list) return table.concat(list, ",") end

--- The strip's offsets from the corner, outermost first, at the library's pitch.
local function pitch(n)
    local H = Widgets.HEADER
    local out, off = {}, H.PAD
    for i = 1, n do out[i] = -off; off = off + H.SIZE + H.GAP end
    return out
end

local function assertStrip(hb, keys, what)
    assertTrue(type(hb) == "table", what .. ": the window carries the library's strip (frame.headerButtons)")
    assertEqual(join(hb.order), join(keys), what .. ": left to right, extras . settings . close")
    local want = pitch(#keys)
    for i = #keys, 1, -1 do
        local key = keys[i]
        assertEqual(hb.offsets[key], want[#keys - i + 1], what .. ": " .. key .. " at the library's pitch")
    end
end

test("AD-86 main window: lock, journal, expand / collapse all, settings, close on HeaderButtons", function()
    W.Show()
    local f = W.Frame()
    local hb = f.headerButtons
    assertStrip(hb, { "lock", "journal", "toggleAll", "settings", "close" }, "the main window")
    assertTrue(hb.settings == f.settingsButton and hb.close == f.close, "the window keeps its names")
    assertTrue(hb.extras.lock == f.lockButton and hb.extras.journal == f.journalButton
        and hb.extras.toggleAll == f.toggleAllButton, "every extra by its old name")
    assertEqual(f.settingsButton.tip, NS.L["Open the settings panel"], "the settings mark keeps its words")
    assertEqual(f.settingsButton.__tip, NS.L["Open the settings panel"], "and the library shows them")
    W.Hide()
end)

test("AD-86 main window: the settings mark opens the settings through the launcher's opener", function()
    W.Show()
    local f = W.Frame()
    assertEqual(countOpens(function() click(f.settingsButton) end), 1, "one click, the settings panel")
    W.Hide()
end)

--- One open block with a row, so a click on Expand / Collapse all has something to fold.
local function withOpenBlock(fn)
    local skills = { byKey = { guns = { key = "guns", name = "Guns", category = "weapon", rank = 105, max = 110,
                                        tempPoints = 0, modifier = 0, learned = true } },
                     order = { weapon = { "guns" } } }
    local stats = { base = {}, spell = {}, defense = {}, utility = {} }
    local saved = B.source
    B.source = function() return skills, stats end
    local ok, err = pcall(fn)
    B.source = saved
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].collapsed = false end
    W.Hide()
    if not ok then error(err, 0) end
end

test("AD-86 main window: the expand / collapse all mark's tooltip follows what a click does", function()
    -- The library's HeaderButton shows `__tip` on hover, so that is the field pinned through a toggle
    -- (review fix: the mark's own `tip` alone is not what the player reads).
    withOpenBlock(function()
        W.Show()
        W.Render()
        local b = W.Frame().toggleAllButton
        assertTrue(W.AnyExpanded(), "a block is open")
        assertEqual(b.__tip, NS.L["Collapse all blocks"], "open: the library shows Collapse all")
        click(b)
        M.__fireTimers()
        W.Render()
        assertEqual(b.__tip, NS.L["Expand all blocks"], "all collapsed: the library shows Expand all")
        assertEqual(b.tip, b.__tip, "and the mark's own words agree")
        click(b)
        M.__fireTimers()
        W.Render()
        assertEqual(b.__tip, NS.L["Collapse all blocks"], "expanded again: back to Collapse all")
    end)
end)

test("AD-86 journal: lock, settings, close on HeaderButtons, and settings opens the settings", function()
    J.Show()
    local f = J.Frame()
    local hb = f.headerButtons
    assertStrip(hb, { "lock", "settings", "close" }, "the Journal")
    assertTrue(hb.extras.lock == f.lockButton and hb.close == f.close and hb.settings == f.settingsButton,
        "the window keeps its names")
    assertEqual(f.lockButton.tip, NS.L["Lock or unlock the window"], "the lock keeps its words")
    assertEqual(countOpens(function() click(f.settingsButton) end), 1, "one click, the settings panel")
    J.Hide()
end)

test("AD-86 trainer popup: settings, close on HeaderButtons; settings hides the popup first", function()
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    local ok, err = pcall(function()
        TP.Show("fistWeapons")
        local f = TP.Frame()
        assertStrip(f.headerButtons, { "settings", "close" }, "the trainer popup")
        assertTrue(f.headerButtons.close == f.close and f.headerButtons.settings == f.settingsButton,
            "the window keeps its names")
        assertTrue(f:IsShown(), "the popup is open")
        assertEqual(countOpens(function() click(f.settingsButton) end), 1, "one click, the settings panel")
        assertTrue(not f:IsShown(), "and the popup, a strata over the panel, hid first")
    end)
    TP.Hide()
    M.UnitFactionGroup = savedFaction
    if not ok then error(err, 0) end
end)

--- A detached block and a merged window open, `fn(band, merged)`; everything docked again after.
local function withBands(fn)
    B:Detach("weapon")
    M.__fireTimers()
    local b = NS.db.profile.layout.blocks
    b.primary.docked, b.other.docked = false, false
    D.Refresh()
    local gid = G.Merge("primary", "other", "bottom")
    M.__fireTimers()
    local ok, err = pcall(fn, D.Frame("weapon"), G.Frame(gid))
    for _, id in ipairs(NS.BLOCKS) do
        local s = NS.db.profile.layout.blocks[id]
        s.filter, s.docked, s.collapsed = "all", true, false
    end
    NS.db.profile.layout.groups = {}
    D.Refresh()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

test("AD-86 detached and merged bands: a settings mark in the corner, opening the settings", function()
    withBands(function(band, merged)
        for _, w in ipairs({ { "a detached block's band", band }, { "a merged window's band", merged } }) do
            local what, f = w[1], w[2]
            local hb = f.headerButtons
            assertTrue(type(hb) == "table", what .. ": the library's strip")
            assertEqual(join(hb.order), "settings", what .. ": settings alone, no close (it has none)")
            assertTrue(hb.close == nil, what .. ": no close is added")
            assertTrue(hb.settings ~= nil and hb.settings == f.settingsButton, what .. ": the settings mark")
            assertEqual(hb.offsets.settings, -Widgets.HEADER.PAD, what .. ": in the corner")
            local inParts = false
            for _, p in ipairs(f.bandParts) do if p == f.settingsButton then inParts = true end end
            assertTrue(inParts, what .. ": shown and hidden with the band")
            assertEqual(countOpens(function() click(f.settingsButton) end), 1, what .. ": opens the settings")
        end
    end)
end)

--- Record the x of every RIGHT point production sets on each of `regions` while `fn` runs (the kit
--- records a frame's points only on a texture): answers { [region] = x }.
local function rightXDuring(regions, fn)
    local got = {}
    for _, r in ipairs(regions) do
        rawset(r, "SetPoint", function(self, point, _, _, x) if point == "RIGHT" then got[self] = x end end)
    end
    local ok, err = pcall(fn)
    for _, r in ipairs(regions) do rawset(r, "SetPoint", nil) end
    if not ok then error(err, 0) end
    return got
end

test("AD-86 detached and merged bands: the skin's header places settings in the corner, the marks inward at the pitch", function()
    withBands(function(band, merged)
        local H = Widgets.HEADER
        local was = NS.GetSetting("skin.skin")
        local other
        for _, s in ipairs(M.LibStub("LibKa0s-Skin-1.0"):Skins()) do if s.key ~= was then other = s.key break end end
        local regions = { band.settingsButton, band.dock, band.collapse, merged.settingsButton, merged.dockAll }
        local got = rightXDuring(regions, function()
            NS.SetByPath("skin.skin", other)   -- a switch places every recorded header again
            M.__fireTimers()
        end)
        NS.SetByPath("skin.skin", was or NS.DEFAULT_SKIN)
        M.__fireTimers()
        for _, w in ipairs({ { "a detached block's band", band, band.dock }, { "a merged window's band", merged, merged.dockAll } }) do
            local what, f, inner = w[1], w[2], w[3]
            assertEqual(got[f.settingsButton], -H.PAD, what .. ": settings PAD from the corner")
            assertEqual(got[inner], -(H.PAD + H.SIZE + H.GAP), what .. ": the dock mark next, GAP inward")
        end
        assertEqual(got[band.collapse], -(H.PAD + 2 * (H.SIZE + H.GAP)), "the detached band's collapse mark next")
    end)
end)

test("AD-86 detached and merged bands: without a skin's header, every mark GAP inward of the one before", function()
    -- Review fix: the no-skin rung (S.Header placed nothing) stood the dock GAP from settings but the
    -- other marks 2 px apart; D.PlaceInward, which both bands' builds call, keeps the strip's one pitch.
    withBands(function(band, merged)
        local _, gap = NS.Chrome.HeaderPitch()
        assertEqual(gap, Widgets.HEADER.GAP, "the strip's pitch is the library's")
        local chains = {
            { "a detached block's band", band.settingsButton,
              { band.dock, band.collapse, band.sort, band.filter, band.restore } },
            { "a merged window's band", merged.settingsButton, { merged.dockAll, merged.collapseAll } },
        }
        for _, c in ipairs(chains) do
            local what, anchorMark, marks = c[1], c[2], c[3]
            local placed = {}
            for _, m in ipairs(marks) do
                rawset(m, "SetPoint", function(self, point, rel, _, x)
                    if point == "RIGHT" then placed[self] = { rel, x } end
                end)
            end
            local ok, err = pcall(D.PlaceInward, anchorMark, marks, gap)
            for _, m in ipairs(marks) do rawset(m, "SetPoint", nil) end
            if not ok then error(err, 0) end
            local prev = anchorMark
            for i, m in ipairs(marks) do
                local p = placed[m]
                assertTrue(p ~= nil and p[1] == prev, what .. ": mark " .. i .. " left of the one before")
                assertEqual(p[2], -gap, what .. ": mark " .. i .. " GAP inward")
                prev = m
            end
        end
    end)
end)

-- ── the library-absent rung ──────────────────────────────────────────────────────────────────

local loadDegraded = dofile("tests/degraded_env.lua")

test("AD-86 degraded: without LibKa0s the main window and the Journal still build the strip, settings opening the panel", function()
    local NS2 = loadDegraded()
    NS2.addon:OnInitialize()
    NS2.addon:OnEnable()
    NS2.MainWindow.Show()
    local f = NS2.MainWindow.Frame()
    local hb = f.headerButtons
    assertTrue(type(hb) == "table", "the same strip, this addon's marks")
    assertEqual(join(hb.order), "lock,journal,toggleAll,settings", "extras . settings (no close without Core)")
    local n = 0
    NS2.OpenOptionsPanel = function() n = n + 1 end
    click(f.settingsButton)
    assertEqual(n, 1, "the settings mark opens the panel")
    NS2.MainWindow.Hide()
    NS2.Journal.Show()
    assertEqual(join(NS2.Journal.Frame().headerButtons.order), "lock,settings", "the Journal's strip")
    NS2.Journal.Hide()
end)

