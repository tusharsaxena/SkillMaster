-- tests/test_mainwindow.lua — the main window: toggle, chrome, test-mode marker, lock and position.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local W = NS.MainWindow

test("window: Toggle shows it, and again hides it", function()
    W.Hide()
    assertTrue(W.Toggle(), "shown")
    assertTrue(W.IsShown(), "IsShown after show")
    W.Toggle()
    assertFalse(W.IsShown(), "hidden after the second toggle")
end)

test("window: the chrome is the shared one: the title, the wrapped close control, MEDIUM strata", function()
    W.Show()
    local f = W.Frame()
    assertEqual(f.title:GetText(), "Skill Master")
    assertTrue(f.close ~= nil, "the close control was built through NS.MakeCloseButton")
    assertEqual(f:GetFrameStrata(), NS.Constants.LAYERS.STRATA.WINDOW)
    local found = false
    for _, name in ipairs(M.UISpecialFrames) do if name == W.FRAME_NAME then found = true end end
    assertTrue(found, "Escape closes the window (UISpecialFrames)")
    W.Hide()
end)

test("window: test mode shows the localized strip, and turning it off hides it", function()
    W.Show()
    NS.ToggleTestMode()
    local strip = W.Frame().strip
    assertTrue(strip ~= nil and strip:IsShown(), "the test strip shows in test mode")
    assertEqual(strip.text:GetText(), "Test mode: the skills shown are sample data.")
    NS.ToggleTestMode()
    assertFalse(strip:IsShown(), "and hides when test mode ends")
    W.Hide()
end)

test("window: combat ends test mode (preview-mode)", function()
    W.Show()
    NS.ToggleTestMode()
    NS.addon:OnEnterCombat()
    assertFalse(NS.IsTestMode(), "test mode ended")
    assertFalse(W.Frame().strip:IsShown(), "and the marker went with it")
    W.Hide()
end)

test("window: locked refuses the drag; unlocked drags and saves the drop point", function()
    W.Show()
    local f = W.Frame()
    local realStart, started = f.StartMoving, 0
    f.StartMoving = function() started = started + 1 end
    NS.SetByPath("locked", true)
    f:GetScript("OnDragStart")(f)
    assertEqual(started, 0, "a locked window refused the drag")
    NS.SetByPath("locked", false)
    f:GetScript("OnDragStart")(f)
    assertEqual(started, 1, "an unlocked window starts moving")
    f.StartMoving = realStart
    local realGetPoint = f.GetPoint
    f.GetPoint = function() return "TOPLEFT", M.UIParent, "TOPLEFT", 40, -50 end
    f:GetScript("OnDragStop")(f)
    f.GetPoint = realGetPoint
    local p = NS.db.profile.window.point
    assertEqual(p and p.point, "TOPLEFT")
    assertEqual(p and p.x, 40)
    W.ResetPosition()
    assertFalse(NS.db.profile.window.point, "Reset position forgets the drop point")
    W.Hide()
end)
