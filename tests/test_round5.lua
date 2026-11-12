-- tests/test_round5.lua — the owner's round-5 feedback (2026-11-13): a detached row's action mark
-- drawn as the main window's, the Journal's table headers on a band of their own, the Journal's lock
-- mark and test mode's surfaces (the main window, the Journal and one toast of each kind).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local W, D, R = NS.MainWindow, NS.Detached, NS.Rows

local function withWorld(fn)
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(fn)
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function withDetached(id, fn)
    local s = NS.db.profile.layout.blocks[id]
    s.docked = false
    D.Refresh()
    local ok, err = pcall(fn)
    s.docked = true
    D.Refresh()
    if not ok then error(err, 0) end
end

-- ── R5-5: the detached row's action mark ────────────────────────────────────────────────────

-- The owner's screenshots (round 5): the detached window's marks read soft, the bracket's right stroke
-- at half intensity, while the main window's were crisp. The 13 px art sits centered in the 18 px
-- control, 2.5 px in, so where it lands on a physical pixel depends on the frame's own position: the
-- main window's happened to land on the grid, a detached frame's (a drop point anywhere) half a pixel
-- off, and the 1-texel strokes straddled two pixels. The art snaps to the pixel grid on every frame.
local function snapped(tex)
    return tex ~= nil and rawget(tex, "__snap") == true and rawget(tex, "__texelBias") == 0
end

