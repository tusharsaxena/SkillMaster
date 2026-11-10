# 01 — Findings: Ka0s Skill Master (principal-engineer review)

**Verdict: minor issues.** Nothing Critical. One High: skill lines and the crafting overlays' spells are matched on English strings, so on any non-enUS client the skill model and the crafting clicks stop working. The rest is Medium and Low: perf churn on the stat path, gaps in the stand-down tests, and some UX around destructive or irreversible actions.

**Resolved scope:** `all`, so the whole addon at `/mnt/d/Profile/Users/Tushar/Documents/GIT/SkillMaster`, HEAD `5c650e8` (branch tip, clean tree). That covers every authored file under `core/`, `defaults/`, `locales/`, `modules/`, `settings/` and `tests/`, plus the TOC, `Bindings.xml`, `.luacheckrc`, `.pkgmeta` and the docs as evidence. `libs/` and `tests/_kit/` are vendored. They are read only to check the vendor sync and the stubs against their libraries.

Profile: `profile=wow kind=addon`, from `dev-copilot-profile`. Standards context: WowAddonStandards **v2.105.0**, read from the local worktree `#Worktrees/WowAddonStandards-forever-only` at `3d6855f`, which is clean. The caller said GitHub master does not have the Forever-only amendment, so this worktree's HEAD is not origin master's. The overlay's three-check sibling rule does not hold for it. It was used because the caller told me to use it.

## Measurement run (today, 2026-11-10, HEAD 5c650e8)

All output went to the session scratchpad. Nothing was written into the repo except this bundle.

| Suite | Result | Command |
|---|---|---|
| luacheck | **pass**: 0 warnings / 0 errors in 120 files | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` |
| Headless suite | **pass**: 373 passed, 0 failed, 1 skipped, 374 total | `KA0S_KIT_CLIENT=forever ka0s-bounded lua5.1 tests/run.lua` |
| Skipped case | `diagnostics contract: an addon that opts out lands the report and leaves logging off`. This is a declared skip: the addon keeps the default, and the case above it covers that | (same run) |
| Fresh `--list` inventory | **pass**: byte-identical to the committed `docs/test-cases.md` (`diff` empty, 574 lines). The README badge reads `373/373`, which matches Total 373 | `KA0S_KIT_CLIENT=forever ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/list.md` |
| Offline perf | **ran**: `windowRenderOff` 0.04209 ms, 4136.0 B/iter; `windowRenderOn` 0.04079 ms, 4136.3 B/iter; `settingsRead` 0.00044 ms, 0.0 B/iter. The api/iter column is hard-coded to 0 (F-008) | `KA0S_KIT_CLIENT=forever ka0s-bounded lua5.1 tests/perf.lua` |
| Complexity (sighted, kit rev 53) | **pass**: 0 warnings, max CCN 15 (`Bar.PaintBorder`, `modules/Bar.lua:257`, mostly dense defaulting), 14078 NLOC / 2043 funcs, avg CCN 2.4. blindFiles 0, crashedFiles 0 | `ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` |
| `make test` | not applicable: there is no root `Makefile` | — |
| Vendor sync | **clean**. `libs/LibKa0s/` matches `LibKa0s@v1.94.0:LibKa0s/` after CR normalization, except for 208 icons the TOC-declared icon list prunes, which is expected: the 18 shipped icons equal CLAUDE.md's `LibKa0s icons:` line. `tests/_kit/` matches `LibKa0s@v1.94.0:testkit/` exactly. `tests/test_vendor_sync.lua` passes as well | `git -C LibKa0s archive v1.94.0 LibKa0s testkit \| tar -x -C <scratch>; diff -rq --strip-trailing-cr` |
| Cross-addon, class 1 (slash) | **clean**: 36 roots across the 18 roster addons, no duplicate, no raw `SLASH_*` in loaded source. SkillMaster: `skm`, `skillmaster` | the two overlay loops, roster derived from the worktree's `standards/ADDONS.md` (18 rows) |
| Cross-addon, class 2 (minors) | **3 lines (split)**. Consumers vendor three tags: v1.93.0 (9 addons), v1.94.0 (8, SkillMaster among them), v1.95.0 (QuickComms). Where bytes differ, the minor differs too (Compat 3→4, Skin 17→18, DebugLogDiagnostics DIAG 7→8), so LibStub's highest-wins picks one payload deterministically. This is a re-vendor sweep in progress, not a SkillMaster defect | overlay class-2 loop |
| Cross-addon, class 3 (bytes) | Same tag split. Against SkillMaster (reference) the v1.93 consumers differ in `Compat.lua`/`Skin.lua`, and QuickComms in `DebugLogDiagnostics.lua`, `LibKa0s.xml` and an extra `Role.lua`. Every differing file has a bumped minor, so the hazard stays latent. v1.94 consumers are byte-identical apart from icon pruning | `diff -rq --strip-trailing-cr SkillMaster/libs/LibKa0s <a>/libs/LibKa0s` |
| Cross-addon, class 4 (Interface) | **clean**: Retail slot `120105` everywhere, Forever slot `16001` everywhere. SkillMaster carries `16001` alone with the camelot/standard gating pair, which is right for roster Clients `Forever` (clients-§9) | overlay class-4 loop |

**Committed artifacts that disagree with today's run:**
- `docs/automated-tests/RESULTS.md` and the bundle `20261110-025504` measured `9a66b14`, which is 42 commits behind HEAD. They record 120 cases, 43 lint files, max CCN 10 over 449 functions, and `windowRenderOff` 0.0 B/iter. Today's run gives 374 cases, 120 files, max CCN 15 over 2043 functions, and 4136 B/iter. The record is stale, which is normal before the release regeneration. It is not non-compliant.
- `docs/performance.md:20` says "The data modules (T2.x) and the bars (T3.x) add their own buckets as they land". They have all landed and none added a bucket (F-008).

Census scope used throughout: the tracked authored Lua, `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, for structural claims, and the TOC load list for runtime claims (events, writes).

