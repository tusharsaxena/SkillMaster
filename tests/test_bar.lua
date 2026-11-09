-- tests/test_bar.lua — the bar widget (plan Task 3.1): the base/bonus geometry, the ticks and markers,
-- the text, the expiry timer and the resolved style.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNear = T.assertNear
local Bar = NS.Bar

local function fresh(styleKey)
    return Bar.Create(M.UIParent, styleKey or "row")
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

test("bar: ticks at or beyond the cap are dropped", function()
    -- red under: a tick filter of `<= max` (a tick drawn on the end) or none at all.
    local bar = fresh()
    bar:SetValues{ value = 146, max = 150, ticks = { 75, 150, 225, 300 } }
    assertEqual(#bar.geom.ticks, 1, "only 75 stays under a 150 cap")
    assertNear(bar.geom.ticks[1], 0.5, 1e-9)
    local shown = 0
    for _, t in ipairs(bar.tickTextures) do if t:IsShown() then shown = shown + 1 end end
    assertEqual(shown, 1, "one tick texture on screen")
    bar:SetValues{ value = 10, max = 300, ticks = { 75, 150, 225, 300 } }
    assertEqual(#bar.geom.ticks, 3, "75, 150 and 225 under 300")
end)

test("bar: markers keep the end and drop what is past it", function()
    local bar = fresh()
    bar:SetValues{ value = 22, max = 100, markers = { { at = 55.6, label = "5%" }, { at = 100, label = "9%" },
                                                       { at = 120, label = "past" } } }
    assertEqual(#bar.geom.markers, 2)
    assertNear(bar.geom.markers[1].at, 0.556, 1e-9)
    assertEqual(bar.geom.markers[2].at, 1, "a marker at the cap is drawn on the end")
    assertEqual(bar.geom.markers[2].label, "9%")
end)

test("bar: the timer formats m:ss and h:mm:ss", function()
    assertEqual(Bar.FormatTimer(252), "4:12")
    assertEqual(Bar.FormatTimer(5), "0:05")
    assertEqual(Bar.FormatTimer(3725), "1:02:05")
    assertEqual(Bar.FormatTimer(-3), "0:00")
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
    local style = Bar.ResolveStyle("row")
    assertEqual(style.height, NS.db.profile.bars.height)
    assertTrue(type(style.bg) == "table" and #style.bg >= 3, "the background is a color")
    assertTrue(type(style.tick) == "table", "the tick color is a token")
    assertTrue(type(style.bonusTemp) == "table" and type(style.bonusPerm) == "table", "both bonus colors")
    local mini = Bar.ResolveStyle("mini")
    assertTrue(mini.height < style.height, "a mini bar is shorter")
    assertFalse(mini.showText, "a mini bar draws no text")
end)

test("bar: the pool hands bars back in order and clears their timers on release", function()
    local pool = Bar.NewPool()
    local a = Bar.Acquire(pool, M.UIParent, "row")
    local b = Bar.Acquire(pool, M.UIParent, "row")
    a:SetTimer(GetTime and 5000 or 5000)
    Bar.ReleaseAll(pool)
    assertTrue(a:GetScript("OnUpdate") == nil, "a released bar runs no timer")
    assertTrue(Bar.Acquire(pool, M.UIParent, "row") == a, "position 1 gets its bar back")
    assertTrue(Bar.Acquire(pool, M.UIParent, "row") == b)
    Bar.ReleaseAll(pool)
end)
