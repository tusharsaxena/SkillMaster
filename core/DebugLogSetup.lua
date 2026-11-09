local addonName, NS = ...
-- core/DebugLogSetup.lua — NS.DebugLog from LibKa0s-DebugLog-1.0 (debug-logging), and the bare
-- gated sink NS.Debug with its gates NS.DebugOnce / NS.DebugChanged / NS.DebugAtEnable.
--
-- LOAD-BEARING: after core/Constants.lua (FONT_MONO), core/State.lua (the flag) and
-- core/CoreSetup.lua (the printer); before any NS.Debug call.

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
    -- Degrade, never error: every member the addon calls. SetEnabled still flips OUR flag and says
    -- so; what is lost is the window, said once. No formatter, no color code.
    local missing = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."
    local said = false
    local function sayOnce()
        if said then return end
        said = true
        NS.Print(missing)
    end
    local noop = function() end
    local function diagnosticsAbsent()
        NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format("/skm diagnostics"))
        return 0
    end
    NS.DebugLog = {
        buffer          = {},
        Add             = noop,
        Debug           = noop,
        DebugOnce       = function() return false end,
        DebugChanged    = function() return false end,
        DebugForget     = noop,
        DebugAtEnable   = function() return false end,
        Clear           = noop,
        Show            = sayOnce,
        Hide            = noop,
        Toggle          = sayOnce,
        IsShown         = function() return false end,
        IsEnabled       = function() return NS.State.debug == true end,
        SetEnabled      = function(_, on)
            on = not not on
            NS.State.debug = on
            NS.Print("debug logging " .. (on and "ON" or "OFF"))
            if on then sayOnce() end
        end,
        RefreshHeader   = noop,
        ShowCopy        = sayOnce,
        UpdateScrollBar = noop,
        UpdateStatus    = noop,
        BufferSize      = function() return 0 end,
        LastLine        = function() return nil end,
        FindLine        = function() return nil end,
        MakeCloseButton = function() return nil end,
        RunDiagnostics  = function() return diagnosticsAbsent() end,
        BuildDiagnostics = function() return { lines = {}, dropped = 0, capped = false, capsHit = false } end,
        DebugVerb       = function(self, rest)
            local word = (((rest or ""):match("^%s*(%S*)")) or ""):lower()
            if word == "diagnostics" then diagnosticsAbsent() return true end
            if word == "on" or word == "off" then self:SetEnabled(word == "on") return true end
            return false
        end,
        ConsoleCheckbox = function()
            return {
                label   = "Debug console",
                tooltip = missing,
                get     = function() return false end,
                set     = sayOnce,
            }
        end,
    }
    NS.Debug         = NS.DebugLog.Debug
    NS.DebugOnce     = NS.DebugLog.DebugOnce
    NS.DebugChanged  = NS.DebugLog.DebugChanged
    NS.DebugAtEnable = NS.DebugLog.DebugAtEnable
    return
end

NS.DebugLog = lib:New({
    name      = addonName,   -- seeds the frame globals and the UISpecialFrames entries
    addonName = addonName,   -- the FOLDER the console's close / copy / clear marks are drawn from
    title     = NS.Constants.BRAND,
    font      = NS.Constants.FONT_MONO,
    slash     = "/skm",

    -- The flag stays the addon's, session-only (debug-logging-§5).
    isEnabled  = function() return NS.State.debug == true end,
    setEnabled = function(on) NS.State.debug = on and true or false end,

    -- Call-time forwarders: NS.Print is reclaimed from AceConsole in a later file.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    initSummary = function()
        local db = NS.db
        local line = ("%s v%s, schema v%s, profile '%s'"):format(NS.name, NS.Version(),
            NS.SafeToString(db and db.global and db.global.schemaVersion),
            NS.SafeToString(db and db:GetCurrentProfile()))
        if #NS.rejectedEvents > 0 then
            line = line .. ", rejected events: " .. table.concat(NS.rejectedEvents, ", ")
        end
        return line
    end,

    onVisibilityChanged = function()
        if NS.Helpers and NS.Helpers.RefreshAllPanels then NS.Helpers.RefreshAllPanels() end
    end,

    -- The diagnostics dump (debug-logging-§14): the full brand in both markers; the sections are
    -- modules/Diagnostics.lua's, read at RUN time because that file loads after this one.
    brandName   = NS.Constants.BRAND,
    diagnostics = function() return NS.Diagnostics and NS.Diagnostics.Sections() or {} end,
    L = {
        DIAG_WRITTEN = NS.L["Diagnostic report written to the debug console: %d lines. Use Copy to share it."],
    },
})

NS.Debug         = NS.DebugLog.Debug
NS.DebugOnce     = NS.DebugLog.DebugOnce
NS.DebugChanged  = NS.DebugLog.DebugChanged
NS.DebugAtEnable = NS.DebugLog.DebugAtEnable
