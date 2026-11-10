# 02 — Deviations: Ka0s Skill Master

Audited against Ka0s WoW Addon Standard **v2.105.0**, read from the local worktree (see `01_CURRENT_STATE.md`). Prefix **`SM-`**, first audit.

Grades measure impact (`AUDIT.md` step 5), not rule strength. A doc-only or test-only MUST failure is graded Low, and its entry still names the MUST. The register holds no rows and the issue store is empty, so there is no recorded deviation to accept, and none is filed as one.

## Tally

| Basis | High | Medium | Low | Info | Total |
|---|---|---|---|---|---|
| **Headline** (roots only) | 0 | 0 | 9 | 3 | **12** |
| **All entries** (roots + `derived from` dependents) | 0 | 0 | 11 | 3 | **14** |

| MUST failures | Roots | All entries |
|---|---|---|
| Count | **4** (SM-01, SM-02, SM-03, SM-05) | **6** (adds SM-01a, SM-01b) |

SHOULD failures (roots): SM-04, SM-06, SM-07, SM-08, SM-09. Info: SM-10, SM-11, SM-12.

**Verdict: minor deviations.** No finding reaches a player's session or SavedVariables today. The addon was built to this standard and its gates are green: lint 0/0, 373/1/374 under the Forever profile, `diff -r` empty, line endings 0 strays, packaging clean.

## Deviations

