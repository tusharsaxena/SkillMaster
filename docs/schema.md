# Schema — Ka0s Skill Master

## SavedVariables

Exactly two (savedvariables-§4, toc-file-§2):

- `SkillMasterDB` — AceDB-3.0, defaults from `defaults/Profile.lua`.
- `SkillMasterPerfDB` — LibKa0s-Perf-1.0's capture ring, outside the profile tree (performance-§5).

## Shape and defaults

```
SkillMasterDB
  global
    schemaVersion = 0            -- default 0; the runner raises it to NS.SCHEMA_VERSION (1)
    minimap = { hide = false }   -- LibDBIcon's own table (launcher-§3); LibDBIcon adds minimapPos
  profiles.<name>
    enabled = true               -- Enable Ka0s Skill Master; /skm enable, /skm disable
    scale   = 1                  -- Master scale (0.5 .. 2)
    alpha   = 1                  -- Master opacity (0 .. 1)
    locked  = false              -- Lock frame; /skm lock, /skm unlock
    window  = { point = false }  -- drop point, written only by modules/MainWindow.lua
    skin = {
      source = "ka0s", skin = <library default: WoW Forever>,
      ignorePanel = false, ignoreFonts = false,
      font = "", texture = "", outline = "hud",
      pickerSeen = false,
    }
    alerts = {                   -- modules/Alerts.lua (T4.2); the rows arrive with T5.1's Alerts page
      cap = true,                -- rank-cap toast + chat line
      weapon = true,             -- weapon-gap toast
      weaponGap = 25,            -- points below the weapon cap (5 x level) that count as behind
      sound = false,             -- the toast's sound
      point = false,             -- toast drop point, written only by modules/Alerts.lua
    }
```

Session-only rows (never stored): `state.debugConsole` (the console checkbox) and `state.testMode`.
The Minimap button row's path is `global.minimap.shown`; its get/set invert onto `global.minimap.hide`.

## Writers

Every row goes through `NS.SetByPath` (`settings/Schema.lua`). The named non-setting state and its
writers: `profile.window.point`, owned by `modules/MainWindow.lua` (`savePoint` on drag stop,
`W.ResetPosition`); `profile.alerts.point`, owned by `modules/Alerts.lua` (the toast's
`setPosition`); `global.minimap.minimapPos`, LibDBIcon's own.

## Migrations

| Version | Step | What it does |
|---|---|---|
| 0 → 1 | pre-versioning | nothing to reshape; the stamp itself |

A new step is appended to `STEPS` in `core/Database.lua` with `to = N`, and `NS.SCHEMA_VERSION` is
raised to `N` in the same change. A profile-scoped step sets `perProfile = true`.
