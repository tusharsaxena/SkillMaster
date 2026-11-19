-- tests/test_window_chrome.lua — the window chrome of the LibKa0s v1.105.0 adoption run (Ka0sAddonsCommonTasks
-- docs/2026-11-17-LIBKA0S_V1_105_ADOPTION, wave A; WowAddonStandards v2.113.0):
--   AD-88-SM, LibKa0s#88: every window's test and sim strip is docked by the library directly under
--     the title bar (Widgets minor 27, `dock = "title"`; preview-mode, *Where the strip sits*), and
--     what sits below the title bar moves down by the strip's own `BodyOffset` while it shows:
--     the main window, the Journal and the LDB tooltip's Main window style;
--   AD-89-SM, LibKa0s#89: the main window's footer (the bonus legend) is the library's `Footer`
--     (Widgets minor 27; standalone-windows, *The footer*), FOOTER.HEIGHT tall, the body ending
--     that far above the window's bottom edge plus the host's gap;
--   the review fixes (AD-88-SM + AD-89-SM): the title band's bottom derived from the band itself
--     (NS.Chrome.TitleBottom, as Detached's D.TitleHeight is; 31 only with no band measured), the
--     Journal's Alts hint line on a window footer (Widgets' Footer, shown with the Alts tab), and the
--     library-absent rungs of the title bar and both footers.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local W, J, Br, BP, C = NS.MainWindow, NS.Journal, NS.Broker, NS.BrokerPanel, NS.Chrome
local Widgets = M.LibStub("LibKa0s-Widgets-1.0")

--- Record every point production sets on `region` while `fn` runs (the kit records a frame's
--- points only on a texture): answers { [point] = { rel, relPoint, x, y } }.
local function pointsDuring(region, fn)
    local got = {}
    rawset(region, "SetPoint", function(_, point, rel, relPoint, x, y)
        got[point] = { rel = rel, relPoint = relPoint, x = x, y = y }
    end)
    local ok, err = pcall(fn)
    rawset(region, "SetPoint", nil)
    if not ok then error(err, 0) end
    return got
end

--- Assert `strip` is docked under `bar`: the library's dock methods, and its anchors on the bar's
--- bottom edge, full width (inset 0), placed by the library (strip:Place), never by the host.
local function assertDockedUnder(strip, bar, what)
    assertTrue(strip ~= nil, what .. ": the strip is built")
    assertTrue(bar ~= nil, what .. ": the window names its title bar")
    assertTrue(type(strip.BodyOffset) == "function" and type(strip.Place) == "function",
        what .. ": docked by the library (BodyOffset, Place)")
    local pts = pointsDuring(strip, function() strip:Place() end)
    assertTrue(pts.TOPLEFT and pts.TOPLEFT.rel == bar, what .. ": TOPLEFT on the title bar")
    assertEqual(pts.TOPLEFT.relPoint, "BOTTOMLEFT", what .. ": at its bottom-left")
    assertTrue(pts.TOPRIGHT and pts.TOPRIGHT.rel == bar, what .. ": TOPRIGHT on the title bar")
    assertEqual(pts.TOPRIGHT.relPoint, "BOTTOMRIGHT", what .. ": at its bottom-right")
    assertEqual(strip:BodyOffset(), 0, what .. ": no offset while hidden")
end

--- Arm `strip`'s height at the published TEST_STRIP.HEIGHT: a docked strip's BodyOffset reads its own
--- height, which the client answers and the kit's unarmed frame answers as 0.
local function arm(strip)
    if strip then strip:__setGeom(0, Widgets.TEST_STRIP.HEIGHT) end
end

local function withTestMode(fn)
    if NS.IsTestMode() then NS.ToggleTestMode() end
    NS.ToggleTestMode()
    local ok, err = pcall(fn)
    if NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    if not ok then error(err, 0) end
end

-- ── AD-88-SM: the main window ────────────────────────────────────────────────────────────────

test("chrome AD-88: the main window's test and sim strips dock under its title bar (the skin's band)", function()
    W.Show()
    local f = W.Frame()
    assertTrue(f.titleBar == NS.Skin.Band(f), "the title bar is the skin's band, where it paints the bar")
    assertDockedUnder(f.strip, f.titleBar, "test strip")
    assertDockedUnder(f.simStrip, f.titleBar, "sim strip")
    W.Hide()
end)

