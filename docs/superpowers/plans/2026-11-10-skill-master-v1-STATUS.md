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
| 2.1 SkillData | todo | |
| 2.2 Bonuses | todo | |
| 2.3 StatData | todo | |
| 2.4 Trainers/Helpers | todo | |
| 3.1 Bar | todo | |
| 3.2 Blocks/windows | todo | |
| 3.3 Interactions | todo | |
| 4.1 Broker | todo | |
| 4.2 Alerts | todo | |
| 4.3 Log/Alts/Journal | todo | |
| 5.1 Options | todo | |
| 5.2 Test/Sim | todo | |
| 5.3 Locales/bindings/diag | todo | |
| 6.x Docs/battery/audit/review | todo | |
| 7.x Merge + cleanup | blocked on owner go | |

## Branches / worktrees created by this run (for cleanup)
- SkillMaster: `feat/2026-11-10-skill-master-v1`
- dev-copilot: `feat/2026-11-10-single-client-forever` (worktree `#Worktrees/dev-copilot-forever-only`, pushed)
- WowAddonStandards: branch `feat/2026-11-10-single-client-forever` (local + origin), worktree `#Worktrees/WowAddonStandards-forever-only`
