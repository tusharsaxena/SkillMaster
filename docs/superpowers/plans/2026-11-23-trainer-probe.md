# Trainer probe — plan (SkillMaster#3)

Spec: `docs/superpowers/specs/2026-11-23-trainer-probe-design.md`. Branch
`feat/2026-11-23-skillmaster-trainer-probe` off `master` `0f8d652`. Every item is done when a commit
whose subject starts `<ID>: ` exists on the branch. The gate before every commit is CLAUDE.md's:
`KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0). Baseline on `0f8d652`: 817 passed,
0 failed, 1 skipped.

## Items

| ID | Item | Checkpoint |
| --- | --- | --- |
| SMP-00 | This spec and plan | committed |
| SMP-01 | The probe: `tools/trainer_probe.lua` and `tools/trainer_probe/*.lua`; `tests/test_trainer_probe.lua` drives the checks on hand-made inputs (each known error class goes red) | suite + luacheck green |
| SMP-02 | The first report, on the unchanged data: `docs/trainer-probe/2026-11-23/` | the four known errors are in it |
| SMP-03 | Fix the data: the four errors (with tests that fail on the old rows), `npcID` on every record, coordinates for every record with one standing point, `learn` on the book and quest rows | suite green |
| SMP-04 | Provenance: the second run `docs/trainer-probe/2026-11-23-r2/`, the generated `defaults/TrainerProvenance_Forever.lua` (TOC), `verified` per record, the provenance test | suite green; every record confirmed or with a reason |
| SMP-05 | The books in the UI: the popup card, chat directions and the row tooltip say how the rank is learned; the warning's wording | suite green |
| SMP-06 | Docs: smoke checks (SM-TPROBE-*), test-cases, ARCHITECTURE (provenance, module map), README, validate-seeds (ItemTree, the verified rule), forever-quirks, known-limitations | suite green |
| SMP-REV | One skeptical self-review of `git diff master..HEAD`: licensing leaks, data regressions, tests that pass without their fix | fixes committed |

## Resume

`git log --oneline master..HEAD` shows the items done. Re-run a report with the command in the
spec (D2); the external sources live outside the repo (pins in the spec), so a fresh session
re-fetches them at the same commits first. No version bump, no push.
