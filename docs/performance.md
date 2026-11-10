# Performance — Ka0s Skill Master

The harness is LibKa0s-Perf-1.0 (`core/PerfSetup.lua`), with captures in `SkillMasterPerfDB`.

## Buckets

| Bucket | Bracketed in | Measures |
|---|---|---|
| `windowRender` | `modules/MainWindow.lua` `W.Render` | one pass over the window body |

Each is reached by a real bracket of the gated shape (performance-§2), and `tests/test_perf.lua`
holds every declared bucket to being reached and to noting nothing while capture is off:

```lua
local t0 = Perf.on and debugprofilestop()
-- ... work ...
if t0 then Perf.Note("windowRender", debugprofilestop() - t0) end
```

The data modules (T2.x) and the bars (T3.x) add their own buckets as they land.

## Capture

`/skm perf` prints the workflow. A capture holds the latch's `perf` hold: the addon stands down
through the same teardown as `disabled`, with no `/reload`, and feature verbs answer "Not available
during a performance capture." until it ends.

## Budget

The design's anti-goal: nothing polls per frame except visible expiry timers; skills update on
skill events, stats on throttled unit events (ARCHITECTURE.md, Event Subscriptions).
In-game captures live in [perf-analysis/README.md](perf-analysis/README.md); none has been taken.
