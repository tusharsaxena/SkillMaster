# Module map — Ka0s Skill Master

Every non-vendored file the TOC loads, in load order, with its one responsibility. The TOC's `#`
section headers fix the folder order `libs → locales → core → defaults → modules → settings`
(layout-§1); inside `core/` the order is what each file resolves at load, and each load-bearing
position says so beside its TOC line (toc-file-§5).

| File | Responsibility | Load-order note |
|---|---|---|
| `locales/enUS.lua` | `NS.L` with its key-is-the-string fallback | creates `NS.L`, read at load by DebugLogSetup and every settings file |
| `core/Namespace.lua` | folder name, version fallback, `[SM]` chat tag, library-missing sentence | first: every file reads it |
| `core/Compat.lua` | `NS.Compat`: the skill-list shims, one normalized line record from either return shape ([compat-layer.md](compat-layer.md)) | conventional: reached at call time |
| `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont`, `RegisterLSM` (LibKa0s-Media-1.0) | before Constants, which resolves `FONT_MONO` from it |
| `core/Constants.lua` | brand, logo paths, monospace face, minimap path, `LAYERS` | read at load by the setup files below |
| `core/State.lua` | session-only state: the debug flag, test mode | conventional |
| `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` (LibKa0s-Env-1.0) | conventional |
| `core/CoreSetup.lua` | `NS.Print`, SafeRegister family, window chrome, the `MakeCloseButton` wrapper (LibKa0s-Core-1.0) | before everything that prints |
| `core/SkinSetup.lua` | the skin owner, `NS.Skin`, the stored choice, the picker, the `skin` verb (LibKa0s-Skin-1.0) | registers at load; `NS.DEFAULT_SKIN` read by defaults |
| `core/Bus.lua` | `NS.MSG`, the bus record and targets (LibKa0s-Bus-1.0) | before any subscriber |
| `core/PoolSetup.lua` | `NS.Pool` (LibKa0s-Pool-1.0), for the rows and bars to come | conventional |
| `core/WidgetsSetup.lua` | `NS.Widgets` (LibKa0s-Widgets-1.0): the test strip | before the window |
| `core/LifecycleSetup.lua` | the stand-down latch, `NS.StoodDownRefusal` (LibKa0s-Lifecycle-1.0) | before PerfSetup, which hands it to Perf |
| `core/PerfSetup.lua` | `NS.Perf` and its buckets (LibKa0s-Perf-1.0) | before any file taking `NS.Perf` as an upvalue |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, `NS.Debug` and its gates (LibKa0s-DebugLog-1.0) | after Constants, State and CoreSetup |
| `core/SkillMaster.lua` | AceAddon registration, `OnInitialize` / `OnEnable`, stand-down and stand-up, test mode | after CoreSetup: reclaims `NS.Print` from AceConsole |
| `core/Database.lua` | AceDB store and the migration runner | conventional |
| `core/LauncherSetup.lua` | the launcher object (LibKa0s-Launcher-1.0), registered OnEnable | conventional |
| `defaults/Profile.lua` | `NS.defaults`, the only place a default is written | read by the schema rows at load |
| `defaults/SkillCatalog_Forever.lua` | `NS.SkillCatalog` (every profession, the 16 weapon lines, Defense, Lockpicking, Riding), the excluded Skills-tab headers, `NS.DataMeta` | read at load by SkillData |
| `defaults/ClassWeapons_Forever.lua` | `NS.ClassWeapons_Forever[classFile]`: the weapon lines and Riding each class can train | read at load by SkillData |
| `defaults/Ranks_Forever.lua`, `Trainers_Forever.lua`, `Gathering_Forever.lua`, `Fishing_Forever.lua` | the rank ladders, trainer records, gathering needs and fishing zones (all `verified = false`) | read at call time by Trainers and SkillHelpers; through `NS.L` at load |
| `defaults/Racials_Forever.lua` | `NS.Racials_Forever.byRace`: the +5 racial weapon skills | read at call time by Bonuses |
| `defaults/Stats_Forever.lua` | `NS.STAT_DEFS`: the 30 stats, their groups, references and markers | read at call time by StatData |
| `modules/Bar.lua` | `NS.Bar`: the data bar (base, bonus segment clamped at the end, tier ticks, threshold markers, spark, text, expiry timer), its resolved style and its pool | conventional: reads the skin, the pool and the profile at call time |
| `modules/Chrome.lua` | `NS.Chrome`: the title-bar and header icon controls (catalog marks, a glyph fallback) | conventional |
| `modules/Rows.lua` | `NS.Rows`: one skill or stat row (initials icon, name, bar, timer; the unlearned variant with its trainer line and Go button), its pool and the pure helpers (values, colors, trainer line, money) | conventional |
| `modules/Blocks.lua` | `NS.BLOCKS`, `NS.BlockDefs`, `NS.Blocks`: the eight blocks, their persisted layout, detach / dock / collapse (`LAYOUT_CHANGED`), the entries each shows, the block header, the shared row layout pass; repaints every surface on the data and layout messages | declares the block titles through `NS.L` at load; subscribes on its own bus target |
| `modules/Detached.lua` | `NS.Detached`: a detached block's own HUD frame, its drag-only drop point | conventional |
| `modules/SecureOverlay.lua` | `NS.SecureOverlay`: the crafting rows' secure buttons (made, laid and shown only out of combat) and the combat queue `AfterCombat` | registers its two combat events on its own bus target at load |
| `modules/Interact.lua` | `NS.Interact`: the click map (design §6.5), shift-click to chat, the row menu | conventional |
| `modules/RowTooltip.lua` | `NS.RowTooltip`: the row tooltip's lines (numbers, bar, bonuses with timers, session, next rank, cap gap, gathering and fishing helpers, stat markers, click hints) on GameTooltip | conventional |
| `modules/TrainerPopup.lua` | `NS.TrainerPopup`: the trainers for the faction, one card each, the waypoint and print actions | conventional |
| `modules/Waypoints.lua` | `NS.Waypoints`: TomTom, else the native user waypoint, else chat directions | conventional |
| `modules/MainWindow.lua` | the main window: title band (lock, journal, settings, close), summary strip, docked blocks in a scrolled body, bonus legend, test strip, toggle, key binding button | publishes `NS.BINDINGS` for the General page |
| `modules/Probe.lua` | `/skm probe`: the Forever API report as JSON in a copy window | reads only core members at load |
| `modules/SkillData.lua` | the skills model: scan, classify, synthesize unlearned rows, `SKILLS_UPDATED` / `SKILL_UP`; builds `NS.SkillNameToKey` | after the catalog and the locale, read at load |
| `modules/Trainers.lua` | `NS.Trainers`: `For(key, faction?, race?)` and `NextRank(...)` over the trainer and rank tables | reads the defaults at call time |
| `modules/Helpers.lua` | `NS.SkillHelpers`: skinnable level, weapon cap, fishing need, gatherable nodes (`NS.Helpers` is the options library) | reads the defaults at call time |
| `modules/Bonuses.lua` | `NS.Bonuses`: a skill's modifier broken into racial, item, enchant, buff and Other sources; `BONUSES_UPDATED` | defines `NS.addon:OnBonusesUnitChanged` at load, so after `core/SkillMaster.lua`; reads SkillData at call time |
| `modules/Diagnostics.lua` | the diagnostics report's sections | read at run time |
| `modules/StatData.lua` | `NS.StatData`: the stats model over `NS.STAT_DEFS`, `STATS_UPDATED`, the speed ticker | registers its events on its own bus target at load |
| `modules/SessionLog.lua` | `NS.SessionLog`: the per-character ring of skill-ups (`db.char.log`, 500), session gains, `Rate`, per-skill `ETA`; hears `SKILL_UP` | subscribes on its own bus target at load (after `core/Bus.lua`) |
| `modules/Alts.lua` | `NS.Alts`: each character's skills in `db.global.characters["<realm>-<name>"]` on `SKILLS_UPDATED` (debounced) and `PLAYER_LOGOUT`; `List`, `Forget` | subscribes on its own bus target at load; reads SkillData at call time |
| `modules/Journal.lua` | the Journal window: Session Log and Alts tabs, `/skm journal` | reads SessionLog and Alts at call time; repaints on `SKILLS_UPDATED` / `LAYOUT_CHANGED` |
| `modules/Alerts.lua` | `NS.Alerts`: the rank-cap and weapon-gap toasts (LibKa0s-Toast-1.0), the cap's chat line, the click-to-waypoint | subscribes to `SKILL_UP` / `SKILLS_UPDATED` on its own bus target at load; reads SkillData, Trainers and the settings at call time |
| `modules/Template.lua` | `NS.Template.Render(tpl, ctx)`: the broker feed text tokens (`{pinned}`, `{gains}`, `{last}`, `{lowestProf}`, `{equippedWeapon}`, `{skill:<key>}`, `{stat:<key>}`, `{level}`); an unknown token renders empty | pure; read by Broker at call time |
| `modules/Broker.lua` | `NS.Broker`: the four LibDataBroker data sources (`SkillMaster_All`, `_Professions`, `_Weapons`, `_Stats`), the skill-up flash, the GameTooltip with mini bars and clickable rows; never the launcher, never secure | builds its data objects and bus target at load (after Bus, Pool and the libraries) |
| `settings/Schema.lua` | the schema and the single write seam (LibKa0s-Schema-1.0) | before Slash, OptionsSetup and the pages |
| `settings/Slash.lua` | `NS.COMMANDS` and the dispatcher (LibKa0s-Slash-1.0) | before the landing spec reads it |
| `settings/OptionsSetup.lua` | the panel descriptor, `NS.Helpers` (LibKa0s-Options-1.0) | before every page file |
| `settings/General.lua` | landing spec, Master controls, Skin and Keybindings tabs | first page registered |
| `settings/Profiles.lua` | the AceDBOptions Profiles page | last page registered |

`Bindings.xml` sits at the root beside the TOC and is never a TOC line (launcher-§6).
`libs/` and `tests/_kit/` are vendored from LibKa0s v1.94.0 and never edited.
