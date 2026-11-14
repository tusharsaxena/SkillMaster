Delta: LibKa0s v1.99.0 -> v1.101.0

The base is the tag the provenance line named before this run. The payload Skill Master's round 9
built against (rows R9-1 to R9-3) was the LibKa0s branch `feat/2026-11-14-arrow-text-position-menu`,
copied into the working tree for the build and never committed; the committed payload before this
re-vendor was `v1.99.0`. Library tag `v1.100.0`, which this addon never vendored, is inside the range.

## Pre-flight (Step 0)

Skill Master's one earlier bundle, `2026-11-14-v1.99.0`, states its base as `faa4621`, the commit
its provenance line named before that re-vendor (`ok`).

## 3a. Claimed version

    $ git show HEAD:CLAUDE.md | grep -n '[Bb]undles'
    40:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.99.0 (MIT).
    $ git log -1 --format=%h -- libs/LibKa0s tests/_kit   ->  73437f0, whose CLAUDE.md names v1.99.0

The two answers agree.

## 3b/3c. Per-file minors (v1.101.0's LibKa0s.xml, only files that moved)

| File | v1.99.0 | v1.101.0 |
|---|---|---|
| `Callout.lua` | 2 | 3 |
| `CalloutSettings.lua` | 3 | 4 |
| `WaypointArrow.lua` | 1 | 2 |
| `WaypointArrowSettings.lua` | 1 | 2 |
| `OptionsWidgets.lua` | 45 | 46 |
| `OptionsNav.lua` | 6 | 7 |

Every other file is at the same minor. No cross-major skew.

## 3d. Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -rq` against the
extracted tag were empty for both payloads.

## 3e. Consumption map

Skill Master looks up Bus, Core, DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool, Sim, Skin,
Widgets, Toast, WaypointArrow, Options, Schema and Slash. It does not look up Callout.

## 3f. Kit revision

`Kit.VERSION = 56` on both sides; the kit does not move. Both payloads are still copied whole.

## 3g. Contract delta

The moved majors Skill Master consumes are WaypointArrow (key 1.1 -> 2.2) and Options (OptionsWidgets
46, OptionsNav 7). Their contract changes were adopted in round 9, built against the same bytes:

- WaypointArrow 2.2: the frame is the art box plus its hit pad; the text no longer reads the skin's
  Text role; offsets and saved points are in the parent's units; a drag writes through `d.paths` /
  `d.set`; right-click opens the menu; `SettingsRows` returns a second value (afterSubgroup hooks).
  Adopted in R9-1 to R9-3 and their review fixes (`94ef109`, `8f512d2`).
- OptionsNav 7 adds `O.SideTabs`: the library-absent Options stub gained an `H.SideTabs` no-op (R9-1).
- OptionsWidgets 46: a number row's slider box puts junk text back (R9-4, the owner's `1.5awd`). No
  host change.

**Blockers: none.**

## 3h. Unrecorded tags

`v1.100.0` was never vendored here, so it needs no record of its own.

## 3i. Icon declaration

Kept as it was (26 names), with `LibKa0s sounds: none.` under it. The prune kept the declared icons
and removed 362 Callout voice files (sounds none; v1.100.0 added six packs).

## 3j. Whole-icon-folder tests

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
    (none)