Nothing that needs the game client ran here. Those checks are in `03_SMOKE_TESTS.md`.

---

## High

### F-001 — Game data is matched on English strings: skill lines, excluded headers and the crafting spell `[locale]`
- **Where:**
  - `modules/SkillData.lua:32`: `map[L[e.name]] = key`
  - `modules/SkillData.lua:40`: `for _, header in ipairs(NS.SkillExcludedHeaders) do EXCLUDED[L[header]] = true end`
  - `modules/SkillData.lua:123`: `if header and EXCLUDED[header] then return nil end`
  - `modules/SecureOverlay.lua:62`: `return cat and cat.openSpell and L[cat.openSpell] or nil`
  - `modules/SecureOverlay.lua:86`: `b:SetAttribute("spell", spell)`
- **Problem:** The skills model classifies every Skills-tab line by its localized display name, and the crafting overlays cast by spell name. `NS.L` falls back to English, and all ten non-enUS locale files are empty stubs (`locales/deDE.lua` says so itself). On any other client nothing matches:
  - every profession and weapon line becomes `other:<name>`;
  - the excluded headers stop matching, so armor, language and class lines flood into Other;
  - `addUnlearned` adds a "Not learned" row for every class weapon the player actually has (`SkillData.lua:164-180`);
  - the overlays carry the English spell name, which the client does not know.
- **Impact:** For a non-English player the window shows a wrong, duplicated skill list. Trainer, alert, bonus and gathering lookups (all keyed by catalog key) go dark, and a left click on a crafting row does nothing. This breaks localization-§4 (MUST: match game data on IDs or tokens, never on localized display strings).
- **Reachability:** Any player whose WoW Forever client runs in a non-enUS locale, every login. The addon ships GetLocale-gated stubs for deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN and zhTW, so it expects those clients. Whether Forever ships every one of those locales is unverified.
- **Coverage note:** `tests/test_skilldata.lua:327`, "an unknown (localized) name lands in Other, never an error", pins the collapse as the intended outcome. No test checks a non-enUS client.
- **Fix direction (compliant):**
  - For the overlay, store a spell ID per profession and resolve the client's name from it at sync time. IDs flow to names (localization-§4).
  - For skill lines, prefer a skill-line ID if `/skm probe` shows Forever's `C_SkillInfo` carries one. Otherwise put the game-data strings into each locale file, which is what the stubs already ask for.
  - Until then, say in README and Known Limitations that non-enUS clients are unsupported.

## Medium

### F-002 — A row hidden from the row menu can become impossible to show again `[ux]`
- **Where:**
  - `modules/Interact.lua:85`: `NS.db.profile[kind].hidden[row.entry.key] = true`
  - `modules/Interact.lua:111`: the "Hide this row" menu entry
  - `settings/Skills.lua:70-74`: Hide rows are generated only from `NS.SkillCatalog` keys
