# Architecture — Ka0s Skill Master

The engineer brief and the hub of the doc set (documentation-§3). Topic detail lives in the pages the
Documentation map lists; this file keeps a summary and one link per topic.

## Overview

Ka0s Skill Master shows a vanilla-era character's weapon skills, professions, Defense, Lockpicking,
Riding and character stats as skinnable data bars, with bonuses, trainer directions, a broker feed,
alerts, a session log, an alt overview and gathering helpers. The design is
`docs/superpowers/specs/2026-11-10-skill-master-design.md`; the build plan and its status ledger are
under `docs/superpowers/plans/`.

**Clients: WoW Forever only, by owner decision (2026-11-10, clients-§2, clients-§9).** Weapon skills,
Defense, level-tied skill caps and weapon-master trainers do not exist on Retail, and Retail
professions are a different system, so the addon's core has nothing to show there. The TOC carries
`## Interface: 16001` with `## AllowLoadGameType: camelot` and `## ExcludeLoadGameType: standard`.

The build (TOC `0.1.0` until the release bump; the README's Version History carries the 1.0.0
row) holds the whole v1 design: the Ace3 substrate and one LibKa0s setup file per major, each with
its degradation stub; the data layer (skills, bonuses, stats, trainers, helpers); the display (the
bar widget, the blocks and rows in one or two columns, the detached frames and the merged windows
(round 5), the crafting overlays,
the row tooltip, the trainer popup and waypoints); the broker feed, the alerts, the session log,
the alt overview and the Journal; the settings pages for every display setting; test mode's sample
character and its alts (`modules/Preview.lua` over `defaults/Preview_Forever.lua`, named from
LibKa0s-Sim-1.0's shared `Sim.Sample("forever")` people, with a library-absent copy) and the simulator
(`modules/Simulator.lua` on LibKa0s-Sim-1.0); skins; the launcher, two key bindings and the
diagnostics dump.

Pure data modules (`SkillData`, `Bonuses`, `StatData`, `Trainers`, `Helpers`, `SessionLog`, `Alts`)
read the client API through `NS.Compat` and publish bus messages; display modules consume only
messages and models, so test mode, the simulator and the headless harness drive them the same way
([data-flow.md](data-flow.md)). Strata and levels come from one table, `NS.Constants.LAYERS`
(`core/Constants.lua`, frame-layering-§5).

## Module Map

Every file, its responsibility and why the TOC orders it as it does: [module-map.md](module-map.md).
In short: `core/` holds the identity, the constants, the one setup file per LibKa0s major (Media,
Env, Core, Skin, Bus, Pool, Widgets, Lifecycle, Perf, DebugLog, Launcher), the AceAddon entry
(`core/SkillMaster.lua`) and the store (`core/Database.lua`); `core/Compat.lua` is the compat family (the skill-list shims and the reads the simulator answers),
wrapped at load by the simulator's seam (`core/SimSetup.lua`);
`defaults/Profile.lua` is the defaults tree and `defaults/*_Forever.lua` the data tables (the skill
catalog, the class weapon lists, trainers, ranks, gathering, fishing, racials, stat definitions);
`modules/` holds the display (the bar style `NS.BarStyle`, this addon's settings for LibKa0s-Widgets-1.0's
Bar, which draws every data bar; the title-bar controls `NS.Chrome`, the
blocks `NS.Blocks`, the rows `NS.Rows`, the detached frames, the merged windows `NS.Groups` and their drags `NS.GroupsSnap`, the
main window, the secure crafting
overlays, the click map `NS.Interact`, the row tooltip, the trainer popup, `NS.Waypoints` and
Skill Master's own waypoint arrow `NS.WaypointArrow`, an adapter on `LibKa0s-WaypointArrow-1.0`), the
`/sm probe` report, the skills model (`SkillData`), the bonus breakdown (`Bonuses`), the stats
model (`StatData`), the trainer lookups (`Trainers`), the skill helpers (`NS.SkillHelpers`,
`modules/Helpers.lua`), the session log (`NS.SessionLog`), the alt snapshots (`NS.Alts`), the
Journal window, the alerts (`NS.Alerts`, the rank-cap and weapon-gap toasts), the broker feed
(`NS.Template`, `NS.Broker`: the Skill Master and Skill Master Stats feeds; `NS.BrokerPanel`, their tooltip in the main window's style), test mode's data swap (`NS.Preview`), the simulator (`NS.Sim`,
`NS.SimHost`) and the diagnostics sections;
`settings/` holds the schema,
the slash table and the settings pages.

**Window chrome (LibKa0s v1.105.0 adoption, AD-88-SM and AD-89-SM).** Every window this addon draws
that shows test or simulated data (the main window, the Journal and the LDB tooltip's Main window
style) docks its strip with LibKa0s Widgets' TestStrip (`dock = "title"`, Widgets minor 27) under its
title bar, which is the skin's title band (`NS.Chrome.TitleBar`, `S.Band`). The library anchors the
strip and places it again on every show, hide and resize. The host never anchors it. Everything
below the title bar starts at the band's own bottom edge, read from the band where the skin lays it
(`NS.Chrome.TitleBottom`: its height plus its inset, which is `win.borderSize` for a flat border, as
`modules/Detached.lua`'s `D.TitleHeight` reads its band). The fixed `NS.Chrome.TITLE_BOTTOM` (31: a
1 px inset plus `title.height`, 30 px) is used only when no band is measured. A band that moves (a
skin switch) lays the body out again. The body also moves down by the strip's `BodyOffset` while one
shows (`NS.Chrome.StripOffset`), as preview-mode's *Where the strip sits* requires.

**Title-bar marks (AD-86-SM, LibKa0s#86).** Every window this addon draws builds its title-bar marks
with LibKa0s Widgets' `HeaderButtons` through `NS.Chrome.TitleMarks` (standalone-windows, *Title-bar
controls*): right-aligned, left to right the window's own extras, then settings, then the close in the
corner, 18 px marks `HEADER.PAD` (6) from the corner and `HEADER.GAP` (6) apart, placed again on the
skin's band by `S.Header` (the strip's `hb.right`), and recorded as `frame.headerButtons`. The main
window carries lock, journal and Expand / Collapse all (inward of settings, the rule's order), the
Journal the lock, the trainer popup none (its settings mark hides the popup first, `hideOnSettings`:
it stands a strata over the settings panel). The settings mark opens this addon's settings through the
opener the launcher registers (`core/LauncherSetup.lua`'s `openSettings`, LibKa0s-Core-1.0's
`OpenSettings`), and the close is built through the one wrapper, `NS.MakeCloseButton` (HeaderButtons'
`makeClose`). A detached block's band and a merged window's band carry the settings mark in the corner
and no close (they never had one; docking is their way back), their block-header marks inward of it at
the same pitch (`NS.Detached.BandMarks`, Documented deviations), `HEADER.GAP` (6 px) between every
mark with a skin's header or without one (`NS.Detached.PlaceInward`, the no-skin rung). No window opts out of the settings
mark. The addon builds no LibKa0s `DragHandle`, so no drag-handle settings mark is owed. Without the
Widgets library the same strip is built from `NS.Chrome`'s own marks at the same pitch.

Window footers are `NS.Chrome.Footer`, which is the library's `Footer`. It has no fill and the skin's
`divider` hairline, and it is `FOOTER.HEIGHT` (24 px, `NS.Chrome.FooterHeight`) tall across the
window's bottom edge (standalone-windows, *The footer* and *Window chrome geometry*). Without the
library it is a bare frame of the same height with its left line and no hairline. There are two:

- **The main window's footer** carries the bonus legend's swatches. The body ends `FOOTER.HEIGHT`
  plus a 2 px gap above the bottom edge. Its right side clears the resize grip in its corner.
- **The Journal's Alts footer** carries the hint line ("Snapshots update on login, logout and every
  skill change..."). Its right side clears the resize grip in its corner. It shows only with the
  Alts tab. The Alts body ends `FOOTER.HEIGHT` plus 8 px above the bottom edge, which keeps its row
  count unchanged. The Log tab has no footer, so its body keeps the 12 px pad.

The LDB tooltip's Main window style keeps its own footer, the hint lines from
`NS.Broker.FooterText`, which wrap and are `textHeight + 8` tall. That footer is inside a tooltip and
not along a window's bottom edge. The tooltip has no resize grip and no status line, so *The footer*
does not cover it, and it stays as it is. The launcher is out of this adoption wave's scope.

### Per-client features

All features serve WoW Forever; the addon is Forever-only by owner decision. Its core (weapon
skills, Defense, level-tied caps, weapon masters) does not exist on Retail (clients-§4, clients-§9).
No feature carries a `clients` declaration, and no code reads the client: the one per-client answer,
the default skin, is the library's (skinning-§2).

| Feature | Retail | WoW Forever |
|---|---|---|
| Skill and stat bars, blocks, detached frames, columns | not listed | yes |
| Bonuses, trainers, waypoints, gathering and fishing helpers | not listed | yes |
| Broker feed, alerts, session log, alts, Journal | not listed | yes |
| Settings pages, skins, test mode, simulator, launcher, key bindings, diagnostics | not listed | yes |

"Not listed": the TOC's load-gating pair keeps the addon out of Retail's AddOns list.

## Settings Schema

One schema (`settings/Schema.lua`, on LibKa0s-Schema-1.0) drives the panel, the CLI and resets; the
single write seam is `NS.SetByPath`. Profile rows live under `SkillMasterDB.profiles.<name>`, the
installation's rows under `SkillMasterDB.global`. Every row, default and migration:
[schema.md](schema.md).

Named non-setting state (architecture-§5): `profile.window.point`, the main window's drop point, is
geometry only a drag sets. Its one owner is `modules/MainWindow.lua`; its writers are `savePoint`
(on `OnDragStop`) and `W.ResetPosition` (the Master-controls Reset position button). LibDBIcon also
writes its own `minimapPos` into `global.minimap`, the table the Minimap button row shares. The
Journal's `profile.journal.point` and `profile.journal.size` follow the same rule with
`modules/Journal.lua` as their one owner (`savePoint`, on a drag and on the resize grip's release,
since a grab first pins the window by its top-left; `J.ResetPosition`; `saveSize`, on the resize
grip's release); `char.log` is `modules/SessionLog.lua`'s and `global.characters`
`modules/Alts.lua`'s ([schema.md](schema.md)). `profile.alerts.point`, the alert toasts' drop point,
is the same kind: its one owner is `modules/Alerts.lua`, whose toast descriptor's `setPosition` (a
test-mode drag, or the toast's `ResetPosition`) is its only writer.
The main window's size is not named state: its resize grip (AF-SM-RESIZE, `NS.Chrome.MakeResizable`,
standalone-windows *Resizing*) writes the two settings the size already comes from, `layout.width`
(Window width, one column's: the frame width maps back through `layout.columns`) and
`layout.maxHeight` (Window height), through `NS.SetByPath` in one bulk bracket on the release, so the
Layout page's sliders follow it and its one coalesced `LAYOUT_CHANGED` is the one full redraw. While
the grip is dragged only `W.Relayout` runs (the columns and the body take the new width, at most once
a rendered frame), and a render meanwhile keeps the grip's size. The release snaps both values to their
rows' step grid (10 px, from each row's minimum), so a slider nudge after a drag never jumps the
window. The grip's bounds are those rows'
ranges at the current column count, capped at the screen in the frame's own units (the screen size
divided by Master scale, re-applied by `W.ApplySettings`), so a scale above 1 never lets the window
grow past the screen. A grab pins the window by its top-left
(`NS.Chrome.PinTopLeft`), and the release saves that point with `savePoint`. `locked` hides the grip
and its `canResize` refuses a grab, so `/sm lock`, `/sm unlock`, the header's lock mark and the
launcher's Locked all gate it with the drag. The LDB tooltip (`modules/BrokerPanel.lua`) has no grip.
The waypoint arrow keeps no named non-setting state since round 9 (R9-1): its drop point
(`profile.waypoints.arrowFrame.point`, round 6) is gone, and a drag, the arrow's Lock and Reset
position write the `waypoints.arrowX`, `arrowY` and `arrowLock` settings through `NS.SetByPath`
(the library's `d.set`), so the Position block's sliders follow the drag. The arrow's own Lock is
its only drag gate; `/sm lock` holds the windows and no longer the arrow (Documented deviations, slash-commands-§8).

`profile.layout.blocks[id].point` (T3.2) is named non-setting state, owned by `modules/Detached.lua`:
its writers are `savePoint` (a detached frame's `OnDragStop`) and `D.StorePoint` (where a section
split from a merged window, or a window unmerged, lands; called by `modules/Groups.lua`). `docked`, `order` and `collapsed` are
settings like any other, with schema rows on the Layout page (T5.1), and every actor writes them
through `NS.SetByPath` (architecture-§5): the block header and the detached frame's buttons
(`NS.Blocks:Detach` / `:Dock` / `:SetCollapsed`), the Block order drag list (`:Move`, every changed
`order` inside one bulk bracket, one `LAYOUT_CHANGED`), the window's one Expand / Collapse all control
(`:SetAllCollapsed`, every docked block's `collapsed` inside one bulk bracket, one `LAYOUT_CHANGED`)
and `/sm set`. The `docked` and `collapsed`
rows' `set` (`NS.Blocks.StoreDocked` / `StoreCollapsed`) stores the value and waits out combat;
`order` stores plainly, its `onChange` `NS.Blocks.OrderChanged`. The seam logs each write
(debug-logging-§10). `shown`, `scale` and `locked` are plain rows. `sort` (round 3) and each
block's `filter` (the weapon block's, round 5, R5-10; every block's, round 7, R7-1; each block's set
in `NS.Blocks.FILTER_SETS`: Primary and Secondary `all`, `belowCap`, `atCap`; Weapon Skills `all`,
`learned`, `equipped`, `belowCap`; Other skills `all`, `learned`, `belowCap`; each stat section
`all`, `nonZero`) are plain rows too, each written from its header mark's menu through the seam
(`NS.Blocks:SetSort` from the sort mark's, round 6, `NS.Blocks:SetFilter` from the filter mark's,
which refuses a mode outside the block's set); the filter narrows the block in the main window, its
detached frame, its merged section and both LDB tooltip styles (`NS.Blocks.Entries`). `skills.hidden` /
`stats.hidden` are sets: one Hide row per catalog skill and per stat (get / set: false clears the
entry), and one undrawn row per whole set (type `set`, default `{}`), which the row menu's Hide
writes for a key with no row of its own (an `other:` skill) and the page's Defaults resets. The
LDB tooltip's own sets (`broker.tooltip.hiddenSkills` / `hiddenStats`) follow the same pattern. All
four sets live on one page, Rows (`settings/Rows.lua`, round 5, R5-11..R5-13): every skill and stat
once, one tab per block since round 9 (R9-5: the block's short name, in the default `NS.BLOCKS` order,
each tab drawing only its own group), one eye per set (Window, LDB tooltip) on `NS.OptionsList`'s two-column rows, and one show-all eye per column on each
heading (`SetMany`, one act). It replaced the Skills page's Professions and Weapons tabs, the Stats
page (gone: its General tab held only the undrawn set row) and the Broker page's Tooltip skills and
Tooltip stats tabs. The paths did not move, so nothing migrated. Every hide write, from any actor
(the page's eyes, the row menu, a header's restore eye, `/sm set`), goes through `H.RefreshPanel`:
a page on screen renders at once, a hidden one is owed a render; writes inside a bracket (a
heading's show-all, the page's Defaults) coalesce into one render on the next frame. A block
reorder changes the window, not the page's tab strip (round 9).

`profile.layout.detached` (round 5, R5-7) is one style for every detached window, set on Layout >
Detached windows. `NS.Detached.ApplyStyle(frame)` paints it on each render: the scale (the frame's
own `ownScale` times the tab's), the opacity, the background (the skin's `S.Shell` fill while
`bgFromSkin` is on, else the swatch on a BACKGROUND 2 fill of the frame's own, over the skin's
gradient and art and under the band), the border (the skin's edge while `borderFromSkin` is on,
`S.Shell` `noBorder` otherwise, the frame's own edges through `NS.Chrome.PaintBorder`) and the title
band (`noTopBar` and the frame's `bandParts` hidden for Never; for On hover a 0.1 s `OnUpdate` poll of
`IsMouseOver` toggles both). `S.Shell` is re-called only when its opts change, and the skin's own
repaint replays the recorded ones. A merged group's frame takes the same call.

`profile.layout.groups` (round 5, R5-6) is named non-setting state: the merged detached windows, each
`[gid] = { point, columns = { { id, ... }, ... } }`, membership derived from the columns. Its one owner
is `modules/Groups.lua` (`NS.Groups`): `Merge`, `Split`, `Unmerge`, `Leave` (called from
`NS.Blocks.StoreDocked`, so a block docked by any path leaves its group), the band drag's
`savePoint`, and the normalization every read runs (`NS.Groups.Model.Normalize`: a member no longer
detached, a repeat, an empty column and a group of fewer than two blocks go). The pure model
(`NS.Groups.Model`) works on plain tables and is what the headless suite and the schemaVersion 6
step drive. A grouped block's own frame hides and its rows draw in the merged window; its own
`point` is kept for when it leaves. A merge places the group so the target stays where it stood:
measured before the model moves anything, a left merge moves the group left by the added columns
and a top merge raises it by the dragged sections' drawn extent (each sub-header and its rows, a
dragged group flattened into one column). Merges, splits and unmerges wait out combat on
`SecureOverlay:AfterCombat` as a dock does, one queued merge per dragged window, so two drops in one
combat both happen when it ends; Collapse all and Dock all write each block through the
seam inside one bulk bracket (`NS.Blocks:SetCollapsedFor`, `:DockAll`). The merged window takes the
Detached windows style through `NS.Detached.ApplyStyle`.

The drags that merge and split (round 5, R5-6b) are `modules/GroupsSnap.lua` (`NS.GroupsSnap`),
after AuraMaster's container snapping. Its pure core, `Nearest(rect, targets, exclude)`, takes rects in
UIParent units and answers the nearest target side: the dragged window's facing edge within
`SNAP_RADIUS` (24) of a side, the two overlapping along the other axis, the window itself (or its own
group) never a target, and for a top or bottom side the column under the dragged window's center.
`Classify(dx, dy)` is the section drag's leeway: within `DETACH_RADIUS` (128) of its start it holds,
past it it is out. The driver starts on a detached window's drag, a merged window's band or frame
drag (`BeginWindow`) and a section sub-header's drag (`BeginSection`: a ghost of the sub-header
follows the pointer, edged `sem.good` inside the leeway and `sem.bad` past it). One `OnUpdate`, armed
only while a drag is on, re-measures at most every 0.05 s and shows a `sem.good` strip on the
candidate side, a strata above the detached windows. The drop (`Drop`) calls `NS.Groups.Merge` on the
candidate, or for a section past the leeway with no candidate `NS.Groups.Split` at the ghost's
top-left; a window with no candidate just keeps its saved drop point. A lock refuses each drag at its
start; in combat the frame still moves and the merge or split waits on `AfterCombat`. A stand-down
mid-drag cancels it (`NS.Groups.StandDown`). Secret or unanswered geometry gives no candidate.

`char.pinned`, the skill the broker's `{pinned}` shows, and `char.pinnedStat`, the stat the Skill
Master Stats feed shows (round 6, R6-9), are named non-setting state: their one writer is the row
menu's Pin (`I.MenuRows` in `modules/Interact.lua`, a skill row's and a stat row's), disabled while
test mode or a simulation runs so a sample row never lands in them.

HUD colors follow the skin (skinning-§6): every `*FromSkin` companion, the palette's
`bars.colors.fromSkin` included, defaults true; while the palette follows, the categories and
bonuses draw the owner tokens `sm.cat.*` and `sm.bonus*` (`core/SkinSetup.lua`). No
`Skin.FollowOnce` step: the addon was born on LibKa0s v1.94.0 with the companions on, so no stored
profile predates them ([schema.md](schema.md)).

No structural registry exists.

## Message Bus

Six messages, each declared once in `core/Bus.lua` as `NS.MSG.<KEY>` through LibKa0s-Bus-1.0's
strict catalog, so a misspelled constant raises. `SkillData` sends `SKILLS_UPDATED` and `SKILL_UP`
(the simulator's restoring stop re-sends `SKILLS_UPDATED` with the live model),
`Bonuses` sends `BONUSES_UPDATED`, `StatData` sends `STATS_UPDATED` and `Blocks` sends
`LAYOUT_CHANGED`; the simulator (`modules/Simulator.lua`) sends `SIM_TICK` after each step.

| Constant | Wire name | Sender | Payload | Consumers |
|---|---|---|---|---|
| `SKILLS_UPDATED` | `Ka0s_SkillMaster_SkillsUpdated` | `modules/SkillData.lua` (T2.1); the simulator's restoring stop (`modules/Simulator.lua`) re-sends the live model | the skills model | blocks, broker, alerts, alts, Journal |
| `SKILL_UP` | `Ka0s_SkillMaster_SkillUp` | `modules/SkillData.lua` (T2.1) | key, old, new | blocks (session gains), broker flash, alerts, session log |
| `STATS_UPDATED` | `Ka0s_SkillMaster_StatsUpdated` | `modules/StatData.lua` (T2.3) | the stats model | stat blocks, broker |
| `BONUSES_UPDATED` | `Ka0s_SkillMaster_BonusesUpdated` | `modules/Bonuses.lua` (T2.2) | none | bars, tooltips, broker |
| `LAYOUT_CHANGED` | `Ka0s_SkillMaster_LayoutChanged` | `modules/Blocks.lua` (detach, dock, collapse, collapse all, move); the skin owner's look-change hook; `NS.ApplyLook` (every display row's write, `settings/OptionsSetup.lua`) | none | `modules/Blocks.lua`, which repaints the window and the detached frames; the Journal; the trainer popup (`modules/TrainerPopup.lua`, its trainer names' color while it is shown) |
| `SIM_TICK` | `Ka0s_SkillMaster_SimTicked` | `modules/Simulator.lua` (T5.2), after each step | the step's kind | none yet (published for displays under simulation) |

## Slash Commands

`/sm` and `/skillmaster`, one LibKa0s-Slash-1.0 dispatcher over `NS.COMMANDS` (`settings/Slash.lua`):
`help`, `config`, `skin`, `show`, `hide`, `toggle`, `journal`, `lock`, `unlock`, `test`, `sim`, `probe`, `enable`, `disable`,
`list`, `get`, `set`, `reset`, `resetall`, `debug`, `diagnostics`, `perf`, `version`. The bare
command opens the settings panel. While disabled, every verb but the library's live set refuses on
one line. A report verb (`probe`, `diagnostics`) writes to the debug console, ungated, and prints
one chat pointer; acknowledgments, refusals, `help` and `list` stay in chat
([debug.md](debug.md#reports)). The table with each verb's handler and refusal:
[slash-dispatch.md](slash-dispatch.md).

## Event Subscriptions

| Event | Registered by | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | `NS.RegisterRuntime` (`core/SkillMaster.lua`) | `addon:OnEnterCombat` | combat ends test mode (its three toasts and the windows it opened come down) and a running simulation (preview-mode) |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` | `modules/SecureOverlay.lua` at load, on its own bus target | disarm every crafting overlay at the combat-start edge; after combat run the queued layout work, then re-sync the overlays | Taint Notes below |
| `SKILL_LINES_CHANGED` | `NS.SkillData:Enable` (from `NS.RegisterRuntime`) | debounced `SkillData:Scan` (0.1 s) | the skill list changed; the echo of the scan's own header toggles is ignored for 0.2 s |
| `CHAT_MSG_SKILL` | `NS.SkillData:Enable` | debounced `SkillData:Scan` | a skill-up line |
| `PLAYER_LEVEL_UP` | `NS.SkillData:Enable` | debounced `SkillData:Scan`, with the new level as the weapon-cap floor (5 x level) | the list can still answer the old cap |
| `UNIT_INVENTORY_CHANGED`, `UNIT_AURA` | `NS.UnitEvents` (`core/UnitEventsSetup.lua`), `RegisterUnitEvent` for `"player"` on its one frame, stood up from `NS.RegisterRuntime` | `addon:OnBonusesUnitChanged`: player only, debounced `Bonuses.Refresh` (0.2 s), which re-reads only the part the event touched (an aura change never re-reads the 19 item tooltips); a 1 s ticker while a temp bonus naming a skill is live | gear, lures and buffs change the breakdown |
| `PLAYER_REGEN_ENABLED` | `modules/Bonuses.lua` at load, on its own bus target | `B.Schedule("buffs")` when a buff read was blocked as secret in combat | a buff read secret in combat can be read again (WoW Forever) |
| `UNIT_STATS`, `UNIT_ATTACK_POWER`, `UNIT_RANGED_ATTACK_POWER`, `UNIT_RESISTANCES`, `UNIT_DAMAGE` | `NS.UnitEvents`, for `"player"` (recorded by `modules/StatData.lua` at load) | `StatData:Request`: one `STATS_UPDATED` 0.2 s after a burst | the stats model follows gear, buffs and level |
| `PLAYER_EQUIPMENT_CHANGED`, `UPDATE_INVENTORY_DURABILITY`, `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED` | `modules/StatData.lua` at load, on its own bus target (`NS.SafeRegisterEvents`) | `StatData:Request`: player only, one `STATS_UPDATED` 0.2 s after a burst | the stats model follows gear, buffs and level; leaving combat re-reads what combat answered secret |
| `PLAYER_EQUIPMENT_CHANGED` | `modules/Detached.lua` at load, on its own bus target | `onEquipmentChanged`: re-render the detached weapon block (or the merged window it is a section of) and re-sync the overlays while it is shown; with the header's Equipped filter on a docked weapon block, refresh the main window at once (round 5, R5-10) | a weapon swap changes the weapon block's equipped-only list |
| (timer) | `NS.TrainerPopup.Show` | `P.RefreshDistances` every 1 s (AceTimer, `P.TICK`) while the trainer popup is shown; `P.Hide` and the frame's `OnHide` cancel it, the frame's `OnShow` restarts it (a UIParent hide and show, Alt+Z or a cinematic, runs both; the R5-followups review) (round 5, R5-15) | the player moves: the distances and the nearest-first order follow |
| `PLAYER_LOGOUT` | `modules/Alts.lua` at load, on its own bus target | `Alts:Snapshot` | the last snapshot of the session |
| `USER_WAYPOINT_UPDATED` | `modules/WaypointArrow.lua` at load, on its own bus target | `WaypointArrow.OnWaypointUpdated`: with an arrow up, `C_Map.HasUserWaypoint` false, or a pin whose world place lies more than 2 yd from the trainer's, hides it; a pin the client cannot place keeps it (round 6, R6-11) | the native pin was cleared or replaced elsewhere (the world map's own pin) |
| (`OnUpdate`) | `LibKa0s-WaypointArrow-1.0` on show (round 8, R8-5: the adapter's `Show` and `ShowTest`) | one measure every `WA.THROTTLE` (0.03 s, the library's): the player's world place and facing against the trainer's, the art's rotation (a sheet frame for On the ground), color and the yards; armed on show, set to nil on every hide path (the library's `takeDown`); no `OnHide` disarms it, since a UIParent hide and show (Alt+Z, a cinematic) fires `OnHide` and the arrow would come back frozen (round 6, R6-11; the R6-11 review) | the arrow follows the player |

The bus subscribers on their own targets: `modules/Blocks.lua` hears `SKILLS_UPDATED`,
`STATS_UPDATED`, `BONUSES_UPDATED`, `LAYOUT_CHANGED` and `SKILL_UP` (repaint, revalue, relayout,
session gains); `modules/TrainerPopup.lua` hears `LAYOUT_CHANGED` (the names' color while shown);
`modules/SessionLog.lua` hears `SKILL_UP` (one log entry,
with the zone); `modules/Alts.lua` hears `SKILLS_UPDATED` (one snapshot 2 s after a burst);
`modules/Journal.lua` hears `SKILLS_UPDATED` and `LAYOUT_CHANGED` (a repaint while shown);
`modules/Alerts.lua` hears `SKILL_UP` and `SKILLS_UPDATED` (the cap and weapon-gap checks);
`modules/Broker.lua` hears `SKILLS_UPDATED`, `SKILL_UP`, `STATS_UPDATED` and `BONUSES_UPDATED`
(the feed texts and the flash).

Every registration goes through `NS.SafeRegisterEvent` (events-frames-taint-§1); a refused name
lands in `NS.rejectedEvents`, which the `[Init]` summary and the diagnostics report print. The stand-
down unregisters every event and cancels every timer; the stand-up re-registers from current state.
The player's `UNIT_*` events sit on one private frame, `NS.UnitEvents` (`core/UnitEventsSetup.lua`),
registered through `NS.SafeRegisterUnitEvent` for `"player"` so the client filters other units
(events-frames-taint-§1's unit-filter carve-out); the frame has one dispatching `OnEvent`, and the
latch's stand-down and stand-up are its only teardown and rebuild.

## Taint Notes

The window, the detached frames, the rows, the trainer popup and the waypoint arrow are plain frames
(the arrow stays up in combat: it is not secure), and the key
binding clicks a plain, non-secure button. The settings panel never opens in combat (the library
refuses, options-ui-§2). The one secure surface is the action marks' overlays
(`modules/SecureOverlay.lua`, T3.3; owner feedback round 4: a row's mark is the action; round 8,
R8-1: Layout > Window > *Open a row from*, `layout.openFrom`, says whether a click anywhere on the row
does it too, *Full row*, the default, or the mark alone, *Go icon only*; the detached and merged
windows follow it). Two kinds of `SecureActionButtonTemplate`: one per profession whose window
opens by a cast (`type1 = "spell"`, the localized open spell), and one per character-panel row (a
stat row's paper doll, a weapon, Other or gathering row's Skills tab) that clicks the micro menu's
`CharacterMicroButton` through a secure macro. On WoW Forever an addon that shows `CharacterFrame`
itself taints its `OnShow`, whose PlayerFrame status-bar text then compares secret health values
and raises (docs/forever-quirks.md, "The character panel and secret geometry"); the micro button's own click shows it untainted. `PreClick`
(out of combat: an overlay is never armed in combat) selects the Skills tab's line and writes the
macro for the panel's state, and `PostClick` switches to the Skills tab on the panel already shown,
which is still a tainted sub-frame switch (no secure route reaches that tab: its mode tabs are
mouse-up frames, not buttons). A "spell" overlay's `PreClick` clears its cast for anything but a
plain left click (round 8, R8-1), so a shift-click over it links without opening the window. Each
overlay is parented to `UIParent` and laid over its row's mark (*Go icon only*) or the whole row
(*Full row*, `SO.CoverFor`) at absolute coordinates, one strata above the host and only while the pointer is on that
row (Documented deviations, frame-layering-§1), so no plain frame is ever a secure frame's parent or anchor and
the rows, the window and the detached frames hide, move and re-lay freely in combat. Every
creation, attribute, anchor, strata, level, show and hide of an overlay happens in `Sync`, which in
combat only marks itself dirty; `PLAYER_REGEN_DISABLED` (lockdown not yet on,
events-frames-taint-§2) disarms every overlay so none stays mouse-live in combat, and
`PLAYER_REGEN_ENABLED` replays the combat queue (`SecureOverlay:AfterCombat`: dock, detach,
collapse, and a merge, split or unmerge of merged windows wait there, Review Focus 3) and re-syncs.
The overlays scan the merged windows' rows too and follow each merged window (`SO:Follow`, and
`SetMoving` while its band drags it). A mark click in combat (or, in *Full row*, a row click)
reaches the plain mark's action and prints one line (a profession, or the character panel). Shift- and right-clicks pass through the overlay (`PostClick`) to the row's
handlers. The broker feed (`modules/Broker.lua`, T4.1) is never secure itself: its tooltip rows are
plain buttons parented to the tooltip frame (its own, or GameTooltip with the skin off) that open windows (the main window, the character frame), and
a crafting row opens the main window scrolled to it rather than casting (design §6.5). Its
character-panel clicks still call `ToggleCharacter` from the addon, so on Forever they can raise the
same tainted `OnShow` error ([known-limitations.md](known-limitations.md)). The exception is the Main window style (round 7,
R7-6): its rows are the window's, and the overlays scan them too while the panel shows
(`NS.BrokerPanel.Armed`, either *Open a row from*), so the hovered row gets the window's own spell
cast or micro-button macro, over the whole row with Tooltips > LDB tooltip > *Open a row from* on
*Full row* (`tooltips.ldb.openFrom = "row"`, the default since round 8, R8-1; each panel row carries
it as `row.openFrom`) or over its go icon on *Go icon only*. Over the panel (TOOLTIP, the top strata, which `STRATA_ABOVE` has no row for)
the overlay stays in TOOLTIP, `LEVEL.SECURE` above the panel, which is not a toplevel window. The
panel's scroll and its hide re-sync the overlays (out of combat; at combat start every overlay is
disarmed as ever), its released rows are forgotten, and the overlay's shift- and right-clicks go to
the panel row's own handler (`row.overlayClick`: the link and the row menu lifted over the tooltip).
In *Go icon only* the row's own left click opens nothing; in *Full row* it, like a go icon click the
overlay did not take, is `NS.Interact.Open`, so in combat it says why it cannot open, as the
window's mark does. In the Classic style (no go icon) the row's click opens as before
(`NS.Broker.OpenRow`) and no overlay is laid. A tooltip row's shift-click links it into chat in both
modes and both styles.

## Tooltip placement

Every tooltip Skill Master places itself opens where its element sits in its window, never at the
pointer and never off a corner of the control (WowAddonStandards standalone-windows, *Tooltip
placement*; launcher-§7; LibKa0s#92, adopted as AD-92-SM). Each is owned at `ANCHOR_NONE`, filled,
shown, and then placed by one of `NS.Chrome`'s three placers (`modules/Chrome.lua`), which read
`LibKa0s-Tooltip-1.0` at call time. With the library absent, or geometry the library cannot read (a
placer answers nil and places nothing), the tooltip attaches centered above its element, 2 px off, as
the library's own fallback does. `tests/test_tooltips.lua` holds each site to its placer, checks the
right-fits and right-does-not-fit layouts on the kit's fake screen, and guards the addon's Lua against
any game anchor but `ANCHOR_NONE`.

| Element | Class | Placer | Window group |
|---|---|---|---|
| A skill or stat row: main window, detached block, merged window, the LDB tooltip's Main window panel (`modules/RowTooltip.lua`) | body | `NS.Chrome.PlaceBeside` | `GroupOf(row)`: the row's outermost frame under UIParent (the window, the whole detached or merged HUD display, the panel) |
| A Journal Alts column header (`modules/Journal.lua`) | body (a list's column-header row) | `NS.Chrome.PlaceBeside` | the Journal |
| A trainer card (`modules/TrainerPopup.lua`) | body | `NS.Chrome.PlaceBeside` | the trainer popup |
| The waypoint arrow (`modules/WaypointArrow.lua`, the host's `onEnter` on the library's frame) | body (a HUD display of one icon) | `NS.Chrome.PlaceBeside` | the arrow, the whole display |
| The trainer popup's Set waypoint button, when disabled (its reason) | chrome (a modal dialog's control) | `NS.Chrome.PlaceAttached` | none: centered above the button |
| The broker feeds' tooltip on a display's cell, both Tooltip styles (`modules/Broker.lua` `anchor`) | the launcher shape (launcher-§7) | `NS.Chrome.PlaceLauncher` | none: toward the screen's center, 2 px off the cell |
| The library-absent rung of a title-bar or block-header mark (`modules/Chrome.lua` `showTip`) | chrome | attached above, by a relative point | none |

Each was owned at a game anchor before: `ANCHOR_RIGHT` (a row, a card, the arrow), `ANCHOR_TOP` (the
Set waypoint button, a mark without the library) and `ANCHOR_BOTTOM` (a column header). The broker
feed's tooltip was already attached to its cell toward the screen's half; it now takes the launcher
placer's horizontal side by screen third and its gap as well.

**Left as they are, and why.**

- **The title-bar marks, the closes and the block-header marks** (every window's header strip, a
  detached or merged band, the main window's block headers). `LibKa0s-Tooltip-1.0`'s `AttachTitleTip`
  places them above the control through `PlaceAttached` (`NS.Chrome.IconButton` / `HeaderMark`,
  Widgets' `HeaderButtons`, `NS.MakeCloseButton`). The block headers' marks are treated as
  header-strip controls, as smoke round 1's ruling 3 does for every header-strip mark
  (`tests/test_sr1.lua`).
- **The bonus scanner** (`modules/Bonuses.lua`, `SkillMasterScanTip`). A hidden tooltip owned by
  UIParent at `ANCHOR_NONE` to read item lines. It is never shown, so it has no placement.
- **The minimap button's status tooltip.** `LibKa0s-Launcher-1.0` draws it and re-places it through
  `PlaceLauncher` (Launcher minor 11). No host code anchors it (launcher-§7).
- **The launcher's options menu.** The client's own menu (`MenuUtil.CreateContextMenu`) places its
  entries' tooltips (*What it does not bind*). Its rows are the library's (Enabled, Locked, Test
  mode, Sim mode, Show window, Open settings, Open skin selector) plus this addon's one host row,
  *Journal*, after Show window (`extraEntries`, Launcher minor 11, LibKa0s#81, AD-81-SM): a checkbox
  ticked while the Journal is open, whose click is `/sm journal`'s own handler (launcher-§2), grayed
  while the addon is disabled.
- **Library windows and widgets**: the row menu (Widgets' `ContextMenu`), the docked test and sim
  strips, the debug console, the sim and perf panels, the skin picker and the icon browser. Each is
  placed in the library's own code (`docs/api/Tooltip/version-1-docs.md`, *The library's own sites*).
- **The settings pages** in Blizzard's Settings canvas, the library's Options widgets among them.
  options-ui governs them, and the tooltip-placement rule does not bind them.
- **A broker display's own placement.** The feeds supply `OnEnter`, so the display does not place
  their tooltip. Skill Master places it, as the row above describes. A display that ignores
  `OnEnter` and calls `OnTooltipShow` would get no tooltip, because the feeds define no
  `OnTooltipShow`.

## Known Limitations

What the addon does not do yet, and what is still unverified in game: [known-limitations.md](known-limitations.md).
The main themes are the character panel opened from the Classic-style broker tooltip (a tainted `OnShow`),
the secure overlays' placement and the Skills tab's tainted switch, the trainer popup's and the waypoint
arrow's measurements, test mode and the simulator's reach, and the client APIs assumed until `/sm probe`.

## Documentation map

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `ARCHITECTURE.md` | This file — the hub: overview, module map summary, schema, bus, slash, events, taint, limitations, this map, deviations |
| `scope.md` | What Skill Master shows, and what it deliberately leaves to the game and to other addons |
| `module-map.md` | Every non-vendored file, its responsibility and the TOC's load order |
| `schema.md` | The SavedVariables shape, every default and the migration path |
| `settings-panel.md` | The `Page \| Covers` table and the page → tab → row tree |
| `data-flow.md` | Events in, data modules, messages, displays |
| `common-tasks.md` | Recipes: add a setting, a slash verb, a message, a locale string |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | `NS.COMMANDS` carries eight or more commands (23 as measured on 2026-11-10) |
| `forever-quirks.md` | Present | Clients includes Forever (forever-quirks-§1); holds the vendored Forever catalog and this addon's assumed-API table |
| `midnight-quirks.md` | Not applicable | Clients is `Forever`; the Retail catalog is carried only where Clients includes Retail (client-quirks-§1) |
| `debug.md` | Present | The diagnostics dump is a debug surface beyond the default console (debug-logging-§14) |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `compat-layer.md` | Present | `core/Compat.lua` publishes three or more addon-specific shims (10 as measured on 2026-11-10: the skill list, the player, the weapon enchant, the item tooltip, the unit speed, the spell name) |
| `message-bus.md` | Not applicable | More than ten messages (six as measured on 2026-11-10) |
| `known-limitations.md` | Present | Known Limitations ran past 60 lines (132 on 2026-11-15) |
| `taint.md` | Not applicable | Taint Notes is under 60 lines |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint under the Forever profile; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite, Forever only, plus the not-listed-on-Retail check |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page: buckets, brackets, the capture workflow |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `validate-seeds.md` | The seed-validation contract `/dev-copilot:validate-seeds SkillMaster forever` runs: `tools/seeds/seeds.py` re-checks the trainer, fishing-zone and skill-catalog seeds against WoW Forever's own DB2 (wago.tools `wowf`), with its rulings, precedent and gate |

Frozen and generated material is out of the map and named once per directory (documentation-§3):
`docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/seed-research/<date>-<flavor>/` (a seed-validation run's frozen
bundle, [validate-seeds.md](validate-seeds.md)), `docs/superpowers/` (the v1 design spec, its mockup
sources, the plan and its status ledger) and `docs/investigations/`. Of these, `docs/audits/`,
`docs/reviews/`, `docs/revendor/`, `docs/seed-research/`, `docs/superpowers/` and
`docs/automated-tests/<run>/` exist today.

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| localization-§4 | Three things still match on a localized name, through the locale keys (`NS.L`): a skill line whose record carries no skill-line ID (the 1.12 positional list), the three excluded Skills-tab headers (Class Skills, Armor Proficiencies, Languages) and the crafting spell when `NS.Compat.SpellName` answers nothing for its ID. Every record that carries an ID is matched on it first (`NS.SkillLineIDToKey`), and the crafting cast uses the name its spell ID resolves to. | The client hands no ID for a 1.12-shaped line or for a header, so the locale key is the only route; enUS ships the strings, the other locale files are stubs, so a non-enUS client on the positional shape sorts its lines into Other until they are translated ([known-limitations.md](known-limitations.md)). | 2026-11-10, M6 review F-001 | `/sm probe` shows whether Forever's struct carries a skill-line ID (then only the headers remain), or the locale files gain the skill-line and header strings |

| skinning (LibKa0s `S.Tooltip`) | The skinned broker tooltip (FB-13) is an addon-owned `GameTooltip` frame (`SkillMasterBrokerTooltip`) painted with `NS.Skin.Shell` and `NS.Skin.Text`, not the library's `S.Tooltip`. | `S.Tooltip` only recolors a backdrop the frame already has, and a modern `GameTooltipTemplate` frame draws its art through NineSlice, so there was nothing for it to recolor; the shared `GameTooltip` is never restyled. | 2026-11-10, feedback round 2 | LibKa0s ships a tooltip skin that paints an owned or template tooltip frame |
| options-ui-§16 | `bars.borderStyleFromSkin` (*Use the skin's border*, the bar border's style companion) defaults `false`, in `defaults/Profile.lua` and on its composed row; every other `*FromSkin` companion defaults `true`. | The owner wants no bar border by default under every skin. Azeroth, High Contrast and WoW Midnight state a real bar border style, which wins over *Show border* off while the companion is on (skinning-§6), so the companion on drew an edge the player had switched off. With it off, *Show border* decides; ticking it opts into the skin's border. No migration: AceDB stripped every stored `true` (the old default). | 2026-11-10, feedback round 2 follow-up | The standard lets a bar border companion default off, or makes a host's *Show border* off win over a skin's real style |
| frame-layering-§1 | The crafting rows' secure overlays (`modules/SecureOverlay.lua`) sit one strata above their host window or detached block (`LAYERS.STRATA_ABOVE`), not in the host's strata at a level over it, and only the hovered crafting row's overlay is armed. | The hosts are toplevel (frame-layering-§4), and the client orders a raised toplevel window with everything in it as one group: an overlay in the host's strata lost the hit test to the row under it at any frame level, so no crafting click ever opened a profession (`GetMouseFoci` named the row alone, the overlay shown, placed and three levels higher). Arming only the hovered row keeps an invisible mouse-live frame a strata up from covering another window: a window over the row takes the pointer first, so the row is never hovered. | 2026-11-11, feedback round 2 | The standard gains a rule for secure click overlays over toplevel windows, or the client hit-tests a separate frame over a toplevel window's children by level |
| frame-layering-§6 | The row menu (LibKa0s-Widgets-1.0 `ContextMenu`, a library-owned popup at FULLSCREEN_DIALOG) is lifted by the host to TOOLTIP strata, at the open LDB tooltip's level + `LAYERS.LEVEL.POPUP`, while it is open from that tooltip (`NS.Broker.RaiseMenu`: the row menu, and the Main window style's test-strip menu, round 6 review), and put back to FULLSCREEN_DIALOG (`LAYERS.STRATA.MENU`) as it hides. The standard names the library's tier as one this addon relies on, not one it moves; flagged in round 6 and accepted by the owner in round 7. | Both LDB tooltip styles sit at TOOLTIP, the strata every tooltip takes, so the menu opened from a row at FULLSCREEN_DIALOG drew under it and was half hidden (owner feedback round 6, R6-10, screenshot 59). The library offers no strata option for `ContextMenu`. | 2026-11-13, owner feedback round 6; owner-accepted 2026-11-13 (round 7, R7-8) | LibKa0s's `ContextMenu` takes a strata (or an opener frame whose strata it sits above) |
| library-stack (LibKa0s `Core.ClassColor`) | The header's character name (FB-17) is colored from `RAID_CLASS_COLORS[classFile]` directly, not through `Core.ClassColor`. | The helper reads only the live unit, so test mode and the simulator's sample character would show the player's color; the Journal's alt rows already color this way. | 2026-11-10, feedback round 2 | LibKa0s's class-color helper accepts a class file |
| standalone-windows (*Title-bar controls*) | A detached block's band and a merged window's band build only their settings mark with `W.HeaderButtons` (`close = false`); their block-header marks (dock, collapse, sort, filter, restore; dock all, collapse all) stay `NS.Chrome.HeaderMark`s, placed inward of the settings mark at the strip's pitch (`HEADER.PAD`, `HEADER.GAP`) by the skin's `S.Header`, not built as the strip's extras. | Those marks carry state the library's `HeaderButton` does not: art cropped to its ink box (round 6, R6-3), the filter's filled badge in its own colors (round 8, R8-2) and the restore mark's own showing; an extra built by the library repaints itself at `icon.tint` on a skin switch, which would undo the badge. Their colors already follow the rule (`icon.tint` at rest, `text.link` hot). | 2026-11-17, AD-86-SM (LibKa0s v1.105.0 adoption, wave B) | `W.HeaderButtons` adopts host-built extras (as it adopts `closeButton`), or carries a badge state. Not yet filed as a LibKa0s issue (review of AD-86-SM, 2026-11-17): the run's lead files it, and this row then cites it |
| standalone-windows (*Which marks a window owes*, v2.115.0) | A detached block window, a secondary window, carries no close mark in its header: `NS.Detached.BandMarks` builds its band with `close = false` (`modules/Detached.lua:162-163`, called at `modules/Detached.lua:218`), so its marks are the settings mark and the block's own (dock, collapse, sort, filter, restore). | The dock mark is the designed way back: docking returns the block to the main window, which carries the close. A close would hide a block the player never docked back, leaving it out of both windows. | Owner waiver of 2026-11-19 (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, its owner rulings; item AF-WVR-SM), named in the bullet's waiver list | A detached window gains state a dock cannot restore, or the standard drops the waiver |
| standalone-windows (*Which marks a window owes*, v2.115.0) | A merged (group) window, a secondary window, carries no close mark in its header: its band is built through the same `NS.Detached.BandMarks` (`modules/Groups.lua:645`), `close = false`, so its marks are the settings mark, Dock all and Collapse all. | Dock all is the designed way back, as for a detached block: it returns every merged block to the main window, which carries the close. | Owner waiver of 2026-11-19 (Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/`, its owner rulings; item AF-WVR-SM), named in the bullet's waiver list | A merged window gains state Dock all cannot restore, or the standard drops the waiver |
| slash-commands-§8 | `/sm lock` and `/sm unlock` lock the windows only; the waypoint arrow has its own Lock (`waypoints.arrowLock`, on Trainers and Waypoints › Arrow position and in the arrow's right-click menu), which `/sm lock` does not reach. | Owner decision (round 9): the arrow is moved and locked on its own, apart from the windows, and the library widget owns that lock for every consumer. | 2026-11-14 (owner, round 9) | The standard rules on per-widget locks, or the owner asks for `/sm lock` to hold the arrow too. |

### Files over the 1500-line cap

Nothing is over the cap today.
