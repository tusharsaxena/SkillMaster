# Settings panel — Ka0s Skill Master

The panel is LibKa0s-Options-1.0's, built from the schema (options-ui). Its category registers at
login; each page body builds on its first show.

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Skill Master (landing) | none | The logo, the tagline and the slash command list |
| General | Master controls, Skin, Keybindings | Master controls, the skin, the key binding |
| Layout | Window, Blocks, Block order | The window's width, maximum height, block spacing, summary strip, column count (one or two) and frame strata, and the detached blocks' strata; per block show, dock, collapse, lock and scale; the weapon block's compact filter (equipped and below cap only); the block order, dragged |
| Bars | Bar, Colors, Text, Marks | The bar heights and fill direction; the composed fill, background, border and font blocks; the color mode and palette; the bar text (a presets dropdown plus Custom...) and position; ticks, markers, timer and spark. A live preview bar is pinned above the strip |
| Skills | General, Professions, Weapons and other | Unlearned rows, the gathering and fishing tooltip lines (`skills.helperTooltip`), the hint under the row (`skills.helperHint`, off by default), one Hide row per catalog skill |
| Stats | General, then one tab per stat group | How a stat row draws, one Hide row per stat |
| Broker | Feeds | Each feed's text template (a presets dropdown plus Custom...) and the skill-up flash |
| Alerts | Alerts | The rank-cap and weapon-gap alerts, the gap, the sound |
| Journal | Journal | Skill-ups kept per character, the Alts tab's filter on open |
| Trainers and Waypoints | Trainers and waypoints | The waypoint method, the chat line, the unverified mark |
| Profiles | none | AceDB profiles: switch, copy, reset, delete |

Every page but General and Profiles is declared through `NS.RegisterSchemaPage(key, title, spec)`
(`settings/OptionsSetup.lua`): a canvas subcategory drawn by `H.RenderTabbedSchema`, its Defaults
button restoring the page. Every display row's `onChange` is `NS.ApplyLook`, which sends one
`LAYOUT_CHANGED` per write (one per bulk reset, on the next frame), so the window, the detached
blocks, the Journal and the Bars preview restyle at once. The block rows `layout.blocks.<id>.docked`
and `.collapsed` store through their `set` (`NS.Blocks.StoreDocked` / `StoreCollapsed`, which wait
out combat), and every other actor (the header, the detached frame's buttons, the drag list) writes
them through `NS.SetByPath`; the Hide rows (`skills.hidden.<key>`, `stats.hidden.<key>`, sets) read
and write through `get` / `set`, and an undrawn whole-set row per kind (`skills.hidden`,
`stats.hidden`, type `set`) lets the page's Defaults clear a key with no row of its own.

The text templates (`bars.textTemplate`, `broker.templates.<feed>`) are two rows each, built by
`NS.TemplateRows` (`settings/OptionsSetup.lua`): a session-only presets dropdown
(`bars.textPreset`, `broker.presets.<feed>`) whose last choice is *Custom...*, and the stored
template itself as an EditBox (`dialogControl = "EditBox"`), drawn only while the dropdown reads
Custom (`shownWhen`). The dropdown reads the preset the stored string matches, else Custom; a
preset writes its template through `NS.SetByPath`; Custom writes nothing and shows the box, which
commits on Enter. The stored value is the template string, so a string matching no preset reads as
Custom with its text in the box. No string row may be drawn without `values` or a `dialogControl`
(LibKa0s's empty-dropdown line; `tests/test_template_rows.lua` holds the whole schema to it).

What follows the skin: every composed block on the Bars page carries its `*FromSkin` companion,
default on (skinning-§6), and so does the palette (`bars.colors.fromSkin`, *Use the skin's colors*):
while it is on the category and bonus colors are the skin's owner tokens `sm.cat.*` and
`sm.bonus*`, which keep the mockup's colors apart under every skin. The window, block headers, tooltips, toasts, the Journal and the trainer
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
| Sim mode | `state.sim` (session; composed from `NS.IsSimMode` / `NS.ToggleSim`) |
| Reset position | button: `NS.MainWindow.ResetPosition` |
| Reset all settings | button: the confirmation, then the profile reset |

### Skin

The library's Appearance tab over `skin.source`, `skin.skin`, `skin.ignorePanel`, `skin.ignoreFonts`,
`skin.font`, `skin.texture` and `skin.outline`, written through `NS.WriteSkinChoice`.

### Keybindings

The library's Keybindings tab over `NS.BINDINGS`: Toggle skills window and Toggle journal. Keys stay the
client's and are never stored in a profile (options-ui-§20).

The launcher's right-click menu lists Enabled, Locked, Test mode, Sim mode and Show window; Show window
shares its handler with `/sm toggle` and the key binding, and Sim mode its handler (`NS.ToggleSim`)
with the Master-controls Sim mode box and the bare `/sm sim`.

## Layout

The Window tab's last rows: *Columns* (`layout.columns`, One column / Two columns: the docked blocks
fill two columns, each Window width wide, the shorter column first), *Window strata*
(`layout.strata`) and *Detached block strata* (`layout.detachedStrata`). The two strata rows offer
Background, Low, Medium and High (`NS.Constants.LAYERS.STRATA_CHOICES`, frame-layering-§1) and
their tooltip is the library's `O.StrataTooltip`; the window's row applies through
`NS.MainWindow.ApplySettings`, the crafting overlays take the host's strata on the sync that
follows, and the trainer popup opens one strata above the higher of the two.

The Block order tab is a host tab keyed by its group (the rows `layout.blocks.<id>.order` are
`skipRender`): one row per block in `NS.Blocks.Ordered()`, dragged through LibKa0s-Widgets-1.0's
`ReorderList` (options-ui-§18); a drop calls `NS.Blocks:Move(from, to)`. The controller is
canceled before every render (`spec.beforeRender`).

The Weapon skills subsection adds *Equipped and below cap only*
(`layout.blocks.weapon.belowCapOnly`): the detached block keeps the equipped weapons and the
learned skills below their cap, redrawn on the write's `LAYOUT_CHANGED`. The Journal's size
(`journal.size`, the resize grip) and every `point` are drag state with no row.

## Broker

The feeds' right-click opens this page by its key (`NS.Broker.SETTINGS_PAGE = "broker"`, through
`NS.Helpers.OpenOptionsPanel`); with the library absent it opens the main settings panel.

## Bars

The Bar tab's Fill subsection opens with *Fill direction* (`bars.fillDirection`, Left to right /
Right to left): every bar, in the window, the detached blocks, the tooltips, the Journal and the
broker, anchors its fill, bonus, spark, ticks and markers from that edge.

The preview is `NS.OptionsPreview`: an `NS.Bar` in the page's `H.PageHeader` frame drawing the
mockup's Fishing 107 +25 / 150 with a lure's 4:12 (drawn still, no OnUpdate), restyled on every
`LAYOUT_CHANGED`.

## Profiles

AceDBOptions drawn by AceConfigDialog into the page ([profiles.md](profiles.md)).
