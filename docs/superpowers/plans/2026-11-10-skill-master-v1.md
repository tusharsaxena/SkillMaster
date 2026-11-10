# Ka0s Skill Master v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Orchestrated as ultracode workflows (owner opt-in, 2026-11-10).

**Goal:** Ship Ka0s Skill Master v1.0.0, a WoW Forever-only addon that shows weapon skills, professions,
Defense/Lockpicking/Riding and character stats as skinnable data bars, with bonuses, trainer directions, broker
feeds, alerts, a session log, an alt overview and gathering helpers.

**Architecture:** A born-compliant Ka0s addon (Ace3 + vendored LibKa0s v1.94.0), scaffolded per `NEW_ADDON.md`.
Pure data modules (`SkillData`, `Bonuses`, `StatData`, `Trainers`, `Helpers`, `SessionLog`, `Alts`) read the API
and publish bus messages. Display modules (bar widget, blocks, main window, detached frames, tooltips, journal,
broker, alerts) consume only messages and models, so Sim/Test and the headless harness drive them the same way.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1, interface 16001), Ace3, LibStub, CallbackHandler, LibSharedMedia-3.0,
LibDataBroker-1.1, LibDBIcon-1.0, LibKa0s v1.94.0 (vendored whole), TomTom (optional, detected). Tests: the
LibKa0s testkit at `tests/_kit/`, run with `KA0S_KIT_CLIENT=forever lua tests/run.lua`; lint with
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`; complexity with lizard (CCN ≤ 15).

**Spec:** `docs/superpowers/specs/2026-11-10-skill-master-design.md` (+ mockups in
`docs/superpowers/specs/2026-11-10-skill-master-mockups/`, live canvas https://claude.ai/artifact/NHcfE8qKUA5a8jJgSprc2N)

**Status ledger (resume point):** `docs/superpowers/plans/2026-11-10-skill-master-v1-STATUS.md`. Every task
updates its row in the same commit that finishes it. To resume, read the ledger, `git log --oneline`, and start
at the first row not `done`.

## Global Constraints

- Client: WoW Forever only. `## Interface: 16001`, one number, plus the Forever load-gating line from the
  standards branch (M0). No `IsRetail()` branch, no Retail seed list, no `WOW_PROJECT_*` read outside LibKa0s.
- Title `Ka0s Skill Master`, folder/addon name `SkillMaster`, author `add1kted2ka0s`, MIT, `## X-Standard`
  line, SavedVariables `SkillMasterDB, SkillMasterPerfDB`, slash `/sm` + `/skillmaster`.
- The standard (WowAddonStandards, **at the M0 branch**) wins over this plan on layout, file names and
  conventions. Read `NEW_ADDON.md` and `standards/NEW_ADDON_CONTEXT.md` from the M0 worktree into a temp
  directory, never into the repo.
- Default skin on Forever: WoW Forever, answered by LibKa0s (skinning-§2). Skins adopted from the first commit
  (`core/SkinSetup.lua`, `skin` verb after `config`, `test_skin_values` + `test_skin_switch`).
- Launcher menu: Enabled · Locked · Test mode · Sim mode · Show window, plus Journal. `CLICK` binding for Show
  window in a root `Bindings.xml`.
- Every data table is a `*_Forever.lua` file, records its source and carries `verified = false` until the
  owner's smoke pass.
- Green gate before every commit: forever-profile tests, luacheck 0/0, no function above CCN 15.
- **Concurrency rule:** two other agents are working in `LibKa0s`, `WowAddonStandards` and `dev-copilot`
  (their main checkouts are on `feat/2026-11-10-quickcomms-forever-emotes` / `master`). Never check out,
  stash, commit or reset in those main checkouts. Work only in git worktrees under
  `/mnt/d/Profile/Users/Tushar/Documents/GIT/#Worktrees/`, branched from `origin/master` after a `git fetch`.
  Vendor LibKa0s with `git -C LibKa0s archive v1.94.0` (a tag, not the working tree). Before any merge,
  `git fetch` and rebase on the then-current `origin/master`. If the version number or the CHANGELOG
  conflicts with the other agents' work, take theirs and renumber ours.
