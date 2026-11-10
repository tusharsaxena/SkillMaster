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
- options: the unverified mark follows its row
- options: the bar text template and the timer and marker switches reach the bar
- options: the flat color mode draws the Bar color, or the skin's while its companion is on
- options: the Bars page draws a live preview bar from NS.Bar, restyled by a write
- options: every new page renders on its first show without raising
- options: the journal's length is honored
- options: the library-absent load keeps every hand-written row; the composers' rows are the gap

### test_template_rows.lua (9)

- templates: no string row in the whole schema renders as an empty dropdown
- templates: the Broker page renders with no empty-dropdown line, one dropdown per feed
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
- slash: /sm lock and /sm unlock write `locked` through the seam and echo it
- slash: /sm test flips test mode, and again turns it off
- slash: the stub's one library string is pinned to the live major
- slash: on a library-absent load, /sm enable still lands through writeThrough

### test_mainwindow.lua (5)

- window: Toggle shows it, and again hides it
- window: the chrome is the shared one: the title, the wrapped close control, MEDIUM strata
- window: test mode shows the localized strip, and turning it off hides it
- window: combat ends test mode (preview-mode)
- window: locked refuses the drag; unlocked drags and saves the drop point

### test_launcher.lua (2)

- launcher: the object is the brand, the 128 px logo, registered once OnEnable runs
- launcher: left-click opens the settings panel through the same opener as /sm config

### test_keybinds.lua (4)

- keybinds: Bindings.xml is two CLICK lines in this addon's category, no header, no default
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
- skin: /sm skin opens the library's picker
- skin: Ignore settings panel defaults to on, Ignore fonts to off (skinning-§3)

### test_perf.lua (2)

- perf: windowRender is noted while a capture is on, and nothing is noted while off
- perf: every event-path bucket (detachedRender, skillScan, statScan, bonusRefresh) is reached

### test_probe.lua (9)

