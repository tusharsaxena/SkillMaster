# Analysis — 20261110-025504

- **Addon:** Ka0s Skill Master 0.1.0
- **Verdict:** green
- **Commit:** 9a66b14 (feat/2026-11-10-skill-master-v1)
- **Previous run:** none — this is the first

## Headline

The scaffold's first record is green on all four suites under the Forever kit profile: lint 0/0,
119 of 120 cases passed with one declared skip, three offline perf scenarios recorded, and no
function above CCN 10. Nothing to act on; this run is the baseline every later bundle diffs against.

## Suites

| Suite | Status | Result | Artifact | Moved since none |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 43 files | [`lint.txt`](lint.txt) | first run |
| tests | pass | 119 passed, 1 skipped, 0 failed, 120 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | first run |
| perf | pass | 3 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | first run |

| Metric | Value |
|---|---|
| Total NLOC | 2363 |
| Functions | 449 |
| Avg NLOC / function | 4.0 |
| Avg CCN | 1.9 |
| Max CCN | 10 |
| Avg tokens / function | 31.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skip is the kit's diagnostics-contract case for an addon that opts out of the report turning
logging on; this addon keeps the default, so the case does not apply ([`tests.txt`](tests.txt)).

## What moved

First run — nothing to diff against; every figure above is a baseline reading.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Preview and simulation data

- **Answer:** Current
- **Asked:** 2026-11-10, by hand (scaffold record, not a tag)
- **Files reviewed:** the test-mode strip in `modules/MainWindow.lua`; there is no sample data or simulator yet
- **Commits since the previous release touching them:** none — no previous release
- **Note:** test mode marks the window but has no placeholder rows until the blocks land (plan T3.2); the
  Dwarf Hunter fixture and the simulator are plan T5.2.

## Actions

None.
