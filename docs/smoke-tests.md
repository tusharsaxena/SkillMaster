# Smoke tests — Ka0s Skill Master

In-game checks on **WoW Forever** (client 1.60.1). The owner runs them; an agent never marks one
passed (clients-§6, testing). Each check names what to do and what you should see. Every check
runs on WoW Forever, the one client this addon ships on, except SM-LOAD-2, the not-listed-on-Retail
check (clients-§9).

## Design §9 coverage

The design's in-game checklist (`docs/superpowers/specs/2026-11-10-skill-master-design.md` §9) and
the checks below that cover each item:

| Design §9 item | Checks |
|---|---|
| The probe | SM-PROBE-1 |
| Each category | SM-DISP-1, SM-TEST-1 |
| The lure timer | SM-DISP-2, SM-SIM-1 |
| Click targets in and out of combat | SM-DISP-5, SM-DISP-6, SM-DISP-8 |
| TomTom on and off | SM-DISP-7, SM-OPT-5, SM-SEAM-2 |
| Each skin | SM-SKIN-1, SM-SKIN-2 |
| Detach and dock | SM-DISP-3, SM-OPT-3 |
| Feeds in a broker display | SM-LDB-2, SM-SEAM-1, SM-SEAM-4 |

## Load

- **SM-LOAD-1** Log in on Forever. The AddOns list shows Ka0s Skill Master with its logo; no Lua error.
- **SM-LOAD-2** On a **Retail** client, open the AddOns list. Ka0s Skill Master is **not listed**
  (the `ExcludeLoadGameType: standard` gate, clients-§9). This also settles the open evolution the
  standard recorded for the Forever load gate.
- **SM-LOAD-3** On a fresh profile the skin picker opens once, previewing in test mode; it defaults to
  WoW Forever. Apply or close it; it does not open again on that profile.

## Window

- **SM-WIN-1** `/sm toggle` opens the window titled Skill Master; Escape and the close button hide it.
- **SM-WIN-2** Drag it, `/reload`: it reopens where it was dropped. `/sm lock`: it no longer drags.
- **SM-WIN-3** `/sm test`: an amber band says the skills shown are sample data. Enter combat: the
  band disappears and test mode is off.
- **SM-WIN-4** Bind keys under Options → Keybindings → Ka0s Skill Master: *Toggle skills window* toggles
  the window and *Toggle journal* toggles the Journal. `/sm disable`: each press refuses on one line.

## Display (M3)

- **SM-DISP-1** Open the window: Primary, Secondary, Weapon and Other blocks, then the stat blocks
  (Spell and Defense collapsed). Bars fill rank / max; profession bars show ticks at 75 / 150 / 225.
- **SM-DISP-2** Put on a fishing lure: the Fishing bar gains a teal segment, the text reads
  `rank +N / max`, a timer counts down beside it and the segment goes when the lure runs out. A
  Dwarf's Guns shows a blue (permanent) +5 segment that stops at the bar's end.
- **SM-DISP-3** Click a block header: it collapses; `/reload`: still collapsed. Click the header's
  detach control: the block leaves the window into its own frame; drag it, `/reload`, it stays put;
  its dock control puts it back in its old place.
- **SM-DISP-4** Hover a row: the tooltip shows the numbers, the bar, the bonuses (a lure with its
  time left), the next rank and trainer, a weapon's cap gap, Skinning's mob level, the gathering
  nodes and, for Fishing, the zone's need. Hover a stat: its markers and scale.