- probe: Run() answers the report's six keys
- probe: skillLines holds the raw returns of every line, the collapsed ones included
- probe: headers lists the localized header names
- probe: apis maps every probed name to a boolean
- probe: enchant carries the weapon enchant returns (a lure's time left)
- probe: /sm probe shows the report as JSON in the copy window
- probe: C_SkillInfo and C_Item are read first, a table-shaped line kept whole
- probe: a slot-taking C_Item.GetWeaponEnchantInfo does not error, and each try is recorded
- compat: WeaponEnchantInfo passes a slot and normalizes Forever's table to the 1.12 shape

### test_skilldata.lua (26)

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
- skills: WoW Forever's struct reads its real ranks, and a profession's child line is one row
- skills: a child line with an unknown name still maps through its parent skill-line ID

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

### test_bonuses.lua (16)

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
- bonuses: a blocked aura read never raises and keeps the last buffs read in full
- bonuses: an aura with a secret field is treated as a blocked read

### test_statdata.lua (16)

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
- stats: a secret read never raises and keeps the stat's last plain value, marked stale
- stats: leaving combat asks for a rescan (PLAYER_REGEN_ENABLED)

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

### test_bars_live.lua (18)

- bars live: the bar height reaches the window's rows and the preview, the detached height the blocks
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
- bars live: rank tier ticks hide and come back
- bars live: a tier tick draws above the fill, so a tick the rank has passed still shows
- bars live: threshold markers hide on a stat's bar and come back
- bars live: the expiry timer hides at once and comes back
- bars live: the spark hides when switched off and shows when on
- bars live: every Bars page slider commits while it moves, so a mouse wheel turn is written

### test_blocks.lua (10)

- blocks: the eight blocks, four skill categories then four stat groups
- test_blocks_detach_dock_roundtrip: a block leaves the window, gets its own frame and comes back
- blocks: a detached frame saves its drop point; locked refuses the drag
- test_rows_unlearned_variant: an unlearned skill is a dimmed row with its trainer and a Go button
- rows: initials, money and the riding trainer line
- rows: the color modes
- test_mainwindow_collapsed_persisted: collapsing a block is stored, survives a re-render and the header toggles it
- mainwindow: the title bar carries lock, journal, settings and close; the summary and legend show
- mainwindow: an empty model shows the empty state, and data hides it
- mainwindow: a skin switch restyles every bar, header and icon well, not only the values

### test_interact.lua (10)

- test_secure_overlay_deferred_in_combat: crafting overlays are made and moved only out of combat
- secure overlay: hiding the window hides its overlays; the stand-down takes them down
- interact: the click map (design §6.5)
- interact: shift-click links the row to chat; right-click opens the row menu
- test_rowtooltip_lines_fishing_lure: the lure, its timer, the session and the fishing helper
- rowtooltip: the session line is this skill's gains and rate; the ETA reads in hours
- rowtooltip: skinning names the mob level and the next breakpoint; a weapon its cap gap
- rowtooltip: Show draws on GameTooltip with the bar, Hide gives it back
- trainer popup: the faction's trainers, the selection and the waypoint button
- test_waypoints_fallback_order: TomTom, then the native pin, then chat

### test_sessionlog.lua (5)

- test_sessionlog_ring_cap: the log keeps the newest 500 skill-ups in db.char.log
- test_sessionlog_eta: (max - rank) / the skill's own rate over this session's gains
- sessionlog: Gains counts points this session, per skill too; Rate is points an hour
- sessionlog: a SKILL_UP on the bus lands in the log with the zone
- sessionlog: a malformed skill-up is refused, never stored

### test_alts.lua (4)

- test_alts_snapshot_two_word_name: the key is realm-key, then the whole two-word name
- alts: a half-loaded (empty) model keeps the skills the last snapshot had
- alts: List puts this character first, then by name; Forget drops one
- alts: a burst of SKILLS_UPDATED is one debounced snapshot; PLAYER_LOGOUT snapshots at once

### test_journal.lua (10)

- journal: /sm journal toggles it, through the one toggle handler
- journal: the chrome is the shared one: the title, the wrapped close control, the window tier
- journal: the tabs switch panels: Session Log first, then Alts
- journal: the log lists skill-ups newest first, with the session's gains, and Clear empties it
- journal: a SKILLS_UPDATED repaints an open log
- journal: the alts grid shows a character per row and a mini bar per skill it has
- journal: right-click on a character asks before forgetting it
- journal: an unlocked drag saves the drop point; Reset position forgets it
- journal: the stand-down hides it
- journal: durations and ETAs read as the mockup writes them

### test_alerts.lua (11)

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

### test_template.lua (3)

- test_template_tokens: every token of design §6.7 renders from the context
- test_template_tokens: no pin falls back to the last skill-up, then to the lowest profession
- test_template_unknown_token_empty: unknown tokens and missing data render empty

### test_broker.lua (9)

- broker: four data sources, separate from the launcher object
- broker: each feed renders its default template
- broker: the weapons feed follows the main hand's weapon class
- test_broker_flash_reverts: a skill-up flashes its feeds, then the template comes back
- broker: the All tooltip lists every category with mini bars, bonuses and gains
- broker: the Weapons tooltip is the weapon skills plus Defense; Stats is the four groups
- broker: clicks follow design §6.5 and never touch a secure frame
- broker: a crafting row without ShowAndScrollTo still opens the main window
- broker: stood down, every feed reads Off and its tooltip says so; standing up re-renders

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

### test_preview.lua (6)

- preview: test mode draws the sample Dwarf Hunter in every block
- preview: the bonuses are the sample's: the Dwarf racial on Guns, the lure's timer on Fishing
- preview: the broker, the summary line and the row tooltip read the sample
- preview: the Journal's session log and alts are the sample's
- preview: test mode off restores the live data in every source
- preview: combat ends test mode and puts the live data back

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

### test_seams.lua (5)

- test_seam_broker_crafting_row_scrolls_window: a broker crafting row expands, shows and scrolls to it
- test_seam_broker_unlearned_row_opens_trainer_popup: the popup gets the skill key, not a table
- test_seam_alert_click_sets_waypoint: a cap toast's click goes through the real NS.Waypoints
- test_seam_mini_bars_are_the_bar_widget: the broker tooltip draws NS.Bar's mini style (the Journal's: test_journal)
- test_seam_title_bar_journal_button: the main window's journal mark toggles the Journal

### test_m5_seams.lua (7)

- m5 seam: the broker's right-click opens the registered Broker page through the library's opener
- m5 seam: Skills > Hint under the row drives the row hint live, off by default
- m5 seam: Skills > Gathering and fishing hints switches the tooltip's helper lines, apart from the row hint
- m5 seam: Layout > Weapon skills > Equipped and below cap only refilters the detached block live
- m5 seam: journal.size is the grip's drag state, never a row
- m5 seam: Journal > log length caps the live log, also while a simulation's override is in place
- m5 seam: diagnostics report test mode's sample data in state, model and sim

