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
