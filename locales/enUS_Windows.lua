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

-- The broker feeds (modules/Broker.lua, settings/Broker.lua, SMW-05): the presets' names.
L["Pinned stat"] = true
L["Pinned element"] = true

-- The pins per broker (modules/Pins.lua, modules/Interact.lua, settings/BrokerPins.lua, SMW-06, #11).
L["Pin to the %s broker"] = true
L["%d elements are pinned to this broker. Unpin one first."] = true
L["Pinned"] = true
L["Pins"] = true
L["Move up"] = true
L["Move down"] = true
L["Unpin"] = true
L["Show this pin earlier in the feed's text and tooltip."] = true
L["Show this pin later in the feed's text and tooltip."] = true
L["Take this pin off the broker."] = true
L["Each broker shows its own pins, up to %d, in this order: {pinned} joins them, {pinned1} to {pinned5} show one each, and the tooltip lists them first. Pin a row from its menu in its window (right-click). Pins are kept per character."] = true
L["Nothing pinned."] = true
L["Each broker's pins: their order, and unpin."] = true

-- The LDB tooltip: only the fold acts (modules/BrokerTooltip.lua, modules/BrokerPanel.lua, settings/Tooltips.lua, SMW-07).
L["Click label: toggle window \194\183 Right-click label: options \194\183 Click a chevron to fold"] = true
L["Fold this section in the tooltip"] = true
L["Unfold this section in the tooltip"] = true
L["Main window draws the LDB tooltip as the main window: its block headers, rows, bars and fonts, the window's sort and filter, at the Width and Height below. Classic is the tooltip lines with mini bars. In both, a section's chevron folds it in the tooltip alone."] = true

-- The tree rows (modules/Rows.lua SetTree, SMW-08): a header's fold chevron.
L["Fold"] = true
L["Unfold"] = true

-- Reputations (modules/RepData.lua, modules/Window.lua, SMW-08, #6).
L["No reputations to show yet."] = true
L["%s %s / %s"] = true
L["Standing"] = true
L["Progress"] = true
L["At war"] = true

-- Currencies (modules/CurrencyData.lua, modules/Alerts.lua, settings/Alerts.lua, SMW-09, #7).
L["No currencies to show yet."] = true
L["Amount"] = true
L["Cap"] = true
L["This week"] = true
L["Currency at cap"] = true
L["Spend some before you earn more: what you earn past the cap is lost."] = true
L["Currency cap alert"] = true
L["A toast when a currency with a cap reaches it, once per currency per session."] = true

-- Statistics (modules/StatisticsData.lua, SMW-10): the character panel's Statistics tab.
L["No statistics to show yet."] = true
L["Value"] = true
L["Category"] = true

-- The simulator's tree steps (modules/Simulator.lua, SMW-11).
L["Reputation: %s +%d"] = true
L["Currency: %s +%d"] = true

-- A tree window's Expand / Collapse all control folds and opens its headers (modules/Window.lua, SMW-REV).
L["Expand all headers"] = true
L["Collapse all headers"] = true

-- `true` only documents the key: replace each with the key so a lookup never answers a boolean.
for k, v in pairs(L) do if v == true then rawset(L, k, k) end end
