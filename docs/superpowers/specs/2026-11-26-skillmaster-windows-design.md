# Six windows, six brokers: reputations, currencies, Statistics and multi-pin (design)

Date: 2026-11-26. Issues: #6 (reputations), #7 (currencies), #11 (pin several elements to a broker). Plan:
`docs/superpowers/plans/2026-11-26-skillmaster-windows.md`.

## The owner's request, verbatim

> Lets also build the following:
>
> https://github.com/tusharsaxena/SkillMaster/issues/6
> https://github.com/tusharsaxena/SkillMaster/issues/7
> https://github.com/tusharsaxena/SkillMaster/issues/11
> - [Image #150: a Reputation window with gold header bands "Alliance", "Steamwheedle Cartel", "Other", each faction a row
>   with a standing bar "Honored 3,672 / 12,000", colored by standing] group as in character panel - e.g. Alliance,
>   Steamwheedle Cartel, Other, etc
>
> Also lets add a window for Statistics - [Image #151: a Statistics window: "Character" header with "Times camped 58",
> "Talent tree respecs --", then a nested folding "Wealth" (Total gold acquired, Auctions posted 33, ...) and
> "Consumables"]
> - Disambiguate between character stats and statistics
> - Multi level folding
>
> With these changes, lets have different windows for each of Professions, Skills, Stats, Currencies, Reputations,
> Statistics
> - Each should have different display brokers
>
> [Image #152: Skill Master's window, headers "Primary Professions", "Secondary Skills", "Weapon Skills" with fold
> chevrons] In the LDB tooltip, clicking on a category's expand/collapse button does nothing - allow only this interaction

## The owner's answers

| Question | Answer |
|---|---|
| Pins with six brokers | **Per broker**: each broker shows its own window's pins, up to 5. A row's menu toggles "Pin to the <window> broker", and pinning never removes another pin |
| Does a tooltip fold also fold the window? | **Tooltip-only**: the tooltip keeps its own fold state |
| "Allow only this interaction": what about row hover? | **Keep hover info**: rows can't be clicked, but hover still shows the row's details and highlight; the fold chevron is the only thing that can be clicked |
| Gold as a currency row | **Not shown**: the Currencies window shows only the client's currencies |

## What the recon found

Recon `wf_29cd618e-8fa`, read-only. The full findings, with file:line evidence, are summarised here.

- **One window, two feeds.** Today one window (`modules/MainWindow.lua`, a file-scope singleton) holds eight static blocks:
  - four skill blocks: Primary Professions, Secondary Skills, Weapon Skills, Other;
  - four stat blocks: Base & Combat, Spell & Regen, Defense & Resists, Utility.

  There are two LDB feeds, "Skill Master" (skills) and "Skill Master Stats", with one pinned skill (`char.pinned`) and one
  pinned stat (`char.pinnedStat`). The skills/stats split runs through Blocks, Rows, Interact, RowTooltip, SecureOverlay,
  Preview and the Simulator.
- **The six families.** Forever's character panel has six tabs: Character, Reputation, Skills, PVP, Currency and Statistics.
  - "Statistics" is the sixth tab: achievement-style counters such as Times camped, nested as Character > Wealth.
  - "Stats" is the paper-doll panel, which `StatData` already reads.
- **The client's APIs.** Blizzard's Forever UI source confirms the APIs, and the bare legacy globals are absent:
  - **Reputations:** `C_Reputation.GetNumFactions`, `GetFactionDataByIndex` (one FactionData table: `isHeader`, `isChild`,
    `isHeaderWithRep`, `isCollapsed`, `reaction`, the thresholds and `currentStanding`), `GetFactionDataByID`, and
    `Expand`/`CollapseFactionHeader`.
  - **Currencies:** `C_CurrencyInfo.GetCurrencyListSize`, `GetCurrencyListInfo` (`currencyListDepth`, `quantity`,
    `maxQuantity`, the weekly fields), `ExpandCurrencyList` and `GetCurrencyInfo(id)`.
  - **Statistics:** `GetStatisticsCategoryList`, `GetCategoryInfo` (the parent, with -1 for a root),
    `GetCategoryNumAchievements`, `GetAchievementInfo`, and `GetStatistic(categoryID, index)`, which answers
    `quantity, skip, statID`. This is Forever's form and differs from Retail's.
  - **Events:** `UPDATE_FACTION`, `CURRENCY_DISPLAY_UPDATE` and `CRITERIA_UPDATE`, which is noisy and has no payload.
