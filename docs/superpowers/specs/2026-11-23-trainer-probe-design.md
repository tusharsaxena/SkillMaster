# Trainer probe — offline verification of the trainer data (SkillMaster#3)

Started 2026-11-23. Branch `feat/2026-11-23-skillmaster-trainer-probe` off `master` `0f8d652`.
Builds GitHub issue #3, the build ticket for the research in #2. The plan and its checkpoints are
`docs/superpowers/plans/2026-11-23-trainer-probe.md`.

## The issue (verbatim)

> ## Goal
>
> Check every trainer record in `defaults/Trainers_Forever.lua` against an offline data source, with no in-game travel. Checking 138 NPCs in game would take two characters, both factions and hours per pass, and would need redoing after every data or client change.
>
> This is the build ticket for the approach researched in #2.
>
> ## Proposal: an offline probe
>
> A script under `tools/`, run from the shell (not shipped in the addon). It:
>
> 1. Loads `defaults/Trainers_Forever.lua` (and `Ranks_Forever.lua`) headless, the way `tests/run.lua` loads the addon.
> 2. Loads a pinned copy of QuestieDB's Forever NPC table (`data/Forever/foreverNpcDB.lua`, by commit sha) plus its `areaIdToUiMapId` table.
> 3. Joins records by NPC name and faction, and reports, per record:
>    - **name**: no match, or more than one match (for example "Doctor Martin Felbin" vs *Felben*);
>    - **role**: the NPC has no trainer bit (npcFlags 0x10), or its subName doesn't name our skill or rank (for example Gorina, a Mining Supplier);
>    - **place**: its AreaID doesn't map to our `mapID`, or our `x`/`y` is more than N map-% from its spawn (Woo Ping on Forever's re-bounded Stormwind map);
>    - **duplicates**: two records sharing one point (Bixi Wobblebonk and Buliwyf).
> 4. Writes a dated report (markdown plus JSON) under `docs/trainer-probe/<date>/`, plus a suggested patch for the coordinates.
>
> ## Acceptance
>
> - [ ] `lua tools/trainer_probe.lua <path-to-QuestieDB>` runs offline and writes the report.
> - [ ] The four known errors from #2 show up in the first report and are fixed in the data.
> - [ ] A record the probe confirms can drop `verified = false`, with its source and the QuestieDB sha recorded (`NS.DataMeta`).
> - [ ] The headless suite gains a check that every shipped record has either a probe confirmation or an explicit `unverified` reason.
> - [ ] Licensing note: QuestieDB is GPLv3 for contributions. Ship only our own corrected numbers and the sha, never their table.
>
> ## Out of scope
>
> Creature positions are server data, not client DB2, so wago.tools exports can check map IDs and frames but not trainer positions (see #2). New or moved Forever-only NPCs still need an in-game spot check, and the probe should list them for one.

## The owner's comments (verbatim)

> **2026-11-16:** Method.gg has a list of trainer locations - e.g. https://www.method.gg/wow-forever/wow-forever-cooking-profession-leveling-guide-items-and-trainers#leveling-cooking-150-225

> **2026-11-16:** Also add notes about books which give training (along side vendor who sells)

> **2026-11-23:** The ItemTree addon also has trainer locations - use that as a potential data source and try to replicate how it sources the data
> https://www.curseforge.com/wow/addons/itemtree

## What the addon models today

- `defaults/Trainers_Forever.lua`: 138 records (name, faction, city, subzone, `mapName`, `mapID`,
  optional `x`/`y`, `cost`, `costByKey`, `minLevelByKey`, `teaches`, `ranks`, `race`, `source`),
  every one `verified = false`. Only the 8 weapon masters carry coordinates.
- `defaults/Ranks_Forever.lua`: the rank ladders (cap, level gate, skill gate, cost).
- No recipe data and no "how is this rank learned" field. The out-of-city Expert and Artisan rows
  for Cooking, First Aid and Fishing are book vendors or quest givers stored as if they were
  trainers; the file's comment says so and nothing else does.
- The trainer popup (`modules/TrainerPopup.lua`) draws a card per trainer: name, cost, place, an
  "Also teaches" line, and a warning while any card is unverified. Chat directions
  (`modules/Waypoints.lua`) and the row tooltip (`modules/RowTooltip.lua`) name the trainer too.

## Sources and their pins

| Source | Pin | Use |
| --- | --- | --- |
| QuestieDB (github.com/Questie/QuestieDB) `data/Forever/` + `support/Forever/` + the four static NPC correction layers | commit `47a4756b775e8c73687fd3066d6c13f0bc43a55e` (2026-11-23) | The reference: Forever names, titles (subName), npcFlags, sides, spawns, book vendors, rank-quest starts; `conversion.json`'s per-area frame transform |
| CMaNGOS classic-db (github.com/cmangos/classic-db) `Full_DB/ClassicDB_1_12_1_z2815.sql.gz` | commit `22b51464f1625f6ef6275771de1f5466c6f5d19e`, sha256 `4f92db52…d0c0` (the pin ItemTree's own compiler names) | ItemTree's method: what each trainer's rows teach, the rank books and their vendors, the rank quests and their givers (cross-check) |
| pfQuest (github.com/shagu/pfQuest) `db/units.lua` | commit `104f35678ca39ab1fb78b655f815cc7016f5e0c8`, sha256 `b8de09aa…a922` | Era spawns, projected into Forever's frame (cross-check) |
| ItemTree (curseforge.com/wow/addons/itemtree) | v1.2.8, the owner's install (copied read-only); its compiler at github.com/Rockjaw-Bonesnapper-Co/itemtree-era-sources `4e3acfcd` | The method only (below). All Rights Reserved: nothing of it is copied |
| Method.gg WoW Forever profession guides | 12 pages read 2026-11-23 (no Engineering or weapon-master page exists) | Whether a guide names each NPC (cross-check, names only) |

The CurseForge download was blocked (HTTP 403); the owner's installed copy replaced it.

### How ItemTree sources its trainers (the method replicated)

ItemTree's `Core/TrainerSearch.lua` header and its published compiler say: Classic Era trainers
come from the CMaNGOS dump's trainer tables, the profession and top rank **by the rank spells a
trainer's rows teach** (each "learn" spell resolved through `spell_template`), then by its title's
words; places from the dump's spawns with pfQuest's area ids; Forever additions from a pinned
QuestieDB commit (its `OpenSources.lua`), the client's own vendor tables and crowd-sourced player
sightings. The probe replicates the offline part: the rank-spell reading of the dump
(`tools/trainer_probe/cmangos.lua`), pfQuest's Era spawn, and QuestieDB as the Forever reference.
The client vendor tables and player sightings need a running client and players, so they are not
replicated; the in-game spot-check list stands in for them.

## Decisions (made in this session; each recorded here)

- **D1 — Reference and confirmation.** QuestieDB's Forever NPC table, with its four static
  correction layers applied in its own order, is the reference. A record is confirmed when its
  name (or `npcID`) matches exactly one NPC of its side, the role holds (the trainer bit and a
  title naming the skill and the top rank; or, for a rank learned from a book or a quest, the
  NPC sells that book or starts that quest), a spawn's AreaID maps to the record's `mapID`, the
  record's `x`/`y` is within **1.0 map-%** of the spawn (#2's tolerance), and no other NPC shares
  its point. CMaNGOS, pfQuest and Method.gg are cross-checks: they never confirm or refute alone,
  and a disagreement puts the record on the in-game spot-check list.
- **D2 — The tool.** `lua tools/trainer_probe.lua <QuestieDB> [--cmangos <dump>] [--pfquest
  <units.lua>] [--methodgg <names.tsv>] [--itemtree <pin>] [--date] [--run] [--write-provenance]`,
  Lua 5.1 like the suite, split into `tools/trainer_probe/*.lua` (io, questiedb, cmangos, pfquest,
  checks, era, report). Dev-only: not in the TOC. Every source is untrusted data: Lua sources load
  only in an empty sandbox (`setfenv`), nothing from them executes with library access.
- **D3 — Output.** `docs/trainer-probe/<date>[-<run>]/report.md`, `report.json` and
  `suggested-patch.tsv` (one row per proposed field change), written CRLF (the repo's pin). The
  first run, before any fix, is `docs/trainer-probe/2026-11-23/`; the run after the fixes is
  `docs/trainer-probe/2026-11-23-r2/`.
- **D4 — Provenance in the data.** The probe writes `defaults/TrainerProvenance_Forever.lua`
  (`--write-provenance`, generated, in the TOC before the trainers): `NS.DataMeta.Trainers_Forever`
  (the tag `questiedb@<sha12>`, the run, every source's pin) and per record either the values it
  confirmed (`npcID`, name, `mapID`, `x`, `y`) or the reason it could not. `Trainers_Forever.lua`
  sets `verified = <tag>` on a confirmed record and `verified = false` plus `unverified = <reason>`
  on the rest. The suite fails when a record has neither, or when a confirmed record no longer
  holds the values the probe confirmed (an edit since the probe).
- **D5 — Licensing.** Skill Master ships only its own records: corrected names, `npcID`s, item and
  quest ids, coordinates **rounded to 0.1** (its own precision), and the source commits. No source
  table, fixture or file is committed. The reports quote a source only against one record. The
  Method.gg names list stays outside the repo; the report says yes or no per record. Recorded in
  `docs/ARCHITECTURE.md` (Trainer data provenance); it is not a deviation from the standard.
- **D6 — Coordinates for every record with one standing point.** The source now prints a point
  for 136 records, so the header rule "coordinates only where a source printed them" is met for
  them too; the waypoint pin replaces the chat-only fallback. Records whose spawns spread, or that
  stand inside an instance (Annora, Uldaman), keep no point.
- **D7 — The four known errors.** Woo Ping moves into Forever's Stormwind frame (63.9, 69.1);
  "Doctor Martin Felbin" becomes Doctor Martin Felben (npc 11044); Gorina (a Mining Supplier,
  vendor only) is dropped, Makaru stays Orgrimmar's Mining trainer; Buliwyf Stonehand takes his
  own point (61.2, 89.5) and Bixi keeps hers (62.2, 89.6); Sayoc (81.7, 19.6) and Hanashi
  (81.5, 19.6) stop sharing one point. Each is pinned by a test that fails on the old data.
- **D8 — How a rank is learned (the books comment).** A record gains `learn`:
  `{ kind = "book", itemID, item }` for the book vendors (Expert Cookbook: Shandrina, Wulan;
  Expert First Aid - Under Wraps: Deneb Walker, Balai Lok'Wein; Expert Fishing - The Bass and You:
  Old Man Heming) and `{ kind = "quest", questID, quest }` for the rank quests (Clamlette Surprise:
  Dirge Quikcleave; Nat Pagle, Angler Extreme: Nat Pagle; Triage: Doctor Gustaf VanHowzen and
  Doctor Gregory Victor). Ids and names agree in QuestieDB (vendors, quest starts) and the CMaNGOS
  dump. The smallest UI: the popup card's second line, the chat directions and the row tooltip
  read "Sells <book>" or "Quest: <quest>". Left out: the Artisan books (Artisan Cookbook, Artisan
  Fishing - The Way of the Lure, Artisan First Aid - Heal Thyself), which no vendor sells (quest
  rewards); recipe books and recipe vendors (no recipe model exists); item links and tooltips.
- **D9 — The 1.12 dump's ranks.** Read by ItemTree's method, the dump has every titled trainer
  teach one rank below its title (a Journeyman to 75, an Artisan to 225), while QuestieDB's Forever
  titles agree with the records. The probe keeps the titles, counts that pattern once in the report
  and lists one in-game check (SM-TPROBE-3) rather than flagging 74 records.
- **D10 — The validate-seeds rule.** `docs/validate-seeds.md` said "the `verified = false` flags
  are the owner's smoke-pass state; no tool changes them". Issue #3 supersedes that for the
  trainers: the probe's provenance file sets them, and the seeds tool still never does. ItemTree is
  named there as a trainer reference (the acceptance of #2's comment), by its method.
- **D11 — Out of scope, listed.** The 55 Forever-only trainer NPCs QuestieDB knows and the dump
  does not (Zephras Isle, the Junior gathering trainers, …) are listed in the report, not added: a
  new record needs ranks and costs nothing offline gives. Costs and level gates are not checked
  (#2 option 2, the in-game capture). The popup's unverified warning now reads "Not confirmed on
  WoW Forever yet (marked until checked)".

## Acceptance (from the issue)

- `lua tools/trainer_probe.lua <path-to-QuestieDB>` runs offline and writes the report.
- The four known errors show up in the first report and are fixed in the data.
- A confirmed record drops `verified = false`; source and sha in `NS.DataMeta`.
- The headless suite checks every shipped record has a probe confirmation or an explicit
  `unverified` reason.
- The probe lists the Forever-only NPCs that need an in-game spot check.
- Licensing: only our numbers and the sha ship.

## Round 2 (2026-11-23): the owner's feedback

The owner smoked SM-TPROBE-1 to 4 (passed); 5 and 6 are owed (no character with those
professions). Then, verbatim:

> 1. "For Leatherworking, im at 155/225. This is what SkillMaster shows me": our popup "Train: Leatherworking (Artisan)" lists Telonis, Darnassus, Craftsmen's Terrace (64, 22). ItemTree shows "No trainer teaches Artisan Cooking. Artisan Cooking is learnt from a quest. Clamlette Surprise, given by Dirge Quickcleave, Tanaris", then the trainers who teach Cooking (Alegorn, Cook Ghilm, …). "Same for cooking - im at 225/225 … Do some more research on this - i think ItemTree is right - all artisan professions need a quest to progress after 225. Look up ItemTree and online sources to validate - and clearly call out what quest needs to be taken (the cooking one is correct - Clamlette surprise quest)".
> 2. "in the trainer window, for professions - add a checkbox to show all trainers irrespective of current rank. Order them from highest (artisan) first and then go down. Add a identifying mark for trainers for your current rank when in this mode".
> 3. (later the same day) "Go ahead and ship these 55 forever only trainers".

### Research: how Artisan (225 to 300) is reached on WoW Forever

Sources: **[IT]** ItemTree v1.2.8 (owner's install), `Core/TrainerSearch.lua` `UntaughtRank`: it
says "No trainer teaches <rank>" only when no trainer row in the 1.12 dump teaches that rank spell,
and names the books (`RANK_BOOKS`) and the quests; **[CM]** the CMaNGOS 1.12 dump (pin above): the
trainer rows that teach each Artisan rank spell, and the quests whose reward teaches it; **[QDB]**
QuestieDB Forever `47a4756b775e`: each teacher present on Forever, its side, title and spawn; no
Forever-only quest touches a rank (its Forever profession quests are the "Camping 101" set);
**[MG]** Method.gg WoW Forever guides (read 2026-11-23); **[WP]** wow-professions.com/forever
leatherworking guide; **[GG]** games.gg "WoW Forever professions guide" (both read 2026-11-23).

| Profession | Forever answer | Quest | Giver / teacher and place | Sources | Confidence |
| --- | --- | --- | --- | --- | --- |
| Alchemy | Trainer, no quest | none | Kylanna Windwhisper, Feathermoon Stronghold, Feralas (Alliance); Rogvar, Stonard, Swamp of Sorrows (Horde) | CM, QDB, MG | high |
| Blacksmithing | Trainer, no quest | none | Brikk Keencraft, Booty Bay, Stranglethorn Vale (both) | CM, QDB, MG, GG | high |
| Enchanting | Trainer, no quest | none | Annora, Uldaman, Badlands (both) | CM, QDB, MG | high |
| Engineering | Trainer, no quest | none | Buzzek Bracketswing, Gadgetzan, Tanaris (both) | CM, QDB (no Method.gg page) | medium |
| Herbalism | Trainer, no quest | none | any Herbalism trainer (the capitals' included) | CM, QDB | medium-high |
| Leatherworking | Trainer, no quest | none | Drakk Stonehand, Aerie Peak, The Hinterlands (Alliance); Hahrana Ironhide, Camp Mojache, Feralas (Horde) | CM, QDB, MG, WP | high |
| Mining | Trainer, no quest | none | any Mining trainer (the capitals' included) | CM, QDB | medium-high |
| Skinning | Trainer, no quest | none | any Skinning trainer (the capitals' included) | CM, QDB | medium-high |
| Tailoring | Trainer, no quest | none | Timothy Worthington, Theramore Isle, Dustwallow Marsh (Alliance); Daryl Stack, Tarren Mill, Hillsbrad Foothills (Horde) | CM, QDB, MG, GG | high |
| Cooking | **Quest** | Clamlette Surprise (6610) | Dirge Quikcleave, Gadgetzan, Tanaris (both) | IT, CM, QDB, MG, GG | high |
| First Aid | **Quest** | Triage (6624 Alliance, 6622 Horde) | Doctor Gustaf VanHowzen, Theramore Isle, Dustwallow Marsh (Alliance); Doctor Gregory Victor, Hammerfall, Arathi Highlands (Horde) | IT, CM, QDB, MG, GG | high |
| Fishing | **Quest** | Nat Pagle, Angler Extreme (6607) | Nat Pagle, Dustwallow Marsh (both) | IT, CM, QDB, MG, GG | high (see doubt) |

**Verdict.** The owner's reading holds for the three secondary skills only. Artisan Cooking, First
Aid and Fishing are quests; the nine primary professions are trained, by a "Master" trainer outside
the capitals for the six crafts and by any trainer for the three gathering skills. What the owner
saw is a real data error, though: the capitals' **"Artisan"-titled** trainers (Telonis, Una,
Ainethil, Doctor Herbert Halsey, Bengus Deepforge, Saru Steelfury, Springspindle Fizzlegear, Roxxik,
Georgio Bolero, Josef Gregorian) train to **Expert (225)**, not Artisan. CM's rows, MG's guides and
WP say so. Skill Master listed them under Artisan, and the probe's title rule ("Artisan" = 300)
agreed with the error.

**Doubts, recorded.**
- **Journeyman and Expert titles.** CM and MG also have every "Journeyman"-titled trainer teach
  Apprentice and every "Expert" one Journeyman. The owner's SM-TPROBE-3 pass (2026-11-23) says a
  Journeyman trainer offers Journeyman in game, so those ranks stay as they are; only the Artisan
  title moves. A later in-game look at an Expert trainer settles the rest (SM-TPROBE-9).
- **SM-TPROBE-3's Artisan half** (Georgio Bolero offering Artisan) was passed but contradicts every
  source above and the owner's own Leatherworking report. The sources and the newer report win;
  SM-TPROBE-8 checks again.
- **Fishing:** CM has Katoom the Angler (Revantusk Village, Hinterlands, Horde) teach Artisan
  Fishing too, and ItemTree reads that row ("Nat Pagle's quest and a trainer both"). MG lists
  Katoom as Apprentice and Journeyman only, and GG and MG give Nat Pagle's quest as the route. The
  Forever guides win: Katoom is not added as an Artisan trainer.
- CM also has Caryssia Moonhunter (a Tribal Leatherworking specialization trainer) and Meilosh (a
  Timbermaw vendor) teach Artisan rows. No Forever source names either, so neither is added.

### Decisions, round 2

- **D12 — Artisan teachers.** The ten capital "Artisan" trainers train to 225. The seven Master
  trainers above join the data (Kylanna Windwhisper, Rogvar, Buzzek Bracketswing, Drakk Stonehand,
  Hahrana Ironhide, Timothy Worthington, Daryl Stack; Brikk Keencraft and Annora are there already).
  The probe's title rule: Journeyman 150, Expert 225, **Artisan 225**, Master 300.
- **D13 — "No trainer teaches".** When no record of a rank is a trainer (every one is a book vendor
  or a quest giver), the popup says so under the rank's heading, as ItemTree does: "No trainer
  teaches Artisan Cooking. Artisan Cooking is learned from a quest: Clamlette Surprise, given by
  Dirge Quikcleave, Gadgetzan, Tanaris." (a book reads "... from a book: Expert Cookbook, sold by
  ..."). The giver's card stays selectable, so Set waypoint leads to it, and a heading "Trainers who
  teach Cooking" lists the skill's trainers below. "learned", not ItemTree's "learnt": this repo is
  American English (its prose gate).
- **D14 — Show all trainers.** A check box in the popup for a skill with ranks, persisted per
  profile (`trainers.showAll`, a schema row on the Trainers and Waypoints page). On, the popup lists
  every rank's teachers, Artisan first and Apprentice last, each record once under the highest rank
  it trains (a quest giver or book vendor under its rank), and marks the trainers of your next rank
  "Your next rank" in the skin's good color, with a tooltip line. The check box is the client's
  `UICheckButtonTemplate` painted by the skin (`NS.Skin.Checkbox`): LibKa0s-Widgets has no check box
  (its census rejected one), so this is the skinned stock control the options panel also uses.
- **D15 — The 55 Forever-only trainers** (supersedes D11's "not added"). Each joins with its npcID,
  name, side, skill and ranks from its title (Junior = Apprentice for a gathering skill; Journeyman,
  Expert, Master as titled; a plain title such as "Alchemist" or "Cook" trains to Journeyman, the
  level an untitled village trainer trains to in CM), its uiMap and QuestieDB's Forever spawn
  rounded to 0.1, `verified = false` and the reason "Forever-only, from QuestieDB spawn, not yet
  seen in game". "Master Goblin Engineer" (Melbin Powderfuse) teaches Engineering to 300.
  "Superior Fisherman" (Krix) is read as Fishing to 150 (no Forever source has an Artisan Fishing
  trainer). "Stablemaster and Riding Trainer" and "Undead Horse Riding Instructor" join the riding
  records; a riding record needs a race, so they take the race their side's riding comes from.
  **Sides:** the owner, 2026-11-23: "new zones are reachable by both alliance and horde". So every
  trainer on Zephras Isle (uiMap 2521) and in Riverglades (uiMap 2548) is `Neutral` (the value the
  Booty Bay and Gadgetzan records use), whatever side QuestieDB gives; the other Forever-only
  trainers take QuestieDB's side. The probe keeps such a record unverified by its `hold` reason, so
  it never confirms a record the owner has not seen.
