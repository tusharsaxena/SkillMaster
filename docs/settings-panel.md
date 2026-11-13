# Settings panel — Ka0s Skill Master

The panel is LibKa0s-Options-1.0's, built from the schema (options-ui). Its category registers at
login; each page body builds on its first show.

| Page | Tabs | Covers |
|---|---|---|
| Ka0s Skill Master (landing) | none | The logo, the tagline and the slash command list |
| General | Master controls, Skin, Keybindings | Master controls, the skin, the key binding |
| Layout | Window, Blocks, Detached windows, Block order | The window's width, maximum height, block spacing, summary strip, column count (one or two), where a row opens from (Full row or Go icon only, round 8) and frame strata; per block show, dock, collapse, lock, scale and Show rows (its header's filter, round 7); the weapon block's compact filter (equipped and below cap only); every detached window's scale, opacity, title band, strata, background and border; the block order, dragged |
| Bars | Bar, Colors, Text, Marks, Icons | The bar heights and fill direction; the composed fill, background, border and font blocks; the color mode and palette; what rows show, the bar text (a presets dropdown plus Custom) and position; Rank tier colors (each tier a darker shade of the category color, By category only), thresholds in the window (off by default) and in the row tooltip (on; round 6, R6-4), timer and spark (off by default); the rows' icons (show, size, zoom, and the composed border on the icon family with Use the row's color). No preview bar: the open window restyles live (owner feedback round 4) |
| Skills | General | Unlearned rows, the gathering and fishing tooltip lines (`skills.helperTooltip`), the hint under the row (`skills.helperHint`, off by default) |
| Rows | Show and hide | Every catalog skill and stat once, under the window's block headings in its block order: a boxed row (icon, name) with two eyes, the main window's Hide (`skills.hidden.<key>`, `stats.hidden.<key>`) and the LDB tooltip's (`broker.tooltip.hiddenSkills.<key>`, `hiddenStats.<key>`); a Window / LDB tooltip caption line on top; each heading's two eyes show that group's hidden rows again (round 5, R5-11..R5-13) |
| Broker | Feed, Tooltip | The feed's text template (a presets dropdown plus Custom) and the skill-up flash; the Skill Master feed's four section switches and the Skill Master Stats feed's four (round 6, R6-9) |
| Tooltips | Main window tooltip, LDB tooltip | Each tooltip's bar width, bar height, row height and font size; Apply skin to the tooltip (the LDB tooltip). The heights keep their `bars.*` paths and the skin row `broker.tooltip.skin`; the widths and font sizes are `tooltips.row.*` / `tooltips.ldb.*` (owner feedback round 4). The LDB tooltip's *Tooltip style* (`tooltips.ldb.style`: *Main window*, a new profile's default, or *Classic*, round 6, R6-10) with its *Width (px)* (`tooltips.ldb.width`, 420, counted as Layout > Window width; at the narrow end the title moves left of the gains text and truncates rather than draw over it) and *Height (px)* (`tooltips.ldb.height`, 560, the tallest it grows before it scrolls), both dimmed in Classic; *Open a row from* (`tooltips.ldb.openFrom`: *Full row*, the default since round 8, R8-1, or *Go icon only*; round 7, R7-6; the main window's two choices, the same overlay rules), right under Tooltip style and dimmed in Classic, whose rows always open from the whole row; *Apply skin to the tooltip*, the LDB *Bar width*, *Row height* and *Font size* are Classic's and dimmed in Main window (*Bar height* stays live: the Journal's Alts bars read it too) |
| Alerts | Alerts, Muted weapons | The rank-cap and weapon-gap alerts, the gap, the sound; the skill-up alert, which skills it reads and its own sound (round 4) |
| Journal | Journal | Skill-ups kept per character, the Log tab's range (the window's own picker writes the same row), the Alts sub-tab on open |
| Trainers and Waypoints | Trainers and waypoints | The waypoint method (Map pin or Chat only; no TomTom, round 7, R7-7), the chat line, Show Skill Master's arrow (on by default: a map pin comes with Skill Master's own arrow and the game's arrow stays off) and Arrow scale (0.5 to 2; round 6, R6-11), the unverified mark; the trainer popup's Trainer name color with Use class color and Use the skin's color (on by default: the skin's accent) |
| Profiles | none | AceDB profiles: switch, copy, reset, delete |

