# Scope — Ka0s Skill Master

## What it does

Skill Master shows a WoW Forever character's skills and stats as bars the player can style:

- every weapon skill, every primary and secondary profession, and Defense, Lockpicking and Riding,
  in four categories (Primary, Secondary, Weapon, Other);
- every bonus on a skill (racial, item, weapon enchant such as a fishing lure, buff), as an overlay
  segment, a text suffix, a tooltip breakdown and an expiry timer;
- character stats in four groups (base and melee/ranged, spell and regen, defense and resists,
  utility including movement speed), each scaled against its own reference with threshold markers;
- trainer directions for unlearned skills and the next rank, with a map-pin waypoint and Skill Master's own arrow (its look, text, position and right-click menu are settings), or chat directions; a TomTom waypoint instead of the pin when the real TomTom is loaded (AF-SM-TOMTOM);
- two LibDataBroker feeds (Skill Master for the skills, Skill Master Stats for the stats since round 6, each tooltip sectioned and skinned), alerts, a session log with ETA, an alt overview and gathering helpers.

Each piece of the window is a setting: bar sizes, fill direction, colors (the skin's or the
player's), the border and the font, block order, docking, one or two columns, and the window's and
the detached blocks' frame strata. Test mode shows a sample character and the simulator plays a
scripted session on it.

## What it deliberately does not do

- **Retail.** The addon is Forever-only by owner decision; Retail does not list it (clients-§9).
- **Per-item or per-category broker feeds.** The owner chose one skills feed whose tooltip shows and hides each section and row (feedback round 2, FB-12), plus one stats feed (round 6, R6-9).
- **Recipe browsing or a tradeskill-window replacement.** Skill Master opens the stock window.
- **Armor proficiencies, languages and class spell-school lines.** Not selected for v1.
- **Guessing.** A bonus it cannot attribute shows as "Other"; a trainer no offline source confirms
  (the trainer probe, GitHub issue #3) and the thresholds stay marked unverified until checked in game. A stat the client API cannot give is left out, never faked.
- **Polling.** Skills update on `SKILL_LINES_CHANGED` / `CHAT_MSG_SKILL`, stats on throttled unit
  events; the only tickers run while something visible needs them (expiry timers, the speed read, the
  trainer popup's distances, the waypoint arrow) and stop when it hides.
