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
L["%s - %s"] = true
L["No skills to show yet."] = true
L["Test mode: the skills shown are sample data."] = true
L["Test mode"] = true
L["Test mode cannot start in combat."] = true
L["Shows or hides the Skill Master window."] = true

-- The Journal window (modules/Journal.lua).
L["Skill Master \194\183 Journal"] = true
L["Alts"] = true
L["Time"] = true
L["Skill"] = true
L["Change"] = true
L["Zone"] = true
L["No skill-ups logged yet."] = true
L["Skill-ups this session (%s)"] = true
L["Average: %.1f an hour"] = true
L["ETA to cap"] = true
L["Two skill-ups of a skill give it an ETA."] = true
L["New session"] = true
L["Clear log"] = true
L["Clear this character's skill-up log? Every entry is removed."] = true
L["%m/%d %H:%M"] = true
L["%d h %d m"] = true
L["%d m"] = true
L["~%d m"] = true
L["~%d h"] = true
L["Professions"] = true
L["Weapons"] = true
L["No characters recorded yet."] = true
L["Lv %d %s %s"] = true
L["%s \194\183 this character"] = true
L["Snapshots update on login, logout and every skill change. Right-click a character to forget it."] = true
L["Forget %s? Their snapshot is removed until they log in again."] = true
-- FB-32 (the Log tab) and FB-33 (the Alts tab).
L["Log"] = true
L["Date"] = true
L["%m/%d/%y"] = true
L["Current session"] = true
L["Last 1 day"] = true
L["Last 3 days"] = true
L["Last 7 days"] = true
L["Last 30 days"] = true
L["All time"] = true
L["No skill-ups in this range."] = true
L["Skill-ups \194\183 %s"] = true
L["Average: %.1f a day over %s"] = true
L["1 day"] = true
L["%d days"] = true
L["Unlearned"] = true
L["Base & Combat"] = true
L["Spell & Regen"] = true
L["Defense & Resists"] = true
L["Realm: %s"] = true
L["Last seen: %s"] = true
L["Right-click to forget this character."] = true
L["No character has a skill in this block yet."] = true
L["How many skill-ups the Log keeps per character; the oldest go first."] = true
L["Log shows"] = true
L["The skill-ups the Log tab lists and sums: this session, the last few days or all of them."] = true
L["The block the Alts tab shows when the Journal opens."] = true

-- Slash help rows.
L["List available commands"] = true
L["Open the settings panel"] = true
L["Choose a skin: open the skin picker"] = true
L["Show the Skill Master window"] = true
L["Hide the Skill Master window"] = true
L["Show or hide the Skill Master window"] = true
L["Show or hide the Journal: the skill-up log and your alts"] = true
L["Lock the window in place"] = true
L["Unlock the window so it can be dragged"] = true
L["Turn test mode on or off"] = true
L["Turn the addon on"] = true
L["Turn the addon off \226\128\148 `/sm enable` turns it back on"] = true
L["List every setting and its current value"] = true
L["Print a setting's current value \226\128\148 `/sm get <path>`"] = true
L["Set a setting \226\128\148 `/sm set <path> <value>` (try /sm list)"] = true
L["Reset one setting to its default \226\128\148 `/sm reset <path>`"] = true
L["Reset this profile to defaults"] = true
L["Toggle the debug console \226\128\148 `on`/`off` enable/disable logging"] = true
L["Write the diagnostics report to the debug console"] = true
L["Measure performance \226\128\148 try `/sm perf` for the workflow"] = true
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
L["%s · %s cap"] = true
L["Train %s (Lv %d): %s"] = true
L["Click to set waypoint · right-click to dismiss"] = true
L["no trainer known"] = true
L["%s: %s"] = true
-- ---- END T4.2 ----

