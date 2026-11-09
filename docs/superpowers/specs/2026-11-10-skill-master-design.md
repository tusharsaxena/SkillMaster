# Ka0s Skill Master — Design

**Date:** 2026-11-10 · **Status:** draft for owner approval · **Client:** WoW Forever only (1.60.1, interface 16001)

Decisions the owner made are marked **(owner)**. Decisions Claude made are marked **(call)**. The owner can override any call.

## 1. Intent

The stock Skills tab and Whetstone show a flat list of `rank / max` bars. Skill Master turns that list into a live,
fully skinnable dashboard for a vanilla-era character. It covers every weapon skill, primary and secondary
profession, Defense, Lockpicking and Riding, and puts the character's stats next to them as normalized bars with
threshold markers. Every bonus is visible and explained. Unlearned skills say where to learn them. Broker feeds
put the same data on any LDB display. The bar was set as "Whetstone on steroids": Whetstone's job, done with the
Ka0s look, its options depth and its integrations.

**Why Forever only (owner):** weapon skills, Defense, level-tied caps and weapon-master trainers do not exist on
Retail, and Retail professions are a different system. The core of the addon has nothing to show there.

## 2. Goals

1. Show every skill in four categories, Primary, Secondary, Weapon and Other (Defense, Lockpicking, Riding)
   **(owner)**, as data bars in the style of AuraMaster / EllesmereUI data bars **(owner)**.
2. Show every bonus on the bar: an overlay segment, a text suffix, a tooltip breakdown and an expiry timer for
   temporary bonuses **(owner, all four)**.
3. Character stats in four groups (Base + melee/ranged, Spell + regen, Defense + resists, Utility incl. movement
   speed) **(owner)** as bars and/or text. Each stat is scaled against its own reference **(owner)** and shows
   cap/threshold markers **(owner)**.
4. Layout: every section is a block. Any block can dock into the main window or be detached into its own movable
   frame **(owner)**.
5. LDB: the standard launcher, plus four data feeds, *All skills*, *Professions*, *Weapon Skills* and *Stats*.
   There are no per-item feeds **(owner)**. Feed text is an editable template with a skill-up flash **(owner)**.
6. Clicking a bar or a feed row opens the relevant game window **(owner)**.
7. Unlearned weapon skills show trainer directions from a bundled trainer DB. A click sets a waypoint through
   TomTom, else a native map pin, else prints directions in chat **(owner)**.
8. Extras **(owner, all four)**: cap & training alerts, a session log with ETA, an alt overview and gathering/fishing
   helpers.
9. Every Ka0s standard feature applies: LibKa0s skins (WoW Forever is the default on Forever), the options panel,
   launcher, slash commands, test and sim mode, key binding, localization, automated tests, and a customization
   option for every visual element **(owner)**.

## 3. Non-goals / anti-goals

- **Non-goal:** Retail support. No Retail code paths exist, and the TOC load-gates Retail out.
- **Non-goal:** per-item LDB feeds (the owner chose category feeds).
- **Non-goal:** recipe browsing or tradeskill-window replacement. Skill Master opens the stock window.
- **Non-goal:** armor proficiencies, languages and class spell-school lines (not selected).
- **Anti-goal:** anything taint-prone. Opening profession windows must use secure buttons, and the addon must
  never call protected functions from insecure code in combat.
- **Anti-goal:** wrong data shown as fact. Trainer coords and threshold numbers stay unverified until they have
  been checked in game. A bonus that cannot be attributed shows as "Other", never as a guessed source.
- **Anti-goal:** a heavy addon. Skills update only on `SKILL_LINES_CHANGED` / `CHAT_MSG_SKILL`, and stats on a
  throttled set of unit events. Nothing polls per frame except the visible expiry timers.

## 4. Standards impact (prerequisite work)

The Ka0s standard (clients-§1/§2) currently allows no Forever-only addon. **Owner ruling, 2026-11-10:** an addon
may be single-client, Retail-only or Forever-only, when its core does not exist on the other client. The default
is still to build for both.