- **SM-DISP-5** Click Leatherworking (or any craft, Cooking, First Aid, Mining's Smelting): its
  window opens. Click Skinning, a weapon, Defense or Riding: Character → Skills. Click a stat:
  the paper doll. Shift-click a row with the chat box open: `[Guns 105 +5 / 110]` is inserted.
  Right-click: the row menu (pin, waypoint, trainers, hide).
- **SM-DISP-6** In combat, click a crafting row: nothing opens and one line says why; no "action
  blocked" error. Detach a block in combat: it moves only when combat ends. Escape the window in
  combat: no error, and no invisible button is left where the rows were after combat.
- **SM-DISP-7** An unlearned weapon row reads `Not learned · <trainer>, <city> · 10s`. Its Go button
  (or a click) opens the trainer popup: the faction's weapon masters, the unverified warning. Set
  waypoint with TomTom loaded (a TomTom arrow), without it (a map pin), and Print to chat.
- **SM-DISP-8** Open the window and the Journal over it, then click the window: it comes to the
  front and a crafting row still opens its profession (the overlay was re-leveled above the rows).
  Drag the window by its title: no invisible button is left at the old place, and at the drop
  clicking Leatherworking opens it.
- **SM-DISP-9** Detach the Weapon block: the equipped weapon (a Dwarf Hunter's Guns) reads
  `> Guns` in gold. With `layout.blocks.weapon.belowCapOnly` on, only the equipped weapon and the
  skills below their cap show; swap weapons and the marker follows. With `skills.helperHint` on, the
  Skinning, Mining, Herbalism and Fishing rows carry one muted hint line under the bar.
## Journal

- **SM-JRN-1** `/sm journal` opens "Skill Master · Journal" with Session Log and Alts tabs; Escape and
  the close mark close it; drag it, `/reload`, and it opens where it was dropped.
- **SM-JRN-4** Drag the Journal's bottom-right grip continuously: the window follows the pointer
  without lag and never gets smaller than it opened; release: more log rows show. `/reload`: it
  opens at the dragged size. Lock the window (`/sm lock`): the grip does nothing.
- **SM-JRN-2** Gain a skill point: a row appears at the top of Session Log with the time, the skill,
  `old -> new` and the zone, and the session card counts it. A second gain of the same skill gives it
  an ETA. Clear log empties the list; New session sets the count back to +0.
- **SM-JRN-3** Log in a second character, then back: Alts lists both, each under its whole two-word
  name, this character first, with mini bars per skill; Professions / Weapons / Other filter the
  columns. Right-click the other character, confirm, and it is gone.

## Integration (M3 + M4)

- **SM-SEAM-1** Collapse the Primary block and scroll the window to the top. Hover the All feed and
  click Leatherworking in its tooltip: the window opens, Primary expands and the body scrolls to
  the row. Click an unlearned weapon in the Weapons feed: the trainer popup opens on that skill.
- **SM-SEAM-2** The broker tooltip's and the Journal's mini bars match the window's bar colors;
  switch skins and reopen both: they follow. Click the cap toast with TomTom loaded: an arrow.
- **SM-SEAM-3** Click the main window's journal mark: the Journal opens; again: it closes.
- **SM-SEAM-4** Hover a feed, then move straight onto another addon's tooltip owner (a bag item):
  the other tooltip stays up (the feed's leave check hides only its own). The feed tooltip's footer
  reads `Click label: toggle window · Click row: open its window · Right-click: feed options`;
  right-click the feed opens the settings on the Broker page (the main page until it exists).

## Launcher and settings

- **SM-LDB-1** The minimap button shows the logo. Left-click opens the settings; right-click shows
  Enabled, Locked, Test mode, Sim mode, Show window. Hovering shows the status tooltip.
- **SM-LDB-2** In a broker display (Titan Panel, ChocolateBar or Bazooka), add the four Skill Master
  feeds: All, Professions, Weapons and Stats each show their template's text. Gain a skill point:
  All and that skill's feed read `^ <skill> <new>` for five seconds, with the up chevron. Hover each
  feed: its tooltip lists the rows with mini bars.
- **SM-CFG-1** Settings → AddOns → Ka0s Skill Master: the landing page lists the slash commands; General
  has Master controls, Skin and Keybindings tabs; Profiles works.
- **SM-CFG-2** Uncheck Minimap button: the button hides, and Reset all settings does not bring it back.

## Settings pages (T5.1)

- **SM-OPT-1** Open Bars: the live preview reads Fishing 107 +25 / 150 with 4:12. Drag Bar height
  and change Color mode to Flat with Use the skin's color off: the preview and the open window
  restyle at once.
- **SM-OPT-2** Bars > Bar > Border: turn Use the skin's border off, pick a non-Solid style and a
  thickness of 3: every bar's edge changes. Bars > Text: turn Use the skin's font off, pick a font.
- **SM-OPT-3** Layout > Block order: drag Weapon Skills to the top; the window reorders. Layout >
  Blocks: turn off Dock in the window for one block, it pops out; turn it back on in combat and it
  docks after combat.
- **SM-OPT-4** Hide a skill from its row menu, then Skills > Professions (or Weapons and other):
  untick its Hide row and the row comes back.
- **SM-OPT-5** Trainers and Waypoints: Waypoint method Chat only, click an unlearned row's Go: only
  the chat line, no TomTom arrow. Turn Mark unverified trainers off: no "(unverified)".
- **SM-OPT-6** Each page's Defaults button restores the page; the window repaints once.
- **SM-OPT-7** (M5 integration) Right-click a broker feed: the Broker settings page opens, not
  the landing page. Skills > General: tick Hint under the row and the Skinning, Mining, Herbalism and
  Fishing rows gain their hint line at once; untick Gathering and fishing hints and the tooltips lose
  their helper lines while the row hint stays. Detach Weapon Skills, then Layout > Blocks > Weapon
  skills > Equipped and below cap only: the detached frame drops the capped, unequipped weapons.

## Settings closing M5

- **SM-OPT-8** Bars > Bar > Fill > Fill direction: Right to left. Every bar (the window, a detached
  block, a row tooltip, the Journal's Alts and a broker tooltip) fills from its right edge, the bonus
  segment running on to its left and the spark at the fill's left end; tier ticks and markers sit
  mirrored. Left to right puts them back.
- **SM-OPT-9** Layout > Window > Columns: Two columns. The window doubles in width and the docked
  blocks fill two columns side by side; detach and dock a block and the columns re-balance. Back to
  One column: one column, the old width.
- **SM-OPT-10** Layout > Window > Window strata: Low. Open a bag or the character frame over the
  window: it covers the window. High: the window draws over them. With High set, click an unlearned
  row's Go: the trainer popup still opens over the window. With the window at Low, click
  Leatherworking: it still opens (the crafting overlay follows the window's strata). Detached block
  strata does the same for a detached block.
- **SM-OPT-11** Bars > Colors: with Use the skin's colors on (the default) the bars show the
  mockup's category colors; turn it off and change the Weapon skills swatch: the weapon bars take it.
- **SM-OPT-12** During a simulation (`/sm sim`, start the trip), right-click a row: Pin to the
  broker feed is grayed out and does nothing. With test mode on, the All feed starts `Fishing 107+25/150`
  and a `{equippedWeapon}` template reads `Guns 105+5/110`, whatever your own pin and weapon.

## Disabled

- **SM-OFF-1** `/sm disable`: the window hides, `/sm toggle` answers one disabled line, the key
  binding does nothing, the right-click menu grays all but Enabled. `/sm enable` restores it.

## Test mode and the simulator

- **SM-TEST-1** `/sm test`: the window, a detached block, the broker feeds and the Journal all show
  Ember Ironsong, the level-22 Dwarf Hunter (Leatherworking 146/150, Fishing 107 +25 with a lure
  timer near 4:12, Guns 105 +5, Fist Weapons, Polearms, Thrown and Riding unlearned), the summary
  reads "Lv 22 · Dwarf Hunter" and the strip says the data is sample data. `/sm test` again: your
  own character everywhere.
- **SM-SIM-1** Tick General → Master controls → Sim mode: the step panel opens beside the window and
  the box stays ticked. Start the fishing trip: every 3 s a step plays; a skill-up flashes the broker
  and adds a Journal line, the lure puts a teal segment on Fishing, the mount moves Run Speed to
  160%. The window shows the cyan simulation strip.
- **SM-SIM-2** Untick Sim mode (or the launcher's Sim mode entry, or `/sm sim stop`): the session
  ends, your own skills, Journal log and broker gains are back, and `/reload` shows nothing of the
  session was saved. Entering combat or `/sm disable` ends a session too; test mode refuses while one
  runs and the simulator refuses in test mode, combat, an instance or a group.
- **SM-SIM-3** With test mode on, `/sm diagnostics`: the state line reads `testMode=true`, the model
  section `preview source=on` and the sim section `preview data=true`; during a simulation the state
  line reads `simMode=true` and the sim section names the scenario and its step.


## Probe

- **SM-PROBE-1** `/sm probe`: a copy window opens with a JSON report, `skillLines` holding every
  skill (a collapsed header in the Skills tab is collapsed again afterwards). Copy it and send it to
  the author; it settles the assumed rows in `docs/midnight-quirks.md`.

## Skins and diagnostics

- **SM-SKIN-1** `/sm skin`: pick Ka0s Default, Apply. The window and the debug console change look.
- **SM-SKIN-2** `/sm skin` once per shipped skin (every entry of the picker, WoW Forever included),
  Apply each: the window, a detached block, the Journal, the trainer popup, an alert toast and the
  broker tooltip all restyle, and every character on them draws (no empty boxes in the legend, the
  block headers' fallback marks, the Journal's `old -> new` or the stat tooltip's marker lines). The
  category colors stay told apart (Primary blue, Secondary green, Weapon orange, Other violet) and
  the lure's teal and the racial's blue bonus segments keep their own colors.
- **SM-DIAG-1** `/sm diagnostics`: the report appears in the debug console with the ten sections
  (identity, settings, state, skin, model, probe, bonuses, layout, sim, rejected).
