local _, NS = ...
-- locales/enUS.lua — NS.L and its metatable fallback: the key IS the English string (localization).
--
-- LOAD-BEARING: creates NS.L, which core/DebugLogSetup.lua and every settings file read at load.

NS.L = setmetatable({}, { __index = function(_, k) return k end })
local L = NS.L

-- Shared lines.
L["%s is unavailable: the LibKa0s library did not load."] = true
L["Not available during a performance capture."] = true
L["Diagnostic report written to the debug console: %d lines. Use Copy to share it."] = true
L["Slash Commands"] = true

-- The main window.
L["Skill Master"] = true
L["No skills to show yet."] = true
L["Test mode: the skills shown are sample data."] = true
L["Test mode"] = true
L["Test mode cannot start in combat."] = true
L["Toggle the Skill Master window"] = true
L["Shows or hides the Skill Master window."] = true

-- Slash help rows.
L["List available commands"] = true
L["Open the settings panel"] = true
L["Choose a skin: open the skin picker"] = true
L["Show the Skill Master window"] = true
L["Hide the Skill Master window"] = true
L["Show or hide the Skill Master window"] = true
L["Lock the window in place"] = true
L["Unlock the window so it can be dragged"] = true
L["Turn test mode on or off"] = true
L["Turn the addon on"] = true
L["Turn the addon off \226\128\148 `/skm enable` turns it back on"] = true
L["List every setting and its current value"] = true
L["Print a setting's current value \226\128\148 `/skm get <path>`"] = true
L["Set a setting \226\128\148 `/skm set <path> <value>` (try /skm list)"] = true
L["Reset one setting to its default \226\128\148 `/skm reset <path>`"] = true
L["Reset this profile to defaults"] = true
L["Toggle the debug console \226\128\148 `on`/`off` enable/disable logging"] = true
L["Write the diagnostics report to the debug console"] = true
L["Measure performance \226\128\148 try `/skm perf` for the workflow"] = true
L["Print the addon version"] = true

-- Settings.
L["Profiles"] = true
L["Scales the Skill Master window."] = true
L["Opacity of the Skill Master window."] = true
L["Locks the Skill Master window in place."] = true
L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."] = true
L["All settings reset to defaults."] = true

-- The metatable answers the key itself; `true` above only documents the key. Replace each `true`
-- with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