- Commits end with the session attribution lines. Push after each milestone. **Never merge without the
  owner's go.**

## Review Focus

1. **A character with no professions or a half-loaded skill list at login** (`GetNumSkillLines()` returns 0
   before `SKILL_LINES_CHANGED`): show empty-state rows, no Lua error → test `test_skilldata_empty_list` (T2.1).
2. **Collapsed skill headers in the stock Skills tab** hide child lines from `GetSkillLineInfo`: the scan must
   expand headers it needs and restore the player's collapse state → test `test_skilldata_restores_collapsed_headers` (T2.1).
3. **Combat lockdown**: clicking a crafting row, detaching a block, or the pool re-anchoring a secure
   overlay in combat must queue or no-op, never taint → test `test_secure_overlay_deferred_in_combat` (T3.3).
4. **Bonus that exceeds the cap** (Guns 105 + 5 with max 110, lure +100 at 150/150): bar clamps the base,
   the bonus segment draws to the end and the text still shows the full numbers → test `test_bar_bonus_overflow_clamped` (T3.1).
5. **Non-enUS client**: skill and header names are localized, so classification must go through the
   catalog's localized-name map and unknown names must land in "Other", never error → test `test_skilldata_unknown_name_goes_other` (T2.1).

---

## Milestone 0 — Standards amendment (worktrees, pushed, not merged)

### Task 0.1: `Forever` Clients value in WowAddonStandards

**Files (worktree `#Worktrees/WowAddonStandards-forever-only`, branch `feat/2026-11-10-single-client-forever`):**
- Modify: `standards/standards/clients.md` (§1 intro, §2), `standards/ADDONS.md` (Clients table + value
  table + Skill Master row), `standards/standards/toc-file.md` (§3 table), `standards/STANDARDS.md` (index
  blurb if it enumerates values), `standards/NEW_ADDON_CONTEXT.md` (TOC starter note), `standards/CHANGELOG.md`, version
  references per the repo's own bump procedure (read `CLAUDE.md` there first).

- [ ] Step 1: `git -C WowAddonStandards fetch && git -C WowAddonStandards worktree add "../#Worktrees/WowAddonStandards-forever-only" -b feat/2026-11-10-single-client-forever origin/master`.
- [ ] Step 2: Write the rule. Default: build for both clients. Single-client (`Retail` or `Forever`) is
  allowed by the owner's decision when the addon's core does not exist on the other client, and the README +
  `docs/ARCHITECTURE.md` record the reason. Owner ruling dated 2026-11-10.
