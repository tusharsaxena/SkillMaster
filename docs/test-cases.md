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

### test_skilldata.lua (22)

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

### test_skin_switch.lua (5)

- skin switch: the check is falsifiable, a surface that redraws a literal is reported
- skin switch: the main window changes
- skin switch: the main window changes with the Scope ignored
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
| test_skilldata.lua | 22 |
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
| test_skin_switch.lua | 5 |
| test_client_globals.lua | 3 |
| Skipped | 1 |
| **Total** | **148** |
