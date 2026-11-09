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
