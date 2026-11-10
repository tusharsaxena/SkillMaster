# Analysis — 20261110-063942

- **Addon:** Ka0s Skill Master 0.1.0
- **Verdict:** green
- **Commit:** 21b1936 (feat/2026-11-10-skill-master-v1)
- **Previous run:** 20261110-025504

## Headline

The M6 record is green on all four suites under the Forever kit profile (`KA0S_KIT_CLIENT=forever`;
the addon's Clients value is `Forever`, so the default Retail profile was not run): lint 0/0 over 122
files, 397 of 398 cases passed with the same single declared skip, seven offline perf scenarios
recorded, and no function above CCN 15 ([`manifest.json`](manifest.json)). The addon grew sixfold
since the scaffold baseline and got somewhat denser per function, but nothing crossed a threshold.
Nothing to act on before the release bump.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261110-025504 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 122 files | [`lint.txt`](lint.txt) | files 43 → 122; still 0/0 |
| tests | pass | 397 passed, 1 skipped, 0 failed, 398 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 120 → 398 cases; skip count unchanged at 1 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 3 → 7 scenarios |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 10 → 15; warnings 0 → 0 |

| Metric | Value |
|---|---|
| Total NLOC | 14708 |
| Functions | 2141 |
| Avg NLOC / function | 5.8 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 52.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The one skip is the same kit diagnostics-contract case as the baseline. It covers an addon that opts
out of the report turning logging on. This addon keeps the default, so the case does not apply
([`tests.txt`](tests.txt)). It is not counted as a pass.

Complexity passes, but the ceiling is reached exactly. `Bar.PaintBorder` (`modules/Bar.lua`, lines
257–276) sits at CCN 15, the highest value the gate allows, with `Header.SetBlock`
(`modules/Blocks.lua`) and `R.FillColor` (`modules/Rows.lua`) at 14
([`complexity.txt`](complexity.txt)). None is a warning. One more branch in `Bar.PaintBorder` would
fail the release gate.

## What moved

- **lint:** 0/0 at both runs. The file count rose from 43 to 122 because the modules, settings and
  suites landed in M2–M5. The `.luacheckrc` exclusions are unchanged (`RESULTS.md`, *Lint*).
- **tests:** 120 → 398 cases, 119 → 397 passed, 1 → 1 skipped, 0 → 0 failed. The growth is the
  domain, display, broker/alerts/journal, options and sim suites ([`test-cases.md`](test-cases.md)).
- **perf:** 3 → 7 scenarios. `bonusRefresh`, `statScan`, `skillScan` and `detachedRender` are new.
  The scenarios now count API calls per iteration (commit cbfe5cb), so `windowRenderOff` at 27.0
  `api/iter` and `windowRenderOn` at 29.0 have no baseline counterpart: the baseline window rendered
  no blocks. Between the two window scenarios the difference is 2 API calls and 0.3 bytes per
  iteration ([`perf.txt`](perf.txt)). Timings are not compared across runs.
- **complexity:** NLOC 2363 → 14708 and functions 449 → 2141, which is growth. The averages measure
  density: avg NLOC/function 4.0 → 5.8, avg CCN 1.9 → 2.4, avg tokens 31.4 → 52.2. Max CCN 10 → 15,
  warnings 0 → 0, band and over-cap files 0 → 0, blind and crashed files 0 → 0.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None. `Bar.PaintBorder` at CCN 15 carries no warning, so there is nothing to rule on. The next run's
analysis says whether it moved.
