# Schema — Ka0s Skill Master

## SavedVariables

Exactly two (savedvariables-§4, toc-file-§2):

- `SkillMasterDB` — AceDB-3.0, defaults from `defaults/Profile.lua`.
- `SkillMasterPerfDB` — LibKa0s-Perf-1.0's capture ring, outside the profile tree (performance-§5).

## Shape and defaults

```
SkillMasterDB
  global
    schemaVersion = 0            -- default 0; the runner raises it to NS.SCHEMA_VERSION (2)
    minimap = { hide = false }   -- LibDBIcon's own table (launcher-§3); LibDBIcon adds minimapPos
    characters = {}              -- the alt snapshots (modules/Alts.lua), keyed "<realm>-<name>" from
                                 -- AceDB 40's db.keys: "PvP-Traxex Silentshot" (forever-quirks-§4);
                                 -- each { name, class, className, race, faction, level, updated,
                                 -- skills = { [key] = { name, category, rank, max } } }
  char.<db.keys.char>
    pinned = false               -- the skill key the broker's {pinned} shows (the row menu's Pin)
    log = {}                     -- the session log's ring (modules/SessionLog.lua): the newest 500
                                 -- { t, key, old, new, zone }, oldest first
  profiles.<name>
    enabled = true               -- Enable Ka0s Skill Master; /sm enable, /sm disable
    scale   = 1                  -- Master scale (0.5 .. 2)
    alpha   = 1                  -- Master opacity (0 .. 1)
    locked  = false              -- Lock frame; /sm lock, /sm unlock
    window  = { point = false }  -- drop point, written only by modules/MainWindow.lua
    skin = {
      source = "ka0s", skin = <library default: WoW Forever>,
      ignorePanel = true, ignoreFonts = false,
      font = "", texture = "", outline = "hud",
      pickerSeen = false,
    }
    layout = {                   -- the Layout page (T5.1)
      width = 440, maxHeight = 560, blockGap = 0, summary = true,
      columns = 1,               -- 1 | 2 columns of docked blocks, each `width` wide
      strata = "MEDIUM", detachedStrata = "MEDIUM",   -- BACKGROUND | LOW | MEDIUM | HIGH
      blocks.<id> = { shown = true, docked = true, order = n, collapsed, scale = 1, locked = false,
                      point = false }   -- point: drag-only, written only by modules/Detached.lua
      blocks.weapon.belowCapOnly = false   -- the detached compact preset's filter (M5 polish)
    }
    bars = {                     -- the Bars page (T5.1); defaults/Profile.lua comments each key
      height, compactHeight, tooltipHeight, miniHeight, rowHeight, fontSize, textAnchor,
      fillDirection = "LEFT",    -- "LEFT" (left to right) | "RIGHT" (right to left)
      rowDisplay = "both",       -- Rows show, skill and stat rows alike: "both" | "bar" | "text"
      textTemplate = "{rank} {bonus} / {max}", spark, ticks, markers, timer, colorMode,
      barTexture, barAlpha, barColor, useClassColorBar, barTextureFromSkin, barColorFromSkin,
      bgColor, useClassColorBg, bgColorFromSkin,
      border = false,            -- Show border: off by default from feedback round 2 (FB-10); no
                                 -- migration, as AceDB stripped a stored true (the old default)
      borderStyle, borderSize, borderColor, useClassColorBorder, borderStyleFromSkin,
      borderColorFromSkin,       -- a skin's real bar border style wins while the style companion
                                 -- is on (skinning-§6); under None, Show border decides
      font, fontColor, useClassColorFont, fontFlags = "@skin", fontShadow, fontFromSkin,
      fontColorFromSkin, fontShadowFromSkin,   -- every *FromSkin defaults true
      colors = { fromSkin = true, primary, secondary, weapon, other, stats, bonusTemp, bonusPerm },
                                 -- fromSkin on: the skin's sm.cat.* / sm.bonus* owner tokens draw
    }                            -- colors are positional { r, g, b, a }
    skills = { showUnlearned = true, hidden = { [key] = true },
               helperTooltip = true,   -- the gathering and fishing lines in a row's tooltip
               helperHint = false }    -- the one-line hint under the row (design §12 item 4)
    stats  = { hidden = { [key] = true } }   -- how a row draws is bars.rowDisplay (schemaVersion 2)
    broker = { flashSeconds = 5, templates = { all, professions, weapons, stats } }
    journal = { point = false, size = false, keep = 500, filter = "professions" }
                                 -- point and size ({ w, h }, the resize grip): drag state, written
                                 -- only by modules/Journal.lua; keep and filter: the Journal page
    waypoints = { method = "auto", announce = true }   -- method: "auto" | "tomtom" | "native" | "chat"
    trainers = { unverified = true,
                 nameColor = { r, g, b, a }, useClassColorName = false,   -- the trainer popup's
                 nameColorFromSkin = true }   -- trainer name: the skin's accent while on (FB-11)
    alerts = {                   -- modules/Alerts.lua (T4.2); the Alerts page (T5.1)
      cap = true,                -- rank-cap toast + chat line
      weapon = true,             -- weapon-gap toast
      weaponGap = 25,            -- points below the weapon cap (5 x level) that count as behind
      sound = false,             -- the toast's sound
      point = false,             -- toast drop point, written only by modules/Alerts.lua
    }
```

