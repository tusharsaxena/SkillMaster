# Settings panel — Ka0s Skill Master

The panel is LibKa0s-Options-1.0's, built from the schema (options-ui). Its category registers at
login; each page body builds on its first show.

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Skill Master (landing) | none | The logo, the tagline and the slash command list |
| General | Master controls, Skin, Keybindings | Master controls, the skin, the key binding |
| Layout | Window, Blocks, Block order | The window's width, maximum height, block spacing and summary strip; per block show, dock, collapse, lock and scale; the block order, dragged |
| Bars | Bar, Colors, Text, Marks | The bar heights; the composed fill, background, border and font blocks; the color mode and palette; the bar text template and position; ticks, markers, timer and spark. A live preview bar is pinned above the strip |
| Skills | General, Professions, Weapons and other | Unlearned rows, the gathering and fishing hints, one Hide row per catalog skill |
| Stats | General, then one tab per stat group | How a stat row draws, one Hide row per stat |
| Broker | Feeds | Each feed's text template and the skill-up flash |
| Alerts | Alerts | The rank-cap and weapon-gap alerts, the gap, the sound |
| Journal | Journal | Skill-ups kept per character, the Alts tab's filter on open |
| Trainers and Waypoints | Trainers and waypoints | The waypoint method, the chat line, the unverified mark |
| Profiles | none | AceDB profiles: switch, copy, reset, delete |

Every page but General and Profiles is declared through `NS.RegisterSchemaPage(key, title, spec)`
(`settings/OptionsSetup.lua`): a canvas subcategory drawn by `H.RenderTabbedSchema`, its Defaults
button restoring the page. Every display row's `onChange` is `NS.ApplyLook`, which sends one
`LAYOUT_CHANGED` per write (one per bulk reset, on the next frame), so the window, the detached
blocks, the Journal and the Bars preview restyle at once. Rows over `NS.Blocks`' own state
(`layout.blocks.<id>.docked`, `.collapsed`, `.order`) and the Hide rows (`skills.hidden.<key>`,
`stats.hidden.<key>`, sets) read and write through `get` / `set`.

What follows the skin: every composed block on the Bars page carries its `*FromSkin` companion,
default on (skinning-§6). The window, block headers, tooltips, toasts, the Journal and the trainer
popup take their fonts, colors, textures and borders from the skin and the Skin tab's font,
texture and outline overrides; they have no per-element rows.

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

The library's Keybindings tab over `NS.BINDINGS`: Toggle skills window and Toggle journal. Keys stay the
client's and are never stored in a profile (options-ui-§20).

The launcher's right-click menu lists Enabled, Locked, Test mode and Show window; Show window shares
its handler with `/skm toggle` and the key binding.

## Layout

The Block order tab is a host tab keyed by its group (the rows `layout.blocks.<id>.order` are
`skipRender`): one row per block in `NS.Blocks.Ordered()`, dragged through LibKa0s-Widgets-1.0's
`ReorderList` (options-ui-§18); a drop calls `NS.Blocks:Move(from, to)`. The controller is
canceled before every render (`spec.beforeRender`).

## Bars

The preview is `NS.OptionsPreview`: an `NS.Bar` in the page's `H.PageHeader` frame drawing the
mockup's Fishing 107 +25 / 150 with a lure's 4:12 (drawn still, no OnUpdate), restyled on every
`LAYOUT_CHANGED`.

## Profiles

AceDBOptions drawn by AceConfigDialog into the page ([profiles.md](profiles.md)).
