# Schema — Ka0s Skill Master

## SavedVariables

Exactly two (savedvariables-§4, toc-file-§2):

- `SkillMasterDB` — AceDB-3.0, defaults from `defaults/Profile.lua`.
- `SkillMasterPerfDB` — LibKa0s-Perf-1.0's capture ring, outside the profile tree (performance-§5).

## Shape and defaults

```
SkillMasterDB
  global
    schemaVersion = 0            -- default 0; the runner raises it to NS.SCHEMA_VERSION (7)
    minimap = { hide = false }   -- LibDBIcon's own table (launcher-§3); LibDBIcon adds minimapPos
    characters = {}              -- the alt snapshots (modules/Alts.lua), keyed "<realm>-<name>" from
                                 -- AceDB 40's db.keys: "PvP-Traxex Silentshot" (forever-quirks-§4);
                                 -- each { name, class, className, race, faction, level, updated,
                                 -- skills = { [key] = { name, category, rank, max } },
                                 -- stats = { [key] = { group, value, display, pct } } } (FB-33;
                                 -- absent in an older snapshot: the Journal draws a dash)
  char.<db.keys.char>
    pinned = false               -- the skill key the broker's {pinned} shows (the row menu's Pin)
    pinnedStat = false           -- the stat key the Skill Master Stats feed shows (a stat row's Pin;
                                 -- round 6, R6-9); none: the feed reads "Stats"
    log = {}                     -- the log's ring (modules/SessionLog.lua): the newest journal.keep
                                 -- (500; 50 .. 2000) { t, key, old, new, zone }, oldest first; the
                                 -- Journal's ranges reach no further back than it holds
  profiles.<name>
    enabled = true               -- Enable Ka0s Skill Master; /sm enable, /sm disable
    scale   = 1                  -- Master scale (0.5 .. 2)
    alpha   = 1                  -- Master opacity (0 .. 1)
    locked  = false              -- Lock frame; /sm lock, /sm unlock, the window's and the Journal's lock marks
    window  = { point = false }  -- drop point, written only by modules/MainWindow.lua
    skin = {
      source = "ka0s", skin = <library default: WoW Forever>,
      ignorePanel = true, ignoreFonts = false,
      font = "", texture = "", outline = "hud",
      pickerSeen = false,
    }
    layout = {                   -- the Layout page (T5.1)
      width = 420, maxHeight = 560, blockGap = 0, summary = true,
      fitHeight = false,         -- off: the window stays maxHeight tall (owner feedback round 3)
      columns = 1,               -- 1 | 2 columns of docked blocks, each `width` wide
      strata = "MEDIUM", detachedStrata = "MEDIUM",   -- BACKGROUND | LOW | MEDIUM | HIGH
      detached = {               -- Layout > Detached windows (round 5, R5-7): every detached window
        scale = 1, alpha = 1,    -- scale multiplies blocks.<id>.scale
        bgColor, useClassColorBg = false, bgFromSkin = true,
        border = true, borderStyle = "Solid", borderSize = 1, borderColor, useClassColorBorder = false,
        borderFromSkin = true,
        titleBand = "always",    -- "always" | "hover" | "never"
      },
      blocks.<id> = { shown = true, docked = true, order = n, collapsed = false, scale = 1, locked = false,
                      -- collapsed: false for every block (round 6, R6-8: Spell and Defense were true);
                      -- a default change only, no schemaVersion step: a profile that stored a value
                      -- keeps it, and one that never toggled them (AceDB stores no default) reads
                      -- the new default, expanded
                      point = false,    -- point: drag-only, written only by modules/Detached.lua
                      sort = "name" }   -- "name" | "value" | "valueAsc" | "progress" (round 3)
      blocks.weapon.belowCapOnly = false   -- the detached compact preset's filter (M5 polish)
      blocks.weapon.filter = "all"         -- "all" | "learned" | "equipped" | "belowCap": the header's
                                           -- filter mark (round 5, R5-10); a new key with a default,
                                           -- so no schemaVersion step (AceDB answers it)
      groups = {}                -- merged detached windows (round 5, R5-6), written only by
                                 -- modules/Groups.lua: [gid] = { point = { point, relPoint, x, y }
                                 -- | false, columns = { { id, ... }, ... } }; a member is a
                                 -- detached block, in one group at most; two or more per group
    }
    icons = {                    -- Bars > Icons (feedback round 2): the rows' in-game icons
      show = true, size = 16, zoom = 7,   -- zoom: the % cropped from each side of the art
      border = true, borderStyle = "Solid", borderSize = 1, borderColor, useClassColorBorder,
      borderStyleFromSkin = true,         -- the style and thickness follow the skin's icon border
      borderColorFromRow = true,          -- the row's own color (a meaning color: no skin companion)
      borderColorFromSkin = true,         -- off the row's: the skin's icon border, else the swatch
    }
    bars = {                     -- the Bars page (T5.1); defaults/Profile.lua comments each key
      height, rowHeight,         -- the main window's bar and row, and the detached blocks' (no
                                 -- separate detached height: schemaVersion 4 drops compactHeight)
      tooltipHeight, tooltipRowHeight,   -- Main window tooltip bar / row height (the row tooltip)
      miniHeight = 10, brokerRowHeight = 18,   -- LDB tooltip bar / row height (miniHeight: the journal's too)
      fontSize, textAnchor,
      fillDirection = "LEFT",    -- "LEFT" (left to right) | "RIGHT" (right to left)
      rowDisplay = "both",       -- Rows show, skill and stat rows alike: "both" | "bar" | "text"
      textTemplate = "{rank} {bonus} / {max}", timer, colorMode,
      markersWindow = false,     -- a stat's thresholds on the window's bars (detached, merged, LDB
                                 -- tooltip and journal too); round 6, R6-4
      markersTooltip = true,     -- the row tooltip's bar and threshold lines (schemaVersion 7 split
                                 -- the one `markers` switch into these two)
      spark = false,             -- off by default (feedback round 2)
      tierColors = false,        -- Rank tier colors (Color mode By category only): a profession's fill
                                 -- per tier on a scale to 300, each tier a darker shade of the category
                                 -- color; replaced the tier ticks (schemaVersion 4 drops `ticks`)
      barTexture, barAlpha, barColor, useClassColorBar, barTextureFromSkin, barColorFromSkin,
      bgColor, useClassColorBg, bgColorFromSkin,
      border = false,            -- Show border: off by default from feedback round 2 (FB-10); no
                                 -- migration, as AceDB stripped a stored true (the old default)
      borderStyle, borderSize, borderColor, useClassColorBorder,
      borderStyleFromSkin = false,   -- Use the skin's border: OFF by default, the one companion that
                                 -- is (options-ui-§16 deviation, ARCHITECTURE.md); while on, a skin's
                                 -- real bar border style wins (skinning-§6); under None, Show border decides
      borderColorFromSkin,
      font, fontColor, useClassColorFont, fontFlags = "@skin", fontShadow, fontFromSkin,
      fontColorFromSkin, fontShadowFromSkin,   -- every other *FromSkin defaults true
      colors = { fromSkin = true, primary, secondary, weapon, other, stats, bonusTemp, bonusPerm },
                                 -- fromSkin on: the skin's sm.cat.* / sm.bonus* owner tokens draw
    }                            -- colors are positional { r, g, b, a }
    skills = { showUnlearned = true, hidden = { [key] = true },
               helperTooltip = true,   -- the gathering and fishing lines in a row's tooltip
               helperHint = false }    -- the one-line hint under the row (design §12 item 4)
    stats  = { hidden = { [key] = true } }   -- how a row draws is bars.rowDisplay (schemaVersion 2)
    broker = {                   -- the one "Skill Master" feed (modules/Broker.lua; FB-12, schemaVersion 3)
      flashSeconds = 5,
      template = "{pinned} · +{gains}",   -- the feed's text (presets + Custom)
      tooltip = {
        skin = true,             -- Apply skin to the tooltip (FB-13): the feed's own skinned frame
        sections = { primary = true, secondary = true, weapon = true, other = true,   -- Skill Master
                     stats_base = true, stats_spell = true, stats_defense = true,      -- Skill Master
                     stats_utility = true },   -- Stats (round 6, R6-9; schemaVersion 9 dropped `stats`)
        hiddenSkills = { [key] = true },   -- left out of the tooltip only, apart from skills.hidden
                                           -- (all four hidden sets: the Rows page, round 5, R5-13)
        hiddenStats  = { [key] = true },   -- left out of the tooltip only, apart from stats.hidden
      },
    }
    tooltips = {                 -- the Tooltips page (owner feedback round 4)
      row = { barWidth = 200, fontSize = 12 },   -- a main window or detached row's tooltip
      ldb = { style = "window",  -- "window" (modules/BrokerPanel.lua) | "classic" (round 6, R6-10;
                                 -- schemaVersion 8 kept earlier profiles on "classic")
              width = 420, height = 560,   -- the Main window style's size (the window's defaults)
              barWidth = 128, fontSize = 12 },   -- the Classic style's
    }
    journal = { point = false, size = false, keep = 500, range = "session", filter = "primary" }
                                 -- range: session | 1d | 3d | 7d | 30d | all (the Log tab, FB-32);
                                 -- filter: an NS.BLOCKS id (the Alts sub-tab on open, FB-33; a stored
                                 -- "professions" / "weapons" reads as primary / weapon)
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
      weaponMode = "untrained",  -- "untrained" (skip 5 points or fewer) | "equipped" | "all"
      weaponMuted = {},          -- weapons the gap alert never reads, a set of keys
      sound = false,             -- the toast's sound
      point = false,             -- toast drop point, written only by modules/Alerts.lua
    }
```

