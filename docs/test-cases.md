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
- slash: /skm lock and /skm unlock write `locked` through the seam and echo it
- slash: /skm test flips test mode, and again turns it off
- slash: the stub's one library string is pinned to the live major
- slash: on a library-absent load, /skm enable still lands through writeThrough

### test_mainwindow.lua (5)

- window: Toggle shows it, and again hides it
- window: the chrome is the shared one: the title, the wrapped close control, MEDIUM strata
- window: test mode shows the localized strip, and turning it off hides it
- window: combat ends test mode (preview-mode)
- window: locked refuses the drag; unlocked drags and saves the drop point

### test_launcher.lua (2)

- launcher: the object is the brand, the 128 px logo, registered once OnEnable runs
- launcher: left-click opens the settings panel through the same opener as /skm config

### test_keybinds.lua (2)

- keybinds: Bindings.xml is one CLICK line in this addon's category, no header, no default
- keybinds: the bound button runs the window's one toggle handler

### test_skinsetup.lua (4)

- skin: this addon is a registered owner wearing its stored choice
- skin: writing the skin row applies it through the owner
- skin: the picker's preview is the test mode (skinning-§10)
- skin: /skm skin opens the library's picker

### test_perf.lua (1)

- perf: windowRender is noted while a capture is on, and nothing is noted while off

### test_probe.lua (7)