test("chrome AD-88: the main window's body sits under the title bar and moves down by the strip's BodyOffset", function()
    W.Show()
    local f = W.Frame()
    arm(f.strip)
    local function summaryY() return select(5, f.summaryIcon:GetPoint(1)) end
    local ok, err = pcall(function()
        W.Render()
        assertEqual(summaryY(), -(C.TITLE_BOTTOM + 4), "no strip: the summary under the title band")
        withTestMode(function()
            W.Render()
            local off = f.strip:BodyOffset()
            assertEqual(off, Widgets.TEST_STRIP.HEIGHT, "the shown strip's offset is its height")
            assertEqual(summaryY(), -(C.TITLE_BOTTOM + off + 4), "moved down by the offset")
        end)
        W.Render()
        assertEqual(summaryY(), -(C.TITLE_BOTTOM + 4), "and back up when the strip goes")
    end)
    W.Hide()
    if not ok then error(err, 0) end
end)

-- ── AD-89-SM: the main window's footer ───────────────────────────────────────────────────────

test("chrome AD-89: the main window's legend is the library's Footer, FOOTER.HEIGHT (24 px) tall", function()
    W.Show()
    local f = W.Frame()
    local foot = f.legend
    assertEqual(Widgets.FOOTER.HEIGHT, 24, "the published footer height")
    assertTrue(foot ~= nil and foot.line ~= nil and type(foot.SetLeft) == "function"
        and type(foot.SetGrip) == "function", "built by Widgets.Footer (its hairline and its lines)")
    assertTrue(foot.rule == nil, "no hand-drawn rule of its own: the footer's hairline is the library's")
    assertTrue(f.legendText[1]:GetParent() == foot and f.legend.markerLabel:GetParent() == foot,
        "the legend's swatches and labels ride the footer")
    W.Hide()
end)

test("chrome AD-89: the main window's body ends FOOTER.HEIGHT above its bottom edge, plus the gap", function()
    W.Show()
    local f = W.Frame()
    W.Hide()
    local pts = pointsDuring(f.scroll, function()
        NS.ToggleTestMode()   -- a marker change is a new layout
        W.Show()
        W.Render()
    end)
    NS.ToggleTestMode()
    W.Render()
    W.Hide()
    M.__fireTimers()
    assertTrue(pts.BOTTOMRIGHT ~= nil, "the scroll is placed")
    assertEqual(pts.BOTTOMRIGHT.y, Widgets.FOOTER.HEIGHT + 2, "FOOTER.HEIGHT plus the host's 2 px gap")
end)

-- ── AD-88-SM: the Journal ────────────────────────────────────────────────────────────────────

test("chrome AD-88: the Journal's strip docks under its title bar, the tabs moved down by BodyOffset", function()
    J.Show()
    local f = J.Frame()
    local ok, err = pcall(function()
        assertTrue(f.titleBar == NS.Skin.Band(f), "the title bar is the skin's band")
        assertDockedUnder(f.strip, f.titleBar, "journal strip")
        arm(f.strip)
        if NS.IsTestMode() then NS.ToggleTestMode() end
        local on = pointsDuring(f.tabs.log, function() NS.ToggleTestMode(); J.Render() end)
        local ok2, err2 = pcall(function()
            assertTrue(f.strip:IsShown(), "the strip shows in test mode")
            assertEqual(f.strip:BodyOffset(), Widgets.TEST_STRIP.HEIGHT, "the offset is the strip's height")
        end)
        local back = pointsDuring(f.tabs.log, function() NS.ToggleTestMode(); J.Render() end)
        M.__fireTimers()
        if not ok2 then error(err2, 0) end
        assertEqual(on.TOPLEFT.y, -(C.TITLE_BOTTOM + 2 + Widgets.TEST_STRIP.HEIGHT), "tabs under the strip")
        assertEqual(back.TOPLEFT.y, -(C.TITLE_BOTTOM + 2), "and under the title band once it goes")
    end)
    J.Hide()
    if not ok then error(err, 0) end
end)

-- ── AD-88-SM: the LDB tooltip's Main window style ────────────────────────────────────────────

test("chrome AD-88: the Main window style tooltip's strip docks under its title band", function()
    local p = NS.db.profile.tooltips.ldb
    local saved = p.style
    p.style = "window"
    local ok, err = pcall(function()
        local f = BP.Frame()
        assertTrue(f.titleBar == NS.Skin.Band(f), "the title bar is the skin's band")
        assertDockedUnder(f.strip, f.titleBar, "tooltip strip")
        arm(f.strip)
        withTestMode(function()
            local pts = pointsDuring(f.list, function()
                Br.OnEnter(M.UIParent)
            end)
            assertTrue(f.strip:IsShown(), "the strip shows in test mode")
            assertEqual(pts.TOPLEFT.y, -(C.TITLE_BOTTOM + f.strip:BodyOffset() + 1), "the body under the strip")
            -- The kit's Hide fires no OnHide: release the test-mode rows (their bar timers) as the client does.
            Br.HideTooltip()
            f:__fire("OnHide")
        end)
    end)
    Br.HideTooltip()
    p.style = saved
    if not ok then error(err, 0) end
end)

