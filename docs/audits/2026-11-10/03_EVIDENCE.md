# 03 — Evidence: Ka0s Skill Master

Every citation below was re-read at HEAD `5c650e8` before it was written, and the cited text is quoted beside it. Commands ran from the repo root through `~/.claude/dev-copilot/bin/ka0s-bounded` wherever the plugin requires it. Each count states its scope.

## E0 — Standard source

```
$ git -C "../#Worktrees/WowAddonStandards-forever-only" rev-parse HEAD; … branch --show-current; … status --porcelain | wc -l
3d6855f1cd266a84d40e026e15870395f8a047f3
feat/2026-11-10-single-client-forever
0
$ head -1 standards/STANDARDS.md
# Ka0s WoW Addon Standard (v2.105.0, 2026-11-10)
```
The rules were read from that worktree on the dispatcher's instruction. No network fetch was made.

## E1 — Mechanical runs

```
$ ka0s-bounded luacheck .
Total: 0 warnings / 0 errors in 120 files          exit=0
$ ka0s-bounded lua tests/run.lua
373 passed, 0 failed, 1 skipped, 374 total         exit=0
$ KA0S_KIT_CLIENT=forever ka0s-bounded lua tests/run.lua
373 passed, 0 failed, 1 skipped, 374 total         exit=0
  SKIP  diagnostics contract: an addon that opts out lands the report and leaves logging off — this addon keeps the default …
$ ka0s-bounded lua tests/run.lua --list > list.md; diff list.md docs/test-cases.md   → identical
$ ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
  complexity  pass  — 0 warnings (fun rate 0.00), 14078 NLOC / 2043 funcs, avg NLOC 5.8, avg CCN 2.4 (max 15), …
  record:  newest bundle 20261110-025504 measured 9a66b14, 42 commit(s) behind HEAD …     exit=0
```
- Lint scope: `.luacheckrc:6` reads `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }`, and `.luacheckrc:56-58` reads `files["tests/"] = { globals = { "_G.SKM_TEST" }, }`.
- Kit revision: `tests/_kit/framework.lua:20` `Kit.VERSION = 53`. The sighted gate is declared at `tests/run.lua:143` `{ name = "test_lizard_sighted", dir = "tests/_kit/" }`.
- Bundle `docs/automated-tests/20261110-025504/manifest.json`: `release "0.1.0"`, `git.sha 9a66b145…`, `suites.complexity` `{maxCcn 10, nloc 2363, functions 449, blindFiles 0, crashedFiles 0}`. Its `ANALYSIS.md:61` is `## Preview and simulation data`, and `:63` is `- **Answer:** Current` (**SM-10**).

## E2 — Vendored LibKa0s (tag from `CLAUDE.md:40` "Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.94.0 (MIT).")

```
$ git -C ../LibKa0s archive v1.94.0 LibKa0s testkit | tar -x -C lk194
$ diff -r lk194/LibKa0s libs/LibKa0s     → 208 lines, every one "Only in lk194/LibKa0s/media/icons…"
$ diff -r lk194/testkit tests/_kit       → empty (exit 0)
$ find libs/LibKa0s/media/icons -type f  → LICENSE-open-iconic.txt + the 18 icons CLAUDE.md:41 declares
```
- The sibling `../LibKa0s` sits on another branch (`describe` = v1.95.0). The diff was taken at the tag, not at the sibling's `HEAD`.
- `grep 'Bundles \[LibKa0s\]' README.md` returns nothing. No `## Libraries…` heading exists in README.

## E3 — Line endings and packaging (whole tracked set, no exclusions)

```
$ (AUDIT check (e), the NUL-separated byte counter)   → 0
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes   → 26:* text=auto eol=crlf
$ grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes        → 36:*.sh text eol=lf / 37:*.py text eol=lf
$ grep -c ' binary$' .gitattributes                          → 20
$ diff <(head -84 .gitattributes | tr -d '\r') <line-endings-§5 client body>   → identical
$ (.pkgmeta checks a/b/c)                                    → no output
```
`tests/_kit/test_eol.lua` is wired at `tests/run.lua:140`.

## E4 — Clients and TOC (clients-§9, toc-file)

