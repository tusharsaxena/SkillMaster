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

-- `true` only documents the key: replace each with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
