# Ka0s Skill Master

![WoW](https://img.shields.io/badge/WoW-Forever_1.60.1-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1063%2F1063_passing-green)

WoW Forever only. Weapon skills, Defense, level-based skill caps and weapon masters don't exist on Retail, so there is nothing for this addon to show there.

Skill Master puts every skill your character has into windows of bars you can style: each weapon skill, your primary and secondary professions, Defense, Lockpicking and Riding, and your character stats. A bar shows your rank against its cap, and anything raising it (a racial, an item, a fishing lure, a buff) as its own colored segment with a timer when it runs out. Unlearned skills tell you where to train them. It also shows what the character panel's other tabs show: your reputations, your currencies and your Statistics.

- Six windows, one for each part of the character panel: Professions (primary and secondary), Skills (weapon skills and the rest), Character Stats (the paper doll's numbers), Currencies, Reputations, and Statistics (the Statistics tab's counters, such as Times camped).
- Skills in four groups (Primary, Secondary, Weapon, Other) and stats in four more, each a block you can collapse, reorder, sort, filter (say, only the professions at their cap that need training, or only the stats that aren't zero), or pop out into its own frame.
- Reputations grouped as the Reputation tab groups them (Alliance, Steamwheedle Cartel, Other), each a standing bar such as "Honored 3,672 / 12,000"; currencies under the Currency tab's headers, a bar where a currency has a cap; the Statistics categories nested as the tab nests them (Character, then Wealth under it). Each header folds, and folding never changes the character panel itself.
- Hover tooltips with the bonus breakdown, the next rank and its trainer, how far a weapon is behind its cap, and gathering and fishing hints.
- Click a profession to open it, an unlearned skill for its trainers, nearest first with their distance in yards, and a waypoint (a map pin with Skill Master's own arrow pointing the way, a TomTom waypoint if you use TomTom, or directions in chat).
- Six broker feeds for Titan Panel and the like, one per window (Skill Master for Professions, then Skill Master Skills, Stats, Currencies, Reputations and Statistics), each with an icon that says what it shows and each showing up to five rows you pin from a row's menu; alerts when a profession caps, a weapon falls behind or (if you turn it on) a currency reaches its cap; a Journal with this session's skill-ups, reputation and currency changes, and an overview of your alts.
- Every part of the look is a setting: bar sizes, fill direction, colors, border, font, text, one or two columns, frame layering, and skins.

You set it up in the game's Settings → AddOns → Ka0s Skill Master, or with `/sm`.

## Usage

Each window has its own command: `/sm professions`, `/sm skills`, `/sm stats`, `/sm currencies`, `/sm reputations` and `/sm statistics` open or close it (`/sm toggle` opens all six, or closes them all when any is open; the minimap button's Show window is the Professions window, and `/sm hide` closes them all). The game's Options → Keybindings → Ka0s Skill Master has a key for each window and one for the Journal, and the General page's Keybindings tab in this addon's settings sets the same ones. Each window remembers where you dropped it; the first time, the new ones open next to the Professions window. Drag the grip in its bottom-right corner to resize it; the new size becomes Window width and Window height on the Layout page. `/sm lock` (or the lock button in its title bar) stops it from moving and hides the grip, and `/sm unlock` lets you drag and resize it again; the close button or Escape puts it away. The LDB tooltip keeps its own size.

Each block has a header. Click it to collapse the block, or use the mark on its right to pull the block out into a frame of its own that you can place anywhere; the same mark on the frame docks it again. In the Reputations, Currencies and Statistics windows every header (Alliance, Player vs. Player, Character, Wealth and the like) carries the same mark: it pulls that category out into a window of its own, which moves, joins other windows and docks back the same way. Hover a row for the details. Click a profession to open its window (out of combat), click a weapon or Defense for the Skills tab, and click an unlearned skill to see its trainers and set a waypoint. Shift-click puts the skill into chat. Right-click gives you the row menu, where you can pin the row to its window's broker feed (up to five per feed; Broker → Pins orders and removes them; a pinned row shows a pin mark at the end of its name, in the windows and the feed's tooltip) or hide the row. A row opens from anywhere on it; to open it from its go icon only, set Layout → Window → *Open a row from* to *Go icon only* (the detached and merged windows follow it). In a broker feed's tooltip only a section's header can be clicked: a click anywhere on it folds that section in the tooltip alone, and hovering a row still shows its details.

In the Reputations, Currencies and Statistics windows a header row folds when you click it. Every Statistics category starts folded, and Skill Master reads a category only once you open it, so the window costs nothing until you look.

The waypoint arrow can be dragged wherever you want it. Right-click it to clear the waypoint, share it in chat, show it on the map, reopen the trainers, lock it or reset its position, open its settings, or hide it. Its look, text and position are on the Trainers and Waypoints page.

Test mode fills everything with a sample character, a level 22 Dwarf Hunter, so you can try a layout before your own character has the skills to show it. Turn it on with `/sm test`, from the minimap button's right-click menu, or with the Test mode box under General → Master controls; a band across the window says you are looking at sample data, and combat ends it. Test mode also fills the Reputations, Currencies and Statistics windows. Sim mode plays a short fishing trip on the same character: a skill-up every few seconds, a lure going on and off, a mount changing your speed, then a reputation and a currency gain. Start it with `/sm sim` or the Sim mode box, and stopping it puts your own character back. Neither saves anything.

`/sm skin` opens the skin picker. While it is open the window shows in test mode so you can see each skin as you pick it, and the eye button turns that preview off and on. Press Apply to keep the skin. Closing the picker without applying puts everything back the way it was.

`/sm journal` (or the journal mark in the window's title bar) opens the Journal: every skill-up, reputation change and currency gain or spend with an estimate of when the next skill-up lands, and your other characters' skills side by side. Click any column header of the Log (Date, Time, Name, Change, Zone) to filter it: a day, a part of the day, skill-ups, reputations or currencies (or one of them), gains or losses, a zone. Filters combine, the summary beside the Log counts what they leave, and Clear filters drops them all. The minimap button opens the settings on a left-click and a menu on a right-click, whose *Journal* entry opens or closes the Journal. `/sm disable` turns the whole addon off until you type `/sm enable`. Once, when you have a moment, type `/sm probe`, press Copy on the debug console it writes to, and send the text to the author; it describes how WoW Forever reports your skills, reputations, currencies and Statistics, and changes nothing.

Everything else lives under Settings → AddOns → Ka0s Skill Master, and `/sm help` (or `/skillmaster help`) lists every command.

## How the bars work

- Skill Master reads your skills and stats from the game when they change, never on a timer. The only thing that ticks is a bonus timer you can see. Statistics are read only while their window or feed tooltip is open, or while one is pinned, and at most once a second.
- Each skill lands in its group and gets its cap: a profession's rank cap, or five times your level for a weapon skill.
- The bonus on top is split into where it comes from: your race, an item, a weapon enchant such as a lure, or a buff. Anything it can't place shows as Other rather than a guess.
- Stats are drawn against a sensible scale for your level, with marks at the caps that matter (hit, resistances, crit immunity).
- The colors come from your skin unless you turn that off and pick your own. Each group keeps its own color either way.

## FAQ

| Question | Answer |
|---|---|
| Does it work on Retail? | No. The game doesn't list it on Retail at all, because the skills it shows don't exist there. |
| Why does a trainer say "unverified"? | Almost every trainer's name, role and spot has been checked offline against WoW Forever data. The mark stays on the few that couldn't be (one stands inside a dungeon). You can hide it on the Trainers and Waypoints page. |
| Why does a cooking, first aid or fishing teacher say "Sells" or "Quest"? | Those ranks aren't trained. You buy a book from that vendor or do that NPC's quest, and the card says which. Artisan in those three is always a quest, and the popup says so. |
| Where do I train Artisan in a craft? | From a master trainer outside the capitals, such as Drakk Stonehand in the Hinterlands for Alliance leatherworkers. The capitals' trainers stop at Expert. |
| Can I see every trainer, not just my next rank's? | Tick Show all trainers in the trainer window. It lists every rank, Artisan first, and marks the trainers for your next rank. |
| Can I see my alts' skills? | Yes. Log each character in once and the Journal's Alts tab shows them all, with their reputations and currencies. |
| What is the difference between Character Stats and Statistics? | Character Stats are the paper doll's numbers (Strength, crit, armor). Statistics are the character panel's Statistics tab: counters such as Times camped or Auctions posted. |
| Does Skill Master show my gold? | No. The Currencies window shows only the currencies the game lists. |
| Where are my settings stored? | In your own profile, so characters can share a layout or keep their own. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The window doesn't move when I drag it | It is locked. Type `/sm unlock`. |
| Clicking a profession does nothing | You are in combat. Professions open from the window once combat ends. |
| `/sm toggle` says the addon is disabled | Type `/sm enable`. |
| The window shows a Dwarf Hunter's skills | Test mode is on. Type `/sm test` to turn it off. |
| The window sits behind my bags or another window | Raise it under Layout → Window strata. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/sm debug on` and reproduce the bug.
- Type `/sm diagnostics`.
- If the debug window isn't open, open it with `/sm debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

The backlog lives on GitHub: please file bugs and ideas at https://github.com/tusharsaxena/SkillMaster/issues rather than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 1.0.0 | Unreleased | - Every weapon skill, profession, Defense, Lockpicking and Riding as bars, with your stats beside them<br>- Bonus segments with timers, and tooltips that break each bonus down<br>- Trainer directions and waypoints for unlearned skills and the next rank<br>- Blocks you can collapse, reorder, detach, and lay out in one or two columns<br>- Six windows: Professions, Skills, Character Stats, Currencies, Reputations and Statistics<br>- Six broker feeds with up to five pins each, cap and weapon alerts, the Journal and an alt overview<br>- Settings for every part of the look, skins, test mode and a sim mode<br>- A key binding per window and the Journal, and the minimap button |

## Credits

- Open Iconic by Waybury, MIT license, https://github.com/iconic/open-iconic (the window and console marks).
- Phosphor Icons, MIT license, https://github.com/phosphor-icons/core (the action mark on every skill row, the Progress sort mark, every block's filter mark and the pin mark on a pinned row).
- The waypoint arrow's five looks are original art made for the Ka0s addons, under the MIT license.
