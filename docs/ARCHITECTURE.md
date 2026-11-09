# Architecture — Ka0s Skill Master

The engineer brief and the hub of the doc set (documentation-§3). Topic detail lives in the pages the
Documentation map lists; this file keeps a summary and one link per topic.

## Overview

Ka0s Skill Master shows a vanilla-era character's weapon skills, professions, Defense, Lockpicking,
Riding and character stats as skinnable data bars, with bonuses, trainer directions, broker feeds,
alerts, a session log, an alt overview and gathering helpers. The design is
`docs/superpowers/specs/2026-11-10-skill-master-design.md`; the build plan and its status ledger are
under `docs/superpowers/plans/`.

**Clients: WoW Forever only, by owner decision (2026-11-10, clients-§2, clients-§9).** Weapon skills,
Defense, level-tied skill caps and weapon-master trainers do not exist on Retail, and Retail
professions are a different system, so the addon's core has nothing to show there. The TOC carries
`## Interface: 16001` with `## AllowLoadGameType: camelot` and `## ExcludeLoadGameType: standard`.

v0.1.0 began as the born-compliant skeleton (the Ace3 substrate, the LibKa0s setup files, one
descriptor and one degradation stub each, the window, skins, the settings panel, the launcher and
the diagnostics dump). Milestone 2 added the data layer, milestone 3 the display (the bar widget,
the blocks and rows, the detached frames, the crafting overlays, the row tooltip, the trainer popup
and waypoints) and milestone 4 the broker feeds, the alerts, the session log, the alt overview and
the Journal. The settings pages for the new state and test mode's sample data arrive in milestone 5.

Pure data modules (`SkillData`, `Bonuses`, `StatData`, `Trainers`, `Helpers`, `SessionLog`, `Alts`)
will read the client API and publish bus messages; display modules consume only messages and
models, so test mode, the simulator and the headless harness drive them the same way
([data-flow.md](data-flow.md)).

## Module Map

Every file, its responsibility and why the TOC orders it as it does: [module-map.md](module-map.md).
In short: `core/` holds the identity, the constants, the one setup file per LibKa0s major (Media,
Env, Core, Skin, Bus, Pool, Widgets, Lifecycle, Perf, DebugLog, Launcher), the AceAddon entry
(`core/SkillMaster.lua`) and the store (`core/Database.lua`); `core/Compat.lua` is the compat family (the skill-list shims);
`defaults/Profile.lua` is the defaults tree and `defaults/*_Forever.lua` the data tables (the skill
catalog, the class weapon lists, trainers, ranks, gathering, fishing, racials, stat definitions);
`modules/` holds the display (the bar widget `NS.Bar`, the title-bar controls `NS.Chrome`, the
blocks `NS.Blocks`, the rows `NS.Rows`, the detached frames, the main window, the secure crafting
overlays, the click map `NS.Interact`, the row tooltip, the trainer popup and `NS.Waypoints`), the
`/skm probe` report, the skills model (`SkillData`), the bonus breakdown (`Bonuses`), the stats
model (`StatData`), the trainer lookups (`Trainers`), the skill helpers (`NS.SkillHelpers`,
`modules/Helpers.lua`), the session log (`NS.SessionLog`), the alt snapshots (`NS.Alts`), the
Journal window, the alerts (`NS.Alerts`, the rank-cap and weapon-gap toasts), the broker feeds
(`NS.Template`, `NS.Broker`) and the diagnostics sections;
`settings/` holds the schema,
the slash table and the settings pages.

### Per-client features

All features serve WoW Forever; the addon is Forever-only by owner decision. Its core (weapon
skills, Defense, level-tied caps, weapon masters) does not exist on Retail (clients-§4, clients-§9).
No feature carries a `clients` declaration.

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
`modules/Blocks.lua`'s and have schema rows on the Layout page (T5.1) that write through it:
`NS.Blocks:Detach` / `:Dock` / `:SetCollapsed` / `:SetOrder`, and `:Move` from the Block order drag
list, so a row, a header click and `/skm set` take one path. `shown`, `scale` and `locked` are plain
rows. `skills.hidden` / `stats.hidden` are sets written by the row menu (T3.3) and by the Skills and
Stats pages' Hide rows (get / set: false clears the entry).