- `SkillMaster.toc:1` `## Interface: 16001`, `:2` `## AllowLoadGameType: camelot`, `:3` `## ExcludeLoadGameType: standard`, `:8` `## IconTexture: Interface\AddOns\SkillMaster\media\logos\skillmaster.logo.128.tga`, `:15` `# X-Curse-Project-ID: not published on CurseForge yet`.
- TGA header: `skillmaster.logo.128.tga type 2 w 128 h 128 bpp 32`.
- `grep -rnE 'WOW_PROJECT_|GetBuildInfo|IsRetail|ClientKey|IsForever|ForClient|clients *=' core modules settings defaults locales` → one hit, `modules/Probe.lua:144` `local version, build, date, interface = GetBuildInfo()` (**SM-12**: report only).
- The reason is recorded at `README.md:8` "WoW Forever only. Weapon skills, Defense, level-based skill caps and weapon masters don't exist on Retail, …" and at `docs/ARCHITECTURE.md:14` "**Clients: WoW Forever only, by owner decision (2026-11-10, clients-§2, clients-§9).**".
- Smoke: `docs/smoke-tests.md:27` "**SM-LOAD-2** On a **Retail** client, open the AddOns list. Ka0s Skill Master is **not listed**".
- Pin: `tests/run.lua:7` `dofile("tests/client_pin.lua")(Loader)   -- Forever-only: every run is the Forever profile (clients-§9)`.

## E5 — SM-01: schema-row writes outside `NS.SetByPath`

- The seam is `settings/Schema.lua:212` `NS.SetByPath          = S.Set          -- THE single write seam (architecture-§5)`.
- Rows address the paths:
  - `settings/Layout.lua:75` `set = function(v) if v then B:Dock(id) else B:Detach(id) end end }),`
  - `settings/Layout.lua:79` `set = function(v) B:SetCollapsed(id, v) end }),`
  - `settings/Skills.lua:23` `path = kind .. ".hidden." .. key, page = page, …`
- The writers assign the stored tables directly:
  - `modules/Blocks.lua:94` `s.docked = false`
  - `:104` `s.docked = true`
  - `:113` `s.collapsed = collapsed and true or false`
  - `:125` `for i, id in ipairs(ids) do B.Settings(id).order = i end`
  - `:136` `s.order = math.floor(n)`
- Non-panel callers reach those writers with no seam in between:
  - `modules/Blocks.lua:242` `local function onHeaderClick(self) B:ToggleCollapsed(self.id) end`
  - `:246` `if h.docked then B:Detach(h.id) else B:Dock(h.id) end`
  - `modules/Detached.lua:106` `… function() NS.Blocks:Dock(f.id) end,`
  - `:108` `… function() NS.Blocks:ToggleCollapsed(f.id) end)`
  - `settings/Layout.lua:155` `if B:Move(from, to) then H.RefreshPanel(ctx, true) end`
- The row menu writes the hidden set directly: `modules/Interact.lua:85` `NS.db.profile[kind].hidden[row.entry.key] = true`.
- SM-01a: `grep -n 'NS.Debug' modules/Blocks.lua modules/Interact.lua` returns nothing, so these writes log no settings line.
- SM-01b: `docs/ARCHITECTURE.md:91-94` reads "`docked`, `order` and `collapsed` are `modules/Blocks.lua`'s and have schema rows on the Layout page (T5.1) that write through it: `NS.Blocks:Detach` / `:Dock` / `:SetCollapsed` / `:SetOrder`, and `:Move` from the Block order drag list, so a row, a header click and `/skm set` take one path." `docs/ARCHITECTURE.md:258-260` reads "## Documented deviations / None."
- Write-path classification, from the grep of named keys over `core modules settings`:
  - Named (e) state, compliant: `MainWindow.lua:45`, `:531`; `Journal.lua:98`, `:104`, `:691`; `Detached.lua:48`; `Alerts.lua:281`; `Interact.lua:103` (`char.pinned`); `SessionLog.lua:41`, `:52`; `Alts.lua:20`.
  - Library-table and launcher writes: `LauncherSetup.lua:38` and `General.lua:85`.
  - Load pass: `Database.lua:28`.
  - Class (a): the Blocks and Interact sites above.
