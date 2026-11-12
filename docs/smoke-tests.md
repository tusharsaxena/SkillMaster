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
| Detach and dock | SM-DISP-3, SM-DISP-11, SM-OPT-3 |
| Feeds in a broker display | SM-LDB-2, SM-SEAM-1, SM-SEAM-4, SM-DISP-18 |

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
  window opens. Click Skinning or Fishing: its own window (Camping) opens. Click a weapon, Defense or
  Riding: Character → Skills, with that skill selected (`/sm debug` logs `[Click] Skills tab for <key>:
  line <n>, selected by <call>`). Click a stat:
  the paper doll. Shift-click a row with the chat box open: `[Guns 105 +5 / 110]` is inserted.
  Right-click: the row menu (pin, waypoint, trainers, hide).
- **SM-DISP-6** In combat, click a crafting row: nothing opens and one line says why; no "action
  blocked" error. Detach a block in combat: it moves only when combat ends. Escape the window in
  combat: no error, and no invisible button is left where the rows were after combat.
- **SM-DISP-7** An unlearned weapon row reads `Not learned · <trainer>, <city> · 10s`. A click on
  the row (its action mark included) opens the trainer popup: the faction's weapon masters, the unverified warning. Set
  waypoint with TomTom loaded (a TomTom arrow), without it (a map pin), and Print to chat.
- **SM-DISP-8** Open the window and the Journal over it, then click the window: it comes to the
  front and a crafting row still opens its profession (the overlay was re-leveled above the rows).
  Drag the window by its title: no invisible button is left at the old place, and at the drop
  clicking Leatherworking opens it.
- **SM-DISP-9** Detach the Weapon block: the equipped weapon (a Dwarf Hunter's Guns) reads
  `> Guns` in gold. With `layout.blocks.weapon.belowCapOnly` on, only the equipped weapon and the
  skills below their cap show; swap weapons and the marker follows. With `skills.helperHint` on, the
  Skinning, Mining, Herbalism and Fishing rows carry one muted hint line under the bar.
- **SM-DISP-10** (FB-14) Every row draws an in-game icon in a thin border of its color, never two
  letters: each profession its own spell icon, each weapon line, Defense, Lockpicking, Riding and
  each stat a fitting classic icon; an unlearned row's icon is gray; an alert toast draws the same
  icon. A line Skill Master does not know shows the question mark. Note any icon that draws blank
  or green: its catalog name is unverified (`defaults/SkillCatalog_Forever.lua`, `defaults/Stats_Forever.lua`).
- **SM-DISP-11** (FB-15) A docked block's header shows the detach mark (a box, its arrow out of the
  top right); a detached frame's dock control is the same mark turned round (the arrow into the
  bottom left). Both tint on hover.
- **SM-DISP-12** (FB-16, round 2) At the top right, between the settings mark and the close: one
  control. While any block is open it is Collapse all (inward arrows); click it and every block in
  the window folds, and it turns into Expand all (outward arrows). `/reload` keeps it; a detached
  block keeps its own state. Only the lock stands left of the title. At the narrowest Window width
  (320) the title stays centered, and the scroll bar sits inside the window's border.
- **SM-DISP-14** (round 3) Every skill row (crafting, gathering, weapon, Other, not learned) carries
  the same action mark (an arrow into a box) at the right end, in one column with the block headers'
  detach marks, the bar ending the same few pixels before it; stat rows carry none. Clicking a
  crafting row's mark (or anywhere on the row) opens the
  profession out of combat (`/sm debug` logs `[Click] crafting overlay ... cast ...`), and in combat
  says why it cannot. Fishing's lure timer sits inside its bar's right end. Detach a block: its title sits
  in the middle of the band, and the first and last rows have a little room above and below.
- **SM-DISP-15** (round 2) Bars > Marks: tick Rank tier colors. Every profession bar draws to 300
  (Leatherworking 121/150 fills two fifths): Apprentice to 75 in the category's own color, each tier
  after it a shade darker; the text still reads the real cap. A weapon bar is unchanged. Colors >
  Color mode By progress: the tiers go and the bars fill to their caps again.
- **SM-DISP-16** (round 2) Right-click Cooking > Pin to the broker feed with a `{pinned}` feed text:
  the feed shows Cooking at once.
- **SM-DISP-17** (round 2) Hover the broker feed: each section sits under the window's block title
  (Primary Professions, Weapon Skills, ...) on a header band, every other row is striped, every
  skill name is white (an unlearned one muted), the bars a little thicker and the lines a little
  taller than before, in the window's bar colors. Then hover an item: its tooltip has no band or
  stripe left on it.