- `WowAddonStandards` (own branch, version bump + changelog, pushed, **not merged** until the owner says go):
  - clients.md: state the default ("build for both") and the single-client exception. The owner decides it and
    the README/ARCHITECTURE records the reason.
  - ADDONS.md: a new Clients value `Forever`. Its TOC shape is one number (16001) plus a load-gating line, so the
    Retail client never lists it. The exact directive (`## AllowLoadGameType: camelot`, mirroring Retail's
    `standard`/`camelot` pair) is to be verified against toc-file-§3. Audit flags: a missing gating line, any
    `IsRetail()` branch or Retail seed list (dead code). Add Skill Master's row.
  - Ripple per the standard's own process (index blurb, toc-file-§3 table, context pack, playbooks if they
    enumerate the values).
- `dev-copilot`: check whether `wow-new-addon`, `wow-standards-audit` or `wow-bump-interface` hard-code the three
  values. If any does, add `Forever` on its own branch (same push/merge rule).
- Skill Master is scaffolded with `/dev-copilot:wow-new-addon`, which follows `NEW_ADDON.md` and the context pack.
  The standard wins over anything in this doc on layout, file names and conventions.

## 5. Architecture

### 5.1 Libraries
The Ka0s stack applies (Ace3, LibStub, CallbackHandler, LibSharedMedia, LibDataBroker-1.1, LibDBIcon, LibKa0s with
its Skin, Widgets, Options, Launcher, Slash, Toast, Sim, Compat and DebugLog majors). Optional: TomTom (detected,
never required). **(call)** Tooltips use the LibKa0s tooltip facility if one exists. If not, they use the stock
GameTooltip with custom bar lines drawn by our own pool.

### 5.2 Modules (call)
| Module | Responsibility |
|---|---|
| `SkillData` | Scans `GetNumSkillLines`/`GetSkillLineInfo`. Classifies each line into a category by its localized header. Builds the model `{ key, name, category, rank, max, tempPoints, modifier, learned, ... }`. Fires `SkillMaster_SkillsUpdated` and `SkillMaster_SkillUp(key, old, new)`. |
| `Bonuses` | Breaks a skill's modifier down into sources: racial table (permanent), equipped items (tooltip scan for "+N <Skill>" / "Increased <Weapon> +N"), weapon temp enchants (`GetWeaponEnchantInfo` + tooltip, e.g. lures, with expiry), buffs. Whatever is left is "Other". Each source is tagged temp/perm with an optional expiry. |
| `StatData` | Reads stats per group through feature-detected APIs. Computes derived values (armor mitigation % vs level-equal mob). Each stat carries its reference (scale) and threshold list from `data/Stats_Forever.lua`. |
| `Trainers` | `data/Trainers_Forever.lua`: weapon masters (faction, city, NPC, coords, cost, skills taught), profession trainers per rank, riding trainers per race. Lockpicking is taught by the class trainer. Answers "where do I learn X / train the next rank of X" for the player's faction. |
| `Waypoints` | TomTom (`TomTom:AddWaypoint`) → native pin (`C_Map.SetUserWaypoint`, feature-detected) → chat directions. |
| `Display` | Block engine. A *block* is one section (Primary, Secondary, Weapon, Other, Stats:Base, Stats:Spell, Stats:Defense, Stats:Utility). Blocks render into the main window (docked, ordered, collapsible) or into their own detached frame. Rows are pooled. |
| `Broker` | The standard launcher plus 4 data feeds, text templates, skill-up flash and tooltips. |
| `Alerts` | Rank-cap reached → toast + chat with the next trainer. Weapon skill ≥ N below 5×level → toast. Each alert can be switched off, with an optional sound. |
| `SessionLog` | Ring buffer (500 per char) of skill-ups `{ t, key, old, new }`. Session rate (ups/hour) over a sliding window. ETA to max per skill. |
| `Alts` | Snapshots each character's skills on logout and on change into `global.characters[realm-name]`. |
| `Helpers` | Gathering: highest skinnable mob level, minable/herbable nodes vs skill (table), fishing skill needed for the current zone (table, by uiMapID if available, else zone name). |
| `Sim` | Test mode = a static fake character for layout. Sim mode = scripted skill-ups, lure on/off and stat changes, to preview the flashes, toasts and timers. |

### 5.3 Data flow
Events → `SkillData`/`StatData` (debounced 0.1s) → AceEvent messages → `Display`, `Broker`, `Alerts`, `SessionLog`,
`Alts`. Nothing reads the WoW API except the data modules, so every display can be driven by Sim/Test and by the
headless test harness.

