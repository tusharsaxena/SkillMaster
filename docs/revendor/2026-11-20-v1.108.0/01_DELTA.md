Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded for item SD-RV-SM of Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/` (the copy, provenance,
icon-declaration and prune mechanics of `/dev-copilot:wow-revendor-libka0s` 2.10.1; the adoption interview and the
issue filing are skipped because the run's bundle pre-decides the work). The payload comes from the local tag, never
the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit `56c20b76`, not yet on
origin, which is expected for this run: `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing).

## Step 0 pre-flight (this addon)

The newest single-tag bundle is `2026-11-19-v1.107.0`. Its line 1 says base v1.106.0, and the provenance line before
its re-vendor (`18dea6c`) was v1.106.0. Result: ok, so there is no base correction.

## 3a Base

- `grep -n '[Bb]undles' CLAUDE.md` named v1.107.0 (CLAUDE.md:40) before the roll.
- `git log -1 --format=%h -- libs/LibKa0s tests/_kit` returned `3932243` ("AF-RV-SM: Re-vendor the re-cut LibKa0s
  v1.107.0 ..."), whose CLAUDE.md names v1.107.0. The two agree.
- Before the copy, `diff -rq` of a v1.107.0 extract against `libs/LibKa0s` printed only the
  `Only in <extract>/LibKa0s/media/icons` and `.../media/sounds` lines (the undeclared icons and the callout voice
  packs), and against `tests/_kit` printed nothing. The payload matched v1.107.0.
- Range: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0` is 15 commits (SD-LK-94, SD-LK-99, SD-LK-100,
  SD-LK-97 Batches A to D, SD-LK-GUARD, SD-LK-REL).

## 3b/3c Per-file minors that moved (old = this addon before the copy, new = v1.108.0)

Run with the spec's loop over the tag's `LibKa0s.xml`. Files not listed did not move. No file was added.

| File | Old | New |
|---|---|---|
| Core.lua | MINOR 18 | 19 |
| Callout.lua | MINOR 4 | 5 |
| CalloutSettings.lua | SETTINGS_MINOR 5 | 6 |
| WaypointArrow.lua | MINOR 2 | 3 |
| WaypointArrowSettings.lua | SETTINGS_MINOR 2 | 3 |
| Charts.lua | MINOR 2 | 3 |
| ChartsRender.lua | RENDER_MINOR 1 | 2 |
| SkinPaint.lua | PAINT_MINOR 19 | 20 |
| SkinPaintHud.lua | HUD_MINOR 1 | 2 |
| SkinPaintControls.lua | CONTROLS_MINOR 18 | 19 |
| Widgets.lua | MINOR 29 | 30 |
| WidgetsDropdown.lua | DROPDOWN_MINOR 2 | 3 |
| WidgetsDragHandle.lua | DRAG_MINOR 15 | 16 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR 2 | 3 |
| WidgetsLineChart.lua | CHART_MINOR 7 | 8 |
| WidgetsBar.lua | BAR_MINOR 1 | 2 |
| OptionsCompose.lua | COMPOSE_MINOR 19 | 20 |

Every file matched v1.107.0 before the copy, so there is no cross-major skew.

## 3d Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -r` of both payloads against the
v1.108.0 extract were both empty. After the prune the only differences are `Only in <extract>/LibKa0s/media/icons`
(the undeclared icons) and `Only in <extract>/LibKa0s/media/sounds` (`LibKa0s sounds: none.`, 362 files removed by the
prune). No file was removed upstream, so nothing was deleted by hand.

## 3e Consumption map

Unchanged from the v1.107.0 bundle. The majors that moved and that this addon looks up: Core (`core/CoreSetup.lua`,
`core/SkinSetup.lua`), Skin (`core/SkinSetup.lua`, `modules/Diagnostics.lua`), Widgets (`core/WidgetsSetup.lua`,
`settings/BoxList.lua`), Options (`settings/OptionsSetup.lua`, through `NS.Helpers`) and WaypointArrow
(`modules/WaypointArrow.lua`). Callout and Charts moved but this addon never looks them up.

## 3f Kit revision

`grep -n 'Kit.VERSION'` reads 58 in the extract and 57 in `tests/_kit/framework.lua` before the copy. Both payloads
travel together by construction (whole-folder copy).

## 3g Contract delta (blockers, fixed in the SD-RV-SM commit)

Read against the tag's `CHANGELOG.md` v1.108.0 block, *What a consumer owes at its re-vendor*, and the Options document
`docs/api/Options/version-38.5.46.3.7.2.9.17.3.1.4.20.13.7.5.8.7.12.1.1.1.4-docs.md` (*Moving to this version*).

- **OptionsCompose minor 20 emits per-part companions by default.** A schema dump before and after the copy showed
  five new rows. Three are on Layout > Detached windows: `layout.detached.bgColorFromSkin` (ColorPair),
  `layout.detached.borderStyleFromSkin` and `layout.detached.borderColorFromSkin` (BorderGroup). This addon already
  writes one hand-written companion per block in `extra` (`layout.detached.bgFromSkin`,
  `layout.detached.borderFromSkin`), and each governs the whole fill or the whole edge (`modules/Detached.lua`), so
  the composer's rows would be a second switch for the same swatch. Fixed by `omit` on both blocks
  (`settings/Layout.lua`). The Bars and Trainers blocks already carry their companions in `extra` and emit nothing
  new.
- **WaypointArrowSettings minor 3** emits `waypoints.arrowFontColorFromSkin` and `waypoints.arrowFontShadowFromSkin`
  (the other two new rows). The AceDB seeds, the skin listener that re-applies the arrow and the guard surface are
  SD-SK-SM.2 to SM.4, the next item. The full-schema pin in `tests/test_options.lua` moves 365 -> 367.
- **W.BarStyle border and gloss.** `modules/BarStyle.lua` already passes `borderFromSkin = false` (it resolves the
  border itself, SD-LK-97.2's named exception); the gloss (`glossFromSkin`, default true) now reaches every bar drawn
  in the skin's texture, which is R-2's intent. No change.
- **Kit revision 58's typed-value scanner** reads three- and four-number tables and `or { r, g, b }` fallbacks. Six
  new hits, none of which draws a look, take kit row categories in `Kit.skinValues.rows` (`tests/run.lua`): three
  texture-coordinate or shade-factor tables as `not a color`, three `or { 1, 1, 1 }` last resorts behind
  `text.body` as `unreachable default`.
- Callout, Charts, `S.ApplyBarFill`, `W.ContextMenu` submenus and `Core.ApplySkin`'s `skinBands` bind nothing here.

## 3h Unrecorded tags

The listing (the audit's walk plus the provenance-rolling CLAUDE.md commits, horizon 2026-11-14) printed nothing new:
v1.107.0 has its bundle. No span bundle.

## 3i Icon declaration

Kept as is, directly under the provenance line (CLAUDE.md:41). The release adds no library-drawn icon. The prune
refused nothing. No set was added or removed, so the README credits are unchanged. Hand lists have drifted before
(KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke is the
backstop for a name the host forgot.

## 3j Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v /_kit/` finds nothing. No blocker.