- **Problem:** The row menu offers Hide on every row, including unknown `other:<name>` rows, and writes the set directly instead of going through `NS.SetByPath`. Those keys have no schema row. The Skills page cannot show them, the page's Defaults button resets only catalog rows, and the CLI has no path to address.
- **Impact:** Once hidden, an unknown row stays hidden for good. Only a whole-profile reset (`/skm resetall`) brings it back. The direct write also skips the row's `onChange`, so an open Skills page goes stale.
- **Reachability:** Any player who right-clicks an Other row the catalog does not know and picks Hide. On enUS that needs a line the 1.12 catalog lacks (unverified on Forever). On any non-enUS client every skill line qualifies (F-001).
- **Fix direction:** Route the write through `NS.SetByPath` (architecture-§5). Give `skills.hidden` a schema-backed way to clear the whole set, for example a set-level row that the Skills page Defaults resets. Alternatively, leave Hide off rows that have no schema row.

### F-003 — Every stat tick rebuilds every detached block from scratch, and the speed ticker forces a full stat rescan twice a second `[perf]`
- **Where:**
  - `modules/StatData.lua:291`: `self.ticker = NS.addon:ScheduleRepeatingTimer(function() S:Request() end, S.SPEED_TICK)`
  - `modules/Blocks.lua:376-377`: `repaint` calls `NS.MainWindow.Refresh()` and `NS.Detached.Refresh()`
  - `modules/Detached.lua:160-177`: `D.Refresh`, which runs `applyPoint(f)` (line 167, re-anchor, re-scale, re-strata), `D.Render` (release and re-lay every row) and `SecureOverlay:Sync` for every detached block on each call
- **Problem:** While the utility stats are on screen (docked and expanded by default), the 0.5 s ticker re-reads around 25 stat APIs and 19 durability slots only to learn the speed. Each `STATS_UPDATED` then repaints every surface. The main window at least short-circuits to a values-only pass. The detached path has no signature check and redoes geometry on every tick. It also re-anchors a frame the player may be dragging at that moment; the visual effect is unverified.
- **Impact:** Steady garbage and CPU on an idle character. The design's own budget says "nothing polls per frame except visible expiry timers" (`docs/performance.md`). Today's offline run measures `windowRenderOff` at **4136 B/iter** for the main window alone. No scenario or bucket covers the detached path (F-008), so its cost is unmeasured.
- **Reachability:** Any player with the main window open (utility block visible by default) or a detached utility block, out of combat, twice a second. In combat the `UNIT_*` events add up to 5 rescans a second.
- **Fix direction:** The speed tick should read speed alone and publish only when it changed. `D.Refresh` should keep `applyPoint` for layout or settings changes and use a row-set signature like `W.Render`'s. Bracket both paths (performance-§2) and add an offline scenario (performance-§9).

### F-004 — `UNIT_AURA` and `UNIT_INVENTORY_CHANGED` are registered for every unit, then filtered in Lua `[perf]`
- **Where:**
  - `modules/Bonuses.lua:328`: `NS.SafeRegisterEvent(addon, "UNIT_INVENTORY_CHANGED", "OnBonusesUnitChanged", ...)`
  - `modules/Bonuses.lua:329`: `NS.SafeRegisterEvent(addon, "UNIT_AURA", "OnBonusesUnitChanged", ...)`
  - `modules/StatData.lua:283`: `if event:sub(1, 5) == "UNIT_" and unit ~= "player" then return end`, which applies the same pattern to five `UNIT_*` stat events
- **Problem:** AceEvent cannot filter by unit, so the client dispatches every party, raid and nameplate aura change into Lua just for it to be discarded.
- **Impact:** This is the firehose cost events-frames-taint-§1 measured and then carved out a remedy for. It is the largest per-event overhead in the addon.
- **Reachability:** Any player in a group or raid, or near nameplate units, on every aura change, all session.
- **Fix direction:** Use events-frames-taint-§1's unit-filter frame: one private frame doing `RegisterUnitEvent(event, "player")` with a single dispatching `OnEvent`, created and torn down through the stand-down latch (slash-commands-§7, which counts per-unit frames).

### F-005 — "Clear log" erases the character's stored skill-up history in one click, with no confirmation `[ux]`
- **Where:**
  - `modules/Journal.lua:283`: `p.clear = makeButton(p, L["Clear log"], function() J.ClearLog() end)`
  - `modules/Journal.lua:633`: `NS.Preview.Log():Clear()`
  - For contrast, `modules/Journal.lua:658` asks first before Forget: `StaticPopup_Show("SKILLMASTER_FORGET_ALT", ...)`
