# Data flow — Ka0s Skill Master

The pipeline the addon is built around (design §5.3), and how much of it exists today.

```
game events ──► data modules ──► bus messages ──► displays
SKILL_LINES_CHANGED   SkillData (T2.1)   SKILLS_UPDATED, SKILL_UP   blocks, rows, bars (T3.x)
CHAT_MSG_SKILL        Bonuses (T2.2)     BONUSES_UPDATED            broker feeds (T4.1)
UNIT_* stat events    StatData (T2.3)    STATS_UPDATED              alerts, session log, alts (T4.x)
```

- Only the data modules read the client API. Displays read models and messages, so test mode, the
  simulator and the headless suite drive them identically.
- Data modules debounce their events (0.1 s) and publish one message per pass.
- Every message name is a constant in `core/Bus.lua`; each subscriber registers on its own bus target.

## SkillData (T2.1)

`SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL` and `PLAYER_LEVEL_UP` each ask for one scan 0.1 s later; a
burst is one scan. The scan opens every collapsed header through `NS.Compat`, reads every line,
closes the headers it opened (bottom up) and ignores the `SKILL_LINES_CHANGED` its own toggles cause
for 0.2 s. Each line is classified by `NS.SkillNameToKey` (the catalog's names through `NS.L`); an
unknown name lands in Other as `other:<name>`, and a line under Class Skills, Armor Proficiencies or
Languages that the catalog does not name is left out. Unlearned weapon and Riding rows the class can
train follow the learned ones in catalog order. An empty list (not yet loaded at login) is an empty
model with nothing synthesized. Each pass sends `SKILL_UP(key, old, new)` for every learned rank that
rose, then `SKILLS_UPDATED(model)`. Stand-up rescans; stand-down cancels the pending scan with every
other timer.

## SessionLog, Alts and the Journal (T4.3)

`SKILL_UP(key, old, new)` adds one `{ t, key, old, new, zone }` to `db.char.log`, a ring of the
newest 500. A session starts at login and again on the Journal's New session; `Gains` sums this
session's points, `Rate(window)` is points an hour over the last `window` seconds of it, and
`ETA(key)` is `(max - rank)` over the rate that skill's own gains this session set (nil under two
gains). `SKILLS_UPDATED` asks for one alt snapshot 2 s later and `PLAYER_LOGOUT` takes one at once;
an empty model (a list not loaded yet) keeps the skills the last snapshot had. The Journal reads
both at render time and repaints on `SKILLS_UPDATED`, which follows a pass's `SKILL_UP`s.

## Alerts (T4.2)

`modules/Alerts.lua` listens on its own bus target. `SKILL_UP(key)` reads the new entry: a
profession at its cap whose `NS.Trainers:NextRank` answers a rank toasts once per skill and cap
(`cap:<key>:<max>`) and prints one chat line naming the first trainer; a weapon skill
`alerts.weaponGap` (25) or more below `max(max, 5 x level)` toasts once per skill per session
(`weapon:<key>`). `SKILLS_UPDATED(model)` checks every weapon whose cap rose since the previous model
(a level-up); the first model only records the caps. A left-click on a cap toast hands its trainer
to `NS.Waypoints:Set` when that module exists, else prints the directions. The stand-down clears
the toast; a profile reload re-reads its position.

## Broker (T4.1)

`modules/Broker.lua` keeps the last `SKILLS_UPDATED` and `STATS_UPDATED` models, counts the
session's gains from `SKILL_UP`, and re-renders each feed's template (`profile.broker.templates`)
on every message; an unchanged text is not re-assigned. A `SKILL_UP` flashes "^ <name> <new>" on
the All feed and the skill's own feed for `profile.broker.flashSeconds` (one AceTimer, restarted by
the next skill-up). The only client read is the main hand's weapon class, for `{equippedWeapon}`.
The stand-down shows "Off" on every feed; the stand-up re-renders.

## What runs in v0.1.0

- `OnInitialize` builds the store, runs migrations, applies the skin, registers the slash commands
  and the settings category.
- `OnEnable` registers the launcher, moves the `disabled` hold to match `enabled`, registers
  `PLAYER_REGEN_DISABLED` (combat ends test mode) and shows the first-run skin picker once per profile.
- The window renders its empty state, or its test-mode strip, on show and on every mode change.
- `enabled = false` (or a perf capture) stands the addon down through the one latch: the window
  hides, every event is unregistered and every timer canceled; standing up re-registers from
  current state.

The README's `## How the window works` is the player-facing version of this page.

## The seams between the display and the M4 surfaces

- A broker crafting row calls `NS.MainWindow.ShowAndScrollTo(key)`: a collapsed docked block holding
  it is expanded (through `NS.Blocks:SetCollapsed`, queued in combat), the window is shown and
  rendered, and the body scrolls to the row's laid-out top (`row.layY`) less one header. A row in a
  detached block, or an unknown key, still shows the window. An unlearned broker row opens
  `NS.TrainerPopup.Show(key)`. Neither path touches a secure frame (design §6.5).
- A left-click on a cap toast hands its trainer to `NS.Waypoints:Set`: TomTom, then the native user
  waypoint, then the directions in chat; a trainer without coordinates always goes to chat.
- The broker tooltip and the Journal's alt grid draw `NS.Bar` in its `mini` style: the broker from
  `NS.Rows.SkillValues` / `StatValues` with `NS.Rows.FillColor`, the Journal from the snapshot's rank,
  cap and category. Both follow `profile.bars` (the colors, `miniHeight`) as the window's rows do.
- The main window's journal mark calls `NS.Journal.Toggle`.
