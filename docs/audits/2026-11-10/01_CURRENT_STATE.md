# 01 — Current state: Ka0s Skill Master

First standards audit of this repo. Deviation prefix assigned: **`SM-`**.

## Run metadata

| Item | Value |
|---|---|
| Repo | `SkillMaster`, branch `feat/2026-11-10-skill-master-v1`, HEAD `5c650e8`, clean tree (`git status --porcelain` empty) |
| Run date | 2026-11-10 |
| Kind | **Addon** (`dev-copilot-profile`: `profile=wow`, `kind=addon`, `reason=toc:## Interface`; confirmed: a root `SkillMaster.toc`, and `standards/ADDONS.md:35` lists the repo in the addon table). The whole addon rule set and the whole `AUDIT.md` playbook apply. |
| Standard | **v2.105.0 (2026-11-10)**, the `standards/STANDARDS.md` header |
| Standard source | **The local worktree** `#Worktrees/WowAddonStandards-forever-only`, branch `feat/2026-11-10-single-client-forever`, at `3d6855f`, clean (`git status --porcelain` empty). This was the dispatcher's instruction: v2.105.0, which adds the `Forever` Clients value and clients-§9, exists only on that unmerged branch. No network copy was fetched, so no comparison with published `master` was made. Published `master` does not yet carry the rules this addon is built to. |
| Playbook | `AUDIT.md` from the same worktree, all 1611 lines read |
| Sections read | Every file the `STANDARDS.md` Sections list links (31 files under `standards/standards/`). The sections that bind the findings were re-read for this run: clients, toc-file, documentation, slash-commands, architecture, skinning, performance, lint, packaging, line-endings, localization, debug-logging and library-stack. |
| Roster row | `ADDONS.md:35`: Ka0s Skill Master, Clients **`Forever`**, launcher `Enabled · Locked · Test mode · Sim mode · Show window (the skills window)`, preview `test`, Sim mode checkbox `next to Test mode` |

## Snapshot, section by section

