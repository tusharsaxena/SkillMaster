# Six windows, six brokers: plan (resumable, checkpointed)

Spec: `docs/superpowers/specs/2026-11-26-skillmaster-windows-design.md`. Branch: `feat/2026-11-26-skillmaster-windows`.
The build clone is `~/ka0s-scratch/smw/SkillMaster`; never build in the live repo, which the game loads. Merge waits for
the owner's go-ahead.

## State lives in git

An item is done when a commit whose subject starts `<ID>: ` is on the branch, or on master after the merge.

```sh
git log --format=%s master..feat/2026-11-26-skillmaster-windows | grep -oE '^SMW-[0-9]+[A-Z]?' | sort -u
```

## Gate (every item)

- `ka0s-bounded lua tests/run.lua` with `KA0S_KIT_CLIENT=forever` (Skill Master is Forever-only), and the default client
  wherever the suite runs;
- `ka0s-bounded luacheck .` at 0/0;
- `python3 -m pytest -q -p no:cacheprovider tools/seeds`;
- `tests/perf.lua` where present, with no ceiling raised;
- files under 1500 lines; CCN 15 or less, through the vendored complexity suite;
- CRLF per `.gitattributes`.

New tests go in new suite files: `tests/test_round6.lua` is at 1490 lines. Smoke rows are written unrun.

## Items

| ID | Milestone | What | Depends |
|---|---|---|---|
| SMW-PLAN | M0 | spec and plan | - |
| SMW-00 | M1 | re-vendor LibKa0s v1.117.0 (both payloads, provenance, icon declaration) | SMW-PLAN |
| SMW-01 | M1 | `/sm probe`: factions, currencies, statistics sections; forever-quirks notes from the Blizzard source | SMW-00 |
| SMW-02 | M1 | family registry; Blocks dispatch on a provider table (no visible change) | SMW-00 |
| SMW-03 | M1 | Tree row model and addon-side folds (`char.fold`) | SMW-02 |
| SMW-04 | M2 | window factory; six windows; schema 14; slash verbs, bindings, launcher entries; "Character Stats" labels | SMW-03 |
| SMW-05 | M2 | six brokers from the registry; per-feed templates and sections; Broker.lua split | SMW-04 |
| SMW-06 | M2 | pins per broker (#11): lists up to 5, menu toggle, `{pinned}`/`{pinnedN}`, tooltip pins, settings list, read-time migration | SMW-05 |
| SMW-07 | M2 | LDB tooltip: tooltip-only folds that redraw in place; rows not clickable (hover kept); Classic chevrons; `openFrom` retired | SMW-05 |
| SMW-08 | M3 | RepData and the Reputations window (panel grouping, standing bars, expand-read-restore, refresh by id); Journal gains, Alts sub-tab (#6) | SMW-04 |
| SMW-09 | M3 | CurrencyData and the Currencies window (caps, weekly in the tooltip, no gold); Journal gains, Alts sub-tab; optional cap alert (#7) | SMW-04 |
| SMW-10 | M3 | StatisticsData and the Statistics window (lazy fold-driven reads, debounced `CRITERIA_UPDATE`, pinnable) | SMW-04 |
| SMW-11 | M3 | test mode, preview and simulator samples for the three families | SMW-08 SMW-09 SMW-10 |
| SMW-12 | M4 | docs (README, ARCHITECTURE, settings, schema, forever-quirks, module map, test inventory) and smoke rows | SMW-11 |
| SMW-REV | M4 | independent review and fixes | SMW-12 |

## Checkpoints

The lead re-gates each milestone, pushes the branch (`git -C <live> fetch <clone> +B:B`, then `git push -u origin B`) and
records the totals and head in the spec's run record (an "Execution record" section appended to this plan when the run
ends).

## Resume

1. Run the state command above.
2. In the clone, read `git status`. Finish or stash an interrupted item, and never `reset --hard` work you have not read.
3. Continue with the next item in table order; run the gate before each commit.
4. If the clone is lost, re-clone from the pushed branch.
