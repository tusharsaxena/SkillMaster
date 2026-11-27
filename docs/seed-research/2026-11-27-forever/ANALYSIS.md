# Analysis: Skill Master seed validation, 2026-11-27 (forever, build 1.60.1.71139 + ForeverDB v2026.11.27.57)

The third run of `tools/seeds/seeds.py` (contract: `docs/validate-seeds.md`), the second with ForeverDB.
It was run for GitHub issue #10, the verification pass over every Forever data table, after the owner's
ruling of 2026-11-27: the tables are validated from the sources (wago.tools and ForeverDB), with no
trainer visits in game. DB2: wago.tools product `wowf`, build `1.60.1.71139`, the newest live build
that is not a background download on 2026-11-27. ForeverDB: tag `v2026.11.27.57`, commit
`70113b63e998` (`SOURCES.md` has the full pin and every file's sha256). The previous bundle is
`2026-11-25-forever` (build 1.60.1.71091, ForeverDB v2026.11.24.46).

## DB2 (1.60.1.71139 against 1.60.1.71091)

Seven of the eight frozen tables are byte-identical to the previous bundle's. `SpellName` changed
content at the same row count (32,512 rows). The run proposes the same 15 candidates and the same
52 label flags (31 `subzone`, 21 `map-name`). All were ruled on 2026-11-15 and still hold
(`RULINGS.md`).

## ForeverDB (v2026.11.27.57)

| Check | Result |
| --- | --- |
| Trainer npcID in `npc` | 201 of 201 found; every name matches |
| Side (`nfac`) | 197 agree; 4 Neutral records that ForeverDB gives one side (5 on v2026.11.24.46) |
| Spot on the shipped map (1.0 map-% tolerance) | 200 within tolerance (the largest gap 0.36 map-%); Annora has no spot on the Badlands map |
| Role (`spf`) | 174 agree, 19 absent from `spf` (riding, books and quests), 8 disagree |
| Gathering node and herb names (`obj`) | 41 of 41 found |

The 13 ForeverDB flags are the 2026-11-25 run's, minus one side flag the new tag no longer raises,
and they keep their rulings:
- 4 Neutral sides (Zephras Isle and Riverglades, the owner's ruling of 2026-11-23);
- Annora's spot (Uldaman's back entrance, the owner's ruling of 2026-11-24);
- 3 fist-weapon masters `spf` does not model;
- 5 profession roles where `spf` contradicts ForeverDB's own NPC titles, which agree with the shipped
  roles.

Nothing needed a fix and `apply` changed nothing.

## What this settles for issue #10

Against two independent sources (Forever's own DB2, and ForeverDB, a build of the Forever server's
data), this run confirms:
- every trainer's NPC, name, point and side;
- every skill line, alias and spell id in the catalog;
- every fishing zone's UiMap id and name;
- every gathering node's and herb's name.

What DB2 and this tool cannot hold (costs, minimum levels, the gathering `need` and zone fishing
levels, racials, class weapons and the stat formulas) is validated separately for #10 and recorded
in its commit.

## Re-check next run

Whether `spf.ProfessionTrainers` still contradicts the NPC titles, and whether ForeverDB's `oskill`
(gathering skill per object) is filled yet. Once it is, the `need` values become checkable here.
