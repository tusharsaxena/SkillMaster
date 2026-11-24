# 05 Summary: LibKa0s v1.109.0 -> v1.112.0

- Tag moved v1.109.0 -> v1.112.0; base from the provenance line (CLAUDE.md:40), confirmed by `41662e7`.
- Minors moved: Core 20, Compat 6, SkinDefsOthers 11, SkinPaintControls 21, WidgetsDragHandle 17,
  WidgetsCopyWindow 7, WidgetsHeader 2, IconBrowserWindow 3. Kit revision 59 -> 60.
- Span bundle `../2026-11-24-v1.109.0-v1.109.0/` back-fills v1.109.0. No base correction.
- Delivered for free (class A): the disabled-primary paint, High Contrast's 1, -1 HUD shadow, the copy window as a
  companion, the kit's bank shapes. The strip right-click does not reach this addon (it docks no strip).
- Contract blockers: none.
- `LibKa0s icons:` line kept unchanged. The prune refused nothing and removed only undeclared icons and the callout
  voice packs. No provenance split, README credits unchanged, no dead stub mirrors.
- Adopted in later commits of the same run: the companion header (FB-SM-03) and FollowColor (FB-SM-02).
- Gate (Forever only): `KA0S_KIT_CLIENT=forever ka0s-bounded lua tests/run.lua` 858 passed, 0 failed, 1 skipped,
  859 total; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 163 files.
