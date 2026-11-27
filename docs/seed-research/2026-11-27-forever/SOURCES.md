# Sources: Skill Master seed validation, 2026-11-27 (forever)

Written by `tools/seeds/seeds.py derive`. Do not edit by hand.

- Product: wago.tools `wowf` (WoW Forever)
- Build: `1.60.1.71139` (created unknown, per https://wago.tools/api/builds)
- Run date: 2026-11-27 (passed as `--date`; the tool reads no clock)
- User-Agent: `SkillMaster-seed-check`

| Table | URL | Bytes (csv) | Why |
| --- | --- | --- | --- |
| UiMap | `https://wago.tools/db2/UiMap/csv?build=1.60.1.71139` | 3097 | Name_lang, Type, ParentUiMapID: the trainer mapIDs and fishing uiMapIDs (C_Map ids) |
| UiMapAssignment | `https://wago.tools/db2/UiMapAssignment/csv?build=1.60.1.71139` | 6778 | UiMapID -> AreaID and MapID: the zone area a place must sit under, and its Map |
| Map | `https://wago.tools/db2/Map/csv?build=1.60.1.71139` | 12296 | ID, MapName_lang: the instance (continent) each UiMap sits on |
| AreaTable | `https://wago.tools/db2/AreaTable/csv?build=1.60.1.71139` | 152398 | AreaName_lang, ParentAreaID: the subzones and places under a zone |
| WMOAreaTable | `https://wago.tools/db2/WMOAreaTable/csv?build=1.60.1.71139` | 2340576 | AreaName_lang, AreaTableID: the city districts, which are WMO areas |
| SkillLine | `https://wago.tools/db2/SkillLine/csv?build=1.60.1.71139` | 14266 | DisplayName_lang, CategoryID, ParentSkillLineID: the catalog's skill-line ids |
| SpellName | `https://wago.tools/db2/SpellName/csv?build=1.60.1.71139` | 851618 | Name_lang: the catalog's open and icon spell ids |
| Creature | `https://wago.tools/db2/Creature/csv?build=1.60.1.71139` | 11970 | Name_lang: the trainers' names, reported only (the client table holds no trainers) |

Each table is frozen as `raw/<Table>.csv.gz`; `seeds.py derive --replay` re-derives from them with no network and no cache.

## ForeverDB (second evidence source, clients-§10)

ForeverDB's data is GPL-3.0, so this bundle keeps no raw rows: only the pin below, the per-id verdicts in `candidates.json` (`foreverdb.verdicts`) and the flags. A replay re-fetches the pinned tag, which is immutable, through dev-copilot's `scripts/foreverdb.py fetch --tag v2026.11.27.57 --date <date>`.

- Repository: https://github.com/foreverfraddons/forever-db
- Tag: `v2026.11.27.57`, commit `70113b63e998eb3a0ef9cf6c2b3c320effd46258` (TOC `## Version` 2026.11.27.57; meta.build 2026-11-27, meta.hash `ebff6aa0b75a410b`)
- Fetched: 2026-11-27, from github
- Helper: dev-copilot 2.12.0, scripts/foreverdb.py at installed
- Spot tolerance: 1.0 map-% (the trainer probe's)

| File | Bytes | sha256 (as fetched) | sha256 (LF) |
| --- | --- | --- | --- |
| `ForeverDB/ForeverDB.toc` | 625 | `65fd6201a1e24e108aed08ed8b54644701074bb214239b051792932094863503` | `65fd6201a1e24e108aed08ed8b54644701074bb214239b051792932094863503` |
| `ForeverDB/ForeverDB.lua` | 3230294 | `9cc9c9d1de813057cb77dcf7fd7173961857dd77b3ef5052781e7c855311e015` | `9cc9c9d1de813057cb77dcf7fd7173961857dd77b3ef5052781e7c855311e015` |
| `ForeverDB/ForeverDB_2.lua` | 3441179 | `e95cc3ff3e269aed9bb65edd4b617ba8a0a47f83af05ba4360e7e7f2dfe10960` | `e95cc3ff3e269aed9bb65edd4b617ba8a0a47f83af05ba4360e7e7f2dfe10960` |
| `ForeverDB/ForeverDB_3.lua` | 3299195 | `e313fc96cbe1458b9f6ff07ff8b3eba68bdf666c979614b138dfb928721869aa` | `e313fc96cbe1458b9f6ff07ff8b3eba68bdf666c979614b138dfb928721869aa` |
| `ForeverDB/ForeverDB_4.lua` | 2016410 | `b50275696ff8606ea812c16433465abdaf9b82c3000a8e581c0ea7f7c87a5faf` | `b50275696ff8606ea812c16433465abdaf9b82c3000a8e581c0ea7f7c87a5faf` |

URLs: `https://raw.githubusercontent.com/foreverfraddons/forever-db/70113b63e998eb3a0ef9cf6c2b3c320effd46258/ForeverDB/ForeverDB.toc`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/70113b63e998eb3a0ef9cf6c2b3c320effd46258/ForeverDB/ForeverDB.lua`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/70113b63e998eb3a0ef9cf6c2b3c320effd46258/ForeverDB/ForeverDB_2.lua`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/70113b63e998eb3a0ef9cf6c2b3c320effd46258/ForeverDB/ForeverDB_3.lua`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/70113b63e998eb3a0ef9cf6c2b3c320effd46258/ForeverDB/ForeverDB_4.lua`