| ID | Section | Grade | Rule | Description | Fix direction |
|---|---|---|---|---|---|
| **SM-01** | architecture-§5 | Low | MUST | Schema-row paths are written outside the single write seam `NS.SetByPath`. A block header click, the dock and detach buttons, and the Layout drag list write `layout.blocks.<id>.collapsed`, `.docked` and `.order` through `NS.Blocks` writers that assign the stored table directly. The row menu's *Hide this row* writes `skills.hidden.<key>` / `stats.hidden.<key>` directly (`modules/Interact.lua:85`). Rows address every one of these paths (`settings/Layout.lua:75`, `:79`; `settings/Skills.lua:23`). The seam's validate → write → onChange path, its settings-change log line and its panel refresh are skipped for these writes. | Invert the direction. Every non-panel writer (header click, dock button, drag list, row menu) calls `NS.SetByPath(path, v)`. The rows' `set` closures keep only the combat-deferral (`whenSafe`) and the `LAYOUT_CHANGED` send, or that logic moves into the rows' `onChange`. `B:Move` writes each changed `order` through the seam inside one bulk bracket. |
| SM-01a | debug-logging-§10 | Low | MUST | Derived from SM-01. A collapse, dock, detach, reorder or row-menu hide writes a setting and logs no settings line, because §10's one line is written at the seam these writes skip. No `NS.Debug` exists in `modules/Blocks.lua` or in `modules/Interact.lua`'s `hideRow`. | Closes with SM-01. |
| SM-01b | documentation-§3 | Low | MUST | Derived from SM-01. `docs/ARCHITECTURE.md:90-96` presents the bypass as the design ("so a row, a header click and `/skm set` take one path", that path being `NS.Blocks` rather than the seam), and `## Documented deviations` holds no row for it. | Rewrite the paragraph when SM-01 lands. Do not add a register row unless the owner ratifies the bypass. |
| **SM-02** | slash-commands-§7 (*The conformance test every addon ships*), testing-§12 | Low | MUST | `tests/test_disabled.lua` covers the ten steps only in part. Missing: step 1's `T_on`/`F_on` baseline; the `-- red under:` comment on steps 3 and 6; step 5 and step 6's zero-shows over every frame in `F_on` (only the main window is checked); step 7's `debug diagnostics` form; and step 8's `RightButton` options menu (Enabled live, the rest grayed, nothing written), zero shows on the left-click, and the binding press under the `perf` hold alone (both bindings). Steps 2, 3 (count), 4, 6 (reach per event), 7 (every row), 9 and 10 are covered. | Extend the suite step by step, as `05_EXECUTION_PLAN.md` S2 lists. Add a red-under comment naming the mutation for steps 3 and 6. |
| **SM-03** | skinning-§9 (anti-pattern #110) | Low | MUST | `Kit.skinSwitch.surfaces` (`tests/run.lua:60-94`) declares six surfaces. It omits three the addon paints from skin tokens: the row tooltip's bar (`modules/RowTooltip.lua:212`), the broker feed tooltip's bars and token-colored text (`modules/Broker.lua:133`, `:235`), and the Bars page's live preview (`settings/Bars.lua:185`). Coverage is the declaration, so these three are never switch-tested. | Add the three surfaces with build/reset closures. Mark the preview `scope`, because it is a settings-panel element. |
| **SM-04** | documentation-§6 | Low | SHOULD | Undated hand counts of the repo's own tree sit in live docs. One is already wrong: the Documentation map says `core/Compat.lua` "publishes three addon-specific shims" (`docs/ARCHITECTURE.md:232`), but the family grep counts 9. Also undated: "23 commands" (`:227`), "Six messages" (`:233`), "the eight blocks" (`docs/module-map.md:40`). The Tier 2 *answer* stays right (9 ≥ 3, so the doc is owed and present). | Write the trigger cells as rules ("three or more shims; present") or date them. Correct the 3 → 9. |
| **SM-05** | documentation-§3 (`ARCHITECTURE.md` → Event Subscriptions) | Low | MUST | The Event Subscriptions table and the bus-subscriber paragraph (`docs/ARCHITECTURE.md:136-152`) omit `modules/Detached.lua:210`, the detached weapon block's `PLAYER_EQUIPMENT_CHANGED` on its own bus target. | Add the row (registered by `modules/Detached.lua` at load, handler `onEquipmentChanged`, re-renders the weapon block and re-syncs overlays). |
| **SM-06** | performance (adoption strength: coverage is a SHOULD) | Low | SHOULD | The harness declares one bucket, `windowRender` (`core/PerfSetup.lua:29-30`). The per-event and per-tick paths are unbracketed: `UNIT_AURA` / `UNIT_INVENTORY_CHANGED` → `Bonuses.Refresh` (`modules/Bonuses.lua:322`), the 1 s bonus ticker (`:302`), `StatData`'s burst flush (`modules/StatData.lua:278`), and `SkillData:Scan` (`modules/SkillData.lua:235`). A capture cannot attribute their cost. | Add Shape A brackets and declared buckets (`bonusRefresh`, `statFlush`, `skillScan`) and pin each as reached in `tests/test_perf.lua`. |
| **SM-07** | documentation-§1 item 4 | Low | SHOULD | README has no `## Screenshots` section. That is a SHOULD while the addon is unpublished and becomes a MUST at first publish. | Add captioned images under `media/screenshots/` (and its `.pkgmeta` ignore line) before publishing. |
| **SM-08** | documentation-§3 (*The shape of `docs/superpowers/`*) | Low | SHOULD | The plan `plans/2026-11-10-skill-master-v1.md` and its ledger `…-v1-STATUS.md` do not share the spec's topic (`specs/2026-11-10-skill-master-design.md` → `skill-master`), so the pairing by topic fails. The files were written after v2.102.0, so the history exemption does not reach them. | The owner may leave the files as they are (a SHOULD, recorded here) or rename them to the shared topic before the bundle freezes. |
| **SM-09** | toc-file-§5 | Low | SHOULD | The `# Core` group labels its load-bearing lines but never marks the conventional ones. `core\State.lua`, `core\EnvSetup.lua`, `core\PoolSetup.lua` and `core\Database.lua` (`SkillMaster.toc:64`, `:65`, `:73`, `:84`) carry no label. Each is conventional: every reader of what they publish reads it at call time. | Add one group-level "Conventional unless marked" note, or label the four lines. |
| **SM-10** | automated-tests-§4 / §6 | Info | — | The only run bundle, `20261110-025504` (manifest `release: "0.1.0"`, a scaffold record), measured `9a66b14`, 42 commits behind HEAD, at 2363 NLOC / 449 functions / max CCN 10. Today's sighted run reads 14078 NLOC / 2043 functions / max CCN 15, with 0 warnings. The record describes a tree that no longer exists. The checkpoint is release, and the addon is unreleased, so this is a release-process note and not a finding. | Cut a full `run-automated-tests.sh` bundle with `ANALYSIS.md` (including `## Preview and simulation data`) at the 1.0.0 release. |
| **SM-11** | documentation-§1 item 11 / versioning-git | Info | — | README Version History's top row is `1.0.0 \| Unreleased`, while the TOC is `## Version: 0.1.0`. This is intentional and stated (`docs/ARCHITECTURE.md:19-20`), and it resolves at the release bump. | `bump-version` moves the TOC to 1.0.0 and dates the row in one change. |
| **SM-12** | library-stack-§7 (one setup file per module) | Info | — | `modules/Probe.lua:189` resolves `LibStub("LibKa0s-Perf-1.0", true)` directly for `EncodeJSON` instead of reaching it through `core/PerfSetup.lua`. It is nil-guarded (`:190`), so it degrades. `modules/Probe.lua:144` reads `GetBuildInfo()` only to report the build. That is not a clients-§3 client decision. | Optional: expose `NS.Perf.EncodeJSON` (or a nil stub member) from `core/PerfSetup.lua` and read it there. |

## Checked and not filed

These were checked and are compliant, or sit outside a rule's scope. Evidence is in `03_EVIDENCE.md`.
- clients-§9 shape, reason and suite pin.
- toc-file-§1 / §3, and the `IconTexture` TGA header.
- Vendored payloads: both `diff -r` empty, and the icon subset is exact.
- Provenance and icons lines, README badge, logo, inventory, numbered lists, `/skm skin`, Reporting a bug and Credits.
- The latch and teardown; the registration census is empty after disable.
- Launcher: one object, labels, toggles on handlers, minimap row path and reset veto.
- Bindings shape.
- Diagnostics: one row, `DebugVerb` first, stub answers.
- Library debug sinks passed to all four descriptors.
- Bus constants and casing.
- Close-button wrapper only; no settings-window close in combat.
- Frame layering through `LAYERS`, windows `SetToplevel`.
- Display glyphs in the safe set.
- Skin adoption, Skin tab, Keybindings tab last, `KEYBINDS_UNCHANGED`.
- No `LSM30_`, no reorder arrows, no `EllesmereUIDB`, no `stockDefault`.
- Lint scope; line endings (body identical, 0 strays, gate wired); packaging (a)/(b)/(c) clean.
- Tier 1/2 docs and four-table map; vendored quirks block identical.
- Test inventory equals `--list`, badge 373/373.
- Complexity sighted (kit 53), 0 warnings, watch list empty.
- slash-commands-§8 lock/unlock (MAY, present and seam-routed).
- No register rows and no issues, so the register checks have nothing to fire on.
