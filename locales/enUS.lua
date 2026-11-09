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

-- ---- T2.1: the skill catalog (defaults/SkillCatalog_Forever.lua) ----------------------------
-- Skill-line names and Skills-tab headers: a translation here is what NS.SkillNameToKey matches
-- on a non-enUS client, so each value MUST be the client's own spelling of the line.
L["Alchemy"] = true
L["Blacksmithing"] = true
L["Enchanting"] = true
L["Engineering"] = true
L["Herbalism"] = true
L["Leatherworking"] = true
L["Mining"] = true
L["Skinning"] = true
L["Tailoring"] = true
L["Cooking"] = true
L["First Aid"] = true
L["Fishing"] = true
L["Axes"] = true
L["Two-Handed Axes"] = true
L["Bows"] = true
L["Crossbows"] = true
L["Daggers"] = true
L["Fist Weapons"] = true
L["Guns"] = true
L["Maces"] = true
L["Two-Handed Maces"] = true
L["Polearms"] = true
L["Staves"] = true
L["Swords"] = true
L["Two-Handed Swords"] = true
L["Thrown"] = true
L["Unarmed"] = true
L["Wands"] = true
L["Defense"] = true
L["Lockpicking"] = true
L["Riding"] = true
L["Horse Riding"] = true
L["Ram Riding"] = true
L["Wolf Riding"] = true
L["Tiger Riding"] = true
L["Raptor Riding"] = true
L["Mechanostrider Piloting"] = true
L["Undead Horsemanship"] = true
L["Kodo Riding"] = true
L["Class Skills"] = true
L["Armor Proficiencies"] = true
L["Languages"] = true
-- ---- end T2.1 --------------------------------------------------------------------------------
-- BEGIN T2.4 (Trainers, Ranks, Gathering, Fishing) -- merged by the integrator.
-- Profession and riding rank names (defaults/Ranks_Forever.lua).
L["Apprentice"] = true
L["Journeyman"] = true
L["Expert"] = true
L["Artisan"] = true
-- Zone names the fishing table matches GetZoneText against (defaults/Fishing_Forever.lua).
L["Elwynn Forest"] = true
L["Dun Morogh"] = true
L["Teldrassil"] = true
L["Durotar"] = true
L["Mulgore"] = true
L["Tirisfal Glades"] = true
L["Stormwind City"] = true
L["Ironforge"] = true
L["Darnassus"] = true
L["Orgrimmar"] = true
L["Thunder Bluff"] = true
L["Undercity"] = true
L["Westfall"] = true
L["Loch Modan"] = true
L["Darkshore"] = true
L["The Barrens"] = true
L["Silverpine Forest"] = true
L["Redridge Mountains"] = true
L["Duskwood"] = true
L["Wetlands"] = true
L["Ashenvale"] = true
L["Stonetalon Mountains"] = true
L["Hillsbrad Foothills"] = true
L["Stranglethorn Vale"] = true
L["Arathi Highlands"] = true
L["Alterac Mountains"] = true
L["Desolace"] = true
L["Dustwallow Marsh"] = true
L["Swamp of Sorrows"] = true
L["Thousand Needles"] = true
L["Feralas"] = true
L["Tanaris"] = true
L["Azshara"] = true
L["The Hinterlands"] = true
L["Western Plaguelands"] = true
L["Felwood"] = true
L["Un'Goro Crater"] = true
L["Moonglade"] = true
L["Eastern Plaguelands"] = true
L["Winterspring"] = true
L["Silithus"] = true
L["Deadwind Pass"] = true
L["Burning Steppes"] = true
-- Mining nodes (defaults/Gathering_Forever.lua).
L["Copper Vein"] = true
L["Tin Vein"] = true
L["Incendicite Mineral Vein"] = true
L["Silver Vein"] = true
L["Lesser Bloodstone Deposit"] = true
L["Iron Deposit"] = true
L["Indurium Mineral Vein"] = true
L["Gold Vein"] = true
L["Mithril Deposit"] = true
L["Truesilver Deposit"] = true
L["Dark Iron Deposit"] = true
L["Small Thorium Vein"] = true
L["Rich Thorium Vein"] = true
-- Herbs (defaults/Gathering_Forever.lua).
L["Peacebloom"] = true
L["Silverleaf"] = true
L["Earthroot"] = true
L["Mageroyal"] = true
L["Briarthorn"] = true
L["Stranglekelp"] = true
L["Bruiseweed"] = true
L["Wild Steelbloom"] = true
L["Grave Moss"] = true
L["Kingsblood"] = true
L["Liferoot"] = true
L["Fadeleaf"] = true
L["Goldthorn"] = true
L["Khadgar's Whisker"] = true
L["Wintersbite"] = true
L["Firebloom"] = true
L["Purple Lotus"] = true
L["Arthas' Tears"] = true
L["Sungrass"] = true
L["Blindweed"] = true
L["Ghost Mushroom"] = true
L["Gromsblood"] = true
L["Golden Sansam"] = true
L["Dreamfoil"] = true
L["Mountain Silversage"] = true
L["Plaguebloom"] = true
L["Icecap"] = true
L["Black Lotus"] = true
-- END T2.4
-- ── T2.2 Bonuses (modules/Bonuses.lua) ─────────────────────────────────────────────────────────
-- Tooltip patterns: a translator replaces the value with the client's own wording, keeping the
-- capture order (amount first in the first and third, name first in the second).
L["%+(%d+) (.+)"] = true
L["Increased (.+) %+(%d+)"] = true
L["%+(%d+) (.-) Skill"] = true
-- Source labels.
L["%s racial"] = true
L["Weapon enchant"] = true
L["Item"] = true
L["Buff"] = true
L["Other"] = true
-- ── end T2.2 ───────────────────────────────────────────────────────────────────────────────────
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
-- L["Defense"] is declared once, in the T2.1 block above (the skill line and the stat share it).
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
-- BEGIN T4.2 (Alerts) -- merged by the integrator.
L["%s cap"] = true
L["Train %s (Lv %d): %s"] = true
L["is %d below your cap. Glancing blows and misses are more likely."] = true
L["Click to set waypoint · right-click to dismiss"] = true
L["no trainer known"] = true
L["%s: %s"] = true
-- ---- END T4.2 ----

-- The metatable answers the key itself; `true` above only documents the key. Replace each `true`
-- with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