-- The display: bars, rows, blocks, the window body and the detached frames (T3.1, T3.2).
L["Not learned"] = true
L["Lv %d"] = true
L["Go"] = true
L["Primary Professions"] = true
L["Secondary Skills"] = true
L["Weapon Skills"] = true
L["Other skills"] = true
L["Stats \194\183 Base & Combat"] = true
L["Stats \194\183 Spell & Regen"] = true
L["Stats \194\183 Defense & Resists"] = true
L["Stats \194\183 Utility"] = true
L["Detach this block into its own frame"] = true
L["Dock this block in the main window"] = true
L["%s near cap: train %s"] = true
L["Lock or unlock the window"] = true
L["Open the journal"] = true
L["temp bonus"] = true
L["permanent bonus"] = true
L["threshold"] = true
L["Lv %d \194\183 %s %s"] = true
L["\194\183 %s"] = true
L["Expand all blocks"] = true
L["Collapse all blocks"] = true

-- The interactions: the click map, the row menu, the row tooltip, the trainer popup, the waypoints (T3.3).
L["Profession windows open from Skill Master out of combat."] = true
L["The character panel opens from Skill Master out of combat."] = true
L["Pin to the broker feed"] = true
L["Set a waypoint to the trainer"] = true
L["Show trainers"] = true
L["Hide this row"] = true
L["Primary"] = true
L["Secondary"] = true
L["Weapon"] = true
L["effective %d"] = true
L["Bonuses"] = true
L["Racial / items / buffs"] = true
L["none"] = true
L["This session"] = true
L["+%d (%d / h)"] = true
L["ETA to %d"] = true
L["%s at this rate"] = true
L["(unverified)"] = true
L["Next rank"] = true
L["%s at %d \194\183 Lv %d"] = true
L["Trainer"] = true
L["Cap at your level"] = true
L["%d (5 \195\151 %d)"] = true
L["fine"] = true
L["far below"] = true
L["low"] = true
L["Below cap by"] = true
L["Skinning %d: mobs up to Lv %d"] = true
L["Next breakpoint: %d (mobs up to Lv %d)"] = true
L["Can gather"] = true
L["Next"] = true
L["%s at %d"] = true
L["Fishing in %s needs ~%d (you: %d +%d)"] = true
L["no fish escape"] = true
L["fish will escape"] = true
L["Arrow: open the profession \194\183 Shift-click: link \194\183 Right-click: menu"] = true
L["Arrow: Skills tab \194\183 Shift-click: link \194\183 Right-click: menu"] = true
L["Arrow: trainers and waypoint \194\183 Right-click: menu"] = true
L["Arrow: character panel \194\183 Shift-click: link \194\183 Right-click: menu"] = true
L["Scale: vs %s"] = true
L["Also teaches: %s"] = true
L["%d yd"] = true
L["Coordinates unverified on WoW Forever (flagged until the smoke pass)"] = true
L["Set waypoint"] = true
L["Print to chat"] = true
L["End test"] = true
L["No map coordinates for this trainer yet; Print to chat gives directions."] = true
L["Waypoint method is Chat only (Trainers and Waypoints page); Print to chat gives directions."] = true
L["No map pin on this client; Print to chat gives directions."] = true
L["Train: %s (%s)"] = true
L["Trainers for your faction (%s) who train %s to %s (%d):"] = true
L["Trainers for your faction (%s) who train %s to %s (%d) or higher:"] = true
L["%s (%d)"] = true
L["Learn: %s"] = true
L["Trainers for your faction (%s) who teach %s:"] = true
L["No trainer for your faction is recorded for this skill."] = true
L["Map pin set: %s"] = true

-- ---- T4.1: the broker feed (modules/Broker.lua) ----
L["+%d this session"] = true
L["Off"] = true
L["No stats to show yet."] = true
L["Ka0s Skill Master is disabled."] = true
L["Utility"] = true
-- ---- END T4.1 ----

-- ---- BEGIN M5 polish (the M3/M4 review leftovers) ----
-- The broker tooltip's footer (modules/Broker.lua), as the mockup writes it.
L["Click label: toggle window \194\183 Right-click label: options \194\183 Rows: click to open, right-click for the menu"] = true
-- The one-line gathering hint under a row (modules/Rows.lua, profile.skills.helperHint).
L["Gathers %s \194\183 next: %s at %d"] = true
L["Gathers %s"] = true
L["Next: %s at %d"] = true
L["No fishing data for this zone"] = true
-- ---- END M5 polish ----

