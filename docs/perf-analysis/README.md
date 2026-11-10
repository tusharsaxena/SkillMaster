# Perf analysis — Ka0s Skill Master

The standing store of **in-game** performance captures (performance-§8). Each capture is a frozen
bundle `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` holding three artifacts:

- `report.md` — the report the player copied out of the client after `/sm perf finish`;
- `dump.json` — the JSON capture from the same run (`SkillMasterPerfDB`; schema: LibKa0s-Perf-1.0's
  capture contract, `docs/api/Perf` in the LibKa0s repo);
- `ANALYSIS.md` — the write-up.

Bundles are produced by `/dev-copilot:wow-perf-analysis` from a real client paste, never assembled
from the offline scenarios or the source, and never edited after they are written.

## Taking a capture

In game: `/sm perf` shows the steps; start, play the scenario, then `/sm perf finish` and copy the
report and the dump out of the panel.

## Capture index

No capture has been taken yet.
