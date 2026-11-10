# 04 — Technical design: Ka0s Skill Master remediation

Keyed to the IDs in `02_DEVIATIONS.md`. Nothing here is user-facing breakage, so the order is driven by risk of regression: SM-01 touches the most code, and it comes first, while the tree is fresh.

## SM-01 (+ SM-01a, SM-01b) — every schema-row write through `NS.SetByPath`

**Shape.** Turn the call direction around. Today rows call `NS.Blocks`, and `NS.Blocks` writes the stored table. After the change, every non-panel actor calls the seam, and the seam calls the row.

1. The `layout.blocks.<id>.docked` and `.collapsed` rows (`settings/Layout.lua`) drop their `set` closures, so the schema lib writes the stored value. The side effects move into each row's `onChange`, which calls the same code the writers run today:
   - `whenSafe` combat deferral through `NS.SecureOverlay:AfterCombat`;
   - `B.Changed()` (`LAYOUT_CHANGED`).
   Watch the combat queue. Today `whenSafe` defers the **write itself**, so a collapse clicked in combat is not stored until combat ends. Keep that behavior: in combat, the header click queues `NS.SetByPath(path, v)` under the same key. Do not write first and relayout later; that would change the stored value while the overlays still sit over the old layout.
2. `B:Detach` / `:Dock` / `:SetCollapsed` / `:ToggleCollapsed` become thin callers, `NS.SetByPath(("layout.blocks.%s.collapsed"):format(id), v)`, so the header click (`modules/Blocks.lua:242`, `:246`) and the detached frame's buttons (`modules/Detached.lua:106`, `:108`) all pass the seam.
3. `B:Move(from, to)` renumbers every block. Write each changed `order` through `NS.SetByPath` inside one `NS.SchemaRuntime.BulkRun` (or `BulkBegin`/`BulkEnd`) bracket, so one drag sends one coalesced `LAYOUT_CHANGED` (the `NS.ApplyLook` bulk path already does this) and logs one bulk line. `B:SetOrder` becomes the row's `onChange` side, or is deleted if the row writes plainly.
4. The row menu's `hideRow` (`modules/Interact.lua:84-86`) calls `NS.SetByPath(kind .. ".hidden." .. key, true)`. The Skills/Stats Hide rows already resolve that path through their get/set closures over the set, so the seam reaches the right entry.
5. SM-01a closes by construction: the seam logs the settings line (debug-logging-§10). Add no host `NS.Debug` beside it, or the line is written twice.
6. SM-01b: rewrite `docs/ARCHITECTURE.md:90-96` to say the rows are plain seam writes whose `onChange` repaints, and that every actor calls `NS.SetByPath`. `docs/schema.md` follows.

**Risk.** The Layout page's drag list re-renders on `H.RefreshPanel(ctx, true)` after a move (`settings/Layout.lua:155`). Keep that line; the bulk bracket must close before it runs. The reset paths (page Defaults, Reset all) already go through `ApplyDefault` and are unaffected.

**Tests.** Write the characterization cases first (testing-§13), one each for header-click collapse, the dock button, a drag move and row-menu hide. Each asserts the stored value and the `LAYOUT_CHANGED` count. Then add cases asserting that each act reaches the seam: wrap `NS.SetByPath` and assert it was called, which goes red under the current code.

## SM-02 — finish `tests/test_disabled.lua`

