# Debug — Ka0s Skill Master

## The console

LibKa0s-DebugLog-1.0's console (`core/DebugLogSetup.lua`). `/sm debug` toggles the window;
`/sm debug on` and `/sm debug off` turn logging on and off. The flag is session-only
(`NS.State.debug`, off at every login and `/reload`, never saved) and independent of the window, so a
bug can be reproduced with the console closed and read afterwards. Lines are tag-first:
`[Set]` (the write seam), `[Test]` (test mode and its sample data), `[Sim]` (the simulator and its
seam), `[Migrate]`, `[Bus]`, `[Click]` (a crafting overlay's cast, a click that found no armed
overlay, a pin to the broker feed), `[Skills]` (a scan's line and row counts), `[Reps]` (a full reputation read: its rows, and why one was partial), `[Bonus]`,
`[Alerts]`, `[Broker]`, `[Probe]`, `[Layout]` (a merge, split or snap drop), `[Combat]` (an action
queued until combat ends) and `[Arrow]` (the waypoint arrow's library lines), plus the library's own
`[Cmd]`, `[Cfg]`, `[Launcher]` and `[Lifecycle]` lines.

## Reports

A report is a multi-line read-out the player asks for by name (the owner's report-routing ruling of
2026-11-08, debug-logging). `/sm probe` is this addon's one report verb besides diagnostics: it writes
the probe's JSON through `NS.DebugLog:Report("Probe", "probe", fn)`, ungated (it lands with logging
off), under a `/sm probe` header line. A hidden console opens, and chat gets exactly one pointer line,
`probe: N lines written to the debug console. Use Copy to share it.` (`REPORT_WRITTEN`, localized
through the descriptor's `L`). Without the library the probe has no JSON encoder, so it refuses in
chat on one line and writes nothing. Acknowledgments, refusals, usage, `help` and the reserved
`/sm list` stay in chat; the Journal shows its log in its own window and has no chat read-out.

## The diagnostics report

Two forms and no third: `/sm diagnostics` and `/sm debug diagnostics`, plus the console title bar's
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
| `state` | whether the window is shown, test mode is on and Sim mode is on (`simMode`); or "stood down: runtime state released" |
| `skin` | the skin engine's minor, the stored and the applied choice |
| `model` | the live skill model's counts (total, learned, unlearned, rows per category), the stat count, the session log's entries and gains, the alts, whether test mode's preview source is on; stood down, a note that the last scan is kept |
| `probe` | the probe's read-only half: the skill-list API (`C_SkillInfo`, `global` or `none`) and its visible line count, how many probed globals are present and the missing ones (capped) |
| `bonuses` | each learned skill with a modifier as `key=+N (temp N)`, then the bonus cache as it stands (sources, items, buffs, whether the temp ticker runs) and each cached source; "bonus cache empty" before the first collect |
| `layout` | the window's stored scale, opacity, lock, point, max height, summary strip, column count and strata, and the detached blocks' strata; each block's docked, order, collapsed, scale, lock, point, detached-frame state and merged-window group; the docked order and the detached blocks; then the merged windows (their count, and each one's columns, point and frame state) |
| `sim` | the simulation's state (active, step panel, scenario, step, events), the seam's wrapped and unwrapped counts, whether test mode's sample data is on |
| `rejected` | the events `SafeRegisterEvent` refused this session |

The report reads state only. It registers no event, takes no hold, starts no timer, calls no
protected function and is safe in combat. It never runs the probe's scan (which expands a
collapsed Skills-tab header) and never collects the bonus sources (which reads gear tooltips): both
sections read what is already there. It does not read other addons' data or the chat log.