- [ ] Step 3: Add the value `Forever`. TOC shape: `## Interface: 16001` (one number) plus
  `## AllowLoadGameType: camelot` (mirror of Retail's `standard`). Verify the directive name against
  toc-file-§3 and the Retail row before writing it. Audit flags: a missing or misspelled gating line, an
  `IsRetail()` read, a Retail seed list, or a `clients = { "retail" }` declaration (dead code).
- [ ] Step 4: Add the roster row `| Ka0s Skill Master | ../../SkillMaster/ | https://github.com/tusharsaxena/SkillMaster | Forever | Enabled · Locked · Test mode · Sim mode · Show window (the skills window) | test | next to Test mode |`.
- [ ] Step 5: Run the repo's own checks if it has any (`scripts/`). Commit, `git push -u origin feat/2026-11-10-single-client-forever`.

### Task 0.2: dev-copilot value check

- [ ] Step 1: `grep -rn "Retail (port pending)\|Retail · Forever" ` in a fresh worktree of dev-copilot
  (`#Worktrees/dev-copilot-forever-only`, branch `feat/2026-11-10-single-client-forever`, from `origin/master`).
- [ ] Step 2: Where a spec or overlay enumerates the Clients values (`wow-new-addon`, `wow-standards-audit`,
  `wow-bump-interface`), add `Forever` (one Forever number, no Retail number). If nothing enumerates them,
  remove the worktree and branch and record "no change needed" in the ledger.
- [ ] Step 3: Commit + push the branch (if any). Ledger: M0 done.

## Milestone 1 — Scaffold + probe

### Task 1.1: Born-compliant skeleton

**Files:** everything `NEW_ADDON.md` steps 0–7 lay down (from the M0 worktree), named for `SkillMaster`.
Libraries: copy `libs/` (Ace3 set, CallbackHandler, LibStub, LibSharedMedia, LibDataBroker, LibDBIcon) from
`../OutfitterReborn/libs/` (a Retail · Forever addon on master). LibKa0s: `git -C ../LibKa0s archive v1.94.0 LibKa0s testkit | tar -x -C <tmp>`,
then `<tmp>/LibKa0s → libs/LibKa0s/`, `<tmp>/testkit → tests/_kit/`. Prune icons per library-stack-§7.

- [ ] Step 1: Follow the playbook to the letter. The `.gitattributes` already exists (initial commit). Do not
  write a CHANGELOG.md or the context pack into the repo.
- [ ] Step 2: TOC per Global Constraints. Setup files: Media, Env, Pool, Core, Perf, DebugLog, Skin, Widgets,
  Launcher, Lifecycle, Slash, Options (skip Item — no item handling beyond tooltip scan; revisit if Bonuses
  needs `LibKa0s-Item`).
- [ ] Step 3: `core/Bus.lua` message constants: `SKILLS_UPDATED`, `SKILL_UP`, `STATS_UPDATED`,
  `BONUSES_UPDATED`, `LAYOUT_CHANGED`, `SIM_TICK`.
- [ ] Step 4: Run `KA0S_KIT_CLIENT=forever lua tests/run.lua` → all kit tests pass; luacheck 0/0.
- [ ] Step 5: Commit `M1: scaffold Ka0s Skill Master (born compliant, Forever-only)`.

### Task 1.2: `/sm probe`

**Files:** Create `modules/Probe.lua`, `tests/test_probe.lua`; add the `probe` row to `NS.COMMANDS`.

**Interfaces:** Produces `NS.Probe.Run() -> table` (the report) and the verb, which shows the report in the
LibKa0s copy box as JSON.

- [ ] Step 1: Test `test_probe_report_shape`: with kit stubs, `Run()` returns keys `client`, `build`,
  `skillLines` (array of the raw `GetSkillLineInfo` returns for every line), `headers`, `apis` (map of name →
  boolean for `GetUnitSpeed`, `GetSpellBonusDamage`, `GetSpellCritChance`, `GetHitModifier`,
  `GetSpellHitModifier`, `GetCombatRating`, `GetWeaponEnchantInfo`, `GetCritChance`, `GetRangedCritChance`,
  `GetDodgeChance`, `GetParryChance`, `GetBlockChance`, `UnitResistance`, `C_Map.SetUserWaypoint`,
  `C_Map.GetBestMapForUnit`, `CastSpellByName`, `IsAddOnLoaded("TomTom")`), `enchant` (weapon enchant returns).
- [ ] Step 2: Run → FAIL. Step 3: implement. Step 4: Run → PASS.
- [ ] Step 5: Create `docs/client-quirks.md` listing every assumed API shape as "assumed (1.12)" until the
  probe confirms it. Commit. **Push** (M1 done) and ask the owner to run `/sm probe` when convenient. Never wait for it.

## Milestone 2 — Data layer (parallel tasks, disjoint files)

### Task 2.1: Skill catalog + `SkillData`

**Files:** Create `defaults/SkillCatalog_Forever.lua`, `modules/SkillData.lua`, `tests/test_skilldata.lua`;
locale keys in `locales/enUS.lua`.

**Interfaces:**
- `NS.SkillCatalog[key] = { category = "primary"|"secondary"|"weapon"|"other", kind = "craft"|"gather"|"weapon"|"defense"|"lockpicking"|"riding", tiers = {75,150,225,300}|nil, openSpell = "<enUS spell name>"|nil, opensSkillsTab = bool }`.
  The keys are stable English camelCase (`leatherworking`, `twoHandedAxes`, `fistWeapons`, `defense`, `riding`, `lockpicking`, ...).
  It covers every vanilla profession, all 16 weapon skill lines, Defense, Lockpicking and Riding. A
  `NS.SkillNameToKey[localizedName] = key` map is built from locale strings.
- `NS.SkillData:Scan() -> model`, with `model.byKey[key] = { key, name, category, rank, max, tempPoints, modifier, learned = true }`
  and `model.order[category] = { keys... }`. Unlearned weapon/riding rows (`learned = false`) are
  synthesized from the catalog for skills the class can learn (`NS.ClassWeapons_Forever[classFile]`).
- `NS.SkillData:Get(key)`, `NS.SkillData:Model()`. Sends `SKILLS_UPDATED(model)`, and `SKILL_UP(key, old, new)` when a rank rises.
- Events: `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL`, `PLAYER_LEVEL_UP` (weapon max = 5 × level), debounced 0.1 s.

- [ ] Step 1: Tests: `test_skilldata_classifies_categories` (fixture with Leatherworking 146/150, Fishing
  107 +25 temp/150, Guns 105 +5/110, Defense 100/110 → categories and numbers), `test_skilldata_empty_list`,
  `test_skilldata_restores_collapsed_headers`, `test_skilldata_unknown_name_goes_other`,
  `test_skilldata_skill_up_message` (rank 80 → 81 fires `SKILL_UP("bows",80,81)` once),
  `test_skilldata_unlearned_synthesized` (Dwarf Hunter: `fistWeapons`, `polearms`, `thrown` present with `learned=false`).
- [ ] Step 2: FAIL. Step 3: implement. Step 4: PASS + luacheck. Step 5: commit.

### Task 2.2: `Bonuses`

**Files:** `defaults/Racials_Forever.lua`, `modules/Bonuses.lua`, `tests/test_bonuses.lua`.

**Interfaces:** `NS.Bonuses:Breakdown(key) -> { total = n, sources = { { label, amount, kind = "temp"|"perm", expires = <GetTime seconds>|nil, source = "racial"|"item"|"enchant"|"buff"|"other" } } }`.
The total equals the skill's `modifier`. Any part not attributed becomes one `source = "other"` entry.
Racials: Human Swords/Maces +5, Dwarf Guns +5, Orc Axes +5, Troll Bows/Throwing +5 (perm). Item scan:
tooltip lines matching the locale patterns `"%+(%d+) (.+)"` and `"Increased (.+) %+(%d+)"`. Enchant: main-hand
temp enchant (`GetWeaponEnchantInfo`) whose tooltip line names the fishing bonus, with an expiry. Sends
`BONUSES_UPDATED` on `UNIT_INVENTORY_CHANGED`, `UNIT_AURA(player)` and a 1 s ticker only while a temp bonus exists.

- [ ] Step 1: Tests `test_bonuses_lure_temp_with_expiry` (Fishing +25 enchant, 252 s left → one temp source,
  expires), `test_bonuses_dwarf_guns_racial`, `test_bonuses_residual_other` (modifier 12, attributed 7 → other 5),
  `test_bonuses_none`. Steps 2–5 as above.

### Task 2.3: `StatData`

**Files:** `defaults/Stats_Forever.lua`, `modules/StatData.lua`, `tests/test_statdata.lua`.

**Interfaces:** `NS.StatData:Scan() -> { base = {...}, spell = {...}, defense = {...}, utility = {...} }`. Each
entry is `{ key, label, value, display, pct, ref, markers = { { at = pct, label } } }`. `NS.STAT_DEFS` in the
defaults file declares per stat `{ group, api, ref = "maxInGroup"|"cap"|number, markers = {...}, fmt }`.
Missing APIs (feature-detected) are left out of the result. Values pinned:
- base group (Str/Agi/Sta/Int/Spi) ref = the highest of the five. AP/RAP ref 400. Crit (melee/ranged/spell) ref 30%.
- hit: ref 9%, markers 5% "vs same level" and 9% "vs raid boss". Spell hit: ref 16%, marker 16%.
- defense skill: ref 5 × level, marker 440 "crit immunity vs bosses" only at level 60.
- armor: shows the mitigation `armor / (armor + 400 + 85 × level)`, ref 75%, marker 75% "cap".
- resists: ref 5 × (level + 3) (315 at 60), marker the same.
- run speed: `GetUnitSpeed("player") / 7 × 100`, ref 200%, marker 100%. Swim and mount the same where the API allows.
- durability: lowest equipped slot %, marker 20% "repair".
Sends `STATS_UPDATED` on `UNIT_STATS`, `UNIT_ATTACK_POWER`, `UNIT_RANGED_ATTACK_POWER`, `UNIT_RESISTANCES`,
`UNIT_DAMAGE`, `PLAYER_EQUIPMENT_CHANGED`, `UPDATE_INVENTORY_DURABILITY`, and a 0.5 s speed ticker only while a
stat block showing speed is visible. Throttled to 0.2 s.

- [ ] Step 1: Tests `test_statdata_primary_vs_highest` (Agi 112 → 100%, Str 48 → 42.9%), `test_statdata_hit_markers`,
  `test_statdata_armor_mitigation` (1104 at level 22 → 1104/(1104+400+1870) = 32.7%), `test_statdata_missing_api_omitted`,
  `test_statdata_resist_ref_at_60` (315). Steps 2–5.

### Task 2.4: Trainers, ranks, helpers data + lookups

**Files:** `defaults/Trainers_Forever.lua`, `defaults/Ranks_Forever.lua`, `defaults/Gathering_Forever.lua`,
`defaults/Fishing_Forever.lua`, `defaults/ClassWeapons_Forever.lua`, `modules/Trainers.lua`,
`modules/Helpers.lua`, `tests/test_trainers.lua`, `tests/test_helpers.lua`.

**Interfaces:**
- Trainer record: `{ id, name, faction = "Alliance"|"Horde"|"Neutral", city, subzone, mapName, x, y, cost, teaches = { keys }, verified = false, source = "<url or 'vanilla 1.12 data'>" }`.
  It covers every vanilla weapon master, one profession trainer per rank and city for each profession, and the riding trainers per race.
- `NS.Trainers:For(key, faction) -> { trainer... }` (sorted by city of the player's race first).
- `NS.Trainers:NextRank(key, rank, max, level) -> { rankName, cap, minLevel, trainers }|nil`. Ranks: Apprentice
  75 (L5), Journeyman 150 (L10), Expert 225 (L20), Artisan 300 (L35). Riding 75 (L40, 90g), 150 (L60, 900g).
- `NS.Helpers.SkinnableLevel(rank)`: rank ≥ 100 → `floor(rank/5)`, else `floor(rank/10)+10`.
- `NS.Helpers.FishingNeed(zoneName) -> minSkill|nil`. `NS.Helpers.Nodes(key, rank) -> { gatherable = {...}, next = {name, need} }`.
- `NS.Helpers.WeaponCap(level) = 5 * level`.
- [ ] Step 1: Tests `test_trainers_fist_alliance` (includes Bixi Wobblebonk, Ironforge), `test_trainers_next_rank_at_cap`
  (Leatherworking 150/150 L22 → Expert, 225, L20), `test_trainers_riding_level_gate`,
  `test_helpers_skinnable_level` (122→24, 100→20, 50→15, 1→10), `test_helpers_fishing_need_unknown_nil`. Steps 2–5.
- Push at the end of M2.

## Milestone 3 — Display

### Task 3.1: Bar widget

**Files:** `modules/Bar.lua`, `tests/test_bar.lua`.
**Interfaces:** `NS.Bar.Create(parent, styleKey) -> bar`; `bar:SetValues{ value, max, bonus, bonusKind = "temp"|"perm", ticks = {n...}, markers = {{at,label}}, text }`;
`bar:SetTimer(expires|nil)`; `bar:ApplyStyle(style)`, where the style is resolved from profile + skin tokens
(texture, fill/bonus/tick/marker colours, border, background, height, font, text anchor, spark). Pooled via `NS.Pool`.
- [ ] Tests `test_bar_bonus_overflow_clamped`, `test_bar_ticks_beyond_max_dropped`, `test_bar_timer_format` (252 → "4:12").

### Task 3.2: Blocks, main window, detach/dock

**Files:** `modules/Blocks.lua`, `modules/MainWindow.lua`, `modules/Detached.lua`, `modules/Rows.lua`, tests.
**Interfaces:** `NS.BLOCKS = { "primary","secondary","weapon","other","stats_base","stats_spell","stats_defense","stats_utility" }`.
Each block def is `{ id, title, source = "skills"|"stats", filter }`. Profile: `layout.blocks[id] = { docked = true, order, collapsed, point, scale, locked }`.
`NS.MainWindow:Toggle()`, `NS.Blocks:Detach(id)`, `NS.Blocks:Dock(id)` send `LAYOUT_CHANGED`. The window follows
standalone-windows (title bar per the mockup, skin owner, close via `NS.MakeCloseButton`, strata from `NS.Constants.LAYERS`).
Row: icon, name, bar, timer, and an unlearned variant with a "Go" button. Summary strip optional.
- [ ] Tests `test_blocks_detach_dock_roundtrip`, `test_rows_unlearned_variant`, `test_mainwindow_collapsed_persisted`.

### Task 3.3: Interactions, tooltips, trainer popup, waypoints

**Files:** `modules/Interact.lua`, `modules/SecureOverlay.lua`, `modules/RowTooltip.lua`, `modules/TrainerPopup.lua`, `modules/Waypoints.lua`, tests.
**Interfaces:** Click map per spec §6.5. Crafting rows: one `SecureActionButtonTemplate` per profession
(`type="spell"`, `spell=<localized openSpell>`), created out of combat and re-anchored only out of combat (queued on
`PLAYER_REGEN_ENABLED`). Others: `ToggleCharacter("SkillFrame")` / `("PaperDollFrame")`. Shift-click links to chat; right-click opens
the row menu. `NS.Waypoints:Set(trainer) -> "tomtom"|"native"|"chat"`.
Tooltip content per mockup artboard 3. Helpers lines on gathering/fishing rows.
- [ ] Tests `test_secure_overlay_deferred_in_combat`, `test_waypoints_fallback_order`, `test_rowtooltip_lines_fishing_lure`.
- Push at the end of M3.

## Milestone 4 — Broker, alerts, journal

### Task 4.1: Feeds + templates
**Files:** `modules/Broker.lua`, `modules/Template.lua`, tests. The launcher stays in `core/LauncherSetup.lua` (standard).
**Interfaces:** feeds `SkillMaster_All`, `SkillMaster_Professions`, `SkillMaster_Weapons`, `SkillMaster_Stats` (LDB data sources).
`NS.Template.Render(tpl, ctx) -> string`, tokens `{pinned} {gains} {last} {lowestProf} {equippedWeapon} {skill:<key>} {stat:<key>} {level}`.
Unknown tokens render empty. Flash: `▲ <name> <new>` for `profile.broker.flashSeconds` (default 5). Tooltip rows per mockup 4.
Clicks per spec §6.5 (no secure frames).
- [ ] Tests `test_template_tokens`, `test_template_unknown_token_empty`, `test_broker_flash_reverts`.

### Task 4.2: Alerts
**Files:** `modules/Alerts.lua`, tests. Rank cap reached (`rank == max` and `NextRank` exists) → LibKa0s Toast
+ chat with the trainer. Weapon skill ≥ `profile.alerts.weaponGap` (default 25) below the cap on `SKILL_UP`/level-up → toast,
once per skill per session. Each alert can be switched off, with an optional sound.
- [ ] Tests `test_alerts_cap_once`, `test_alerts_weapon_gap_threshold`.

### Task 4.3: SessionLog, Alts, Journal window
**Files:** `modules/SessionLog.lua`, `modules/Alts.lua`, `modules/Journal.lua`, tests.
**Interfaces:** `NS.SessionLog:Add(key, old, new, t)` (ring of 500 in `db.char.log`); `:Gains()`; `:Rate(windowSec=3600) -> upsPerHour`;
`:ETA(key) -> seconds|nil` = `(max - rank) / perSkillRate`, where the per-skill rate comes from that skill's
gains in the current session (nil when there are < 2 gains). `NS.Alts:Snapshot()` into `db.global.characters["<realm>-<name>"]` (Forever names
are two words, client-quirks §5: key by `UnitFullName` exactly). `:List()`. Journal = tabbed window per mockup 5.
- [ ] Tests `test_sessionlog_ring_cap`, `test_sessionlog_eta`, `test_alts_snapshot_two_word_name`.
- Push at the end of M4.

## Milestone 5 — Options, Sim/Test, polish

### Task 5.1: Settings pages
Schema-driven pages per options-ui: General, Layout, Bars, Skills, Stats, Broker, Alerts, Journal, Trainers &
Waypoints, Profiles (+ Skin tab, Keybindings). Every visual element has a row, or follows the skin with a reset.
Live apply via `LAYOUT_CHANGED`. Tests: the kit's schema/options tests + `test_options_every_bar_style_key_has_row`.

### Task 5.2: Test mode + Sim mode
`defaults/Preview_Forever.lua` = the mockup's Dwarf Hunter (Lv 22). Test mode swaps the data sources for the
fixture. Sim mode runs scripted skill-ups every 3 s, a lure on/off and a speed change, via `LibKa0s-Sim`.
Tests: the kit's sim tests + `test_sim_skill_up_drives_flash`.

### Task 5.3: Locales, bindings, diagnostics
Locale files per standard (enUS full, others stubbed per localization-§). `Bindings.xml` CLICK binding.
`modules/Diagnostics.lua` sections: model counts, probe summary, bonus sources, layout. Kit tests.
- Push at the end of M5.

## Milestone 6 — Docs, battery, audit, review

- [ ] 6.1 Docs: README (features, version history 1.0.0, why Forever-only), CLAUDE.md stub, DEPENDENCIES.md,
  `docs/ARCHITECTURE.md` (incl. per-client feature table: "all features serve Forever; addon is Forever-only by
  owner decision"), `docs/testing.md`, `docs/smoke-tests.md` (design §9 list).
- [ ] 6.2 `/dev-copilot:wow-automated-tests` bundle (lint, tests, perf, lizard) → green.
- [ ] 6.3 `/dev-copilot:wow-standards-audit` against the M0 standards branch → fix MUST deviations.
- [ ] 6.4 `/dev-copilot:review` (WoW profile) → fix confirmed findings.
- [ ] 6.5 File the LibKa0s issue "promote Skill Master bar widget to Widgets" (`gh issue create -R tusharsaxena/LibKa0s`).
- [ ] 6.6 Push all three branches. Report to the owner with the smoke checklist. **Stop and wait for go.**

## Milestone 7 — After the owner's go

- [ ] 7.1 `git fetch` in each repo. Rebase the standards branch on `origin/master` and resolve version/changelog
  collisions with the other agents' work. Merge to master and push. Same for dev-copilot (if a branch exists).
- [ ] 7.2 Merge `feat/2026-11-10-skill-master-v1` into SkillMaster `main` and push.
- [ ] 7.3 Cleanup: delete the merged branches (local + remote), `git worktree remove` both `#Worktrees/*-forever-only`,
  and drop any stashes this run created. Only touch what this run made.
