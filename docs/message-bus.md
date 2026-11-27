# Message bus

Skill Master's modules talk through thirteen messages. Each one is declared once in `core/Bus.lua` as
`NS.MSG.<KEY>`, through LibKa0s-Bus-1.0's strict catalog, so a misspelled constant raises at the call
site instead of becoming a message nobody receives. This file is the register: the hub
([ARCHITECTURE.md](ARCHITECTURE.md#message-bus)) keeps a summary and links here (documentation-§3,
the spill rule; the trigger, more than ten messages, fired on 2026-11-27).

## How the bus works

- **One publisher target.** `NS.bus` is an AceEvent-embedded table, and every sender calls
  `NS.bus:SendMessage(NS.MSG.X, ...)`. SendMessage fans out to every receiver.
- **One target per consumer.** Each consumer registers on its own target from `NS.NewBusTarget()`,
  because CallbackHandler keys a registration by message and target: two modules sharing a target
  would overwrite each other's handler.
- **Stand-down and stand-up.** The targets belong to `NS.busRecord` (`Bus:New`), so `NS.BusStandDown()`
  takes every event and message down with the addon (slash-commands-§7), and `NS.BusStandUp()`
  registers them again, logging any it could not replay (`Bus` debug lines).
- **Without the library** `core/Bus.lua` falls back to a stub with the same surface: the stand-down
  still works, and the stand-up re-registers nothing until a `/reload`.
- **Names.** The wire name is `Ka0s_SkillMaster_<Event>`, `<Event>` in PascalCase naming what
  happened; the key is its SCREAMING_SNAKE form (naming-cheatsheet).
- **Who sends.** Only data modules read the client API and send the model messages; displays read
  models and messages ([data-flow.md](data-flow.md)), so test mode, the simulator and the headless
  harness drive them the same way.

## The thirteen messages

`SkillData` sends `SKILLS_UPDATED` and `SKILL_UP` (the simulator's restoring stop re-sends
`SKILLS_UPDATED` with the live model), `Bonuses` sends `BONUSES_UPDATED`, `StatData` sends
`STATS_UPDATED` and `Blocks` sends `LAYOUT_CHANGED`. The three tree models send their own (SMW-08..10).
The family windows and the feeds' tooltip say when they show (SMW-10). The simulator
(`modules/Simulator.lua`) sends `SIM_TICK` after each step.

| Constant | Wire name | Sender | Payload | Consumers |
|---|---|---|---|---|
| `SKILLS_UPDATED` | `Ka0s_SkillMaster_SkillsUpdated` | `modules/SkillData.lua` (T2.1); the simulator's restoring stop (`modules/Simulator.lua`) re-sends the live model | the skills model | blocks, broker, alerts, alts, Journal |
| `SKILL_UP` | `Ka0s_SkillMaster_SkillUp` | `modules/SkillData.lua` (T2.1) | key, old, new | blocks (session gains), broker flash, alerts, session log |
| `STATS_UPDATED` | `Ka0s_SkillMaster_StatsUpdated` | `modules/StatData.lua` (T2.3) | the stats model | stat blocks, broker |
| `BONUSES_UPDATED` | `Ka0s_SkillMaster_BonusesUpdated` | `modules/Bonuses.lua` (T2.2) | none | blocks (the bars and tooltips revalue), broker |
| `LAYOUT_CHANGED` | `Ka0s_SkillMaster_LayoutChanged` | `modules/Blocks.lua` (detach, dock, collapse, collapse all, move; a tree fold, `NS.Tree`; a pin, `NS.Pins`); the skin owner's look-change hook; `NS.ApplyLook` (every display row's write, `settings/OptionsSetup.lua`) | none | `modules/Blocks.lua`, which repaints the windows and the detached frames; the Journal; the trainer popup (`modules/TrainerPopup.lua`, its trainer names' color while it is shown); `modules/StatisticsData.lua` (whether to watch `CRITERIA_UPDATE`) |
| `REPS_UPDATED` | `Ka0s_SkillMaster_RepsUpdated` | `modules/RepData.lua` (SMW-08); the simulator's stop | the reputations model | blocks, broker, alts, Journal |
| `REP_CHANGED` | `Ka0s_SkillMaster_RepChanged` | `modules/RepData.lua`, a standing that moved between two reads (`RD.Changes`; none on the first read, the login baseline) | key, old, new, name, oldReaction, newReaction (R5-SM-10) | session log (the Journal's Log: a row per change) |
| `CURRENCIES_UPDATED` | `Ka0s_SkillMaster_CurrenciesUpdated` | `modules/CurrencyData.lua` (SMW-09); the simulator's stop | the currencies model | blocks, broker, alts, Journal |
| `CURRENCY_CHANGED` | `Ka0s_SkillMaster_CurrencyChanged` | `modules/CurrencyData.lua`, an amount that moved | key, old, new, name | session log, alerts (the cap alert) |
| `STATISTICS_UPDATED` | `Ka0s_SkillMaster_StatisticsUpdated` | `modules/StatisticsData.lua` (SMW-10), the first use (unless a block's own pass asked) and each debounced re-read; the simulator's stop | the Statistics model | blocks, broker |
| `WINDOW_TOGGLED` | `Ka0s_SkillMaster_WindowToggled` | `modules/Window.lua` (SMW-10), a family window's show, hide and `OnHide` | family id, shown | `modules/StatisticsData.lua` |
| `FEED_TOOLTIP_TOGGLED` | `Ka0s_SkillMaster_FeedTooltipToggled` | `modules/Broker.lua` (SMW-10, `B.TooltipToggled`), a feed's tooltip up (before it fills) or down | family id, shown | `modules/StatisticsData.lua` (its first use, and whether to watch) |
| `SIM_TICK` | `Ka0s_SkillMaster_SimTicked` | `modules/Simulator.lua` (T5.2), after each step | the step's kind | none yet (published for displays under simulation) |

The three tree families (reputations, currencies, statistics) are heard by `modules/Blocks.lua` and
`modules/Broker.lua` through each family's `message` field (`rawget(NS.MSG, fam.message)`), not a
named registration, so a new tree family needs only its `message` set.

## Adding a message

Follow [common-tasks.md](common-tasks.md#add-a-bus-message): declare it in `core/Bus.lua` with a
comment naming its sender and payload, add its row to the table above, and add it to `test_bus`.
