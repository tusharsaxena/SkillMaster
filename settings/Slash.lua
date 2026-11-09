local _, NS = ...
-- settings/Slash.lua — the ordered NS.COMMANDS table and the LibKa0s-Slash-1.0 dispatcher
-- (slash-commands-§1). NS.Slash IS the dispatcher instance.
local L = NS.L

local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
local cli   -- built below, once NS.COMMANDS exists; the handlers reach it at CALL time

local function echo(path) cli:CliGet(path) end

local function setAndEcho(path, value)
    local ok, err = NS.SetByPath(path, value)
    if ok == false then NS.Print(tostring(err)) return end
    echo(path)
end

local function runPerf(rest)
    for _, line in ipairs(NS.Perf.OnCommand(rest or "")) do NS.Print(line) end
end

local function runResetAll()
    if StaticPopup_Show and StaticPopupDialogs.SKILLMASTER_RESET_ALL then
        StaticPopup_Show("SKILLMASTER_RESET_ALL")
    else
        NS.Helpers.RestoreAllDefaults()
        NS.Print(L["All settings reset to defaults."])
    end
end

-- Positional triples {name, desc, fn}. `skin` sits directly after `config` (skinning-§3).
NS.COMMANDS = {
    {"help",        L["List available commands"],                 function() cli:PrintHelp() end},
    {"config",      L["Open the settings panel"],                 function() NS.OpenOptionsPanel() end},
    {"skin",        L["Choose a skin: open the skin picker"],     function() NS.RunSkinVerb() end},
    {"show",        L["Show the Skill Master window"],            function() NS.MainWindow.Show() end},
    {"hide",        L["Hide the Skill Master window"],            function() NS.MainWindow.Hide() end},
    {"toggle",      L["Show or hide the Skill Master window"],    function() NS.MainWindow.Toggle() end},
    {"lock",        L["Lock the window in place"],                function() setAndEcho("locked", true) end},
    {"unlock",      L["Unlock the window so it can be dragged"],  function() setAndEcho("locked", false) end},
    {"test",        L["Turn test mode on or off"],                function() NS.ToggleTestMode() end},
    {"enable",      L["Turn the addon on"],                       function() setAndEcho("enabled", true) end},
    {"disable",     L["Turn the addon off \226\128\148 `/skm enable` turns it back on"],
                                                                  function() setAndEcho("enabled", false) end},
    {"list",        L["List every setting and its current value"], function() cli:CliList() end},
    {"get",         L["Print a setting's current value \226\128\148 `/skm get <path>`"],
                                                                  function(rest) cli:CliGet(rest) end},
    {"set",         L["Set a setting \226\128\148 `/skm set <path> <value>` (try /skm list)"],
                                                                  function(rest) cli:CliSet(rest) end},
    {"reset",       L["Reset one setting to its default \226\128\148 `/skm reset <path>`"],
                                                                  function(rest) cli:CliReset(rest) end},
    {"resetall",    L["Reset this profile to defaults"],          function() runResetAll() end},
    {"debug",       L["Toggle the debug console \226\128\148 `on`/`off` enable/disable logging"],
        function(rest)
            -- DebugVerb tests `diagnostics` FIRST, then on/off; any other word toggles the window.
            if not NS.DebugLog:DebugVerb(rest) then NS.DebugLog:Toggle() end
        end},
    {"diagnostics", L["Write the diagnostics report to the debug console"],
                                                                  function() NS.DebugLog:RunDiagnostics() end},
    {"perf",        L["Measure performance \226\128\148 try `/skm perf` for the workflow"],
                                                                  function(rest) runPerf(rest) end},
    {"version",     L["Print the addon version"],                 function() cli:CliVersion() end},
}

if not SlashLib then
    -- Degrade, never error: the host's own minimal routing (sanctioned, slash-commands-§1). The
    -- schema CLI verbs NAME the missing library. The one library string carried is
    -- DISABLED_LINE_FORMAT, pinned against the live major by tests/test_slash.lua.
    local DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"
    local function absent(verb)
        return function()
            NS.Print(L["%s is unavailable: the LibKa0s library did not load."]:format("/skm " .. verb))
        end
    end
    local function rows(indent)
        local out = {}
        for i, e in ipairs(NS.COMMANDS) do out[i] = indent .. "/skm " .. e[1] .. "  " .. e[2] end
        return out
    end
    cli = {
        __disabledLineFormat = DISABLED_LINE_FORMAT,
        OnSlash = function(self, msg)
            local name, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
            name = (name or ""):lower()
            if name == "" then return NS.OpenOptionsPanel() end
            for _, e in ipairs(NS.COMMANDS) do
                if e[1] == name then return e[3](rest or "") end
            end
            NS.Print("unknown command '" .. name .. "'")
            self:PrintHelp()
        end,
        PrintHelp = function()
            NS.Print("v" .. NS.Version() .. " slash commands")
            for _, line in ipairs(rows("  ")) do NS.Print(line) end
        end,
        HelpHeader      = function() return "v" .. NS.Version() .. " slash commands" end,
        HelpRows        = function() return rows("  ") end,
        LandingRows     = function() return rows("") end,
        DisabledLine    = function() return DISABLED_LINE_FORMAT:format(NS.Constants.BRAND, "/skm enable") end,
        CliList         = absent("list"),
        CliGet          = absent("get"),
        CliSet          = absent("set"),
        CliReset        = absent("reset"),
        CliResetAll     = absent("resetall"),
        CliProfile      = absent("profile"),
        ProfileSwitch   = function() absent("profile")() return false end,
        CliVersion      = function() NS.Print("v" .. NS.Version()) end,
        BuildListLines  = function() return {} end,
        SetRowAnnotator = function() end,
        Text            = function(_, key) return key end,
    }
else
    cli = SlashLib:New({
        slash        = "/skm",
        slashAliases = { "/skillmaster" },
        commands     = NS.COMMANDS,                       -- passed IN, never owned by the library
        aliases      = { options = "config" },
        -- The disabled gate (slash-commands-§7): every verb but the live ones refuses on one line.
        isEnabled    = function() return not NS.Lifecycle:IsHeld(NS.HOLD_DISABLED) end,
        brandName    = NS.Constants.BRAND,
        print        = function(line) NS.Print(line) end,
        version      = NS.Version,
        get          = function(path) return NS.GetSetting(path) end,
        set          = function(path, v) return NS.SetByPath(path, v) end,
        findRow      = function(path) return NS.FindSchemaRow(path) end,
        applyDefault = function(row) return NS.ApplyDefault(row) end,
        allRows      = function() return NS.Schema end,
        groupKey     = function(row) return row.page end,
        bulkBegin    = NS.SchemaRuntime.BulkBegin,
        bulkEnd      = NS.SchemaRuntime.BulkEnd,
        -- The dispatcher's own refusals land in the console as [Cmd] lines (debug-logging-§4).
        debug        = function(tag, message) NS.Debug(tag, "%s", message) end,
    })
end

NS.Slash = cli

--- The two chat commands, both onto one dispatcher. Called from OnInitialize.
function NS.RegisterSlash()
    local function dispatch(msg) cli:OnSlash(msg) end
    NS.addon:RegisterChatCommand("skm", dispatch)
    NS.addon:RegisterChatCommand("skillmaster", dispatch)
end