### 5.4 Forever API probe (first implementation step)
The Forever client's API surface is only partly known (LibKa0s#44). Before the data modules are built, a
`/skm probe` verb dumps a JSON report the owner runs once in game. It covers the exact return shape of
`GetSkillLineInfo` (temp points, modifier), what `GetWeaponEnchantInfo` returns while a lure is applied, the
presence of `GetUnitSpeed`, `GetSpellBonusDamage`, `GetSpellCritChance`, `GetHitModifier`, `GetCombatRating`,
`C_Map.SetUserWaypoint`, `C_Map.GetBestMapForUnit`, `CastSpellByName` protection, and the localized skill header
names. Findings go to `docs/client-quirks` (the addon's own quirk file) and decide which stats ship. A stat the
API cannot give is left out of the defaults (clients-§3 feature detection), never faked.

## 6. UI

The mockup is the visual spec: the private claude.ai canvas *Skill Master UX*
(https://claude.ai/artifact/NHcfE8qKUA5a8jJgSprc2N), six artboards: main window, detached blocks + alerts,
tooltips + trainer popup, broker feeds + launcher menu, journal, options. Its artboard sources are copied into
`docs/mockups/` so the repo holds the spec. Summary:

### 6.1 Main window
Title bar "Skill Master" with buttons: lock, settings, journal and close. An optional summary strip shows the
level, session skill-ups and the next alert. Below it are the docked blocks, each with a collapsible header
(like the screenshot, Ka0s-skinned) whose detach button pops the block out. Scrolls when taller than its
configured max height.

### 6.2 Skill row
`[icon] Name ............ [====base====|+bonus|    ] 107 (+25) / 150  [⏱ 4:12]`
- Fill = rank / max. Bonus = overlay segment past the base, in its own color (temp vs perm), and it may extend
  past the max marker.
- Tier ticks on profession bars at 75/150/225/300. On weapon bars the max is 5×level and a marker shows the
  current rank's distance to it.
- Color modes **(call)**: by category, by progress gradient, by skill-up likelihood (gray/green/yellow/orange
  vs. max), or flat.
- Unlearned weapon skill: dimmed row, "Not learned · Woo Ping, Stormwind · 10s" and a pin button.
- Hover: tooltip with rank, max, bonus breakdown, session gains, ETA and the next trainer. Click: open the game
  window (6.5). Shift-click: link to chat. Right-click: row menu (pin to feed, hide, set waypoint).

### 6.3 Stat row
`Name  [=====|===:====|==]  value` with a threshold marker (tick + label on hover, e.g. "Hit cap 9%",
"Defense 440", "Resist cap 315") and a reference scale per stat. Defaults **(call)**: primaries vs. the highest
primary, percentages vs. 100% or their cap, speed vs. 100%, resists vs. 315. Each stat can be shown as a bar, a
text value or both, and can be hidden.

### 6.4 Journal window (call)
A second window with two tabs. *Session Log* lists skill-ups with timestamps, rate and ETA, and can be cleared.
*Alts* is a grid of characters × skills with mini bars, filterable by category. It opens from the main window
title bar, the launcher menu or `/skm journal`.

### 6.5 Click targets (call)
| Row | Opens |
|---|---|
| Crafting profession / Cooking / First Aid / Smelting (Mining) | Its tradeskill window, via a secure action button (`type=spell`). Disabled in combat. |
| Gathering (Herbalism, Skinning), Fishing, weapon, Defense, Lockpicking, Riding | Character frame → Skills tab |
| Unlearned skill | Trainer popup + waypoint |
| Stat row | Character frame → paper doll |
| Feed row (tooltip) | Never secure. Crafting rows open the main window scrolled to that row. Every other row opens the same window as its main-window row. Clicking a feed's label toggles the main window. |

### 6.6 Options panel
The standard Ka0s settings panel (options-ui), with pages: **General** (enable, lock, skin, scale, strata,
test/sim), **Layout** (block order, dock/detach per block, columns, max height, spacing), **Bars** (texture,
height, border, background, fill/bonus/tier/marker colors, color mode, spark, text template & font per element),
**Skills** (per-category show/hide, per-skill hide, sort, unlearned display, tier ticks), **Stats** (per group/per
stat show, mode, reference, markers), **Broker** (per feed template, flash duration, tooltip content), **Alerts**,
**Journal** and **Profiles**. Every visual element (window, header, row, bar, text, icon, tooltip, toast) has
font, size, color, texture and border settings, or follows the skin.

### 6.7 Broker feeds
| Feed | Default text template | Tooltip |
|---|---|---|
| Skill Master: All | `{pinned} · +{gains}` | All categories with mini bars, bonuses, session gains |
| Skill Master: Professions | `{lowestProf}` | Primary + secondary |
| Skill Master: Weapons | `{equippedWeapon}` (main hand) | Weapon skills + Defense, below-cap highlighted |
| Skill Master: Stats | `{stat:crit} crit · {stat:speed}` | All four stat groups |

Tokens (call): `{pinned}`, `{gains}`, `{last}`, `{lowestProf}`, `{equippedWeapon}`, `{skill:<key>}`,
`{stat:<key>}`, `{level}`. When a skill goes up, the feed text is replaced by "▲ Bows 81" for N seconds (default 5).

### 6.8 Launcher (standard)
Left-click opens settings and right-click opens the menu: **Enabled · Locked · Test mode · Sim mode · Show
window**. The menu also gets a *Journal* entry **(call)**. Show window gets a `CLICK` key binding (launcher-§6).

### 6.9 Slash (call)
`/skm` (alias `/skillmaster`): `show`, `hide`, `toggle`, `journal`, `lock`, `unlock`, `test`, `sim`, `probe`,
`reset`, `config`, plus the standard verbs.

## 7. Saved variables (call)
`SkillMasterDB` (AceDB). `profile`: all display/options. `char`: session log, pinned skill, block positions if
per-char layout is enabled. `global.characters`: alt snapshots `{ class, level, faction, updated, skills = {...} }`.

## 8. Data tables (all `*_Forever.lua`, per clients-§5)
- Trainers (weapon masters, profession rank trainers, riding), racial skill bonuses, profession rank caps & level
  requirements, stat thresholds & references, gathering node requirements, fishing zone requirements.
- Each table records its source and a `verified` flag. Unverified entries show a small "unverified" marker in
  the tooltip until the owner's smoke pass flips them.

## 9. Testing
- Headless harness (testkit): `SkillData` classification, `Bonuses` attribution (fixture tooltips), `StatData`
  normalization/markers, template rendering, ETA math, alt snapshots, trainer lookup.
- luacheck clean, lizard CCN ≤ 15, the automated-test bundle per standard.
- `docs/smoke-tests.md`: an in-game checklist for the owner on Forever (probe, each category, lure timer, click
  targets in and out of combat, TomTom on/off, each skin, detach/dock, feeds in a broker display).

## 10. Left to the builder
Exact file layout (the standard decides), widget implementation, the color defaults inside the skin tokens, data
table content (research and cite sources), and the localization keys.

## 11. Risks
- Forever API gaps → handled by the probe-first step and feature detection.
- Trainer coords and thresholds may be wrong for Forever → `verified` flags and the smoke pass.
- Secure buttons for profession windows inside a detachable, re-pooled row frame → the secure overlay is
  created once per profession and is only re-anchored out of combat.

## 12. Builder-check calls (Claude, 2026-11-10)
1. **Probe vs build order.** Data modules are built against vanilla 1.12 return shapes behind feature detection,
   with fixture tests. The probe ships in the first milestone, and its JSON (when the owner sends it) corrects the
   shapes. The build does not block on the probe. Every API assumption is listed in `docs/client-quirks.md` as
   "assumed" until the probe confirms it.
2. **Standards ordering.** The standards (and dev-copilot, if needed) changes are milestone 0 of the same plan, on
   their own branches. Skill Master is scaffolded and audited against the standards branch. Skill Master's
   branch is not merged before the standards branch.
3. **Release scope.** One feature-complete v1.0.0 covering every goal in §2. Milestones are internal checkpoints,
   not releases. Unverified trainer/threshold entries may ship with their "unverified" marker. The owner decides
   the merge and the release.
4. **Helpers placement.** Gathering and fishing helpers are tooltip lines on the Skinning, Mining, Herbalism and
   Fishing rows, plus an optional one-line hint under the row (off by default). They get no block of their own.
   Options live on the Skills page.
5. **Feed rows** never use secure frames (see 6.5).
6. **Bars widget.** Skill Master builds its own bar widget on LibKa0s Skin tokens. A GitHub issue on LibKa0s
   proposes promoting it to Widgets later. No cross-repo widget work in this plan.
