# Sources: Skill Master seed validation, 2026-11-15 (forever)

Written by `tools/seeds/seeds.py derive`. Do not edit by hand.

- Product: wago.tools `wowf` (WoW Forever)
- Build: `1.60.1.70938` (created 2026-11-13 01:36:09, per https://wago.tools/api/builds)
- Run date: 2026-11-15 (passed as `--date`; the tool reads no clock)
- User-Agent: `ka0s-seed-validation (SkillMaster tools/seeds)`

| Table | URL | Bytes (csv) | Why |
| --- | --- | --- | --- |
| UiMap | `https://wago.tools/db2/UiMap/csv?build=1.60.1.70938` | 3097 | Name_lang, Type, ParentUiMapID: the trainer mapIDs and fishing uiMapIDs (C_Map ids) |
| UiMapAssignment | `https://wago.tools/db2/UiMapAssignment/csv?build=1.60.1.70938` | 6778 | UiMapID -> AreaID and MapID: the zone area a place must sit under, and its Map |
| Map | `https://wago.tools/db2/Map/csv?build=1.60.1.70938` | 12296 | ID, MapName_lang: the instance (continent) each UiMap sits on |
| AreaTable | `https://wago.tools/db2/AreaTable/csv?build=1.60.1.70938` | 152398 | AreaName_lang, ParentAreaID: the subzones and places under a zone |
| WMOAreaTable | `https://wago.tools/db2/WMOAreaTable/csv?build=1.60.1.70938` | 2340576 | AreaName_lang, AreaTableID: the city districts, which are WMO areas |
| SkillLine | `https://wago.tools/db2/SkillLine/csv?build=1.60.1.70938` | 14266 | DisplayName_lang, CategoryID, ParentSkillLineID: the catalog's skill-line ids |
| SpellName | `https://wago.tools/db2/SpellName/csv?build=1.60.1.70938` | 851160 | Name_lang: the catalog's open and icon spell ids |
| Creature | `https://wago.tools/db2/Creature/csv?build=1.60.1.70938` | 11970 | Name_lang: the trainers' names, reported only (the client table holds no trainers) |

Each table is frozen as `raw/<Table>.csv.gz`; `seeds.py derive --replay` re-derives from them with no network and no cache.
