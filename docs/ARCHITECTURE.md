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

v0.1.0 is the born-compliant skeleton: the Ace3 substrate, the LibKa0s setup files (one descriptor
and one degradation stub each), the main window with its test mode and key binding, skins, the
settings panel, the launcher and the diagnostics dump. The data modules and the bars arrive in the
plan's milestones 2 to 5.

Pure data modules (`SkillData`, `Bonuses`, `StatData`, `Trainers`, `Helpers`, `SessionLog`, `Alts`)
will read the client API and publish bus messages; display modules consume only messages and
models, so test mode, the simulator and the headless harness drive them the same way
([data-flow.md](data-flow.md)).

## Module Map

Every file, its responsibility and why the TOC orders it as it does: [module-map.md](module-map.md).
In short: `core/` holds the identity, the constants, the one setup file per LibKa0s major (Media,
Env, Core, Skin, Bus, Pool, Widgets, Lifecycle, Perf, DebugLog, Launcher), the AceAddon entry
(`core/SkillMaster.lua`) and the store (`core/Database.lua`); `defaults/Profile.lua` is the defaults
tree; `modules/` holds the main window and the diagnostics sections; `settings/` holds the schema,
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
writes its own `minimapPos` into `global.minimap`, the table the Minimap button row shares.

No structural registry exists yet.

## Message Bus

Six messages, each declared once in `core/Bus.lua` as `NS.MSG.<KEY>` through LibKa0s-Bus-1.0's
strict catalog, so a misspelled constant raises. None is sent yet; the senders arrive with the data
modules.

| Constant | Wire name | Sender | Payload | Consumers |
|---|---|---|---|---|
| `SKILLS_UPDATED` | `Ka0s_SkillMaster_SkillsUpdated` | `modules/SkillData.lua` (T2.1) | the skills model | blocks, broker, alerts, alts |
| `SKILL_UP` | `Ka0s_SkillMaster_SkillUp` | `modules/SkillData.lua` (T2.1) | key, old, new | broker flash, alerts, session log |
| `STATS_UPDATED` | `Ka0s_SkillMaster_StatsUpdated` | `modules/StatData.lua` (T2.3) | the stats model | stat blocks, broker |
| `BONUSES_UPDATED` | `Ka0s_SkillMaster_BonusesUpdated` | `modules/Bonuses.lua` (T2.2) | none | bars, tooltips |
| `LAYOUT_CHANGED` | `Ka0s_SkillMaster_LayoutChanged` | `modules/Blocks.lua` (T3.2); the skin owner's look-change hook until then | none | the window and detached frames |
| `SIM_TICK` | `Ka0s_SkillMaster_SimTicked` | the simulator (T5.2) | the step's name | displays under simulation |

## Slash Commands

`/skm` and `/skillmaster`, one LibKa0s-Slash-1.0 dispatcher over `NS.COMMANDS` (`settings/Slash.lua`):
`help`, `config`, `skin`, `show`, `hide`, `toggle`, `lock`, `unlock`, `test`, `enable`, `disable`,
`list`, `get`, `set`, `reset`, `resetall`, `debug`, `diagnostics`, `perf`, `version`. The bare
command opens the settings panel. While disabled, every verb but the library's live set refuses on
one line. The table with each verb's handler and refusal: [slash-dispatch.md](slash-dispatch.md).

## Event Subscriptions

| Event | Registered by | Handler | Why |
|---|---|---|---|
| `PLAYER_REGEN_DISABLED` | `NS.RegisterRuntime` (`core/SkillMaster.lua`) | `addon:OnEnterCombat` | combat ends test mode (preview-mode) |

Every registration goes through `NS.SafeRegisterEvent` (events-frames-taint-§1); a refused name
lands in `NS.rejectedEvents`, which the `[Init]` summary and the diagnostics report print. The stand-
down unregisters every event and cancels every timer; the stand-up re-registers from current state.

## Taint Notes

Nothing in v0.1.0 touches a protected function or a secure frame. The window is a plain frame and
the key binding clicks a plain, non-secure button. The settings panel never opens in combat (the
library refuses, options-ui-§2). The crafting-row secure overlays (T3.3) will be created out of
combat and re-anchored only out of combat, queued on `PLAYER_REGEN_ENABLED`.

## Known Limitations

- The window has no content yet: the skill and stat bars arrive with milestones 2 and 3.
- Sim mode (the launcher entry and the Master-controls checkbox) arrives with the simulator in T5.2.
- Every client API the data modules will use is assumed from the 1.12 shape until `/skm probe`
  confirms it ([midnight-quirks.md](midnight-quirks.md), the addon's own section).

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
| `slash-dispatch.md` | Present | 20 commands in `NS.COMMANDS` |
| `midnight-quirks.md` | Present | Always (client-quirks-§1); holds the vendored catalog and this addon's assumed-API table |
| `debug.md` | Present | The diagnostics dump is a debug surface beyond the default console (debug-logging-§14) |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `compat-layer.md` | Not applicable | No `core/Compat.lua`: the addon makes no deprecated or version-variant client call outside LibKa0s's majors (compat's applicability condition) |
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
