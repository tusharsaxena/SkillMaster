# Owner feedback round 9 — the waypoint arrow's text, position, size and menu

Started 2026-11-14. Skill Master branch `feat/2026-11-14-feedback-round9` (off `main` `7f720b6`);
LibKa0s branch `feat/2026-11-14-arrow-text-position-menu` (worktree `#Worktrees/LibKa0s-arrow2`, off
`master` `1dd9680`, v1.100.0). Issues #3 and #4 come after this round, in a round of their own.

## Owner requests (2026-11-14)

1. Text formatting options for the Waypoint arrow block.
2. Positioning options for the waypoint arrow.
3. The arrow's default size about 1.25x today's; that size is the new scale 1.0.
4. Right-click opens a menu instead of clearing: Clear first, then Share in chat (`/way xx.x,yy.y`)
   and whatever else is relevant.

## Owner decisions

- **Home:** the LibKa0s widget (`LibKa0s-WaypointArrow-1.0`) and its settings block, so every consumer
  gets them; release as the next LibKa0s tag and re-vendor Skill Master from it. v1.100.0 was cut by
  another session the same day, so this release is **v1.101.0**.
- **Text:** the canonical Font block (options-ui-§16: Font, Font size, Font color, Use class color,
  Font flags, Font shadow, "From skin" where the skin has a value), plus **Text position** (Below,
  Above, Left, Right, Hidden), an optional **trainer name line**, and **Distance units** (yards, or
  compact such as `4.2k yd`).
- **Position:** the standard Position block (X and Y offsets from the screen center, Reset position)
  plus the arrow's **own Lock** toggle, separate from `/sm lock`. Dragging updates the offsets.
- **Menu:** Clear waypoint first, then Share in chat (opens the chat box pre-filled, never sends),
  Show on map, Show trainers (Skill Master's trainer popup), Lock / Unlock, Reset position, Arrow
  settings…, Hide arrow.
- The addon is unreleased: no migration for the dropped `waypoints.arrowFrame.point` state.

## Tasks

### LibKa0s (WaypointArrow minor 2, WaypointArrowSettings minor 2)

| ID | Task |
|---|---|
| L1 | Size: the art box at scale 1 grows 48 → 60 px (1.25x); everything measured from it (shadow offset, text gap, ground cells) follows. |
| L2 | Text: the six canonical font settings plus the From-skin companion, text position, the name line, distance units; settings rows in the canonical block's shape and order. |
| L3 | Position: `x`, `y` (offsets from UIParent CENTER) and `lock` settings; a drag writes the offsets through the host; Reset position. |
| L4 | Menu: right-click opens a LibKa0s-Widgets context menu with stock items (Clear waypoint, Share in chat, Show on map, Lock / Unlock, Reset position); the host adds its own items; `menu = false` keeps the old click. |
| L5 | Docs and record: API document for the new key, CHANGELOG, test-cases, register and README lines. |
| L-REL | Release v1.101.0 (after review), tag, push, merge to master. |

### Skill Master

| ID | Task |
|---|---|
| R9-1 | Settings: the Waypoint arrow subgroup gains the Text and Position blocks and the Lock toggle on `waypoints.*` paths; `waypoints.arrowFrame.point` goes; defaults, schema counts, docs. |
| R9-2 | Menu: Skill Master's items (Show trainers, Arrow settings…, Hide arrow); the tooltip says right-click opens the menu; strings. |
| R9-3 | Text: the trainer's name as the label line; localized distance formats for both units. |
| R9-4 | The settings slider's edit box keeps junk text (`1.5awd` in the owner's screenshot): find the layer and fix it there, or record why not. |
| R9-RV | Re-vendor LibKa0s v1.101.0; gates; smoke rows. |

## Checkpoints

1. LibKa0s L1–L5 green (`lua tests/run.lua`, luacheck 0/0), reviewed.
2. Skill Master R9-1–R9-4 green against the branch payload, reviewed.
3. v1.101.0 released, Skill Master re-vendored, both pushed. Merge waits for the owner.

## Ledger

| ID | Status | Commit |
|---|---|---|
| L1 | pending | |
| L2 | pending | |
| L3 | pending | |
| L4 | pending | |
| L5 | pending | |
| L-REL | pending | |
| R9-1 | pending | |
| R9-2 | pending | |
| R9-3 | pending | |
| R9-4 | pending | |
| R9-RV | pending | |