Per step:
- **1** Capture `T_on = #M.__timers()` and `F_on` = every frame shown in the mocks, either the kit's shown-frame registry or an explicit list: main window, the detached frames, Journal, trainer popup, toast. Use the kit's helper if revision 53 has one.
- **3** Add `-- red under: drop NS.BusStandDown() from NS.StandDown (core/SkillMaster.lua)`.
- **5** and **6** Assert that every frame in `F_on` is hidden after disable, and that none is shown after the fires.
- **6** Add `-- red under: drop addon:UnregisterAllEvents() from NS.StandDown — OnEnterCombat runs and ends test mode`.
- **7** Dispatch `debug diagnostics` as well as `diagnostics`, and assert that neither prints the refusal line.
- **8** Drive `OnClick(nil, "RightButton")` through the kit's menu mock. Assert *Enabled* is enabled, every other entry (Locked, Test mode, Sim mode, Show window) is grayed, and the click writes nothing and shows nothing. Add a zero-shows assertion to the left-click. Then write `enabled = true`, take `NS.HOLD_PERF` and press both binding buttons. Assert that nothing toggles, exactly one `Not available during a performance capture.` line prints, and no disabled line prints. Press the journal binding while disabled too.

## SM-03 — declare the missing skin surfaces

Add three entries to `Kit.skinSwitch.surfaces` (`tests/run.lua`):
- the row tooltip: show `GameTooltip` over a mock row, then return the tooltip bar's frame;
- the broker feed tooltip: open a feed's `OnEnter`, then return the tooltip;
- the Bars page preview: build the page, then return the preview frame, marked `scope` because it is a settings-panel element under *Ignore settings panel*.

If one of them legitimately does not follow the skin, give it a `Kit.skinValues` row naming the skinning-§9 cause instead.

## SM-04 — counts as rules

In `docs/ARCHITECTURE.md`'s Documentation map, write the Tier 2 trigger cells as the rule plus a dated measurement, for example "`NS.COMMANDS` carries eight or more commands (23 as measured on 2026-11-10)". Correct the compat cell to 9 shims. Do the same for `docs/module-map.md:40` "the eight blocks": name them, or point at `NS.BLOCKS`.

## SM-05 — the missing event row

Add `| PLAYER_EQUIPMENT_CHANGED | modules/Detached.lua at load, on its own bus target | onEquipmentChanged: re-render the detached weapon block and re-sync the overlays while it is shown | a weapon swap changes the weapon block |` to `docs/ARCHITECTURE.md` → Event Subscriptions, and mirror it in `docs/data-flow.md`.

## SM-06 — perf buckets for the event paths

Add Shape A brackets around the bodies these schedule:
- `Bonuses.Refresh` (key `bonusRefresh`);
- `StatData`'s flush (`statFlush`);
- `SkillData:Scan` (`skillScan`).

Declare the buckets in `core/PerfSetup.lua`, each with `within` only where it really nests, and pin each as reached in `tests/test_perf.lua` (performance-§3). Each module needs a load-time upvalue `local Perf = NS.Perf`. All three modules load after `core/PerfSetup.lua`, so their TOC positions are unchanged.

## SM-07 — screenshots before publish

Before the first CurseForge upload, add `media/screenshots/` with captioned images and a `## Screenshots` section between the description and `## Usage`. Add `- media/screenshots` to `.pkgmeta` in the same change (packaging).

## SM-08 — superpowers pairing

This is the owner's call. Either `git mv` the plan and its ledger to `2026-11-10-skill-master.md` / `2026-11-10-skill-master-STATUS.md` (updating `docs/ARCHITECTURE.md:11-12`), or leave them, since this is a SHOULD and this bundle records it.

## SM-09 — TOC conventional note

Add one line under `# Core -- dependency-correct order (layout-§1)`: `# Conventional unless marked LOAD-BEARING: each reaches the others at CALL time.`

## SM-10 / SM-11 — release bookkeeping (Info)

At the 1.0.0 release:
- `bump-version` moves the TOC to `1.0.0` and dates the README row.
- A full `run-automated-tests.sh` run writes the release bundle and its `ANALYSIS.md`, with `## Preview and simulation data` now reviewing `modules/Preview.lua`, `defaults/Preview_Forever.lua` and `modules/Simulator.lua`.

## SM-12 — optional

Publish `NS.Perf.EncodeJSON` from `core/PerfSetup.lua` (the library's function when live, nil in the stub) and have `modules/Probe.lua` read it there.
