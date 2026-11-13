# Skill Master feedback round 7: plan and ledger

Resumable: each task is one commit (or a few) on `feat/2026-11-13-feedback-round7`, cut from
`feat/2026-11-13-feedback-round6` at `b57fb70` (rounds 5 and 6 are not merged yet; this stacks on them).
Pick up at the first ledger row that is not `done`. Green gate before every commit:
`KA0S_KIT_CLIENT=forever lua tests/run.lua` and `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0).
Push after each milestone; never merge without the owner's go.

## Owner decisions (2026-11-13)

- The arrow in the owner's screenshot was TomTom's (some addon provides TomTom's API), which is why
  Skill Master's arrow never showed. Decision: drop TomTom support entirely; a waypoint is always the
  native map pin plus Skill Master's own arrow (directions in the owner's test were right).
- Filters on every category's header: Primary and Secondary: All, Below cap, At cap (needs training);
  Weapon Skills unchanged (All, Learned, Equipped, Below cap); Other skills: All, Learned, Below cap;
  each stat section: All, Non-zero.
- The LDB tooltip's go icon arms the main window's secure click out of combat; in the Classic style
  (no go icon) the whole row opens.
- Round-6 items accepted as they are: the ContextMenu strata raise stays a recorded, owner-accepted
  deviation (frame-layering-§6); the tooltip's test strip keeps its right-click End test.

## Tasks

- **R7-1 (filters everywhere):** a filter mark and menu on every block header, with the sets above.
- **R7-2 (icon border colour):** Bars > Icons "Use the row's color" defaults off for new profiles (existing keep theirs).
- **R7-3 (no header meta):** remove "vs highest primary" and any similar header meta text.
- **R7-4 (tooltip scroll bar):** the LDB panels always draw their scroll bar, disabled when nothing scrolls, so no empty gutter.
- **R7-5 (titles):** "Skill Master · Professions and Skills" and "Skill Master · Stats".
- **R7-6 (go icon only):** an LDB tooltip setting, open from the go icon only (default) or the whole row.
- **R7-7 (no TomTom):** TomTom support removed; the native pin and Skill Master's arrow always.
- **R7-8 (deviation ratified):** the frame-layering-§6 row marked owner-accepted (2026-11-13).

Milestones: M1 = R7-7, R7-2, R7-3, R7-5, R7-4, R7-8; M2 = R7-1; M3 = R7-6.

## Ledger

| Task | Status | Commit |
|---|---|---|
| R7-7 | done (uncommitted) | |
| R7-2 | done (uncommitted) | |
| R7-3 | done (uncommitted) | |
| R7-5 | done (uncommitted) | |
| R7-4 | done (uncommitted) | |
| R7-8 | done (uncommitted) | |
| R7-1 | queued (workflow) | |
| R7-6 | queued (workflow) | |
