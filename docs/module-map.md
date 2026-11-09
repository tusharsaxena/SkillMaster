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
| `modules/MainWindow.lua` | the main window, its toggle, the test strip, the key binding button | publishes `NS.BINDINGS` for the General page |
| `modules/Probe.lua` | `/skm probe`: the Forever API report as JSON in a copy window | reads only core members at load |
| `modules/SkillData.lua` | the skills model: scan, classify, synthesize unlearned rows, `SKILLS_UPDATED` / `SKILL_UP`; builds `NS.SkillNameToKey` | after the catalog and the locale, read at load |
| `modules/Diagnostics.lua` | the diagnostics report's sections | read at run time |
| `settings/Schema.lua` | the schema and the single write seam (LibKa0s-Schema-1.0) | before Slash, OptionsSetup and the pages |
| `settings/Slash.lua` | `NS.COMMANDS` and the dispatcher (LibKa0s-Slash-1.0) | before the landing spec reads it |
| `settings/OptionsSetup.lua` | the panel descriptor, `NS.Helpers` (LibKa0s-Options-1.0) | before every page file |
| `settings/General.lua` | landing spec, Master controls, Skin and Keybindings tabs | first page registered |
| `settings/Profiles.lua` | the AceDBOptions Profiles page | last page registered |

`Bindings.xml` sits at the root beside the TOC and is never a TOC line (launcher-§6).
`libs/` and `tests/_kit/` are vendored from LibKa0s v1.94.0 and never edited.