No structural registry exists yet.

## Message Bus

Six messages, each declared once in `core/Bus.lua` as `NS.MSG.<KEY>` through LibKa0s-Bus-1.0's
strict catalog, so a misspelled constant raises. `SkillData` sends `SKILLS_UPDATED` and `SKILL_UP`,
`Bonuses` sends `BONUSES_UPDATED`, `StatData` sends `STATS_UPDATED` and `Blocks` sends
`LAYOUT_CHANGED`; `SIM_TICK`'s sender arrives with the simulator (T5.2).

| Constant | Wire name | Sender | Payload | Consumers |
|---|---|---|---|---|
| `SKILLS_UPDATED` | `Ka0s_SkillMaster_SkillsUpdated` | `modules/SkillData.lua` (T2.1) | the skills model | blocks, broker, alerts, alts, Journal |
| `SKILL_UP` | `Ka0s_SkillMaster_SkillUp` | `modules/SkillData.lua` (T2.1) | key, old, new | blocks (session gains), broker flash, alerts, session log |
| `STATS_UPDATED` | `Ka0s_SkillMaster_StatsUpdated` | `modules/StatData.lua` (T2.3) | the stats model | stat blocks, broker |
| `BONUSES_UPDATED` | `Ka0s_SkillMaster_BonusesUpdated` | `modules/Bonuses.lua` (T2.2) | none | bars, tooltips, broker |
| `LAYOUT_CHANGED` | `Ka0s_SkillMaster_LayoutChanged` | `modules/Blocks.lua` (detach, dock, collapse, move); the skin owner's look-change hook; `NS.ApplyLook` (every display row's write, `settings/OptionsSetup.lua`) | none | `modules/Blocks.lua`, which repaints the window and the detached frames; the Journal; the Bars page's preview |
| `SIM_TICK` | `Ka0s_SkillMaster_SimTicked` | the simulator (T5.2) | the step's name | displays under simulation |

## Slash Commands

`/skm` and `/skillmaster`, one LibKa0s-Slash-1.0 dispatcher over `NS.COMMANDS` (`settings/Slash.lua`):
`help`, `config`, `skin`, `show`, `hide`, `toggle`, `journal`, `lock`, `unlock`, `test`, `probe`, `enable`, `disable`,
`list`, `get`, `set`, `reset`, `resetall`, `debug`, `diagnostics`, `perf`, `version`. The bare
command opens the settings panel. While disabled, every verb but the library's live set refuses on
one line. The table with each verb's handler and refusal: [slash-dispatch.md](slash-dispatch.md).

## Event Subscriptions