- The impact is not observed in a client. Whether an open Layout or Skills page shows a stale checkbox after a header click or a row-menu hide is left to the owner's smoke. The grade (Low) rests only on what the code shows.

## E6 — SM-02: `tests/test_disabled.lua` against slash-commands-§7's ten steps

| Step | Evidence | State |
|---|---|---|
| 1 Baseline | `:33-34` `local R_on = bringUp()` / `assertTrue(#R_on > 0, …)`. No `T_on` or `F_on` is captured. | partial |
| 2 Seam | `:16` `local function disable() NS.SetByPath("enabled", false) end` | met |
| 3 Empty set | `:40` `assertEqual(#regSet(), 0, "survivors:\n  " .. joined(regSet()))`, by count with names in the message. No `-- red under:` between `:37` and `:42`. | partial |
| 4 No timer | `:48` `assertEqual(#M.__timers(), 0, …)`. The suite never checks that no new timer is armed for the rest of the run. | mostly met |
| 5 Frames hidden | `:57` `assertFalse(NS.MainWindow.IsShown(), …)` checks the main window only. Detached frames, the Journal, the trainer popup and the toast are not checked. | partial |
| 6 Fires | `:75` asserts `PLAYER_REGEN_DISABLED` by name. `:80-81` assert zero SV writes and zero prints. `:86-87` assert `__fireUnconditional` reached at least 1 per event. Zero shows are checked for the main window only (`:82`). No `-- red under:` between `:64` and `:91`. | partial |
| 7 Slash | `:103-120` dispatch every `NS.COMMANDS` row. `:123-124` cover the bare `/skm`. `:128-135` cover the perf-hold line. `debug diagnostics` is never dispatched (`grep -rn 'debug diagnostics' tests/*.lua` is empty). | partial |
| 8 Launcher/binding | `:145` covers `OnClick(nil, "LeftButton")` with opener count `:147` and zero writes `:154`, but zero shows are not asserted. The `"RightButton"` menu is never driven. `:150` covers the window binding while disabled. The perf-hold-alone press and the journal binding are not driven. | partial |
| 9 Re-enable | `:166` `assertEqual(joined(regSet()), joined(R_on))`, plus the setting changed while disabled (`:161`, `:170`) | met |
| 10 Latch | `:176` `-- red under: an enable path, or a perf resume, that calls NS.StandUp() directly …`, then `T.assertLatchHoldOrder{…}` at `:179` | met |

Supporting census (TOC-derived load list, 77 authored `.lua`):
- Registrations sit on the addon object (`core/SkillMaster.lua:59`, `modules/Bonuses.lua:328-329`, `modules/SkillData.lua:275`) or on tracked bus targets (`modules/Alerts.lua:297-298`, `Alts.lua:117-118`, `Blocks.lua:397-401`, `Broker.lua:225-228`, `Detached.lua:210`, `Journal.lua:709-710`, `SecureOverlay.lua:227-228`, `SessionLog.lua:166`, `StatData.lua:304`, `settings/Bars.lua:196`).
- Teardown: `core/SkillMaster.lua:79` `addon:UnregisterAllEvents()`, `:80` `addon:CancelAllTimers()`, `:81` `NS.BusStandDown()`.
- Latch: `core/LifecycleSetup.lua:66-73` `NS.Lifecycle = lib:New({ … standDown = function() NS.StandDown() end, standUp = function() NS.StandUp() end, …`. The perf harness shares it: `core/PerfSetup.lua:33` `lifecycle = NS.Lifecycle,`.

## E7 — SM-03: skin-switch surfaces

- Declared: `tests/run.lua:63-93` names six surfaces: main window, a detached block, journal, trainer popup, alert toast and debug console.
- Painted and undeclared:
  - `modules/RowTooltip.lua:212` `tipBar = Bar.Create(GameTooltip, "tooltip")`
  - `modules/Broker.lua:133` `local r, g, b = NS.Skin.Color(token)`
  - `modules/Broker.lua:235` `local barPool = NS.Bar.NewPool()`
  - `settings/Bars.lua:185` `local bar = NS.Bar.Create(frame, "row")`

## E8 — SM-04: undated counts

