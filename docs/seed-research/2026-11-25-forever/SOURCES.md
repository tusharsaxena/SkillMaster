# Sources: Skill Master seed validation, 2026-11-25 (forever)

Written by `tools/seeds/seeds.py derive`. Do not edit by hand.

- Product: wago.tools `wowf` (WoW Forever)
- Build: `1.60.1.71091` (created unknown, per https://wago.tools/api/builds)
- Run date: 2026-11-25 (passed as `--date`; the tool reads no clock)
- User-Agent: `SkillMaster-seed-check`

| Table | URL | Bytes (csv) | Why |
| --- | --- | --- | --- |
| UiMap | `https://wago.tools/db2/UiMap/csv?build=1.60.1.71091` | 3097 | Name_lang, Type, ParentUiMapID: the trainer mapIDs and fishing uiMapIDs (C_Map ids) |
| UiMapAssignment | `https://wago.tools/db2/UiMapAssignment/csv?build=1.60.1.71091` | 6778 | UiMapID -> AreaID and MapID: the zone area a place must sit under, and its Map |
| Map | `https://wago.tools/db2/Map/csv?build=1.60.1.71091` | 12296 | ID, MapName_lang: the instance (continent) each UiMap sits on |
| AreaTable | `https://wago.tools/db2/AreaTable/csv?build=1.60.1.71091` | 152398 | AreaName_lang, ParentAreaID: the subzones and places under a zone |
| WMOAreaTable | `https://wago.tools/db2/WMOAreaTable/csv?build=1.60.1.71091` | 2340576 | AreaName_lang, AreaTableID: the city districts, which are WMO areas |
| SkillLine | `https://wago.tools/db2/SkillLine/csv?build=1.60.1.71091` | 14266 | DisplayName_lang, CategoryID, ParentSkillLineID: the catalog's skill-line ids |
| SpellName | `https://wago.tools/db2/SpellName/csv?build=1.60.1.71091` | 851602 | Name_lang: the catalog's open and icon spell ids |
| Creature | `https://wago.tools/db2/Creature/csv?build=1.60.1.71091` | 11970 | Name_lang: the trainers' names, reported only (the client table holds no trainers) |

Each table is frozen as `raw/<Table>.csv.gz`; `seeds.py derive --replay` re-derives from them with no network and no cache.

## ForeverDB (second evidence source, clients-§10)

ForeverDB's data is GPL-3.0, so this bundle keeps no raw rows: only the pin below, the per-id verdicts in `candidates.json` (`foreverdb.verdicts`) and the flags. A replay re-fetches the pinned tag, which is immutable, through dev-copilot's `scripts/foreverdb.py fetch --tag v2026.11.24.46 --date <date>`.

- Repository: https://github.com/foreverfraddons/forever-db
- Tag: `v2026.11.24.46`, commit `6e0a34b4bd017483aff616f5766348e1cea519ae` (TOC `## Version` 2026.11.24.46; meta.build 2026-11-24, meta.hash `34e1dda1e0baf54c`)
- Fetched: 2026-11-25, from github + install
- Helper: dev-copilot 2.12.0, scripts/foreverdb.py at commit 140d30ba69c6e602e40cbe8151693b4936aa8736 (branch feat/2026-11-25-seeds-foreverdb)
- Owner's install read: version 2026.11.24.46 (`/mnt/g/Games/Blizzard/World of Warcraft/_forever_/Interface/AddOns/ForeverDB`), confirmed against the tag by its sha256
- Spot tolerance: 1.0 map-% (the trainer probe's)

| File | Bytes | sha256 (as fetched) | sha256 (LF) |
| --- | --- | --- | --- |
| `ForeverDB/ForeverDB.toc` | 625 | `0f58c1666f22332a2b1b0de9a665dc78acab3db9ac8207ee23e8ecd6e4375e0c` | `0f58c1666f22332a2b1b0de9a665dc78acab3db9ac8207ee23e8ecd6e4375e0c` |
| `ForeverDB/ForeverDB.lua` | 3231144 | `8db482a11ce9dc96db8a00d9fb1fcc95a22a564fa64c8f3547ab95c913b19bc4` | `8db482a11ce9dc96db8a00d9fb1fcc95a22a564fa64c8f3547ab95c913b19bc4` |
| `ForeverDB/ForeverDB_2.lua` | 3433858 | `72a641230b2d96ccc812a0065c35ebe6f1770eebf13ad745cb27260b53accb9a` | `72a641230b2d96ccc812a0065c35ebe6f1770eebf13ad745cb27260b53accb9a` |
| `ForeverDB/ForeverDB_3.lua` | 3313064 | `843aed45dd307caea7e4a3dd7c4c4c326278005c4c09a947d7c3d160497ed466` | `843aed45dd307caea7e4a3dd7c4c4c326278005c4c09a947d7c3d160497ed466` |
| `ForeverDB/ForeverDB_4.lua` | 1971859 | `7a0218364c64edba12d9cedcb67e777fcdbdd005418ca1451354bd5471f6a386` | `7a0218364c64edba12d9cedcb67e777fcdbdd005418ca1451354bd5471f6a386` |

URLs: `https://raw.githubusercontent.com/foreverfraddons/forever-db/v2026.11.24.46/ForeverDB/ForeverDB.toc`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/v2026.11.24.46/ForeverDB/ForeverDB.lua`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/v2026.11.24.46/ForeverDB/ForeverDB_2.lua`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/v2026.11.24.46/ForeverDB/ForeverDB_3.lua`, `https://raw.githubusercontent.com/foreverfraddons/forever-db/v2026.11.24.46/ForeverDB/ForeverDB_4.lua`
