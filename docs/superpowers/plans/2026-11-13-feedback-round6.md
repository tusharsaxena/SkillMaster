# Skill Master feedback round 6: plan and ledger

Resumable: each task is one commit (or a few) on `feat/2026-11-13-feedback-round6`, cut from
`feat/2026-11-13-feedback-round5` at `4da951f` (round 5 is not merged yet; this branch stacks on it).
Pick up at the first ledger row that is not `done`. Green gate before every commit:
`KA0S_KIT_CLIENT=forever lua tests/run.lua` and `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
Push after each milestone; never merge without the owner's go.

## Owner decisions (2026-11-13)

- The LDB tooltip keeps today's interaction model (no clickable header controls, no tooltip-level
  collapse-all); the window's sort, filter and collapse state show in it. It is restyled as the main window.
- The LDB tooltip has its own width and height settings, starting at the main window's default size.
- The new Stats broker's feed shows one stat pinned the way a skill is pinned today: the row menu's
  "Pin to the broker feed" on a stat row.
- Waypoints: when TomTom is absent, Skill Master draws its own arrow; the native map pin is still set
  (no longer super-tracked, so the client's arrow goes away). Texture and colour picked from a mockup.

## My calls

- Toasts: the weapon-gap and skill-up toasts take the cap toast's skin look (skin background, border,
  body text); the kind label stays small in its semantic colour, and the value keeps red/green, written
  `74 / 110 (-36)` and `81 / 110 (+1)`.
- Thresholds: `bars.markers` splits into a window switch (default off) and a row-tooltip switch
  (default on); a schemaVersion step carries an old `false` to both.
- New profiles: every block expanded (stats_spell and stats_defense default `collapsed = false`).
- The LDB tooltip's new look is a style setting, "Main window" for new profiles; existing profiles keep
  the classic look until switched (owner: "default for new profiles, can be customized later").
- Trainer popup: the Set waypoint button reads "Set waypoint"; the "Waypoint order" footer goes; with no
  coordinates for a trainer the button is disabled with a tooltip saying so (Print to chat still works).
- Trainer popup lists the next rank's trainers and every higher rank's, grouped by rank, nearest first
  inside a rank, with a max height and a scroll bar (part of issue #4).

## Tasks

- **R6-1 (toast look):** gap and skill-up toasts in the cap toast's skin look; `(+n)` / `(-n)` in brackets.
- **R6-2 (test mode cues):** a test-mode strip in the Journal and a test-mode line in the LDB tooltip.
- **R6-3 (header marks):** every header mark (filter, sort, pop-out, restore eye) the same size and vertical centre.
- **R6-4 (thresholds):** thresholds hidden in the window by default, shown in the row tooltip; two switches.
- **R6-5 (sort menu):** the sort mark opens a menu of every sort order, current ticked, like the filter mark.
- **R6-6 (waypoint button):** "Set waypoint"; no Waypoint order footer, window shrinks; disabled without coordinates.
- **R6-7 (trainer ranks):** the popup lists next-rank-and-above trainers, grouped by rank, scrolls past a max height.
- **R6-8 (expanded default):** every block expanded on a new profile (window and LDB tooltip).
- **R6-9 (Stats broker):** a second LDB object for stats, same tooltip style, feed from a pinned stat.
- **R6-10 (LDB look):** the LDB tooltip as the main window: own size, scroll, fonts, headers with the
  window's collapse state, text inside the bar, window bar size, the row mark at the right, sort and
  filter shared; the row menu drawn above the tooltip.
- **R6-11 (waypoint arrow):** Skill Master's own arrow without TomTom, after the owner picks from the mockup.

Milestones: M1 = R6-1..R6-8, M2 = R6-10, R6-9; M3 = R6-11 (after the mockup pick).

## Ledger

| Task | Status | Commit |
|---|---|---|
| R6-1 | done | 3fc429d |
| R6-2 | done | 7cb41aa |
| R6-3 | done | 204d15b |
| R6-5 | done | b953641 |
| R6-8 | done | 8fe9ed7 |
| R6-4 | done | 72b74c8 |
| R6-6 | done | a5867ff |
| R6-7 | done | 69d0716 |
| R6-10 | done | 380c10a |
| R6-9 | done | 8efb5df |
| R6 review | done | (this commit) |
| R6-11 | waiting on the owner's mockup pick | |
