-- tests/test_mainwindow.lua — the main window: toggle, chrome, test-mode marker, lock and position.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local W = NS.Windows.Get("professions")   -- SMW-04: the window behind NS.MainWindow

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
    assertEqual(f.title:GetText(), "Character Ledger \194\183 Professions")
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
    local p = NS.db.profile.windows.professions.point
    assertEqual(p and p.point, "TOPLEFT")
    assertEqual(p and p.x, 40)
    W.ResetPosition()
    assertFalse(NS.db.profile.windows.professions.point, "Reset position forgets the drop point")
    W.Hide()
end)

-- ---------------------------------------------------------------------------------------------
-- The resize grip (AF-SM-RESIZE; standalone-windows, Resizing): the corner grip sizes the window,
-- Window width and Window height take the size on the release, and Locked hides and refuses it.
-- ---------------------------------------------------------------------------------------------

local function layout() return NS.db.profile.windows.professions end   -- SMW-04: the Professions window's

test("window: a grip drag reflows the columns at most once per frame and redraws once, after the release", function()
    -- red under: no grip on the main window; a handler that runs the full redraw (W.Render) from
    -- OnSizeChanged or once per size change; the size written per tick or never.
    local L0 = layout()
    local savedW, savedH, savedCols = L0.width, L0.maxHeight, L0.columns
    L0.columns, L0.width, L0.maxHeight = 1, 420, 560
    NS.db.profile.windows.professions.point = false
    W.Show()
    W.Refresh(true)
    local f = W.Frame()
    local grip = f.resizeGrip
    assertTrue(grip ~= nil and grip:IsShown(), "the main window has a shown resize grip")
    local realRender, realRelayout = W.Render, W.Relayout
    local renders, layouts = 0, 0
    W.Render = function(...) renders = renders + 1 return realRender(...) end
    W.Relayout = function(...) layouts = layouts + 1 return realRelayout(...) end
    local driver = f.resizeDriver
    local function frameTick() driver:__fire("OnUpdate", 0.016) end
    local widths = {}
    local function spyWidth(frame, key)
        rawset(frame, "SetWidth", function(_, v) widths[key] = v end)
    end
    spyWidth(f.content, "content")
    spyWidth(f.columns[1], "column")
    spyWidth(f, "frame")
    -- Where the window stands: the grab pins it by its top-left there (NS.Chrome.PinTopLeft).
    local pins = {}
    rawset(f, "GetLeft", function() return 300 end)
    rawset(f, "GetTop", function() return 700 end)
    rawset(f, "SetPoint", function(_, ...) pins[#pins + 1] = { ... } end)
    rawset(f, "GetPoint", function() return "TOPLEFT", M.UIParent, "BOTTOMLEFT", 300, 700 end)

    grip:__fire("OnMouseDown", "LeftButton")
    assertTrue(f.__sizingCount > 0, "the grab starts sizing")
    local pin = pins[#pins]
    assertTrue(pin and pin[1] == "TOPLEFT" and pin[3] == "BOTTOMLEFT" and pin[4] == 300 and pin[5] == 700,
        "pinned by its top-left where it stood, before sizing")
    local perFrame = {}
    for i = 1, 3 do
        local before = layouts
        for step = 1, 3 do
            f:__setGeom(500 + i * 10 + step, 520 + i * 20 + step)
            f:__fire("OnSizeChanged", f:GetWidth(), f:GetHeight())
        end
        frameTick()
        perFrame[i] = layouts - before
    end
    assertEqual(renders, 0, "no full redraw while sizing")
    assertEqual(L0.width, 420, "Window width is not written per tick")
    assertEqual(L0.maxHeight, 560, "nor Window height")
    for i = 1, 3 do assertTrue(perFrame[i] <= 1, "frame " .. i .. " ran " .. perFrame[i] .. " layout passes") end
    -- The cheap pass reflows the body to the new width: 533 less the edges (4) and the scroll gutter (26).
    assertEqual(widths.content, 503, "the body follows the grip")
    assertEqual(widths.column, 503, "and so does its column")
    assertTrue(widths.frame == nil, "nothing but the grip sizes the frame while it is dragged")

    grip:__fire("OnMouseUp", "LeftButton")
    M.__fireTimers()   -- the one coalesced LAYOUT_CHANGED the release's bulk write queues
    assertEqual(renders, 1, "the full redraw runs once, after the release")
    -- Window width is a column's: the frame's 533 less the scroll gutter and edges, plus a column's own
    -- 20, is 523; both rows step by 10, so the slider's grid takes 520 and 583 takes 580.
    assertEqual(L0.width, 520, "Window width takes the dragged width, on its step grid")
    assertEqual(L0.maxHeight, 580, "Window height takes the dragged height, on its step grid")
    assertEqual(widths.frame, 530, "the redraw keeps the dragged width, snapped to the grid")
    for _, fr in ipairs({ f.content, f.columns[1], f }) do rawset(fr, "SetWidth", nil) end
    for _, k in ipairs({ "GetLeft", "GetTop", "SetPoint", "GetPoint" }) do rawset(f, k, nil) end
    local p = NS.db.profile.windows.professions.point
    assertTrue(p and p.point == "TOPLEFT" and p.relPoint == "BOTTOMLEFT" and p.x == 300 and p.y == 700,
        "the release saves the pinned point with the size")

    W.Render, W.Relayout = realRender, realRelayout
    L0.width, L0.maxHeight, L0.columns = savedW, savedH, savedCols
    W.ResetPosition()
    W.Refresh(true)
    W.Hide()
end)

test("window: the grip's bounds are Window width's and Window height's range, per column count", function()
    local L0 = layout()
    local savedCols = L0.columns
    L0.columns = 1
    W.Show()
    W.Refresh(true)
    local f = W.Frame()
    M.UIParent:__setGeom(1920, 1000)
    W.Refresh(true)
    local minW, minH, maxW, maxH = f:GetResizeBounds()
    assertEqual(minW, 330, "one column: Window width 320 plus the gutter and edges")
    assertEqual(minH, 200, "Window height's minimum")
    assertEqual(maxW, 810, "Window width 800 plus the gutter and edges")
    assertEqual(maxH, 1000, "Window height 1200, never past the screen")
    L0.columns = 2
    W.Refresh(true)
    minW = f:GetResizeBounds()
    assertEqual(minW, 636, "two columns of 300 px bodies, the 6 px gap, the gutter and edges")
    -- red under: a screen cap in UIParent units, which lets a window at Master scale 2 grow past it.
    L0.columns = 1
    local savedScale = NS.GetSetting("scale")
    M.UIParent:__setGeom(1200, 1000)
    local frameScale = 1   -- the base mock's GetScale answers no number, so the pair is recorded here
    rawset(f, "SetScale", function(_, v) frameScale = v end)
    rawset(f, "GetScale", function() return frameScale end)
    NS.SetByPath("scale", 2)
    W.ApplySettings()
    local _, _, maxW2, maxH2 = f:GetResizeBounds()
    assertEqual(maxW2, 600, "at Master scale 2 the width cap is half the screen, in the frame's units")
    assertEqual(maxH2, 500, "and so is the height cap")
    NS.SetByPath("scale", savedScale)
    W.ApplySettings()
    rawset(f, "SetScale", nil)
    rawset(f, "GetScale", nil)
    M.UIParent.__geomLive = nil
    L0.columns = savedCols
    W.Refresh(true)
    W.Hide()
end)

test("window: Locked hides the grip and refuses a grab; /cl unlock and the lock mark bring it back", function()
    -- red under: a grip that stays shown, or sizes, while the window is locked.
    W.Show()
    local f = W.Frame()
    local grip = f.resizeGrip
    NS.SetByPath("locked", true)
    assertFalse(grip:IsShown(), "a locked window hides its grip")
    local before = f.__sizingCount
    grip:__fire("OnMouseDown", "LeftButton")
    assertEqual(f.__sizingCount, before, "and a grab on it does not size the window")
    grip:__fire("OnMouseUp", "LeftButton")
    NS.Slash:OnSlash("unlock")
    assertTrue(grip:IsShown(), "/cl unlock shows the grip")
    NS.Slash:OnSlash("lock")
    assertFalse(grip:IsShown(), "/cl lock hides it")
    f.lockButton:GetScript("OnClick")(f.lockButton, "LeftButton")
    assertTrue(grip:IsShown(), "the header's lock mark unlocks it")
    assertFalse(NS.GetSetting("locked"))
    W.Hide()
end)

test("broker: the LDB tooltip has no resize grip", function()
    -- The owner's ruling (AF-SM-RESIZE): only the main window resizes.
    local p = NS.BrokerPanel.Frame()
    assertTrue(p.resizeGrip == nil, "the broker tooltip is not resizable")
end)
