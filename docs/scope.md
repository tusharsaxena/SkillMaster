# Scope — Ka0s Character Ledger

## What it does

Character Ledger shows a WoW Forever character's skills and stats as bars the player can style:

- every weapon skill, every primary and secondary profession, and Defense, Lockpicking and Riding,
  in four categories (Primary, Secondary, Weapon, Other);
- every bonus on a skill (racial, item, weapon enchant such as a fishing lure, buff), as an overlay
  segment, a text suffix, a tooltip breakdown and an expiry timer;
- character stats in four groups (base and melee/ranged, spell and regen, defense and resists,
  utility including movement speed), each scaled against its own reference with threshold markers;
- trainer directions for unlearned skills and the next rank, with a map-pin waypoint and Character Ledger's own arrow (its look, text, position and right-click menu are settings), or chat directions; a TomTom waypoint instead of the pin when the real TomTom is loaded (AF-SM-TOMTOM);
- the character panel's other tabs (the six-windows run, 2026-11-26): reputations grouped as the Reputation tab
  groups them, each a standing bar (GitHub issue #6); currencies under the Currency tab's headers, a bar where one
  has a cap, never gold (#7); and the Statistics tab's counters, nested and folding, read only as a category opens;
- six windows, one per family (Professions, Skills, Character Stats, Currencies, Reputations, Statistics), and six
  LibDataBroker feeds, one per window, each tooltip sectioned and skinned and each feed with up to five pins (#11);
  alerts, a session log with ETA, an alt overview and gathering helpers.

Each piece of the window is a setting: bar sizes, fill direction, colors (the skin's or the
player's), the border and the font, block order, docking, one or two columns, and the window's and
the detached blocks' frame strata. Test mode shows a sample character and the simulator plays a
scripted session on it.

## What it deliberately does not do

- **Retail.** The addon is Forever-only by owner decision; Retail does not list it (clients-§9).
- **Per-item or per-category broker feeds.** One feed per window (the six-windows run), each tooltip showing and hiding its own sections and rows (feedback round 2, FB-12); a feed shows several elements through its pins, never a feed per element.
- **Gold.** The Currencies window shows only the client's currency list (the owner's ruling, 2026-11-26).
- **Folding the character panel.** The tree windows' folds are the addon's own; reading a reputation or currency
  list opens its collapsed headers for the read and closes them again, never while that tab shows.
- **Recipe browsing or a tradeskill-window replacement.** Character Ledger opens the stock window.
- **Armor proficiencies, languages and class spell-school lines.** Not selected for v1.
- **Guessing.** A bonus it cannot attribute shows as "Other"; a trainer no offline source confirms
  (the trainer probe, GitHub issue #3) and the thresholds stay marked unverified until checked in game. A stat the client API cannot give is left out, never faked.
- **Polling.** Skills update on `SKILL_LINES_CHANGED` / `CHAT_MSG_SKILL`, stats on throttled unit
  events, reputations on `UPDATE_FACTION`, currencies on `CURRENCY_DISPLAY_UPDATE`, and the Statistics on
  `CRITERIA_UPDATE`, registered only while they show or one is pinned, with a one-shot 1 s debounce; the only tickers run while something visible needs them (expiry timers, the speed read, the
  trainer popup's distances, the waypoint arrow) and stop when it hides.
