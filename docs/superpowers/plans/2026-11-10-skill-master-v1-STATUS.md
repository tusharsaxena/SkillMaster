# Skill Master v1 — Status ledger

Resume rule: read this table plus `git log --oneline`, then start at the first row that is not `done`.
Plan: `2026-11-10-skill-master-v1.md`. Update a row in the same commit that finishes its task.

| Task | Status | Commit / note |
|---|---|---|
| Design + mockup | done | dd75fbf; approved by owner 2026-11-10 |
| Plan | done | this commit |
| 0.1 Standards: Forever value | done | WowAddonStandards 3d6855f on `feat/2026-11-10-single-client-forever` (pushed, not merged); v2.105.0, clients-§9; renumber at merge if another branch takes v2.105.0 |
| 0.2 dev-copilot value check | done | dev-copilot 3f93791 + c7133ca on `feat/2026-11-10-single-client-forever` (pushed, not merged): `Forever` value, 2.9.0 |
| 1.1 Scaffold | done | 7c58239 libs, 9a66b14 scaffold, d61f038 first automated-test bundle (green, 119/120, 1 skip); Sim mode deferred to 5.2; placeholder logo |
| 1.2 Probe | done | d5acab3; assumed-API table lives in `docs/midnight-quirks.md` (the standard's quirk file, client-quirks-§1) instead of the plan's `docs/client-quirks.md`; kit Forever set lists skills as `C_SkillInfo.*`, enchant as `C_Item.*`; owner to run `/skm probe` |
| 2.1 SkillData | done | 0aadd86, merged in 2ced847; `core/Compat.lua` (skill-list adapter, both shapes) and `docs/compat-layer.md` created |
| 2.2 Bonuses | done | 091a728, merged in f4444bc; built on `modifier`; lure tooltip wording a guess until the probe |
| 2.3 StatData | done | 7c09297, merged in b81aa9f; events on its own bus target, `test_disabled` step 6 fires on every target |
| 2.4 Trainers/Helpers | done | 450ccd3, merged in 077956f; helpers published as `NS.SkillHelpers` (`NS.Helpers` is the options library); plan's fist-weapon trainer corrected to Buliwyf Stonehand / Ilyenia Moonfire |
| 3.1 Bar | done | 46d4c3a, merged in 792c776; `NS.Bar` styles row/compact/tooltip/mini, bonus clamped at the end; not yet run in the client |
| 3.2 Blocks/windows | done | bfbefdc, merged in 792c776; the M1 window extended in place; layout/bars/skills/stats state has no settings rows until 5.1 |
| 3.3 Interactions | done | fe7dc00, merged in 792c776; overlays on UIParent at absolute coordinates; overlay geometry and the Forever API shapes unverified in game |
| 4.1 Broker | done | 6539729, merged in d257a6f; integration: mini bars on `NS.Bar`, `broker.categoryColors` dropped for `bars.colors`, crafting row -> `MainWindow.ShowAndScrollTo`; no launcher Journal entry (Launcher minor 9 has no hook) |
| 4.2 Alerts | done | fa0bc74, merged in 547fc27; cap-toast click -> real `NS.Waypoints:Set` (seam test); no settings rows until 5.1 |
| 4.3 Log/Alts/Journal | done | e6cf6c4, merged in e72d438; Alts keyed by `db.keys` (realm + full name), not `UnitFullName`; mini bars on `NS.Bar`; title-bar journal mark wired |
| 5.1 Options | todo | |
| 5.2 Test/Sim | todo | |
| 5.3 Locales/bindings/diag | todo | |
| 6.x Docs/battery/audit/review | todo | |
| 7.x Merge + cleanup | blocked on owner go | |

## Branches / worktrees created by this run (for cleanup)
- SkillMaster: `feat/2026-11-10-skill-master-v1`
- dev-copilot: `feat/2026-11-10-single-client-forever` (worktree `#Worktrees/dev-copilot-forever-only`, pushed)
- SkillMaster M3/M4 worktrees `#Worktrees/skm-m3/display`, `skm-m4/{broker,alerts,journal}` and branches `m3/display`, `m4/*`: removed after the M3+M4 integration
- WowAddonStandards: branch `feat/2026-11-10-single-client-forever` (local + origin), worktree `#Worktrees/WowAddonStandards-forever-only`