-- ── review fixes: the title band's bottom read from the band ─────────────────────────────────

--- Stand `band` in for a skin whose band is `h` tall at an inset of `inset` (a flat border of that
--- size), as the client answers it; answers the restore.
local function fakeBand(band, h, inset)
    rawset(band, "GetHeight", function() return h end)
    rawset(band, "GetPoint", function() return "TOPLEFT", band, "TOPLEFT", inset, -inset end)
    return function()
        rawset(band, "GetHeight", nil)
        rawset(band, "GetPoint", nil)
    end
end

test("chrome review: the title band's bottom is read from the band, 31 only with none measured", function()
    W.Show()
    local f = W.Frame()
    W.Hide()
    assertEqual(C.TitleBottom(f), C.TITLE_BOTTOM, "an unmeasured band: the 1 px inset plus title.height")
    assertEqual(C.TITLE_BOTTOM, 31, "the fallback")
    assertEqual(C.TitleBottom(nil), C.TITLE_BOTTOM, "no window: the fallback")
    assertEqual(C.TitleBottom({}), C.TITLE_BOTTOM, "no title bar: the fallback")
    local restore = fakeBand(f.titleBar, 30, 2)
    local ok, err = pcall(function()
        assertEqual(C.TitleBottom(f), 32, "a 2 px flat border: the band's height plus its inset")
    end)
    restore()
    if not ok then error(err, 0) end
end)

test("chrome review: the main window's body follows the band's own bottom", function()
    W.Show()
    local f = W.Frame()
    local restore = fakeBand(f.titleBar, 30, 2)
    local ok, err = pcall(function()
        W.Render()
        assertEqual(select(5, f.summaryIcon:GetPoint(1)), -(32 + 4), "the summary under a 32 px band")
    end)
    restore()
    W.Render()
    W.Hide()
    if not ok then error(err, 0) end
end)

test("chrome review: the Journal's tabs follow the band's own bottom", function()
    J.Show()
    local f = J.Frame()
    local restore = fakeBand(f.titleBar, 30, 2)
    local ok, err = pcall(function()
        local pts = pointsDuring(f.tabs.log, function() J.Render() end)
        assertTrue(pts.TOPLEFT ~= nil, "a band change places the tabs again")
        assertEqual(pts.TOPLEFT.y, -(32 + 2), "the tabs under a 32 px band")
    end)
    restore()
    J.Render()
    J.Hide()
    if not ok then error(err, 0) end
end)

test("chrome review: the LDB tooltip's body follows the band's own bottom", function()
    local p = NS.db.profile.tooltips.ldb
    local saved = p.style
    p.style = "window"
    local f = BP.Frame()
    local restore = fakeBand(f.titleBar, 30, 2)
    local ok, err = pcall(function()
        local pts = pointsDuring(f.list, function() Br.OnEnter(M.UIParent) end)
        assertEqual(pts.TOPLEFT.y, -(32 + 1), "the body under a 32 px band")
    end)
    restore()
    Br.HideTooltip()
    p.style = saved
    if not ok then error(err, 0) end
end)

-- ── review fixes: the Journal's Alts hint line is a window footer ────────────────────────────

local ALTS_HINT = NS.L["Snapshots update on login, logout and every skill change. Right-click a character to forget it."]

test("chrome review: the Journal's Alts hint is the library's Footer, shown with the Alts tab only", function()
    J.Show()
    local f = J.Frame()
    local ok, err = pcall(function()
        local foot = f.altsFooter
        assertTrue(foot ~= nil and foot.line ~= nil and type(foot.SetLeft) == "function"
            and type(foot.SetGrip) == "function", "built by Widgets.Footer (its hairline and its lines)")
        assertEqual(foot.left:GetText(), ALTS_HINT, "the hint is the footer's left line")
        assertTrue(foot.__grip == true, "its right side clears the window's resize grip")
        assertTrue(f.altsPanel.foot == nil, "no hand-built hint line in the panel")
        J.SelectTab("alts")
        assertTrue(foot:IsShown(), "shown on the Alts tab")
        J.SelectTab("log")
        assertTrue(not foot:IsShown(), "hidden on the Log tab, which gives its height back to the body")
    end)
    J.Hide()
    if not ok then error(err, 0) end
end)

