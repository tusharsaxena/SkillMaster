# Analysis: Skill Master seed validation, 2026-11-25 (forever, build 1.60.1.71091 + ForeverDB v2026.11.24.46)

The second run of `tools/seeds/seeds.py` (contract: `docs/validate-seeds.md`) and the first with
**ForeverDB** as the second evidence source (clients-§10; LibKa0s#102 and #105, the
2026-11-25 seeds and ForeverDB run). DB2: wago.tools product `wowf`, build `1.60.1.71091`, the
newest live build that is not a background download on 2026-11-25. ForeverDB: tag
`v2026.11.24.46`, commit `6e0a34b4bd01`, the same build as the owner's install (confirmed by sha256).
The helper was dev-copilot 2.12.0's `scripts/foreverdb.py` at `140d30ba69c6` (the run's feature
branch; `SOURCES.md` has the full pin). The previous bundle is `2026-11-15-forever` (build
1.60.1.70938).

## What changed in the tool

- **The trainer reader was broken on the shipped file.** Since the trainer probe (issue #3) and the
  feedback rounds, `defaults/Trainers_Forever.lua` rows carry an `npcID` and coordinates, the weapon
  masters' and riding rows grew, and two records are standalone `add{}` calls. The old reader keyed on
  row length and stopped at the first Expert row. It now reads each block's field positions from the
  `add{}` its rows feed, so it covers all 201 records; its output was checked field by field against
  the file loaded by Lua (identical), and `test_seeds.py` parses the shipped file.
- **ForeverDB evidence** (`derive --foreverdb`): trainers against `npc`, `nfac`, the NPC's spots
  (`spm`, else `spw` projected through `umaa`) and `spf`'s trainer tables; gathering nodes against
  `obj`. Verdicts only; no ForeverDB row is in this bundle (GPL-3.0).
- `status` compares the ForeverDB tag as well as the build, and skips background-download builds.
  The User-Agent is now `SkillMaster-seed-check`.

## DB2 (1.60.1.71091 against 1.60.1.70938)

Seven of the eight frozen tables are byte-identical to the previous bundle's; only `SpellName` grew.
The run proposes the same 15 candidates and the same 52 label flags as 2026-11-15, all ruled then
and still held (`RULINGS.md`). The 63 trainers added since (round 2's Forever-only trainers and the
probe's records) raise no DB2 flag: their mapIDs are zone UiMaps, and they name no subzone.

## ForeverDB (v2026.11.24.46)

| Check | Result |
| --- | --- |
| Trainer npcID in `npc` | 201 of 201 found; every name matches |
| Side (`nfac`) | 196 agree; 5 Neutral records that ForeverDB gives one side |
| Spot on the shipped map (1.0 map-% tolerance) | 200 within tolerance (the largest gap 0.36 map-%); Annora has no spot on the Badlands map |
| Role (`spf`) | 174 agree, 19 absent from `spf` (riding, books and quests), 8 disagree |
| Gathering node and herb names (`obj`) | 41 of 41 found |

So ForeverDB, an independent build of the Forever server's data, confirms every trainer's NPC, name
and point that QuestieDB and the trainer probe gave. There was nothing to fix in names or positions.

### The 14 flags and their rulings

- **Kept by a recorded owner ruling, 5:**
  - Annora (`fdb-spot`): her only spawn is inside Uldaman (instance map 70), and her shipped point is
    the dungeon's back entrance (the owner, 2026-11-24).
  - Iaadaria Bitterwind, Gorg, Gur'dok, Alphonse Dumas (`fdb-side`): Zephras Isle and Riverglades
    trainers are Neutral (the owner, 2026-11-23); ForeverDB's `nfac` is the NPC's own side.
- **Kept, fist weapons, 3:** Buliwyf Stonehand, Ilyenia Moonfire, Sayoc (`fdb-role`). `spf.WeaponMasters`
  names Fist Weapons (473) for none of the eight masters, so it does not model the line; the CMaNGOS
  1.12 dump teaches it at these three (trust the sources).
- **Kept, the data cannot decide, 5:** Aedi Thriceforged, Eaysaa Brightgust, Nasalanna Windsinger,
  Messana Crestwind, Norzsh (`fdb-role`). ForeverDB's own `npc` titles (Miner, Alchemist, Skinner,
  Leatherworker, Weaponsmith) agree with the shipped roles, while its `spf.ProfessionTrainers` says
  Blacksmithing, Enchanting, Enchanting, Mining and Mining. `spf` disagrees with ForeverDB's titles
  on 16 of its 294 rows, mostly a run of neighboring Forever-only ids, and lists a "Weapon Merchant"
  and a "General Goods" vendor as trainers, so a role from `spf` alone is not evidence enough.
- **Fixed by hand, 1:** Angelique Butler (`fdb-side`), below.

## Judgment calls applied

- **Angelique Butler (First Aid Trainer, Alterac Mountains, npc 251977): Neutral to Alliance.**
  ForeverDB's `nfac` says Alliance, and every other Alterac Mountains Forever trainer (Alard Schmied,
  Linzy Blackbolt, Charles Worth, Vanessa Sellers, Katherine Lee, Edward Egan, Patricia Egan) is
  Alliance in both QuestieDB and ForeverDB. QuestieDB alone made her Neutral, and no owner ruling
  covers Alterac Mountains. Effect: she leaves the Horde trainer lists; Horde First Aid keeps every
  capital trainer. Smoke: SM-SEEDFDB-1. To reverse it, set her row back to `"Neutral"`; a later run
  then flags her again. She is not a probe-confirmed record, and the probe's confirmation
  covers npcID, name, mapID and point, not side, so `defaults/TrainerProvenance_Forever.lua` is
  unchanged and no probe re-run was needed; the next probe run will report that QuestieDB says
  Neutral.

## Needs owner review

1. The five `spf` role disagreements above: in game, does Aedi Thriceforged train Mining, Eaysaa
   Brightgust Alchemy, Nasalanna Windsinger Skinning, Messana Crestwind Leatherworking, and Norzsh
   Blacksmithing? `spf` puts Kagil, Norzsh and Zor'la (Durotar) where a Junior Skinning, Mining and
   Herbalism trio would sit, like Tirisfal's and Mulgore's; if Durotar has one, the shipped Norzsh row
   is wrong. SM-SEEDFDB-2 is the check.
2. Mining nodes ForeverDB names that the list lacks: Cold Iron Deposit, Starsilver Vein, Heavy and
   Hakkari Thorium Vein, Poor Copper Vein, Spectral Iron Deposit, Fool's Gold Vein, and the
   "Ooze Covered" variants of seven shipped veins. Each needs a measured skill level before it can be
   added (ForeverDB holds none), so none was.

## For a later run

- Re-run when the `wowf` build **or** the ForeverDB tag moves (`seeds.py status --foreverdb-tag`).
- ForeverDB's `oskill` (object skill requirements) is empty at this tag; once it carries rows, the
  gathering `need` values become checkable.
- If a later tag fixes `spf.ProfessionTrainers`' shifted run, the five role flags disappear.
