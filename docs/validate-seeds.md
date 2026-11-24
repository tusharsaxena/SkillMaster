# Seed validation — Skill Master

The seed-validation contract `/dev-copilot:validate-seeds SkillMaster forever` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies Skill Master's procedure: the tool, the files it writes, the
precedent a ruling follows and what the client's data can and cannot check. The headings below are
the interface the command reads, so keep their names.

Each run ends in a frozen bundle under `docs/seed-research/<date>-forever/` (raw tables, `SOURCES.md`,
`candidates.json`, `RULINGS.md` and a hand-written `ANALYSIS.md`). The tool is `tools/seeds/seeds.py`
(its docstring is the reference), with its tests in `tools/seeds/test_seeds.py`. The first run is
`docs/seed-research/2026-11-15-forever/`; the first with ForeverDB evidence is
`docs/seed-research/2026-11-25-forever/` (LibKa0s#102).

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `forever` | wago.tools product `wowf` (WoW Forever). **Evidence: ForeverDB** (the trainers and gathering nodes) | `defaults/Trainers_Forever.lua`, `defaults/Fishing_Forever.lua`, `defaults/SkillCatalog_Forever.lua`, `defaults/Gathering_Forever.lua` (all hand-made, tool-checked) | `tools/seeds/seeds.py`; dev-copilot's `scripts/foreverdb.py` |

Skill Master is Forever-only (roster Clients `Forever`, clients-§9), so there is no `retail` flavor.
`defaults/Preview_Forever.lua` is not a seed: it is test mode's fictional sample character from the
design mockups, and nothing in it mirrors a DB2 row.

## Rules

- **What the tool checks, and what it never touches.**
  - `defaults/Trainers_Forever.lua`: each record's `mapID` (a UiMap id: the code hands it to
    `C_Map` and `UiMapPoint`), its `mapName` against that UiMap row, the Map the UiMap sits on, its
    `subzone` and `city` against AreaTable and WMOAreaTable under the map's zone, and its `teaches`
    keys against the skill catalog. Trainer names are looked up in Creature and reported only: the
    Forever client's Creature table holds companion and mount creatures, not trainers (0 of 138
    names on 1.60.1.70938, 0 of 201 on 1.60.1.71091), so a miss there is no evidence.
  - `defaults/Fishing_Forever.lua`: each zone's `uiMapID` and enUS name against UiMap.
  - `defaults/SkillCatalog_Forever.lua`: every `skillLineID` and riding `aliasID` against SkillLine,
    and the open and icon spell ids against SpellName.
  - **Measured and design values are never checked against DB2 and never proposed**: trainer
    positions (x, y), costs, ranks, minimum levels, the gathering `need` values and the zone fishing
    levels. The client's tables do not hold them. The trainers are measured or sourced records, so
    the tool proposes **no trainer candidates**.
  - **ForeverDB evidence** (clients-§10's second source, for what DB2 cannot hold), when `derive`
    gets `--foreverdb`:
    - each trainer's `npcID` against ForeverDB's `npc` (`fdb-npc`: no row; `fdb-name`: the name
      differs), its `faction` against `nfac` (`fdb-side`; Neutral is `AH`), its point against the
      NPC's spots on the shipped `mapID` (`fdb-spot`: none, or the nearest more than 1.0 map-% away,
      the trainer probe's tolerance; `spm` points first, else `spw` world spawns projected through
      `umaa`), and its `teaches` against `spf`'s `ProfessionTrainers` and `WeaponMasters`
      (`fdb-role`);
    - each gathering node's and herb's name against ForeverDB's object names, `obj` (`fdb-node`).
      The `need` values are not checked: ForeverDB's `oskill` is empty at v2026.11.24.46.
    - ForeverDB is **evidence, not truth**: it never overrides a DB2 answer, and every disagreement
      is a flag that needs a ruling; nothing applies automatically.
    - **Its data is GPL-3.0.** No row goes into the repo, a fixture or a bundle: the bundle keeps
      the tag, its commit, every file's sha256 and the URLs (`SOURCES.md`), the per-id verdicts
      (`candidates.json`, `foreverdb.verdicts`: `found`, `missing`, `name-mismatch`, `ok`,
      `mismatch`, `position-off`, `no-spot`, `absent`) and the flags, which quote only the one field
      they compare. A replay re-fetches the pinned tag, which is immutable.
  - **The `verified` flags are not this tool's.** No seeds ruling changes them. Since GitHub issue
    #3 the trainers' flags come from the offline trainer probe (`tools/trainer_probe.lua`, its
    generated `defaults/TrainerProvenance_Forever.lua`); the other seeds' stay the owner's
    smoke-pass state.