test("chrome review: the Alts panel ends FOOTER.HEIGHT plus the gap above the bottom, the Log panel at PAD", function()
    J.Show()
    local f = J.Frame()
    local restore = fakeBand(f.titleBar, 30, 2)   -- a band change places both panels again
    local alts, log
    local ok, err = pcall(function()
        log = pointsDuring(f.logPanel, function()
            alts = pointsDuring(f.altsPanel, function() J.Render() end)
        end)
    end)
    restore()
    J.Render()
    J.Hide()
    if not ok then error(err, 0) end
    assertEqual(alts.BOTTOMRIGHT.y, Widgets.FOOTER.HEIGHT + 8, "the Alts body ends above its footer")
    assertEqual(log.BOTTOMRIGHT.y, 12, "the Log body keeps its PAD")
end)

-- ── review fixes: the library-absent rungs ───────────────────────────────────────────────────

local loadDegraded = dofile("tests/degraded_env.lua")

--- A library-absent load, initialized and enabled as the client would.
local function degraded()
    local NS2, M2 = loadDegraded()
    NS2.addon:OnInitialize()
    NS2.addon:OnEnable()
    return NS2, M2
end

test("chrome degraded: with no skin library the title bar is a bare frame of the band's rect", function()
    local NS2, M2 = degraded()
    local host = M2.CreateFrame("Frame", nil, M2.UIParent)
    local h
    local real = M2.CreateFrame
    local bar
    M2.CreateFrame = function(...)
        local fr = real(...)
        rawset(fr, "SetHeight", function(_, v) h = v end)
        return fr
    end
    local ok, err = pcall(function() bar = NS2.Chrome.TitleBar(host) end)
    M2.CreateFrame = real
    if not ok then error(err, 0) end
    assertTrue(bar ~= nil and bar ~= host, "a frame of its own")
    assertEqual(h, NS2.Chrome.TITLE_BOTTOM - 1, "the band's height, under its 1 px inset")
    assertEqual(NS2.Chrome.TitleBottom({ titleBar = bar }), NS2.Chrome.TITLE_BOTTOM, "the fallback bottom")
end)

test("chrome degraded: with no widgets library a footer is a bare frame of FOOTER.HEIGHT with its left line", function()
    local NS2, M2 = degraded()
    local host = M2.CreateFrame("Frame", nil, M2.UIParent)
    local real = M2.CreateFrame
    local heights = {}
    M2.CreateFrame = function(...)
        local fr = real(...)
        rawset(fr, "SetHeight", function(self, v) heights[self] = v end)
        return fr
    end
    local foot
    local ok, err = pcall(function() foot = NS2.Chrome.Footer(host, { left = "hint" }) end)
    M2.CreateFrame = real
    if not ok then error(err, 0) end
    assertTrue(foot ~= nil, "a footer frame")
    assertEqual(heights[foot], 24, "FOOTER.HEIGHT, from the stub's figures")
    assertTrue(foot.line == nil, "no hairline without the library")
    assertEqual(foot.left:GetText(), "hint", "the left line still says its words")
    foot:SetLeft("other")
    assertEqual(foot.left:GetText(), "other", "and SetLeft changes them")
end)

test("chrome degraded: the main window and the Journal open without LibKa0s, their footers bare", function()
    local NS2 = degraded()
    NS2.MainWindow.Show()
    local f = NS2.MainWindow.Frame()
    assertTrue(NS2.MainWindow.IsShown(), "the main window opens")
    assertTrue(f.titleBar ~= nil and f.strip == nil, "a bare title bar, no strip")
    assertTrue(f.legend ~= nil and f.legend.line == nil, "the legend on a bare footer")
    NS2.MainWindow.Hide()
    NS2.Journal.Show()
    local j = NS2.Journal.Frame()
    assertTrue(j.titleBar ~= nil and j.strip == nil, "the Journal: a bare title bar, no strip")
    NS2.Journal.SelectTab("alts")
    assertTrue(j.altsFooter ~= nil and j.altsFooter:IsShown(), "the Alts footer shows on its tab")
    assertEqual(j.altsFooter.left:GetText(), ALTS_HINT, "with the hint")
    NS2.Journal.SelectTab("log")
    NS2.Journal.Hide()
end)