- **Problem:** The irreversible wipe of `db.char.log` (up to `journal.keep`, max 2000 entries) has no confirmation. The milder Forget-an-alt action does, and Forget can be undone by logging the alt in again.
- **Impact:** One misclick loses the history that the ETA, session-rate and log views are built on.
- **Reachability:** Any player with the Journal open on the Log tab who clicks the button beside "New session".
- **Fix direction:** Ask through a StaticPopup like `SKILLMASTER_FORGET_ALT`.

### F-006 — `tests/test_disabled.lua` misses parts of slash-commands-§7's ten steps `[tests]`
- **Where:**
  - `tests/test_disabled.lua:37-42` (steps 2-3) and `:64-91` (step 6) have no `-- red under:` comment. slash-commands-§7 requires one on steps 3, 6 and 10; only step 10, at `:176`, has it.
  - `:139-156` (step 8):
    - never drives the launcher's `"RightButton"` menu (§7 step 8: Enabled live, the rest grayed, nothing written or shown);
    - asserts no frame shows after left-click;
    - never re-invokes the binding under the `perf` hold alone;
    - never invokes the Journal binding.
- **Impact:** Those parts of the disabled contract can regress without anything going red (testing-§12).
- **Reachability:** The test inventory only. The shipped stand-down looked correct when read.
- **Fix direction:** Add the missing assertions and the falsification comments. The pass count does not change unless new cases are added. If they are, `docs/test-cases.md` and the badge move in the same change.

### F-007 — The step-9 case calls `OnEnable()` itself, so it does not test the stand-up path `[tests]`
- **Where:** `tests/test_disabled.lua:158-173`. The key line is `:168`: `NS.addon:OnEnable()`.
- **Problem:** The case changes `scale` while disabled, re-enables, and then calls `OnEnable()` before it asserts that the window took scale 1.25. `NS.StandUp` (`core/SkillMaster.lua:86-92`) never calls `MainWindow.ApplySettings`. The test's own `OnEnable` call is what produces the value it asserts.
- **Impact:** The case cannot catch a stand-up that rebuilds from a stale snapshot (performance-§6), which is the thing step 9 exists to check (testing-§12: a test that builds its own result).
- **Reachability:** The test inventory only. In game, the write-time reaction (`NS.MasterReactions.scale`) already applies the scale, so shipped behavior is correct.
- **Fix direction:** Drop the explicit `OnEnable()`. Assert on what the enable write and `StandUp` leave behind, and add a `-- red under:` comment.

### F-008 — The perf instrumentation stopped at one bucket, and the offline runner reports a column it never measures `[perf]` `[tests]`
- **Where:**
  - `core/PerfSetup.lua:29-31`: buckets = `{ { key = "windowRender" } }` only
  - `tests/perf.lua:37`: `return { name = name, iters = iters, ms = ms, api = 0, bytes = bytes }`
  - `docs/performance.md:20`
- **Problem:**
  - The hottest paths have no bracket and no scenario: `Bonuses.Refresh` (19 item tooltips plus 40 buff tooltips), `SkillData:Scan`, `StatData:Scan`, `Detached.Refresh` and `Broker.Refresh`.
  - `api/iter` is a constant 0 that reads as a measurement.
  - "Dormant bracket is free" is compared Off against On, not Off against instrumentation absent (performance-§2, §9), so the claim is unverified.
  - The write-up still promises buckets that never came.
- **Impact:** F-003 and F-004 cannot be confirmed in game or offline. The committed record shows 0.0 B/iter where HEAD measures 4136.
- **Reachability:** The developer and the evidence only. There is no runtime effect.
- **Fix direction:**
  - Declare and bracket the hot paths.
  - Count API calls in the scenarios or drop the column.
  - Add the Off-versus-absent scenario.
  - Update `docs/performance.md` in the same change.

### F-009 — Crafting overlays can stay mouse-live under a window of the same strata raised over their host `[design]`
- **Where:**
  - `modules/SecureOverlay.lua:139-144` (`arm`: level = host level + `LEVEL.SECURE`)
  - `modules/SecureOverlay.lua:188-201` (`Follow` hooks only the host)
  - Documented at `docs/ARCHITECTURE.md:183`: "the host (the Journal) does not re-level the host's overlays."
- **Problem:** When the Journal, or another MEDIUM toplevel window, is raised over the main window, the invisible secure buttons may still sit above it. A click on the Journal over a crafting row would then cast the profession instead (frame-layering-§4: invisible but mouse-live).
- **Impact:** A profession window opens unexpectedly. There is no taint: it is a secure cast the player clicked for.
- **Reachability:** Any player who opens the Journal over the main window's crafting rows and clicks there, out of combat. Unverified in client; the documented limitation is the evidence.
- **Fix direction:** Have the addon's other windows (the Journal is its own frame) re-sync or lower the host's overlays when they are raised or shown over it, for example by passing them to `SecureOverlay:Follow` with a "covers host" check in `wanted()`. Verify in client first (03, SM-9).

