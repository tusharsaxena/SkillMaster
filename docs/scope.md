# Scope — Ka0s Skill Master

## What it does

Skill Master shows a WoW Forever character's skills and stats as bars the player can style:

- every weapon skill, every primary and secondary profession, and Defense, Lockpicking and Riding,
  in four categories (Primary, Secondary, Weapon, Other);
- every bonus on a skill (racial, item, weapon enchant such as a fishing lure, buff), as an overlay
  segment, a text suffix, a tooltip breakdown and an expiry timer;
- character stats in four groups (base and melee/ranged, spell and regen, defense and resists,
  utility including movement speed), each scaled against its own reference with threshold markers;
- trainer directions for unlearned skills and the next rank, with a TomTom, map-pin or chat waypoint;
- four LibDataBroker feeds, alerts, a session log with ETA, an alt overview and gathering helpers.

v0.1.0 ships the skeleton those features plug into: the window, test mode, skins, settings, the
launcher and the key binding.

## What it deliberately does not do

- **Retail.** The addon is Forever-only by owner decision; Retail does not list it (clients-§9).
- **Per-item broker feeds.** The owner chose four category feeds.
- **Recipe browsing or a tradeskill-window replacement.** Skill Master opens the stock window.
- **Armor proficiencies, languages and class spell-school lines.** Not selected for v1.
- **Guessing.** A bonus it cannot attribute shows as "Other"; trainer coordinates and thresholds stay
  marked unverified until checked in game. A stat the client API cannot give is left out, never faked.
- **Polling.** Skills update on `SKILL_LINES_CHANGED` / `CHAT_MSG_SKILL`, stats on throttled unit
  events; only visible expiry timers tick.