- **Trainer references beyond DB2** (issue #3, and #2's comment naming ItemTree). The client's DB2
  holds no trainer NPC, so names, roles and positions are checked by the trainer probe (and, since
  2026-11-25, cross-checked here against ForeverDB, above), not against DB2:
  QuestieDB's Forever NPC table (the reference), the CMaNGOS 1.12 dump read by **ItemTree**'s method
  (ItemTree, curseforge.com/wow/addons/itemtree, v1.2.8: its trainer search classes a trainer by the
  rank spells its trainer rows teach, then its title; its Era data is that dump plus pfQuest's area
  ids, and its Forever data a pinned QuestieDB commit, so it is not independent of QuestieDB; it is
  All Rights Reserved, so the probe replicates the method and copies none of its data), pfQuest and
  Method.gg's guides. A seeds run that changes a trainer's `npcID`, `name`, `mapID`, `x` or `y` re-runs the probe
  after `apply` (below).
- **Only the tool writes the rulings, and `apply` only removes.** Rulings live in
  `tools/seeds/forever_rulings.json`, written only by `seeds.py rule`, keyed `<list>:<id>` for a
  candidate and `shipped:<kind>:<list>:<id>` for a flag, never by build. A ruling holds until the
  thing it ruled on stops being proposed. `apply` removes the trainer or fishing rows whose flag
  was ruled `remove`, and nothing else; it never adds a row, because every addition needs a value
  DB2 does not hold.
- **What a ruling may be.**
  - Candidates are ruled `reject` only (the tool refuses `accept`). A fishing candidate needs the
    zone's measured level, and a catalog candidate is a design decision (design goal 1: the
    catalog's lines, with anything else shown as an `other:` row), so the owner adds either by hand
    and the next derive stops proposing it. Reject with `needs owner review: <why>` whenever the
    owner might want it.
  - Flags are ruled `keep` or `remove`; `remove` exists only for a trainer or fishing row. A
    catalog, alias or spell flag (a wrong id or name) is fixed by hand in the seed file, and the
    flag disappears on the next derive.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in `tools/seeds/forever_rulings.json`;
  2. the seed files' own headers (`Fishing_Forever.lua`: levels recalled from 1.12, unverified;
     `Trainers_Forever.lua`: coordinates only where a source printed them (since issue #3, QuestieDB's
     single standing point, through the trainer probe), never a guessed pin;
     `SkillCatalog_Forever.lua`: the skill-line ids a `/sm probe` confirmed on build 70862);
  3. the design spec, `docs/superpowers/specs/2026-11-10-skill-master-design.md` (goal 1: the four
     categories and the lines in each);
  4. the owner's feedback rounds recorded in the plan ledger under `docs/superpowers/plans/`,
     among them: trust the sources (the CMaNGOS 1.12 dump) over smoke; nothing is shown as
     unverified; the Zephras Isle and Riverglades trainers are Neutral (2026-11-23); Annora's point
     is Uldaman's back entrance, 65.3, 42.6 (2026-11-24).
