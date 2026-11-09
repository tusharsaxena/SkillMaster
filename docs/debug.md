# Debug — Ka0s Skill Master

## The console

LibKa0s-DebugLog-1.0's console (`core/DebugLogSetup.lua`). `/skm debug` toggles the window;
`/skm debug on` and `/skm debug off` turn logging on and off. The flag is session-only
(`NS.State.debug`, off at every login and `/reload`, never saved) and independent of the window, so a
bug can be reproduced with the console closed and read afterwards. Lines are tag-first:
`[Set]` (the write seam), `[Test]` (test mode and its sample data), `[Sim]` (the simulator and its
seam), `[Migrate]`, `[Bus]`, plus the library's own `[Cmd]`,
`[Cfg]`, `[Launcher]` and `[Lifecycle]` lines.

## The diagnostics report

Two forms and no third: `/skm diagnostics` and `/skm debug diagnostics`, plus the console title bar's
Diagnostics link. All three run `NS.DebugLog:RunDiagnostics()`.

- It runs while the addon is disabled.
- It turns debug logging on for the session first when it is off (the addon keeps the default; it
  never calls `SetEnabled` around the run).
- It **appends** to the console, after whatever trace is already there, and never clears it, so one
  Copy carries the trace and the report.
- It stays under the library's line cap and per-list caps; a capped report ends with a `truncated` line.

The library writes both markers (with the brand `Ka0s Skill Master`), the identity header (client
build, locale, debug flag, combat reads, the LibKa0s minors, the `[Init]` summary) and a guard per
section. This addon writes the sections, in `modules/Diagnostics.lua`:

| Section | Lines |
|---|---|
| `identity` | stored and code schema version, the profile, `enabled` and stood-down, the latch's holds |
| `settings` | every setting that differs from its default, plus `enabled`, `skin.source`, `skin.skin` always |
| `state` | whether the window is shown and test mode is on; or "stood down: runtime state released" |
| `skin` | the skin engine's minor, the stored and the applied choice |
| `sim` | the simulation's state (active, step panel, scenario, step, events), the seam's wrapped and unwrapped counts, whether test mode's sample data is on |
| `rejected` | the events `SafeRegisterEvent` refused this session |

The report reads state only. It registers no event, takes no hold, starts no timer, calls no
protected function and is safe in combat. It does not read other addons' data or the chat log.
