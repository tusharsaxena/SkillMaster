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
L["Report the client's skill and stat API as JSON, to send to the author"] = true

-- The probe.
L["Skill Master probe: copy this and send it to the author"] = true
L["Probe report ready: press Ctrl+C to copy it."] = true

-- Settings.
L["Profiles"] = true
L["Scales the Skill Master window."] = true
L["Opacity of the Skill Master window."] = true
L["Locks the Skill Master window in place."] = true
L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."] = true
L["All settings reset to defaults."] = true

-- ---- BEGIN T2.3 (StatData): stat labels and marker labels (defaults/Stats_Forever.lua) ----
L["Strength"] = true
L["Agility"] = true
L["Stamina"] = true
L["Intellect"] = true
L["Spirit"] = true
L["Attack Power"] = true
L["Ranged Attack Power"] = true
L["Melee Crit"] = true
L["Ranged Crit"] = true
L["Melee Hit"] = true
L["Ranged Hit"] = true
L["Spell Damage"] = true
L["Bonus Healing"] = true
L["Spell Crit"] = true
L["Spell Hit"] = true
L["Mana Regen (per 5 s)"] = true
L["Armor"] = true
L["Defense"] = true
L["Dodge"] = true
L["Parry"] = true
L["Block"] = true
L["Fire Resistance"] = true
L["Nature Resistance"] = true
L["Frost Resistance"] = true
L["Shadow Resistance"] = true
L["Arcane Resistance"] = true
L["Speed"] = true
L["Run Speed"] = true
L["Swim Speed"] = true
L["Durability"] = true
L["vs same level"] = true
L["vs raid boss"] = true
L["normal run speed"] = true
L["resist cap"] = true
L["cap"] = true
L["crit immunity vs bosses"] = true
L["repair"] = true
-- ---- END T2.3 ----

-- The metatable answers the key itself; `true` above only documents the key. Replace each `true`
-- with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
