# Settings panel — Ka0s Skill Master

The panel is LibKa0s-Options-1.0's, built from the schema (options-ui). Its category registers at
login; each page body builds on its first show.

| Page | Covers |
|---|---|
| Ka0s Skill Master (landing) | The logo, the tagline and the slash command list |
| General | Master controls, the skin, the key binding |
| Profiles | AceDB profiles: switch, copy, reset, delete |

## Landing

Drawn by the library from `NS.LANDING` (`settings/General.lua`): logo `media/logos/skillmaster.logo.tga`,
the TOC's `## Notes`, and one row per `NS.COMMANDS` entry. No tab strip (options-ui-§13).

## General

### Master controls

Composed by `H.MasterControls` with General visibility omitted (the window is opened by the player):

| Row | Schema path |
|---|---|
| Enable Skill Master | `enabled` |
| Master scale | `scale` |
| Master opacity | `alpha` |
| Lock frame | `locked` |
| Debug console | `state.debugConsole` (session) |
| Minimap button | `global.minimap.shown` (inverts onto `global.minimap.hide`) |
| Test mode | `state.testMode` (session) |
| Reset position | button: `NS.MainWindow.ResetPosition` |
| Reset all settings | button: the confirmation, then the profile reset |

### Skin

The library's Appearance tab over `skin.source`, `skin.skin`, `skin.ignorePanel`, `skin.ignoreFonts`,
`skin.font`, `skin.texture` and `skin.outline`, written through `NS.WriteSkinChoice`.

### Keybindings

The library's Keybindings tab over `NS.BINDINGS`: Toggle the Skill Master window. Keys stay the
client's and are never stored in a profile (options-ui-§20).

The launcher's right-click menu lists Enabled, Locked, Test mode and Show window; Show window shares
its handler with `/skm toggle` and the key binding.

## Profiles

AceDBOptions drawn by AceConfigDialog into the page ([profiles.md](profiles.md)).