Every page but General and Profiles is declared through `NS.RegisterSchemaPage(key, title, spec)`
(`settings/OptionsSetup.lua`): a canvas subcategory drawn by `H.RenderTabbedSchema`, its Defaults
button restoring the page. Every display row's `onChange` is `NS.ApplyLook`, which sends one
`LAYOUT_CHANGED` per write (one per bulk reset, on the next frame), so the window, the detached
blocks and the Journal restyle at once. The block rows `layout.blocks.<id>.docked`
and `.collapsed` store through their `set` (`NS.Blocks.StoreDocked` / `StoreCollapsed`, which wait
out combat), and every other actor (the header, the detached frame's buttons, the drag list) writes
them through `NS.SetByPath`; the Hide rows (`skills.hidden.<key>`, `stats.hidden.<key>`,
`broker.tooltip.hiddenSkills.<key>`, `broker.tooltip.hiddenStats.<key>`, sets) read and write
through `get` / `set`, and an undrawn whole-set row per set (type `set`) lets the Rows page's
Defaults clear a key with no row of its own. Each page's Defaults restores its own rows only: the
Skills and Broker pages' leave the hidden rows hidden, the Rows page's shows every one again.

The text templates (`bars.textTemplate`, `broker.template`) are two rows each, built by
`NS.TemplateRows` (`settings/OptionsSetup.lua`): a session-only presets dropdown
(`bars.textPreset`, `broker.preset`) whose last choice is *Custom*, and the stored
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
fill two columns, each Window width wide, the shorter column first), *Open a row from*
(`layout.openFrom`, round 8, R8-1: *Full row*, the default, a left click anywhere on a main window,
detached or merged window row does what its go icon does, the crafting and character-panel rows'
secure overlay laid over the whole hovered row; *Go icon only*, the go icon alone, the rest of the
row linking on a shift-click and opening the row menu on a right-click; the row tooltip's click
hint says which) and *Window strata*
(`layout.strata`); *Detached block strata* (`layout.detachedStrata`) is on the Detached windows tab
(round 5, same path, nothing migrated). The two strata rows offer
Background, Low, Medium and High (`NS.Constants.LAYERS.STRATA_CHOICES`, frame-layering-§1) and
their tooltip is the library's `O.StrataTooltip`; the window's row applies through
`NS.MainWindow.ApplySettings`, the crafting overlays sit one strata above the host's on the sync that
follows, and the trainer popup opens one strata above the higher of the two.

The Detached windows tab (round 5, R5-7) styles every detached window at once, and a merged group's
window too (`NS.Detached.ApplyStyle(frame)`); every row's onChange is `NS.ApplyLook`, so the write's
`LAYOUT_CHANGED` re-renders each open one. Its subsections:

- *Window*: *Window scale* (`layout.detached.scale`, 0.5 to 2, multiplying each block's own *Block
  scale*), *Window opacity* (`layout.detached.alpha`, 0 to 1, the whole window), *Title band*
  (`layout.detached.titleBand`: Always; On hover, the band's fill, title and marks hidden until the
  pointer is over the window, polled every 0.1 s so a pointer on a row or a mark counts, the body kept
  below the band so nothing jumps and the window drags by it while shown; Never, no band, a 6 px strip
  at the top kept as the drag area, docking and collapsing from the Blocks tab) and *Detached block
  strata*.
- *Background*: the composed color pair (`bgColor`, `useClassColorBg`, options-ui-§16's background
  rule) and *Use the skin's background* (`bgFromSkin`, on by default, skinning-§6). On, the skin's
  window fill (`S.Shell`); off, the swatch on a fill of the window's own, over the skin's and under
  the band.
- *Border*: the composed border block with its *Show border* toggle (`border`, `borderStyle`,
  `borderSize`, `borderColor`, `useClassColorBorder`) and *Use the skin's border* (`borderFromSkin`,
  on by default). On, the skin's window edge; off, the style, thickness and swatch on edges of the
  window's own (`NS.Bar.PaintBorder`); Show border off draws neither.

