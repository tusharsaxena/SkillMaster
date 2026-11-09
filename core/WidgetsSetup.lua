local _, NS = ...
-- core/WidgetsSetup.lua — NS.Widgets from LibKa0s-Widgets-1.0. Reached today: TestStrip, the main
-- window's test-mode marker (modules/MainWindow.lua), CopyWindow, the probe's report
-- (modules/Probe.lua), ContextMenu, the row menu (modules/Interact.lua), and CloseMenu, which the
-- window's OnHide calls so the menu never outlives it.

local lib = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
if lib then
    NS.Widgets = lib
    return
end

-- Degrade, never error: no strip, and the window says "Test mode" in its title instead.
NS.Widgets = {
    TestStrip  = function() return nil end,
    CopyWindow = function() return nil end,
    ContextMenu = function() return nil end,
    CloseMenu  = function() end,
}