## Low

### F-010 — The degraded Bus stub cannot stand subscriptions down `[design]`
- **Where:** `core/Bus.lua:22`: `StandDown = function() return 0 end`. The concrete risk is `modules/Alts.lua:118`, which registers `PLAYER_LOGOUT → A:Snapshot()` on a bus target.
- **Problem:** With LibKa0s-Bus-1.0 absent, targets are plain AceEvent embeds that disable never unregisters. One result is that logout snapshots still write `db.global.characters` while the addon is disabled (slash-commands-§7: no SV write reachable from a game event).
- **Reachability:** Only an install where LibKa0s-Bus-1.0 fails to register (a broken or partial `libs/`). The library is vendored, so in practice that is nobody.
- **Fix direction:** Have the stub record its targets and unregister them on `StandDown`. Add that to the library seam upstream if consumers need it.

### F-011 — Stat references bypass the simulator seam `[correctness]`
- **Where:** `modules/StatData.lua:213`: `local level = UnitLevel and num(UnitLevel("player")) or nil`
- **Problem:** During a simulation the stat caps use the real level, not the sample character's.
- **Reachability:** Any player running `/skm sim` on a character whose level differs from the sample's, for the session.
- **Fix direction:** Read `NS.Compat.PlayerLevel()`.

### F-012 — A simulation stopped by a stand-down leaves the simulated stats model in place after re-enable `[correctness]`
- **Where:** `modules/Simulator.lua:264` returns early on `standDown`, and `core/SkillMaster.lua:86-92` (`NS.StandUp`) requests no stat scan.
- **Problem:** After re-enabling, the Speed stat can show the simulated 160% until the next stat event.
- **Reachability:** A player who disables the addon mid-simulation and re-enables it.
- **Fix direction:** Call `StatData:Request()` from the stand-up.

### F-013 — Localized fragments joined with literal separators `[locale]`
- **Where:**
  - `modules/Alerts.lua:77`: `title .. " · " .. L["%s cap"]...`, with the dot written as a raw UTF-8 literal where the rest of the file escapes it
  - `modules/Journal.lua:394`
  - `modules/MainWindow.lua:384`
- **Problem:** Word order is fixed in code, so a translation cannot reorder it.
- **Reachability:** A future translator. There is no effect on enUS.
- **Fix direction:** One format key per line.

### F-014 — Journal log times omit the day `[ux]`
- **Where:** `modules/Journal.lua:187`: `row.cols[1]:SetText(date("%H:%M", e.t))`
- **Problem:** The log keeps up to 2000 entries across days, but the time column shows only `HH:MM`.
- **Reachability:** Any player whose log spans more than one day.
- **Fix direction:** Show the date when an entry is not from today.

### F-015 — `journal.keep` is a profile setting, but it truncates per-character data `[design]`
- **Where:** `modules/SessionLog.lua:17-20` (the `cap()` function), `:43`: `while #log > keep do table.remove(log, 1) end`
- **Problem:** Switching to a profile with a lower keep value permanently trims this character's log at its next skill-up.
- **Reachability:** A player who uses several profiles with different keep values.
- **Fix direction:** Trim only on an explicit change of the setting, or document the behavior on the row's tooltip.

### F-016 — Two degraded-path and label nits `[naming]`
- **Where:**
  - `modules/MainWindow.lua:89`: `ipairs({ frame.close, frame.lockButton, ... })`
  - `settings/General.lua:46`: `addonName = "Skill Master",`
- **Problem:**
  - At `MainWindow.lua:89`, `frame.close` is nil on a Core-absent load, so `ipairs` stops at once and no title control gets its chrome level.
  - At `General.lua:46`, the brand-like literal is neither localized nor `NS.Constants.BRAND`. How the library uses it is unverified.
- **Reachability:** The first only on a LibKa0s-Core-absent load. The second only as text the Master-controls composer may display.

## Upstream findings

None. Vendor sync is clean at v1.94.0. Reviewing the stubs against their call sites found every member present (DebugLog, Widgets, Perf, Launcher, Lifecycle, Skin, Sim, SimSeam, Pool). The LibKa0s tag split across the collection (v1.93 / v1.94 / v1.95) is a re-vendor sweep question for `/dev-copilot:wow-revendor-libka0s`, not a defect here.

## Counts

Critical 0 · High 1 · Medium 8 · Low 7 (F-016 contains two nits, counted once).