- **The collapse trap.** Reputation and currency headers are client state shared with Blizzard's panel, and the index API
  lists only expanded rows. The reader therefore expands, reads and restores, as `SkillData` already does for skills. It does
  this on the first build only, out of combat and never while the panel is shown, with a re-entry latch. Later refreshes go
  by id (`GetFactionDataByID`, `GetCurrencyInfo`), which touches no state. Statistics has no such trap.
- **The tooltip bug.** The window-style broker tooltip makes every header inert on purpose (`stillHeader()` disables the
  mouse on the header and on its chevron), and nothing redraws the tooltip after a fold. The Classic style has no chevrons.
- **File sizes.** These files are near the 1500-line cap: Journal.lua 1215, Broker.lua 1051, Blocks.lua 848, Groups.lua
  839, MainWindow.lua 797 and locales/enUS.lua 952. New code goes in new files.
- **LibKa0s.** It has no tree or fold list and no LDB feed helper, so both are built here. Skill Master vendors v1.114.0.

## Design

### Families and windows

- **A registry.** A family registry, `NS.Families`, lists six families. Each entry carries its title, its block ids, its data
  provider (a model getter plus its bus message), its row kind, its feed spec and its window defaults.

  | Family | Window title | Blocks |
  |---|---|---|
  | `professions` | Skill Master · Professions | primary, secondary |
  | `skills` | Skill Master · Skills | weapon, other |
  | `stats` | Skill Master · Character Stats | the four stat blocks, without the "Stats ·" prefix in their own window |
  | `currencies` | Skill Master · Currencies | one tree block |
  | `reputations` | Skill Master · Reputations | one tree block |
  | `statistics` | Skill Master · Statistics | one tree block |

- **A window factory.** `MainWindow` becomes a factory (`modules/Window.lua`) instantiated per family. Each instance has its
  own frame, pools, position, size, columns, strata and shown state under `profile.windows.<family>`. `NS.MainWindow`
  stays as a thin shim over the Professions window, so existing callers, the `SkillMasterToggleWindow` binding and
  `/sm show|hide|toggle` keep working. Every family gets:
  - a slash verb (`/sm professions|skills|stats|currencies|reputations|statistics`);
  - a key binding button;
  - a launcher menu entry.

  The binding names are permanent once shipped.
- **What stays common.** Detached and merged block windows stay family-agnostic, so blocks of different families may share
  a merged window as today. The Journal stays one shared window, reached from each family window's journal mark.
- **Migration, schema 14.** `profile.window.point` and `layout.width`, `maxHeight`, `fitHeight`, `columns`, `summary` and
  `strata` move to `windows.professions`. The other windows start next to it, stacked down and to the right, the first
  time.

### Tree blocks and folding

- **One renderer.** A tree row model (`modules/Tree.lua`) serves Reputations, Currencies and Statistics. Entries carry
  `{depth, header, nodeKey}`:
  - a header row is a chevron plus the title, indented by depth;
  - a leaf row is a bar or a value;
  - the children of a folded node are skipped.
- **Folds are the addon's own.** The fold state is addon-side, under `char.fold[family][nodeKey]`. It never calls the
  client's Expand or Collapse functions. The keys are:
  - reputations: the header's factionID;
  - currencies: the header name plus its depth;
  - statistics: the categoryID.
- **Default folds.** Every Statistics category starts folded. Reputation and currency headers start open.

### Reputations (#6)

- **`RepData`** (a sibling of `SkillData` and `StatData`) reads the faction list into `header > sub-header > faction`, keyed
  by factionID. It announces `REPS_UPDATED`, and its update is coalesced on `UPDATE_FACTION`.
- **The structure is the panel's own:**
  - top headers such as Alliance and Other;
  - sub-headers such as Steamwheedle Cartel, with their own bar when `isHeaderWithRep`;
  - an Inactive header when the client lists one.
- **The bar** runs from the current threshold to the next, filled by `currentStanding`. It is labelled with the client's
  `FACTION_STANDING_LABELn` (the standing name) and "current / next", and colored by `FACTION_BAR_COLORS[reaction]`.
  Exalted is shown full. Friendship and major-faction bars use their own maths if the probe shows that Forever lists them.
- **Session gains** come from comparing `currentStanding` between reads, for the Journal log. The Alts tab gets a
  Reputations sub-tab with standings.

### Currencies (#7)

- **`CurrencyData`** reads the client's currency list (headers by `currencyListDepth`) and announces `CURRENCIES_UPDATED` on
  `CURRENCY_DISPLAY_UPDATE`. A nil type means a full re-read; an id means that one id.
- **The rows.** A currency with a cap gets a bar (`quantity / maxQuantity`); one without is a plain value row. The tooltip
  gives the amount, the cap, the weekly earned out of the weekly cap when `canEarnPerWeek`, and the description.
