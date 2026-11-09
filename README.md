# Ka0s Skill Master

![WoW](https://img.shields.io/badge/WoW-Forever_1.60.1-purple)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-198%2F198_passing-green)

WoW Forever only. Weapon skills, Defense, level-based skill caps and weapon masters don't exist on Retail, so there is nothing for this addon to show there.

Skill Master turns your character's skill list into a window of bars you can style: every weapon skill, your primary and secondary professions, Defense, Lockpicking and Riding, with your character stats beside them. It is in early development. This release has the window, the settings panel, the minimap button and skins; the skill and stat bars arrive in later releases.

You set it up in the game's Settings → AddOns → Ka0s Skill Master, or with `/skm`.

## Usage

Type `/skm toggle` to open or close the Skill Master window, or bind a key to it. You can set that key in two places: the game's Options → Keybindings → Ka0s Skill Master, and the General page's Keybindings tab in this addon's settings. The window remembers where you dropped it. `/skm lock` stops it from moving, `/skm unlock` lets you drag it again, and the window's close button or Escape puts it away.

Test mode fills the window with sample data so you can try a layout before your character has the skills to show. Turn it on with `/skm test`, from the minimap button's right-click menu, or with the Test mode box under General → Master controls. A band across the top of the window says you are looking at sample data, and entering combat ends test mode on its own.

`/skm skin` opens the skin picker. While it is open the window shows in test mode, so you can watch each skin as you pick it; the eye button turns that preview on and off. Press Apply to keep the skin you picked. Closing the picker without applying puts everything back the way it was.

Once, when you have a moment, type `/skm probe` and send the text it shows to the author. It lists how this game client reports your skills and stats, which is still being mapped out for WoW Forever, and it changes nothing.

The minimap button opens the settings on a left-click and a menu on a right-click: turn the addon on or off, lock the window, switch test mode, and show or hide the window. `/skm disable` turns the whole addon off until you type `/skm enable`.

Everything else lives under Settings → AddOns → Ka0s Skill Master, and `/skm help` (or `/skillmaster help`) lists every command.

## How the window works

Skill Master reads your skills and stats from the game only when they change, never on a timer. Each skill goes into one of four groups (Primary, Secondary, Weapon and Other) and becomes a bar showing its rank, its cap and any bonus on top. Until those bars land in a later release, the window shows an empty state, or sample data in test mode.

The look comes from the skin you picked. Turning the addon off stops all of it: nothing runs and nothing is shown until you turn it back on.

## FAQ

| Question | Answer |
|---|---|
| Does it work on Retail? | No. The game doesn't list it on Retail at all, because the skills it shows don't exist there. |
| Why is the window empty? | This early release only has the window itself. The skill and stat bars come in a later version. Test mode shows you the layout in the meantime. |
| Where are my settings stored? | In your own profile, so each character can share or keep its own layout. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The window doesn't move when I drag it | It is locked. Type `/skm unlock`. |
| `/skm toggle` says the addon is disabled | Type `/skm enable`. |
| The window shows sample skills | Test mode is on. Type `/skm test` to turn it off. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/skm debug on` and reproduce the bug.
- Type `/skm diagnostics`.
- If the debug window isn't open, open it with `/skm debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

The backlog lives on GitHub: please file bugs and ideas at https://github.com/tusharsaxena/SkillMaster/issues rather than in comments, so nothing gets lost.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 0.1.0 | Unreleased | - First build: the Skill Master window, test mode, skins, the settings panel, the minimap button and the key binding |

## Credits

- Open Iconic by Waybury, MIT license, https://github.com/iconic/open-iconic (the window and console marks).