### Layout (layout)
- The modular tree: `core/`, `defaults/`, `locales/`, `modules/`, `settings/`, `media/logos/`, `tests/`, `libs/`, plus `Bindings.xml` at the root.
- Authored-Lua census: 120 tracked files (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`). The largest is `modules/Journal.lua` at 711 lines. Nothing is in the 1000–1500 band or over the cap.
- The hub carries the `Files over the 1500-line cap` heading with "Nothing is over the cap today." (`docs/ARCHITECTURE.md:262-264`). The kit gate is wired by path (`tests/run.lua:142`).
- No generator to place: `git ls-files '*.py' '*.sh'` outside `libs/` and `tests/_kit/` is empty.
- `media/` holds only `logos/`. `skillmaster.logo.128.tga` is TGA type 2, 128×128, 32 bpp. `skillmaster.logo.tga` (300×300) is the landing logo.

### TOC (toc-file, clients)
- `SkillMaster.toc:1-3`: `## Interface: 16001`, `## AllowLoadGameType: camelot`, `## ExcludeLoadGameType: standard`. This is the exact clients-§9 / toc-file-§3 Forever block.
- The field order matches toc-file-§1. `## IconTexture` points at the addon's own 128 px logo (`:8`). `X-Curse-Project-ID` is absent, with the not-published comment in its place (`:15`), which is compliant.
- The `#` sections run in the mandated order. LibKa0s is listed once as `libs\LibKa0s\LibKa0s.xml` (`:30`). Load-bearing lines are annotated. Four `# Core` lines carry no label: `core\State.lua`, `core\EnvSetup.lua`, `core\PoolSetup.lua` and `core\Database.lua` (SM-09).
- The file ends in one CRLF.

### Clients (clients, v2.105.0)
- Roster value `Forever`. The TOC matches it.
- No Retail branch, no client read and no `clients =` declaration in `core modules settings defaults locales`. The grep's only hit is `modules/Probe.lua:144` `GetBuildInfo()`, which reports the build in the probe's JSON and decides nothing.
- Every seed file is the Forever list alone (`defaults/*_Forever.lua`).
- The suite is pinned to Forever: `tests/client_pin.lua`, dofiled at `tests/run.lua:7`. Both a bare run and `KA0S_KIT_CLIENT=forever` run 373/1/374.
- The smoke file covers Forever plus the not-listed-on-Retail check (`docs/smoke-tests.md:27`, SM-LOAD-2).
- The reason is recorded in both places: `README.md:8` ("WoW Forever only." then the reason) and `docs/ARCHITECTURE.md:14-17`, `:56-70` (the per-client table in the clients-§4 single-client form).

### Libraries (library-stack)
- Ace3, LibSharedMedia, LibDataBroker and LibDBIcon are vendored, with no `externals:`.
- The provenance line `Bundles [LibKa0s](…) v1.94.0 (MIT).` is in `CLAUDE.md:40`. The `LibKa0s icons:` declaration sits on the next line (`:41`, 18 icons). README carries neither the line nor a library inventory.
- `diff -r` against LibKa0s `v1.94.0` (archived from the sibling `../LibKa0s` at the tag) is empty outside `media/icons/`, for both `LibKa0s/` and `testkit/` ↔ `tests/_kit/`. The icon folder holds exactly the 18 declared icons plus `LICENSE-open-iconic.txt`.
- The kit is revision 53 (`tests/_kit/framework.lua:20`).

### Patterns: namespace, AceAddon, bus, schema (architecture)
- AceAddon: `core/SkillMaster.lua:8`. The printer is reclaimed at `:10`.
- Bus: six messages declared once through `Bus.Catalog` (`core/Bus.lua:46-59`). Every tail is PascalCase. No literal appears at a call site outside `core/Bus.lua`, apart from the suite's `tests/test_bus.lua:7-12` pins.
- Schema: one seam, `NS.SetByPath = S.Set` (`settings/Schema.lua:212`). **Several schema-row paths are written around it**: block `docked` / `collapsed` / `order` from header clicks, the dock buttons and the drag list, and `skills.hidden.<key>` from the row menu (SM-01).
- Named non-setting state is named in the hub (`docs/ARCHITECTURE.md:79-100`): window, journal, alert and detached-block points, journal size, `char.log`, `global.characters` and `char.pinned`.

### SavedVariables (savedvariables)
- `SkillMasterDB` and `SkillMasterPerfDB`. `global.schemaVersion = 0` in defaults (`defaults/Profile.lua:148`).
- The runner is `NS.RunMigrations` (`core/Database.lua:18-32`). `NS.SCHEMA_VERSION = 1`, and its one step is a no-op.

### Settings panel (options-ui, skinning)
- `LibKa0s-Options-1.0` descriptor at `settings/OptionsSetup.lua:74-110`. The landing page is the library's (`buildMain` → `BuildLandingPage`, `:103`).
- General page: Master controls composed by `H.MasterControls` (`settings/General.lua:43-63`), with `omit = { visibility = true }`. The window opens only when the player opens it. After it come the Skin tab (`H.AppearanceTab`) and the Keybindings tab (`H.KeybindingsTab`), last (`:146-149`). Defaults tooltip: `H.ResetAllTooltip(H.KEYBINDS_UNCHANGED)` (`:155`).
- The minimap row is `global.minimap.shown`, inverted onto `minimap.hide` (`core/Constants.lua:23`, `settings/General.lua:80-87`). The reset veto is pinned by `tests/test_schema.lua:43-51`.
- Skin owner registered at file load (`core/SkinSetup.lua:215`), with `spec.preview` passed (`:115`). The skin-switch gate's surface list is `tests/run.lua:60-94`: six surfaces, and three painted surfaces are missing (SM-03).
- No hand-built keybinding widget and no `LSM30_*` row, and no vendored SharedMediaWidgets.
- Display glyphs (`·`, `×`, `—`) are all in localization-§7's safe set.

### Slash (slash-commands)
- 23 rows in `NS.COMMANDS` (`settings/Slash.lua:31-68`). `skin` follows `config`.
- `enable` and `disable` write `enabled` through `NS.SetByPath` (`:47-49`, via `setAndEcho`). `lock` and `unlock` (the slash-commands-§8 MAY) write `locked` the same way (`:40-41`).
- Dispatcher at `:118-138`: `isEnabled` reads the `disabled` hold, and the `debug` sink is passed. The host passes no `liveVerbs`, so the library default applies.
- Stub branch at `:70-116`.

### Disabled state (slash-commands-§7)
- One latch, two holds: `core/LifecycleSetup.lua:64-73` (`LibKa0s-Lifecycle-1.0`). The perf harness is handed the same latch (`core/PerfSetup.lua:33`).
- Teardown at `core/SkillMaster.lua:66-83`: frames hidden, `UnregisterAllEvents`, `CancelAllTimers`, and every tracked bus target stood down (`NS.BusStandDown`, `core/Bus.lua:38`).
- Every module event and message registration sits on a tracked bus target (Alerts, Alts, Blocks, Broker, Detached, Journal, SecureOverlay, SessionLog, StatData) or on the addon object. The disabled suite passes: R_on is non-empty, and the set is empty after disable.
- The suite is `tests/test_disabled.lua`, listed at `tests/run.lua:137`. It is partial against the ten steps (SM-02).

### Launcher (launcher)
- One object through `LibKa0s-Launcher-1.0` (`core/LauncherSetup.lua:45-69`). The label is `NS.Constants.BRAND` ("Ka0s Skill Master").
- The toggles call the verb handlers (`runVerb`). `isLocked`, `isTestMode`, `isSimMode` and `isWindowShown` are passed, matching the roster column.
- Bindings: `Bindings.xml` carries two `CLICK` lines under `BINDING_HEADER_SKILLMASTER`, the Show window line first. They are not in the TOC and not in `.pkgmeta`. The buttons are plain `AnyDown` buttons (`modules/MainWindow.lua:544-559`).

### Debug (debug-logging)
- `core/DebugLogSetup.lua:77+`: the descriptor passes `addonName`. The stub covers every member, `RunDiagnostics` and `DebugVerb` included (`:25-69`).
- `diagnostics` is one `COMMANDS` row (`settings/Slash.lua:63-64`), and `debug` routes through `DebugVerb` first (`:58-62`).
- `debug` sinks are passed to Slash, Options, Launcher and Lifecycle.

### Tests and lint (testing, lint)
- `luacheck .` (bounded): 0 warnings / 0 errors in 120 files.
- `.luacheckrc` excludes only the vendored and frozen trees plus `tests/_kit/`. The harness global sits in `files["tests/"]`.
- Suite: 373 passed, 0 failed, 1 skipped, 374 total. The skip is the diagnostics opt-out case, which does not apply here.
- `docs/test-cases.md` is byte-identical to a fresh `--list`, and the README badge reads 373/373, matching the Total row.
- Kit gates declared: `test_eol`, `test_layout_cap`, `test_lizard_sighted`, `test_skin_values`, `test_skin_switch` and `test_client_globals` (`tests/run.lua:140-146`), plus `test_vendor_sync` and `test_disabled`.

### Performance and complexity (performance, automated-tests)
- `LibKa0s-Perf-1.0` instance with one bucket, `windowRender` (`core/PerfSetup.lua:21-41`), and one Shape A bracket (`modules/MainWindow.lua:402`, `:425`) (SM-06).
- Complexity suite (bounded, `--no-bundle`): pass, 0 warnings, 14078 NLOC / 2043 functions, max CCN 15. The runner says its newest bundle `20261110-025504` measured `9a66b14`, **42 commits behind HEAD** (SM-10).
- The watch list is empty, so no Accepted dispositions to age.

### Packaging (packaging)
- `.pkgmeta` checks (a), (b) and (c) print nothing. Every root dot-entry is ignored, and there is no false claim.

### Line endings (line-endings)
- `.gitattributes` pins `* text=auto eol=crlf` (`:26`) and carries both carve-outs (`:36-37`) and 20 `binary` lines.
- The body is byte-identical (CR stripped) to line-endings-§5's client-bound canonical body (84 lines). There is no appendix.
- Working-tree agreement: **0** tracked files disagree with the pin. The gate `tests/_kit/test_eol.lua` is wired.

### Root doc set (documentation-§1/§2/§7)
- README: H1, then four badges (no CurseForge badge, since the addon is unpublished). The standard badge is the bare image. The `[wow]` badge reads `Forever_1.60.1`.
- No logo image and no numbered list.
- The sections run Usage (which names `/skm skin`, `:28`), How the bars work, FAQ, Troubleshooting (with the Reporting-a-bug row), Reporting a bug (verbatim), Issues, Version History (`- ` prefixed) and Credits (Open Iconic, SHOULD met).
- No `## Screenshots` (SM-07). No font text.
- `CLAUDE.md`: the stub shape, the compliance section, and the provenance and icons lines.
- `DEPENDENCIES.md`: present, WSL2/Ubuntu.

### `docs/` (documentation-§3)
- Tier 1: all six docs present under their canonical names.
- Tier 2, evaluated against the code:
  - `slash-dispatch.md` is present (23 commands).
  - `midnight-quirks.md` is present. Its vendored block, stamped v2.105.0, is byte-identical to `client-quirks.md` once CRs are stripped.
  - `compat-layer.md` is present. The family grep counts **9** shims, but the map says "three" (SM-04).
  - `message-bus.md` is *Not applicable*: 6 messages.
  - `profiles.md` and `debug.md` are present.
  - `perf-analysis/README.md` is present.
  - `known-limitations.md` and `taint.md` are *Not applicable*: Known Limitations runs 33 lines and Taint Notes 20.
- `## Documentation map`: four tables. Every `.md` under `docs/` outside the frozen stores is registered once, with no dangling row.
- No non-canonical names. No retired docs (`file-index.md`, `conventions.md`, `complexity.md`, `docs/perf-runs/`). No `docs/pending/LEDGER.md`.
- Hub: 264 lines, every mandated section present and under 60 lines. The Event Subscriptions table omits one registration (SM-05).
- `docs/superpowers/` holds one spec and two plans whose topics do not pair (SM-08).

### Recorded-deviation register
- `docs/ARCHITECTURE.md:258-260`: `## Documented deviations` reads "None."
- Issue store: `gh issue list --state all --limit 200 --json …` returns `[]`. No issues, so no `state:will-not-do` issue lacks a row, and no register row exists whose rule could have changed.
- `CLAUDE.md` and `docs/scope.md` carry no accepted-deviation note.
- No `docs/audits/`, `docs/reviews/` or `docs/revendor/` store exists before this run. The only re-vendor tag is the birth tag v1.94.0 (commits `7c58239`, `bfbefdc`), so no bundle is owed yet.

### Shared subsystems: descriptor and stub per module
These files carry the library wiring, so they are what the run checked: `CoreSetup`, `DebugLogSetup`, `OptionsSetup` (load-completing), `Slash`, `LauncherSetup`, `LifecycleSetup`, `PerfSetup`, `Bus`, `SkinSetup`, `MediaSetup`, `PoolSetup`, `WidgetsSetup`, `EnvSetup` and `SimSetup`. Each resolves its major with `LibStub(major, true)` and degrades.

Surface parity is gated for Core, DebugLog, Options, Slash, Launcher, Lifecycle, Bus, Schema and Toast (`tests/test_surface_parity.lua`). The Pool, Widgets, Perf and Sim stubs were checked by hand against the members the addon reaches:
- Pool: `New`, `Acquire` and `ReleaseAll`.
- Widgets: `TestStrip`, `CopyWindow`, `ContextMenu` and `CloseMenu`. `TEST_STRIP` is nil-guarded at `modules/MainWindow.lua:291`.
- Perf: `on`, `Note` and `OnCommand`.
- Sim: the seam stub.

All are covered. No hand-rolled console, dispatcher, widget maker or harness exists (#47 clean).
