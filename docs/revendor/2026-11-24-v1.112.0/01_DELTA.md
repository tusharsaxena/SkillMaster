Delta: LibKa0s v1.109.0 -> v1.112.0

Recorded for item FB-SM-01 of Ka0sAddonsCommonTasks `docs/2026-11-24-FEEDBACK_BATCH/` (the owner's S4: "SkillMaster
still vendors LibKa0s v1.109.0 and missed the v1.111.0 strip run"). It follows the copy, provenance,
icon-declaration and prune mechanics of `/dev-copilot:wow-revendor-libka0s` 2.11.0. The adoption interview and the
issue filing are skipped because the run's bundle pre-decides the work. The payload comes from the local tag, never
the sibling tree: `git -C ../LibKa0s archive v1.112.0 LibKa0s testkit tools` (tag commit `1f1904ee`, local only for
this run).

## Step 0 pre-flight (this addon)

The newest single-tag bundle is `2026-11-20-v1.108.0`. Its line 1 says base v1.107.0, and the provenance line before
its re-vendor (`ed0e546`) was v1.107.0. Result: ok, so there is no base correction.

## 3a Base

- `grep -n '[Bb]undles' CLAUDE.md` named v1.109.0 (CLAUDE.md:40) before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` returned `41662e7` ("FU-RV-SM: Re-copy Compat.lua (minor 5)
  and Sim.lua (minor 4) from the re-cut v1.109.0 ..."), whose CLAUDE.md names v1.109.0. The two agree.
- Before the copy, `diff -rq` of a v1.109.0 extract against `libs/LibKa0s` printed only `Only in <extract>/LibKa0s/media:
  sounds` (`LibKa0s sounds: none.`), and against `tests/_kit` printed nothing. The payload matched v1.109.0.
- Range: `git -C ../LibKa0s log --oneline v1.109.0..v1.112.0` is 15 commits (v1.110.0 K101, v1.111.0 SRC, v1.112.0
  FB-LK-01..04 and FB-LK-REL).

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.112.0)

Run with the spec's loop over the tag's `LibKa0s.xml`. Files not listed did not move. No file was added.

| File | Old | New |
|---|---|---|
| Core.lua | MINOR 19 | 20 |
| Compat.lua | MINOR 5 | 6 |
| SkinDefsOthers.lua | MINOR 10 | 11 |
| SkinPaintControls.lua | CONTROLS_MINOR 20 | 21 |
| WidgetsDragHandle.lua | DRAG_MINOR 16 | 17 |
| WidgetsCopyWindow.lua | COPY_MINOR 6 | 7 |
| WidgetsHeader.lua | HEADER_MINOR 1 | 2 |
| IconBrowserWindow.lua | WINDOW_MINOR 2 | 3 |

Every file matched v1.109.0 before the copy, so there is no cross-major skew.

## 3d Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the
v1.112.0 extract were both empty. After the prune the only differences are `Only in <extract>/LibKa0s/media/icons`
(the undeclared icons) and `Only in <extract>/LibKa0s/media/sounds` (362 files removed by the prune). No file was
removed upstream, so nothing was deleted by hand.

## 3e Consumption map

Unchanged from the v1.108.0 bundle. The majors that moved and that this addon looks up: Core (`core/CoreSetup.lua`,
`core/SkinSetup.lua`), Skin (`core/SkinSetup.lua`, `modules/Diagnostics.lua`) and Widgets (`core/WidgetsSetup.lua`,
`settings/BoxList.lua`). Compat moved, and this addon's Compat seam is its own (`core/Compat.lua`); it calls none of
Compat minor 6's container members. IconBrowser moved, and this addon never looks it up.

## 3f Kit revision

`grep -n 'Kit.VERSION'` reads 60 in the extract and 59 in `tests/_kit/framework.lua` before the copy. Both payloads
travel together by construction (whole-folder copy).

## 3g Contract delta

Read against the tag's `CHANGELOG.md` v1.110.0, v1.111.0 and v1.112.0 blocks (*What a re-vendoring host owes*).

- **Core minor 20 adds `FollowColor`.** `tests/test_surface_parity.lua` compares the live Core with the addon's
  degraded stub through the instance, and stays green with no ignore row. Adoption is item FB-SM-02.
- **WidgetsHeader minor 2 (`companion`).** The trainer popup is a companion of the skills window; moving it is item
  FB-SM-03. The standard's rule (v2.119.0) binds at this re-vendor.
- **WidgetsCopyWindow minor 7.** No suite here clicks the copy window's settings mark. No change.
- **SkinPaintControls minor 21 (a disabled primary paints the plain box).** This addon disables no primary button.
  No change.
- **SkinDefsOthers minor 11 (High Contrast HUD shadow 1, -1).** No suite here pins 2, -2. No change.
- **WidgetsDragHandle minor 17 (a strip's right-click opens what its gear opens).** This addon's detached and group
  windows are title bands, not strips, so nothing moves.
- **Compat minor 6, kit revision 60.** No suite pins `Compat.MINOR` 5 or `KIT_VERSION` 59; the gate is green.

No blocker.

## 3h Unrecorded tags

The listing (the audit's walk plus the provenance-rolling CLAUDE.md commits, horizon 2026-11-14) printed v1.109.0,
which had no bundle. It is back-filled as `../2026-11-24-v1.109.0-v1.109.0/`.

## 3i Icon declaration

Kept as is, directly under the provenance line (CLAUDE.md:41). The range adds no library-drawn icon this addon
wires (the companion header draws one fewer mark). The prune refused nothing. No set was added or removed, so the
README credits are unchanged. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup
`tests/test_mediasetup.lua:19`); the owner's in-client smoke is the backstop for a name the host forgot.

## 3j Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/` finds nothing. No blocker.