- probe: Run() answers the report's six keys
- probe: skillLines holds the raw returns of every line, the collapsed ones included
- probe: headers lists the localized header names
- probe: apis maps every probed name to a boolean
- probe: enchant carries the weapon enchant returns (a lure's time left)
- probe: /skm probe shows the report as JSON in the copy window
- probe: C_SkillInfo and C_Item are read first, a table-shaped line kept whole

### test_skilldata.lua (24)

- skillcatalog: every vanilla profession, the 16 weapon lines, Defense, Lockpicking and Riding
- skillcatalog: kinds, tiers and the window each row opens
- skillcatalog: the localized-name map answers each enUS name and the racial riding names
- skillcatalog: both data tables record a source and stay unverified until the smoke pass
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

### test_trainers.lua (12)

- test_trainers_fist_alliance: Alliance fist weapons are taught in Ironforge and Darnassus
- test_trainers_fist_alliance: the home city of the player's race sorts first
- trainers: Horde fist weapons come from Sayoc in Orgrimmar only
- trainers: For reads the player's faction and race when none is passed
- trainers: Neutral trainers are on both factions' lists
- trainers: an unknown key answers an empty list, never an error
- trainers: every record is unverified and names its source
- test_trainers_next_rank_at_cap: Leatherworking 150/150 at level 22 trains Expert
- trainers: NextRank answers nil at Artisan and for a skill with no ranks
- trainers: NextRank's skill gate (Journeyman wants 50)
- test_trainers_riding_level_gate: riding 75 opens at 40, 150 at 60
- test_trainers_riding_level_gate: the race's own riding trainer sorts first

### test_helpers.lua (8)

- test_helpers_skinnable_level: 122 -> 24, 100 -> 20, 50 -> 15, 1 -> 10
- test_helpers_fishing_need_unknown_nil: a zone the table lacks answers nil
- helpers: FishingNeed answers the getaway-free skill for a known zone
- helpers: FishingNeed prefers the uiMapID over the name
- helpers: Nodes lists what the rank can gather and the next node up
- helpers: Nodes at the top has no next node, and an unknown key answers nil
- helpers: WeaponCap is five per level
- helpers: FishingNeedHere reads the map ID first, then the zone text

### test_bonuses.lua (14)

- bonuses: lure on the pole is one temp enchant source with its expiry
- bonuses: a Dwarf's Guns +5 is one permanent racial source
- bonuses: modifier 12 with 7 attributed leaves one Other 5
- bonuses: no modifier, no sources
- bonuses: an unknown or unlearned skill answers an empty breakdown
- bonuses: the '+N <Skill>' item pattern, case-insensitive, other stats ignored
- bonuses: a skill buff is a temp source with its aura's expiry
- bonuses: more attributed than the modifier shows a negative Other, never a silent mismatch
- bonuses: the 1.12 globals and a scanning tooltip are the fallback readers
- bonuses: inventory change publishes BONUSES_UPDATED; the 1 s ticker runs only while a temp bonus lives
- racials: the table is Forever data, unverified, with a source, +5 per racial skill
- racials: every racial skill key is a catalog key
- bonuses: UNIT_AURA re-reads the buffs only, never the equipped tooltips
- bonuses: a temp '+N' line that names no skill starts no ticker

### test_statdata.lua (14)

- statdata (primary_vs_highest): the primaries scale against the highest, Agi 112 -> 100%, Str 48 -> 42.9%
- statdata: attack power is base plus buffs against 400, crit against 30%
- statdata (hit_markers): hit scales to 9% with markers at 5% and 9%, spell hit to 16%
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

### test_bar.lua (10)

- bar: a bonus past the cap clamps the base, draws to the end and keeps the full text (Review Focus 4)
- bar: the bonus segment wears the temp or the permanent color
- bar: an empty cap (an unlearned skill) draws nothing and raises nothing
- bar: ticks at or beyond the cap are dropped
- bar: markers keep the end and drop what is past it
- bar: the timer formats m:ss and h:mm:ss
- bar: SetTimer shows the time left, ticks it, and SetTimer(nil) disarms the OnUpdate
- bar: a timer that runs out clears itself
- bar: the resolved style reads the profile and the skin's tokens
- bar: the pool hands bars back in order and clears their timers on release

### test_blocks.lua (9)

- blocks: the eight blocks, four skill categories then four stat groups
- test_blocks_detach_dock_roundtrip: a block leaves the window, gets its own frame and comes back
- blocks: a detached frame saves its drop point; locked refuses the drag
- test_rows_unlearned_variant: an unlearned skill is a dimmed row with its trainer and a Go button
- rows: initials, money and the riding trainer line
- rows: the color modes
- test_mainwindow_collapsed_persisted: collapsing a block is stored, survives a re-render and the header toggles it
- mainwindow: the title bar carries lock, journal, settings and close; the summary and legend show
- mainwindow: an empty model shows the empty state, and data hides it

### test_interact.lua (9)

- test_secure_overlay_deferred_in_combat: crafting overlays are made and moved only out of combat
- secure overlay: hiding the window hides its overlays; the stand-down takes them down
- interact: the click map (design §6.5)
- interact: shift-click links the row to chat; right-click opens the row menu
- test_rowtooltip_lines_fishing_lure: the lure, its timer, the session and the fishing helper
- rowtooltip: skinning names the mob level and the next breakpoint; a weapon its cap gap
- rowtooltip: Show draws on GameTooltip with the bar, Hide gives it back
- trainer popup: the faction's trainers, the selection and the waypoint button
- test_waypoints_fallback_order: TomTom, then the native pin, then chat

### test_surface_parity.lua (10)

- parity: the Core stub publishes every NS member core/CoreSetup.lua publishes live
- parity: the DebugLog stub carries the whole live surface
- parity: the Options stub carries every helper the degraded build can reach
- parity: the Slash stub carries every dispatcher member the addon calls
- parity: the Launcher stub carries the whole live surface
- parity: the Lifecycle stub carries the whole live surface
- parity: the Bus stub carries the library's whole surface
- parity: the Schema stub carries the library's lib-level surface, and its instance a live one's
- parity: the Perf, Pool and Widgets stubs carry every member the addon reaches
- parity: the degraded load completes: options, slash and launcher answer without raising

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
- disabled 8: the launcher's left-click and the key binding while disabled
- disabled 9: re-enabling restores the registration set from current state
- disabled 10: releasing ONE hold does not resurrect an addon the other holds down

### test_diagnostics.lua (2)

- diagnostics: the report carries this addon's five sections and raises in none
- diagnostics: stood down, the state section says so and reads nothing else

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

- skin values: every host row carries its file, substring, why and cause id
- skin values: no typed value outside the kit's categories and the host's rows
- skin values: the check is falsifiable, a planted value of each shape is reported

### test_skin_switch.lua (9)

- skin switch: the check is falsifiable, a surface that redraws a literal is reported
- skin switch: the main window changes
- skin switch: the main window changes with the Scope ignored
- skin switch: a detached block changes
- skin switch: a detached block changes with the Scope ignored
- skin switch: the trainer popup changes
- skin switch: the trainer popup changes with the Scope ignored
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
| test_database.lua | 3 |
| test_bus.lua | 3 |
| test_slash.lua | 6 |
| test_mainwindow.lua | 5 |
| test_launcher.lua | 2 |
| test_keybinds.lua | 2 |
| test_skinsetup.lua | 4 |
| test_perf.lua | 1 |
| test_probe.lua | 7 |
| test_skilldata.lua | 24 |
| test_trainers.lua | 12 |
| test_helpers.lua | 8 |
| test_bonuses.lua | 14 |
| test_statdata.lua | 14 |
| test_bar.lua | 10 |
| test_blocks.lua | 9 |
| test_interact.lua | 9 |
| test_surface_parity.lua | 10 |
| test_vendor_sync.lua | 3 |
| test_disabled.lua | 9 |
| test_diagnostics.lua | 2 |
| test_diagnostics_contract.lua | 8 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_lizard_sighted.lua | 8 |
| test_skin_values.lua | 3 |
| test_skin_switch.lua | 9 |
| test_client_globals.lua | 3 |
| Skipped | 1 |
| **Total** | **230** |
