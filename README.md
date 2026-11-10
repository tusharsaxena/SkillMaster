# Ka0s Skill Master

![WoW](https://img.shields.io/badge/WoW-Forever_1.60.1-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-400%2F400_passing-green)

WoW Forever only. Weapon skills, Defense, level-based skill caps and weapon masters don't exist on Retail, so there is nothing for this addon to show there.

Skill Master puts every skill your character has into one window of bars you can style: each weapon skill, your primary and secondary professions, Defense, Lockpicking and Riding, with your character stats beside them. A bar shows your rank against its cap, and anything raising it (a racial, an item, a fishing lure, a buff) as its own colored segment with a timer when it runs out. Unlearned skills tell you where to train them.

- Skills in four groups (Primary, Secondary, Weapon, Other) and stats in four more, each a block you can collapse, reorder, or pop out into its own frame.
- Hover tooltips with the bonus breakdown, the next rank and its trainer, how far a weapon is behind its cap, and gathering and fishing hints.
- Click a profession to open it, an unlearned skill for its trainers and a waypoint (TomTom, a map pin, or directions in chat).
- Four broker feeds for Titan Panel and the like, alerts when a profession caps or a weapon falls behind, a Journal with this session's skill-ups and an overview of your alts.
- Every part of the look is a setting: bar sizes, fill direction, colors, border, font, text, one or two columns, frame layering, and skins.

You set it up in the game's Settings → AddOns → Ka0s Skill Master, or with `/sm`.

## Usage

Type `/sm toggle` to open or close the window, or bind a key to it. The game's Options → Keybindings → Ka0s Skill Master has two keys, *Toggle skills window* and *Toggle journal*, and the General page's Keybindings tab in this addon's settings sets the same two. The window remembers where you dropped it. `/sm lock` stops it from moving and `/sm unlock` lets you drag it again; the close button or Escape puts it away.

Each block has a header. Click it to collapse the block, or use the mark on its right to pull the block out into a frame of its own that you can place anywhere; the same mark on the frame docks it again. Hover a row for the details. Click a profession to open its window (out of combat), click a weapon or Defense for the Skills tab, and click an unlearned skill to see its trainers and set a waypoint. Shift-click puts the skill into chat. Right-click gives you the row menu, where you can pin a skill to the broker feed or hide the row.

Test mode fills everything with a sample character, a level 22 Dwarf Hunter, so you can try a layout before your own character has the skills to show it. Turn it on with `/sm test`, from the minimap button's right-click menu, or with the Test mode box under General → Master controls; a band across the window says you are looking at sample data, and combat ends it. Sim mode plays a short fishing trip on the same character: a skill-up every few seconds, a lure going on and off, a mount changing your speed. Start it with `/sm sim` or the Sim mode box, and stopping it puts your own character back. Neither saves anything.

`/sm skin` opens the skin picker. While it is open the window shows in test mode so you can see each skin as you pick it, and the eye button turns that preview off and on. Press Apply to keep the skin. Closing the picker without applying puts everything back the way it was.

`/sm journal` (or the journal mark in the window's title bar) opens the Journal: this session's skill-ups with an estimate of when the next one lands, and your other characters' skills side by side. The minimap button opens the settings on a left-click and a menu on a right-click. `/sm disable` turns the whole addon off until you type `/sm enable`. Once, when you have a moment, type `/sm probe` and send the text it shows to the author; it describes how WoW Forever reports your skills and changes nothing.

Everything else lives under Settings → AddOns → Ka0s Skill Master, and `/sm help` (or `/skillmaster help`) lists every command.

## How the bars work

- Skill Master reads your skills and stats from the game when they change, never on a timer. The only thing that ticks is a bonus timer you can see.
- Each skill lands in its group and gets its cap: a profession's rank cap, or five times your level for a weapon skill.
- The bonus on top is split into where it comes from: your race, an item, a weapon enchant such as a lure, or a buff. Anything it can't place shows as Other rather than a guess.
- Stats are drawn against a sensible scale for your level, with marks at the caps that matter (hit, resistances, crit immunity).
- The colors come from your skin unless you turn that off and pick your own. Each group keeps its own color either way.

## FAQ

| Question | Answer |
|---|---|
| Does it work on Retail? | No. The game doesn't list it on Retail at all, because the skills it shows don't exist there. |
| Why does a trainer say "unverified"? | Trainer spots and some thresholds come from the classic data and haven't all been checked on WoW Forever yet. You can hide the mark on the Trainers and Waypoints page. |
| Can I see my alts' skills? | Yes. Log each character in once and the Journal's Alts tab shows them all. |
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
| 1.0.0 | Unreleased | - Every weapon skill, profession, Defense, Lockpicking and Riding as bars, with your stats beside them<br>- Bonus segments with timers, and tooltips that break each bonus down<br>- Trainer directions and waypoints for unlearned skills and the next rank<br>- Blocks you can collapse, reorder, detach, and lay out in one or two columns<br>- Four broker feeds, cap and weapon alerts, the Journal and an alt overview<br>- Settings for every part of the look, skins, test mode and a sim mode<br>- Two key bindings and the minimap button |

## Credits

- Open Iconic by Waybury, MIT license, https://github.com/iconic/open-iconic (the window and console marks).
