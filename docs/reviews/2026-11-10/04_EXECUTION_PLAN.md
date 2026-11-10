# 04 — Execution plan

The gate before every commit is `KA0S_KIT_CLIENT=forever lua tests/run.lua` plus `ka0s-bounded luacheck .` at 0/0. Commit only on explicit instruction (CLAUDE.md). Any change that moves the pass count regenerates `docs/test-cases.md` and updates the README badge in the same commit.

## M1 — Evidence first (F-006, F-007, F-008)
- **Done when:** step 3, 6, 8 and 9 assertions can fail; the new buckets and scenarios exist; `docs/performance.md` is current.

| Task | Role | IDs | Files |
|---|---|---|---|
| M1-T1 | test-author | C-09 (F-006, F-007) | `tests/test_disabled.lua` |
| M1-T2 | perf-instrumenter | C-07 (F-008) | `core/PerfSetup.lua`, `modules/Bonuses.lua`, `modules/SkillData.lua`, `modules/StatData.lua`, `modules/Detached.lua`, `modules/Broker.lua`, `tests/perf.lua`, `tests/test_perf.lua`, `docs/performance.md` |

**Checkpoint:** record a fresh `tests/perf.lua` run as the "before" baseline for M3.

## M2 — Locale-independent data (F-001, F-002)
- **Done when:** SM-1 and SM-2 pass on enUS and deDE, and SM-3 passes.

| Task | Role | IDs | Files |
|---|---|---|---|
| M2-T1 | wow-api-migrator | C-01 | `defaults/SkillCatalog_Forever.lua`, `core/Compat.lua`, `modules/SecureOverlay.lua`, `.luacheckrc`, tests |
| M2-T2 | locale-author | C-02 | `locales/*.lua`, `modules/SkillData.lua`, README, `docs/ARCHITECTURE.md` |
| M2-T3 | lua-refactorer | C-03 | `modules/Interact.lua`, `settings/Skills.lua`, tests |

**Checkpoint:** before M2-T1, run `/skm probe` in client to confirm the spell and skill-line ID shapes.

## M3 — Stat-path churn (F-003, F-004, F-011, F-012)
- **Done when:** the M1 scenarios show lower bytes/iter for detached refresh and lower scan counts, and SM-4 and SM-5 pass.

| Task | Role | IDs | Files |
|---|---|---|---|
| M3-T1 | lua-refactorer | C-04 | `modules/StatData.lua` |
| M3-T2 | lua-refactorer | C-05 | `modules/Detached.lua`, `modules/Blocks.lua` |
| M3-T3 | events-migrator | C-06 | `core/UnitEventsSetup.lua` (new), `SkillMaster.toc`, `core/SkillMaster.lua`, `modules/Bonuses.lua`, `modules/StatData.lua`, `tests/test_loadorder.lua` (derives from TOC; verify) |

**Checkpoint:** run the taint regression in client after M3-T3.

## M4 — UX and hygiene (F-005, F-009, F-010, F-013..F-016)

| Task | Role | IDs | Files |
|---|---|---|---|
| M4-T1 | ux-cleanup | C-08 | `modules/Journal.lua`, `modules/SessionLog.lua`, `locales/enUS.lua` |
| M4-T2 | ux-cleanup | C-10 | `core/Bus.lua`, `core/SkillMaster.lua`, `modules/Alerts.lua`, `modules/Journal.lua`, `modules/MainWindow.lua`, `settings/General.lua`, `locales/enUS.lua` |
| M4-T3 | layering | F-009 (after SM-9 confirms it) | `modules/SecureOverlay.lua`, `modules/Journal.lua` |

## Concurrency map
- These must serialize because they touch the same files:
  - M1-T2 and M3-T1/M3-T3: `modules/StatData.lua`, `modules/Bonuses.lua`.
  - M1-T2 and M3-T2: `modules/Detached.lua`.
  - M3-T3 and M4-T2: `core/SkillMaster.lua`.
  - M2-T1 and M4-T3: `modules/SecureOverlay.lua`.
  - M4-T1 and M4-T2: `modules/Journal.lua` and `locales/enUS.lua`.
  - M2-T2 and M4-T1/T2: `locales/enUS.lua`.
- M1-T1 can run in parallel with everything; it touches the test file only.
- M2-T3 can run in parallel with M1 and M3.

## Upstream
None.

## Commit strategy (one commit per task)
- `Tests (disabled §7): steps 3/6/8 assertions and red-under, step 9 off the stand-up path`
- `Perf: buckets and offline scenarios for the scan, bonus, detached and broker paths`
- `Locale: crafting overlays cast by spell ID-derived name`
- `Locale: skill lines and headers through the locale files`
- `Rows: Hide goes through the seam; page Defaults clears the hidden set`
- `Stats: the speed tick reads speed only`
- `Detached: values-only repaint when the row set is unchanged`
- `Events: player-only UNIT_* on the unit-filter frame (events-frames-taint-§1)`
- `Journal: confirm Clear log; dated log rows; keep trims on its own change`
- `Hygiene: Bus stub stands down, StandUp rescans stats, format keys`