- **SM-DISP-18** (round 2) Hover the broker feed, then move down its rows: the row under the pointer
  takes the window's hover color, over its stripe and under its text, and loses it as the pointer
  moves on. Click a stat row: the character panel opens; a weapon row: Skills; an unlearned row: the
  trainer popup; a crafting row: the main window, scrolled to it.
- **SM-DISP-19** (round 2) The Weapon Skills header shows no cap line beside its title. Every block
  header's detach mark is the title's color, and lights up under the pointer. Point at a row's
  action mark: it lights up the same way, and goes back when the pointer moves off it.
- **SM-DISP-20** (round 2) Out of combat, click a crafting row (Leatherworking, Cooking, First Aid)
  once: its profession window opens on the first click. Open a bag over a crafting row and click the
  bag there: the bag takes the click, and no profession opens.
- **SM-DISP-21** (round 3) Each block header has a sort mark left of its detach mark. Click it on
  Weapon Skills: Value, highest first (Guns 120 on top, the not-learned rows still last), then lowest
  first, then Progress to max, then back to the default order. Layout > Blocks > Weapon Skills > Sort
  rows by shows the same choice; a detached block's band carries the mark too; the LDB tooltip lists
  Weapon Skills in the same order.
- **SM-DISP-22** (round 3) Collapse every block: the window keeps its height and its rows area goes
  empty. Layout > Shrink to fit the rows on: the window shrinks to its headers. The lock mark stands
  at the top right with the journal, settings, Expand / Collapse all and close marks; nothing left of
  the title.
- **SM-DISP-23** (round 3) The Defense / Lockpicking / Riding block reads Other skills in the
  window, the LDB tooltip, and on the Skills, Bars and Broker pages.
- **SM-DISP-24** (round 5, R5-5) Detach the Weapon block and drag it about the screen: every row's
  action mark (the arrow into a bracket) draws as crisp as the main window's wherever the frame is
  dropped, the bracket's right stroke as bright as its left, nothing cut at the right edge. Bars >
  Row height 21: the marks still sit centered in their rows, crisp.
- **SM-BRK-1** (round 3) With nothing pinned (a fresh character, or right-click a pinned row > Pin to
  the broker feed again to unpin), the feed reads `Professions and Skills`. Right-click a row in the
  LDB tooltip: the row menu (pin, waypoint, trainers, Hide in this tooltip); Hide removes it from the
  tooltip only. The bars end a short gap before the value column.
- **SM-ALR-1** (round 3) Level up with Unarmed at 4 points: no weapon toast (Alerts > Weapons that
  alert: Skip untrained weapons, the default). Equipped weapons only: only the worn weapons toast.
  Mute Bows on Alerts > Muted weapons: Bows never toasts.
- **SM-OPT-15** (round 2) Bars > Icons: Icon size 24 (capped at the row's height), Icon zoom 20 (the
  art fills the well), Border thickness 2; untick Use the row's color and Use the skin's color and
  pick a swatch: every icon takes it. Untick Show icons: the names move left into the icons' place.
- **SM-OPT-14** (round 2) Skills > Professions and Weapons and other: one boxed row per skill, its
  icon and name, an eye on the right; click the eye: the row dims and the skill leaves the window,
  click again to bring it back. Layout > Block order: the same boxes, a three-line handle on the
  left to drag, an eye that hides or shows the block.
- **SM-DISP-13** (FB-17) The summary line opens with the class icon, then the character's name in
  its class color, then `· Lv N · Race Class`. Note which icon source drew (the `classicon-<class>`
  atlas, or the class sheet), or none.
## Journal

- **SM-JRN-1** `/sm journal` opens "Skill Master · Journal" with Log and Alts tabs; Escape and
  the close mark close it (and any open range menu with it); drag it, `/reload`, and it opens where
  it was dropped.
- **SM-JRN-4** (FB-33) With the Journal where it first opens (centered), grab the bottom-right grip
  and drag slowly: the grip's corner stays under the pointer, the top-left corner stays put, and the
  window never leaps or grows faster than the pointer moves; it never gets smaller than it opened.
  Release: more log rows show, and on Alts more characters across once it is wide enough. `/reload`:
  it opens at the dragged size and place. Lock the window (`/sm lock`): the grip does nothing.
