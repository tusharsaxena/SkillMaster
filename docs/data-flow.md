# Data flow — Ka0s Skill Master

The pipeline the addon is built around (design §5.3), and how much of it exists today.

```
game events ──► data modules ──► bus messages ──► displays
SKILL_LINES_CHANGED   SkillData (T2.1)   SKILLS_UPDATED, SKILL_UP   blocks, rows, bars (T3.x)
CHAT_MSG_SKILL        Bonuses (T2.2)     BONUSES_UPDATED            broker feed (T4.1)
UNIT_* stat events    StatData (T2.3)    STATS_UPDATED              alerts, session log, alts (T4.x)
```

- Only the data modules read the client API. Displays read models and messages, so test mode, the
  simulator and the headless suite drive them identically.
- Data modules debounce their events (SkillData 0.1 s, StatData and Bonuses 0.2 s) and publish one message per pass.
- Every message name is a constant in `core/Bus.lua`; each subscriber registers on its own bus target.
- Two displays read an event themselves: the detached weapon block (`modules/Detached.lua`) hears
  `PLAYER_EQUIPMENT_CHANGED` on its own bus target and, while shown, re-renders its equipped-only
  list (in its own frame, or in the merged window it is a section of) and re-syncs the overlays; the
  waypoint arrow (`modules/WaypointArrow.lua`) hears `USER_WAYPOINT_UPDATED` and hides when the
  native pin is cleared or replaced.
- A detached block in a merged window (`modules/Groups.lua`, round 5) is drawn there: every
  `NS.Detached.Refresh` (a layout change or a data repaint) refreshes the merged windows with the
  same `anchor`, and `RefreshValues` and the stand-down reach them too.
- While a utility-stat display is on screen, StatData reads the speed alone every 0.5 s and asks
  for a full stat pass only when it moved. A data message repaints a shown detached frame in place;
  only a layout change re-anchors it.

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
newest `journal.keep` (500 by default; the Journal page, T5.1), or, while a simulation runs, to a
session-only list (`SessionLog:Override`, T5.2) that the same cap trims. `REP_CHANGED` and `CURRENCY_CHANGED` add a
row per change beside them (R5-SM-10), and the cap counts each sort apart: `journal.keep` skill-ups and as many
changes, so a reputation grind never trims a skill-up. The Log's column filters (`NS.JournalFilters`, R5-SM-11)
narrow what the Log draws and the summary and ETA cards count; they are session-only and never written. A profile switch to a lower cap never trims what the log held when the session first wrote to it; lowering *Skill-ups to keep* itself trims at once. *Clear log* asks first, as *Forget* does. A session starts at login and again on the Journal's New session; `Gains` sums this
session's points (`GainsFor(key)` one skill's), `Rate(window, now, key)` is points an hour over the
last `window` seconds of it (one skill's with `key`: the row tooltip's "This session" line), and
`ETA(key)` is `(max - rank)` over the rate that skill's own gains this session set (nil under two
gains). `Since(from, key)`, `Gains(from)` and `ETA(key, from)` take a start instead of the
session's (FB-32): the Journal's Log tab reads them from its range (`journal.range`: this session,
the last 1, 3, 7 or 30 days, or all time, 0), and lists the date and the time of every row. Its
summary card is the range's points, and points an hour for this session or a day for the others.
`SKILLS_UPDATED` asks for one alt snapshot 2 s later and `PLAYER_LOGOUT` takes one at once;
an empty model (a list not loaded yet) keeps the skills the last snapshot had. A snapshot carries
the stats too (FB-33: `stats[key] = { group, value, display, pct }` from StatData's model; no model
keeps the last snapshot's, and a snapshot from before FB-33 has none, a dash in the Journal). The
Journal's Alts tab is a matrix, characters across and the rows of one main-window block down (a
sub-tab per `NS.BLOCKS` id: a skill block's every skill some character has, a stat block's every
`NS.STAT_DEFS` row). Hovering a cell the character has shows the main window's row tooltip for that
row (`NS.RowTooltip.ShowEntry`, R6-SM-04), its entry built from the snapshot (`J.AltTip`) and its lines in
alt mode: no bonus breakdown, session gains, fishing helper or click hint (what only the player's client
knows, or what the grid does not do), the next rank, trainer and weapon cap at that character's level,
faction and race (`raceFile`); an unlearned cell reads "-" and has none. The Journal reads both at render time and repaints on `SKILLS_UPDATED`, which
follows a pass's `SKILL_UP`s, and on `REPS_UPDATED` and `CURRENCIES_UPDATED`, which follow their
`REP_CHANGED` and `CURRENCY_CHANGED` rows.

## Alerts (T4.2)

