# Analysis: Skill Master seed validation, 2026-11-15 (forever, build 1.60.1.70938)

The first run of `tools/seeds/seeds.py` (contract: `docs/validate-seeds.md`), against wago.tools
product `wowf`, build `1.60.1.70938`, the live WoW Forever build on 2026-11-15. There is no previous
bundle, so this run sets the baseline the next one diffs against.

## What was checked

| List | Shipped | Checked against | Result |
| --- | --- | --- | --- |
| Trainers (`defaults/Trainers_Forever.lua`) | 138 records | UiMap, UiMapAssignment, Map, AreaTable, WMOAreaTable; the catalog keys | every mapID is a zone UiMap on a known Map; 21 `map-name` and 31 `subzone` flags, all labels; every `teaches` key is a catalog key |
| Fishing zones (`defaults/Fishing_Forever.lua`) | 43 zones | UiMap, UiMapAssignment, Map | every uiMapID and enUS name matches its UiMap row; no flags |
| Skill lines (`defaults/SkillCatalog_Forever.lua`) | 31 skill-line ids, 8 riding alias ids | SkillLine | every id exists and carries the catalog's name; no flags |
| Open and icon spells (same file) | 9 open, 12 icon spell ids | SpellName | every id exists and every open spell's name is the one cast; no flags |
| Trainer names | 138 | Creature | 0 found: the client's Creature table holds 183 companion and mount names, so this is no evidence (report only) |

Nothing was accepted and nothing was removed: `apply` made **0 changes**, and no seed file moved.

## The flags (52, all `keep`)

- **`map-name`, 21:** every Stormwind record carries `mapName = "Stormwind"`, while UiMap 1453 is
  `Stormwind City`. The mapID, which the waypoint uses, is right. The label is the source's short
  name (the City Tour), and the fishing list already says `Stormwind City`. Kept; renaming the
  label is the owner's call.
- **`subzone`, Thunder Bluff, 17:** `Lower Rise`, `Middle Rise` and `High Rise` are the City Tour's
  labels. Thunder Bluff's AreaTable names only Elder, Spirit and Hunter Rise, and its WMOAreaTable
  rows carry no district names, so the client has nothing to check these against. Kept.
- **`subzone`, Undercity, 14:** the client names the districts `War Quarter`, `Rogues' Quarter`,
  `Magic Quarter` and `Trade Quarter` (WMOAreaTable, under area 1497), with no leading "The"; the
  seed says `The War Quarter` and so on. `The Apothecarium` matches. Kept as
  **needs owner review**: the rows are right, and the chat label could drop "The" by hand.

## The candidates (15, all `reject`)

- **Fishing, 8, all needs owner review** (a level is measured, and DB2 holds none):
  - vanilla zones missing from the recalled 1.12 list: Badlands (1418), Blasted Lands (1419),
    Searing Gorge (1427);
  - WoW Forever zones with no recorded level: Mount Hyjal (2482), Zephras Isle (2521, plus a
    second System-1 UiMap 2665), Riverglades (2548), Shen'dralas (2652).

  A player fishing in any of these gets no fishing level from the helper today.
- **Skill lines, 7:**
  - **rejected outright, 3:** Dual Wield (118) is a proficiency, not one of the 16 weapon lines;
    Survival (142) and Swimming (155) are unused vanilla lines (Flags 0).
  - **needs owner review, 4:**
    - Poisons (40), the rogue line that ranks like Lockpicking;
    - Galestrider Riding (3011), a WoW Forever riding line with the racial riding lines' Flags 144,
      which may belong in `riding.aliasIDs`;
    - Comprehension (3012), a WoW Forever secondary-category line;
    - Feral Combat (3014), a WoW Forever weapon-category line; the class line 134 is category 7.

    A line the catalog lacks shows today as an `other:` row with the unknown icon.

## For the owner

1. Galestrider Riding (3011): if it is a race's riding line, add it to `riding.aliasIDs` and the
   `aliases` names in `defaults/SkillCatalog_Forever.lua`, so it folds into the Riding row.
2. Poisons, Comprehension and Feral Combat (3014): show them as catalog lines, or leave them as
   `other:` rows.
3. The eight fishing zones: measure a level in game for any that has water, and add it by hand.
4. The Undercity district labels and the `Stormwind` map label: keep them, or spell them as the
   client does.

## What a later run should re-check

- Whether later Forever builds add zones (UiMap Type 3) or skill lines; each shows up as a new
  candidate, and every ruling here stays put.
- Whether Creature ever carries trainer NPCs. If it does, the trainer names can be checked for
  real, and the tool's report-only line becomes a flag.
- The catalog header's `/sm probe` note (build 70862) against each new build: on this one every
  skill-line id still resolves, so the probe and DB2 agree.