- **SM-JRN-2** (FB-32) Gain a skill point: a row appears at the top of Log with the date, the time,
  the skill, `old -> new` and the zone, every column inside its own width (a long skill or zone name
  ends in an ellipsis, nothing overlaps), and the summary card counts it. A second gain of the same
  skill gives it an ETA. With no ETA yet, the card's gray note wraps inside the card. Clear log
  empties the list; New session sets the count back to +0.
- **SM-JRN-5** (FB-32) The range dropdown above the summary card offers Current session, Last 1 day,
  Last 3 days, Last 7 days, Last 30 days and All time, in the addon's skin, All time on a new profile
  (round 4). Pick Last 7 days on a character with older skill-ups: the list and the summary card
  (titled "Skill-ups · Last 7 days", "Average: N a day over 7 days") both widen to them. `/reload`: the pick is kept, and the Journal settings page's *Log shows*
  row reads it; change it there and the open Journal follows.
- **SM-JRN-3** (FB-33) Log in a second character, then back: Alts shows both as columns, this
  character first, each name on two lines inside its column (the given name over the surname, in
  the class color); hovering a name shows its level, race, class, realm, faction and when it was
  last seen. The sub-tabs are the main window's blocks: Primary, Secondary, Weapons, Other, Base &
  Combat, Spell & Regen, Defense & Resists, Utility, all on one line; each lists every row its block
  does, a mini bar per value and a dash where a character has none (every stat of a character not
  logged in since this update is a dash until it logs in). Right-click the other character's name,
  confirm, and it is gone.
- **SM-JRN-6** (round 4) The Zone column shows a whole city name ("Stormwind City") without an
  ellipsis. With more skill-ups than fit, a thin scroll bar stands right of the Log table; drag it and
  the table scrolls; with few, it is gone. On Alts > Weapons with two characters, a scroll bar does
  the same, and every weapon either character can train is listed, "Unlearned" where a character
  has not learned it (a dash only where its class cannot train it). Other lists Riding.

## Integration (M3 + M4)

- **SM-SEAM-1** Collapse the Primary block and scroll the window to the top. Hover the Skill Master feed and
  click Leatherworking in its tooltip: the window opens, Primary expands and the body scrolls to
  the row. Click an unlearned weapon in the feed tooltip's Weapon section: the trainer popup opens on that skill.
- **SM-SEAM-2** The broker tooltip's and the Journal's mini bars match the window's bar colors;
  switch skins and reopen both: they follow. Click the cap toast with TomTom loaded: an arrow.