test("round5 detached mark: a detached row's action mark snaps to the pixel grid, as the main window's", function()
    withWorld(function()
        local main = W.Rows()[1]
        assertTrue(main ~= nil and main.act.icon ~= nil, "the main window draws a row with its mark")
        assertTrue(snapped(main.act.icon), "the main window's mark snaps to the pixel grid")
        withDetached("weapon", function()
            local rows = D.Rows("weapon")
            assertTrue(#rows > 0, "the detached weapon block draws rows")
            for _, row in ipairs(rows) do
                assertTrue(snapped(row.act.icon), row.entry.key .. ": the detached mark snaps as the main window's")
            end
        end)
    end)
end)

test("round5 detached mark: the mark sits a whole unit down its row at any row height", function()
    local bars = NS.db.profile.bars
    local was = bars.rowHeight
    bars.rowHeight = 21   -- (21 - 18) / 2 = 1.5: half a unit off before the fix
    local ok, err = pcall(withWorld, function()
        withDetached("weapon", function()
            local row = D.Rows("weapon")[1]
            local x, y
            rawset(row.act, "SetPoint", function(_, _, _, _, ox, oy) x, y = ox, oy end)
            D.Render("weapon")
            rawset(row.act, "SetPoint", nil)
            assertEqual(x, -R.EDGE, "the mark at the header's inset")
            assertEqual(y, math.floor(y), "a whole unit down the row")
        end)
    end)
    bars.rowHeight = was
    if not ok then error(err, 0) end
end)

test("round5 detached mark: every chrome mark snaps its art (the band's controls too)", function()
    local b = NS.Chrome.IconButton(M.UIParent, "lock", "L")
    assertTrue(snapped(b.icon), "a fresh control's art snaps")
    assertFalse(b.glyph ~= nil and b.glyph:IsShown(), "the art drew, not the glyph")
end)

-- ── R5-4: the Journal's table headers ────────────────────────────────────────────────────────

local J = NS.Journal

local function sameColor(got, want, msg)
    assertTrue(got ~= nil and want ~= nil, msg .. ": painted")
    for i = 1, 3 do assertTrue(math.abs(got[i] - want[i]) < 1e-6, msg .. ": channel " .. i) end
end

local function colorOf(tex) return rawget(tex, "__color") end

local function assertBand(header, what)
    assertTrue(header.bg ~= nil, what .. ": a background band")
    sameColor(colorOf(header.bg), NS.Bar.Color("sm.headerBg"), what .. ": the block header's color")
    assertTrue(header.rule ~= nil, what .. ": a rule under it")
    assertEqual(header.rule:GetHeight(), 1, what .. ": the rule is 1 px")
    assertTrue(colorOf(header.rule) ~= nil, what .. ": the rule painted (the skin's divider)")
    local point = header.rule:GetPoint(1)
    assertEqual(point, "BOTTOMLEFT", what .. ": the rule along the band's bottom")
end

test("round5 table headers: the Log and Alts headers stand on a band of the block header's color with a rule", function()
    J.Show()
    J.SelectTab("log")
    local log = J.Frame().logPanel
    assertBand(log.header, "the Log header")
    assertEqual(log.headers[1]:GetText(), NS.L["Date"]:upper(), "the Log labels read uppercase")
    assertEqual(log.headers[5]:GetText(), NS.L["Zone"]:upper(), "every one")
    J.SelectTab("alts")
    assertBand(J.Frame().altsPanel.header, "the Alts header")
    J.SelectTab("log")
    J.Hide()
end)

test("round5 table headers: a look change repaints both bands (the Journal re-renders on LAYOUT_CHANGED)", function()
    J.Show()
    local f = J.Frame()
    f.logPanel.header.bg:SetColorTexture(0, 0, 0, 0)
    f.altsPanel.header.bg:SetColorTexture(0, 0, 0, 0)
    NS.bus:SendMessage(NS.MSG.LAYOUT_CHANGED)
    M.__fireTimers()
    sameColor(colorOf(f.logPanel.header.bg), NS.Bar.Color("sm.headerBg"), "the Log band repainted")
    sameColor(colorOf(f.altsPanel.header.bg), NS.Bar.Color("sm.headerBg"), "the Alts band repainted")
    J.Hide()
end)

-- ── R5-2: the Journal's lock mark ────────────────────────────────────────────────────────────

local function lockIcon(b) return b.icon and b.icon:GetTexture() end

test("round5 journal lock: the title bar's lock mark beside the close control toggles the one locked setting", function()
    local was = NS.GetSetting("locked")
    NS.SetByPath("locked", false)
    J.Show()
    local f = J.Frame()
    assertTrue(f.lockButton ~= nil, "the Journal carries a lock mark")
    assertEqual(f.lockButton.tip, NS.L["Lock or unlock the window"], "the main window's tooltip")
    assertEqual(lockIcon(f.lockButton), NS.Icon("unlock"), "unlocked: the open padlock")
    f.lockButton:__fire("OnClick", "LeftButton")
    assertTrue(NS.GetSetting("locked") == true, "a click locks, through the seam")
    assertEqual(lockIcon(f.lockButton), NS.Icon("lock"), "and the mark shows it")
    assertEqual(lockIcon(W.Frame() and W.Frame().lockButton or f.lockButton), NS.Icon("lock"),
        "the main window's mark follows")
    f.lockButton:__fire("OnClick", "LeftButton")
    assertTrue(NS.GetSetting("locked") == false, "a second click unlocks")
    NS.SetByPath("locked", was and true or false)
    J.Hide()
end)

test("round5 journal lock: /sm lock and /sm unlock repaint the Journal's mark", function()
    local was = NS.GetSetting("locked")
    NS.SetByPath("locked", false)
    J.Show()
    local f = J.Frame()
    NS.Slash:OnSlash("lock")
    assertEqual(lockIcon(f.lockButton), NS.Icon("lock"), "/sm lock: the closed padlock")
    NS.Slash:OnSlash("unlock")
    assertEqual(lockIcon(f.lockButton), NS.Icon("unlock"), "/sm unlock: the open one")
    J.Hide()
    NS.SetByPath("locked", true)
    J.Show()
    assertEqual(lockIcon(f.lockButton), NS.Icon("lock"), "a change while hidden shows on the next open")
    NS.SetByPath("locked", was and true or false)
    J.Hide()
end)
