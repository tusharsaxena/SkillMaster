-- tests/test_bar.lua — the data bar (plan Task 3.1): the base/bonus geometry, the tier segments and
-- markers, the text, the expiry timer and the resolved style. Since AD-80-SM (LibKa0s#80) the bar is
-- LibKa0s-Widgets-1.0's Bar, styled from this addon's settings by NS.BarStyle; the cases are kept and
-- re-pinned onto it (Compute is W.BarCompute, `tiers` the widget's `segments`, FormatTimer
-- W.BarFormatTimer, the pool W.AcquireBar / W.ReleaseBars, and a resolved color slot is a token name).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNear = T.assertNear
local W, BS = NS.Widgets, NS.BarStyle

local function fresh(styleKey)
    return W.Bar(M.UIParent, BS.Opts(styleKey or "row"))
end

test("bar: a bonus past the cap clamps the base, draws to the end and keeps the full text (Review Focus 4)", function()
    -- red under: a bonus segment that is not clamped (it would draw past the bar's end), or a text
    -- built from the clamped numbers.
    local bar = fresh()
    bar:SetValues{ value = 105, max = 110, bonus = 5, bonusKind = "perm" }
    assertNear(bar.geom.fill, 105 / 110, 1e-9, "Guns 105 / 110 base")
    assertNear(bar.geom.fill + bar.geom.bonus, 1, 1e-9, "Guns +5 reaches exactly the end")
    assertEqual(bar.text:GetText(), "105 +5 / 110")

    bar:SetValues{ value = 150, max = 150, bonus = 100, bonusKind = "temp" }
    assertEqual(bar.geom.fill, 1, "a full base")
    assertEqual(bar.geom.bonus, 0, "no room past the end: the segment draws nothing beyond it")
    assertEqual(bar.text:GetText(), "150 +100 / 150", "the text still shows the full numbers")

    bar:SetValues{ value = 107, max = 150, bonus = 100, bonusKind = "temp" }
    assertNear(bar.geom.fill, 107 / 150, 1e-9)
    assertNear(bar.geom.fill + bar.geom.bonus, 1, 1e-9, "a +100 lure at 107 / 150 stops at the end")
    assertEqual(bar.text:GetText(), "107 +100 / 150")

    bar:SetValues{ value = 160, max = 150 }
    assertEqual(bar.geom.fill, 1, "a rank above its cap clamps")
    assertEqual(bar.text:GetText(), "160 / 150")
end)

test("bar: the bonus segment wears the temp or the permanent color", function()
    local bar = fresh()
    bar:ApplyStyle{ bonusTemp = { 0.1, 0.2, 0.3, 1 }, bonusPerm = { 0.4, 0.5, 0.6, 1 } }
    bar:SetValues{ value = 10, max = 100, bonus = 5, bonusKind = "temp" }
    assertEqual(bar.bonusColor[1], 0.1, "temp")
    bar:SetValues{ value = 10, max = 100, bonus = 5, bonusKind = "perm" }
    assertEqual(bar.bonusColor[1], 0.4, "perm")
end)

test("bar: an empty cap (an unlearned skill) draws nothing and raises nothing", function()
    local bar = fresh()
    bar:SetValues{ value = 0, max = 0 }
    assertEqual(bar.geom.fill, 0)
    assertEqual(bar.geom.bonus, 0)
end)

test("bar: Rank tier colors draw a tiered bar to its last tier, its fill one segment per tier entered", function()
    -- Feedback round 2: the tier ticks gave way to a fill colored per rank tier on a scale to 300.
    local tiers = { 75, 150, 225, 300 }
    local g = W.BarCompute({ value = 121, max = 150, bonus = 10, segments = tiers }, nil, true)
    assertNear(g.fill, 121 / 300, 1e-9, "on a scale to 300, not to the cap")
    assertNear(g.bonus, 10 / 300, 1e-9, "the bonus on the same scale")
    assertEqual(#g.segments, 2, "Apprentice and Journeyman entered")
    assertNear(g.segments[1].from, 0, 1e-9)
    assertNear(g.segments[1].to, 75 / 300, 1e-9)
    assertEqual(g.segments[2].tier, 2)
    assertNear(g.segments[2].to, 121 / 300, 1e-9, "the second stops at the rank")
    assertEqual(g.text, "121 +10 / 150", "the text keeps the real cap")
    assertEqual(#W.BarCompute({ value = 300, max = 300, segments = tiers }, nil, true).segments, 4, "all four at 300")
    assertEqual(#W.BarCompute({ value = 0, max = 75, segments = tiers }, nil, true).segments, 0, "none at 0")
    local plain = W.BarCompute({ value = 121, max = 150, segments = tiers }, nil, false)
    assertTrue(plain.segments == nil, "off: no segments")
    assertNear(plain.fill, 121 / 150, 1e-9, "off: on the cap")
    local weapon = W.BarCompute({ value = 50, max = 110 }, nil, true)
    assertTrue(weapon.segments == nil and math.abs(weapon.fill - 50 / 110) < 1e-9, "untiered: as before")
end)

test("bar: markers keep the end and drop what is past it", function()
    -- The row tooltip's bar: thresholds on by default there (the window's are off, R6-4).
    local bar = fresh("tooltip")
    bar:SetValues{ value = 22, max = 100, markers = { { at = 55.6, label = "5%" }, { at = 100, label = "9%" },
                                                       { at = 120, label = "past" } } }
    assertEqual(#bar.geom.markers, 2)
    assertNear(bar.geom.markers[1].at, 0.556, 1e-9)
    assertEqual(bar.geom.markers[2].at, 1, "a marker at the cap is drawn on the end")
    assertEqual(bar.geom.markers[2].label, "9%")
end)

test("bar: the timer formats m:ss and h:mm:ss", function()
    assertEqual(W.BarFormatTimer(252), "4:12")
    assertEqual(W.BarFormatTimer(5), "0:05")
    assertEqual(W.BarFormatTimer(3725), "1:02:05")
    assertEqual(W.BarFormatTimer(-3), "0:00")
end)

test("bar: SetTimer shows the time left, ticks it, and SetTimer(nil) disarms the OnUpdate", function()
    -- red under: an OnUpdate left armed after the timer is cleared (a per-frame cost nobody sees).
    local bar = fresh()
    local saved = M.__now
    M.__now = 1000
    bar:SetTimer(1252)
    assertTrue(bar.timer:IsShown(), "the timer shows")
    assertEqual(bar.timer:GetText(), "4:12")
    assertTrue(bar:GetScript("OnUpdate") ~= nil, "armed while a timer runs")
    M.__now = 1010
    bar:__fire("OnUpdate", 1)
    assertEqual(bar.timer:GetText(), "4:02", "the tick re-reads the clock")
    bar:SetTimer(nil)
    assertFalse(bar.timer:IsShown(), "hidden")
    assertTrue(bar:GetScript("OnUpdate") == nil, "disarmed")
    M.__now = saved
end)

test("bar: a timer that runs out clears itself", function()
    local bar = fresh()
    local saved = M.__now
    M.__now = 1000
    bar:SetTimer(1001)
    M.__now = 1002
    bar:__fire("OnUpdate", 1)
    assertFalse(bar.timer:IsShown(), "hidden once expired")
    assertTrue(bar:GetScript("OnUpdate") == nil, "and disarmed")
    M.__now = saved
end)

test("bar: the resolved style reads the profile and the skin's tokens", function()
    local style = BS.Resolve("row")
    assertEqual(style.height, NS.db.profile.bars.height)
    -- re-pinned: a slot that follows the skin is its token NAME, the widget resolves it at paint time
    local bg = BS.Color(style.bg)
    assertTrue(type(bg) == "table" and #bg >= 3, "the background resolves to a color")
    assertFalse(style.segmented, "Rank tier colors off by default")
    assertTrue(BS.Color(style.bonusTemp) ~= nil and BS.Color(style.bonusPerm) ~= nil, "both bonus colors")
    local mini = BS.Resolve("mini")
    assertTrue(mini.height < style.height, "a mini bar is shorter")
    assertFalse(mini.showText, "a mini bar draws no text")
end)

test("bar: the pool hands bars back in order and clears their timers on release", function()
    local pool = NS.Pool.New()
    local a = W.AcquireBar(pool, M.UIParent, BS.Opts("row"))
    local b = W.AcquireBar(pool, M.UIParent, BS.Opts("row"))
    a:SetTimer(GetTime and 5000 or 5000)
    W.ReleaseBars(pool)
    assertTrue(a:GetScript("OnUpdate") == nil, "a released bar runs no timer")
    assertTrue(W.AcquireBar(pool, M.UIParent, BS.Opts("row")) == a, "position 1 gets its bar back")
    assertTrue(W.AcquireBar(pool, M.UIParent, BS.Opts("row")) == b)
    W.ReleaseBars(pool)
end)

test("bar: a secret width (a tooltip-anchored bar, tainted) lays out on the last plain width", function()
    -- red under: arithmetic on the secret GetWidth (Forever, 2026-11-12: the host bar's Layout, now the widget's, from
    -- RowTooltip.placeBar, "attempt to perform arithmetic on a secret number value").
    local Kit = T.kit
    local restore = Kit.installSecretValue()
    local bar = fresh("tooltip")
    bar.knownWidth = 200
    bar.GetWidth = function() return Kit.secret(200) end
    local ok, err = pcall(bar.SetValues, bar, { value = 74, max = 125 })
    restore()
    assertTrue(ok, tostring(err))
    assertNear(bar.fill:GetWidth(), (200 - 2) * 74 / 125, 1e-6, "the fill sized from the plain width")
end)

-- AD-80-SM: the swap keeps every bar's look. The widget draws this addon's owner tokens, so the
-- colors a bar paints are the ones modules/Bar.lua painted, and the bonus slots are remapped from
-- the widget's defaults (sem.info / sem.good) onto cl.bonusTemp / cl.bonusPerm.
test("bar: the bars are LibKa0s-Widgets-1.0's Bar, owned by this addon's skin", function()
    local bar = fresh()
    assertTrue(bar.Repaint == M.LibStub("LibKa0s-Widgets-1.0").__barMethods.Repaint, "the library's widget")
    assertEqual(bar.owner, "CharacterLedger", "this addon's skin owner")
    assertTrue(NS.Bar == nil, "modules/Bar.lua is gone")
end)

test("bar: the bonus slots are remapped onto cl.bonusTemp and cl.bonusPerm", function()
    local style = BS.Resolve("row")
    assertEqual(style.bonusTemp, "cl.bonusTemp", "the temp slot names the owner token")
    assertEqual(style.bonusPerm, "cl.bonusPerm", "the permanent slot names the owner token")
    local bar = fresh()
    bar:SetValues{ value = 10, max = 100, bonus = 5, bonusKind = "temp" }
    local want = NS.SkinColor("cl.bonusTemp")
    for i = 1, 4 do assertNear(bar.bonusColor[i], want[i] or 1, 1e-9, "temp channel " .. i) end
    bar:SetValues{ value = 10, max = 100, bonus = 5, bonusKind = "perm" }
    want = NS.SkinColor("cl.bonusPerm")
    for i = 1, 4 do assertNear(bar.bonusColor[i], want[i] or 1, 1e-9, "perm channel " .. i) end
end)

test("bar: a bar paints the owner tokens it painted before the swap", function()
    local bar = fresh()
    bar:SetValues{ value = 50, max = 100 }
    local fill = NS.SkinColor("cl.barFill")
    for i = 1, 4 do assertNear(bar.fillColor[i], fill[i] or 1, 1e-9, "the fill, channel " .. i) end
    local bg, want = M.__paint(bar.bg).color, NS.SkinColor("cl.barBg")
    for i = 1, 3 do assertNear(bg[i], want[i], 1e-6, "the background, channel " .. i) end
    -- a player's own pick (the colors not following the skin) is handed over as the color itself
    local colors = NS.db.profile.bars.colors
    local saved = colors.fromSkin
    colors.fromSkin = false
    local style = BS.Resolve("row")
    colors.fromSkin = saved
    assertTrue(type(style.bonusTemp) == "table", "the player's temp color, not a token name")
end)