-- ==== BEGIN T5.3 (locales, bindings, diagnostics) -- merged by the integrator. ====
-- The library-absent sentences (core/Namespace.lua and the setup files' degradation stubs).
L["The LibKa0s library is missing from this installation of Ka0s Skill Master (expected in libs/LibKa0s)"] = true
L["%s; running on reduced built-in fallbacks."] = true
L["%s, so the debug console window is unavailable."] = true
L["%s, so there is no minimap button and no broker plugin."] = true
L["%s, so performance measurement is unavailable."] = true
L["debug logging ON"] = true
L["debug logging OFF"] = true
L["Debug console"] = true
L["no holds"] = true
-- The skin option lists and the reload line (core/SkinSetup.lua).
L["Ka0s skins"] = true
L["All text"] = true
L["HUD text only"] = true
L["Ka0s Default"] = true
L["Reload your interface (/reload) to finish changing the skin."] = true
-- The key bindings (modules/MainWindow.lua, launcher-§6).
L["Toggle skills window"] = true
L["Toggle journal"] = true
L["Shows or hides the Journal: the skill-up log and your alts."] = true
-- ==== END T5.3 ====

-- ---- T5.1 the settings pages (settings/Layout.lua, Bars.lua, Skills.lua, Broker.lua, Alerts.lua,
-- Journal.lua, Trainers.lua) and the rows they drive ----
L["Bar"] = true
L["Colors"] = true
L["Text"] = true
L["Marks"] = true
L["Draw this in the skin's look. %s is not read while this is on."] = true
L["Size"] = true
L["Bar height (px)"] = true
L["Height of a row's bar in the main window and the detached blocks."] = true
L["Row height (px)"] = true
L["Height of one skill or stat row, its bar included, in the main window and the detached blocks."] = true
L["Height of the bar in the tooltip of a main window or detached row."] = true
L["Height of the bar's line in the tooltip of a main window or detached row. Never shorter than its bar."] = true
L["Height of the bars in the LDB (broker) tooltip's Classic style, and in the Journal's Alts tab."] = true
L["Height of one skill or stat line in the LDB (broker) tooltip, Classic style. Never shorter than its bar."] = true
L["Fill"] = true
L["The fill color while Color mode (Colors) is Flat. Not read while Use the skin's color is on."] = true
L["The color behind the fill. Not read while Use the skin's color is on."] = true
L["The border's color. Not read while Use the skin's color is on."] = true
L["The bar text's color. Not read while Use the skin's color is on."] = true
L["Use the skin's color"] = true
L["Bar color"] = true
L["Background"] = true
L["Background color"] = true
L["Border"] = true
L["Border color"] = true
L["Palette"] = true
L["Color mode"] = true
L["How a bar's fill is colored: by its category, by progress to its cap, by the chance of a skill-up, or one flat color (Bar > Fill)."] = true
L["By category"] = true
L["By progress"] = true
L["By skill-up chance"] = true
L["Flat"] = true
L["Use the skin's colors"] = true
L["Draw the category and bonus colors in the skin's own. The swatches below are not read while this is on."] = true
L["Primary professions"] = true
L["Fill of a primary profession's bar (By category)."] = true
L["Secondary skills"] = true
L["Fill of a secondary skill's bar (By category)."] = true
L["Weapon skills"] = true
L["Fill of a weapon skill's bar (By category)."] = true
L["Fill of the Other block's bars (By category)."] = true
L["Stats"] = true
L["Fill of a stat's bar (By category)."] = true
L["Temporary bonus"] = true
L["The bonus segment of a temporary bonus: a lure, a buff."] = true
L["Permanent bonus"] = true
L["The bonus segment of a permanent bonus: a racial, an item."] = true
L["Content"] = true
L["Rows show"] = true
L["What every skill and stat row draws, in the window, the detached blocks and the broker tooltips: the bar and its value, the bar alone, or the value alone in the bar's place."] = true
L["Bar text"] = true
L["What a skill's bar says, shown here for 107 +25 / 150. Custom writes your own. A stat's bar shows its value."] = true
L["Tokens: {rank}, {bonus} (+25), {max}, {pct} (percent of the cap) and {left} (points to the cap). Press Enter to apply."] = true
L["{left} to go"] = true
-- A template setting's presets dropdown and its box (settings/OptionsSetup.lua NS.TemplateRows).
L["Custom"] = true
L["Custom text"] = true
L["Text position"] = true
L["Where the text sits on the bar."] = true
L["Left"] = true
L["Center"] = true
L["Right"] = true
L["Font"] = true
L["Font color"] = true
L["Use the skin's shadow"] = true
L["Font shadow"] = true
L["Thresholds in the window"] = true
L["A stat's marks (the hit cap, the resist cap, crit immunity) on its bar in the main window, the detached and merged windows, the LDB tooltip and the journal."] = true
L["Thresholds in the row tooltip"] = true
L["A stat's marks (the hit cap, the resist cap, crit immunity) on the bar and as lines in the tooltip shown when you hover a row."] = true
L["Expiry timer"] = true
L["The time a temporary bonus has left, beside its bar."] = true
L["Spark"] = true
L["Rank tier colors"] = true
L["Icons"] = true
L["Icon"] = true
L["Show icons"] = true
L["Draw each row's in-game icon at its left end."] = true
L["Icon size (px)"] = true
L["The icon's width and height, its border included. Never taller than the row."] = true
L["Icon zoom (%)"] = true
L["How much of the art's edge is cropped away on each side. 7 trims the old icons' baked-in border."] = true
L["The icon border's color. Not read while Use the row's color or Use the skin's color is on."] = true
L["Use the row's color"] = true
L["Edge each icon in its row's own color (its category, progress or skill-up chance, as Color mode says). Use the skin's color and Border color are not read while this is on."] = true
L["Draw a profession's bar to 300 whatever its cap, its fill split by rank tier: Apprentice to 75 in its category's color, then Journeyman, Expert and Artisan each a shade darker. Works only while Color mode (Colors) is By category."] = true
L["A thin line riding the end of the fill."] = true
L["Bars"] = true
L["Restore every Bars setting on this profile to its default."] = true
L["Window"] = true
L["Blocks"] = true
L["Block order"] = true
L["Window width (px)"] = true
L["Width of the Skill Master window. Multiplied by Master scale on General > Master controls."] = true
L["Block spacing (px)"] = true
L["Space between two docked blocks."] = true
L["Show summary strip"] = true
L["Columns"] = true
L["One column"] = true
L["Two columns"] = true
L["Lay the docked blocks in one column, or in two side by side. Each column is Window width wide."] = true
L["Low"] = true
L["Medium"] = true
L["High"] = true
L["Window strata"] = true
L["The Skill Master window's layer."] = true
L["Detached block strata"] = true
L["The layer every detached block's frame draws in."] = true
L["Fill direction"] = true
L["The edge every bar fills from."] = true
L["Left to right"] = true
L["Right to left"] = true
L["The line under the title: your level, this session's skill-ups and the next rank to train."] = true
L["Show this block"] = true
L["Show this block in the window, or in its own frame while detached."] = true
L["Dock in the window"] = true
L["Off pops the block out into a frame of its own, as its header's detach button does."] = true
L["Collapse"] = true
L["Show the block's header only, as a click on it does."] = true
L["Lock this block"] = true
L["Equipped and below cap only"] = true
L["While detached, list only the weapons you have equipped and the skills still below their cap."] = true
L["Stop the detached frame from being dragged."] = true
L["Block scale"] = true
L["Scale of the block's own frame while it is detached."] = true
L["Position: %s"] = true
L["The block's place in the window, 1 at the top. Drag it on Layout > Block order."] = true
L["Drag a block by its handle to move it. The eye shows or hides it; a hidden block keeps its place."] = true
L["Hide this block"] = true
L["Show %s"] = true
L["Drag to reorder"] = true
L["Layout"] = true
L["Restore every Layout setting on this profile to its default: the window, every block and the block order."] = true
L["Hide %s"] = true
L["Hidden rows"] = true
L["General"] = true
L["Show unlearned skills"] = true
L["List the weapon skills and Riding your class can learn but has not, dimmed, with their trainer."] = true
L["Gathering and fishing hints"] = true
L["Hint under the row"] = true
L["One muted line under the Skinning, Mining, Herbalism and Fishing rows: what you can gather now and the next step."] = true
L["In a gathering skill's tooltip: the highest level you can skin, the next node you can gather and the skill a zone's fish need."] = true
L["Skills"] = true
L["Bar and value"] = true
L["Bar only"] = true
L["Value only"] = true
L["Feed"] = true
L["Feed text"] = true
L["Skill-up flash"] = true
L["What the feed shows on your broker display. Custom writes your own."] = true
L["The feed's own text. Tokens: %s. Press Enter to apply."] = true
L["Pinned skill and session gains"] = true
L["Pinned skill"] = true
L["Lowest profession and session gains"] = true
L["Last skill-up and session gains"] = true
L["Equipped weapon and Defense"] = true
L["Pinned skill and crit"] = true
L["{pinned} \194\183 {stat:crit} crit"] = true
L["Crit and speed"] = true
L["{stat:crit} crit \194\183 {stat:speed}"] = true
L["Flash duration (seconds, 0 = off)"] = true
L["How long the feed shows the skill that just went up (^ Bows 81) in place of its text."] = true
-- FB-12 / FB-13: the feed's tooltip (settings/Broker.lua)
L["Tooltip"] = true
L["Apply skin to the tooltip"] = true
L["Draw the feed's tooltip in the skin's backdrop, border and fonts. Off, it is the game's plain tooltip. Classic style only: the Main window style always wears the skin."] = true
L["Sections"] = true
L["Draw this section in the feed's tooltip."] = true
L["Broker"] = true
L["Alerts"] = true
L["Rank cap alert"] = true
L["A toast and a chat line when a profession reaches its rank's cap and a higher rank can be trained."] = true
L["Weapon skill alert"] = true
L["A toast when a weapon skill falls behind its cap (5 per level) by the gap below."] = true
L["Weapon skill gap (points)"] = true
L["How far below its cap a weapon skill must be before it alerts. Needs Weapon skill alert."] = true
L["Play a sound"] = true
L["Restore every Alerts setting on this profile to its default."] = true
L["Journal"] = true
L["Skill-ups to keep"] = true
L["Alts tab opens on"] = true
L["Restore every Journal setting on this profile to its default. The log itself is kept."] = true
L["Trainers and waypoints"] = true
L["Waypoint method"] = true
L["Where a trainer's waypoint goes: Map pin places one on the map, Chat only writes the directions. A trainer with no coordinates, or a client with no map pin, is always written to chat."] = true
L["Map pin"] = true
L["Chat only"] = true
L["Say where in chat"] = true
L["Print a chat line naming the trainer when a waypoint is set."] = true
L["Mark unverified trainers"] = true
L["Flag trainer data not yet checked on WoW Forever, in tooltips, the trainer popup and chat."] = true
-- Feedback round 2, FB-11: the trainer popup's name color (settings/Trainers.lua).
L["Trainer popup"] = true
L["Trainer name color"] = true
L["The trainer's name in the trainer popup. Not read while Use the skin's color is on."] = true
L["Draw the trainer's name in the skin's accent. Trainer name color is not read while this is on."] = true
L["Trainers and Waypoints"] = true
L["Restore every Trainers and Waypoints setting on this profile to its default."] = true
L["Restore every setting on this page to its default, on this profile."] = true
-- ---- END T5.1 ----

-- ---- T5.2: test mode and the simulator ----
L["Test mode cannot start while a simulation runs."] = true
L["Simulation"] = true
L["Simulation: a sample character plays scripted events."] = true
L["Run the simulator: scripted skill-ups, a lure and a speed change \226\128\148 `/sm sim` shows the steps"] = true
L["A simulation cannot start while test mode is on."] = true
L["A simulation cannot start in combat."] = true
L["A simulation cannot start in an instance."] = true
L["A simulation cannot start in a group."] = true
L["A fishing trip: skill-ups, a lure and a mount"] = true
L["Simulation stopped: Skill Master was disabled."] = true
L["Simulation stopped: combat started."] = true
L["Simulation stopped: the profile changed."] = true
L["Simulation started (%s): a sample character plays scripted events. Nothing is saved."] = true
L["Skill Master - Simulation"] = true
L["Skill-up: %s"] = true
L["Fishing lure on"] = true
L["Fishing lure off"] = true
L["Mount up: speed 160%"] = true
L["Dismount: speed 100%"] = true
L["Your skill in %s has increased to %d."] = true
L["Strong Fishing Pole"] = true
L["Shiny Bauble (+25 Fishing Skill)"] = true
L["Forgetting a character waits until the simulation stops."] = true
-- The sample character's words (defaults/Preview_Forever.lua), localized when its models are built.
L["Defenses"] = true
L["Shiny Bauble"] = true
L["Dwarf"] = true
L["Human"] = true
L["Gnome"] = true
L["Hunter"] = true
L["Warrior"] = true
L["Mage"] = true
L["Paladin"] = true
-- ---- END T5.2 ----

-- ---- BEGIN M5 integration (the settings stubs and the Skin tab rows routed through L) ----
L["Skin source"] = true
L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."] = true
L["Skin"] = true
L["The Ka0s skin this addon wears. Changes the window, the tool windows and the settings pages right away."] = true
L["Ignore settings panel"] = true
L["Keep this addon's settings panel in the game's own look. Its other surfaces still wear the skin."] = true
L["Ignore fonts"] = true
L["Keep every font in this addon as the game draws it. The skin still colors the text."] = true
L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."] = true
L["Texture"] = true
L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."] = true
L["Font outline"] = true
L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."] = true
L["Skin picker seen"] = true
L["Whether the first-run skin picker was closed on this profile."] = true
L["%s, so the settings panel is unavailable."] = true
L["unknown command '%s'"] = true
L["v%s slash commands"] = true
L["The simulator needs LibKa0s-Sim-1.0."] = true
-- ---- END M5 integration ----

-- Owner feedback round 3 (main thread): the broker title with nothing pinned
L["Professions and Skills"] = true
L["Hide in this tooltip"] = true
L["Default order"] = true
L["Value, highest first"] = true
L["Value, lowest first"] = true
L["Progress to max, nearest first"] = true
L["Sorted: %s. Click to sort."] = true
L["Sort rows by"] = true
L["The order of the block's rows, here, in its detached frame and in the LDB tooltip. The sort mark on its header opens a menu of every order."] = true
L["Skip untrained weapons"] = true
L["Equipped weapons only"] = true
L["Every learned weapon"] = true
L["Weapons that alert"] = true
L["Skip untrained weapons leaves out a weapon still at 5 points or fewer. Equipped weapons only reads the main hand, off hand and ranged weapons you wear now."] = true
L["Muted weapons"] = true
L["The weapons the weapon skill alert never reads, as a set of keys."] = true
L["Mute %s"] = true
L["Never alert for this weapon, whatever its gap."] = true
L["Window height (px)"] = true
L["Height of the Skill Master window; the rows scroll inside it."] = true
L["Shrink to fit the rows"] = true
L["Shrink the window when its rows take less than Window height, so it grows and shrinks as blocks expand and collapse."] = true

-- owner feedback round 4: the Tooltips page (settings/Tooltips.lua)
L["Main window tooltip"] = true
L["LDB tooltip"] = true
L["Bar width (px)"] = true
L["Font size"] = true
L["Tooltips"] = true
L["Width of the bar in the tooltip of a main window or detached row."] = true
L["Size of Skill Master's lines in the tooltip of a main window or detached row. The game's other tooltips keep theirs."] = true
L["Width of the bars in the LDB (broker) tooltip, Classic style. The tooltip widens to fit them; a wide value column can stretch them further."] = true
L["Size of the text in the LDB (broker) tooltip, Classic style. The Main window style takes the window's fonts."] = true
L["Restore every Tooltips setting on this profile to its default."] = true

-- owner feedback round 4: the section header's restore mark (modules/Blocks.lua)
L["1 hidden row. Click to show it again."] = true
L["%d hidden rows. Click to show them again."] = true

-- owner feedback round 4: the skill-up alert (modules/Alerts.lua, settings/Alerts.lua)
L["Skill ups"] = true
L["Skill-up alert"] = true
L["A short green toast on every skill point. Skill-ups a few seconds apart share one toast."] = true
L["All skills"] = true
L["Professions only"] = true
L["Weapons and Other only"] = true
L["Skill-up alerts for"] = true
L["Which skills the skill-up alert reads: every skill, the primary and secondary professions, or the weapon and Other skills. Needs Skill-up alert."] = true
L["Play a sound on skill up"] = true
L["Play the toast's sound as each skill-up toast shows."] = true
L["Play the toast's sound as each rank cap or weapon skill alert shows."] = true
L["Weapon skill gap"] = true
L["Glancing blows and misses are more likely."] = true
L["%d this session"] = true
L["%d to cap"] = true
L["%s at this pace"] = true
L["Skill up"] = true
L["Skill up \194\183 %d skills"] = true
L["Also %s"] = true

-- Layout > Detached windows (round 5, R5-7).
L["Detached windows"] = true
L["Window scale"] = true
L["Scale of every detached window. Multiplies each block's own Block scale (Blocks tab)."] = true
L["Window opacity"] = true
L["Opacity of every detached window, its rows and title band included."] = true
L["Title band"] = true
L["When a detached window shows its title band and its marks: always, only while the pointer is over the window, or never. With Never, a thin strip at the top stays the drag area; dock and collapse the block from the Blocks tab."] = true
L["Always"] = true
L["On hover"] = true
L["Never"] = true
L["The fill behind a detached window's rows. Not read while Use the skin's background is on."] = true
L["Use the skin's background"] = true
L["Fill every detached window as the skin fills its windows. Background color is not read while this is on."] = true
L["The edge of a detached window. Not read while Use the skin's border is on."] = true
L["Use the skin's border"] = true
L["Edge every detached window as the skin edges its windows. Border style, thickness and color are not read while this is on."] = true

-- Merged detached windows (round 5, R5-6: modules/Groups.lua)
L["Split from the group"] = true
L["Unmerge all"] = true
L["Dock in the main window"] = true
L["Dock all in the main window"] = true
L["Split this section from the group"] = true
L["Dock every section in the main window"] = true
L["Collapse or expand every section"] = true

-- The Weapon Skills block's filter mark (round 5, R5-10: modules/Blocks.lua)
L["All"] = true
L["Learned"] = true
L["Equipped"] = true
L["Below cap"] = true
L["Show"] = true
L["Showing: %s. Click to filter."] = true
L["No rows match this filter."] = true
L["Show rows"] = true

-- The Rows page (round 5, R5-11..R5-13: settings/Rows.lua)
L["Rows"] = true
L["Show and hide"] = true
L["Hide %s in the LDB tooltip"] = true
L["Leave this row out of the window and the detached blocks. The row menu's Hide sets it too."] = true
L["Leave this row out of the LDB tooltip: a skill out of the Skill Master feed's, a stat out of the Skill Master Stats feed's. The tooltip's row menu's Hide sets it too."] = true
L["Every skill hidden from the window, as a set of keys."] = true
L["Every stat hidden from the window, as a set of keys."] = true
L["Every skill the LDB tooltip leaves out, as a set of keys."] = true
L["Every stat the LDB tooltip leaves out, as a set of keys."] = true
L["Nothing in this group is hidden here."] = true
L["%d hidden. Click to show them again."] = true
L["Show in the window"] = true
L["Show in the LDB tooltip"] = true
L["The first eye hides a row from the window and the detached blocks, the second from the LDB tooltip; a dimmed eye is hidden there. A row hidden from both is dimmed. A heading's eyes show its group's hidden rows again."] = true
L["Show every skill and stat again, in the window and in the LDB tooltip: both hidden sets are cleared, on this profile."] = true
L["Restore every Skills setting on this profile to its default. Hidden rows stay hidden: the Rows page's Defaults shows them again."] = true
L["Restore every Broker setting on this profile to its default. Hidden tooltip rows stay hidden: the Rows page's Defaults shows them again."] = true

-- ---- Round 6, R6-10: the LDB tooltip in the main window's style (settings/Tooltips.lua,
-- modules/BrokerPanel.lua) ----
L["Tooltip style"] = true
L["Main window draws the LDB tooltip as the main window: its block headers, rows, bars and fonts, the window's collapse, sort and filter, at the Width and Height below. Classic is the tooltip lines with mini bars."] = true
L["Main window"] = true
L["Classic"] = true
L["Width (px)"] = true
L["Width of the LDB tooltip in the Main window style, counted as Layout > Window width is."] = true
L["Height (px)"] = true
L["The tallest the LDB tooltip grows in the Main window style; past it, it scrolls (the mouse wheel or its scroll bar)."] = true
L["Nothing to show in this tooltip."] = true