```
$ git ls-files 'docs/*.md' 'docs/*/*.md' README.md CLAUDE.md DEPENDENCIES.md | grep -vE '^docs/(superpowers|automated-tests/2|perf-analysis/2)' \
   | grep -v 'test-cases.md\|automated-tests/RESULTS.md\|midnight-quirks.md' \
   | xargs grep -noiE '\b([0-9]+|two|three|…|twelve)\s+(modules?|files?|pages?|messages?|commands?|shims?|cases?|suites?|events?|rows?|tabs?|blocks?|feeds?|verbs?|tables?|setup files?)\b'
docs/ARCHITECTURE.md:112:Six messages      docs/ARCHITECTURE.md:227:23 commands     docs/ARCHITECTURE.md:233:Six messages
docs/automated-tests/README.md:4:four suites   docs/module-map.md:40:eight blocks   docs/testing.md:23:Three suites   docs/testing.md:53:four suites
```
- Scope: live docs only. Excluded are the generated `test-cases.md` and `RESULTS.md`, the vendored quirks catalog, and the frozen and superpowers stores.
- Seven regex hits. Reading found one more the regex missed, `docs/ARCHITECTURE.md:232` "`core/Compat.lua` publishes three addon-specific shims (the skill list, T2.1)".
- `:112` and `docs/automated-tests/README.md:4` name their members in place and are compliant. The cells filed are `:227`, `:232`, `:233` and `docs/module-map.md:40`.
- The wrong figure:
  ```
  $ cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'
  9
  ```
- Other trigger counts behind the map cells: `grep -c '^    {"' settings/Slash.lua` → 23. Known Limitations section → 33 lines. Taint Notes → 20 lines.

## E9 — SM-05: Event Subscriptions

- `modules/Detached.lua:210` `NS.SafeRegisterEvent(D.events, "PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged, NS.rejectedEvents)`.
- `docs/ARCHITECTURE.md:136-145` lists `PLAYER_EQUIPMENT_CHANGED` only under `modules/StatData.lua` (`:144`). The subscriber paragraph `:147-152` does not name Detached.

## E10 — SM-06: perf coverage

- `core/PerfSetup.lua:29-30` `buckets = { { key = "windowRender" }, …`.
- The one bracket: `modules/MainWindow.lua:402` `local t0 = Perf.on and debugprofilestop()` and `:425` `if t0 then Perf.Note("windowRender", debugprofilestop() - t0) end`.
- Unbracketed event paths:
  - `modules/Bonuses.lua:322` `B.__pending = NS.addon:ScheduleTimer(B.Refresh, B.DEBOUNCE)`
  - `:302` `B.__ticker = NS.addon:ScheduleRepeatingTimer(B.Tick, B.TICK)`
  - `modules/StatData.lua:278` `self.timer = NS.addon:ScheduleTimer(flush, S.THROTTLE)`
  - `modules/SkillData.lua:235` `pending = NS.addon:ScheduleTimer(function()`

## E11 — SM-07 … SM-12

- SM-07: `grep -n '^## ' README.md` → Usage, How the bars work, FAQ, Troubleshooting, Reporting a bug, Issues and feature requests, Version History, Credits. There is no `## Screenshots`, and `media/` holds only `logos/`.
- SM-08: `git ls-files docs/superpowers | grep -v mockup` → `plans/2026-11-10-skill-master-v1-STATUS.md`, `plans/2026-11-10-skill-master-v1.md`, `specs/2026-11-10-skill-master-design.md`.
- SM-09:
  - `SkillMaster.toc:63-64` reads `core\Constants.lua` / `core\State.lua`. No comment sits above `:64`.
  - `:65` `core\EnvSetup.lua`, `:73` `core\PoolSetup.lua` and `:84` `core\Database.lua` are likewise unlabeled.
  - Their publications are read at call time only. Examples: `core/DebugLogSetup.lua:85` `isEnabled  = function() return NS.State.debug == true end,` and `core/LauncherSetup.lua:65` `version       = function() return NS.Version() end,`.
