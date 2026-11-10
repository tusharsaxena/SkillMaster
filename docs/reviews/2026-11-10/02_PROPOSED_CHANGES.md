# 02 — Proposed changes (HLD + LLD)

**Standards source:** WowAddonStandards **v2.105.0**, read from the local worktree `#Worktrees/WowAddonStandards-forever-only` at `3d6855f1cd266a84d40e026e15870395f8a047f3`. The tree is clean. Its HEAD is not GitHub master: per the caller, master lacks the Forever-only amendment. I used this worktree on the caller's instruction rather than through the overlay's three-check sibling rule. Every change below was checked against it.

No change below touches `libs/` or `tests/_kit/`.

## HLD — themes

### T1. Locale-independent game data (F-001)
- **Rationale:** localization-§4 requires matching on IDs or tokens. Two of the three sites have an ID route today: the crafting spell (spell ID → name), and possibly the skill line (if `/skm probe` shows a skill-line ID in Forever's `C_SkillInfo` struct).
- **No ID available:** the 1.12 positional API has no ID. There the compliant fallback is to put the skill-line and header strings into each locale's file. The stubs already name this as their first job.
- **Rejected:** a hardcoded table of translations inside `SkillData.lua`. It bypasses the locale module (localization-§1).
- **Rejected:** gating the addon off on non-enUS clients. That is scope removal, not a fix. It could be an interim owner decision, recorded as a deviation row.

### T2. One write path for row hiding (F-002)
- Route the row menu's Hide through `NS.SetByPath` (architecture-§5).
- Give the `skills.hidden` and `stats.hidden` sets a clear-all row that the page Defaults reaches.
- **Rejected:** a host-side "unhide unknown" slash verb. It would add a second write path.

### T3. Stat-path churn (F-003, F-004, F-011, F-012)
- The speed tick reads speed only.
- The detached render gets a signature short-circuit.
- `UNIT_*` listening moves to the sanctioned unit-filter frame (events-frames-taint-§1). The frame is created on stand-up and destroyed on stand-down through the existing latch: no second teardown path (slash-commands-§7, anti-pattern #85 guidance).
- **Trade-off:** one private frame. It is sanctioned only if it does `RegisterUnitEvent` plus one dispatching `OnEvent`, nothing else.

### T4. Destructive-action UX (F-005, F-014, F-015)
- Confirm before Clear log, using the same StaticPopup pattern as Forget.
- Show the date on log rows from other days.
- `journal.keep` trims only when the setting itself changes.

### T5. Evidence that can fail (F-006, F-007, F-008)
- Complete slash-commands-§7 steps 3, 6 and 8, with `-- red under:` comments (testing-§12).
- Make step 9 assert on the stand-up path.
- Declare and bracket the hot paths (performance-§2).
- Add scenarios to `tests/perf.lua`: Bonuses refresh, Detached refresh, and render with instrumentation absent (performance-§9).
- Measure or drop `api/iter`. Scenarios stay out of the test count (testing-§7).

### T6. Overlays under covering windows (F-009)
- Re-sync overlays when an addon-owned window in the same strata is raised over their host.
- Hide an overlay whose row center is under such a window.
- Verify in client before coding (SM-9).

### T7. Small hygiene (F-010, F-013, F-016)
- Degraded Bus stub tracks targets.
- Use one format key per joined line.
- `ipairs` over a list with a possibly-nil head.
- Use the brand constant in MasterControls.

## Upstream change-set

None. No `[upstream]` finding was raised.

## LLD

### C-01 — Crafting overlay casts by spell ID-derived name (F-001, part)
- **Files:** `defaults/SkillCatalog_Forever.lua` (add `openSpellID` to each `craft(...)`, and Smelting for mining); `modules/SecureOverlay.lua` `spellFor`.

```lua
-- before (SecureOverlay.lua:62)
return cat and cat.openSpell and L[cat.openSpell] or nil
-- after
local id = cat and cat.openSpellID
local name = id and NS.Compat.SpellName(id)      -- new Compat shim: C_Spell.GetSpellName / GetSpellInfo
return name or (cat and cat.openSpell and L[cat.openSpell]) or nil
```

- **Risk:** vanilla professions have one spell ID per rank. Any rank's ID gives the rank-free localized name, and that name casts the highest known rank. The IDs must be confirmed by `/skm probe` on Forever. Mark them `verified = false` like the rest of the catalog.
- **Standards:** localization-§4 (IDs flow to names). The new shim lives in `core/Compat.lua` (compat). `.luacheckrc` gets `C_Spell`/`GetSpellInfo` read globals.
- **Tests:** add a case "overlay spell resolves through the ID on a non-enUS mock". This moves the pass count, so regenerate `docs/test-cases.md` and update the badge in the same change.

### C-02 — Skill-line and header strings per locale (F-001, part)
- **Files:** `locales/<xx>.lua`, the T2.1 block keys (skill-line names, aliases, the three excluded headers).
- If the probe shows a skill-line ID, add `skillLineID` to the catalog instead. Then `SkillData.classify` matches on it first and the name map becomes the fallback.
- **Interim:** a README FAQ line and an ARCHITECTURE Known Limitations bullet saying non-enUS clients are unsupported until the strings land.
- **Tests:** a deDE-mock case that a German "Kochkunst" line lands on `cooking`, plus inventory and badge.

### C-03 — Hide through the seam, and a clearable set (F-002)
- **Files:** `modules/Interact.lua` `hideRow`; `settings/Skills.lua`.

```lua
-- Interact.lua hideRow, after
local kind = row.kind == "stat" and "stats" or "skills"
local ok = NS.SetByPath(kind .. ".hidden." .. row.entry.key, true)
```

- **Simpler and preferred:** register one set-level row per kind, with `path = "skills.hidden"`, `type = "table"` (or the library's set type, if Options offers one), `default = {}`, and `skipRender = true`. The page's Defaults then resets the whole set, unknown keys included.
- The menu writes go through a `writeThrough` of `skills.hidden.<key>`. If the library cannot address a dynamic key, the alternative is to hide the menu entry on rows with no schema row.
- Pick one variant in implementation and cite options-ui and architecture-§5 when you do.
- **Tests:** "a hidden `other:` row is shown again by the Skills page Defaults". Inventory moves.

### C-04 — Speed tick reads speed only (F-003, part)
- **File:** `modules/StatData.lua` `WatchSpeed`. The ticker calls a new `S:SpeedTick()`. It reads `NS.Compat.UnitSpeed("player")`, compares with the last value, and only then updates the two speed entries in place and sends `STATS_UPDATED`.
- **Expected movement:** fewer `Scan` calls per second while idle. Confirm with the new perf scenario from C-07.

### C-05 — Detached render short-circuit (F-003, part)
- **File:** `modules/Detached.lua`.
- Split `D.Refresh(relayout)`. `applyPoint` runs only on first show, on `relayout = true` (LAYOUT_CHANGED or a settings change) and on a profile switch.
- Data repaints call a values-only `D.RefreshValues()` when the frame's entry-key signature is unchanged, mirroring `W.Render`'s `lastSig`.
- `modules/Blocks.lua:374-378` `repaint` then calls `NS.Detached.Refresh(false)`.
- **Risk:** the detached weapon block's `belowCapOnly` filter changes the row set on a rank change. The signature must include the keys, like the main window's.

### C-06 — Unit-filter frame for player-only `UNIT_*` (F-004, F-011)
- **New file:** `core/UnitEventsSetup.lua`, placed after `core/Bus.lua` in the TOC with a LOAD-BEARING comment. The file creates one frame.
- `NS.UnitEvents.Register(event, handler)` records `(event → handler)`.
- `StandUp` calls `NS.SafeRegisterUnitEvent(frame, event, NS.rejectedEvents, "player")` for each recorded event.
- `StandDown` calls `frame:UnregisterAllEvents()`.
- The frame has one `OnEvent` that dispatches. It does nothing else (events-frames-taint-§1 carve-out).
- Hooked into `NS.RegisterRuntime` and `NS.StandDown` (`core/SkillMaster.lua`), so it sits under the one latch (slash-commands-§7).
- Bonuses (`UNIT_INVENTORY_CHANGED`, `UNIT_AURA`) and StatData's five `UNIT_*` events move onto it.
- StatData `context()` reads `NS.Compat.PlayerLevel()` (F-011).
- **Tests:** `test_disabled` step 2-3 already asserts an empty registration set, so it covers the new frame (the kit records `RegisterUnitEvent`). Add a case that a non-player `UNIT_AURA` never reaches the handler.
- **Risk:** the simulator delivers `UNIT_AURA`/`UNIT_INVENTORY_CHANGED` via `H.HANDLERS`. Keep `NS.addon:OnBonusesUnitChanged` as the dispatched handler so `Simulator.lua:120` still works.

### C-07 — Perf evidence (F-008)
- **`core/PerfSetup.lua`:** buckets `bonusesRefresh`, `skillScan`, `statScan`, `detachedRender` and `brokerRefresh`, in report order. Each is bracketed with the gated idiom at its function. Nesting: `statScan` sits inside nothing; `windowRender` may contain `Bonuses:Breakdown` but not `bonusesRefresh`. Say so with `within` where it applies.
- **`tests/perf.lua`:** scenarios `bonusesRefresh`, `detachedRefresh` and `windowRenderAbsent`. The last swaps `NS.Perf` for `{ on = false }` with no `Note`, matching the absent-instrumentation baseline.
- Either count API calls through the mocks' call recorder or remove the `api/iter` column.
- **`docs/performance.md`:** rewrite the bucket table and remove the line-20 promise.
- **`tests/test_perf.lua`:** "every declared bucket is reached" now covers five more buckets, which may move the inventory count.

### C-08 — Clear log confirmation, dates and trim rule (F-005, F-014, F-015)
- **`modules/Journal.lua`:**
  - Add `StaticPopupDialogs.SKILLMASTER_CLEAR_LOG`, the same shape as `SKILLMASTER_FORGET_ALT`. The button calls `J.ConfirmClear()`. A sim session's override list is cleared without a prompt.
  - In `bindLogRow`, use `date("%H:%M", e.t)` when `date("%x", e.t) == date("%x")`, else `date("%m-%d %H:%M", e.t)`. The format belongs in a locale key.
- **`modules/SessionLog.lua`:** `SL:Add` trims only to `max(cap(), #log_at_load)`, or the trim moves into the `journal.keep` row's `onChange`.
- Add the new locale keys to `locales/enUS.lua`; `test_locale` already requires that.

### C-09 — Test completeness (F-006, F-007)
- **`tests/test_disabled.lua`:**
  - Add `-- red under: drop addon:UnregisterAllEvents() in NS.StandDown` to step 3.
  - Add `-- red under: remove the NS.BusStandDown() call` to step 6.
  - Step 8 gains: zero-show assertions; `"RightButton"` through the kit menu mock (Enabled clickable, the rest grayed, zero writes and shows); the binding re-invoked under `HOLD_PERF` alone, asserting one `Not available during a performance capture.` line; and the Journal binding button.
  - Step 9 drops line 168's `NS.addon:OnEnable()`. Instead it stubs `SetScale` before `disable()`, then asserts that the value the frame ends with after `enable()` and `Show()` is 1.25, with `-- red under:`.
- These are edits that strengthen tests, never weaken them. Case count is unchanged unless step 8 is split.

### C-10 — Hygiene (F-010, F-012, F-013, F-016)
- `core/Bus.lua` stub: `NewTarget` appends each target to a list. `StandDown` calls `t:UnregisterAllEvents(); t:UnregisterAllMessages()`. `StandUp` returns `0, {}`, documented as "the degraded load re-registers nothing". The cleaner alternative is for the modules to re-register in `RegisterRuntime`; that is a larger change, deferred.
- `core/SkillMaster.lua` `NS.StandUp`: add `if NS.StatData then NS.StatData:Request() end` (F-012).
- `modules/Alerts.lua:77`, `modules/Journal.lua:394`, `modules/MainWindow.lua:384`: one format key each, e.g. `L["%s · %s cap"]`, with the dot escaped (`\194\183`).
- `modules/MainWindow.lua:89`: iterate a list built without a nil head. `settings/General.lua:46`: `addonName = NS.Constants.BRAND`, or the library's documented field.

## Standards conformance (per change)

| Change | Conforms | Rule that shaped it |
|---|---|---|
| C-01 | yes | localization-§4; compat (new shim in `core/Compat.lua`) |
| C-02 | yes | localization-§1/§4; a hardcoded in-module translation table was rejected |
| C-03 | yes | architecture-§5 (single seam); options-ui (page Defaults) |
| C-04, C-05 | yes | performance-§2 (bracket), §9 (scenario) |
| C-06 | yes | events-frames-taint-§1 unit-filter carve-out; slash-commands-§7 (one latch; per-unit frames torn down). A general frame factory was rejected because the carve-out forbids it |
| C-07 | yes | performance-§2, §9; testing-§7 (scenarios not counted) |
| C-08 | yes | localization (new keys in enUS) |
| C-09 | yes | slash-commands-§7 steps 3/6/8/9; testing-§12 |
| C-10 | yes | slash-commands-§7; localization |

**Expected watch-list movement:** none of these should push a function over CCN 15. The current maximum is `Bar.PaintBorder`, at 15, and none of these changes touch it. Confirm at the next release regeneration.
