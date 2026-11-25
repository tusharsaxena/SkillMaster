# Performance — Ka0s Skill Master

The harness is LibKa0s-Perf-1.0 (`core/PerfSetup.lua`), with captures in `SkillMasterPerfDB`.

## Buckets

| Bucket | Bracketed in | Measures |
|---|---|---|
| `windowRender` | `modules/MainWindow.lua` `W.Render` | one pass over the window body |
| `detachedRender` | `modules/Detached.lua` `D.Render`, `modules/Groups.lua` `G.Render` | one detached block's rows, or one merged window |
| `skillScan` | `modules/SkillData.lua` `SD:Scan` | reading the skill list and building the model, before its messages |
| `statScan` | `modules/StatData.lua` `S:Scan` | reading every stat (the throttled flush, a speed change) |
| `bonusRefresh` | `modules/Bonuses.lua` `B.Refresh` | the invalidate and live-temp check, before `BONUSES_UPDATED` |

Each bracket closes before its module sends its message, so the displays the message repaints are
measured by their own buckets and no bucket is declared `within` another. `statScan` can run inside
`windowRender` on a cold start (the window asks for a model before the first flush); the capture
reports that nesting as observed.

Each is reached by a real bracket of the gated shape (performance-§2), and `tests/test_perf.lua`
holds every declared bucket to being reached and to noting nothing while capture is off:

```lua
local t0 = Perf.on and debugprofilestop()
-- ... work ...
if t0 then Perf.Note("windowRender", debugprofilestop() - t0) end
```

The offline scenarios (`tests/perf.lua`, outside the gate) time each bucket's path plus the window
with capture off and on; `api/iter` counts the client's global functions (and `C_*` members) called
per iteration, frame methods excluded.

## Capture

`/sm perf` prints the workflow. A capture holds the latch's `perf` hold: the addon stands down
through the same teardown as `disabled`, with no `/reload`, and feature verbs answer "Not available
during a performance capture." until it ends.

## Budget

The design's anti-goal: nothing polls per frame except visible expiry timers and the shown
waypoint arrow (LibKa0s-WaypointArrow-1.0's OnUpdate, throttled to 0.03 s, disarmed when the arrow
is taken down); skills update on skill events, stats on throttled unit events (plus a 0.5 s speed
read while a speed display is on screen) (ARCHITECTURE.md, Event Subscriptions).
In-game captures live in [perf-analysis/README.md](perf-analysis/README.md); none has been taken.
