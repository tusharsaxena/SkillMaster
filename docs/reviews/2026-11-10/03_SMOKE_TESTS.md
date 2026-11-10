# 03 — In-client smoke tests

These are for a human to run in the WoW Forever client after the changes in `02_PROPOSED_CHANGES.md` land. The headless suites are not repeated here.

**Pre-flight (shell, once):**
- `KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua5.1 tests/run.lua` must be green.
- `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` must report 0/0.

**Pre-flight (client):**
- WoW Forever 1.60.1, TOC `## Interface: 16001`. A level 20+ character with at least one crafting profession (e.g. Leatherworking), Fishing, and a ranged weapon.
- Run `/console scriptErrors 1`, then `/reload`.
- Keep one enUS client and, if available, one deDE or frFR client.

## Per-change tests

### SM-1 — C-01 crafting overlay by spell ID
- **Setup:** main window open, out of combat.
- **Steps:**
  1. Left-click the Leatherworking row.
  2. Close the profession window.
  3. Repeat on a deDE client.
- **Expected:** the profession window opens on both clients, with no Lua error.
- **Pass:** it opens on both locales.

### SM-2 — C-02 classification on a non-enUS client
- **Setup:** deDE client with the deDE strings added, fresh `/reload`.
- **Steps:** `/skm show`.
- **Expected:**
  - Professions appear in Primary and Secondary, weapons in Weapon Skills.
  - No "Not learned" row for a weapon the character knows.
  - No language or armor rows in Other.
- **Pass:** all three.

### SM-3 — C-03 hide and unhide
- **Steps:**
  1. Right-click any row and choose "Hide this row".
  2. Open Settings → Skills and click Defaults.
- **Expected:** the row disappears at step 1 and is back after step 2. With the Skills page open during step 1, its Hide checkbox ticks live.
- **Pass:** both.

### SM-4 — C-04/C-05 stat tick churn
- **Setup:** main window open, utility block expanded, one block detached.
- **Steps:**
  1. Run `/run collectgarbage("collect") print(collectgarbage("count"))`.
  2. Stand still for 60 s.
  3. Repeat step 1.
  4. Start dragging the detached block and hold it still for 2 s.
- **Expected:**
  - KB growth over the minute is far below the pre-change baseline. Record both numbers.
  - The dragged block does not snap back mid-drag.
- **Pass:** growth is lower than baseline and there is no snap.

### SM-5 — C-06 unit-filter frame
- **Setup:** join a party or a battleground.
- **Steps:**
  1. Run `/skm perf` and follow the two-arm protocol: clean arm first, suspend as the second arm, no `/reload` between arms.
  2. Read the bucket figures. Do not read the frame-time delta.
- **Expected:** `bonusesRefresh` count tracks the player's own aura changes only.
- **Pass:** the counts are of the order of the player's own buffs. Record the capture as a `docs/perf-analysis/<stamp>/` bundle with `/dev-copilot:wow-perf-analysis`.

### SM-6 — C-07 buckets
- **Steps:** `/skm perf` capture over 2 minutes of normal play.
- **Expected:** all six buckets appear in the report, in the declared order.
- **Pass:** no bucket reads 0 calls while its path visibly ran.

### SM-7 — C-08 Clear log
- **Steps:**
  1. Open the Journal's Log tab and click Clear log, then No.
  2. Click Clear log again, then Yes.
- **Expected:** step 1 keeps the log; step 2 empties it.
- **Pass:** both. Separately, entries older than today show a date.

### SM-8 — C-09/C-10 disabled state
- **Steps:**
  1. `/skm disable`.
  2. Right-click the minimap button.
  3. Press the Journal keybind.
  4. `/logout`, then log back in.
- **Expected:**
  - The menu shows Enabled clickable and everything else grayed.
  - The keybind prints one refusal line.
  - `SkillMasterDB.global.characters` has the same timestamp as before step 1. Check it with `/dump`.
- **Pass:** all.

### SM-9 — F-009 overlay under the Journal (verify before M4-T3)
- **Steps:**
  1. Open the main window and the Journal.
  2. Drag the Journal over the Leatherworking row and click the Journal there.
- **Expected after the fix:** no profession window opens.
- **Pre-fix record:** note whether it opens. That confirms or refutes F-009.

## Regression suite
- `/reload` gives no errors.
- A fresh character gets the defaults and the first-run skin picker.
- ADDON_LOADED → PLAYER_LOGIN → PLAYER_ENTERING_WORLD runs clean.
- Enter and leave combat with the window open:
  - The crafting click in combat prints one line.
  - Overlays come back after combat.
  - Test mode ends on combat.
- Profile switch, copy and reset (the window and Journal geometry follow the profile).
- Toggle every option on each settings page once.
- `/skm test`: test strip and sample data.
- `/skm sim`: a full run; it stops on combat.

## Taint
- In combat, click the window's crafting row, the broker rows, and the detached block rows.
- Expect no "Interface action failed because of an AddOn".
- `/skm config` and Esc → Options both open the panel out of combat.

## Localization sanity
- On deDE or frFR, re-run SM-1, SM-2 and SM-7, and check toast titles (C-10).

## Cross-addon (the in-client half)
- With several roster addons loaded, type each root (`/skm`, `/skillmaster`, and the siblings') and confirm each reaches its own addon.
- Settings → AddOns: each addon appears once, and each of Skill Master's pages appears once.

## Sign-off

| ID | Tested? | Pass/Fail | Notes |
|---|---|---|---|
| SM-1 (C-01) | | | |
| SM-2 (C-02) | | | |
| SM-3 (C-03) | | | |
| SM-4 (C-04/C-05) | | | |
| SM-5 (C-06) | | | |
| SM-6 (C-07) | | | |
| SM-7 (C-08) | | | |
| SM-8 (C-09/C-10) | | | |
| SM-9 (F-009) | | | |
