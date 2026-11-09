local addonName, NS = ...
-- core/LauncherSetup.lua — the launcher (launcher): ONE LibDataBroker object registered twice,
-- through LibKa0s-Launcher-1.0, which owns the click (left: settings, right: the options menu) and
-- the status tooltip. Built at load; :Register() waits for OnEnable, when db.global.minimap exists.
--
-- LOAD-BEARING: reads NS.Constants (the brand and the 128 px logo) at file load.

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

local function minimapStore()
    local g = NS.db and NS.db.global
    return type(g) == "table" and g.minimap or nil
end

-- The menu's toggles call the SAME handlers their verbs and the window call.
local function runVerb(name)
    for _, command in ipairs(NS.COMMANDS or {}) do
        if command[1] == name then return command[3]("") end
    end
end

if not lib then
    local missing = NS.L["%s, so there is no minimap button and no broker plugin."]:format(NS.LIBKA0S_MISSING)
    local said = false
    NS.Launcher = {
        Register = function()
            if not said then said = true NS.Print(missing) end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        SetShown     = function(_, shown)
            local t = minimapStore()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = lib:New({
    name    = addonName,                     -- the registration name LibDBIcon keys the position by
    icon    = NS.Constants.LOGO_ICON_PATH,
    label   = NS.Constants.BRAND,            -- plain text, never the TOC Title (launcher-§1)
    minimap = minimapStore,                  -- db.global.minimap: shared with the Minimap button row

    openSettings   = function() NS.OpenOptionsPanel() end,
    openSkinPicker = function() NS.RunSkinVerb() end,

    isEnabled      = function() return NS.GetSetting("enabled") ~= false end,
    setEnabled     = function(on) runVerb(on and "enable" or "disable") end,
    isLocked       = function() return NS.GetSetting("locked") == true end,
    toggleLock     = function() runVerb(NS.GetSetting("locked") and "unlock" or "lock") end,
    isTestMode     = function() return NS.IsTestMode() end,
    toggleTestMode = function() runVerb("test") end,
    isWindowShown  = function() return NS.MainWindow.IsShown() end,
    toggleWindow   = function() NS.MainWindow.Toggle() end,

    version       = function() return NS.Version() end,
    print         = function(line) NS.Print(line) end,
    debug         = function(tag, message) NS.Debug(tag, "%s", message) end,
    debugAtEnable = function(tag, message) NS.DebugAtEnable(tag, "%s", message) end,
})
