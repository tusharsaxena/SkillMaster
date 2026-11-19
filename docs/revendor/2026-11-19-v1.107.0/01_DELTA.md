Delta: LibKa0s v1.106.0 -> v1.107.0

Recorded for item AF-RV-SM of Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/` (the copy, provenance,
icon-declaration and prune mechanics of `/dev-copilot:wow-revendor-libka0s` 2.9.0; the adoption interview is
skipped because the run's bundle pre-decides adoptions). The payload comes from the local tag, never the sibling
tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit `5e96365`, not yet on origin, which
is expected for this run: `git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing).

## Step 0 pre-flight (this addon)

The newest single-tag bundle is `2026-11-16-v1.105.0`. Its line 1 says base v1.101.0, and the provenance line
before its re-vendor was v1.101.0 (that bundle's own 3a). Result: ok, so there is no base correction.

## 3a Base

- `grep -n '[Bb]undles' CLAUDE.md` named v1.106.0 (CLAUDE.md:40) before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` returned `6b43bd7` ("Re-vendor LibKa0s v1.106.0 ..."),
  whose CLAUDE.md names v1.106.0. The two agree.
- Before the copy, `diff -rq` of a v1.106.0 extract against `libs/LibKa0s` printed only
  `Only in <extract>/LibKa0s/media/icons` and `.../media/sounds` lines (the undeclared icons and the callout
  voice packs), and against `tests/_kit` printed nothing. The payload matched v1.106.0.
- Range: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0` is 6 commits (AF-LK-01, AF-LK-02, AF-DR-LK,
  AF-LK-03 x3).

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.107.0)

Run with the spec's loop over the tag's `LibKa0s.xml`. Files not listed did not move.

| File | Old | New |
|---|---|---|
| WidgetsDragHandle.lua | DRAG_MINOR 14 | 15 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR 1 | 2 |

Every file matched v1.106.0 before the copy, so there is no cross-major skew.

## 3d Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the
v1.107.0 extract were both empty. After the prune the only differences are `Only in <extract>/LibKa0s/media/icons`
(the undeclared icons) and `Only in <extract>/LibKa0s/media/sounds` (`LibKa0s sounds: none.`, 362 files removed
by the prune). No file was removed upstream, so nothing was deleted by hand.

## 3e Consumption map

Unchanged from the v1.105.0 bundle (less `modules/Bar.lua`, deleted by AD-80-SM). This addon never calls
`Widgets.DragHandle` or `LibKa0s-Callout-1.0`: `grep -rnE 'DragHandle|tooltipPlace|Callout' --include='*.lua' .`
outside `libs/` and `tests/_kit/` finds only a comment in `core/WidgetsSetup.lua`. Its strips are
`Widgets.TestStrip` (`modules/MainWindow.lua:243,251`, `modules/BrokerPanel.lua:268`, `modules/Journal.lua:879`),
which v1.107.0 did not move.

## 3f Kit revision

`grep -n 'Kit.VERSION'` reads 57 in both the extract and `tests/_kit/framework.lua`. The kit did not move in this
range; both payloads still travel together by construction (whole-folder copy).

## 3g Contract delta

The only moved major is Widgets (DragHandle 14 -> 15, DragHandleTip 1 -> 2). The release's *What a consumer owes*
list (LibKa0s `CHANGELOG.md`, v1.107.0 block) is about drag strips: the settings mark on by default, `onClose` for
close, the retired `tooltipPlace`, and a strip consumer declaring `settings`. This addon owns no drag strip, so
none of it binds here. No blockers.

## 3h Unrecorded tags

The listing (the audit's walk plus the provenance-rolling CLAUDE.md commits, horizon 2026-11-14) printed
`v1.106.0`: vendored by `6b43bd7` with no bundle. It is recorded in the span bundle beside this one,
`../2026-11-19-v1.106.0-v1.106.0/`.

## 3i Icon declaration

Kept as is, directly under the provenance line (CLAUDE.md:41). It already declares `settings`, so the run's
"strip consumers declare `settings`" rule needs no change (and this addon has no strip). The prune refused
nothing. No set was added or removed, so the README credits are unchanged. Hand lists have drifted before
(KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is
the backstop for a name the host forgot.

## 3j Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/` finds nothing. No blocker.