| Event | Registered by | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | `NS.RegisterRuntime` (`core/SkillMaster.lua`) | `addon:OnEnterCombat` | combat ends test mode (preview-mode) |
| `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` | `modules/SecureOverlay.lua` at load, on its own bus target | disarm every crafting overlay at the combat-start edge; after combat run the queued layout work, then re-sync the overlays | Taint Notes below |
| `SKILL_LINES_CHANGED` | `NS.SkillData:Enable` (from `NS.RegisterRuntime`) | debounced `SkillData:Scan` (0.1 s) | the skill list changed; the echo of the scan's own header toggles is ignored for 0.2 s |
| `CHAT_MSG_SKILL` | `NS.SkillData:Enable` | debounced `SkillData:Scan` | a skill-up line |
| `PLAYER_LEVEL_UP` | `NS.SkillData:Enable` | debounced `SkillData:Scan`, with the new level as the weapon-cap floor (5 x level) | the list can still answer the old cap |
| `UNIT_INVENTORY_CHANGED`, `UNIT_AURA` | `NS.Bonuses.RegisterRuntime` (from `NS.RegisterRuntime`) | `addon:OnBonusesUnitChanged`: player only, debounced `Bonuses.Refresh` (0.2 s), which re-reads only the part the event touched (an aura change never re-reads the 19 item tooltips); a 1 s ticker while a temp bonus naming a skill is live | gear, lures and buffs change the breakdown |
| `UNIT_STATS`, `UNIT_ATTACK_POWER`, `UNIT_RANGED_ATTACK_POWER`, `UNIT_RESISTANCES`, `UNIT_DAMAGE`, `PLAYER_EQUIPMENT_CHANGED`, `UPDATE_INVENTORY_DURABILITY`, `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD` | `modules/StatData.lua` at load, on its own bus target (`NS.SafeRegisterEvents`) | `StatData:Request`: player only, one `STATS_UPDATED` 0.2 s after a burst | the stats model follows gear, buffs and level |
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
handlers. The broker feeds (`modules/Broker.lua`, T4.1) are never secure: their tooltip rows are
plain buttons parented to GameTooltip that open windows (the main window, the character frame), and
a crafting row opens the main window scrolled to it rather than casting (design §6.5).

## Known Limitations

- The Layout, Bars, Skills and Stats settings pages arrive in T5.1: until then the block layout,
  the bar look and the hidden rows follow their defaults and the row controls (collapse, detach,
  dock, the row menu's Hide).
- An overlay is placed when its row is laid out, shown, scrolled, raised or dropped; while its
  window is being dragged it is taken down (`SecureOverlay:SetMoving`) and laid again at the drop,
  so a crafting row cannot be cast from mid-drag. A raise re-levels it on the host's mouse-down,
  `Raise` and `OnShow` and once more on the next frame; a window of the same strata raised above
  the host (the Journal) does not re-level the host's overlays.
- The gathering and fishing helpers are tooltip lines, switched by `skills.helperTooltip` (Skills >
  General > Gathering and fishing hints), plus the optional one-line hint under the row,
  `skills.helperHint` (Skills > General > Hint under the row, off by default; design §12 item 4).
- Not on the Bars page: a fill direction (the mockup's Left to right) and a per-element font for
  the window, block headers, tooltips and toasts, which follow the skin and the Skin tab. The
  Layout page has no column count and no frame strata row (design §6.6).
- Test mode marks the window but still shows the live models: the sample character (the preview
  fixture) arrives in T5.2 through `NS.Blocks.source`.
- The launcher menu has no *Journal* entry yet (design §6.8): `LibKa0s-Launcher-1.0` minor 9 builds
  only its fixed entries (Enabled, Locked, Test mode, Sim mode, Show window, Open settings), takes
  no extra entry from the descriptor, and launcher-§2 forbids a host menu. It needs a library seam;
  until then the Journal opens from `/skm journal` and the main window's title-bar journal mark.
- Broker displays that only call a data object's `OnTooltipShow` show no feed tooltip: the feeds
  supply `OnEnter` / `OnLeave` (their rows are clickable), not `OnTooltipShow`.
- The Alts grid shows five skill columns at a time; Shift + mouse wheel pages through the rest.
- Sim mode (the launcher entry and the Master-controls checkbox) arrives with the simulator in T5.2.
- Every client API the data modules will use is assumed until `/skm probe` confirms it
  ([midnight-quirks.md](midnight-quirks.md), the addon's own section). The kit's Forever API set
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
| `slash-dispatch.md` | Present | 22 commands in `NS.COMMANDS` |
| `midnight-quirks.md` | Present | Always (client-quirks-§1); holds the vendored catalog and this addon's assumed-API table |
| `debug.md` | Present | The diagnostics dump is a debug surface beyond the default console (debug-logging-§14) |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `compat-layer.md` | Present | `core/Compat.lua` publishes three addon-specific shims (the skill list, T2.1) |
| `message-bus.md` | Not applicable | Six messages, not more than ten |
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

None.

### Files over the 1500-line cap

Nothing is over the cap today.
