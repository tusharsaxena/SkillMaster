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
bar widget, the blocks and rows in one or two columns, the detached frames, the crafting overlays,
the row tooltip, the trainer popup and waypoints); the broker feed, the alerts, the session log,
the alt overview and the Journal; the settings pages for every display setting; test mode's sample
character (`modules/Preview.lua` over `defaults/Preview_Forever.lua`) and the simulator
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
`modules/` holds the display (the bar widget `NS.Bar`, the title-bar controls `NS.Chrome`, the
blocks `NS.Blocks`, the rows `NS.Rows`, the detached frames, the main window, the secure crafting
overlays, the click map `NS.Interact`, the row tooltip, the trainer popup and `NS.Waypoints`), the
`/sm probe` report, the skills model (`SkillData`), the bonus breakdown (`Bonuses`), the stats
model (`StatData`), the trainer lookups (`Trainers`), the skill helpers (`NS.SkillHelpers`,
`modules/Helpers.lua`), the session log (`NS.SessionLog`), the alt snapshots (`NS.Alts`), the
Journal window, the alerts (`NS.Alerts`, the rank-cap and weapon-gap toasts), the broker feed
(`NS.Template`, `NS.Broker`), test mode's data swap (`NS.Preview`), the simulator (`NS.Sim`,
`NS.SimHost`) and the diagnostics sections;
`settings/` holds the schema,
the slash table and the settings pages.

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
`modules/Journal.lua` as their one owner (`savePoint`, `J.ResetPosition`; `saveSize`, on the resize
grip's release); `char.log` is `modules/SessionLog.lua`'s and `global.characters`
`modules/Alts.lua`'s ([schema.md](schema.md)). `profile.alerts.point`, the alert toasts' drop point,
is the same kind: its one owner is `modules/Alerts.lua`, whose toast descriptor's `setPosition` (a
test-mode drag, or the toast's `ResetPosition`) is its only writer.

`profile.layout.blocks[id].point` (T3.2) is named non-setting state: its one writer is `savePoint`
in `modules/Detached.lua` (a detached frame's `OnDragStop`). `docked`, `order` and `collapsed` are
settings like any other, with schema rows on the Layout page (T5.1), and every actor writes them
through `NS.SetByPath` (architecture-§5): the block header and the detached frame's buttons
(`NS.Blocks:Detach` / `:Dock` / `:SetCollapsed`), the Block order drag list (`:Move`, every changed
`order` inside one bulk bracket, one `LAYOUT_CHANGED`), the window's Expand all and Collapse all
(`:SetAllCollapsed`, every docked block's `collapsed` inside one bulk bracket, one `LAYOUT_CHANGED`)
and `/sm set`. The `docked` and `collapsed`
rows' `set` (`NS.Blocks.StoreDocked` / `StoreCollapsed`) stores the value and waits out combat;
`order` stores plainly, its `onChange` `NS.Blocks.OrderChanged`. The seam logs each write
(debug-logging-§10). `shown`, `scale` and `locked` are plain rows. `skills.hidden` /
`stats.hidden` are sets: one Hide row per catalog skill and per stat (get / set: false clears the
entry), and one undrawn row per whole set (type `set`, default `{}`), which the row menu's Hide
writes for a key with no row of its own (an `other:` skill) and the page's Defaults resets.

`char.pinned`, the skill the broker's `{pinned}` shows, is named non-setting state: its one writer
is the row menu's Pin (`I.MenuRows` in `modules/Interact.lua`), disabled while test mode or a
simulation runs so a sample skill never lands in it.

HUD colors follow the skin (skinning-§6): every `*FromSkin` companion, the palette's
`bars.colors.fromSkin` included, defaults true; while the palette follows, the categories and
bonuses draw the owner tokens `sm.cat.*` and `sm.bonus*` (`core/SkinSetup.lua`). No
`Skin.FollowOnce` step: the addon was born on LibKa0s v1.94.0 with the companions on, so no stored
profile predates them ([schema.md](schema.md)).

No structural registry exists.

## Message Bus

Six messages, each declared once in `core/Bus.lua` as `NS.MSG.<KEY>` through LibKa0s-Bus-1.0's
strict catalog, so a misspelled constant raises. `SkillData` sends `SKILLS_UPDATED` and `SKILL_UP`,
`Bonuses` sends `BONUSES_UPDATED`, `StatData` sends `STATS_UPDATED` and `Blocks` sends
`LAYOUT_CHANGED`; the simulator (`modules/Simulator.lua`) sends `SIM_TICK` after each step.

| Constant | Wire name | Sender | Payload | Consumers |
|---|---|---|---|---|
| `SKILLS_UPDATED` | `Ka0s_SkillMaster_SkillsUpdated` | `modules/SkillData.lua` (T2.1) | the skills model | blocks, broker, alerts, alts, Journal |
| `SKILL_UP` | `Ka0s_SkillMaster_SkillUp` | `modules/SkillData.lua` (T2.1) | key, old, new | blocks (session gains), broker flash, alerts, session log |
| `STATS_UPDATED` | `Ka0s_SkillMaster_StatsUpdated` | `modules/StatData.lua` (T2.3) | the stats model | stat blocks, broker |
| `BONUSES_UPDATED` | `Ka0s_SkillMaster_BonusesUpdated` | `modules/Bonuses.lua` (T2.2) | none | bars, tooltips, broker |
| `LAYOUT_CHANGED` | `Ka0s_SkillMaster_LayoutChanged` | `modules/Blocks.lua` (detach, dock, collapse, collapse all, move); the skin owner's look-change hook; `NS.ApplyLook` (every display row's write, `settings/OptionsSetup.lua`) | none | `modules/Blocks.lua`, which repaints the window and the detached frames; the Journal; the Bars page's preview |
| `SIM_TICK` | `Ka0s_SkillMaster_SimTicked` | `modules/Simulator.lua` (T5.2), after each step | the step's kind | none yet (published for displays under simulation) |

## Slash Commands

`/sm` and `/skillmaster`, one LibKa0s-Slash-1.0 dispatcher over `NS.COMMANDS` (`settings/Slash.lua`):
`help`, `config`, `skin`, `show`, `hide`, `toggle`, `journal`, `lock`, `unlock`, `test`, `sim`, `probe`, `enable`, `disable`,
`list`, `get`, `set`, `reset`, `resetall`, `debug`, `diagnostics`, `perf`, `version`. The bare
command opens the settings panel. While disabled, every verb but the library's live set refuses on
one line. The table with each verb's handler and refusal: [slash-dispatch.md](slash-dispatch.md).

## Event Subscriptions

| Event | Registered by | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | `NS.RegisterRuntime` (`core/SkillMaster.lua`) | `addon:OnEnterCombat` | combat ends test mode and a running simulation (preview-mode) |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` | `modules/SecureOverlay.lua` at load, on its own bus target | disarm every crafting overlay at the combat-start edge; after combat run the queued layout work, then re-sync the overlays | Taint Notes below |
| `SKILL_LINES_CHANGED` | `NS.SkillData:Enable` (from `NS.RegisterRuntime`) | debounced `SkillData:Scan` (0.1 s) | the skill list changed; the echo of the scan's own header toggles is ignored for 0.2 s |
| `CHAT_MSG_SKILL` | `NS.SkillData:Enable` | debounced `SkillData:Scan` | a skill-up line |
| `PLAYER_LEVEL_UP` | `NS.SkillData:Enable` | debounced `SkillData:Scan`, with the new level as the weapon-cap floor (5 x level) | the list can still answer the old cap |
| `UNIT_INVENTORY_CHANGED`, `UNIT_AURA` | `NS.UnitEvents` (`core/UnitEventsSetup.lua`), `RegisterUnitEvent` for `"player"` on its one frame, stood up from `NS.RegisterRuntime` | `addon:OnBonusesUnitChanged`: player only, debounced `Bonuses.Refresh` (0.2 s), which re-reads only the part the event touched (an aura change never re-reads the 19 item tooltips); a 1 s ticker while a temp bonus naming a skill is live | gear, lures and buffs change the breakdown |
| `UNIT_STATS`, `UNIT_ATTACK_POWER`, `UNIT_RANGED_ATTACK_POWER`, `UNIT_RESISTANCES`, `UNIT_DAMAGE` | `NS.UnitEvents`, for `"player"` (recorded by `modules/StatData.lua` at load) | `StatData:Request`: one `STATS_UPDATED` 0.2 s after a burst | the stats model follows gear, buffs and level |
| `PLAYER_EQUIPMENT_CHANGED`, `UPDATE_INVENTORY_DURABILITY`, `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD` | `modules/StatData.lua` at load, on its own bus target (`NS.SafeRegisterEvents`) | `StatData:Request`: player only, one `STATS_UPDATED` 0.2 s after a burst | the stats model follows gear, buffs and level |
| `PLAYER_EQUIPMENT_CHANGED` | `modules/Detached.lua` at load, on its own bus target | `onEquipmentChanged`: re-render the detached weapon block and re-sync the overlays while it is shown | a weapon swap changes the weapon block's equipped-only list |
| `PLAYER_LOGOUT` | `modules/Alts.lua` at load, on its own bus target | `Alts:Snapshot` | the last snapshot of the session |

The bus subscribers on their own targets: `modules/SessionLog.lua` hears `SKILL_UP` (one log entry,
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

The window, the detached frames, the rows and the trainer popup are plain frames, and the key
binding clicks a plain, non-secure button. The settings panel never opens in combat (the library
refuses, options-ui-§2). The one secure surface is the crafting rows' overlays
(`modules/SecureOverlay.lua`, T3.3): one `SecureActionButtonTemplate` per profession whose window
opens by a cast (`type1 = "spell"`, the localized open spell), parented to `UIParent` and laid over
its row at absolute coordinates, so no plain frame is ever a secure frame's parent or anchor and
the rows, the window and the detached frames hide, move and re-lay freely in combat. Every
creation, attribute, anchor, strata, level, show and hide of an overlay happens in `Sync`, which in
combat only marks itself dirty; `PLAYER_REGEN_DISABLED` (lockdown not yet on,
events-frames-taint-§2) disarms every overlay so none stays mouse-live in combat, and
`PLAYER_REGEN_ENABLED` replays the combat queue (`SecureOverlay:AfterCombat`: dock, detach and
collapse wait there, Review Focus 3) and re-syncs. A crafting click in combat reaches the plain row
and prints one line. Shift- and right-clicks pass through the overlay (`PostClick`) to the row's
handlers. The broker feed (`modules/Broker.lua`, T4.1) is never secure: its tooltip rows are
plain buttons parented to the tooltip frame (its own, or GameTooltip with the skin off) that open windows (the main window, the character frame), and
a crafting row opens the main window scrolled to it rather than casting (design §6.5).

## Known Limitations

- An overlay is placed when its row is laid out, shown, scrolled, raised or dropped; while its
  window is being dragged it is taken down (`SecureOverlay:SetMoving`) and laid again at the drop,
  so a crafting row cannot be cast from mid-drag. A raise re-levels it on the host's mouse-down,
  `Raise` and `OnShow` and once more on the next frame; a window of the same strata raised above
  the host (the Journal) does not re-level the host's overlays.
- The gathering and fishing helpers are tooltip lines, switched by `skills.helperTooltip` (Skills >
  General > Gathering and fishing hints), plus the optional one-line hint under the row,
  `skills.helperHint` (Skills > General > Hint under the row, off by default; design §12 item 4).
- No per-element font for the window, block headers, tooltips and toasts: they follow the skin and
  the Skin tab's overrides. Only the bars have their own font block.
- Two columns place each docked block in the shorter column so far, so the block order reads down
  the columns by height rather than strictly left to right.
- The launcher menu has no *Journal* entry yet (design §6.8): `LibKa0s-Launcher-1.0` minor 9 builds
  only its fixed entries (Enabled, Locked, Test mode, Sim mode, Show window, Open settings), takes
  no extra entry from the descriptor, and launcher-§2 forbids a host menu. It needs a library seam;
  until then the Journal opens from `/sm journal` and the main window's title-bar journal mark.
- Broker displays that only call a data object's `OnTooltipShow` show no feed tooltip: the feed
  supplies `OnEnter` / `OnLeave` (its rows are clickable), not `OnTooltipShow`.
- The Alts grid shows five skill columns at a time; Shift + mouse wheel pages through the rest.
- The simulator plays one scenario (a fishing trip: six skill-ups, a lure on and off, a mount up
  and down) on test mode's sample character. Only the reads the simulated character needs go
  through the seam: the skill list, the player's level, class and race, the weapon enchant, the
  main hand's tooltip and the speed. The other stats, the buffs and the zone stay live during a
  session.
- Test mode's lure timer counts from when test mode turned on and is redrawn on the next repaint,
  not every second (the live ticker follows only live temp bonuses).
- On a client that is not enUS, the skill lines are matched on their skill-line ID when the
  client's record carries one; a positional (1.12-shaped) record has none, and its lines and the
  excluded headers are matched on the locale's strings, which only enUS ships today. Such a client
  sorts its lines into Other until the locale files are translated (Documented deviations).
- Every client API the data modules use is assumed until `/sm probe` confirms it
  ([forever-quirks.md](forever-quirks.md), the addon's own section). The kit's Forever API set
  already lists the skill list as `C_SkillInfo.*` rather than the 1.12 globals.

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
| `known-limitations.md` | Not applicable | Known Limitations is under 60 lines |
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

None yet.

Frozen and generated material is out of the map and named once per directory (documentation-§3):
`docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`,
`docs/revendor/<date>-v<tag>/`, `docs/superpowers/` (the v1 design spec, its mockup sources, the plan
and its status ledger) and `docs/investigations/`. Only `docs/superpowers/` and
`docs/automated-tests/<run>/` exist today.

## Documented deviations

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| localization-§4 | Three things still match on a localized name, through the locale keys (`NS.L`): a skill line whose record carries no skill-line ID (the 1.12 positional list), the three excluded Skills-tab headers (Class Skills, Armor Proficiencies, Languages) and the crafting spell when `NS.Compat.SpellName` answers nothing for its ID. Every record that carries an ID is matched on it first (`NS.SkillLineIDToKey`), and the crafting cast uses the name its spell ID resolves to. | The client hands no ID for a 1.12-shaped line or for a header, so the locale key is the only route; enUS ships the strings, the other locale files are stubs, so a non-enUS client on the positional shape sorts its lines into Other until they are translated (Known Limitations). | 2026-11-10, M6 review F-001 | `/sm probe` shows whether Forever's struct carries a skill-line ID (then only the headers remain), or the locale files gain the skill-line and header strings |

### Files over the 1500-line cap

Nothing is over the cap today.