### test_m5_review.lua (6)

- profile switch: the window's bars restyle from the new profile with the same row set
- profile switch: the broker feeds re-read the new profile's templates
- profile switch: the Journal takes the new profile's drop point and size
- profile reset: one LAYOUT_CHANGED reaches the look listeners (the Bars preview, the Journal)
- bars preview: the fill is the Fishing row's own color, and a palette or mode edit reaches it
- test mode: a sample row's menu cannot pin the sample skill into the character's store

### test_m5_leftovers.lua (14)

- skin colors: every HUD color companion defaults on, in the defaults and on its row
- skin colors: the category and bonus owner tokens carry the mockup's colors
- skin colors: following the skin, each category fills in its own token, not one shared fill
- settings: fill direction, both strata and the column count each have a live row
- settings: a strata row's tooltip is the library's, over the row's own values (frame-layering-§1)
- fill direction: right to left anchors the fill, the bonus and the spark on the bar's right edge
- strata: the window and a detached block take their rows' strata live; overlays sit in the host's
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
- F-002: a hidden skill the catalog does not know is shown again by the Skills page Defaults
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

### test_surface_parity.lua (11)

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

### test_diagnostics.lua (8)

- diagnostics: the report carries this addon's ten sections and raises in none
- diagnostics: stood down, the state section says so and reads nothing else
- diagnostics: the section list is identity, settings, state, skin, the four domain sections, sim, rejected
- diagnostics: model counts the skills by category and learned state, the stats and the stores
- diagnostics: probe summarizes the skill API and the probed globals without expanding a header
- diagnostics: bonuses lists each skill's modifier and the cached sources, collecting none
- diagnostics: bonuses says so when nothing is cached yet
- diagnostics: layout prints the window and every block's stored state, detached ones flagged

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

### test_skin_switch.lua (18)

- skin switch: the check is falsifiable, a surface that redraws a literal is reported
- skin switch: the main window changes
- skin switch: the main window changes with the Scope ignored
- skin switch: a detached block changes
- skin switch: a detached block changes with the Scope ignored
- skin switch: the journal changes
- skin switch: the journal changes with the Scope ignored
- skin switch: the trainer popup changes
- skin switch: the trainer popup changes with the Scope ignored
- skin switch: the alert toast changes
- skin switch: the alert toast changes with the Scope ignored
- skin switch: the row tooltip's bar changes
- skin switch: the row tooltip's bar changes with the Scope ignored
- skin switch: the broker feed tooltip's mini bars changes
- skin switch: the broker feed tooltip's mini bars changes with the Scope ignored
- skin switch: the Bars page preview changes
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
| test_mainwindow.lua | 5 |
| test_launcher.lua | 2 |
| test_keybinds.lua | 4 |
| test_locale.lua | 8 |
| test_skinsetup.lua | 5 |
| test_perf.lua | 2 |
| test_probe.lua | 9 |
| test_skilldata.lua | 26 |
| test_trainers.lua | 12 |
| test_helpers.lua | 8 |
| test_bonuses.lua | 16 |
| test_statdata.lua | 16 |
| test_bar.lua | 10 |
| test_bars_live.lua | 18 |
| test_blocks.lua | 10 |
| test_interact.lua | 10 |
| test_sessionlog.lua | 5 |
| test_alts.lua | 4 |
| test_journal.lua | 10 |
| test_alerts.lua | 11 |
| test_template.lua | 3 |
| test_broker.lua | 9 |
| test_polish.lua | 12 |
| test_preview.lua | 6 |
| test_sim.lua | 12 |
| test_seams.lua | 5 |
| test_m5_seams.lua | 7 |
| test_m5_review.lua | 6 |
| test_m5_leftovers.lua | 14 |
| test_m6_fixes.lua | 18 |
| test_surface_parity.lua | 11 |
| test_vendor_sync.lua | 3 |
| test_disabled.lua | 9 |
| test_diagnostics.lua | 8 |
| test_diagnostics_contract.lua | 8 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| test_lizard_sighted.lua | 8 |
| test_skin_values.lua | 3 |
| test_skin_switch.lua | 18 |
| test_client_globals.lua | 3 |
| Skipped | 1 |
| **Total** | **441** |
