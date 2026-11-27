# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_loadorder.lua (6)

- loadorder: the runner loads exactly the TOC's files and the library XML's files
- loadorder: FONT_MONO resolved from the Media seam, not the fallback (MediaSetup before Constants)
- loadorder: NS.Print is reclaimed from AceConsole and is the same object as NS.Util.print
- toc: the Forever-only shape (clients-§9): one 16001 number and both gating lines, in order
- clients-§9: no Retail branch, no client read and no retail declaration in the addon's source
- loadorder: the one MakeCloseButton wrapper is the only caller of the library factory

### test_schema.lua (6)

- schema: every row resolves against the defaults tree
- schema: every row carries a group, a label and a desc (options-ui-§13)
- schema: the Master controls come first, General visibility omitted, Test mode present
- schema: a write through the seam lands in the profile and reaches its reaction
- schema: the minimap row says SHOWN while LibDBIcon's stored key says hidden (launcher-§3)
- schema: the reset-all veto keeps the minimap row and every profile row out of the walk

### test_options.lua (16)

- test_options_every_bar_style_key_has_row
- options: every display default outside bars and layout has a row too
- options: the pages register in the mockup's order, General first and Profiles last
- options: a look row applies live through LAYOUT_CHANGED and reaches the window's bars
- options: a reset of a whole page sends one LAYOUT_CHANGED, not one per row
- options: a hidden skill has a row that un-hides it
- options: the per-block rows go through NS.Blocks (detach, dock, collapse, order)
- options: a hidden block leaves the window and the detached frames
- options: the waypoint method preference decides the provider
- options: an unverified trainer's directions carry no mark (the owner, 2026-11-25)
- options: the bar text template and the timer and marker switches reach the bar
- options: the flat color mode draws the Bar color, or the skin's while its companion is on
- options: the Bars page has no preview bar (owner feedback round 4)
- options: every new page renders on its first show without raising
- options: the journal's length is honored
- options: the library-absent load keeps every hand-written row; the composers' rows are the gap

### test_template_rows.lua (9)

- templates: no string row in the whole schema renders as an empty dropdown
- templates: the Broker page renders with no empty-dropdown line, one dropdown per feed (SMW-05)
- templates: every template row's default is one of its presets
- templates: picking a preset writes its template
- templates: Custom keeps the text, and the box edits it
- templates: a stored string matching no preset reads as Custom, its text in the box
- templates: choosing Custom in the dropdown reveals the box; a preset hides it again
- templates: the page's Defaults lets go of Custom and restores the shipped template
- templates: the bar text's presets are named by what they draw for 107 +25 / 150

### test_row_display.lua (8)

- rows show: one setting on the Bars page's Text tab, and stats.display is gone
- rows show: Bar and value draws a skill row's bar and its text, and a stat row's
- rows show: Bar only draws the bar with no text, for skills and stats
- rows show: Value only draws the value in the bar's place, for skills and stats
- rows show: an unlearned skill keeps its trainer line in every mode
- rows show: the broker tooltip's skill and stat lines honor it
- rows show: schemaVersion 2 moves a stored stats.display once, in every stored profile
- rows show: schemaVersion 2 moves the active profile's stats.display past the copied default

### test_database.lua (3)

- database: the defaults stamp 0 and the runner raises it to the code's target
- database: the runner is idempotent
- database: a fresh profile wears the library's per-client default skin (skinning-§2)

### test_bus.lua (3)

- bus: the six messages are declared once, PascalCase on the wire
- bus: the catalog is strict, so a misspelled constant raises instead of going silent
- bus: a subscriber on its own target receives a published message

### test_slash.lua (6)

- slash: every entry is a positional triple
- slash: the reserved verbs are all present, `skin` directly after `config`
- slash: /cl lock and /cl unlock write `locked` through the seam and echo it
- slash: /cl test flips test mode, and again turns it off
- slash: the stub's one library string is pinned to the live major
- slash: on a library-absent load, /cl enable still lands through writeThrough

### test_mainwindow.lua (9)

- window: Toggle shows it, and again hides it
- window: the chrome is the shared one: the title, the wrapped close control, MEDIUM strata
- window: test mode shows the localized strip, and turning it off hides it
- window: combat ends test mode (preview-mode)
- window: locked refuses the drag; unlocked drags and saves the drop point
- window: a grip drag reflows the columns at most once per frame and redraws once, after the release
- window: the grip's bounds are Window width's and Window height's range, per column count
- window: Locked hides the grip and refuses a grab; /cl unlock and the lock mark bring it back
- broker: the LDB tooltip has no resize grip

### test_launcher.lua (4)

- launcher: the object is the brand, the 128 px logo, registered once OnEnable runs
- launcher: left-click opens the settings panel through the same opener as /cl config
- launcher: the menu carries a Journal checkbox after Show window and before Open settings
- launcher: the Journal entry's tick is the Journal's state and its click the journal verb's

### test_keybinds.lua (4)

- keybinds: Bindings.xml is seven CLICK lines in this addon's category, no header, no default
- keybinds: the bound button runs the window's one toggle handler
- keybinds: the Journal button runs the Journal's one toggle handler
- keybinds: a Journal press while stood down refuses on the toggle verb's line

### test_locale.lua (8)

- locale: the enUS files are the TOC's, the base first, before every other locale
- locale: NS.L answers the key on a miss, and every entry answers a string, never `true`
- locale: every routed literal has an enUS entry
- locale: every enUS key is read by the addon's own files (localization-§3, no dead key)
- locale: no key is written twice in the enUS files
- locale: the lexer is falsifiable, a routed literal and a dead key are both seen
- locale: each stub is gated on its own locale, silent elsewhere, and a subset of enUS
- locale: the stub gate is falsifiable, an ungated chunk writes on every client

### test_skinsetup.lua (5)

- skin: this addon is a registered owner wearing its stored choice
- skin: writing the skin row applies it through the owner
- skin: the picker's preview is the test mode (skinning-§10)
- skin: /cl skin opens the library's picker
- skin: Ignore settings panel defaults to on, Ignore fonts to off (skinning-§3)

### test_perf.lua (2)

- perf: windowRender is noted while a capture is on, and nothing is noted while off
- perf: every event-path bucket (detachedRender, skillScan, statScan, bonusRefresh) is reached

### test_probe.lua (10)

