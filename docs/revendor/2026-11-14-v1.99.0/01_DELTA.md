Delta: LibKa0s faa4621 -> v1.99.0

The base is a commit, not a tag: Skill Master's round 8 (R8-5) vendored LibKa0s from the unmerged
branch `feat/2026-11-14-waypoint-arrow` at `faa4621` (v1.97.0 plus the waypoint arrow), a documented
deviation (testing-§11) retired by this re-vendor. `faa4621` is an ancestor of `v1.99.0`.

## Pre-flight (Step 0)

Every roster addon's newest single-tag bundle states the right base (`ok` on all seventeen with a
store). Skill Master has no `docs/revendor/` store before this bundle, so this is its first.

## 3a. Claimed version

    $ grep -n '[Bb]undles' CLAUDE.md
    40:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) faa4621 (MIT), untagged, from branch `feat/2026-11-14-waypoint-arrow` (v1.97.0 plus the waypoint arrow).
    $ git log -1 --format=%h -- libs/LibKa0s tests/_kit   ->  bd888be, whose CLAUDE.md names faa4621

The payload before this run matched `git archive faa4621 LibKa0s testkit` (content diff empty apart
from the declared icon and sound prune). The two answers agree.

## 3b/3c. Per-file minors (v1.99.0's LibKa0s.xml, only files that moved)

| File | faa4621 | v1.99.0 |
|---|---|---|
| `Callout.lua` | 1 | 2 |
| `CalloutSettings.lua` | 2 | 3 |

Every other file is at the same minor. `DebugLogDiagnostics.lua` changed one header comment
(`unreleased` -> `v1.99.0`), minor 10 on both sides. No cross-major skew.

    $ git -C ../LibKa0s diff --stat faa4621 v1.99.0 -- LibKa0s testkit
     LibKa0s/Callout.lua             | 222 ++++++++++++++++++++++++----
     LibKa0s/CalloutSettings.lua     | 317 +++++++++++++++++++++++++-------------
     LibKa0s/DebugLogDiagnostics.lua |   2 +-

## 3d. Diffs

After the copy and before the prune, `diff -r --strip-trailing-cr` and `diff -rq` against the
extracted tag were empty for both payloads.

## 3e. Consumption map

Skill Master looks up Bus, Core, DebugLog, Env, Launcher, Lifecycle, Media, Perf, Pool, Sim, Skin,
Widgets, Toast, WaypointArrow, Options, Schema and Slash. It does not look up Callout.

## 3f. Kit revision

`Kit.VERSION = 56` on both sides; the kit does not move. Both payloads are still copied whole.

## 3g. Contract delta

The moved majors (Callout) intersected with the consumed ones: none. No `__Attach*` site in the addon.
**Blockers: none.**

## 3h. Unrecorded tags

No store before this run, so no horizon and nothing to back-fill.

## 3i. Icon declaration

Kept as it was, the next non-blank line under the provenance line (26 names), with `LibKa0s sounds: none.`
under it. The prune kept the declared icons and removed the 91 Callout voice files (sounds none).

## 3j. Whole-icon-folder tests

    $ grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
    (none)
