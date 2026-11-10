# 05 — Final summary (written as if the plan shipped and `03_SMOKE_TESTS.md` passed)

## Headline
Skill Master now recognizes skills and opens profession windows on non-English clients: game data is matched on IDs or locale-file strings, not hardcoded English.

Other changes:
- Rows hidden from the row menu can always be shown again.
- The idle stat path no longer rescans every stat twice a second.
- The idle stat path no longer rebuilds every detached block.
- Player-only unit events are filtered by the client instead of in Lua.
- Clearing the Journal's log asks first.
- The disabled-state tests and perf instrumentation now cover the paths they claim to cover.

## Counts
Critical fixed: 0, High fixed: 1, Medium fixed: 8, Low fixed: 7.

F-009 is fixed only if SM-9 confirmed it. Otherwise it is closed as not reproducible.

## Changes by theme

### T1 Locale-independent game data
- **What changed:** overlays cast via a spell ID's localized name; skill lines and headers come from the locale files.
- **Why it mattered:** non-enUS players had a broken skill list and dead crafting clicks (F-001). C-01, C-02.
- **Files:** `defaults/SkillCatalog_Forever.lua`, `core/Compat.lua`, `modules/SecureOverlay.lua`, `modules/SkillData.lua`, `locales/*.lua`, `.luacheckrc`, README, `docs/ARCHITECTURE.md`.

### T2 Row hiding through the seam
- **What changed:** Hide writes through `NS.SetByPath`, and page Defaults clears the set.
- **Why it mattered:** unknown rows could not be shown again (F-002). C-03.
- **Files:** `modules/Interact.lua`, `settings/Skills.lua`.

### T3 Stat-path churn
- **What changed:**
  - The speed tick reads speed only.
  - The detached frames render values only when nothing moved.
  - `UNIT_*` events go to a unit-filter frame under the stand-down latch.
  - Stat references read the simulator seam.
  - The stand-up rescans stats.
- **Why it mattered:** F-003, F-004, F-011, F-012. C-04, C-05, C-06, C-10 (part).
- **Files:** `modules/StatData.lua`, `modules/Detached.lua`, `modules/Blocks.lua`, `core/UnitEventsSetup.lua` (new), `SkillMaster.toc`, `core/SkillMaster.lua`, `modules/Bonuses.lua`.

### T4 Destructive-action UX
- **What changed:** Clear log confirms, log rows show dates, and `journal.keep` trims only when changed.
- **Why it mattered:** F-005, F-014, F-015. C-08.
- **Files:** `modules/Journal.lua`, `modules/SessionLog.lua`, `locales/enUS.lua`.

### T5 Evidence that can fail
- **What changed:** slash-commands-§7 steps completed with falsification comments; five perf buckets and three scenarios added; `docs/performance.md` rewritten.
- **Why it mattered:** F-006, F-007, F-008. C-07, C-09.
- **Files:** `tests/test_disabled.lua`, `tests/perf.lua`, `tests/test_perf.lua`, `core/PerfSetup.lua`, `docs/performance.md`.

### T6/T7 Overlay layering and hygiene
- **Why it mattered:** F-009, F-010, F-013, F-016. C-10.

## API / behavior changes
- No slash verbs were added or removed.
- New StaticPopup `SKILLMASTER_CLEAR_LOG`.
- New perf buckets: `bonusesRefresh`, `skillScan`, `statScan`, `detachedRender`, `brokerRefresh`.
- New file `core/UnitEventsSetup.lua` in the TOC.
- New locale keys: the log date format and the joined-title formats.
- Catalog gains `openSpellID`, and `skillLineID` if the probe confirms one.

## Saved-variable / migration notes
- No schema bump.
- `skills.hidden` / `stats.hidden` keep their shape. If C-03 takes the set-row variant, the set keeps the same table.

## Deprecated-API migrations

| Old | New | Files |
|---|---|---|
| spell attribute by English name | name resolved from spell ID via `NS.Compat.SpellName` | `modules/SecureOverlay.lua`, `core/Compat.lua` |

## Performance impact
Before figure, from today's `tests/perf.lua`: `windowRenderOff` = 4136.0 B/iter.

The after figures come from the M1 scenarios (`detachedRefresh`, `bonusesRefresh`) and the SM-5 capture bundle. Fill them in from those records; nothing is estimated here.

## Test and complexity movement
- Before: 373 passed / 1 skipped / 374 total. Badge 373/373.
- After: 373 plus the new cases from C-01, C-02, C-03 and C-06. `docs/test-cases.md` and the badge move in each of those commits.
- No watch-list entry should cross CCN 15 (current maximum: `Bar.PaintBorder` at 15). Confirm at the release regeneration.

## Known follow-ups
- Translations beyond the game-data strings: the stubs stay partial.
- The launcher Journal entry needs a LibKa0s seam. This is an existing known limitation.
- Re-vendor to LibKa0s v1.95.0 with the collection sweep.

## Verification evidence
- `03_SMOKE_TESTS.md` sign-off table.
- Commit range: TBD, from `5c650e8`.

## Suggested PR description
```
Review 2026-11-10 fixes (F-001..F-016)

- Locale: match game data on IDs / locale strings; crafting overlays cast by spell-ID name (F-001)
- Rows: Hide through NS.SetByPath; page Defaults clears hidden sets (F-002)
- Perf: speed tick reads speed only; detached values-only repaint; player UNIT_* on the
  unit-filter frame; buckets + offline scenarios (F-003, F-004, F-008)
- Journal: confirm Clear log; dated rows; keep trims on change (F-005, F-014, F-015)
- Tests: slash-commands-§7 steps 3/6/8/9 falsifiable (F-006, F-007)
- Hygiene: F-009..F-013, F-016
```