- **Fix policy for ForeverDB flags** (the owner, 2026-11-25: "fix everything flagged"): fix by hand
  every mismatch the evidence supports, judgment calls included, each with its evidence in the
  ruling's reason and one smoke row per shipped-data change, then rule the flag `keep` ("fixed by
  hand: ..."); the next derive stops raising it. Two things stay as they are: a recorded owner
  ruling (above), and a flag the data cannot decide (ForeverDB contradicting itself or another
  source with nothing to settle it), ruled `keep` with `needs owner review`. The bundle's
  `ANALYSIS.md` lists every judgment-call fix under *Judgment calls applied*.
- **Evidence.** Read the candidate's or flag's own rows in the bundle's `raw/*.csv.gz`. A name the
  client spells differently (a district without its "The", a city's short name) is a label
  question for the owner, not a wrong row: keep it and say so.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: forever

### Status

```sh
python3 "<root>/scripts/foreverdb.py" status
python3 tools/seeds/seeds.py status --flavor forever --foreverdb-tag <foreverdb>
```

The first prints the newest ForeverDB tag (`<foreverdb>`; `--foreverdb <tag>` on the command pins
another). The second prints `CURRENT <build> (<bundle>)`, or `NEW <build> (...)`, comparing the live
`wowf` build (the newest that is not a background download) and the tag with the newest
`docs/seed-research/*-forever` bundle: either one moving means a run.

### Freeze and derive

```sh
python3 "<root>/scripts/foreverdb.py" fetch --tag <foreverdb> --date <date>     # prints <fdb-dir>
python3 tools/seeds/seeds.py derive --flavor forever --bundle docs/seed-research/<date>-forever --date <date> --build <build> \
    --foreverdb <fdb-dir> --foreverdb-helper "dev-copilot <version>, scripts/foreverdb.py at <commit>"
```

The helper reads ForeverDB at the tag (or, with `--from-install <AddOns/ForeverDB>`, an installed
copy, read-only) into its own cache outside the repo; `seeds.py` reads only that cache and refuses
one whose `foreverdb.json` no longer matches its `SOURCES.json`. `derive` fetches the eight tables once per build into `tools/seeds/.cache/` (git-ignored, streamed, always
`?build=`, an identifying User-Agent), freezes them as `raw/*.csv.gz` (about 0.7 MB), and writes
`SOURCES.md` and `candidates.json`. `--replay` re-derives from `raw/` alone, offline. The coverage
gate checks sentinel rows of the build (Stormwind City, Booty Bay, Fishing, Alchemy, …) and a floor
on what the seed parse reads; **if it fails, stop**: the reader or the fetch needs fixing. Report
the candidate count, the flag count and the unruled count. `--replay` with no `--foreverdb` reads
the bundle's pinned tag from the helper's cache (`--foreverdb-cache` overrides the root) and stops,
naming the fetch, when it is not cached.

### Rule

```sh
python3 tools/seeds/seeds.py check --bundle docs/seed-research/<date>-forever
python3 tools/seeds/seeds.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-forever
```

`check` lists every unruled key and exits 1; it must print `OK` after `rule`.

- **Candidates** (`reject` only):
  - `fishing`: a UiMap zone (Type 3) the zone list lacks. Always `needs owner review`: its level
    is measured.
  - `catalog`: a SkillLine row in category 6, 9 or 11 with no parent line and no "Racial" or
    "[DNT]" in its name, that the catalog lacks. Reject an unused line (Flags 0) or a proficiency
    outside design goal 1's lines plainly; a WoW Forever line the design has not met is
    `needs owner review`.
- **Flags** (`keep` or, for trainers and fishing only, `remove`):
  - `map-unknown`, `map-instance`: the id is gone from the build. Remove the row unless its comment
    says why it ships.
  - `map-name`, `subzone`, `place`: a label the client spells differently or does not name. Keep
    it, with the client's spelling in the reason, unless the row is plainly in the wrong place.
  - `skill`: a `teaches` key that is no catalog key: fix it by hand, then keep.
  - `skill-name`, `skill-unknown`, `alias-*`, `spell-*`: fix the id or name by hand, then keep.
  - `fdb-npc`, `fdb-name`, `fdb-side`, `fdb-spot`, `fdb-role`, `fdb-node` (ForeverDB): the fix
    policy above. A name, side or point the evidence supports is fixed by hand and kept; a recorded
    owner ruling is kept citing it; a flag the data cannot decide is kept as `needs owner review`.
    `remove` is for a trainer that does not exist, never for a disagreement.

### Apply

```sh
python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>
```

`report` comes before `apply`, so `RULINGS.md` is written while the run's flags still include
every row a removal takes out. `apply` refuses while anything is unruled, keeps each file's line
endings and layout, and a second `apply` changes nothing.

### After

- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape: what changed between
  the builds, what was proposed and flagged and how it was ruled, what a later run should re-check.
- When a row was removed, or the owner added one by hand after a ruling, add a smoke check to
  `docs/smoke-tests.md` (the trainer popup or the fishing helper, Forever) and its *Pending
  sign-off* note. A run that changes no shipped list adds none.
- When a removal changes a trainer count a test pins (`tests/test_trainers.lua`), update the test.
- When a hand fix changed a trainer's `npcID`, `name`, `mapID`, `x` or `y` (the values the probe
  confirms), re-run the trainer probe with `--write-provenance` (`docs/testing.md`): the suite fails a
  confirmed record whose values changed. A side (`faction`) fix needs no probe run: the provenance
  file stores no side, and the probe's side check accepts either side against QuestieDB's AH.