`modules/Alerts.lua` listens on its own bus target. `SKILL_UP(key)` reads the new entry: a
profession at its cap whose `NS.Trainers:NextRank` answers a rank toasts once per skill and cap
(`cap:<key>:<max>`) and prints one chat line naming the first trainer; a weapon skill
`alerts.weaponGap` (25) or more below `max(max, 5 x level)` toasts once per skill per session
(`weapon:<key>`), when `A.WeaponWatched` reads it: never a muted weapon (`alerts.weaponMuted`), and
as `alerts.weaponMode` says (skip one at 5 points or fewer, the default; only the equipped; all).
Every `SKILL_UP` also toasts the skill-up itself (`alerts.skillUp`, on by default) for the skills
`alerts.skillUpScope` names (all, professions, or combat), with its own sound (`alerts.skillUpSound`). `SKILLS_UPDATED(model)` checks every weapon whose cap rose since the previous model
(a level-up); the first model only records the caps. A left-click on a cap toast hands its trainer
to `NS.Waypoints:Set` when that module exists, else prints the directions. The stand-down clears
the toast; a profile reload re-reads its position.

## Broker (T4.1)

`modules/Broker.lua` keeps the last `SKILLS_UPDATED` and `STATS_UPDATED` models, counts the
session's gains from `SKILL_UP`, and re-renders the one feed's template (`profile.broker.template`)
on every message; an unchanged text is not re-assigned. Any `SKILL_UP` flashes "^ <name> <new>" on
the feed for `profile.broker.flashSeconds` (one AceTimer, restarted by the next skill-up). The
tooltip is filled on hover from the same models: the sections `profile.broker.tooltip.sections`
switches on, less the keys in `broker.tooltip.hiddenSkills` / `hiddenStats` (never the window's
`skills.hidden` / `stats.hidden`), drawn on the feed's own skinned frame or, with
`broker.tooltip.skin` off, the shared GameTooltip. The only client read is the main hand's weapon class, for `{equippedWeapon}`;
in test mode the context's `{pinned}` and `{equippedWeapon}` are the sample's own (`NS.Preview`'s
broker source carries `pins` and `mainHand`), so a sample feed reads neither `db.char.pins` nor
the live gear. Each family has its own feed (SMW-05): its text renders its own pins (`char.pins.<family>`, SMW-06),
and a tree family's feed reads its model (`REPS_UPDATED`, `CURRENCIES_UPDATED`, `STATISTICS_UPDATED`).
The stand-down shows "Off" on the feed; the stand-up re-renders.

## The tree families: reputations, currencies, Statistics (SMW-08..10)