- probe: Run() answers the report's six keys
- probe: skillLines holds the raw returns of every line, the collapsed ones included
- probe: headers lists the localized header names
- probe: apis maps every probed name to a boolean
- probe: enchant carries the weapon enchant returns (a lure's time left)
- probe: /cl probe writes the JSON report to the debug console with one chat pointer
- probe: library-absent, /cl probe refuses in chat on one line
- probe: C_SkillInfo and C_Item are read first, a table-shaped line kept whole
- probe: a slot-taking C_Item.GetWeaponEnchantInfo does not error, and each try is recorded
- compat: WeaponEnchantInfo passes a slot and normalizes Forever's table to the 1.12 shape

### test_probe_sections.lua (11)

- probe sections: the report carries factions, currencies and statistics
- probe sections: the new API presence rows are reported, the absent legacy globals false
- probe sections: factions lists every row with collapsed headers opened, then restores them
- probe sections: at most 60 faction rows are written
- probe sections: GetFactionDataByID is asked for a child of a collapsed header
- probe sections: never expands while the Reputation panel is shown or in combat
- probe sections: currencies lists the whole list, opened and restored, with a by-id read
- probe sections: never opens the currency list while the Currency tab is shown
- probe sections: an absent API answers its section's source as none, never raises
- probe sections: statistics is the category tree with up to 3 raw rows each
- probe sections: statistics records whether the Retail form GetStatistic(statID) answers, under pcall

### test_skilldata.lua (27)

- skillcatalog: every vanilla profession, the 16 weapon lines, Defense, Lockpicking and Riding
- skillcatalog: kinds, tiers and the window each row opens
- skillcatalog: the localized-name map answers each enUS name and the racial riding names
- skillcatalog: both data tables record a source and are verified against Forever's DB2 (GitHub issue #10)
- classweapons: Forever's own additions over 1.12, Rogue Axes and Druid Polearms (#10, DB2)
- classweapons: every class lists only catalog keys
- compat: SkillLineInfo normalizes the table shape
- compat: SkillLineInfo normalizes the multi shape
- compat: SkillLineInfo normalizes the global shape
- compat: no skill-list API at all answers 0 lines and nil, never an error
- skilldata: classifies categories (Leatherworking, Fishing + lure, Guns + racial, Defense)
- skilldata: armor, languages and class spell lines are left out (design §3)
- skilldata: an empty or half-loaded list gives empty-state rows and no error
- skilldata: the model exists before the first scan, empty
- skilldata: collapsed headers are expanded for the scan and restored after it
- skilldata: an unknown (localized) name lands in Other, never an error
- skilldata: a rank rising 80 -> 81 sends SKILL_UP("bows", 80, 81) once
- skilldata: the first scan sends no SKILL_UP
- skilldata: unlearned weapon and riding rows are synthesized for a Dwarf Hunter
- skilldata: the 1.12 global shape scans the same model
- skilldata: the three events are debounced into one scan 0.1 s later
- skilldata: PLAYER_LEVEL_UP lifts the weapon cap to 5 x the new level before the list catches up
- skilldata: the scan's own header toggles do not schedule another scan
- skilldata: two racial riding lines are one Riding row at the higher rank
- compat: the 1.12 positional reader asks the client once per line
- skills: WoW Forever's struct reads its real ranks, and a profession's child line is one row
- skills: a child line with an unknown name still maps through its parent skill-line ID

### test_trainers.lua (36)

- test_trainers_fist_alliance: Alliance fist weapons are taught in Ironforge and Darnassus
- test_trainers_fist_alliance: the home city of the player's race sorts first
- trainers: Horde fist weapons come from Sayoc in Orgrimmar only
- trainers: For reads the player's faction and race when none is passed
- trainers: Neutral trainers are on both factions' lists
- trainers: an unknown key answers an empty list, never an error
- trainers: every record names its source, its side and what it teaches, under a unique id
- test_trainers_next_rank_at_cap: Leatherworking 150/150 at level 22 trains Expert
- trainers: NextRank answers nil at Artisan and for a skill with no ranks
- trainers: NextRank's skill gate (Journeyman wants 50)
- test_trainers_riding_level_gate: riding 75 opens at 40, 150 at 60
- test_trainers_riding_level_gate: the race's own riding trainer sorts first
- trainer probe fix: Woo Ping stands in Forever's re-bounded Stormwind frame, not the Era one
- trainer probe fix: Undercity's Journeyman Alchemy trainer is Doctor Martin Felben (npc 11044)
- trainer probe fix: Gorina, a Mining Supplier, is no Mining trainer; Makaru still trains Orgrimmar
- trainer probe fix: no two NPCs share one shipped point (Bixi and Buliwyf, Sayoc and Hanashi)
- trainer probe: every record carries its NPC id, once, and a point inside the map or none
- trainer probe: a rank learned from a book or a quest names it (the owner's books comment on #3)
- trainer provenance: every record carries the probe's confirmation or an explicit unverified reason
- trainer provenance: a confirmed record still holds the values the probe confirmed
- trainer provenance: every trainer is verified, by the probe or by the seeds evidence (GitHub issue #10)
- trainer provenance: no trainer is shown as unverified (the owner, 2026-11-25)
- trainer probe books: a card for a book vendor or a rank quest's giver says how the rank is learned (#3)
- round2 artisan: Alliance Artisan Leatherworking is Drakk Stonehand in the Hinterlands, not Telonis
- round2 artisan: no capital trainer trains a craft to Artisan; each side has a Master who does
- round2 artisan: the capitals' Artisan-titled trainers train Expert (225)
- round2 note: Artisan Cooking at 225 says no trainer teaches it and names Clamlette Surprise and Dirge
- round2 note: a book rank and a quest rank say so; a trained rank has no note
- round2 show all: AllRanks lists every rank, Artisan first, each trainer once under its highest
- round2 show all: the popup's check box lists every rank and marks the next rank's trainers
- round2 show all: quest givers sit in their rank's group, an unlearned skill marks Apprentice
- round2 forever-only: the 55 ship, each verified by the seeds evidence, with the probe's hold, an npcID and a point
- round2 forever-only: Zephras Isle and Riverglades trainers serve both factions (the owner's ruling)
- round2 forever-only: a Junior trainer trains Apprentice only; riding's Forever instructors join
- source ranks: a capital's titled craft trainer trains one rank below its title (Wowhead: Fimble Finespindle)
- source ranks: every profession's every rank has a teacher for each faction

### test_trainer_probe.lua (18)

- trainer probe: a misspelled name finds no NPC and names the near miss
- trainer probe: a record's npcID must carry its name
- trainer probe: the side must serve the record's faction (Neutral wants both)
- trainer probe: a vendor stored as a trainer fails the role check (Gorina)
- trainer probe: a title's rank must be the record's top rank (one below the title, the owner's ruling)
- trainer probe: a book vendor passes when it sells the book that trains the record's rank
- trainer probe: a rank quest's giver passes when it starts that quest
- trainer probe: a point in the Era frame fails the place check and the patch has Forever's (Woo Ping)
- trainer probe: a record with no point gets the one standing point; spread spawns and instances give none
- trainer probe: two NPCs on one point are both flagged (Bixi and Buliwyf)
- trainer probe: the SQL tuple reader keeps quotes, escapes, NULL and numbers
- trainer probe: the sandbox gives a source no library
- trainer probe: the provenance file loads and holds each record's confirmation or reason
- trainer probe: the JSON writer escapes and sorts
- trainer probe: the command line wants the QuestieDB path and reads the options
- trainer probe: an Artisan title trains to 225 and a Master title to 300 (round 2)
- trainer probe: a Junior title trains Apprentice and a plain craft title Journeyman (round 2)
- trainer probe: a held record is never confirmed, and its reason is the hold

### test_helpers.lua (8)

- test_helpers_skinnable_level: 122 -> 24, 100 -> 20, 50 -> 15, 1 -> 10
- test_helpers_fishing_need_unknown_nil: a zone the table lacks answers nil
- helpers: FishingNeed answers the getaway-free skill for a known zone
- helpers: FishingNeed prefers the uiMapID over the name
- helpers: Nodes lists what the rank can gather and the next node up
- helpers: Nodes at the top has no next node, and an unknown key answers nil
- helpers: WeaponCap is five per level
- helpers: FishingNeedHere reads the map ID first, then the zone text

### test_bonuses.lua (16)

- bonuses: lure on the pole is one temp enchant source with its expiry
- bonuses: a Dwarf's Guns +5 is one permanent racial source (the mechanism; Forever ships none)
- bonuses: modifier 12 with 7 attributed leaves one Other 5
- bonuses: no modifier, no sources
- bonuses: an unknown or unlearned skill answers an empty breakdown
- bonuses: the '+N <Skill>' item pattern, case-insensitive, other stats ignored
- bonuses: a skill buff is a temp source with its aura's expiry
- bonuses: more attributed than the modifier shows a negative Other, never a silent mismatch
- bonuses: the 1.12 globals and a scanning tooltip are the fallback readers
- bonuses: inventory change publishes BONUSES_UPDATED; the 1 s ticker runs only while a temp bonus lives
- racials: WoW Forever has none, verified against its DB2 (GitHub issue #10)
- racials: every racial skill key is a catalog key
- bonuses: UNIT_AURA re-reads the buffs only, never the equipped tooltips
- bonuses: a temp '+N' line that names no skill starts no ticker
- bonuses: a blocked aura read never raises and keeps the last buffs read in full
- bonuses: an aura with a secret field is treated as a blocked read

### test_statdata.lua (17)

- statdata (primary_vs_highest): the primaries scale against the highest, Agi 112 -> 100%, Str 48 -> 42.9%
- statdata: attack power is base plus buffs against 400, crit against 30%
- statdata: a hit chance adds the combat rating bonus, as Forever's paper doll does (#10)
- statdata (hit_markers): hit scales to 9% with markers at 5% and 9%, spell hit to 17% (Forever's table, #10)
- statdata (armor_mitigation): 1104 armor at level 22 -> 1104/(1104+400+1870) = 32.7%, against 75%
- statdata (missing_api_omitted): a stat the client cannot give is left out, never faked
- statdata (resist_ref_at_60): resists scale to 5 x (level + 3) = 315 at 60, with the cap marker
- statdata: defense scales to 5 x level, and the 440 marker shows only at 60
- statdata: speed is yards per second over 7, against 200% with the 100% marker
- statdata: durability is the lowest equipped slot, with the 20% repair marker
- statdata: every def declares a known group, an api, a ref and a source record
- statdata: Model() and Get(key) answer the last scan
- statdata: a burst of stat events sends STATS_UPDATED once, after the 0.2 s throttle
- statdata: another unit's event schedules nothing
- statdata: the speed ticker runs only while a speed display asks for it
- stats: a secret read never raises and keeps the stat's last plain value, marked stale
- stats: leaving combat asks for a rescan (PLAYER_REGEN_ENABLED)

### test_bar.lua (14)

- bar: a bonus past the cap clamps the base, draws to the end and keeps the full text (Review Focus 4)
- bar: the bonus segment wears the temp or the permanent color
- bar: an empty cap (an unlearned skill) draws nothing and raises nothing
- bar: Rank tier colors draw a tiered bar to its last tier, its fill one segment per tier entered
- bar: markers keep the end and drop what is past it
- bar: the timer formats m:ss and h:mm:ss
- bar: SetTimer shows the time left, ticks it, and SetTimer(nil) disarms the OnUpdate
- bar: a timer that runs out clears itself
- bar: the resolved style reads the profile and the skin's tokens
- bar: the pool hands bars back in order and clears their timers on release
- bar: a secret width (a tooltip-anchored bar, tainted) lays out on the last plain width
- bar: the bars are LibKa0s-Widgets-1.0's Bar, owned by this addon's skin
- bar: the bonus slots are remapped onto cl.bonusTemp and cl.bonusPerm
- bar: a bar paints the owner tokens it painted before the swap

### test_bars_live.lua (18)

- bars live: the bar height reaches the window's rows and the detached blocks
- bars live: the row height reaches every window row
- bars live: the tooltip and mini heights reach the row tooltip and the broker tooltip
- bars live: fill direction anchors the fill on the right edge, and back
- bars live: bar opacity scales the drawn fill's alpha
- bars live: the bar texture draws once its skin companion is off, and the skin's again once on
- bars live: the flat Bar color draws once Color mode is Flat and its companion is off
- bars live: the row tooltip's bar wears the row's own fill, so Color mode and the palette reach it
- bars live: the background color draws once its companion is off
- bars live: turning the border off hides the drawn edges, and on shows them again
- bars live: the bar text template and position reach the drawn text
- bars live: the font color and size draw once their companions are off
- bars live: Rank tier colors split the fill by tier on a scale to 300, and off restores it
- bars live: Rank tier colors works only under Color mode By category
- bars live: threshold markers hide on a stat's bar and come back
- bars live: the expiry timer hides at once and comes back
- bars live: the spark is off by default, shows when on and hides when off
- bars live: every Bars page slider commits while it moves, so a mouse wheel turn is written

### test_bars_round2.lua (8)

- tooltip bar: every region it draws is painted and inside the bar at heights 4 to 20
- tooltip bar: hidden once GameTooltip is cleared for another owner, never carried into the broker tooltip
- tooltip bar: a row tooltip with no bar line leaves no bar from the last one
- bar border: off by default in the profile and on its schema row
- bar border: off under the default skin's None; a real skin style wins only while its companion is on
- trainer popup: the trainer's name wears the skin's accent by default, apart from the other text
- trainer popup: the name's swatch draws once Use the skin's color is off, the class color through its companion
- trainer popup: a changed name color reaches an open popup at once

### test_class_first.lua (5)

- FB-SM-02 bars: the flat fill, background, border and text draw the class color while the skin's is followed too
- FB-SM-02 bars: with the class off the skin's color still wins over the swatch
- FB-SM-02 detached windows: the background and the border draw the class color while the skin's is followed too
- FB-SM-02 icons: the border draws the class color while the skin's icon border is followed too
- FB-SM-02 trainer popup: the trainer's name draws the class color while the skin's accent is followed too

### test_trainers_tabs.lua (2)

- FB-SM-06 the Trainers and Waypoints page: two tabs, Trainers then Waypoints
- FB-SM-06 each row on its tab

### test_detached_width.lua (6)

- FB-SM-04 the width row: Layout > Blocks, beside Block scale, 200 to 600 in steps of 10, 280 by default
- FB-SM-04 a detached window takes its block's width
- FB-SM-04 the grip: shown, its bounds the row's range at the content's height
- FB-SM-04 the grip: a drag writes the width on its step grid and keeps the drop point
- FB-SM-04 Locked hides the grip and refuses a grab, the global lock and the block's own
- FB-SM-04 a merged window's columns take its widest member's width

### test_bars_sizes.lua (8)

- bar sizes: each tooltip's heights sit in its own group on the Tooltips page, no detached height
- bar sizes: a detached block's bar and row take the main window's bar and row heights
- bar sizes: LDB tooltip row height sizes every skill or stat line, and a release hands them back
- bar sizes: Main window tooltip row height sizes the bar's line, and a clear hands it back
- bar sizes: schemaVersion 4 drops a stored bars.compactHeight and keeps the rest
- bar sizes: Use the skin's border is off by default, so a skin's real style never beats Show border off
- tooltips: a font size reaches a tooltip's lines and goes back to each line's own font
- tooltips: the row tooltip's bar takes Tooltips > Bar width; the LDB tooltip widens for its own

### test_round2_layout.lua (7)

- round2 layout: the window is wide enough for its body and the scroll bar's whole gutter
- round3 marks: every row carries the one action mark (ph:sign-in), a stat row too (round 4)
- round2 layout: a detached block's body starts under the skin's band, its rows padded above and below
- round2 layout: Spark is off by default, the tier ticks are gone, Rank tier colors is a Marks row
- round2 layout: Layout > Block order draws one boxed row per block in order, its eye showing or hiding it
- round4 restore: a block hiding rows shows an eye mark that brings them back; none otherwise
- round4 restore: a stat block's mark brings back its own stats

### test_round2_icons.lua (10)

- round2 icons: a tier's shade is the category color darkened, the first tier the color itself
- round2 icons: a row's mark stands in the header's column, the bar one inset short of it
- round2 icons: the bar's timer sits inside its far end, and the near end when the text sits right
- round2 icons: the Icons tab's rows, their defaults the old fixed look
- round2 icons: size, zoom, border and its color reach the drawn icon; off hides it
- round2 icons: the LDB tooltip draws the window's block titles on header bands and stripes every other row
- round2 icons: a skill's name in the LDB tooltip is white, a weapon below its cap included
- round2 icons: Pin to the Professions broker redraws the feed at once
- round2 header: the detach mark wears the marks' rest color at rest and the hot color under the pointer
- round2 hammer: the action mark lights up while the pointer is on it, as the detach mark does

### test_round3.lua (10)

- round3 sort: Value orders a block high first, not-learned rows last; Default is the catalog's
- round3 sort: the header's sort mark picks Default, Value high, Value low, Progress (its menu, round 6), and the window redraws
- round3 sort: the LDB tooltip lists a section in its block's order
- round3 alerts: skip untrained by default; equipped only; every weapon; a muted weapon never
- round3 window: collapsing every block keeps the window's height; Shrink to fit lets it shrink
- round3 broker: a second Pin on the pinned skill unpins it, and the feed reads Professions
- round3 broker: a tooltip row opens no menu; the tooltip's own Hide set still leaves it out of the tooltip only
- round3 broker: the bars stop at the widest value, never past the old fixed column
- round3 click: a weapon row opens the Skills tab with its line selected
- round3 click: Compat.OpenTradeSkill answers false without the call, and the call's own answer with it

### test_round5.lua (11)

- round5 detached mark: a detached row's action mark snaps to the pixel grid, as the main window's
- round5 detached mark: the mark sits a whole unit down its row at any row height
- round5 detached mark: every chrome mark snaps its art (the band's controls too)
- round5 table headers: the Log and Alts headers stand on a band of the block header's color with a rule
- round5 table headers: a look change repaints both bands (the Journal re-renders on LAYOUT_CHANGED)
- round5 journal lock: the title bar's lock mark beside the close control toggles the one locked setting
- round5 journal lock: a profile switch repaints the Journal's mark from the new profile
- round5 journal lock: /cl lock and /cl unlock repaint the Journal's mark
- round5 test mode: /cl test shows the main window, the Journal and one sticky toast of each kind
- round5 test mode: ending it takes the toasts down and puts the windows back as they were
- round5 test mode: combat ends it and its toasts with it; nothing live is written

### test_round5_style.lua (9)

- round5 detached style: every row is on the Layout page's Detached windows tab, the strata row moved there
- round5 detached style: the companions start on the skin, in the composer and in the defaults
- round5 detached style: Window scale multiplies the block's own scale
- round5 detached style: Window opacity reaches the open window
- round5 detached style: the background follows the skin until its companion is off, then the swatch
- round5 detached style: the border is the skin's, the window's own, or none
- round5 detached style: Title band Never hides the band and keeps a drag strip
- round5 detached style: Title band On hover shows the band while the pointer is over the window
- round5 detached style: a skin switch keeps the style

### test_round5_groups.lua (28)

- round5 groups model: two lone windows merged on a side make a group, left and right as columns
- round5 groups model: top and bottom stack into the target's column
- round5 groups model: a dragged group merges whole, its columns kept beside, stacked above or below
- round5 groups model: a window is never merged into itself, and an unknown side is refused
- round5 groups model: a section moves within its own group, and a split group of one dissolves
- round5 groups model: Normalize drops refused, repeated and malformed members, empty columns and groups
- round5 groups: a merge draws one window, the sections' own frames hidden, the title their short names
- round5 groups: left and right merges make columns, each the detached width, the header spanning them
- round5 groups: each sub-header carries a chevron, the title, the sort mark and the split mark
- round5 groups: the split mark pops the section out beside the group, and a group of one dissolves
- round5 groups: a split at a drop point lands there; a three-section group stays a group
- round5 groups: the menu splits, unmerges and docks, from a sub-header or the band
- round5 groups: a right-click on a sub-header or the band opens the menu
- round5 groups: a block docked by any path leaves its group
- round5 groups: Collapse all collapses every section, then expands them; Dock all docks every one
- round5 groups: a merge, a split and an unmerge in combat wait for its end
- round5 groups: a hovered crafting row in a merged window gets its overlay, over the merged window
- round5 groups: the merged window takes the Detached windows style
- round5 groups: the band drags the window and its drop is the group's point; locked, it stays
- round5 groups: a merge on the left keeps the target where it stood
- round5 groups: a window dropped on a group's top raises the group by the dropped section, not the group
- round5 groups: a section dragged onto a window's top raises the new group by that section
- round5 groups: two merges dropped in one combat both happen when it ends
- round5 groups style: the merged window's background and border follow the Detached windows tab
- round5 groups style: Title band Never hides the merged band and keeps a drag strip
- round5 groups style: Title band On hover shows the merged band while the pointer is over it
- round5 groups: schemaVersion 6 normalizes a stored layout.groups and drops a malformed one
- round5 groups: the diagnostics' layout section names each group and each block's

### test_round5_snap.lua (19)

- round5 snap: each of the four sides is found where the dragged window's facing edge meets it
- round5 snap: the radius is SNAP_RADIUS, inclusive; one unit past it is no candidate
- round5 snap: a side needs the two windows to overlap along the other axis
- round5 snap: the nearest candidate wins, across targets and across one target's sides
- round5 snap: a window is never its own target, by key or by a set
- round5 snap: a top or bottom drop on a merged window stacks into the column under its center
- round5 snap: a section inside DETACH_RADIUS holds, past it is out
- round5 snap: a detached window dragged under another glows its bottom and merges there on the drop
- round5 snap: the driver measures at most every THROTTLE seconds
- round5 snap: a drop left of a window makes a second column, the target kept where it stood
- round5 snap: a drop with no window near is a plain move
- round5 snap: a merged window dragged by its band merges whole onto a detached window's side
- round5 snap: a window dragged over its own group's frame is never merged into it
- round5 snap: a section dragged inside the leeway holds, edged sem.good, and its release changes nothing
- round5 snap: a section dragged past the leeway, edged sem.bad, splits off at its drop point
- round5 snap: a section dragged out onto another window's side merges there
- round5 snap: locked refuses every drag: a window's, a group's and a section's
- round5 snap: in combat a drop still moves, and the merge it asks for waits for combat's end
- round5 snap: a stand-down mid-drag drops the drag, the driver disarmed and the glow hidden

### test_round5_followups.lua (27)

- round5 filter: All, Learned, Equipped and Below cap narrow the weapon block, stored per profile through the seam
- round5 filter: Layout > Blocks > Weapon skills has the Show rows row, its values the filter menu's
- round5 filter: the weapon header's funnel opens a menu, the current filter ticked; a pick filters the window
- round5 filter: a block its filter empties keeps its header and a muted line, not an empty block
- round5 filter: the detached frame carries the filter mark and the muted line
- round5 filter: a merged window's weapon sub-header carries the filter mark and the muted line
- round5 filter: Equipped follows an equipment change in the main window at once
- round5 trainer popup: the Also teaches line wraps inside its card, and the card and the window grow to fit
- round5 trainer popup: a secret or zero measure keeps the one-line card, and too tall a window scrolls, still wrapped
- round5 trainer popup: a card's tooltip carries the whole Also teaches list
- round5 distance: yards between two world positions, none across instances or without one
- round5 distance: nearest first, the unmeasured last in their order, the input untouched
- round5 distance: Compat reads the player's and a map point's world position, nil when the client cannot say
- round5 distance: each card shows its distance and the popup sorts nearest first, the unknown last
- round5 distance: the popup re-measures once a second while shown, keeps the selection, and stops on hide
- round5 distance: a secret or missing player position shows no distance and keeps the data's order
- round5 distance: Escape (the frame's own hide) stops the re-measure too
- round5 rows: the Stats page is gone (its General tab drew nothing) and the Rows page holds every hide row
- round5 rows: the groups follow the window's block order, skills by category, stats by group
- round5 rows: a tab draws a column header, its block's heading and two eyes per row
- round5 rows: a group heading's eyes show that group's hidden rows again, one column each
- round5 rows: a hide written while the page is hidden (the row menu) redraws it on its next show
- round5 rows: the Rows page's Defaults restores both hidden sets; the Skills and Broker pages' leave them
- round5 review: a UIParent hide and show (Alt+Z, a cinematic) restarts the popup's re-measure
- round5 review: a block its filter emptied is content, so the window's empty message stays hidden
- round5 review: a hide written elsewhere while the Rows page is on screen redraws it; a show-all draws once
- round9 rows: one tab per block in the default block order, each drawing only its block

### test_round6.lua (53)

- round6 toast: the gap and skill-up toasts wear the cap toast's skin shell, no tint or edge of their own
- round6 toast: the value stays red or green and carries its delta in brackets
- round6 toast: test mode's gap and skill-up toasts take the same look
- round6 test mode: the Journal shows the main window's strip and its body moves down under it
- round6 test mode: the LDB tooltip says test mode under its title while it is on
- round6 header marks: every ink box is the shipped art's own
- round6 header marks: the window header, a detached band, a merged band and a sub-header draw every mark fitted
- round6 sort menu: the sort mark opens a menu of every order on the header, the band and the sub-header
- round6 expanded: a new profile has every block expanded, in the window and the LDB tooltip
- round6 thresholds: two switches, off in the window and on in the row tooltip, on the Bars page
- round6 thresholds: the tooltip bar follows its own switch, every other bar the window's
- round6 thresholds: the row tooltip lists the thresholds only while its switch is on
- round6 thresholds: the window legend's threshold entry shows only with the window switch on
- round6 thresholds: schemaVersion 7 carries a stored false to both switches and drops the old key
- round6 waypoint: the button reads Set waypoint whatever the provider, and no footer is left
- round6 waypoint: a trainer without coordinates disables the button and its tooltip says why
- round6 waypoint: the window ends a pad under the buttons, shorter by the old footer
- round6 trainer ranks: NextRank groups the next rank's trainers and every higher rank's, the next first
- round6 trainer ranks: a trainer is listed once, under the lowest rank it trains, and an emptied rank goes
- round6 trainer ranks: the popup lists Expert and Artisan trainers under their headings, the intro says or higher
- round6 trainer ranks: nearest first inside each rank, the ranks kept in order, re-sorted each second
- round6 trainer ranks: past the max height the cards scroll under a skin scroll bar, the wheel and the bar drive it
- round6 ldb look: a new profile draws the Main window style on its own TOOLTIP frame, the window's size
- round6 ldb look: the window's headers and rows, the bar with its text inside and the mark at its right
- round6 ldb look: a block collapsed in the window stays open here; the header and its chevron take the pointer
- round6 ldb look: a row's left and right clicks open nothing
- round6 ldb look: the window's weapon filter and sort reach both styles
- round6 ldb look: past its Height the body scrolls, by the wheel and by the skin's scroll bar
- round6 ldb look: the classic-only rows are dimmed in the Main window style, width and height in Classic
- round6 ldb look: schemaVersion 8 keeps every stored profile on Classic; a fresh install starts on it new
- round6 stats feed: its own data source, its tooltip the four stat blocks, its clicks its window's
- round6 stats feed: a stat row's menu pins its stat to the feed per character; with none it reads Character Stats
- round6 stats feed: schemaVersion 9 drops a stored Stats section switch, the stat blocks' switches answer
- round6 review: the Main window style's test strip shows in test mode and takes no click
- round6 review: the Set waypoint button keeps the skin's hover look beside its own tooltip
- round6 review: schemaVersion 8 keeps an empty stored profile on Classic too; only a fresh install starts new
- round6 review: schemaVersion 10 keeps Spell and Defense collapsed on a profile from before R6-8
- round6 arrow: the rotation is bearing minus facing, counter-clockwise from north (x north, y west)
- round6 arrow: the fill blends from the skin's accent at 300 yd to its sem.good at 30 yd
- round6 arrow: a waypoint sets the native pin unsuper-tracked and shows the arrow on it
- round6 arrow: Show Character Ledger's arrow off keeps the old behavior
- round6 arrow: the arrow follows the player's facing and place, throttled, and turns color by distance
- round6 arrow: no facing hides the art and keeps the distance; no distance shows the name alone, dim
- round6 arrow: within 5 yd the arrow hides, the pin clears and chat says you have arrived
- round6 arrow: the menu's Clear waypoint clears the waypoint; a cleared or replaced native pin hides the arrow
- round6 arrow: a drag saves the offsets on the profile; the arrow's own lock refuses it
- round6 arrow: test mode shows it on a sample trainer at a sample distance, writes nothing, and takes it down
- round6 arrow: /cl test raises and lowers the arrow with test mode's other surfaces
- round6 arrow: turning the arrow off hands the pin back to the game's arrow; the scale applies at once
- round6 arrow review: a hide and show of its parent (Alt-Z, a cinematic) leaves the arrow ticking
- round6 arrow review: a profile switch to one with the arrow off hands the pin back to the game's arrow
- round6 arrow review: a profile switch re-applies the shown arrow's scale and position
- round6 arrow review: right-clicking test mode's sample over a real waypoint brings the real arrow back

### test_round7.lua (32)

- round7 no TomTom: a TomTom-shaped global is ignored; the native pin and Character Ledger's arrow always
- round7 no TomTom: the arrow off super-tracks the pin (the client's arrow)
- round7 no TomTom: /cl test shows the sample arrow while the arrow setting is on
- round7 no TomTom: Waypoint method offers the map pin and chat only, no TomTom label
- round7 no TomTom: schemaVersion 11 folds a stored tomtom or native method into auto
- af tomtom: the real TomTom loaded places a TomTom waypoint and no arrow of ours
- af tomtom: the announce line names TomTom
- af tomtom: TomTom's AddWaypoint raising falls back to the native pin and our arrow
- af tomtom: TomTom absent keeps the native pin and our arrow; Chat only still prints
- af tomtom: TomTom loaded but no native pin API still places a waypoint
- af tomtom: Compat.TomTom answers the real addon only, by name
- round7 icon border: Use the row's color is off on a new profile, so the skin's icon border draws
- round7 icon border: schemaVersion 12 keeps the row's color on every profile stored before
- round7 header meta: no block header carries a line beside its title, Base & Combat included
- round7 titles: each feed's tooltip reads its window's title (SMW-05), Character Ledger · Professions ...
- round7 titles: the panel's title never overlaps its gains text, centered while it fits
- round7 scroll bar: an always-shown bar is drawn disabled while nothing scrolls, enabled once it does
- round7 scroll bar: the LDB panel builds its bar always shown
- round7 filters: each block's own set, a Show rows row for every block, All by default
- round7 filters: Primary and Secondary narrow to below cap or at cap with a rank to train; unlearned is All only
- round7 filters: Other skills offers Learned and Below cap
- round7 filters: a stat section's Non-zero leaves out 0 and 0% rows, an emptied one keeps its muted line
- round7 filters: every window header carries the funnel, the filled badge while it narrows, and its menu
- round7 filters: a detached stat frame and a merged section carry the mark and follow the filter
- round7 filters: both LDB tooltip styles honor every block's filter
- round7 go icon: Open a row from is gone from the LDB tooltip; schemaVersion 16 drops a stored one
- round7 go icon: a tooltip row's left, shift and right clicks do nothing, on the row and on its go icon
- round7 go icon: a hovered crafting row arms no secure cast, and its go icon takes no mouse
- round7 go icon: a tooltip row keeps its hover: the window's wash and its row tooltip, with no click hint
- FB-SM-05 test mode: the arrow off still shows a labeled sample
- FB-SM-05 test mode: with TomTom loaded the sample is Character Ledger's, labeled, and TomTom is never written
- FB-SM-05 test mode: turning the arrow off while it runs keeps the sample

### test_round8.lua (22)

- round8 header marks: a detached band's marks rest in the main window header's color
- round8 header marks: a merged window's band and section sub-headers match the main window header
- round8 ldb tooltip: its headers carry no sort or filter mark, on All or a narrowing filter
- round8 ldb tooltip: the main window's headers keep their sort and filter marks
- round8 filter badge: the window header's funnel on a solid square while it narrows, hover readable
- round8 filter badge: a detached band and a merged sub-header wear the same badge
- round8 open a row from: Layout > Window's Open a row from, Full row by default (the LDB tooltip's went, SMW-07)
- round8 open a row from: Full row lays the crafting cast over the whole row, Go icon only over the icon
- round8 open a row from: a Full row click opens what the go icon opens; Go icon only, the row opens nothing
- round8 open a row from: shift-click links and right-click opens the menu in both modes, on the row and its overlay
- round8 open a row from: the crafting overlay casts on a plain left click only, never in combat
- round8 open a row from: in combat a Full row arms nothing and its click says why; armed again after
- round8 open a row from: detached and merged windows follow the main window's setting
- round8 open a row from: the row tooltip's click hint says the mode
- round8 open a row from: a tooltip row opens nothing and arms no cast, in either window mode
- round8 arrow: the profile's arrow defaults are the library's, Raised and the skin's colors
- round8 arrow: the Waypoint arrow subgroup is the library's settings block at Character Ledger's paths
- round8 arrow: each of the five looks reaches the shown arrow through its setting
- round8 arrow: the skin's colors off draws the far and near swatches, faded by distance
- round8 arrow: a profile switch re-applies the arrow's look
- round8 arrow: the library carries every look's art; Character Ledger's own copy is gone
- round8 arrow: a library-absent load has no arrow, so a map pin keeps the game's own

### test_round9.lua (14)

- round9 arrow: the Text and Position blocks sit under the look, at Character Ledger's paths, on the library's defaults
- round9 arrow: the Position block's Reset position is a hook on its subgroup, handed to the page
- round9 arrow: a drag writes the X and Y offsets through the settings seam
- round9 arrow: the arrow's own Lock holds the drag; /cl lock no longer does
- round9 arrow: the menu is Clear first, the library's items, then Character Ledger's, in the owner's order
- round9 arrow: Clear waypoint clears the native pin, as the old right-click did
- round9 arrow: Show trainers opens the trainer popup on the skill its waypoint came from
- round9 arrow: Arrow settings opens Trainers and Waypoints; Hide arrow turns Character Ledger's arrow off
- round9 arrow review: under test mode's sample Show trainers is off, as the library's Show on map is
- round9 arrow review: Arrow settings is off in combat, with the combat tooltip
- round9 arrow review: a drag, the menu's Lock and Reset position refresh the open settings panel
- round9 arrow: the tooltip says right-click opens the menu, and drops the drag hint while locked
- round9 arrow: Show the trainer's name adds the trainer as the second line
- round9 arrow: compact units read thousands of yards in Character Ledger's words

### test_sr1.lua (10)

- sr1 title-bar tips: every control of the main window shows its tooltip above it, in gtip.title
- sr1 title-bar tips: every control of the journal shows its tooltip above it, in gtip.title
- sr1 title-bar tips: every control of the trainer popup shows its tooltip above it, in gtip.title
- sr1 title-bar tips: every control of a block header shows its tooltip above it, in gtip.title
- sr1 title-bar tips: every control of a detached block's band shows its tooltip above it, in gtip.title
- sr1 title-bar tips: every control of a merged window's band shows its tooltip above it, in gtip.title
- sr1 title-bar tips: every control of a merged section's sub-header shows its tooltip above it, in gtip.title
- sr1 title-bar colors: every mark icon.tint at rest and text.link hot, the close close.rest and close.hot, in Ka0s Default and every other skin
- sr1 title-bar colors: a narrowing filter keeps its filled badge (a state color) at rest
- sr1 header bands: cl.headerBg resolves to list.header.bg in every skin

### test_blocks.lua (10)

- blocks: the eight skill and stat blocks, four skill categories then four stat groups, then the tree blocks
- test_blocks_detach_dock_roundtrip: a block leaves the window, gets its own frame and comes back
- blocks: a detached frame saves its drop point; locked refuses the drag
- test_rows_unlearned_variant: an unlearned skill is a dimmed row with its trainer and the action mark
- rows: money and the riding trainer line
- rows: the color modes
- test_mainwindow_collapsed_persisted: collapsing a block is stored, survives a re-render and the header toggles it
- mainwindow: the title bar carries lock, journal, settings and close; the summary and legend show
- mainwindow: an empty model shows the empty state, and data hides it
- mainwindow: a skin switch restyles every bar, header and icon well, not only the values

### test_families.lua (7)

- families: six families in the character panel's order, each with a title, blocks and a feed
- families: the split and the kept broker names (the spec's calls)
- families: every block belongs to exactly one family, and its def says which
- blocks: NS.BLOCKS keeps the eight skill and stat blocks first, then the tree blocks (SMW-08..10)
- blocks: the engine dispatches on B.PROVIDERS by the def's source
- blocks: Models() keys every provider's model by source, and Data() still answers skills, stats
- blocks: Entries(id, skills, stats) and EntriesFrom(id, models) answer the same rows

### test_tree.lua (11)

- tree: char.fold defaults to an empty store
- tree: Statistics categories start folded; reputation and currency headers start open
- tree: Visible skips the children of a folded node, at every depth
- tree: a visible row carries its depth, indent, header flag and chevron
- tree: Toggle flips one node and answers the new state
- tree: a fold never calls the client's Expand or Collapse
- tree: SetAll folds or opens every header it is given
- tree: the node keys the spec names, per family
- tree: a header with no key is drawn open and never stored
- tree: while test mode runs, folds go to a session store and the character's stay as they were
- tree: an explicit store is used as given (the LDB tooltip's own folds)

### test_windows.lua (11)

- windows: one window per family, in the family order, each its own frame and title
- windows: each window draws its own family's docked blocks, and only those
- windows: the Character Stats window drops the Stats prefix nowhere it matters; tree windows show their empty line
- windows: each window's size and strata are its own rows, applied to it alone
- windows: a window never dragged opens next to the Professions window, stacked down and right
- windows: a drag saves that window's drop point alone; Reset position forgets every one
- windows: schemaVersion 14 moves the old window's stored settings to the Professions window
- windows: one slash verb per window toggles it; /cl hide hides them all
- windows: each family's key binding button toggles its window
- windows: a broker crafting row routes to the window that docks it
- windows: a stood-down addon refuses every window

### test_interact.lua (17)

- test_secure_overlay_deferred_in_combat: crafting overlays are made and moved only out of combat
- secure overlay: hiding the window hides its overlays; the stand-down takes them down
- secure overlay: a click that reaches a crafting row logs its overlay's state, before and after the re-sync
- secure overlay: the pointer entering a crafting row lays its overlay before any press
- secure overlay: only the hovered crafting row is armed, one strata over its window, until the pointer leaves
- interact: the click map (design §6.5)
- interact: shift-click links the row to chat; right-click opens the row menu
- test_rowtooltip_lines_fishing_lure: the lure, its timer, the session and the fishing helper
- rowtooltip: the session line is this skill's gains and rate; the ETA reads in hours
- rowtooltip: skinning names the mob level and the next breakpoint; a weapon its cap gap
- rowtooltip: Show draws on GameTooltip with the bar, Hide gives it back
- trainer popup: the faction's trainers, the selection and the waypoint button
- test_waypoints_fallback_order: the native pin, then chat
- interact: shift-click on a profession row inserts its trade link, as the spellbook icon does
- panel overlay: a weapon row's mark opens the panel by the micro button, then the Skills tab on its line
- panel overlay: a stat row's mark opens the paper doll; from another tab it reopens there
- panel overlay: no micro button, no overlay; a plain mark click in combat says why and opens nothing

### test_sessionlog.lua (6)

- test_sessionlog_ring_cap: the log keeps the newest 500 skill-ups in db.char.log
- test_sessionlog_eta: (max - rank) / the skill's own rate over this session's gains
- sessionlog: Gains counts points this session, per skill too; Rate is points an hour
- sessionlog: a SKILL_UP on the bus lands in the log with the zone
- sessionlog: a malformed skill-up is refused, never stored
- sessionlog: Since, Gains and ETA take a range start (the Journal's range picker, FB-32)

### test_alts.lua (6)

- test_alts_snapshot_two_word_name: the key is realm-key, then the whole two-word name
- alts: a half-loaded (empty) model keeps the skills the last snapshot had
- alts: List puts this character first, then by name; Forget drops one
- alts: a burst of SKILLS_UPDATED is one debounced snapshot; PLAYER_LOGOUT snapshots at once
- alts: the snapshot carries the character's stats by key, with each one's block and display
- alts: no stat model keeps the stats the last snapshot had; an old snapshot has none

### test_journal.lua (22)

- journal: /cl journal toggles it, through the one toggle handler
- journal: the chrome is the shared one: the title, the wrapped close control, the window tier
- journal: the tabs switch panels: Log first, then Alts
- journal: the log lists skill-ups newest first, with the session's gains, and Clear empties it
- journal: a SKILLS_UPDATED repaints an open log
- journal: the alts matrix has a column per character, a row per skill, a mini bar per skill it has
- journal: the alts sub-tabs are the main window's blocks, in its order
- journal: a stats sub-tab lists every stat of its block; a snapshot without stats reads a dash
- journal: a character's name is two lines in its column; the rest is the header's tooltip
- journal: right-click on a character's name asks before forgetting it
- journal: an unlocked drag saves the drop point; Reset position forgets it
- journal: the stand-down hides it
- journal: durations and ETAs read as the mockup writes them
- journal: the Log has a Date column beside the time, and every column keeps to its width
- journal: the range picker narrows the Log and its summary; the choice is stored per profile
- journal: the range is a schema row on the Journal page with the six choices
- journal: the ETA note wraps inside its card
- journal: schemaVersion 5 turns a stored pre-FB-33 filter into its block
- journal: a grab pins the window by its top-left, and the release saves that point with the size
- journal: a saved size beyond the screen comes back on it; a wider window shows more characters
- journal: the Log table scrolls by a bar that shows only while it overflows
- journal: the Alts table scrolls by a bar too

### test_alerts.lua (14)

- test_alerts_cap_once: reaching the cap toasts once with the next trainer, and says it in chat
- alerts: the cap alert comes back for the next cap, never twice for one
- alerts: no cap alert below the cap, at the top rank, or when switched off
- test_alerts_weapon_gap_threshold: a weapon skill weaponGap or more below its cap toasts
- alerts: the weapon-gap toast shows once per skill per session, and not when switched off
- alerts: a level-up raising a weapon cap checks every weapon; the first model checks none
- alerts: the bus delivers SKILL_UP to the alerts
- alerts: clicking the cap toast sets a waypoint when Waypoints exists, else prints directions
- alerts: the real toast draws the cap payload with the mockup's lines
- alerts: the stand-down clears the toast; a profile reload refreshes it
- alerts: the defaults carry every alerts key
- alerts: a skill point toasts Skill up with the session, the cap and the ETA; close ones fold
- alerts: Skill-up alerts for narrows the skills; off reads none
- alerts: the real toast labels a skill up green and a weapon gap red, the cap toast neither

### test_template.lua (3)

- test_template_tokens: every token of design §6.7 renders from the context
- test_template_tokens: no pin falls back to the last skill-up, then to the lowest profession
- test_template_unknown_token_empty: unknown tokens and missing data render empty

### test_broker.lua (16)

- broker: one data source per family (SMW-05), "Character Ledger" and "Character Ledger Stats" kept, separate from the launcher object
- broker: the feed renders its template
- broker: {equippedWeapon} follows the main hand's weapon class
- test_broker_flash_reverts: a skill-up flashes its own family's feed, then the template comes back
- broker: the Professions and Skills feeds' tooltips have their own two sections each, on by default, and no stats
- broker: each section has its own switch
- broker: a tooltip Hide leaves the main window alone, and the window's Hide leaves the tooltip
- broker: a tooltip Hide row per catalog skill and per stat, on the Rows page (R5-13), apart from the window's
- broker: clicks follow design §6.5 and never touch a secure frame
- broker: a hovered tooltip row wears the window's hover wash, under its text, until the pointer leaves
- broker: stood down, the feed reads Off and its tooltip says so; standing up re-renders
- broker: the tooltip wears the skin by default, on its own frame, never on GameTooltip
- broker: Apply skin off draws the plain GameTooltip, and takes the skinned one down
- broker: GameTooltip keeps its state, and its hide never takes the skinned tooltip's bars
- broker: schemaVersion 3 carries the All template and drops the other feeds' keys
- broker: schemaVersion 3 moves the active profile's All template past the copied default

### test_feeds.lua (12)

- feeds: one data source per family, in the family order, the two shipped names kept
- feeds: with nothing pinned, a {pinned} feed reads its family's short name
- feeds: each feed's template is its own
- feeds: a pinned skill shows on its own family's feed
- feeds: the Character Stats feed's {pinned} is its pinned stat, in any template
- feeds: a skill-up flashes its own family's feed alone
- feeds: a tree family's tooltip says it has nothing yet, in both styles
- feeds: each feed's cell toggles its own window; a right click opens the Broker page
- feeds: stood down, every feed reads Off
- feeds: the Broker page has a template pair and the section switches per feed
- feeds: schemaVersion 15 moves the one template to the Professions feed's
- feeds: the tooltip content is its own file, and Broker.lua stays well under the cap

### test_pins.lua (8)

- pins: a row's menu ticks its own family's broker, and a second pin keeps the first
- pins: {pinned} joins the feed's pins, {pinned1}..{pinned5} render one each
- pins: five per broker; a sixth row's pin is disabled and says why, other brokers unaffected
- pins: the old one-pin fields fold into their families' lists when read, once
- pins: the Classic tooltip lists the feed's pins first, under Pinned
- pins: the Main window style tooltip lists them first too, a Pinned header over their rows
- pins: the Broker page's Pins tab lists each broker's pins, moves and unpins them
- pins: in test mode the feeds draw the sample's pins, and this character's store stays

### test_ldb_tooltip.lua (6)

- ldb tooltip: a section's chevron folds it in the tooltip alone, and the tooltip redraws in place
- ldb tooltip: a fold's redraw keeps the body's scroll offset, clamped to the new overflow
- ldb tooltip: Classic sections carry chevrons that fold them, and its rows take no click
- ldb tooltip: the Classic header line shows the chevron's state
- ldb tooltip: a tree header's tooltip fold is the tooltip's own, never the window's
- ldb tooltip: a redraw with no tooltip up does nothing

### test_reputations.lua (13)

- reputations: the first read opens every collapsed header, reads, and closes them again bottom up
- reputations: a standing bar runs from the current threshold to the next, labeled and colored by the client
- reputations: in combat or with the Reputation tab up the read opens nothing; combat's end reads in full
- reputations: the read's own header toggles are latched: an UPDATE_FACTION meanwhile reads nothing
- reputations: later reads go by id, touch no header, and announce a moved standing
- reputations: a faction the model does not know asks for the full read again
- reputations: the window draws the tree, and a fold is this addon's own, never the client's
- reputations: the tooltip folds a header in its own folds; the window's stay
- reputations: the Classic tooltip lists the tree, each header a chevron line
- reputations: a row's menu pins it to the Reputations broker, whose text shows its standing
- reputations: the Alts snapshot keeps each standing; the Journal has a Reputations sub-tab
- reputations: a simulation never toggles the client's headers (the seam guards the toggle)
- reputations: a detached Reputations block draws the same tree, and the Journal's sub-tab draws its standings

### test_currencies.lua (9)

- currencies: the first read opens every collapsed header, reads, closes it again, and never reads gold
- currencies: a capped currency is a bar, one without a cap a plain value; the tooltip says the week's cap
- currencies: CURRENCY_DISPLAY_UPDATE with an id reads that one by id, touching no header, and logs the gain
- currencies: a nil currencyType reads every known one again; an unknown id asks for the full read
- currencies: in combat or with the Currency tab up the read opens nothing; the latch holds its own echo
- currencies: an empty list is the window's empty line; the window draws icons, bars and plain values
- currencies: the cap alert is off by default; on, it toasts once as a currency reaches its cap
- currencies: a pin shows its amount; the Alts snapshot and the Journal's Currencies sub-tab
- currencies: a simulation never toggles the client's headers (the seam guards the toggle)

### test_statistics.lua (15)

- statistics: the category tree is depth first, a parent of -1 or one the list lacks a root, a cycle survives
- statistics: a value shows as the tab shows it: the number, -- for none, a string verbatim
- statistics: the first look reads the category tree only; every category starts folded
- statistics: unfolding a category reads its rows alone, in Forever's two-argument form; names are cached
- statistics: CRITERIA_UPDATE is registered only while the window or its tooltip shows, or one is pinned
- statistics: a burst of CRITERIA_UPDATE is one re-read a second later, of the unfolded categories only
- statistics: with nothing showing, CRITERIA_UPDATE reads nothing and the registration goes
- statistics: a pinned statistic shows in its broker's text and is read alone, by its index, while hidden
- statistics: at login a pinned statistic's category is read for the feed, and nothing else
- statistics: the tooltip folds in its own folds and reads what it unfolds; the window's folds stay
- statistics: the Classic tooltip lists the categories, each a chevron line
- statistics: a row's tooltip says its value and category; no Alts sub-tab; the empty window says so
- statistics: test mode reads nothing of the live tab
- statistics: about 1000 rows read once each at two calls a row; a re-read costs one a row
- statistics: the statisticsRead perf bucket is noted while a capture is on, and nothing while off

### test_smw_review.lua (15)

- smw-rev: a currency with no cap is pinnable from its row's menu; a header is not
- smw-rev: a Reputation or Currency tab left selected in a closed character panel does not block the full read
- smw-rev: a new faction met in combat keeps every faction under a collapsed header; combat's end reads in full
- smw-rev: a new currency met in combat keeps every currency under a collapsed header; combat's end reads in full
- smw-rev: a list read that raises after opening a header still closes what it opened, then raises
- smw-rev: the Statistics window reopened reads its unfolded categories afresh, not as it last saw them
- smw-rev: the Statistics tooltip shown again reads what it unfolds afresh
- smw-rev: with the window hidden and one statistic pinned, CRITERIA_UPDATE reads the pinned row alone
- smw-rev: a reputation's later change is a row after the skill-up, so the Log stays in time order
- smw-rev: the feeds read the main hand and the level only for a template that shows them
- smw-rev: a nested header's chevron in the Classic tooltip is inside its hit, which spans the line
- smw-rev: in the Statistics window, Expand all opens every category and Collapse all folds them, the block open
- smw-rev: in the Reputations window, Collapse all folds the headers; a collapsed block opens on Expand all
- smw-rev: the skill windows' Expand / Collapse all still collapses and expands their blocks
- smw-rev: the Character Stats window and feed title the stat blocks without the "Stats ·" prefix

### test_r5_feedback.lua (16)

- r5 sm-01: no fold chevron carries a hint tooltip, in any window or in the LDB tooltip
- r5 sm-02: in a window, a click on a block header's body and on a tree header's row folds it, at every depth
- r5 sm-02: in the Main window style LDB tooltip, a click on a section header's body or a tree header's row folds it
- r5 sm-02: in the Classic LDB tooltip, a header line's hit spans the whole line, at every depth
- r5 sm-03: a pinned row shows the pin mark in every window, and only a pinned row
- r5 sm-03: a pinned row's name gives the mark its room, so a long name never runs under it
- r5 sm-03: the LDB tooltip draws the pin mark on its pinned rows, its Pinned section's included
- r5 sm-03: the Classic LDB tooltip draws the pin mark on its pinned lines, and only those
- r5 sm-03: pinning and unpinning a row shows and hides its mark at once
- r5 sm-04: the six display brokers each draw their own in-game icon; the addon's control broker keeps the logo
- r5 sm-05: /cl toggle shows all six windows when none shows, and hides them all when any shows
- r5 sm-05: /cl professions, the Show window entry and its key binding toggle the Professions window alone
- r5 sm-05: the help says /cl toggle is every window and /cl professions the Professions window
- r5 sm-05: /cl toggle under the perf hold opens nothing and says the capture line once
- r5 sm-06: the probe's doubled profession lines draw each profession once, in the windows and the tooltip
- r5 sm-07: all six windows open while playing raise no Lua error, and /cl toggle closes them all

### test_r5_join_resize.lua (5)

- r5 sm-08: a merged window has a shown resize grip, its bounds per column at the content's height
- r5 sm-08: a drag on the grip sets the column width, snapped, and keeps the drop point
- r5 sm-08: Locked hides a merged window's grip and refuses a grab
- r5 sm-08: a stored column width out of range is clamped, a malformed one dropped
- r5 sm-08: migration 17 cleans a stored group's column width

### test_r5_subdetach.lua (9)

- r5 sm-09: every tree header in the Reputations, Currencies and Statistics windows has a detach mark
- r5 sm-09: detaching Alliance makes its own window of its factions and takes it out of Reputations
- r5 sm-09: docking a sub-category puts it back where it was and forgets its row
- r5 sm-09: a nested Statistics category detaches, read whatever the window's folds say
- r5 sm-09: a currency header detaches, keyed by its name
- r5 sm-09: a detached sub-category collapses, resizes, joins a block and survives a reload
- r5 sm-09: the LDB tooltip keeps the whole tree and shows no detach mark
- r5 sm-09: the model normalizes a stored row and refuses what is no tree header
- r5 sm-09: schemaVersion 18 normalizes a stored layout.subs and drops one that is no table

### test_r5_journal.lua (17)

- r5 sm-10: each reputation change is its own row, in time order, signed
- r5 sm-10: a change that moves the standing records it, and the Change column says where it landed
- r5 sm-10: a standing that moved on the bus lands as a row with both standings
- r5 sm-10: RepData's changes carry the old and new reaction; the first read (the login baseline) has none
- r5 sm-10: the Log draws a reputation row's name and its signed change with the standing
- r5 sm-10: a reputation grind never pushes a skill-up out: the ring keeps journal.keep of each sort
- r5 sm-10: schemaVersion 19 keeps every stored Log row and fills a change row's missing name
- r5 sm-11: every header opens a filter menu; Name is the fourth, after Type (R6-SM-02)
- r5 sm-11: the Type filter (R6-SM-02) narrows to a kind, Name to one name, and the summary counts that kind
- r5 sm-11: Date, Time, Change and Zone filters, combined
- r5 sm-11: an active header shows it, and Clear filters clears every one in one click
- r5 sm-11: the ETA card follows the Type filter
- r5 sm-12: the Log's empty lines and the Clear log question speak of every row, not skill-ups alone
- r5 sm-12: with the Type filter on reputations, the ETA card says the filter leaves no skill-ups
- r5 sm-12: the Alts tab's empty line and footer name reputations and currencies too
- r5 sm-12: test mode's sample Log shows reputation and currency rows beside the skill-ups
- r5 sm-12: the diagnostics count the Log's rows by sort

### test_r5_review.lua (5)

- r5 review: the Log keeps journal.keep of each sort across sessions; a login never lets one sort grow
- r5 review: a lower keep from a profile switch still never trims a sort below what it held
- r5 review: the open Journal's Log shows a reputation or currency change as it lands
- r5 review: the Yesterday filter is the calendar's day before, across a daylight-saving change
- r5 review: a detached sub-category this character's tree lacks shows no window, and keeps its row

### test_r6_owner.lua (18)

- r6 sm-01: the group's title reads Secondary Professions; its id and short label stay
- r6 sm-01: a detached Secondary window is titled Secondary Professions
- r6 sm-01: the settings labels and the Professions window's binding tip say secondary professions
- r6 sm-01: the client's own header, Secondary Skills, still files its lines in the Secondary group
- r6 sm-02: the Log has a Type column after Time: Skill-up, Reputation (a standing change too), Currency
- r6 sm-02: the Type header filters by kind; Name keeps the names, of the picked type only
- r6 sm-02: the Journal is wide enough at its minimum for every column and the side cards
- r6 sm-03: each Type cell is drawn in its kind's own color, three distinct, none the muted style
- r6 sm-03: the type colors are readable on the dark Journal and far apart from each other
- r6 sm-03: the Type filter menu lists each type in its own color; Any type stays plain
- r6 sm-04: an unlearned Alts cell reads '-' in the muted style, and has no tooltip
- r6 sm-04: a learned profession cell shows the main window's tooltip, from that character's snapshot
- r6 sm-04: a weapon cell measures the cap at that character's level
- r6 sm-04: stat, reputation and currency cells show their windows' tooltips, no session line
- r6 sm-04: the main window's own tooltip keeps its bonuses, session and hint lines
- r6 sm-04: an alt's next rank and trainer are asked for that character's level, faction and race
- r6 sm-04: a snapshot keeps the race's token beside its localized name
- r6 review: a repaint under a hovered Alts cell redraws its tooltip, or hides it for a cell with none

### test_preview_trees.lua (6)

- preview trees: the sample's records come in the panels' shapes, built by the live builders
- preview trees: test mode draws the sample in the three windows, reading nothing of the live client
- preview trees: the tree feeds draw the sample's own pins and tree, never this character's store
- preview trees: the sample's Alts record carries its standings and currencies
- preview trees: the simulator's world is read through the seam; its steps raise a reputation and a currency
- preview trees: a simulated currency at its cap never silences a real one (the alerts' state)

### test_polish.lua (12)

- broker: the leave poll hides GameTooltip only while the feed still owns it
- broker: the footer reads as the mockup; a right-click opens the Broker settings page
- helpers: the equipped weapon skills read the main hand, off hand and ranged slots
- detached: the weapon block marks the equipped weapon; the compact filter keeps equipped + below-cap
- detached: an equipment change redraws a shown weapon block
- rows: the gathering hint is off by default and reads NS.SkillHelpers when on
- rows: a hinted row is one line taller and shows its hint; the setting off hides it
- secure overlay: raising the window re-levels its overlays above the rows (out of combat only)
- secure overlay: a row click raises too; a detached frame's mouse-down re-levels its overlays
- secure overlay: a dragged window's overlays come down for the drag and back at the drop
- journal: a grip drag lays out at most once per frame and redraws once, after the release
- journal: the saved size is restored, clamped to the minimum; locked refuses the grip

### test_preview.lua (9)

- preview: test mode draws the sample Dwarf Hunter in every block
- preview: the bonuses are the sample's: none on Guns (no Forever racial), the lure's timer on Fishing
- preview: the broker, the summary line and the row tooltip read the sample
- preview: the Journal's session log and alts are the sample's
- preview: test mode off restores the live data in every source
- preview: combat ends test mode and puts the live data back
- preview: the sample character and its alts are Sim.Sample's Forever people
- preview: no hand-kept copy of the sample people (LibKa0s#104)
- preview: a library-absent load draws a nameless sample character and no alts

### test_sample_names.lua (2)

- sample names: the matcher finds a planted name and passes an identifier
- sample names: no Sample*/Mock* name literal outside tests/, libs/ and the frozen docs

### test_sim.lua (12)

- sim: the seam wraps every Compat member, and nothing escapes it (H2)
- sim: the Sim and seam stubs carry the live surfaces (H9)
- sim: a library-absent load takes the stubs, and the verb names the missing major
- sim: the refusals, each leaving Sim mode unticked (H5)
- sim: test mode refuses while a simulation runs (the two are exclusive)
- test_sim_skill_up_drives_flash: a sim skill-up makes the broker flash and the session log record it
- sim: the lure goes on and off, and the mount changes the speed
- sim: a whole session saves nothing, and the stop restores the live state (H4)
- sim: the stand-down stops a running session first
- sim: the verb, the launcher entry and the checkbox are one handler
- sim: combat stops a running session
- sim: the window shows the simulation strip while a session runs

### test_sim_start_panel.lua (5)

- sim start panel: the panel's Start row is the typed start, and it shows the panel
- sim start panel: the bare /cl sim shows the panel
- sim start panel: a Restart with the panel closed shows it again
- sim start panel: the Master controls Sim box shows the panel
- sim start panel: the launcher menu's Sim mode entry shows the panel

### test_dropdown_selected.lua (3)

- dropdown selected: the Journal's range picker paints its selected range apart
- dropdown selected: the sort menu's current order (a radio row) paints apart
- dropdown selected: the selection is Ka0s Default's gold in every skin, WoW Forever's included

### test_window_chrome.lua (15)

- chrome AD-88: the main window's test and sim strips dock under its title bar (the skin's band)
- chrome AD-88: the main window's body sits under the title bar and moves down by the strip's BodyOffset
- chrome AD-89: the main window's legend is the library's Footer, FOOTER.HEIGHT (24 px) tall
- chrome AD-89: the main window's body ends FOOTER.HEIGHT above its bottom edge, plus the gap
- chrome AD-88: the Journal's strip docks under its title bar, the tabs moved down by BodyOffset
- chrome AD-88: the Main window style tooltip's strip docks under its title band
- chrome review: the title band's bottom is read from the band, 31 only with none measured
- chrome review: the main window's body follows the band's own bottom
- chrome review: the Journal's tabs follow the band's own bottom
- chrome review: the LDB tooltip's body follows the band's own bottom
- chrome review: the Journal's Alts hint is the library's Footer, shown with the Alts tab only
- chrome review: the Alts panel ends FOOTER.HEIGHT plus the gap above the bottom, the Log panel at PAD
- chrome degraded: with no skin library the title bar is a bare frame of the band's rect
- chrome degraded: with no widgets library a footer is a bare frame of FOOTER.HEIGHT with its left line
- chrome degraded: the main window and the Journal open without LibKa0s, their footers bare

### test_header_buttons.lua (10)

- AD-86 main window: lock, journal, expand / collapse all, settings, close on HeaderButtons
- AD-86 main window: the settings mark opens the settings through the launcher's opener
- AD-86 main window: the expand / collapse all mark's tooltip follows what a click does
- AD-86 journal: lock, settings, close on HeaderButtons, and settings opens the settings
- FB-SM-03 trainer popup: a companion, the close alone on HeaderButtons
- AD-86 detached and merged bands: a settings mark in the corner, opening the settings
- AD-86 detached and merged bands: the skin's header places settings in the corner, the marks inward at the pitch
- AD-86 detached and merged bands: without a skin's header, every mark GAP inward of the one before
- AD-86 degraded: without LibKa0s the main window and the Journal still build the strip, settings opening the panel
- FB-SM-03 degraded: without LibKa0s a companion's marks carry no settings

### test_tooltips.lua (11)

- tooltips: a main window row opens beside the window (PlaceBeside), never at ANCHOR_RIGHT
- tooltips: a detached block's row opens beside the detached display (PlaceBeside, GroupOf)
- tooltips: a Journal column header opens beside the Journal (PlaceBeside), never at ANCHOR_BOTTOM
- tooltips: a trainer card opens beside the popup (PlaceBeside), never at ANCHOR_RIGHT
- tooltips: the popup's disabled Set waypoint button attaches its reason above it (PlaceAttached), never ANCHOR_TOP
- tooltips: the waypoint arrow opens beside itself, the whole HUD display (PlaceBeside), never ANCHOR_RIGHT
- tooltips: the broker feed's tooltip is placed on its cell toward the screen's center (PlaceLauncher), in both styles
- tooltips: on the fake screen a row's tooltip opens right of the window when it fits, its top level with the row
- tooltips: on the fake screen a row's tooltip opens left of the window when the right does not fit
- tooltips: without the library a mark's tooltip attaches centered above it, never at a game anchor
- tooltips: the addon's own Lua names no game tooltip anchor but ANCHOR_NONE (no cursor, no corner offset)

### test_no_foreverdb.lua (7)

- characterization: Fishing 150/150's row tooltip names the next rank and its book seller, then the hint
- characterization: a trainer record with no position shows no coordinates and blocks the waypoint
- characterization: every shipped trainer record has a map position
- no ForeverDB: no addon Lua file outside libs/ and tests/_kit/ reads ForeverDB
- no ForeverDB: the TOC and .pkgmeta name no ForeverDB dependency, and the module is gone
- no ForeverDB: no Use ForeverDB setting, default or string
- no ForeverDB: schemaVersion 13 drops a stored trainers.foreverDB from every profile

### test_skin_defaults.lua (8)

- skin defaults: the arrow's text color and shadow companions default on, the schema agreeing (SD-SK-SM.2, SM.3)
- skin defaults: the arrow's text takes the skin's HUD text color and moves on a skin switch (SD-SK-SM.2)
- skin defaults: a list row's eye takes the skin's icon tint with the Scope cleared, the dim as alpha only (SD-SK-SM.1)
- skin defaults: with Ignore settings panel on, the eye keeps the client's white (SD-SK-SM.1)
- skin defaults: a trainer card's tooltip lines read gtip.title and gtip.body (U-7)
- skin defaults: the waypoint arrow's tooltip lines read the gtip family (U-7)
- skin defaults: the row tooltip's tones read the gtip family, meaning colors kept (U-7)
- skin defaults: a trainer card takes the skin's list.hover wash on hover, back on leave (U-31, CharacterLedger#9)

### test_seams.lua (5)

- test_seam_crafting_row_scrolls_window: ShowAndScrollTo expands, shows and scrolls to a crafting row
- test_seam_unlearned_row_opens_trainer_popup: the popup gets the skill key, not a table
- test_seam_alert_click_sets_waypoint: a cap toast's click goes through the real NS.Waypoints
- test_seam_mini_bars_are_the_bar_widget: the broker tooltip draws the Widgets Bar's mini style (the Journal's: test_journal)
- test_seam_title_bar_journal_button: the main window's journal mark toggles the Journal

### test_m5_seams.lua (7)

- m5 seam: the broker's right-click opens the registered Broker page through the library's opener
- m5 seam: Skills > Hint under the row drives the row hint live, off by default
- m5 seam: Skills > Gathering and fishing hints switches the tooltip's helper lines, apart from the row hint
- m5 seam: Layout > Weapon skills > Equipped and below cap only refilters the detached block live
- m5 seam: journal.size is the grip's drag state, never a row
- m5 seam: Journal > log length caps the live log, also while a simulation's override is in place
- m5 seam: diagnostics report test mode's sample data in state, model and sim

### test_m5_review.lua (5)

- profile switch: the window's bars restyle from the new profile with the same row set
- profile switch: the broker feed re-reads the new profile's template
- profile switch: the Journal takes the new profile's drop point and size
- profile reset: one LAYOUT_CHANGED reaches the look listeners (the Journal)
- test mode: a sample row's menu cannot pin the sample skill into the character's store

### test_m5_leftovers.lua (14)

- skin colors: every HUD color companion defaults on, in the defaults and on its row
- skin colors: the category and bonus owner tokens carry the mockup's colors
- skin colors: following the skin, each category fills in its own token, not one shared fill
- settings: fill direction, both strata and the column count each have a live row
- settings: a strata row's tooltip is the library's, over the row's own values (frame-layering-§1)
- fill direction: right to left anchors the fill, the bonus and the spark on the bar's right edge
- strata: the window and a detached block take their rows' strata live; overlays sit one strata over the host's
- columns: two columns lay the docked blocks side by side in a window twice as wide
- sim: a row's menu cannot pin while a simulation runs, and can again after it
- test mode: the broker's {pinned} and {equippedWeapon} are the sample character's
- glyphs: no display string carries a character a shipped skin face cannot draw
- glyphs: the guard is falsifiable, a planted arrow is caught
- client pin: the suite runs as WoW Forever whatever KA0S_KIT_CLIENT says or omits (clients-§9)
- client pin: an unset variable pins Forever, forever is accepted, retail is refused

### test_m6_fixes.lua (18)

- SM-01: a header-click collapse is stored through NS.SetByPath and sends one LAYOUT_CHANGED
- SM-01: the dock buttons (detach, dock) are stored through NS.SetByPath
- SM-01: a drag move renumbers every changed block through the seam with one LAYOUT_CHANGED
- SM-01: the row menu's Hide is stored through NS.SetByPath
- F-002: a hidden skill the catalog does not know is shown again by the Rows page Defaults
- F-012: standing up re-reads the stats and the bonuses, so no simulated value outlives a disable
- F-001: a skill line is matched on its skill-line ID, so a German client's lines land on their rows
- F-001: the adapter carries the struct's skill-line ID
- F-001: a crafting overlay casts the open spell by the name its spell ID resolves to
- F-003: a data repaint keeps a shown detached frame where it is (a drag is not re-anchored)
- F-003: the speed ticker rescans only when the speed changed
- F-004: every UNIT_* event is registered for the player alone, so a raid's auras never reach Lua
- F-011: the stat caps follow the level NS.Compat answers (the simulated character's in a session)
- F-005: Clear log asks first, and only an accept clears the stored history
- F-014: a log row from another day shows its date as well as its time
- F-015: switching to a profile with a lower cap does not trim the stored log; lowering the setting does
- F-010: on a library-absent load the stand-down still takes every bus target's events down
- F-016: the Master controls' Enable row names the brand

### test_fb2_chrome.lua (10)

- fb14: every catalog skill and every stat carries an in-game icon path
- fb14: a profession's icon is its spell's texture first, the catalog's path without one
- fb14: Compat.SpellTexture reads C_Spell first, then the global, else nil
- fb14: the row's icon is a trimmed texture, not two letters
- fb15: the attach mark is the detach mark turned 180 degrees
- fb16: one Expand / Collapse all control, beside the settings mark (AD-86: inward of it), showing what a click does
- fb16: SetAllCollapsed leaves the detached blocks alone and answers how many it changed
- fb17: the class icon's source: the atlas where the client has it, else the class sheet
- fb17: test mode's summary line names the sample character with its class icon
- fb17: live, the name is the player's through NS.Compat

### test_surface_parity.lua (12)

- parity: the Core stub publishes every NS member core/CoreSetup.lua publishes live
- parity: the DebugLog stub carries the whole live surface
- parity: the Options stub carries every helper the degraded build can reach
- parity: the Slash stub carries every dispatcher member the addon calls
- parity: the Launcher stub carries the whole live surface
- parity: the Lifecycle stub carries the whole live surface
- parity: the Bus stub carries the library's whole surface
- parity: the Schema stub carries the library's lib-level surface, and its instance a live one's
- parity: the Toast instance stub carries a live instance's whole surface
- parity: the Perf, Pool and Widgets stubs carry every member the addon reaches
- parity: the degraded load completes: options, slash and launcher answer without raising
- parity: library-absent, a data bar keeps its text and answers every method the addon calls

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_disabled.lua (9)

- disabled 1: the enabled addon registers something to stand down from
- disabled 2-3: writing `enabled` through the seam leaves NOTHING registered
- disabled 4: no timer is left armed
- disabled 5: every frame that was on screen is hidden, and Show refuses
- disabled 6: firing every baseline event writes nothing, says nothing, shows nothing
- disabled 7: every live verb answers, and each feature verb refuses on one line
- disabled 8: the launcher's clicks and the key bindings while disabled
- disabled 9: re-enabling restores the registration set from current state
- disabled 10: releasing ONE hold does not resurrect an addon the other holds down

### test_diagnostics.lua (9)

- diagnostics: the report carries this addon's ten sections and raises in none
- diagnostics: stood down, the state section says so and reads nothing else
- diagnostics: the section list is identity, settings, state, skin, the four domain sections, sim, rejected
- diagnostics: model counts the skills by category and learned state, the stats and the stores
- diagnostics: probe summarizes the skill API and the probed globals without expanding a header
- diagnostics: bonuses lists each skill's modifier and the cached sources, collecting none
- diagnostics: bonuses says so when nothing is cached yet
- diagnostics: layout prints the window and every block's stored state, detached ones flagged
- diagnostics: the settings section lists only the rows off their default, with their values

### test_diagnostics_contract.lua (9)

- diagnostics contract: both forms run the report
- diagnostics contract: the debug word is matched in any case
- diagnostics contract: both markers carry the brand and the end counts the report
- diagnostics contract: the report appends after what the console already holds
- diagnostics contract: the report lands with logging off and turns it on for the session
- diagnostics contract: an addon that opts out lands the report and leaves logging off (skipped: this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it)
- diagnostics contract: with logging already on, the report writes no second enable line
- diagnostics contract: both forms run while the addon is disabled
- diagnostics contract: no other name runs the report

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

### test_lizard_sighted.lua (8)

- lizard sighted: every hazard lizard loses a function over is neutralized
- lizard sighted: fields, strings, comments and look-alike names come through unchanged
- lizard sighted: a method definition is rewritten to its dot form with self
- lizard sighted: no line is added or removed, CRLF included
- lizard sighted: countFunctions counts the keyword, not strings, comments or longer names
- lizard sighted: listedCounts reads the per-file table, once per file
- lizard sighted: parity names every file whose counts differ, and only those
- lizard sighted: lizard lists every function of a hazard fixture once it is sanitized

### test_skin_values.lua (3)

- skin values: every host row carries its file, substring, why and a cause id or kit row category
- skin values: no typed value outside the kit's categories and the host's rows
- skin values: the check is falsifiable, a planted value of each shape is reported

### test_skin_switch.lua (25)

- skin switch: the check is falsifiable, a surface that redraws a literal is reported
- skin switch: the check is falsifiable, a bar whose texture never moves is reported
- skin switch: the main window changes
- skin switch: the main window changes with the Scope ignored
- skin switch: a detached block changes
- skin switch: a detached block changes with the Scope ignored
- skin switch: a merged window changes
- skin switch: a merged window changes with the Scope ignored
- skin switch: the journal changes
- skin switch: the journal changes with the Scope ignored
- skin switch: the trainer popup changes
- skin switch: the trainer popup changes with the Scope ignored
- skin switch: the alert toast changes
- skin switch: the alert toast changes with the Scope ignored
- skin switch: the row tooltip's bar changes
- skin switch: the row tooltip's bar changes with the Scope ignored
- skin switch: the broker feed tooltip changes
- skin switch: the broker feed tooltip changes with the Scope ignored
- skin switch: the broker feed tooltip in the Classic style changes
- skin switch: the broker feed tooltip in the Classic style changes with the Scope ignored
- skin switch: the waypoint arrow changes
- skin switch: the waypoint arrow changes with the Scope ignored
- skin switch: a settings list row's eye marks changes
- skin switch: the debug console changes
- skin switch: the debug console changes with the Scope ignored

### test_client_globals.lua (3)

- client globals: no call of a global a client lacks
- client globals: every allowlist row has a reason and a finding to excuse
- client globals: the check is falsifiable, a planted bare call is flagged for both clients

## Totals

| Suite | Cases |
|-------|------:|
| test_loadorder.lua | 6 |
| test_schema.lua | 6 |
| test_options.lua | 16 |
| test_template_rows.lua | 9 |
| test_row_display.lua | 8 |
| test_database.lua | 3 |
| test_bus.lua | 3 |
| test_slash.lua | 6 |
| test_mainwindow.lua | 9 |
| test_launcher.lua | 4 |
| test_keybinds.lua | 4 |
| test_locale.lua | 8 |
| test_skinsetup.lua | 5 |
| test_perf.lua | 2 |
| test_probe.lua | 10 |
| test_probe_sections.lua | 11 |
| test_skilldata.lua | 27 |
| test_trainers.lua | 36 |
| test_trainer_probe.lua | 18 |
| test_helpers.lua | 8 |
| test_bonuses.lua | 16 |
| test_statdata.lua | 17 |
| test_bar.lua | 14 |
| test_bars_live.lua | 18 |
| test_bars_round2.lua | 8 |
| test_class_first.lua | 5 |
| test_trainers_tabs.lua | 2 |
| test_detached_width.lua | 6 |
| test_bars_sizes.lua | 8 |
| test_round2_layout.lua | 7 |
| test_round2_icons.lua | 10 |
| test_round3.lua | 10 |
| test_round5.lua | 11 |
| test_round5_style.lua | 9 |
| test_round5_groups.lua | 28 |
| test_round5_snap.lua | 19 |
| test_round5_followups.lua | 27 |
| test_round6.lua | 53 |
| test_round7.lua | 32 |
| test_round8.lua | 22 |
| test_round9.lua | 14 |
| test_sr1.lua | 10 |
| test_blocks.lua | 10 |
| test_families.lua | 7 |
| test_tree.lua | 11 |
| test_windows.lua | 11 |
| test_interact.lua | 17 |
| test_sessionlog.lua | 6 |
| test_alts.lua | 6 |
| test_journal.lua | 22 |
| test_alerts.lua | 14 |
| test_template.lua | 3 |
| test_broker.lua | 16 |
| test_feeds.lua | 12 |
| test_pins.lua | 8 |
| test_ldb_tooltip.lua | 6 |
| test_reputations.lua | 13 |
| test_currencies.lua | 9 |
| test_statistics.lua | 15 |
| test_smw_review.lua | 15 |
| test_r5_feedback.lua | 16 |
| test_r5_join_resize.lua | 5 |
| test_r5_subdetach.lua | 9 |
| test_r5_journal.lua | 17 |
| test_r5_review.lua | 5 |
| test_r6_owner.lua | 18 |
| test_preview_trees.lua | 6 |
| test_polish.lua | 12 |
| test_preview.lua | 9 |
| test_sample_names.lua | 2 |
| test_sim.lua | 12 |
| test_sim_start_panel.lua | 5 |
| test_dropdown_selected.lua | 3 |
| test_window_chrome.lua | 15 |
| test_header_buttons.lua | 10 |
| test_tooltips.lua | 11 |
| test_no_foreverdb.lua | 7 |
| test_skin_defaults.lua | 8 |
| test_seams.lua | 5 |
| test_m5_seams.lua | 7 |
| test_m5_review.lua | 5 |
| test_m5_leftovers.lua | 14 |
| test_m6_fixes.lua | 18 |
| test_fb2_chrome.lua | 10 |
| test_surface_parity.lua | 12 |
| test_vendor_sync.lua | 3 |
| test_disabled.lua | 9 |
| test_diagnostics.lua | 9 |
| test_diagnostics_contract.lua | 8 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_lizard_sighted.lua | 8 |
| test_skin_values.lua | 3 |
| test_skin_switch.lua | 25 |
| test_client_globals.lua | 3 |
| Skipped | 1 |
| **Total** | **1085** |