- **SM-SEAM-3** Click the main window's journal mark: the Journal opens; again: it closes.
- **SM-SEAM-4** Hover a feed, then move straight onto another addon's tooltip owner (a bag item):
  the other tooltip stays up (the feed's leave check hides only its own). The feed tooltip's footer
  reads `Click label: toggle window · Right-click label: options · Rows: click to open, right-click for the menu`;
  right-click the feed opens the settings on the Broker page (the main page until it exists).

## Launcher and settings

- **SM-LDB-1** The minimap button shows the logo. Left-click opens the settings; right-click shows
  Enabled, Locked, Test mode, Sim mode, Show window. Hovering shows the status tooltip.
- **SM-LDB-2** In a broker display (Titan Panel, ChocolateBar or Bazooka), add the one Skill Master
  feed ("Skill Master"; no All, Professions, Weapons or Stats feed is offered): it shows its
  template's text. Gain a skill point: the feed reads `^ <skill> <new>` for five seconds, with the
  up chevron. Hover it: the tooltip lists Primary, Secondary, Weapon and Other with mini bars, no
  Stats; it wears the skin (backdrop, border, fonts). Broker > Tooltip: turn Stats on and Weapon
  off, hover again: stats show, weapons do not. Tooltip skills: hide Cooking; the tooltip leaves it
  out and the main window still shows it. Turn *Apply skin to the tooltip* off: the plain tooltip;
  hover a unit or item afterwards, its GameTooltip is the game's own look.
- **SM-CFG-1** Settings → AddOns → Ka0s Skill Master: the landing page lists the slash commands; General
  has Master controls, Skin and Keybindings tabs; Profiles works.
- **SM-CFG-2** Uncheck Minimap button: the button hides, and Reset all settings does not bring it back.

## Settings pages (T5.1)

- **SM-OPT-16** (round 4) Tooltips > Main window tooltip: Bar width 300 and Font size 16: hover a row,
  the tooltip's bar is wider and its lines larger; hover a bag item: its tooltip is the game's normal
  size. Tooltips > LDB tooltip: Bar width 250 widens the feed's tooltip; Font size 10 shrinks its text.
- **SM-OPT-17** (round 4) Hide two weapon rows from their row menu: an eye mark shows in the Weapon
  Skills header (and on the block's band when detached), its tip "2 hidden rows"; click it: both rows
  come back and the mark goes. A hidden Secondary row stays hidden.
- **SM-ALR-2** (round 4) Gain a skill point: a green "SKILL UP" toast names the skill, its numbers
  and "+1", with this session's points, the points to cap and an ETA, for about 4 seconds. Two skill
  points on different skills within 5 s share one toast ("Skill up · 2 skills"). A weapon 25 or more
  behind toasts red "WEAPON SKILL GAP" with "-N". Alerts > Skill-up alerts for: Professions only
  stops the weapon skill-ups; Play a sound on skill up plays the sound on skill-ups alone.
- **SM-OPT-1** Open Bars: no preview bar sits above the tabs (round 4). Drag Bar height and change
  Color mode to Flat with Use the skin's color off: the open window restyles at once.
- **SM-OPT-2** Bars > Bar > Border: turn Use the skin's border off, pick a non-Solid style and a
  thickness of 3: every bar's edge changes. Bars > Text: turn Use the skin's font off, pick a font.
- **SM-OPT-3** Layout > Block order: drag Weapon Skills to the top; the window reorders. Layout >
  Blocks: turn off Dock in the window for one block, it pops out; turn it back on in combat and it
  docks after combat.
- **SM-OPT-4** Hide a skill from its row menu, then Skills > Professions (or Weapons and other):
  untick its Hide row and the row comes back.
- **SM-OPT-5** Trainers and Waypoints: Waypoint method Chat only, click an unlearned row's Go: only
  the chat line, no TomTom arrow. Turn Mark unverified trainers off: no "(unverified)".
- **SM-OPT-6** A fresh profile: no bar draws a border under any skin, Azeroth, High Contrast and
  WoW Midnight included (Show border and Use the skin's border are both off by default). Tick Use
  the skin's border under High Contrast: its edge draws. Set Bars > Main window tooltip bar height to 12, hover a Defense or Other row, then hover the
  broker feed without the row tooltip closing first: no purple bar or blob over the feed's tooltip.
- **SM-OPT-7** Open the trainer popup: each trainer's name is in the skin's accent, apart from the
  place line. Trainers and Waypoints > Trainer popup: turn Use the skin's color off and pick a color:
  the open popup's names take it; tick Use class color: the class's color, at the swatch's opacity.
- **SM-OPT-6** Each page's Defaults button restores the page; the window repaints once.
- **SM-OPT-6** (M5 integration) Right-click a broker feed: the Broker settings page opens, not
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
  Leatherworking: it still opens (the crafting overlay sits one strata over the window's). Detached block
  strata does the same for a detached block.
- **SM-OPT-11** Bars > Colors: with Use the skin's colors on (the default) the bars show the
  mockup's category colors; turn it off and change the Weapon skills swatch: the weapon bars take it.
- **SM-OPT-12** During a simulation (`/sm sim`, start the trip), right-click a row: Pin to the
  broker feed is grayed out and does nothing. With test mode on, the feed starts `Fishing 107+25/150`
  and a `{equippedWeapon}` template reads `Guns 105+5/110`, whatever your own pin and weapon.
- **SM-OPT-13** Bars > Size: set LDB tooltip bar height to 12 and LDB tooltip row height to 24, then
  hover the broker feed: its bars are 12 px and its skill and stat lines spaced 24 px apart, the
  title, section and footer lines unchanged; hover a skill row's tooltip in the main window, then
  any item: no line is stretched. Set Main window tooltip row height to 30 and hover a skill row:
  the bar's line grows and the bar stays centered in it. Pop a block out: its bars and rows are the
  main window's Bar height and Row height (there is no Detached bar height).

## Disabled

- **SM-OFF-1** `/sm disable`: the window hides, `/sm toggle` answers one disabled line, the key
  binding does nothing, the right-click menu grays all but Enabled. `/sm enable` restores it.

## Test mode and the simulator

- **SM-TEST-1** `/sm test`: the window, a detached block, the broker feed and the Journal all show
  Ember Ironsong, the level-22 Dwarf Hunter (Leatherworking 146/150, Fishing 107 +25 with a lure
  timer near 4:12, Guns 105 +5, Fist Weapons, Polearms, Thrown and Riding unlearned), the summary
  reads "Ember Ironsong · Lv 22 · Dwarf Hunter" behind the Hunter icon and the strip says the data is sample data. `/sm test` again: your
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
  the author; it settles the assumed rows in `docs/forever-quirks.md`.

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