The Block order tab is a host tab keyed by its group (the rows `layout.blocks.<id>.order` are
`skipRender`): one boxed row per block in `NS.Blocks.Ordered()` on `NS.OptionsList`
(`settings/BoxList.lua`, ConsumableMaster's Priority list look: a 28 px box, a 4 px gap, the `segment`
handle), dragged through LibKa0s-Widgets-1.0's `ReorderList` (options-ui-§18); a drop calls
`NS.Blocks:Move(from, to)`, and the row's eye writes `layout.blocks.<id>.shown`. The Rows page's one
tab is a host tab keyed by its group the same way (see [Rows](#rows)). Each controller is canceled
before every render (`spec.beforeRender`).

The Weapon skills subsection adds *Equipped and below cap only*
(`layout.blocks.weapon.belowCapOnly`): the detached block keeps the equipped weapons and the
learned skills below their cap, redrawn on the write's `LAYOUT_CHANGED`. Every block's subsection
has *Show rows* (`layout.blocks.<id>.filter`; the weapon block's, round 5, R5-10; every block's,
round 7, R7-1), the header's filter mark as a dropdown of the block's own set: Primary and Secondary
All, Below cap, At cap (needs training); Weapon Skills All, Learned, Equipped, Below cap; Other
skills All, Learned, Below cap; each stat section All, Non-zero. It narrows the main window, the
detached frame, a merged section and both LDB tooltip styles alike. The Journal's size
(`journal.size`, the resize grip) and every `point` are drag state with no row.

## Broker

The feed's right-click opens this page by its key (`NS.Broker.SETTINGS_PAGE = "broker"`, through
`NS.Helpers.OpenOptionsPanel`); with the library absent it opens the main settings panel.

- **Feed**: *Text*, the one template (`broker.template`; the presets cover skills and stats alike:
  pinned skill and gains (with nothing pinned, the feed reads Professions and Skills), pinned skill, lowest profession and gains, last skill-up and gains,
  equipped weapon and Defense, pinned skill and crit, crit and speed), and *Skill-up flash*
  (`broker.flashSeconds`).
- **Tooltip**: *Look*, *Apply skin to the tooltip* (`broker.tooltip.skin`, on): the tooltip is the
  feed's own frame in the skin's backdrop, border and fonts; off, the game's plain GameTooltip.
  The switch takes a shown tooltip down (it moved to the Tooltips page, round 4). *Sections*: one
  switch per skill section of the Skill Master feed (`broker.tooltip.sections.<primary|secondary|weapon|other>`);
  *Stats feed sections*: one per stat block of the Skill Master Stats feed
  (`broker.tooltip.sections.<stats_base|stats_spell|stats_defense|stats_utility>`), all on by default
  (round 6, R6-9: the old Stats switch went with schemaVersion 9). The stats feed has no template:
  its text is the stat pinned from a stat row's menu (*Pin to the broker feed*), its label and value,
  or "Stats" with none.

The tooltip's Hide rows moved to the [Rows](#rows) page (round 5, R5-13), same paths.

## Rows

Owner feedback round 5 (R5-11..R5-13, `settings/Rows.lua`). One page in place of the Skills page's
Professions and Weapons tabs, the Stats page (its General tab drew nothing: its one row was the
undrawn whole-set row) and the Broker page's Tooltip skills and Tooltip stats tabs. Its one tab,
*Show and hide*, is a host tab over `NS.OptionsList` (`settings/BoxList.lua`) begun with two action
columns 84 px wide (`actionWidth`) and the name at 0.62 of the row (`labelWidth`):

- an unboxed caption line (`NS.OptionsList.Header`) naming the columns, *Window* and *LDB tooltip*;
- per block in `NS.Blocks.Ordered()` (Primary Professions, Secondary Skills, Weapon Skills, Other
  skills, then the four stat groups by default), a heading line with the block's window title and
  one eye per column: it shows every hidden row of that group in that column again, as one act
  (`SetMany`, one `LAYOUT_CHANGED`), dimmed when nothing there is hidden;
- per skill (by catalog category) or stat (by group), a boxed row: its icon, its name (dimmed while
  hidden from both) and two eyes, each writing its row through the seam: `skills.hidden.<key>` /
  `stats.hidden.<key>` (the window and the detached blocks) and `broker.tooltip.hiddenSkills.<key>` /
  `hiddenStats.<key>` (the LDB tooltip). Neither set reaches the other.

The page's Defaults restores both hidden sets (every per-key row and the four whole-set rows). The
row menu's Hide and a header's restore eye write the same rows; every write redraws the page
(shown: at once; hidden: on its next show), a bracketed batch (a heading's show-all, Defaults) once
on the next frame, so the eyes always stand as stored. A block reorder (Layout > Block order) redraws
it in the new order the same way. Nothing moved path, so no schemaVersion step.

## Bars

The Bar tab's Fill subsection opens with *Fill direction* (`bars.fillDirection`, Left to right /
Right to left): every bar, in the window, the detached blocks, the tooltips, the Journal and the
broker, anchors its fill (or its tier segments), bonus, spark and markers from that edge.

The Text tab's Content subsection opens with *Rows show* (`bars.rowDisplay`: Bar and value / Bar
only / Value only), one setting for skill rows and stat rows alike. The window's rows and the
detached blocks' (both laid by `NS.Blocks.LayRows` through `NS.Rows`) and the broker tooltip's lines
honor it: Bar only drops the value text (an unlearned skill keeps its *Not learned*), Value only
draws the value in the bar's place, a skill's shaped by the bar text template. The row tooltip's
bar and the Journal's Alts mini bars are not rows and always draw. It replaced the old Stats page's
`stats.display` (schemaVersion 2, [schema.md](schema.md)).

The page has no preview bar (owner feedback round 4 removed the pinned Fishing 107 +25 / 150):
every write restyles the open window and detached blocks at once.

## Profiles

AceDBOptions drawn by AceConfigDialog into the page ([profiles.md](profiles.md)).