Session-only rows (never stored): `state.debugConsole` (the console checkbox), `state.testMode` and
`state.sim` (the Sim mode checkbox, T5.2), and the template presets dropdowns `bars.textPreset` and
`broker.presets.<feed>`, which read the preset the stored template matches and write it to
`bars.textTemplate` / `broker.templates.<feed>` (docs/settings-panel.md). Nothing a simulation does is stored: its session log is a
session-only list (`NS.SessionLog:Override`), alt snapshots stand aside while it runs, and the step
panel's position is the library's memory, never a key here (preview-mode, H4 and H10).
The Minimap button row's path is `global.minimap.shown`; its get/set invert onto `global.minimap.hide`.

## Writers

Every row goes through `NS.SetByPath` (`settings/Schema.lua`). The named non-setting state and its
writers: `profile.window.point`, owned by `modules/MainWindow.lua` (`savePoint` on drag stop,
`W.ResetPosition`); `profile.journal.point` and `profile.journal.size`, owned by
`modules/Journal.lua` (`savePoint` on drag stop and `J.ResetPosition`; `saveSize` on the resize
grip's release); `global.characters`, owned by `modules/Alts.lua` (`Snapshot`, `Forget`);
`char.log`, owned by `modules/SessionLog.lua` (`Add`, `Clear`); `profile.alerts.point`, owned by
`modules/Alerts.lua` (the toast's `setPosition`); `char.pinned`, owned by `modules/Interact.lua`
(the row menu's Pin, refused while test mode or a simulation runs); `global.minimap.minimapPos`,
LibDBIcon's own.

## Migrations

| Version | Step | What it does |
|---|---|---|
| 0 → 1 | pre-versioning | nothing to reshape; the stamp itself |
| 1 → 2 | `rowDisplayFromStats`, per profile | moves a stored `stats.display` of `"bar"` or `"text"` onto `bars.rowDisplay` (unless one is already stored) and drops `stats.display`; `"both"`, the default of both keys, moves nothing |

No `Skin.FollowOnce` step (skinning-§6): the addon was born on LibKa0s v1.94.0 with every HUD color
companion defaulting on, so no stored profile predates the companions and none has to be moved
onto them (NEW_ADDON_CONTEXT item 24b). A companion added later that changes an existing default
would owe the step.

A new step is appended to `STEPS` in `core/Database.lua` with `to = N`, and `NS.SCHEMA_VERSION` is
raised to `N` in the same change. A profile-scoped step sets `perProfile = true`.