- **No gold** (the owner's ruling). An empty list shows an empty state.
- **Journal and Alts.** Session gains come from `quantityChange` for the Journal. The Alts tab gets a Currencies sub-tab.
- **Optional alert.** A "currency at cap" alert is off by default.

### Statistics (new)

- **`StatisticsData`** builds the category tree once, on first use, with one `GetCategoryInfo` per category. It reads a
  category's rows only when that category is unfolded, in the window or the tooltip:
  - each row is `GetStatistic(categoryID, i)`, then `GetAchievementInfo(statID)` for the name;
  - a row with `skip` or no statID is skipped;
  - the value shows as Blizzard shows it: the number, or "--";
  - a string quantity is kept verbatim;
  - names are cached for the session.
- **`CRITERIA_UPDATE`** is registered only while the Statistics window or its tooltip is shown, or while a statistic is
  pinned. It is debounced to one re-read per second of the unfolded categories and the pinned rows (a one-shot timer started
  by the event, not a poll).
- **No Alts tab** for Statistics.
- **Naming.** The UI copy calls it "Statistics (the character panel's Statistics tab)" and never "stats". Character stats
  are "Character Stats".

### Brokers and pins (#11)

- **Six LDB data objects** are built from the registry. "Skill Master" keeps its LDB name for Professions, so existing display
  placements stay, and "Skill Master Stats" keeps its name for Character Stats, relabelled. The new ones are "Skill Master
  Skills", "Skill Master Currencies", "Skill Master Reputations" and "Skill Master Statistics".
- **Clicks on the feed cell:** left toggles that family's window, right opens the Broker settings page.
- **Each feed** has a template (`broker.feeds.<family>.template`) and its own tooltip sections, which are its family's blocks.
- **Pins per broker** (the owner's ruling): `char.pins[family]` is an ordered list of up to 5.
  - A row's menu toggles "Pin to the <window> broker", and pinning never removes another pin.
  - `{pinned}` renders every pin joined by " · ", and `{pinned1}` to `{pinned5}` render one each.
  - The tooltip lists the feed's pins first.
  - The Broker settings page has a reorder and remove list per feed.
  - A stored `char.pinned` or `char.pinnedStat` becomes a one-item list in its family, normalised when read, because
    character scope has no schema steps.
- **Default templates:** Professions keeps `{pinned} · +{gains}`, Character Stats `{pinned}`, and the others `{pinned}`
  falling back to the family title.

### The LDB tooltip: only the fold works

- **Folding.** Each category header's chevron folds and unfolds that category in the tooltip only (`tooltips.ldb.folds`,
  the owner's ruling), and the tooltip redraws in place, keeping its scroll position. Both tooltip styles get the chevrons;
  the Classic style gains them.
- **Rows can't be clicked:** no open, no shift-link, no right-click menu, no secure overlay armed, no Classic hit buttons.
  Hover still shows the row's tooltip and highlight (the owner's ruling).
- **Retired.** The test strip's right-click is removed from the tooltip. `tooltips.ldb.openFrom` is retired by a schema step,
  and the footer says "Click a chevron to fold". The feed cell's own clicks stay, because they belong to the display, not
  the tooltip.

### The probe and the client notes

`/sm probe` gains `factions`, `currencies` and `statistics` sections:
- the API presence rows;
- the first 60 faction rows;
- the whole currency list;
- the category tree with 3 rows per category;
- a check that `GetFactionDataByID` answers for a child of a collapsed header.

The data modules are built on the Blizzard-source shapes behind presence tests; the owner's smoke run of the probe confirms
them. The results go in `docs/forever-quirks.md`.

### Test mode, preview and the simulator

The sample character gets believable reputations (with panel-style headers), currencies and a Statistics tree. The simulator
can raise a reputation and a currency.

## Calls made without asking

- **The split:** Professions holds Primary and Secondary; Skills holds Weapon and Other.
- **Names:** "Character Stats" and "Statistics", in the owner's words.
- **Broker names:** "Skill Master" stays the Professions broker's LDB name.
- **Reputations** are one tree block per window, not a detachable block per header.
- **Folds:** Statistics categories start folded; reputation and currency headers start open.
- **Journal and Alts:** currencies and reputations join them, as #7 asks; Statistics doesn't.
- **A statistic can be pinned**, with the debounced refresh.
- **The build follows Blizzard's Forever source**, and the probe is a smoke step rather than a gate before design.
- **LibKa0s v1.117.0** is re-vendored first. v1.118.0 is in flight on another branch.
- **Window positions:** the old window becomes Professions, and the new windows are placed next to it, stacked.

## Out of scope

Gold (the owner's ruling). A LibKa0s tree widget (it may be peeled later). Version bumps.