- SM-10: see E1.
- SM-11: `README.md:78` `| 1.0.0 | Unreleased | - Every weapon skill, …` and `SkillMaster.toc:7` `## Version: 0.1.0`. `docs/ARCHITECTURE.md:19` reads "The build (TOC `0.1.0` until the release bump; the README's Version History carries the 1.0.0".
- SM-12: `modules/Probe.lua:189` `local Perf = LibStub("LibKa0s-Perf-1.0", true)` and `:190` `if not (Perf and Perf.EncodeJSON and P.__copy) then`.

## E12 — Compliance claims (selected)

**Launcher**
- `core/LauncherSetup.lua:48` `label   = NS.Constants.BRAND,`
- `:59` `toggleTestMode = function() runVerb("test") end,`
- `:63` `toggleWindow   = function() NS.MainWindow.Toggle() end,`
- `settings/Slash.lua:37` `{"toggle", …, function() NS.MainWindow.Toggle() end},`
- `modules/MainWindow.lua:552` `W.__toggleButton = bindingButton(W.TOGGLE_BUTTON, function() W.Toggle() end)`

**Bindings**
- `Bindings.xml:3` `<Binding name="CLICK SkillMasterToggleWindow:LeftButton" category="BINDING_HEADER_SKILLMASTER"/>`
- `modules/MainWindow.lua:544` `button:RegisterForClicks("AnyDown")`

**Minimap**
- `core/Constants.lua:23` `C.MINIMAP_PATH = "global.minimap.shown"`
- `tests/test_schema.lua:51` asserts "the minimap row survived Reset all settings".

**Bus**
- `core/Bus.lua:46` `NS.MSG = Bus.Catalog(addonName, {`, with tails at `:48-58` (`…_SkillsUpdated`, `…_SkillUp`, `…_StatsUpdated`, `…_BonusesUpdated`, `…_LayoutChanged`, `…_SimTicked`).
- The literal grep outside `core/Bus.lua` and tests returns nothing.

**Close button**
- `core/CoreSetup.lua:86` `return lib.MakeCloseButton(parent, onClick, addonName)`
- Callers: `modules/Journal.lua:505`, `modules/MainWindow.lua:85` and `modules/TrainerPopup.lua:138` call `NS.MakeCloseButton(…)`.

**Skin**
- `core/SkinSetup.lua:215` `Skin:RegisterOwner(addonName, {`
- `settings/General.lua:147` `H.AppearanceTab({ owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice }),`
- `:148` `H.KeybindingsTab({ bindings = NS.BINDINGS }),`
- `:155` `defaultsTooltip = H.ResetAllTooltip(H.KEYBINDS_UNCHANGED),`

**Slash and options**
- `settings/Slash.lua:30` `-- Positional triples {name, desc, fn}. `skin` sits directly after `config` (skinning-§3).`; `NS.COMMANDS = {` opens at `:31`. `:47` `{"enable", …, function() setAndEcho("enabled", true) end},`
- Diagnostics: `settings/Slash.lua:63-64` (`{"diagnostics", …, function() NS.DebugLog:RunDiagnostics() end},`); DebugVerb is first at `:61`.
- Library debug sinks:
  - `settings/Slash.lua:137` `debug        = function(tag, message) NS.Debug(tag, "%s", message) end,`
  - `settings/OptionsSetup.lua:109` `debug         = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,`
  - `core/LauncherSetup.lua:67-68` (`debug`, `debugAtEnable`)
  - `core/LifecycleSetup.lua:72` (`debug`)

**Vendored quirks block**
- `docs/midnight-quirks.md:9` `<!-- BEGIN VENDORED: quirks catalog v2.105.0 (source: WowAddonStandards) -->` … `:271` `<!-- END VENDORED -->`
- `diff <(sed -n 10,270p docs/midnight-quirks.md | tr -d '\r') standards/standards/client-quirks.md` → identical.

**Register and issues**
- `docs/ARCHITECTURE.md:258-260` `## Documented deviations` / `None.`
- `gh issue list --state all --limit 200 --json number,title,state,labels` → `[]`.

**Display glyphs**
- The non-ASCII hits, outside comments, are `·` (`modules/Alerts.lua:77`, `:204`; `modules/Blocks.lua:27-31`; `modules/Broker.lua:416`; `modules/Journal.lua:230`, `:394`), `×` (`modules/Blocks.lua:206`) and `—` (`modules/Journal.lua:43`).
- All three are in localization-§7's safe set.
