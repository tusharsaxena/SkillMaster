Delta: LibKa0s v1.112.0 -> v1.113.0

Recorded for item FB2-SM-01 of Ka0sAddonsCommonTasks `docs/2026-11-24-FEEDBACK_BATCH/` (round 2,
`R2_SMOKE_FEEDBACK.md`, decisions D1 to D3). It follows the copy, provenance, icon-declaration and prune mechanics of
`/dev-copilot:wow-revendor-libka0s`. The adoption interview and the issue filing are skipped because the run's bundle
pre-decides the work. The payload comes from the local tag: `git -C ../LibKa0s archive v1.113.0 LibKa0s testkit tools`
(tag local only for this run).

## Step 0 pre-flight

The newest single-tag bundle is `2026-11-24-v1.112.0`, base v1.109.0, and the provenance line before this re-vendor
named v1.112.0 (CLAUDE.md:40), set by `c8306ed`. Result: ok, no base correction.

## 3a Base

- Before the copy, `diff -rq --strip-trailing-cr` of the v1.113.0 extract against `libs/LibKa0s` printed only
  `Sim.lua` and `WidgetsDropdown.lua` (beside the pruned media), and against `tests/_kit` printed nothing.
- Range: `git -C ../LibKa0s log --oneline v1.112.0..v1.113.0` is 10 commits (FB2-LK-01..03, FB2-LK-REL, FB2-LK-REV).

## 3b/3c Per-file minors that moved

| File | Old | New |
|---|---|---|
| Sim.lua | MINOR 4 | 5 |
| WidgetsDropdown.lua | DROPDOWN_MINOR 3 | 4 |

No file was added or removed. Kit revision stays 60.

## 3d Diffs

After the copy and the prune, the only differences from the extract are `Only in <extract>/LibKa0s/media/icons` (the
undeclared icons) and `Only in <extract>/LibKa0s/media/sounds` (362 files removed by the prune).

## 3e Consumption map

Sim (`core/SimSetup.lua`, `modules/Simulator.lua`, `modules/Preview.lua`) and Widgets (`core/WidgetsSetup.lua`,
`modules/Journal.lua`'s character `W.Dropdown`, the settings pages' dropdowns) both moved and both are consumed.

## 3g Contract delta

- **Sim minor 5: a successful `sim:Start` shows the step panel.** This addon's starts (`/sm sim`, `/sm sim start`,
  the panel's Start, the Master controls Sim box) all run the library's `Start`. Proved per path in
  `tests/test_sim_start_panel.lua` (FB2-SM-01).
- **Sim minor 5: `Sim.SampleCrowd` and rule 6 retired.** The addon's sample people already come from `Sim.Sample`
  (AD-87-SM); its own fallback copy is retired in FB2-SM-01.
- **WidgetsDropdown minor 4: a selected row stands off a plain row.** The Journal's character dropdown and the
  settings dropdowns are the library's; proved in `tests/test_dropdown_selected.lua` (FB2-SM-01).
- No suite pins `Sim 4` or `WidgetsDropdown 3`. No blocker.

## 3i Icon declaration

Kept unchanged (CLAUDE.md:41); the prune refused nothing. README credits unchanged.
