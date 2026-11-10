# 05 — Execution plan: Ka0s Skill Master

Ordered, checkable steps keyed to `02_DEVIATIONS.md`. Headline tally: 12 roots (9 Low, 3 Info). With dependents: 14. MUST failures: 4 roots, 6 entries.

Every step ends on the green gate: `KA0S_KIT_CLIENT=forever lua tests/run.lua` and `ka0s-bounded luacheck .` at 0/0. After any suite change, regenerate `docs/test-cases.md` and the README badge.

## Sprint 1 — the write seam (SM-01, SM-01a, SM-01b)

- [ ] S1.1 Add characterization cases for header-click collapse, the detach and dock buttons, a drag move and row-menu hide. Each pins the stored value and the `LAYOUT_CHANGED` count, and all should be green on the current code (testing-§13).
- [ ] S1.2 Add seam-reach cases that wrap `NS.SetByPath`. They go red on the current code.
- [ ] S1.3 Make the `docked` / `collapsed` rows plain seam writes, with combat deferral and `B.Changed()` in `onChange` (`settings/Layout.lua:70-80`).
- [ ] S1.4 Turn `B:Detach` / `:Dock` / `:SetCollapsed` / `:ToggleCollapsed` into `NS.SetByPath` callers, keeping the in-combat queueing of the write (`modules/Blocks.lua:90-144`).
- [ ] S1.5 Make `B:Move` write each changed `order` through the seam inside one bulk bracket. Keep the `H.RefreshPanel` call at `settings/Layout.lua:155`.
- [ ] S1.6 Route `hideRow` through `NS.SetByPath` (`modules/Interact.lua:84-86`).
- [ ] S1.7 Confirm that a header click with debug on writes exactly one settings line (SM-01a).
- [ ] S1.8 Rewrite `docs/ARCHITECTURE.md:90-96` and `docs/schema.md` to match (SM-01b).
- [ ] S1.9 Add an owner smoke check: with the Layout page open, a header click updates the page's Collapse box.

## Sprint 2 — the conformance and skin suites (SM-02, SM-03)

- [ ] S2.1 Step 1: capture `T_on` and `F_on`.
- [ ] S2.2 Step 3: add a `-- red under:` comment naming the mutation.
- [ ] S2.3 Steps 5 and 6: assert every `F_on` frame is hidden and none is shown after the fires.
- [ ] S2.4 Step 6: add a `-- red under:` comment.
- [ ] S2.5 Step 7: dispatch `debug diagnostics`.
- [ ] S2.6 Step 8: cover the right-click menu (Enabled live, the rest grayed, no writes or shows), add zero shows to the left-click, press both bindings under the perf hold alone, and press the journal binding while disabled.
- [ ] S2.7 Mutate once by hand per red-under comment to confirm each assertion goes red, then revert.
- [ ] S2.8 Declare the row tooltip, broker feed tooltip and Bars preview (`scope`) surfaces in `Kit.skinSwitch` (SM-03).

## Sprint 3 — docs and perf (SM-04, SM-05, SM-06, SM-09)

- [ ] S3.1 Rewrite the Documentation map trigger cells as rules plus dated measurements, correct compat to 9 shims, and fix `docs/module-map.md:40` (SM-04).
- [ ] S3.2 Add the `PLAYER_EQUIPMENT_CHANGED` / `modules/Detached.lua` row to Event Subscriptions and `docs/data-flow.md` (SM-05).
- [ ] S3.3 Add the `bonusRefresh`, `statFlush` and `skillScan` buckets and brackets, pin them as reached in `tests/test_perf.lua`, and update `docs/performance.md` (SM-06).
- [ ] S3.4 Add the `# Core` conventional note to `SkillMaster.toc` (SM-09).

## Sprint 4 — release-time (SM-07, SM-10, SM-11; SM-08 and SM-12 at the owner's call)

- [ ] S4.1 Before the first publish: add `media/screenshots/`, a `## Screenshots` section and a `.pkgmeta` ignore line (SM-07).
- [ ] S4.2 At the 1.0.0 bump: move the TOC version to `1.0.0` and date the README row (SM-11).
- [ ] S4.3 Write the release `run-automated-tests.sh` bundle, with `ANALYSIS.md` `## Preview and simulation data` reviewing Preview and the Simulator (SM-10).
- [ ] S4.4 Owner decision: rename the superpowers plan pair to the spec's topic, or leave it recorded (SM-08).
- [ ] S4.5 Optional: publish `NS.Perf.EncodeJSON` from `core/PerfSetup.lua` (SM-12).

## Order constraints

- Run S1 before S2.6, because the menu and binding assertions read the same writers.
- Run S1.1 before S1.3–S1.6.
- S3.3 adds suite cases, so regenerate `docs/test-cases.md` and the badge once at the end of Sprint 3.
