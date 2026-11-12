# Skill Master feedback round 5: plan and ledger

Resumable: each task is one commit (or a few) on `feat/2026-11-13-feedback-round5`, cut from
`feat/2026-11-10-feedback-1` at `05ff3a7` (rounds 3-4 committed as the baseline). Pick up at the first
row of the ledger that is not `done`. The green gate before every commit:
`KA0S_KIT_CLIENT=forever lua tests/run.lua` and `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
Push after each milestone (M1, M2, M3); never merge without the owner's go.

## Owner decisions (2026-11-13)

- Rounds 3-4 committed first, round 5 on its own branch.
- Merging detached windows: all four sides. Top and bottom stack sections in one column; left and
  right make columns in one merged window, on the side dragged to.
- Unmerging: drag a section's sub-header out of the group (AuraMaster's leeway: green holds, red
  splits), a split mark on each section's sub-header, and a right-click menu (Split from group,
  Unmerge all). No unmerge-all mark on the header.
- Detached styling: one shared style for every detached and merged window (Layout page).
- The profession link: the owner's probe showed the professions in spellbook slots 61-66, past the
  skill lines' last slot (60): the scan runs past the lines (done in the baseline, `bd32857`).

## My calls

- Snap radius 24 and a detach leeway of 128 UIParent units, AuraMaster's (`C.SNAP_RADIUS`,
  `C.DETACH_RADIUS`); the drop target's edge glows in the skin's `sem.good`, a drag past the leeway in
  `sem.bad`.
- A merged window's header reads its sections' short names joined by " · " (the Journal's sub-tab
  labels: "Primary · Secondary"), truncated; its marks: collapse all and dock all. Each section keeps a
  sub-header with its chevron, title, sort mark and split mark.
- Groups persist per profile (`layout.groups`, schemaVersion 6): an ordered list of columns, each an
  ordered list of block ids, plus the group's point. A block docked back into the main window leaves
  its group; a group of one is no group.
- Test mode shows the main window, the Journal and three sticky toasts (rank cap, weapon gap, skill
  up), all from the sample character, and takes them down when it ends.

## Tasks

- **R5-1 (test mode surfaces):** `/sm test` shows the main window, the Journal and one toast of each kind.
- **R5-2 (Journal lock):** a lock mark in the Journal's title bar, the same `locked` toggle as the main window's.
- **R5-3 (profession link):** done in the baseline (the scan past the skill lines).
- **R5-4 (table headers):** the Journal's Log and Alts table headers on a band of their own, distinct from the rows.
- **R5-5 (detached mark):** a detached row's action mark drawn as the main window's.
- **R5-6 (merge detached windows):** drag a detached window to another's side to merge; one header; columns; unmerge three ways; persisted.
- **R5-7 (detached style):** a Detached windows group on the Layout page: scale, background opacity, border, title band, for every detached and merged window.
- **R5-8 (trainer probe issue):** tusharsaxena/SkillMaster#3.
- **R5-9 (mockup):** the UX mockup of R5-1, R5-2, R5-4, R5-6 and R5-7.
- **R5-10 (weapon filter):** a filter mark on the Weapon Skills header, built like the sort mark: All, Learned, Equipped (and similar), with a fitting icon.
- **R5-11 (empty Stats tab):** the Stats page's General tab is empty; fill it or remove it (R5-13 may absorb it).
- **R5-12 (BoxList hide pages):** the checkbox-grid hide pages (Stats tabs, Broker tooltip skills/stats and similar) move to the BoxList layout (icon, name, eye).
- **R5-13 (one Rows page):** one "Rows" page lists every skill and stat in the BoxList layout, with two eye columns (Window, LDB tooltip) under a header row; it replaces the separate show/hide pages.
- **R5-14 (trainer popup wrap):** the popup's "Also teaches" text wraps; its box and the window grow to fit.
- **R5-15 (trainer distance):** each trainer in the popup shows its distance from the player (world positions from the map API, guarded), and the list sorts nearest first.
- Tracked only: tusharsaxena/SkillMaster#4 (every rank's trainers and other sources in the popup).

Milestones: M1 = R5-1..R5-5 (small fixes), M2 = R5-7, M3 = R5-6. Added by the owner during the run, a
second workflow: M4 = R5-10, R5-14, R5-15; M5 = R5-11..R5-13.

## Ledger

| Task | Status | Commit |
|---|---|---|
| R5-3 | done | bd32857 |
| R5-8 | done | issue #3 |
| R5-9 | done (the mockup, approved by the owner) | |
| R5-5 | done | 5f7ef03 |
| R5-4 | done | 10dc682 |
| R5-2 | done | a97ba33 |
| R5-1 | done | 20beab6 |
| R5-7 | done | da2299c |
| R5-6 | done: R5-6a (model, persistence, merged window, split, menu) 9fec1a3 + 5217c4d; R5-6b (drag to merge, drag out: modules/GroupsSnap.lua) e445c62 + docs | e445c62 |
| R5-review | done: the final review's fixes (a top merge's point, one combat queue entry per drop, the Journal's lock mark on a profile switch, the merged window's style pinned); inventory and badge | 4799b17 |
| R5-10..R5-15 | queued (second workflow) | |
