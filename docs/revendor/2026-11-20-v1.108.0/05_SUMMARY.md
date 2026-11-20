# 05 Summary: LibKa0s v1.107.0 -> v1.108.0

- Tag moved v1.107.0 -> v1.108.0; base from the provenance line (CLAUDE.md:40), confirmed by `3932243`.
- Minors moved: Core 19, Callout 5, CalloutSettings 6, WaypointArrow 3, WaypointArrowSettings 3, Charts 3,
  ChartsRender 2, SkinPaint 20, SkinPaintHud 2, SkinPaintControls 19, Widgets 30, WidgetsDropdown 3,
  WidgetsDragHandle 16, WidgetsDragHandleTip 3, WidgetsLineChart 8, WidgetsBar 2, OptionsCompose 20. Kit revision
  57 -> 58.
- No span bundle and no base correction.
- Delivered for free (class A): the footer's shown-marks layout, the bar gloss under Glass, the submenu arrow tint,
  the stricter skin guards. The drag-strip and call-out fixes do not reach this addon (it draws neither).
- Contract blockers, fixed in the same commit: the Detached windows' ColorPair and BorderGroup `omit` the composer's
  new per-part companions (`settings/Layout.lua`), which would have doubled the hand-written
  `bgFromSkin` / `borderFromSkin`; six new kit-58 scanner hits take kit row categories in `Kit.skinValues.rows`
  (`tests/run.lua`); the full-schema pin moves 365 -> 367 for the arrow's two new companion rows.
- `LibKa0s icons:` line kept unchanged. The prune refused nothing and removed only undeclared icons and the callout
  voice packs. No provenance split, README credits unchanged, no dead stub mirrors.
- Adopted: nothing beyond the run's items. Declined: nothing. Unreached: `W.OwnerWarnings` (reported to the lead).
- Gate (Forever only; this addon ships on WoW Forever alone): `KA0S_KIT_CLIENT=forever ka0s-bounded lua tests/run.lua`
  804 passed, 0 failed, 1 skipped, 805 total; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 151 files.