### Stage

`tools/seeds/forever_rulings.json`, `docs/seed-research/<date>-forever`, plus
`defaults/Trainers_Forever.lua`, `defaults/Fishing_Forever.lua`, `defaults/Gathering_Forever.lua` and any test, smoke or citation edit
when `apply` or a hand fix changed one. Commit message:
`Seeds (forever): re-validated against <build> (<date>)`.

## Gate

```sh
KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m pytest -q -p no:cacheprovider tools/seeds
```

luacheck must report 0 warnings and 0 errors, and both suites 0 failed. The addon is Forever-only,
so the headless suite runs under the Forever kit profile alone (`tests/client_pin.lua` pins it).

## Notes

- **The client holds no trainer NPCs.** Forever's Creature table is the client's sparse copy
  (companions and mounts). A trainer's name, role and position are checked offline by the trainer
  probe against QuestieDB (issue #3) and by this tool against ForeverDB, and what no source settles
  is on the probe's in-game spot-check list (`docs/trainer-probe/<run>/report.md`) or the bundle's
  *Needs owner review* list.
- **AreaTable-only zones are not proposed.** The fishing list is keyed by uiMapID, so only a UiMap
  zone can be a candidate; an AreaTable zone with no UiMap has no key to ship under.
- **City districts are WMO areas.** Stormwind's Mage Quarter or Ironforge's Great Forge are
  WMOAreaTable rows (`AreaTableID` = the city's area), not AreaTable rows, so the subzone check
  reads both. Thunder Bluff's Lower, Middle and High Rise are named in neither.
- **Gathering nodes are server objects.** DB2 holds no game objects, so `defaults/Gathering_Forever.lua`'s
  node and herb names are checked against ForeverDB's `obj` names only; their `need` values stay
  unchecked. `Racials_Forever.lua` (design values) is not checked.
- **ForeverDB's `spf` roles are weaker than its NPC titles.** On v2026.11.24.46 `spf.ProfessionTrainers`
  disagrees with ForeverDB's own `npc` titles on 16 of 294 rows (a run of neighboring Forever-only
  ids), and `spf.WeaponMasters` names Fist Weapons for no master. Read a `fdb-role` flag against the
  NPC's title before believing it.
- **Shared helper.** Whether one helper should carry the build pin, the cache, the bundle and the
  rulings for every Ka0s addon is LibKa0s#91.
