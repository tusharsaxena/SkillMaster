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
| 5.1 Options | done | 71df5f5, merged in b9fddca; 193 schema rows (160 library-absent); integration: `skills.helperHint` (under-row hint, off) split from the new `skills.helperTooltip` (tooltip helpers, on), rows for both and for `layout.blocks.weapon.belowCapOnly`, `journal.size` named drag state, broker right-click opens the Broker page (seam suite `test_m5_seams`); open: `bars.colors.fromSkin` default false vs skinning-§6; no fill direction/columns/strata rows; not run in the client |
| 5.2 Test/Sim | done | f7625d9, merged in f767d92; SessionLog constructor keeps the `journal.keep` cap; diagnostics `sim` section after the domain sections, `state` carries `simMode`; not run in the client |
| 5.3 Locales/bindings/diag | done | 1d23d09, merged in bbcd089; M5 polish (c0779cc) merged first in 5537d01; integration routed the Skin rows, the settings stubs and the sim line through `L`; open: the second (Journal) binding needs owner sign-off (launcher-§6), 22 font-unsafe glyphs remain, stub locale set chosen by the agent |
| M5 leftovers | done | c52a8ba HUD colors follow the skin by default (sm.cat.* / sm.bonus* owner tokens; no FollowOnce, born on v1.94.0); 18b4376 fill direction, window/detached strata, columns; b7912d4 no pin in a simulation, sample broker tokens in test mode; 5f0f628 17 font-unsafe glyphs replaced + glyph guard test; ecd6515 Forever profile pinned in-repo (`tests/client_pin.lua`); Bindings.xml checked against launcher-§6, compliant (Show window first, one category, no header) |
| 6.1 Docs | done | 6f07dc9; README 1.0.0 row (TOC stays 0.1.0 until the bump), ARCHITECTURE ten sections, smoke design §9 table; audit doc corrections (seam wording, dated Tier 2 counts, the detached PLAYER_EQUIPMENT_CHANGED row) in eaa47c4, the F-001 deviation row and Known Limitation in e3303bc |
| 6.2 Automated-test bundle | done | af4bc94, bundle `docs/automated-tests/20261110-063942` measured 21b1936 on the Forever profile: green, lint 0/0 (122 files), 397 passed + 1 skip of 398, 7 perf scenarios, max CCN 15 (`Bar.PaintBorder`), 0 warnings, 0 blind/crashed |
| 6.3 Standards audit | done | bundle 4b72a98 (docs/audits/2026-11-10, v2.105.0 at 3d6855f); MUST fixes: SM-01/01a/01b + SM-02 eaa47c4, SM-03 62e5c0f, SM-05 eaa47c4; SHOULD: SM-04 eaa47c4, SM-06 cbfe5cb, SM-09 1a52d35, SM-12 c6ef3d0; open: SM-07 screenshots (before publish), SM-08 plan topic name (owner), SM-10/11 at the release bump |
| 6.4 WoW review | done | bundle 4b72a98 (docs/reviews/2026-11-10); F-001 e3303bc (+ localization-§4 deviation row), F-002 eaa47c4, F-003 91f4261, F-004/F-011 1a52d35, F-005/F-014/F-015 5ca1fd2, F-006/F-007/F-012 eaa47c4, F-008 cbfe5cb, F-010/F-013/F-016 c6ef3d0; open: F-009 (overlay under the Journal, needs the client) |
| 6.5-6.6 LibKa0s issue, push, report | done | LibKa0s #80 (bar widget), #81 (launcher extra entries); all three branches pushed; owner report 2026-11-10 |
| 7.x Merge + cleanup | blocked on owner go | |

## Branches / worktrees created by this run (for cleanup)
- SkillMaster: `feat/2026-11-10-skill-master-v1`
- dev-copilot: `feat/2026-11-10-single-client-forever` (worktree `#Worktrees/dev-copilot-forever-only`, pushed)
- SkillMaster M3/M4 worktrees `#Worktrees/skm-m3/display`, `skm-m4/{broker,alerts,journal}` and branches `m3/display`, `m4/*`: removed after the M3+M4 integration
- SkillMaster M5 worktrees `#Worktrees/skm-m5-{options,testsim,locales,polish}` and branches `m5/*`: removed after the M5 integration
- WowAddonStandards: branch `feat/2026-11-10-single-client-forever` (local + origin), worktree `#Worktrees/WowAddonStandards-forever-only`