Session-only rows (never stored): `state.debugConsole` (the console checkbox), `state.testMode` and
`state.sim` (the Sim mode checkbox, T5.2), and the template presets dropdowns `bars.textPreset` and
`broker.preset`, which read the preset the stored template matches and write it to
`bars.textTemplate` / `broker.template` (docs/settings-panel.md). Nothing a simulation does is stored: its session log is a
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
`modules/Alerts.lua` (the toast's `setPosition`); `profile.layout.blocks.<id>.point`, owned by
`modules/Detached.lua` (`savePoint` on drag stop, `StorePoint` for a section split or unmerged from a
merged window); `profile.layout.groups`, owned by `modules/Groups.lua` (`Merge`, `Split`, `Unmerge`,
`Leave`, the band drag's `savePoint`, the normalization on read); `char.pinned` and `char.pinnedStat`, owned by `modules/Interact.lua`
(the row menu's Pin on a skill and on a stat row, refused while test mode or a simulation runs); `global.minimap.minimapPos`,
LibDBIcon's own.

## Migrations

| Version | Step | What it does |
|---|---|---|
| 0 → 1 | pre-versioning | nothing to reshape; the stamp itself |
| 1 → 2 | `rowDisplayFromStats`, per profile | moves a stored `stats.display` of `"bar"` or `"text"` onto `bars.rowDisplay` (unless one is already stored) and drops `stats.display`; `"both"`, the default of both keys, moves nothing |
| 2 → 3 | `oneBrokerFeed`, per profile | one broker feed (FB-12): a stored `broker.templates.all` becomes `broker.template` (unless one other than the default is already stored), and `broker.templates` goes with the Professions, Weapons and Stats feeds' templates; a profile with no `broker.templates` passes through |
| 3 → 4 | `retiredBarKeys`, per profile | drops a stored `bars.compactHeight` (a detached block takes the main window's heights) and `bars.ticks` (replaced by Rank tier colors); nothing carries over |
| 4 → 5 | `journalFilterToBlock`, per profile | the Alts sub-tabs became the main window's blocks (FB-33): a stored `journal.filter` of `"professions"` becomes `"primary"`, `"weapons"` becomes `"weapon"`; `"other"` stays |
| 5 → 6 | `groupsNormalized`, per profile | merged detached windows (round 5, R5-6), `layout.groups`, a new key defaulting to `{}`: nothing carries over; a stored `layout.groups` that is not a table goes, a stored one is normalized against the profile's own blocks (a member that is not a detached block there, a repeat, an empty column and a group of fewer than two go); a profile with none passes through |
| 6 → 7 | `markersSplit`, per profile | thresholds split per surface (round 6, R6-4): a stored `bars.markers = false` carries to both `bars.markersWindow` and `bars.markersTooltip`; any stored `bars.markers` goes, and otherwise the new defaults answer (window off, row tooltip on) |
| 7 → 8 | `classicTooltipKept`, per profile | the LDB tooltip's style (round 6, R6-10), `tooltips.ldb.style`, a new key whose default `"window"` is for new profiles only: every non-empty profile an earlier install stored gets `"classic"`, today's look, unless it already holds a style; a fresh install (the run starts at stamp 0) and an empty stored profile pass through. The runner hands each step `(sv, profile, from)` for this |
| 8 → 9 | `statsSectionRetired`, per profile | the stat blocks moved to their own feed, Skill Master Stats (round 6, R6-9), with a switch per stat block (`broker.tooltip.sections.stats_*`, new keys defaulting on): a stored `broker.tooltip.sections.stats` goes; nothing carries over |

No `Skin.FollowOnce` step (skinning-§6): the addon was born on LibKa0s v1.94.0 with every HUD color
companion defaulting on, so no stored profile predates the companions and none has to be moved
onto them (NEW_ADDON_CONTEXT item 24b). A companion added later that changes an existing default
would owe the step.

A new step is appended to `STEPS` in `core/Database.lua` with `to = N`, and `NS.SCHEMA_VERSION` is
raised to `N` in the same change. A profile-scoped step sets `perProfile = true`.
