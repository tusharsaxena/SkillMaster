# Automated tests — Ka0s Skill Master

The consolidated out-of-game test record (automated-tests). The vendored runner
`tests/_kit/run-automated-tests.sh` runs four suites (lint, tests, perf, complexity) and writes a
frozen bundle `docs/automated-tests/<YYYYMMDD-HHMMSS>/` (one file per suite plus `manifest.json`),
then rolls the run into `RESULTS.md`, one file overwritten in place whose git history is the trend.

```sh
KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --release X.Y.Z   # at release, before the tag
KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle
```

The second form is the commit gate's shape and writes nothing. `lint` and `tests` gate; `perf` and
`complexity` are recorded and never fail a run, but the tag needs all four passing and zero
functions above CCN 15 (automated-tests-§3). A missing tool is a recorded skip, never a pass.
Each release bundle gets a hand-written `ANALYSIS.md`; `/dev-copilot:wow-automated-tests` runs the
whole procedure.
