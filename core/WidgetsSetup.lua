local _, NS = ...
-- core/WidgetsSetup.lua — NS.Widgets from LibKa0s-Widgets-1.0. Reached today: TestStrip, the windows'
-- test and sim strips, docked under each title bar (`dock = "title"`, Widgets minor 27; the main
-- window, the Journal and the LDB tooltip's Main window style), Footer and FOOTER, the window footers
-- and their height through NS.Chrome.Footer (the main window's legend and the Journal's Alts hint
-- line), CopyWindow, the probe's report (modules/Probe.lua),
-- ContextMenu, the row menu (modules/Interact.lua), and CloseMenu, which the window's OnHide calls
-- so the menu never outlives it.

local lib = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
if lib then
    NS.Widgets = lib
    return
end

-- Degrade, never error: no strip, and the window says "Test mode" in its title instead.
NS.Widgets = {
    TestStrip  = function() return nil end,
    Footer     = function() return nil end,   -- NS.Chrome.Footer builds a bare frame of FOOTER.HEIGHT
    FOOTER     = { HEIGHT = 24, PAD = 8, GRIP = 22, MARK = 16, MARK_ART = 12, MARK_GAP = 4 },
    CopyWindow = function() return nil end,
    ContextMenu = function() return nil end,
    CloseMenu  = function() end,
}
