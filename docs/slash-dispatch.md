# Slash dispatch — Ka0s Skill Master

`/skm` and `/skillmaster` reach one LibKa0s-Slash-1.0 dispatcher over `NS.COMMANDS`
(`settings/Slash.lua`). The bare command opens the settings panel; `options` is an alias of
`config`. The dispatcher's own refusals are `[Cmd]` lines in the debug console.

| Verb | Handler | While disabled |
|---|---|---|
| `help` | the library's help | answers |
| `config` | `NS.OpenOptionsPanel` | answers |
| `skin` | `NS.RunSkinVerb` → `O.SkinVerb` | refused (one line) |
| `show` / `hide` / `toggle` | `NS.MainWindow.Show` / `Hide` / `Toggle` | refused |
| `journal` | `NS.Journal.Toggle`: the Journal window | refused |
| `lock` / `unlock` | `NS.SetByPath("locked", ...)` then the stored echo | refused |
| `test` | `NS.ToggleTestMode` | refused |
| `probe` | `NS.Probe.Verb`: the report as JSON in a copy window | refused |
| `enable` / `disable` | `NS.SetByPath("enabled", ...)` then the echo | answers |
| `list` / `get` / `set` / `reset` | the library's schema CLI | answers |
| `resetall` | the confirmation popup, then the profile reset | answers |
| `debug` | `DebugVerb` (`diagnostics`, `on`, `off`), else the console toggle | answers |
| `diagnostics` | `NS.DebugLog:RunDiagnostics` | answers |
| `perf` | `NS.Perf.OnCommand` | answers |
| `version` | the library's version line | answers |

Under the `perf` hold alone, a feature verb answers "Not available during a performance capture."
(slash-commands-§7). On a library-absent load the host's minimal router answers, and `enable` /
`disable` still write through the schema's `writeThrough` list.