-- ---- Round 6, R6-9: the Skill Master Stats feed (modules/Broker.lua, settings/Broker.lua) ----
L["Skill Master Stats"] = true
L["Stats feed sections"] = true
-- Round 7, R7-5: the LDB tooltips' titles (modules/Broker.lua B.FEEDS)
L["Skill Master \194\183 Professions and Skills"] = true
L["Skill Master \194\183 Stats"] = true
L["Draw this stat block in the Skill Master Stats feed's tooltip."] = true

-- ---- Round 6, R6-11: Skill Master's waypoint arrow (modules/WaypointArrow.lua, settings/Trainers.lua) ----
L["Show Skill Master's arrow"] = true
L["A map pin comes with Skill Master's own arrow, pointing the way with the distance under it, and the game's own arrow stays off. Off: the game's arrow points to the map pin."] = true
L["Arrow scale"] = true
L["Size of Skill Master's waypoint arrow."] = true
L["Right-click to clear the waypoint. Drag to move the arrow."] = true
L["You have arrived: %s"] = true

-- ---- Round 7, R7-1: a filter on every block (modules/Blocks.lua B.FILTER_SETS, settings/Layout.lua) ----
L["At cap (needs training)"] = true
L["Non-zero"] = true
L["Which of the block's rows show, here, in its detached frame, in a merged window and in the LDB tooltip: all of them, the learned skills still below their rank's cap, or the learned skills at their cap with a higher rank to train. The filter mark on its header picks it."] = true
L["Which of the block's rows show, here, in its detached frame, in a merged window and in the LDB tooltip: all of them, the skills you have learned, the weapons you have equipped (main hand, off hand, ranged), or the learned skills still below their cap. The filter mark on its header picks it."] = true
L["Which of the block's rows show, here, in its detached frame, in a merged window and in the LDB tooltip: all of them, the skills you have learned, or the learned skills still below their cap. The filter mark on its header picks it."] = true
L["Which of the block's rows show, here, in its detached frame, in a merged window and in the LDB tooltip: all of them, or only the stats whose value is not 0. The filter mark on its header picks it."] = true

-- ---- Round 7, R7-6: open an LDB tooltip row from its go icon or the whole row (settings/Tooltips.lua) ----
L["Open a row from"] = true
L["The go icon"] = true
L["The whole row"] = true
L["Main window style: what a left click on an LDB tooltip row opens from. The go icon opens it as the main window's go icon does (a profession window, the character panel, the trainers), and the rest of the row only links (shift-click) and opens the row menu (right-click). The whole row opens it from anywhere on the row. Classic style rows always open from the whole row."] = true
L["Click label: toggle window \194\183 Right-click label: options \194\183 Rows: click the go icon to open, shift-click to link, right-click for the menu"] = true

-- The metatable answers the key itself; `true` above only documents the key. Replace each `true`
-- with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