`RepData` and `CurrencyData` read their list once in full through `NS.SharedList` (the character panel's collapsed
headers opened for the read and closed again bottom up; never in combat or while that tab shows; a latch for the
client's echo event), then by id on `UPDATE_FACTION` / `CURRENCY_DISPLAY_UPDATE` (debounced 0.2 s), and send
`REPS_UPDATED` / `CURRENCIES_UPDATED`; a standing or amount that moved is `REP_CHANGED` / `CURRENCY_CHANGED`, which
the session log keeps as a Log row per change (R5-SM-10) and the cap alert checks.

`StatisticsData` builds the category tree on first use (the Statistics window or a block of it drawn,
`FEED_TOOLTIP_TOGGLED` for its feed, or a pinned statistic at `PLAYER_ENTERING_WORLD`). The block provider
(`modules/BlockProviders.lua`) asks `SD:Open(store)` as it lays the rows, with the folds it draws under (the window's
`char.fold`, or the LDB tooltip's own), so only an unfolded category's rows are read. `SD:Watch` registers
`CRITERIA_UPDATE` while the Statistics show (`WINDOW_TOGGLED`, `FEED_TOOLTIP_TOGGLED`, `LAYOUT_CHANGED`) or one is
pinned; the event starts a one-shot 1 s timer whose `SD:Refresh` re-reads the unfolded categories and the pinned rows
and sends `STATISTICS_UPDATED`.

Every tree window draws through `NS.Tree` (`Tree.Rows`: a header row's chevron folds it in `char.fold`, never the
client's state), and `modules/Blocks.lua` and `modules/Broker.lua` hear each family's model message.

## Test mode and the simulator (T5.2)

Test mode swaps every source for the sample character (`modules/Preview.lua` over
`defaults/Preview_Forever.lua`): the models are built by the live pipelines from the fixture
(`SkillData.Build` from its skill lines, `StatData.Build` from its stat values, `Bonuses.Compute`
with its lure as a candidate), and the displays read them through `NS.Blocks.source`,
`NS.Bonuses.source`, `NS.Broker.source` and `NS.Preview.Log()` / `.Alts()` / `.Skill()` /
`.Character()`. The tree families' samples (SMW-11) are the client's own records built from the fixture
(`NS.Preview.FactionRows`, `CurrencyRows`, `StatisticsList`) and modeled by `RepData.Build`, `CurrencyData.Build` and
`StatisticsData.Build`; `NS.Blocks.source`'s third answer and the broker source's `models` carry them, and a test-mode
fold goes to the session's own store. The live modules keep running underneath (StatisticsData reads nothing live
while test mode is on); turning test mode off (or combat, or the stand-down) clears every source and repaints.

The simulator feeds the engine instead. `core/SimSetup.lua` wraps `NS.Compat`; while a session runs,
`modules/Simulator.lua` answers the skill list, the player and the main hand from its world (the
sample character), and each step fires the client's event into the module that registered it:
`CHAT_MSG_SKILL` into SkillData (a scan, then `SKILL_UP`: the broker flash, the session log, the
alerts), `UNIT_INVENTORY_CHANGED` and `SKILL_LINES_CHANGED` for the lure, `UNIT_AURA` and the speed
ticker's read for the mount, `UPDATE_FACTION` and `CURRENCY_DISPLAY_UPDATE` for the trip's last two steps (a
reputation and a currency gain, SMW-11), then `SIM_TICK`. The world also answers the faction, currency and
Statistics reads. The session starts from an empty skills model (no `SKILL_UP` for the jump to the sample) and from
empty tree models (`RepData:Adopt`, `CurrencyData:Adopt`, `StatisticsData:Adopt`, read afresh from the world),
logs into a session-only list and takes no alt snapshot; the stop puts the live models, the alerts' and the
broker's session state and the live log back and repaints once.

## The lifecycle

- `OnInitialize` builds the store, runs migrations, applies the skin, registers the slash commands
  and the settings category.
- `OnEnable` registers the launcher, moves the `disabled` hold to match `enabled`, registers the
  runtime events (Event Subscriptions in [ARCHITECTURE.md](ARCHITECTURE.md)) and shows the first-run
  skin picker once per profile.
- The window lays its docked blocks into one or two columns (`layout.columns`, the shorter column
  first) on every layout change and redraws values in place otherwise; a strata, scale or opacity
  write applies at once (`MainWindow.ApplySettings`) and re-syncs the crafting overlays.
- `enabled = false` (or a perf capture) stands the addon down through the one latch: the window
  hides, every event is unregistered and every timer canceled; standing up re-registers from
  current state.

The README's `## How the bars work` is the player-facing version of this page.

## The seams between the display and the M4 surfaces

- A broker crafting row calls `NS.MainWindow.ShowAndScrollTo(key)`: a collapsed docked block holding
  it is expanded (through `NS.Blocks:SetCollapsed`, queued in combat), the window is shown and
  rendered, and the body scrolls to the row's laid-out top (`row.layY`) less one header. A row in a
  detached block, or an unknown key, still shows the window. An unlearned broker row opens
  `NS.TrainerPopup.Show(key)`. Neither path touches a secure frame (design §6.5).
- A left-click on a cap toast hands its trainer to `NS.Waypoints:Set`: a TomTom waypoint when the
  real TomTom is loaded (`NS.Compat.TomTom`, told by name; AF-SM-TOMTOM), the native user waypoint,
  else the directions in chat; a trainer without coordinates always goes to chat. With Show Skill
  Master's arrow on, the native pin is set unsuper-tracked and `NS.WaypointArrow.Show(trainer)`
  points at it (round 6, R6-11); off, the pin is super-tracked and the client's arrow points.
  `USER_WAYPOINT_UPDATED` (the pin cleared or replaced elsewhere) hides the arrow. With TomTom, the
  arrow is hidden and TomTom's points; a TomTom-shaped global from another addon is ignored (round
  7, R7-7). The arrow's drag writes `waypoints.arrowX` / `arrowY` through `NS.SetByPath`. Its
  right-click menu (round 9, R9-2) clears the waypoint, shares it in chat, shows it on the map, locks
  or resets the arrow, opens `NS.TrainerPopup.Show(key)` (Show trainers) or the Trainers and
  Waypoints page (Arrow settings...), and Hide arrow unticks `waypoints.arrow`.
- The broker tooltip and the Journal's alt grid draw LibKa0s-Widgets-1.0's `Bar` in `NS.BarStyle`'s `mini` style: the broker from
  `NS.Rows.SkillValues` / `StatValues` with `NS.Rows.FillColor`, the Journal from the snapshot's rank,
  cap and category. Both follow `profile.bars` (the colors, `miniHeight`, the broker tooltip's `brokerRowHeight`, the fill direction) as the
  window's rows do. While `bars.colors.fromSkin` is on (the default) a category fills in the skin's
  `sm.cat.<category>` owner token and a bonus in `sm.bonusTemp` / `sm.bonusPerm`, each the mockup's
  color under every skin unless the skin states its own (`core/SkinSetup.lua`).
- The main window's journal mark calls `NS.Journal.Toggle`.
