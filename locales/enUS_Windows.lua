local _, NS = ...
-- locales/enUS_Windows.lua — the six windows' strings (docs/superpowers/plans/2026-11-26-skillmaster-windows.md),
-- a topic file of NS.L beside locales/enUS.lua, which is near the file cap. Loaded straight after it.

local L = NS.L

-- The families (defaults/Families.lua, SMW-02): the window titles and the broker feeds' labels.
L["Skill Master \194\183 Professions"] = true
L["Skill Master \194\183 Skills"] = true
L["Skill Master \194\183 Character Stats"] = true
L["Skill Master \194\183 Currencies"] = true
L["Skill Master \194\183 Reputations"] = true
L["Skill Master \194\183 Statistics"] = true
L["Skill Master Skills"] = true
L["Skill Master Character Stats"] = true
L["Skill Master Currencies"] = true
L["Skill Master Reputations"] = true
L["Skill Master Statistics"] = true

-- The family windows (modules/Window.lua, modules/MainWindow.lua, SMW-04): the empty line, the key
-- bindings, the slash verbs, the launcher entries and the Layout > Windows rows.
L["Nothing to show yet."] = true
L["Toggle Professions window"] = true
L["Toggle Skills window"] = true
L["Toggle Character Stats window"] = true
L["Toggle Currencies window"] = true
L["Toggle Reputations window"] = true
L["Toggle Statistics window"] = true
L["Shows or hides the Professions window: primary professions and secondary skills."] = true
L["Shows or hides the Skills window: weapon skills and other skills."] = true
L["Shows or hides the Character Stats window: the character panel's stats."] = true
L["Shows or hides the Currencies window."] = true
L["Shows or hides the Reputations window."] = true
L["Shows or hides the Statistics window: the character panel's Statistics tab."] = true
L["Show the Professions window"] = true
L["Hide every Skill Master window"] = true
L["Show or hide the Professions window"] = true
L["Show or hide the Skills window: weapon skills and other skills"] = true
L["Show or hide the Character Stats window"] = true
L["Show or hide the Currencies window"] = true
L["Show or hide the Reputations window"] = true
L["Show or hide the Statistics window: the character panel's Statistics tab"] = true
L["Character Stats"] = true
L["Currencies"] = true
L["Reputations"] = true
L["Statistics"] = true
L["Width of this window. Multiplied by Master scale on General > Master controls."] = true
L["Height of this window; the rows scroll inside it."] = true
L["This window's layer."] = true

-- `true` only documents the key: replace each with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
