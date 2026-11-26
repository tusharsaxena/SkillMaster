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
| The probe | SM-PROBE-1, SM-PROBE-2, SM-PROBE-3, SM-PROBE-4 |
| Each category | SM-DISP-1, SM-TEST-1, SM-FB2-4 |
| The lure timer | SM-DISP-2, SM-SIM-1, SM-FB2-1 |
| Click targets in and out of combat | SM-DISP-5, SM-DISP-6, SM-DISP-8, SM-DISP-56 |
| Rows page (round 9) | SM-DISP-59 |
| Trainer data (the offline probe, GitHub issue #3) | SM-TPROBE-1, SM-TPROBE-2, SM-TPROBE-3, SM-TPROBE-4, SM-TPROBE-5, SM-TPROBE-6, SM-TPROBE-7, SM-TPROBE-8, SM-TPROBE-9, SM-TPROBE-10, SM-TPROBE-11, SM-TPROBE-12, SM-TPROBE-13, SM-TPROBE-14 |
| Trainer data (seed validation with ForeverDB, 2026-11-25) | SM-SEEDFDB-1, SM-SEEDFDB-2 |
| Waypoints (TomTom by name, AF-SM-TOMTOM) | SM-DISP-7, SM-OPT-5, SM-SEAM-2, SM-DISP-47, SM-DISP-57, SM-DISP-58, SM-DISP-60, SM-DISP-61, SM-DISP-62, SM-DISP-63, SM-DISP-64, SM-DISP-65 |
| Each skin | SM-SKIN-1, SM-SKIN-2, SM-SKIN-3, SM-SKIN-4, SM-SKIN-5, SM-SKIN-6, SM-SKIN-7, SM-SKIN-8, SM-FB2-3 |
| Detach and dock | SM-DISP-3, SM-DISP-11, SM-OPT-3 |
| Feeds in a broker display | SM-LDB-2, SM-SEAM-1, SM-SEAM-4, SM-DISP-18, SM-DISP-39, SM-DISP-40 |

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
- **SM-WIN-5** (round 6, R6-3) Hide one weapon row so the Weapon Skills header shows every mark
  (eye, filter funnel, sort, pop-out): all four read the same size and sit on one line, none higher,
  lower or smaller than the others. Pop the block out and merge it with another detached block: the
  band's marks and the sub-header's marks read the same. Set the sort to Value, highest first and
  Progress: the sort mark keeps the size.
- **SM-WIN-6** (new, AF-SM-RESIZE) With the window unlocked, its bottom-right corner shows the resize
  grip, clear of the legend. Drag it wider and taller: the corner follows the cursor (the window does
  not leap or grow about its center), the rows stretch with the width as you drag, and on release the
  blocks redraw once. Open Layout › Window: Window width and Window height show the new size. `/reload`
  and reopen: the window comes back at that size, where you left it. Try two columns too: both columns
  share the new width.
- **SM-WIN-7** (new, AF-SM-RESIZE) Drag the grip as small and as large as it goes: it stops at Window
  width's and Window height's limits (never off the screen), and the window still draws cleanly at both.
- **SM-WIN-8** (new, AF-SM-RESIZE) `/sm lock`: the grip disappears and the window neither drags nor
  resizes. `/sm unlock`: the grip is back. The title bar's lock mark and the launcher's Locked entry do
  the same. Hover the minimap or broker button for the LDB tooltip: it has no grip and keeps its size.
- **SM-WIN-9** (new, AF-SM-RESIZE review fix) Drag the grip to an odd size and release, then open
  Layout › Window: Window width and Window height read whole tens (the sliders' step). Nudge either
  slider one step: the window moves by that one step only, with no jump first.
- **SM-WIN-10** (new, AF-SM-RESIZE review fix) Set Master scale (General › Master controls) to 1.5 or
  more and drag the grip as large as it goes: the window never grows wider or taller than the
  visible screen. Set Master scale back to 1: the grip can again reach Window width's and
  Window height's limits.

## Display (M3)

- **SM-DISP-1** Open the window: Primary, Secondary, Weapon and Other blocks, then the stat blocks,
  every one expanded on a new profile (round 6, R6-8). Bars fill rank / max; profession bars show ticks at 75 / 150 / 225.
- **SM-DISP-2** Put on a fishing lure: the Fishing bar gains a teal segment, the text reads
  `rank +N / max`, a timer counts down beside it and the segment goes when the lure runs out. A
  Dwarf's Guns shows a blue (permanent) +5 segment that stops at the bar's end.
- **SM-DISP-3** Click a block header: it collapses; `/reload`: still collapsed. Click the header's
  detach control: the block leaves the window into its own frame; drag it, `/reload`, it stays put;
  its dock control puts it back in its old place.
- **SM-DISP-4** Hover a row: the tooltip shows the numbers, the bar, the bonuses (a lure with its
  time left), the next rank and trainer, a weapon's cap gap, Skinning's mob level, the gathering
  nodes and, for Fishing, the zone's need. Hover a stat: its markers (on its bar and as lines) and scale.
  Where it opens is SM-TIP-1 (AD-92-SM: beside the window, no longer off the row's top-right corner).
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
  the row (its action mark included) opens the trainer popup: the faction's weapon masters, with no
  unverified warning since the trainer probe confirmed them (amended, GitHub issue #3). Set
  waypoint (a map pin and Skill Master's arrow), and Print to chat.
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
- **SM-DISP-12** (FB-16, round 2; AD-86-SM moved it inward of the settings mark) At the top right,
  just left of the settings mark: one control. While any block is open it is Collapse all (inward arrows); click it and every block in
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
- **SM-DISP-21** (round 3; its menu, round 6) Each block header has a sort mark left of its detach
  mark. Click it on Weapon Skills: a menu like the filter mark's opens under "Sort rows by" with
  Default order ticked. Pick Value, highest first (Guns 120 on top, the not-learned rows still last),
  then lowest first, then Progress to max, then the default order: each pick reorders the rows and
  the mark's tip names the order. Layout > Blocks > Weapon Skills > Sort
  rows by shows the same choice; a detached block's band carries the mark too; the LDB tooltip lists
  Weapon Skills in the same order.
- **SM-DISP-34** (round 6, R6-5) Pop Weapon Skills out and merge it with another detached block: the
  band's sort mark and each sub-header's sort mark open the same menu, the current order ticked; a
  pick there reorders the main window's block too. Click the mark again with the menu open: it closes.
- **SM-DISP-36** (round 6, R6-4) On a new profile, Melee Hit's bar in the main window carries no
  threshold mark and the footer legend shows no "threshold" entry; hover the row: the tooltip's bar
  carries the marks and lists them. Bars > Marks > Thresholds in the window on: the marks show on the
  window's, a detached block's and a merged window's bars and the legend gains "threshold".
  Thresholds in the row tooltip off: the tooltip's bar and lines lose them. An old profile that had
  Threshold markers off has both new switches off after the update.
- **SM-DISP-35** (round 6, R6-8) Create a new profile (Profiles > New) and switch to it: every block,
  Spell and Defense included, is expanded in the window and in the LDB tooltip. Switch back to an
  existing profile: a block you had collapsed there (by a click) stays collapsed. Load a profile from
  before round 6 that never touched Spell or Defense: both stay collapsed after the update.
- **SM-DISP-22** (round 3) Collapse every block: the window keeps its height and its rows area goes
  empty. Layout > Shrink to fit the rows on: the window shrinks to its headers. The lock mark stands
  at the top right with the journal, settings, Expand / Collapse all and close marks; nothing left of
  the title.
- **SM-DISP-23** (round 3) The Defense / Lockpicking / Riding block reads Other skills in the
  window, the LDB tooltip, and on the Rows, Bars and Broker pages.
- **SM-DISP-24** (round 5, R5-5) Detach the Weapon block and drag it about the screen: every row's
  action mark (the arrow into a bracket) draws as crisp as the main window's wherever the frame is
  dropped, the bracket's right stroke as bright as its left, nothing cut at the right edge. Bars >
  Row height 21: the marks still sit centered in their rows, crisp.
- **SM-DISP-25** (round 5, R5-7) Detach two blocks, then Layout > Detached windows. Window scale 1.5:
  both grow at once, a block with its own Block scale 0.8 to 1.2. Window opacity 0.5: both fade, rows
  and band included. Background: turn off Use the skin's background and pick a red swatch: both
  windows fill red, the title band still drawn over it; back on, the skin's fill. Border: turn off Use
  the skin's border, thickness 3, a yellow swatch: a 3 px yellow edge on both; Show border off: no
  edge. Title band On hover: the band, title and marks vanish, the rows stay where they were; point at
  a window: its band returns and the window drags by it; point away: gone. Never: no band, the rows
  move up, a thin strip at the top still drags the window. Detached block strata sits on this tab.
  `/sm skin` to another skin: every pick above survives the repaint.
- **SM-DISP-26** (round 5, R5-6: the merged window) Detach
  Primary Professions and Secondary Skills and drag Secondary onto Primary's bottom edge: one window
  titled `Primary · Secondary`, each section under its own sub-header (chevron, title, sort mark, split mark); the band's two marks collapse / expand both
  sections and dock both. Right-click a sub-header: Split from the group, Unmerge all, Dock in the main
  window, Dock all in the main window; on the band the two section rows are grayed. The split mark
  pops the section out beside the window, and the window left with one section is a plain detached
  window again. Drag the band: the window moves and comes back there after `/reload`; Lock frame on:
  it stays. Hover a crafting profession's mark in the merged window and click: the profession opens.
  In combat a split waits and runs when combat ends. Layout > Detached windows: opacity and border
  reach the merged window too.
- **SM-DISP-27** (round 5, R5-6b: drag to merge) Detach Primary, Secondary and Weapons, apart. Drag
  Secondary until its left edge is near Primary's right edge, overlapping it vertically: a green strip
  lights Primary's right side; move it away: the strip goes. Release on the strip: one window of two
  columns, `Primary · Secondary`, Primary where it stood. Drag Weapons under the merged window's
  second column: the strip lights only that column's bottom; release: Weapons stacks under Secondary.
  Drag Weapons near the top of the first column instead: it stacks above Primary, and Primary's rows
  stay where they stood (the window grows upward by the Weapons section only). Drag the merged
  window by its band onto another detached window's side: it merges whole. A release with no strip is
  a plain move. Lock frame on (or one section's own Lock): nothing drags. In combat, release on a
  strip: the window moves, and merges once combat ends; drop two different windows on two strips in
  the same combat: both merges happen when it ends. `/reload`: the merged layout comes back.
- **SM-DISP-28** (round 5, R5-6b: drag out) In a merged window of three sections, drag a section's
  sub-header: a ghost of it follows the pointer, edged green; release close by (inside about 128
  units): nothing changes. Drag it further: the edge turns red; release: the section is its own
  detached window where the ghost was, the other two still merged. Drag the last but one out the same
  way: the window left with one section is a plain detached window. Drag a section out past the leeway
  and onto another detached window's side (the green strip lights): release merges it there. Lock
  frame on: the sub-header does not drag. In combat the split waits for the end of combat.
- **SM-DISP-29** (round 5, R5-10: the weapon filter) The Weapon Skills header has a funnel mark left
  of its sort mark (every header has one since round 7, SM-DISP-51); its tooltip reads `Showing: All. Click to filter.` Click it:
  a menu under the mark, Show, then All (ticked), Learned, Equipped, Below cap. Learned: the
  not-learned weapons leave. Equipped: only the main hand, off hand and ranged weapons' skills stay,
  and the funnel wears the filled badge (SM-DISP-55); swap the main-hand weapon for another type: the block follows
  at once. Unequip the main hand with Equipped on and no Unarmed row: the header stays, with
  `No rows match this filter.` under it. Below cap: only learned skills under their cap. Click the
  mark again with the menu open: it closes. Detach the block: the band carries the funnel; merge it
  with another detached block: its sub-header carries it (the other section's its own). Layout >
  Blocks > Weapon Skills > Show rows shows the same choice. `/reload` and a profile switch: the
  filter is the profile's. Every other block has its own funnel since round 7 (SM-DISP-51).
- **SM-DISP-30** (round 5, R5-14: the trainer popup's wrap) Open the trainer popup on an unlearned
  weapon (Fist Weapons, Staves): a weapon master's `Also teaches:` line wraps onto a second line
  inside its card instead of being cut off, the card is taller by that line and the window by every
  such card; the buttons stay below the last card. Hover a card: a tooltip with the
  trainer's name, place and the whole `Also teaches` list (beside the popup since AD-92-SM: SM-TIP-4).
- **SM-DISP-31** (round 5, R5-15: the trainer distance) In Stormwind, open the trainer popup on an
  unlearned weapon: each weapon master in a city on your continent shows `N yd` under its cost, the
  nearest first; one on the other continent, or without coordinates, shows none and comes last.
  Walk towards another trainer with the popup open: within about a second the yards change and the
  cards reorder; the trainer you selected stays selected. Compare one card's yards with Skill Master's
  arrow (roughly equal: a straight line). Enter an instance (or a battleground) with the popup open: no
  distances, no error.
- **SM-DISP-39** (round 6, R6-10) On a new profile, hover the broker feed: the tooltip looks like the
  main window, as wide as it, in the skin's shell with the title band (Skill Master · Professions and Skills since round 7, the session's
  gains at the right): the window's block headers (chevron and title; no sort or filter mark since
  round 8, SM-DISP-54), its rows (icon, name, the bar with its text inside it, the action mark at the
  right end), at the window's row height and fonts, the footer hints under them. Collapse Weapon
  Skills in the window, hover again: its header shows the right chevron and no rows. Set the weapon
  filter to Learned and the sort to Value, highest first: the tooltip follows both. Click a header,
  or its chevron: nothing happens. Left-click a weapon row: Skills opens; right-click it:
  the row menu draws whole, over the tooltip, and the tooltip stays while the menu is open. Tooltips
  > LDB tooltip: Height 200, hover: the body scrolls with the wheel and its scroll bar. Tooltip
  style Classic: today's lines and mini bars, and the row menu over them is whole too. An existing
  profile from before this build opens on Classic.
- **SM-DISP-40** (round 6, R6-9) In a broker display add the second feed, Skill Master Stats: it reads
  `Stats`. Hover it: its tooltip lists the stat blocks (Base & Combat, Spell & Regen, Defense &
  Resists, Utility) in the chosen Tooltip style, and the Skill Master feed's tooltip lists skills
  only. Right-click Ranged Crit (in the window or the stats tooltip) > Pin to the broker feed: the
  feed reads `Ranged Crit 9.1%` (your value) at once; log on an alt: its feed reads `Stats`; pin again
  to unpin. Left-click the stats feed: the window toggles; right-click: the Broker page. Broker >
  Tooltip > Stats feed sections: turn Utility off: the stats tooltip leaves it out. Rows: a stat's
  LDB tooltip eye leaves it out of the stats feed's tooltip.
- **SM-DISP-41** (round 6, review) On a new profile run `/sm test`, hover the Skill Master feed and
  right-click the amber strip at the top of its tooltip: the End test menu draws whole, over the
  tooltip, and the tooltip stays while it is open; click End test: test mode ends. A profile from
  before this build that never changed a setting opens the feed tooltip on Classic.
- **SM-DISP-42** (round 6, review) Open the trainer popup on a weapon master with the map pin
  available: hover Set waypoint: its label takes the skin's hover color, as Print to chat's does.
- **SM-DISP-43** (round 6, R6-11) Open the trainer popup on an unlearned weapon,
  pick a weapon master in your city and click Set waypoint: the map pin is set, the game's own arrow
  does not show, and Skill Master's arrow (Raised by default, round 8) shows above the screen's center with the yards
  under it in the skin's body font. Turn on the spot: the arrow turns to keep pointing at the
  trainer (turn left and it turns right). Face the trainer: it points straight up. Far away (300 yd
  or more) it is the skin's accent; walk in: it shades into the skin's green by 30 yd. Within about
  5 yd it goes, the map pin clears and chat says `You have arrived: <trainer>`.
- **SM-DISP-44** (round 6, R6-11; round 9) With the arrow up: hover it: the tooltip names the trainer and the
  place with `Right-click for options. Drag to move the arrow.` (beside the arrow since AD-92-SM: SM-TIP-5) Drag it elsewhere, `/reload`
  and set a waypoint again: it shows where you left it. Right-click it and pick Clear waypoint:
  it goes and the map pin clears. Set it again and click elsewhere on the world map to place your own
  pin: the arrow goes. Set it again and pick another trainer's Set waypoint: the arrow points at the
  new one. Enter an instance (or ride to another continent): the art goes and the trainer's name
  shows alone, dimmed. Enter combat: it stays.
- **SM-DISP-45** (round 6, R6-11) Trainers and Waypoints > Waypoint arrow: Arrow scale 1.5: the arrow grows at once.
  Untick Show Skill Master's arrow with it up: it goes and the game's own arrow points at the pin;
  set a waypoint again: the game's arrow, no Skill Master arrow. Tick it again.
- **SM-DISP-46** (the R6-11 review) A waypoint set and Skill Master's arrow up. Press
  Alt+Z twice: the arrow comes back and still turns as you turn and counts the yards down (walk in:
  `You have arrived` still prints). Make a second profile with Show Skill Master's arrow off and
  switch to it with the arrow up: it goes and the game's own arrow points at the pin. Switch back,
  set the waypoint, then switch to a profile whose arrow is at scale 2 and dragged elsewhere: the
  arrow takes that scale and place at once.
- **SM-DISP-47** (round 7, R7-7; amended, AF-SM-TOMTOM: the real TomTom is SM-DISP-64) With an
  addon that answers TomTom's API but is not TomTom itself (the owner's round-7 case) loaded: Set
  waypoint on a weapon master gives the map pin and Skill Master's arrow, never TomTom's; `/sm test` shows the sample arrow too. Untick Show Skill Master's
  arrow and set it again: the map pin with the game's own arrow. Trainers and Waypoints > Waypoint
  method offers Map pin and Chat only, no TomTom entry. A profile that had TomTom first or Map pin
  stored reads Map pin after the upgrade.
- **SM-DISP-48** (round 7, R7-3) Expand Stats · Base & Combat in the main window, a detached frame, a
  merged window and the Skill Master Stats feed's tooltip (both styles): no `vs highest primary` (or
  any other muted text) beside any block title; the header holds the chevron, the title and its marks
  only. Hover a stat row: its tooltip still has the `Scale: vs ...` line.
- **SM-DISP-49** (round 7, R7-5) Hover the Skill Master feed, then the Skill Master Stats feed, in each
  Tooltip style: the titles read `Skill Master · Professions and Skills` and `Skill Master · Stats`
  (a middle dot). The broker display still shows both feeds where you had placed them (their names
  are unchanged) and their texts as before. In the Main window style, set Tooltips > LDB tooltip >
  Width (px) to 300 and hover each feed: the title never draws over the `+N this session` text at the
  top right (it moves to the left edge and truncates with an ellipsis if it must); back at 600 it is
  centered again (the round 7 review).
- **SM-DISP-50** (round 7, R7-4) Tooltip style Main window, the default Height: hover either feed
  when everything fits: the scroll bar is drawn at the right, disabled (one dim thumb the whole
  height; dragging does nothing), and no empty gutter shows. Set Tooltips > LDB tooltip > Height to
  200 and hover: the thumb is its normal size and color and drags the body. Switch skins: both looks
  follow the skin.
- **SM-DISP-51** (round 7, R7-1: a filter on every block) Every block header in the main window
  carries the funnel left of its sort mark, in the title's color, its marks one size on one line.
  Primary Professions' funnel: Show, then All (ticked), Below cap, At cap (needs training). Below
  cap: only learned professions under their rank's cap. At cap: only learned professions at their
  rank's cap with a higher rank to train (a profession at Artisan's top cap leaves); the funnel wears
  the filled badge (SM-DISP-55). Unlearned professions show under All only. Secondary Skills the same. Other
  skills: All, Learned, Below cap. Each stat section: All, Non-zero; Non-zero leaves out every row
  reading `0` or `0.0%` (Armor `0 (0.0%)` too); a section left with nothing keeps its header and
  `No rows match this filter.` Detach a stat block: its band carries the funnel; merge two detached
  blocks: both sub-headers carry it. Layout > Blocks > each block > Show rows offers the same set.
  Hover each feed in both Tooltip styles: the sections follow their filters (the Main window style's
  headers carry no funnel since round 8, SM-DISP-54). `/reload` and a profile switch: each filter is
  the profile's.
- **SM-DISP-52** (round 7, R7-6: open from the go icon) Tooltip style Main window, Tooltips > LDB
  tooltip > Open a row from set to Go icon only (Full row is the default since round 8: SM-DISP-56
  covers it). Hover the Skill
  Master feed: the footer reads `Rows: click the go icon to open, shift-click to link, right-click for
  the menu`. Click a row's name or bar: nothing opens. Hover a crafting row (Tailoring): the row
  washes, its row tooltip shows beside it and the go icon lights under the pointer; click the go
  icon: the profession window opens (the cast, as the main window's). A weapon row's go icon opens
  Character > Skills on its line, a stat row's (Skill Master Stats) the paper doll, with no Lua error.
  Shift-click a row: its link goes into chat; right-click a row and its go icon: the row menu, above
  the tooltip. Scroll a long tooltip (Height 200) and click a go icon: the row under the pointer
  opens. Move off the tooltip so it hides, then click where a go icon was: nothing happens. In
  combat: hover a crafting row and click its go icon: one chat line says profession windows open out
  of combat, nothing opens, no error; after combat it opens again. Set Open a row from to Full row:
  a click anywhere on a row opens what its go icon opens (SM-DISP-56) and the footer reads `Rows:
  click to open, shift-click to link, right-click for the menu`. Tooltip style Classic: the setting
  is dimmed and a row opens from anywhere on it.
- **SM-DISP-53** (round 8, R8-3: header mark colors) Detach Weapon Skills: the band's dock, collapse,
  sort and filter marks (and the eye while it hides rows) rest in the title's color, as the main
  window header's marks do, and turn the skin's hot color under the pointer. Merge two detached
  blocks: the band's dock-all and collapse-all marks the same; each section sub-header's chevron,
  funnel, sort and split marks look as the main window header's chevron, funnel, sort and detach.
  Switch skins: every mark follows the new skin's title color.
- **SM-DISP-54** (round 8, R8-4: the LDB tooltip's headers) Tooltip style Main window: hover either
  feed: each block header shows its chevron and title only, no sort mark and no funnel, on All and
  with a filter narrowing the rows. Set Weapon Skills' filter to Below cap and its sort to Value,
  highest first, in the main window, then hover again: the tooltip's weapon rows follow both. The
  main window's headers, detached bands and merged sub-headers keep their sort and filter marks.
  Tooltip style Classic: the section titles carry no marks, as before, and follow the same sort and
  filter.
- **SM-DISP-55** (round 8, R8-2: the filter badge) In the main window set Weapon Skills' filter to
  Learned: its funnel now sits on a solid square in the title's color, the funnel drawn dark on it
  (the window's background), the square no wider than the marks beside it and on their line; the
  other headers' funnels on All stay plain. Hover the badge: the square turns the skin's hot color
  with the funnel still readable on it, and the tooltip names the filter; move off: the title's color
  again. Set it back to All: the plain funnel at its usual size. Detach the block, and merge two
  detached blocks with a filter on one: the band's and the sub-header's funnels wear the same badge.
  Switch skins with a filter on: the square follows the new title color and the funnel the new
  background. `/reload`: the badge is still there.
- **SM-DISP-56** (round 8, R8-1: open a row from) A fresh profile: Layout > Window > Open a row from
  reads Full row, and so does Tooltips > LDB tooltip > Open a row from. In the main window click a
  crafting row's name, its icon and its bar (Tailoring, Cooking): the profession window opens each
  time, out of combat, with no "action blocked" or Lua error (`/sm debug` logs the overlay's
  `PostClick` with no "no armed crafting overlay" line). Click a weapon row's name: Character > Skills
  opens on its line; a stat row's: the paper doll, with no PlayerFrame secret-compare error. Hover a
  row: its tooltip's last line starts `Click:` (`Arrow:` in Go icon only). Shift-click a crafting row
  with the chat box open: its link goes in and its window does not open; right-click it: the row
  menu. Drag the window by its title: it moves, and the rows still open after the drop. In combat
  click a crafting row: one chat line says why, nothing opens; after combat the hovered row opens
  again. Detach Weapon Skills and merge two detached blocks: their rows open from anywhere on them
  too. Set Open a row from to Go icon only: a click on a row's name or bar opens nothing, its go icon
  opens it, shift-click and right-click still work on the whole row; the detached and merged rows
  follow. Hover the Skill Master feed (Main window style): a click anywhere on a row opens what its
  go icon opens (a crafting row its window, not the main window), and the footer names the
  shift-click link; set its Open a row from to Go icon only and SM-DISP-52 holds.
- **SM-DISP-57** (round 8, R8-5: the arrow's five looks) A fresh profile: Trainers and Waypoints >
  Waypoint arrow reads Show Skill Master's arrow, Arrow style Raised, Use the skin's colors ticked
  (Far color and Near color grayed), Arrow scale 1. Set a weapon master's waypoint and pick each
  Arrow style in turn, the arrow up: Flat (one even color, a dark edge), Ridge (a lit spine down the
  middle), Raised (lit from the top left, a soft shadow down and to the right that stays there as you
  turn), Faceted (four flat-shaded planes), On the ground (tilted flat, as if lying on the ground
  ahead of you). Each changes at once, no `/reload`. In every look turn on the spot: the arrow points
  at the trainer (turn left, it turns right) and On the ground steps round smoothly with no jump and no
  frame drawn sideways. Arrow scale 0.5 and 2 in each look: the art stays crisp, Raised's shadow
  scales with it, the yards stay under it. No Lua error, and no look draws as a blank or a green box
  (a texture that failed to load).
- **SM-DISP-58** (round 8, R8-5: the arrow's colors) The arrow up far away (300 yd or more): the
  skin's accent; walk in: it shades into the skin's good color by 30 yd. Switch skins: it follows.
  Untick Use the skin's colors: Far color and Near color light up; set Far to red and Near to blue:
  far away it is red, it shades through purple as you walk in, blue by 30 yd. Tick it again: the
  skin's colors are back. Make a second profile with On the ground and switch to it, the arrow up:
  it lies on the ground at once; switch back: Raised. `/sm test`: the sample arrow draws in the chosen
  look.
- **SM-DISP-59** (round 9: the Rows page's tabs) Open Settings > Rows: a tab strip reads Primary,
  Secondary, Weapons, (Other, when a catalog skill is uncategorized,) Base & Combat, Spell & Regen,
  Defense & Resists and Utility, each hovered tab naming its block in full. The first tab shows only
  the primary professions; switching tabs and clicking eyes is quick, with no hitch. Hide Axes on the
  Weapons tab: the window drops it at once and its eye dims; the heading's eye shows it again.
- **SM-DISP-60** (round 9, R9-1/R9-3: the arrow's text) Set a weapon master's waypoint: the arrow
  is about a quarter larger than before at Arrow scale 1, the yards under it in the skin's font,
  white. Trainers and Waypoints > Arrow text: untick Use the skin's font and pick another Font: the
  yards change face at once; Font size 20, Font color red, Use class color (your class color), Font
  flags Thick outline, Font shadow off: each applies at once. Text position Above, Left, Right:
  the yards move round the arrow and the arrow itself stays put; Hidden: the arrow alone. Tick Show
  the trainer's name: the trainer's name sits under the yards. Distance units Compact, with the
  trainer 1000 yd or more away (another zone of the continent): `4.2k yd`-style. Switch skins with
  Use the skin's font on: the face follows the skin.
- **SM-DISP-61** (round 9, R9-1: the arrow's position) Trainers and Waypoints > Arrow position:
  X offset 300: the arrow moves right at once; Y offset 0: it sits at the screen's center. Drag the
  arrow: both sliders follow when you drop it. Arrow scale 2: it grows where it is. Click Reset
  position: it goes back above the center and the sliders read 0 and 200. Tick Lock the arrow: it no
  longer drags, and its tooltip drops the drag hint; `/sm lock` and `/sm unlock` do not change
  whether it drags. Untick it.
- **SM-DISP-62** (round 9, R9-2: the arrow's menu) Right-click the arrow: a menu at the pointer, in
  the skin, reads Clear waypoint, Share in chat, Show on map, Show trainers, Lock the arrow, Reset
  position, Arrow settings..., Hide arrow. Share in chat: the chat box opens with a ` /way <zone>
  xx.x, yy.y <trainer>` line and sends nothing until you press Enter. Show on map: the world map
  opens on the trainer's zone (in combat the item is grayed, its tooltip saying why). Show trainers:
  Skill Master's trainer popup opens on the skill whose Set waypoint you clicked. Lock the arrow:
  it stops dragging and the next right-click reads Unlock the arrow. Reset position: back above the
  center. Arrow settings...: the settings panel opens on Trainers and Waypoints (in combat the item is
  grayed, its tooltip saying why). Hide arrow: the arrow
  goes and the game's own arrow points to the pin; Show Skill Master's arrow is unticked there.
  Tick it again. Click elsewhere: an open menu closes; walk into the trainer with it open: it closes.
- **SM-DISP-63** (round 9, R9-2: the sample's menu) A waypoint set, then `/sm test`: the sample
  arrow shows over it. Right-click it: Share in chat, Show on map and Show trainers are grayed.
  Clear waypoint: the sample goes, the real arrow is back and
  the map pin stays. `/sm test` again to end test mode: the real arrow stays.
- **SM-DISP-64** (new, AF-SM-TOMTOM, owner img-19) With **TomTom** installed and enabled, open the
  trainer popup on an unlearned weapon (Bows) and press Set waypoint: TomTom's waypoint appears (on
  the world map, the minimap and with TomTom's own arrow), titled with the trainer's name; Skill
  Master's arrow does not show, and chat says `Waypoint set (TomTom): <trainer>: <city> ...`. Hover
  the TomTom waypoint: it names the trainer. A cap toast's click does the same. (A map pin left by
  a Set made before TomTom was enabled is not cleared; known-limitations.md.)
- **SM-DISP-65** (new, AF-SM-TOMTOM) Disable TomTom and `/reload`: Set waypoint is the map pin with
  Skill Master's arrow again, and chat says `Map pin set: ...`. With TomTom enabled, Waypoint method
  Chat only: Set waypoint is grayed and Print to chat prints the directions.
- **SM-DISP-37** (round 6, R6-6) Open the trainer popup on an unlearned weapon: the primary button
  reads `Set waypoint` (no `(map pin)` or `(chat)`), no `Waypoint order:` line sits under the buttons and the window ends a pad below them.
  Open it on Fishing's next rank (profession trainers carry no coordinates): `Set waypoint` is grayed
  in the skin's disabled look and does nothing; hover it: `No map coordinates for this trainer yet;
  Print to chat gives directions.` Print to chat prints them. Trainers and Waypoints > Waypoint method
  Chat only: the button is disabled on a weapon master too, its tooltip naming the setting. The reason
  opens centered above the button (AD-92-SM: SM-TIP-4).
- **SM-DISP-38** (round 6, R6-7) An Alliance character with Fishing at 150 / 150: open its trainer
  popup. The intro reads `Trainers for your faction (Alliance) who train Fishing to Expert (225) or
  higher:`; under an `Expert (225)` heading Old Man Heming, under `Artisan (300)` Nat Pagle. With
  Blacksmithing at 75 / 75: the Journeyman and Expert blacksmiths under `Journeyman (150)`, nearest
  first (walk about: within a second they reorder inside the heading, never across it), no
  `Expert (225)` heading, Brikk Keencraft under `Artisan (300)`. When a list passes the 600-unit
  cap (most likely Blacksmithing or Leatherworking at 75 / 75 on a faction with many recorded
  trainers): the window stops growing, a thin skin scroll bar shows at its right edge, the wheel and
  the bar scroll the cards, the buttons stay put below. Every card's `Also teaches` line still wraps.
- **SM-DISP-32** (R5-followups review) Open the trainer popup, press Alt+Z twice (the UI hides and
  comes back): walk towards another trainer; within about a second the yards change and the cards
  reorder, as before the Alt+Z.
- **SM-DISP-33** (R5-followups review) Detach (or hide on Layout > Block order) every block but Weapon
  Skills, set its filter to Equipped and unequip the main hand: the window shows the Weapon Skills
  header and `No rows match this filter.`, and no `No skills to show yet.` over them.
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
- **SM-OPT-22** (round 7, R7-2) Make a new profile: Bars > Icons > Use the row's color is unticked and
  the icons are edged in the skin's icon border. A profile from before this build still has it ticked
  (its icons edged in their rows' colors) unless you had unticked it.
- **SM-OPT-14** (round 2; the Rows page since round 5) Rows: one boxed row per skill, its
  icon and name, the eyes on the right; click the Window eye: the row dims and the skill leaves the window,
  click again to bring it back. Layout > Block order: the same boxes, a three-line handle on the
  left to drag, an eye that hides or shows the block.
- **SM-DISP-13** (FB-17) The summary line opens with the class icon, then the character's name in
  its class color, then `· Lv N · Race Class`. Note which icon source drew (the `classicon-<class>`
  atlas, or the class sheet), or none.
## Data bars (AD-80-SM, LibKa0s#80)

Every data bar is LibKa0s-Widgets-1.0's `Bar` now, styled from the Bars page by `NS.BarStyle`.

- **SM-BAR-1** (new) Open the window with a lure on and a racial bonus: every skill and stat bar
  looks as it did before: the fill in its category color, the bonus segment past it teal for the
  lure (temp) and blue for the racial (permanent), the `107 +25 / 150` text and the lure's timer
  inside the bar's far end. The same on a detached block, the row tooltip's bar, the Journal's Alts
  mini bars and the LDB tooltip's mini bars. The window's legend swatches match the bonus colors.
- **SM-BAR-2** (new, the one visible change) Bars > Show border on, thickness 1: each bar's edge is
  one physical pixel, crisp at any UI scale (it was one UI unit, which a fractional scale blurred
  or doubled); thickness 3 draws three pixels.
- **SM-BAR-3** (new) With the window open, switch the skin (`/sm skin`, Apply): every bar repaints
  in the new skin at once, no `/reload`. Bars > Rank tier colors on (Color mode By category): a
  profession bar splits into a shade per rank tier entered, on a scale to 300.

## Tooltip placement (AD-92-SM, LibKa0s#92)

Every tooltip Skill Master places itself opens where its element sits, never at the pointer and never
off a corner of the control (standalone-windows, *Tooltip placement*; launcher-§7). The gap is 2 px.
In each check, the tooltip's words are what they were before this change.

- **SM-TIP-1** (a row is a body element) Open the main window near the screen's left: hover a row: its
  tooltip opens right of the window, 2 px off its right edge, its top level with the row's top, and
  covers no row. Drag the window to the screen's right edge and hover again: the tooltip opens left of
  the window instead. Hover rows further down the list: each tooltip's top follows its row, never the
  pointer. A row near the bottom of the screen: the tooltip slides up only as far as it must to stay
  on screen. The row tooltip's bar still sits under its numbers line.
- **SM-TIP-2** (detached and merged windows) Detach a block and hover one of its rows: the tooltip opens
  beside the detached frame (right, or left at the screen's right edge), never over its rows. Merge two
  detached blocks and hover a row in either section: the tooltip opens outside the whole merged window,
  not between its sections.
- **SM-TIP-3** (the Journal) Open the Journal on Alts and hover a character's column header: the
  tooltip (name, level, realm, last seen) opens beside the Journal, its top level with the header,
  no longer under the header over the skill rows.
- **SM-TIP-4** (the trainer popup) Open the trainer popup on an unlearned weapon and hover a card: its
  tooltip opens beside the popup, level with the card, the cards under it uncovered. Open it on
  Fishing's next rank and hover the disabled Set waypoint: the reason opens centered above the button,
  2 px off it (below it only when the popup sits at the very top of the screen).
- **SM-TIP-5** (the waypoint arrow) With the arrow up, hover it: its tooltip opens beside the arrow
  (right of it, or left of it when the arrow is near the screen's right edge), its top level with the
  arrow's, never at the pointer. Drag the arrow elsewhere and hover again: it follows the arrow.
- **SM-TIP-6** (the broker feed, launcher-§7) On a broker display (Titan Panel or the like) at the top of
  the screen, hover the Skill Master feed in each Tooltip style (Main window, Classic): the tooltip
  hangs 2 px under the feed's cell; with the cell in the screen's right third its right edge lines up
  with the cell's right edge (it extends left), in the left third its left edge with the cell's, in the
  middle third it is centered. A display at the bottom of the screen opens it 2 px above the cell. The
  row tooltips inside the Main window style's panel open beside the panel (SM-TIP-1's rule).
- **SM-TIP-7** (the title-bar marks, unchanged) Hover any title-bar or block-header mark: its one-line
  tooltip still opens centered above the mark, as smoke round 1 ruled.

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
- **SM-JRN-7** (round 5, R5-4) The Log table's header (DATE, TIME, SKILL, CHANGE, ZONE, uppercase)
  and the Alts table's header (the block's title and the character names) each stand on a band in
  the block headers' color with a thin rule under it, plainly not a row; the rows keep their stripes.
  `/sm skin` to another skin: both bands follow it.
- **SM-JRN-8** (round 5, R5-2) The Journal's title bar carries a padlock left of its close mark, its
  tooltip "Lock or unlock the window". Click it: it closes, the main window's padlock closes too, and
  neither the Journal nor the main window drags or resizes. `/sm unlock`: both padlocks open. With
  the Journal open, switch to a profile whose window is unlocked: the Journal's padlock opens.

## Integration (M3 + M4)

- **SM-SEAM-1** Collapse the Primary block and scroll the window to the top. Hover the Skill Master feed and
  click Leatherworking in its tooltip: the window opens, Primary expands and the body scrolls to
  the row. Click an unlearned weapon in the feed tooltip's Weapon section: the trainer popup opens on that skill.
- **SM-SEAM-2** The broker tooltip's and the Journal's mini bars match the window's bar colors;
  switch skins and reopen both: they follow. Click the cap toast: a map pin and Skill Master's arrow.
- **SM-SEAM-3** Click the main window's journal mark: the Journal opens; again: it closes.
- **SM-SEAM-4** Hover a feed, then move straight onto another addon's tooltip owner (a bag item):
  the other tooltip stays up (the feed's leave check hides only its own). The feed tooltip's footer
  reads `Click label: toggle window · Right-click label: options · Rows: click to open, shift-click to link, right-click for the menu`;
  right-click the feed opens the settings on the Broker page (the main page until it exists).

## Launcher and settings

- **SM-LDB-1** (amended, AD-81-SM) The minimap button shows the logo. Left-click opens the settings;
  right-click shows Enabled, Locked, Test mode, Sim mode, Show window, Journal, then Open settings
  and Open skin selector. Hovering shows the status tooltip.
- **SM-LDB-3** (new, AD-81-SM) Right-click the minimap button with the Journal closed: *Journal* is
  unticked; click it: the Journal opens and the menu closes. Right-click again: *Journal* is ticked;
  click it: the Journal closes. The same from a broker display's Skill Master feed. `/sm disable`,
  then right-click: *Journal (enable the addon first)* is grayed and does nothing.
- **SM-LDB-2** In a broker display (Titan Panel, ChocolateBar or Bazooka), add the one Skill Master
  feed ("Skill Master"; no All, Professions or Weapons feed is offered; the stats have their own
  feed, SM-DISP-40): it shows its
  template's text. Gain a skill point: the feed reads `^ <skill> <new>` for five seconds, with the
  up chevron. Hover it (Tooltips > Tooltip style Classic): the tooltip lists Primary, Secondary, Weapon and Other with mini bars, no
  Stats; it wears the skin (backdrop, border, fonts). Broker > Tooltip: turn Weapon
  off, hover again: weapons do not show. Rows: Cooking's LDB tooltip eye; the tooltip leaves it
  out and the main window still shows it. Turn *Apply skin to the tooltip* off: the plain tooltip;
  hover a unit or item afterwards, its GameTooltip is the game's own look.
- **SM-CFG-1** Settings → AddOns → Ka0s Skill Master: the landing page lists the slash commands; General
  has Master controls, Skin and Keybindings tabs; Profiles works.
- **SM-CFG-2** Uncheck Minimap button: the button hides, and Reset all settings does not bring it back.

## Settings pages (T5.1)

- **SM-OPT-16** (round 4) Tooltips > Main window tooltip: Bar width 300 and Font size 16: hover a row,
  the tooltip's bar is wider and its lines larger; hover a bag item: its tooltip is the game's normal
  size. Tooltips > LDB tooltip: Bar width 250 widens the feed's tooltip; Font size 10 shrinks its text.
- **SM-OPT-18** (round 5, R5-11..R5-13) The sidebar lists Skills, Rows, Broker; no Stats page. Skills
  has one tab, General, with its three switches. Rows: a Window / LDB tooltip caption line over two
  eye columns, then the window's block headings in its block order (Primary Professions, Secondary
  Skills, Weapon Skills, Other skills, the four stat groups), each skill or stat a boxed row with its
  icon, name and two eyes, the eyes aligned under the captions at any panel width; the names never
  wrap past the eyes. Broker shows Feed and Tooltip only.
- **SM-OPT-19** (round 5, R5-13) Rows: Axes's Window eye hides it from the window and a detached
  Weapon block, the LDB tooltip still lists it; its LDB tooltip eye then hides it there too and the
  row dims. Hide Bows and Guns from the window; the Weapon Skills heading's Window eye brings both
  back at once (one repaint), leaving Axes's tooltip hide. With the Rows page closed, hide Fishing
  from its row menu and reopen Rows: Fishing's Window eye reads dimmed.
- **SM-OPT-21** (R5-followups review) With Rows open and the main window visible, right-click Axes
  in the window > Hide this row: Axes's Window eye dims at once and the Weapon Skills heading's
  Window eye lights; click it: Axes comes back. `/sm set skills.hidden.bows true` with the page open:
  the same. Drag Weapon Skills to the top on Layout > Block order, go back to Rows: Weapon Skills
  is the first heading.
- **SM-OPT-20** (round 5, R5-13) Hide a skill and a stat in both columns, then Skills > Defaults and
  Broker > Defaults: they stay hidden. Rows > Defaults: everything shows again in the window and the
  tooltip. Each Defaults button's tooltip says which.
- **SM-OPT-17** (round 4) Hide two weapon rows from their row menu: an eye mark shows in the Weapon
  Skills header (and on the block's band when detached), its tip "2 hidden rows"; click it: both rows
  come back and the mark goes. A hidden Secondary row stays hidden.
- **SM-ALR-2** (round 4) Gain a skill point: a green "SKILL UP" toast names the skill, its numbers
  and "(+1)", with this session's points, the points to cap and an ETA, for about 4 seconds. Two skill
  points on different skills within 5 s share one toast ("Skill up · 2 skills"). A weapon 25 or more
  behind toasts red "WEAPON SKILL GAP" with "(-N)". Alerts > Skill-up alerts for: Professions only
  stops the weapon skill-ups; Play a sound on skill up plays the sound on skill-ups alone.
- **SM-ALR-3** (round 6, R6-1) `/sm test`: the weapon-gap and skill-up toasts wear the cap toast's
  look (the skin's background, border and text, the same icon size, no red or green wash or edge).
  Only the small label ("WEAPON SKILL GAP", "SKILL UP") and the numbers keep red and green, the
  delta in brackets: "Daggers 74 / 110 (-36)", "Bows 81 / 110 (+1)". Switch skins: all three follow.
- **SM-OPT-1** Open Bars: no preview bar sits above the tabs (round 4). Drag Bar height and change
  Color mode to Flat with Use the skin's color off: the open window restyles at once.
- **SM-OPT-2** Bars > Bar > Border: turn Use the skin's border off, pick a non-Solid style and a
  thickness of 3: every bar's edge changes. Bars > Text: turn Use the skin's font off, pick a font.
- **SM-OPT-3** Layout > Block order: drag Weapon Skills to the top; the window reorders. Layout >
  Blocks: turn off Dock in the window for one block, it pops out; turn it back on in combat and it
  docks after combat.
- **SM-OPT-4** Hide a skill from its row menu, then open Rows: its Window eye is dimmed; click it
  and the row comes back.
- **SM-OPT-5** Trainers and Waypoints: Waypoint method Chat only, click an unlearned row's Go: only
  the chat line, no map pin and no arrow. No "(unverified)" shows (the owner, 2026-11-25: the Mark unverified trainers row is gone).
- **SM-OPT-6** A fresh profile: no bar draws a border under any skin, Azeroth, High Contrast and
  WoW Midnight included (Show border and Use the skin's border are both off by default). Tick Use
  the skin's border under High Contrast: its edge draws. Set Bars > Main window tooltip bar height to 12, hover a Defense or Other row, then hover the
  broker feed without the row tooltip closing first: no purple bar or blob over the feed's tooltip.
- **SM-OPT-7** Open the trainer popup: each trainer's name is in the skin's accent, apart from the
  place line. Trainers and Waypoints > Trainer popup: turn Use the skin's color off and pick a color:
  the open popup's names take it; tick Use class color: the class's color, at the swatch's opacity.
- **SM-OPT-23** Each page's Defaults button restores the page; the window repaints once.
- **SM-OPT-24** (M5 integration) Right-click a broker feed: the Broker settings page opens, not
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

- **SM-TEST-1** (amended, AD-87-SM) `/sm test`: the window, a detached block, the broker feed and the
  Journal all show Samplehunter Mockstride, the level-22 Dwarf Hunter (Leatherworking 146/150, Fishing
  107 +25 with a lure timer near 4:12, Guns 105 +5, Fist Weapons, Polearms, Thrown and Riding
  unlearned), the summary reads "Samplehunter Mockstride · Lv 22 · Dwarf Hunter" behind the Hunter
  icon and the strip says the data is sample data. `/sm test` again: your own character everywhere.
- **SM-TEST-12** (new, AD-87-SM) `/sm test`, then the Journal's Alts tab: the columns are Samplehunter
  Mockstride (this character, first), then Mockflame Samplewick (Mage), Mockshield Sampleforge
  (Warrior) and Sampleblade Mockvale (Paladin). Every name starts `Sample` or `Mock`; hovering a
  name's header shows `Realm: Samplerealm` or `Realm: Mockrealm`, never a real realm.
- **SM-TEST-2** (round 5, R5-1) With the main window and the Journal closed, `/sm test`: both open,
  and three toasts stack: the Leatherworking 150 / 150 cap toast (its next rank and trainer), a weapon-gap
  toast for Daggers (red numbers) and a skill-up toast for Bows (green numbers). They stay up (no countdown) and drag as one
  stack. `/sm test` again: the toasts go and both windows close. Open the Journal first, then
  `/sm test` twice: the Journal stays open. Enter combat in test mode: the toasts go with it.
- **SM-TEST-3** (round 6, R6-2) Open the Journal, then `/sm test`: the amber strip "Test mode: the
  skills shown are sample data." shows under the Journal's title, the tabs and the log below it, and
  nothing overlaps. Hover the LDB feed: the same line sits under the tooltip's title. `/sm test`
  again: the strip and the line go and the Journal's tabs move back up. Right-click the Journal's
  strip: End test ends test mode.
- **SM-TEST-6** (AD-88-SM, the docked strip) `/sm test` with the main window and the Journal open, and
  hover the LDB feed (Tooltips > Tooltip style: Main window). In each of the three, the amber strip
  spans the full width directly under the title bar. It touches the bar's bottom edge with no gap,
  and the bar's title and marks stay visible. The summary line, the Journal's tabs and the tooltip's
  first block header sit just under the strip and none of them is covered. `/sm test` again: the
  strip goes and everything moves back up under the title bar. Repeat once under a second skin (for
  example WoW Midnight): the strip still sits under the bar.
- **SM-TEST-7** (AD-89-SM, the footer) Open the main window: the bonus legend (temp bonus,
  permanent bonus and, with thresholds on, threshold) sits on a 24 px footer along the window's
  bottom edge. The footer has a thin hairline across its top and no darker band of its own (the
  window's background shows through), the legend text is in the muted color, and the last row
  scrolls clear above the hairline. Switch skins: the hairline takes the new skin's divider color.
  Open the Journal on its Alts tab: the hint line ("Snapshots update on login, logout and every
  skill change...") sits on the same 24 px footer along the window's bottom edge, with the hairline
  over it and the text clear of the resize grip. On the Log tab the footer and its hairline are gone,
  and the log's rows reach as far down as before. Drag the grip: it still resizes the window.
- **SM-TEST-8** (AD-86-SM, the main window's title marks) Open the main window. At the top right,
  left to right: the lock, the journal mark, Expand / Collapse all, the settings gear, then the close
  X in the corner, evenly spaced (6 px apart, the X 6 px from the edge), all the same size and gray at
  rest. Hover each: its tooltip opens above it ("Lock or unlock the window", "Open the journal",
  "Collapse all blocks", "Open the settings panel", "Close") and the mark lights in the skin's link
  color, the X in red. Click the gear: the Skill Master settings open. The lock, the journal mark and
  Expand / Collapse all still do what they did. Repeat under a second skin (for example WoW Midnight).
- **SM-TEST-9** (AD-86-SM, the Journal's title marks) Open the Journal: at the top right, the lock,
  the settings gear, then the close X in the corner, at the same spacing as the main window's. Hover
  the gear: "Open the settings panel" above it, the gear in the link color. Click it: the settings
  open. The lock still locks and unlocks both windows, and the X closes the Journal.
- **SM-TEST-10** (AD-86-SM, the trainer popup's title marks) Open the trainer popup (click an
  unlearned weapon row): its title bar carries the settings gear left of the close X. Click the gear:
  the popup closes and the Skill Master settings open on top, not under it. The X still closes it.
- **SM-TEST-11** (AD-86-SM, the detached and merged bands) Detach a block: its band carries a settings
  gear in the top right corner, the dock, collapse, sort and filter marks to its left as before (the
  eye left of them when rows are hidden), evenly spaced at the main window's pitch (6 px between
  marks; the band's marks sit a little further apart than before the adoption, so the strip is a
  touch wider). Click the gear: the settings open. Merge two
  detached blocks: the merged window's band shows the gear in the corner, then dock all and collapse
  all. With Layout > Detached windows > Title band "On hover", the gear hides and shows with the rest
  of the band; with "Never", it is gone with the band.
- **SM-TEST-4** (round 6, R6-11) `/sm test`: Skill Master's waypoint arrow shows,
  pointing up and to the left at a sample weapon master with `240 yd` under it; no map pin is set.
  Drag it where you want it. `/sm test` again: it goes (a waypoint you had set before test mode comes
  back). Enter combat in test mode: it goes with the rest.
- **SM-TEST-5** (the R6-11 review) Set a trainer waypoint (the arrow points at it),
  then `/sm test`, right-click the sample arrow and pick Clear waypoint: the sample goes and the arrow points at the real
  trainer again, the map pin kept. `/sm test` again: the real arrow stays.
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

- **SM-PROBE-1** (amended, AD-79-SM) `/sm probe`: the debug console opens, if it was hidden, with a
  `/sm probe` header line and the JSON report under it, `skillLines` holding every skill (a collapsed
  header in the Skills tab is collapsed again afterwards). No copy window opens. Press the console's
  Copy and send the text to the author; it settles the assumed rows in `docs/forever-quirks.md`.
- **SM-PROBE-2** (new, AD-79-SM) With debug logging off (`/sm debug off`) and the console closed,
  `/sm probe`: chat shows exactly one line, `probe: 2 lines written to the debug console. Use Copy to
  share it.`, and the report is in the console all the same. `/sm list` still prints in chat.
- **SM-PROBE-3** (new, SMW-01) In the character panel, collapse one Reputation header (for example
  Other) and one Currency header, then close the panel. `/sm probe`: the JSON holds `factions`, `currencies`
  and `statistics`. `factions.rows` lists up to 60 factions, the collapsed header's factions among them, and
  `factions.byIDCollapsed` names that header; `currencies.rows` lists every currency; `statistics.categories`
  lists the categories (Character, Wealth, ...) with up to 3 rows each. Open the character panel: the headers
  you collapsed are still collapsed. Copy the report and send it to the author; it settles
  `docs/forever-quirks.md`'s "Reputations, currencies and Statistics" rows.
  Result:
- **SM-PROBE-4** (new, SMW-01) With the Reputation tab shown, `/sm probe`: no Lua error, the panel's headers do
  not move, and `factions.skipped` reads `panel shown`.
  Result:

## Trainer data (the offline probe, GitHub issue #3)

The probe confirmed 136 of 137 trainer records offline (`docs/trainer-probe/2026-11-23-r2/report.md`,
its *In-game spot checks* list). These checks are the spots no offline source settles. Record what
you see on each Result line; none is passed until you say so.

- **SM-TPROBE-1** (Alliance) In Stormwind, open the trainer popup for Swords (unlearned) or a weapon
  skill Woo Ping teaches, Set waypoint on Woo Ping: the pin and the arrow lead to him in the Trade
  District (63.9, 69.1 on Forever's Stormwind map), not to the Era spot. Then do the same for two
  Stormwind profession trainers (for example Tel'Athir in the Mage Quarter, Gelman Stonehand in the
  Dwarven District): each pin stands on the NPC.
  Result: PASSED (owner, 2026-11-23).
- **SM-TPROBE-2** (Horde) In Mulgore, at Bloodhoof Village: Set waypoint on
  Kar Stormsinger (riding): the pin stands on him (46.8, 62.0, a projected Mulgore point). In
  Orgrimmar's Valley of Honor, Sayoc and Hanashi have their own pins a step apart, and Makaru is the
  Mining trainer listed (no Gorina). In Undercity, Journeyman Alchemy lists Doctor Martin Felben.
  Result: PASSED (owner, 2026-11-23).
- **SM-TPROBE-3** (either faction) At one Journeyman trainer (for example Tel'Athir, Alchemy) and one
  Artisan trainer (for example Georgio Bolero, Tailoring), open the trainer window with the skill at
  the rank's gate: the Journeyman trainer offers Journeyman (150) and the Artisan trainer Artisan
  (300). The CMaNGOS 1.12 dump has each one rank lower; Skill Master keeps the titles.
  Result: PASSED (owner, 2026-11-23).
  Superseded (owner's ruling, 2026-11-23: "trust the source not my smoke test"; the owner checked
  Wowhead for Fimble Finespindle and Drakk Stonehand): a Journeyman-titled trainer trains Apprentice,
  an Expert-titled one Journeyman, an Artisan-titled one Expert, and a craft's Master trains Artisan.
  The data follows the source; SM-TPROBE-8 is the in-game check of the new ranks.
- **SM-TPROBE-4** (the books comment) Learn Cooking to 150 and open its trainer popup: Shandrina
  (Alliance) or Wulan (Horde) reads "Sells Expert Cookbook" on her card's second line, and Print to
  chat ends "· Sells Expert Cookbook". Hover the Cooking row: the tooltip's Trainer line says it too.
  The vendor sells the book. Fishing at 150: Old Man Heming "Sells Expert Fishing - The Bass and You",
  Nat Pagle "Quest: Nat Pagle, Angler Extreme". First Aid at 150: Deneb Walker or Balai Lok'Wein
  "Sells Expert First Aid - Under Wraps", and at 225 the Trauma Surgeon "Quest: Triage".
  Result: PASSED (owner, 2026-11-23).
- **SM-TPROBE-5** Open the Enchanting popup at 225 (Artisan): Annora (Uldaman) is the one card with
  the unverified mark and the warning "Not confirmed on WoW Forever yet (marked until checked)";
  Set waypoint is disabled (no coordinates), Print to chat gives Uldaman, Badlands. Any other
  popup with only confirmed trainers shows no warning.
  Result: PASSED (owner, 2026-11-24).
  Amended (the owner's feedback, 2026-11-24): Annora's point is now Uldaman's back entrance in the
  eastern Badlands (65.3, 42.6), so Set waypoint works on her card; she keeps the unverified mark and
  the warning. SM-TPROBE-13 is the re-check.
  Superseded (the owner, 2026-11-25): no trainer is shown as unverified; the mark, the warning and
  the Mark unverified trainers row are gone.
- **SM-TPROBE-6** (Horde) Bena Winterhoof (Thunder Bluff, Middle Rise) trains Alchemy to Expert
  (225), and Sayoc (Orgrimmar) teaches Staves: the two records the 1.12 dump disagrees with.
  Result: Superseded (owner's ruling, 2026-11-24: "trust the dump"): Bena Winterhoof trains Alchemy
  to Apprentice only, and Sayoc teaches no Staves. SM-TPROBE-14 is the check of the data as it now is.

### Round 2 (the owner's feedback, 2026-11-23)

- **SM-TPROBE-7** Cooking at 225/225: the popup's Artisan (300) heading reads "No trainer teaches
  Artisan Cooking. Artisan Cooking is learned from a quest: Clamlette Surprise, given by Dirge
  Quikcleave, Gadgetzan, Tanaris.", Dirge's card under it (Set waypoint leads to him), then "Trainers
  who teach Cooking" with your side's cooking trainers. First Aid at 225: the same for Triage (Doctor
  Gustaf VanHowzen, Theramore Isle, or Doctor Gregory Victor, Hammerfall); Fishing at 225: Nat Pagle,
  Angler Extreme. Cooking at 150: Expert Cooking "is learned from a book: Expert Cookbook".
  Result: PASSED (owner, 2026-11-24). Superseded the same day (the owner's feedback): the
  "Trainers who teach X" group under a quest or book rank is gone; SM-TPROBE-12 is the check.
- **SM-TPROBE-8** Leatherworking at 155/225 (the owner's case): Train: Leatherworking (Artisan) lists
  Drakk Stonehand, Aerie Peak, The Hinterlands (Alliance) or Hahrana Ironhide, Camp Mojache, Feralas
  (Horde), not Telonis or Una. Go to the Master and train Artisan (level 35, skill 200). Any other
  craft at 200+: its Master (Alchemy Kylanna Windwhisper or Rogvar, Blacksmithing Brikk Keencraft,
  Enchanting Annora, Engineering Buzzek Bracketswing, Tailoring Timothy Worthington or Daryl Stack)
  trains Artisan, and a capital's "Artisan"-titled trainer (Georgio Bolero, Una) offers Expert only.
  This re-checks SM-TPROBE-3's Artisan half, which every source contradicts. (Amended after the
  owner's ruling, 2026-11-23: at Expert, Leatherworking 125+, the trainer is Telonis or Una, and a
  capital's Expert-titled trainer, Fimble Finespindle or Simon Tanner, offers Journeyman only.)
  Result: PASSED (owner, 2026-11-24).
- **SM-TPROBE-9** At an Expert-titled capital trainer (for example Lilyssia Nightbreeze, Alchemy, or
  Simon Tanner, Leatherworking) with the skill at 125+, level 20+: does the trainer offer Expert (225),
  or only Journeyman (150)? The 1.12 dump and Method.gg say Journeyman; the data keeps Expert.
  Result: Superseded before it ran (owner's ruling, 2026-11-23, "trust the source not my smoke test";
  Wowhead's Fimble Finespindle): an Expert-titled trainer trains Journeyman, and the data now says so.
- **SM-TPROBE-10** Open a profession's trainer popup: a "Show all trainers" check box sits under the
  intro, skinned, with a tooltip. Tick it: every rank's trainers, Artisan (300) first, then Expert,
  Journeyman, Apprentice, each trainer once; the trainers of your next rank carry "Your next rank" in
  the skin's good color, and their card's tooltip names the rank. Switch skins: the mark stays
  legible. Untick it: back to the next rank only. Close and reopen, and `/reload`: the box keeps its
  state, and Settings > Trainers and Waypoints shows the same Show all trainers row. A weapon skill's
  popup has no check box.
  Result: PASSED (owner, 2026-11-24).
- **SM-TPROBE-11** (the Forever-only trainers) Spot-check a few, each marked unverified: on Zephras
  Isle, Nyassa Swiftdraught (Alchemy) and Halavuul Cragwind (Mining), listed for both factions; in
  Riverglades, Grungle (Mining) and Melbin Powderfuse (does he train Engineering, and to what rank?);
  one Junior trainer per faction (Alliance: Kelsey Fargo, Northshire, Elwynn Forest; Horde: Walter
  Mason, Tirisfal Glades): each pin stands on the NPC and the trainer window offers Apprentice.
  In Alterac Mountains: is it Linzy Blackbolt or Patricia Egan (one point in the data) who stands there?
  Result: PASSED (owner, 2026-11-24).

### Round 3 (the owner's feedback, 2026-11-24)

- **SM-TPROBE-12** First Aid at 225/225 with Show all trainers unticked: Train: First Aid (Artisan)
  lists Doctor Gustaf VanHowzen (Alliance) or Doctor Gregory Victor (Horde) under Artisan (300), with
  the Triage note, and no one else: no "Trainers who teach First Aid" group, and no unverified warning.
  Cooking at 225: Dirge Quikcleave alone. Fishing at 225: Nat Pagle alone. Fishing or Cooking at 150:
  the Expert book vendor and the Artisan quest giver, nobody below them. Tick Show all trainers: every
  trainer of the skill is back, each rank under its heading.
  Result: PASSED (owner, 2026-11-25).
- **SM-TPROBE-13** Enchanting at 225: Annora's card carries no unverified mark or warning (the owner,
  2026-11-25), and Set waypoint is enabled: the pin and arrow lead to Uldaman's back entrance in the eastern Badlands
  (65.3, 42.6). Print to chat gives Uldaman, Badlands (65.3, 42.6).
  Result: PASSED (owner, 2026-11-25: "assume all the SM checks pass").
- **SM-TPROBE-14** (Horde) Staves' popup lists Hanashi (Orgrimmar) and Ansekhwa (Thunder Bluff), not
  Sayoc; Sayoc still lists for Axes, Bows, Daggers, Fist Weapons and Thrown. Bena Winterhoof is under
  Apprentice in Alchemy's Show all trainers list.
  Result: PASSED (owner, 2026-11-25: "assume all the SM checks pass").

### Seed validation with ForeverDB (2026-11-25)

The 2026-11-25 seed run (`docs/seed-research/2026-11-25-forever/ANALYSIS.md`) checked every trainer
against ForeverDB. It changed one shipped row, a judgment call the owner may reverse here.

- **SM-SEEDFDB-1** (the one data change) Angelique Butler, First Aid Trainer in Alterac Mountains, is
  now Alliance, not Neutral. On an Alliance character with First Aid below 150, open the First Aid
  trainer popup with Show all trainers ticked: Angelique Butler is listed (Alterac Mountains). On a
  Horde character, the same popup does not list her. If you can reach her, she is friendly to
  Alliance and hostile or unfriendly to Horde.
  Result: PASSED (owner, 2026-11-25): accepted as built; the change is kept (her row stays Alliance).
- **SM-SEEDFDB-2** (needs owner review, no data changed) ForeverDB's trainer table disagrees with its
  own NPC titles on five Forever-only trainers. Talk to each and note what it trains: on Zephras Isle,
  Aedi Thriceforged (shipped Mining), Eaysaa Brightgust (Alchemy), Nasalanna Windsinger (Skinning) and
  Messana Crestwind (Leatherworking); in Durotar, Norzsh (Blacksmithing). Also check whether Durotar
  has Junior Skinning, Mining and Herbalism trainers (ForeverDB hints at Kagil, Norzsh and Zor'la).
  Result: PASSED (owner, 2026-11-25): accepted as built.

### ForeverDB in the addon (SF-SM-02, LibKa0s#105; retired by ISF-SM-01)

Ka0sAddonsCommonTasks `docs/2026-11-25-SEEDS_AND_FOREVERDB/`, item SF-SM-02: the optional ForeverDB
addon read through `LibKa0s-ForeverDB-1.0` (`modules/ForeverDBSources.lua`, Trainers > Use ForeverDB).
These rows passed and are kept as the record. The feature was removed on 2026-11-25 (ISF-SM-01, below):
only Drop Watcher reads ForeverDB now, so SM-FDB-1..5 no longer describe the addon.

- **SM-FDB-1** (with ForeverDB) On Forever with ForeverDB installed and enabled, log in and run
  `/dump C_AddOns.IsAddOnLoaded("ForeverDB")`: `false`, unless another addon you run loads it. Then
  `/sm diagnostics`: the report's identity section has a `ForeverDB: present=yes loaded=no`
  line with ForeverDB's version. No Lua error.
  Result: PASSED (owner, 2026-11-25).
- **SM-FDB-2** (with ForeverDB) A character whose Fishing, Cooking or First Aid is at 150/150 (the next
  rank, Expert, comes from a book). Hover that skill's row: under the Trainer line come the book's
  name with "ForeverDB" beside it, "Sold by" naming sellers of your faction only (three at most, then
  "+N more"), "Drops from" with up to three creatures and their chances ("rate unknown" where
  ForeverDB has none), and "World drop" when ForeverDB has a level for it. `/dump
  C_AddOns.IsAddOnLoaded("ForeverDB")` now answers `true` (the tooltip loaded it). Hover a skill whose
  next rank a trainer trains: no source lines.
  Result: PASSED (owner, 2026-11-25).
- **SM-FDB-3** (with ForeverDB) Open the same skill's trainer popup and hover the book seller's card
  (for Fishing, Old Man Heming): the card's tooltip ends with the same source lines as SM-FDB-2. Every
  other card is unchanged, and no card's tooltip says "Map position from ForeverDB": every shipped
  trainer has its own position, which ForeverDB never overrides.
  Result: PASSED (owner, 2026-11-25).
- **SM-FDB-4** (with ForeverDB) Settings > Skill Master > Trainers and Waypoints > Trainers: hover Use
  ForeverDB, on by default: its tooltip starts "Needs the ForeverDB addon". Untick it and hover the
  SM-FDB-2 row again: no source lines. Tick it again: they are back.
  Result: PASSED (owner, 2026-11-25).
- **SM-FDB-5** (without ForeverDB) Disable ForeverDB in the AddOns list and `/reload`. Hover the
  SM-FDB-2 row: the tooltip is as it was before this change (the Trainer line, then the helper and the
  click hint), with no Lua error. The trainer popup and its cards are unchanged. The Use ForeverDB row
  is still on the Trainers tab, and `/sm diagnostics` reports `ForeverDB: present=yes loaded=no`.
  Result: PASSED (owner, 2026-11-25).
- **SM-FDB-6** (Retail) Skill Master is Forever-only: on Retail it is not in the AddOns list (the TOC's
  load-gating pair), so there is nothing of it to load or check. Confirm it is absent from Retail's list
  with ForeverDB's presence making no difference.
  Result: PASSED (owner, 2026-11-25).

### Skill Master stops reading ForeverDB (ISF-SM-01, 2026-11-25)

Ka0sAddonsCommonTasks `docs/2026-11-25-ITEM_SEARCH_FEEDBACK/`, item ISF-SM-01 (spec §8): only Drop
Watcher reads ForeverDB. `modules/ForeverDBSources.lua`, the Use ForeverDB row and `## OptionalDeps:
ForeverDB` are gone; a book rank's sources and a trainer's position come from Skill Master's own data.

- **ISF-SM-01-1** On Forever with ForeverDB installed and enabled (and Drop Watcher disabled, so
  nothing else asks for it), log in and `/reload`. `/dump C_AddOns.IsAddOnLoaded("ForeverDB")`:
  `false`, and stays `false` after the steps below. Hover the row of a skill at 150/150 whose next rank
  comes from a book (Fishing, Cooking or First Aid): the Trainer line names the book's seller, then the
  helper and the click hint, with no "Sold by", "Drops from" or "World drop" lines. Open that skill's
  trainer popup and hover the seller's card: no ForeverDB lines. Settings > Skill Master > Trainers and
  Waypoints > Trainers has no Use ForeverDB row. No Lua error.
  Result: not run.

## Skins and diagnostics

- **SM-SKIN-1** `/sm skin`: pick Ka0s Default, Apply. The window and the debug console change look.
- **SM-SKIN-2** `/sm skin` once per shipped skin (every entry of the picker, WoW Forever included),
  Apply each: the window, a detached block, the Journal, the trainer popup, an alert toast and the
  broker tooltip all restyle, and every character on them draws (no empty boxes in the legend, the
  block headers' fallback marks, the Journal's `old -> new` or the stat tooltip's marker lines). The
  category colors stay told apart (Primary blue, Secondary green, Weapon orange, Other violet) and
  the lure's teal and the racial's blue bonus segments keep their own colors.
- **SM-SKIN-3** (LibKa0s v1.108.0, SD-RV-SM) `/sm skin`: Apply a skin with a glossy bar look (Glass).
  Every data bar (the window's rows, a detached block, the row tooltip's bar, the broker tooltip's
  mini bars, the Journal's mini bars) shows the skin's gloss over its fill; back on Ka0s Default the
  gloss goes. Show border off on the Bars page still draws no bar border under every skin.
  Result: PASSED (owner, 2026-11-24).
- **SM-SKIN-4** (SD-RV-SM) Settings > Layout > Detached windows: the Background block shows one Use
  the skin's background and the Border block one Use the skin's border, with no extra Use the skin's
  color rows, and each still switches the detached windows between the skin's look and the swatches.
  Result: PASSED (owner, 2026-11-24).
- **SM-SKIN-5** (SD-SK-SM.2, SM.3) Turn test mode on (the arrow shows on its sample trainer), then
  `/sm skin` and Apply another skin: the arrow's distance text takes the new skin's HUD text color
  and shadow at once, with no reload or reopen. Trainers and Waypoints > Arrow text shows Use the
  skin's color and Use the skin's shadow, both ticked; untick Use the skin's color and the text
  takes the Font color swatch.
  Result: PASSED (owner, 2026-11-24).
- **SM-SKIN-6** (U-7) Under Obsidian (or another skin whose window accent is not gold), hover a
  main window row, a trainer popup card, a Journal Alts column header and the waypoint arrow: each
  tooltip's title is the tooltip gold, its lines the tooltip's light gray and its hints dim gray,
  all legible on the dark game tooltip; a row tooltip's good, warning and bonus colors keep their
  meaning hues.
  Result: PASSED (owner, 2026-11-24).
- **SM-SKIN-7** (U-31, SkillMaster#9) Open the trainer popup and move the pointer over each card: the
  card under the pointer takes the skin's hover wash and loses it when the pointer leaves; the
  selected card shows the hover while under the pointer and is selected again after. Switch skins
  with the popup open and hover again: the wash is the new skin's. The Journal's rows take no hover.
  Result: PASSED (owner, 2026-11-24).
- **SM-SKIN-8** (SD-SK-SM.1) Settings > Skin: clear Ignore settings panel. On the Rows page the eye
  marks take the skin's icon tint, and a dimmed eye is dimmed, not white. Tick Ignore settings panel
  again: the eyes are the client's white, a dimmed one still dimmed. Open another settings page that
  uses icons: none of them is left tinted or dimmed.
  Result: PASSED (owner, 2026-11-24).
- **SM-DIAG-1** `/sm diagnostics`: the report appears in the debug console with the ten sections
  (identity, settings, state, skin, model, probe, bonuses, layout, sim, rejected).

## Feedback batch (2026-11-24)

Ka0sAddonsCommonTasks `docs/2026-11-24-FEEDBACK_BATCH/`, items FB-SM-01 to FB-SM-06.

- **SM-FB-1** (FB-SM-01, S4) Log in on Forever after the LibKa0s v1.112.0 re-vendor: no Lua error.
  The main window, the Journal, a detached block's band and a merged window's band still carry the
  gear, and it opens the settings. A detached or merged window's title band is not an unlock strip:
  right-clicking it does nothing new.
  Result:
- **SM-FB-2** (FB-SM-03, T) Click a row's Go icon to open the trainer popup: its title bar carries
  the close alone, no gear. The close and Escape still close it, and it still closes with the main
  window.
  Result:
- **SM-FB-3** (FB-SM-02, P) Bars > Fill with Color mode Flat, then tick Use class color on the Bar
  color, Background color, Border color and Font color blocks while each Use the skin's color stays
  ticked: the bars' fill, background, border and text draw your class color (green on a hunter).
  Untick Use class color: the skin's colors come back. Do the same on Layout > Detached windows
  (Background, Border), Bars > Icons (Border color, with Use the row's color off) and Trainers and
  Waypoints > Trainers > Trainer name color: each draws the class color while the skin's is ticked.
  Result:
- **SM-FB-4** (FB-SM-06, S3) Open Settings > Skill Master > Trainers and Waypoints: two tabs,
  Trainers (Show all trainers, Trainer popup's Trainer name color) and
  Waypoints (Waypoint method, Say where in chat, the Waypoint arrow, Arrow text and Arrow position
  subgroups with Reset position). Defaults resets the rows on both tabs. The arrow's right-click
  Arrow settings... still opens this page.
  Result:
- **SM-FB-5** (FB-SM-05, S2) With TomTom installed and Show Skill Master's arrow off, `/sm test`:
  Skill Master's sample arrow shows, labeled "Sample: Skill Master's arrow is off" (with the arrow on
  and TomTom loaded: "Sample: TomTom's arrow points to real waypoints"). No TomTom waypoint appears.
  Untick or tick Show Skill Master's arrow during test mode: the sample stays. `/sm test` again: it
  goes.
  Result:
- **SM-FB-6** (FB-SM-04, S1) Detach a block. Its window shows a corner resize grip: drag it wider
  and narrower. The rows follow the width, the height stays the rows' height, and the window does
  not jump. Layout > Blocks > the block's Block width slider shows the new width (a multiple of 10).
  `/reload`: the width and the place are kept. Tick Lock this block, or `/sm lock`: the grip hides
  and a drag on the corner does nothing; unlock: it is back. Merge two detached blocks of different
  widths: the merged window's columns are the wider one's width.
  Result:

### Round 2 (the owner's smoke feedback, 2026-11-24)

Ka0sAddonsCommonTasks `docs/2026-11-24-FEEDBACK_BATCH/R2_SMOKE_FEEDBACK.md`, item FB2-SM-01.

- **SM-FB2-1** (FB2-SM-01, D2) Log in on Forever after the LibKa0s v1.113.0 re-vendor: no Lua error.
  With the step panel closed, `/sm sim start fishingTrip`: the session runs and the step panel opens.
  `/sm sim stop`, close the panel, then `/sm sim`: the panel opens and nothing
  starts. Click the panel's Start row: the session runs with the panel still shown. Close the panel
  while the session runs, then `/sm sim restart`: a fresh session runs and the panel opens again.
  Result:
- **SM-FB2-2** (FB2-SM-01, D2) With the step panel closed, tick General > Master controls > Sim mode,
  and separately pick the launcher menu's Sim mode entry: each opens the step panel.
  Result:
- **SM-FB2-3** (FB2-SM-01, D3) Settings > Skill Master > General > Skin: Azeroth. Open the Journal's
  Log tab and its range picker: the selected range reads gold, the other ranges parchment text.
  Click a block header's sort mark: the current order's row reads gold beside its tick. Back to Ka0s
  Default and Obsidian: the selected rows read gold too, not Obsidian's blue accent. On Forever,
  under the default WoW Forever skin, repeat both menus: the selected rows read gold, not its tan
  accent. In every skin the selected row reads gold and its text differs from the others.
  Result:
- **SM-FB2-4** (FB2-SM-01, D1) `/sm test`: the window and the Journal's Alts tab show the same names
  as SM-TEST-1 and SM-TEST-12 (Samplehunter Mockstride first, then the Mage, Warrior and Paladin),
  every name starting `Sample` or `Mock`. `/sm sim start fishingTrip`: the simulated character is
  Samplehunter Mockstride too.
  Result:

## Six windows (SMW-04, 2026-11-26)

`docs/superpowers/specs/2026-11-26-skillmaster-windows-design.md`. Record what you see on each Result line;
none is passed until you say so.

- **SM-WIN-1** (new, SMW-04) After the upgrade, `/sm toggle`: the window titled "Skill Master · Professions"
  opens where your old Skill Master window stood, at its old width, columns and strata, and holds Primary
  Professions and Secondary Skills only.
  Result:
- **SM-WIN-2** (new, SMW-04) `/sm skills`, `/sm stats`, `/sm currencies`, `/sm reputations`, `/sm statistics`:
  each opens its own window ("Skill Master · Skills" with Weapon Skills and Other skills, "Skill Master ·
  Character Stats" with the four stat blocks, the other three with "Nothing to show yet."), stacked down and
  to the right of the Professions window the first time. A second verb hides that window alone; `/sm hide`
  hides them all; Escape closes the one in front.
  Result:
- **SM-WIN-3** (new, SMW-04) Drag the Skills window somewhere, `/reload`: it comes back there, and the
  Professions window stays where it was. General > Reset position puts every window back.
  Result:
- **SM-WIN-4** (new, SMW-04) Options > Keybindings > Ka0s Skill Master lists seven rows: Toggle Professions
  window, Toggle Skills window, Toggle Character Stats window, Toggle Currencies window, Toggle Reputations
  window, Toggle Statistics window, Toggle journal. A key you had on the old "Toggle skills window" row is now
  on Toggle Professions window. Bind one to the Skills row: it toggles the Skills window alone.
  Result:
- **SM-WIN-5** (new, SMW-04) Layout > Window: one subsection per window (Professions, Skills, Character
  Stats, Currencies, Reputations, Statistics). Change the Character Stats window's width and strata: only that
  window changes. Each window's corner grip writes its own Window width and Window height.
  Result:

## Six brokers (SMW-05, 2026-11-26)

- **SM-FEED-1** (new, SMW-05) In your broker display (Titan Panel, ChocolateBar, ...), the "Skill Master" and
  "Skill Master Stats" cells you had are still in their places; the second is labeled "Skill Master Character
  Stats". The display offers four new feeds: Skill Master Skills, Skill Master Currencies, Skill Master
  Reputations and Skill Master Statistics.
  Result:
- **SM-FEED-2** (new, SMW-05) With nothing pinned, each feed reads its window's short name (Professions,
  Skills, Character Stats, ...). Pin a weapon skill from a row's menu: the Skills feed shows it and the
  Professions feed does not. Gain a weapon skill point: the Skills feed flashes, Professions does not.
  Result:
- **SM-FEED-3** (new, SMW-05) Hover each feed: its tooltip's title is its window's ("Skill Master ·
  Professions" with Primary and Secondary only, "Skill Master · Skills" with Weapon and Other, "Skill Master ·
  Character Stats" with the four stat blocks, the other three "Nothing to show yet."). Left-click each feed:
  its own window toggles. Right-click: the Broker settings page opens.
  Result:
- **SM-FEED-4** (new, SMW-05) Settings > Broker > Feed: one subsection per feed, each with its own Feed text
  presets and Custom box; your old feed text is now the Professions feed's. Tooltip: each feed's section
  switches under its own name.
  Result:

## Pins per broker (SMW-06, GitHub issue #11, 2026-11-26)

- **SM-PIN-1** (new, SMW-06) After the upgrade, a skill you had pinned is still on its feed: a profession on
  the Skill Master (Professions) feed, a weapon skill on Skill Master Skills; a stat you had pinned on Skill
  Master Character Stats.
  Result:
- **SM-PIN-2** (new, SMW-06) Right-click Cooking in the Professions window: the menu reads "Pin to the
  Professions broker" with a tick box. Tick it, then pin Fishing the same way: the Skill Master feed shows
  both, joined by " · ", and Cooking stays pinned. Right-click Cooking again: its tick is on; click it and only
  Cooking goes.
  Result:
- **SM-PIN-3** (new, SMW-06) Pin five rows to one broker: a sixth row's "Pin to the ... broker" is grayed and
  its tooltip says five are pinned. Another window's rows can still pin to their own broker.
  Result:
- **SM-PIN-4** (new, SMW-06) Hover a feed with pins, in both Tooltip styles (Tooltips > Tooltip style): a
  "Pinned" section comes first, its rows in pin order, then the feed's own sections.
  Result:
- **SM-PIN-5** (new, SMW-06) Settings > Broker > Pins: each broker's pins in order, each with move up, move
  down and unpin marks; a broker with none says "Nothing pinned.". Move one and unpin one: the feed text and
  its tooltip follow at once. Custom feed text `{pinned2}` shows the second pin alone.
  Result:
- **SM-PIN-6** (new, SMW-06) `/sm test`: the Professions feed shows the sample's Fishing pin and a row's Pin is
  grayed; end test mode: your own pins are back, unchanged.
  Result:

## The LDB tooltip: only the fold acts (SMW-07, 2026-11-26)

- **SM-TIP-1** (new, SMW-07) Hover the Skill Master feed (Tooltips > Tooltip style: Main window). Click the
  chevron on Secondary Skills: the section folds in the tooltip, which stays up where it was; click it again: it
  opens. The Professions window's Secondary Skills block did not fold, and folding it in the window leaves the
  tooltip's section open.
  Result:
- **SM-TIP-2** (new, SMW-07) Set Tooltips > Height low enough that the tooltip scrolls, scroll down a little,
  then fold and unfold a section: the body stays where you scrolled it (no jump to the top).
  Result:
- **SM-TIP-3** (new, SMW-07) In the tooltip, left-click, shift-click and right-click a row, and click its go
  icon, a crafting row's included: nothing opens, nothing is linked, no menu shows. Hovering a row still
  highlights it and shows its row tooltip, with no click hint. Clicking the header's title does nothing; only
  the chevron folds.
  Result:
- **SM-TIP-4** (new, SMW-07) Tooltips > Tooltip style: Classic. Each section header now starts with a chevron;
  clicking it folds and unfolds that section in place. Rows still wash on hover and take no click.
  Result:
- **SM-TIP-5** (new, SMW-07) Tooltips > LDB tooltip has no "Open a row from" row any more; the footer reads
  "Click label: toggle window · Right-click label: options · Click a chevron to fold". The feed's own left
  click still toggles its window and its right click opens Broker settings. In test mode the tooltip's test
  strip takes no click.
  Result:

## Reputations (SMW-08, GitHub issue #6, 2026-11-26)

- **SM-REP-1** (new, SMW-08) `/sm probe` first; then `/sm reputations`: the Reputations window lists your
  factions as the character panel's Reputation tab groups them (Alliance or Horde, Steamwheedle Cartel under it
  with its own bar, Other, Inactive when you have one), each faction a bar "Honored 3,672 / 12,000" in the
  standing's color; an Exalted faction is a full bar reading "Exalted".
  Result:
- **SM-REP-2** (new, SMW-08) Collapse Steamwheedle Cartel and Other in the character panel's Reputation tab,
  close the panel, `/reload`: the window still lists their factions, and the Reputation tab is still collapsed
  as you left it.
  Result:
- **SM-REP-3** (new, SMW-08) Click a header's chevron (or the header row) in the window: it folds there, and
  the Reputation tab's own headers do not move. `/reload`: the fold is kept. Expand / Collapse all in the title
  bar folds and opens every header, the block left open (SMW-REV).
  Result:
- **SM-REP-4** (new, SMW-08) Gain reputation (kill a faction's mob, or turn in a quest): the bar moves within a
  moment, the Journal's Log shows one line for that faction with "+N", growing with each later gain this
  session, and the row's tooltip says "This session +N". The skill-up counts do not change.
  Result:
- **SM-REP-5** (new, SMW-08) Right-click a faction: "Pin to the Reputations broker"; the Skill Master
  Reputations feed then reads "Stormwind Honored 3,672 / 12,000" (your faction's). Hover the feed in both
  tooltip styles: the Pinned section, then the tree; a header's chevron folds it in the tooltip only.
  Result:
- **SM-REP-6** (new, SMW-08) With the character panel's Reputation tab open, and again in combat, gain
  reputation: nothing in the panel moves or flickers, and the window still updates.
  Result:
- **SM-REP-7** (new, SMW-08) The Journal's Alts tab has a Reputations sub-tab: each character's standing per
  faction (log in on an alt first to record it).
  Result:

## Currencies (SMW-09, GitHub issue #7, 2026-11-26)

- **SM-CUR-1** (new, SMW-09) `/sm currencies`: the Currencies window lists your currencies under the Currency tab's
  own headers, each with its icon; a currency with a cap is a bar "1,200 / 75,000", one without a cap a plain
  amount. Gold is not in the list. A character with no currencies sees "No currencies to show yet.".
  Result:
- **SM-CUR-2** (new, SMW-09) Collapse a header in the character panel's Currency tab, close the panel, `/reload`:
  the window still lists that header's currencies, and the Currency tab is still collapsed as you left it.
  Fold a header in the window: the Currency tab does not change.
  Result:
- **SM-CUR-3** (new, SMW-09) Hover a capped currency: its amount, its cap, "This week 800 / 10,000" where it has a
  weekly cap, and its description.
  Result:
- **SM-CUR-4** (new, SMW-09) Earn a currency (or spend one): its row moves at once; the Journal's Log shows one
  line for it with "+N" (or "-N") for this session, and the skill-up counts do not change. Do it with the
  Currency tab open, and again in combat: nothing in the panel moves.
  Result:
- **SM-CUR-5** (new, SMW-09) Right-click a currency: "Pin to the Currencies broker"; the Skill Master Currencies
  feed reads its name and amount; its tooltip (both styles) lists the Pinned section, then the tree.
  Result:
- **SM-CUR-6** (new, SMW-09) Settings > Alerts > Currency cap alert is off; turn it on, and bring a capped
  currency to its cap: one toast, in the warning color, with the currency's icon. It does not toast again this
  session.
  Result:
- **SM-CUR-7** (new, SMW-09) The Journal's Alts tab has a Currencies sub-tab with each character's amounts.
  Result:

## Statistics (SMW-10, 2026-11-26)

- **SM-STAT-1** (new, SMW-10) `/sm statistics`: the Statistics window lists the character panel's Statistics tab's
  categories (Character, Combat, ...), every one folded. Open Character: its rows first ("Times camped 58",
  "Talent tree respecs --"), then its own folded sub-categories (Wealth, Consumables). Open Wealth: its rows under
  it, one level deeper. Fold Character: Wealth goes with it; open Character again: Wealth is still open.
  Result:
- **SM-STAT-2** (new, SMW-10) Compare a few values with the Statistics tab itself: the same numbers, "--" where the
  tab shows "--"; note what Total gold acquired shows (a number or money text).
  Result:
- **SM-STAT-3** (new, SMW-10) With the window open on an unfolded category, do something it counts (camp, post an
  auction, kill something): the value moves within about a second. Close the window: `/sm debug` shows no
  Statistics read while it is closed and nothing is pinned.
  Result:
- **SM-STAT-4** (new, SMW-10) Right-click a statistic: "Pin to the Statistics broker"; the Skill Master Statistics
  feed reads "Times camped 58". Close the window and change that statistic: the feed text follows. `/reload`:
  the feed shows it again at once. A category's menu has no pin.
  Result:
- **SM-STAT-5** (new, SMW-10) Hover the Skill Master Statistics feed (both tooltip styles): the categories, folded;
  click a category's chevron: it opens in the tooltip only, the window's folds do not change.
  Result:
- **SM-STAT-6** (new, SMW-10) The Journal's Alts tab has no Statistics sub-tab. The window's title says
  "Skill Master · Statistics", and nothing in it says "stats".
  Result:

## Test mode and the simulator: the tree families (SMW-11, 2026-11-26)

- **SM-PRE-1** (new, SMW-11) `/sm test`: the Reputations window shows the sample's standings under Alliance,
  Steamwheedle Cartel and Other (Stormwind "Honored 3,672 / 12,000"); the Currencies window Honor Points
  "1,200 / 75,000" and Darkmoon Prize Ticket "12"; the Statistics window Character, Combat and Deaths, folded, and
  Character opens on "Times camped 58". Folding there and turning test mode off leaves your own folds as they were.
  Result:
- **SM-PRE-2** (new, SMW-11) In test mode the Reputations, Currencies and Statistics feeds read the sample's pins
  ("Stormwind Honored 3,672 / 12,000", "Honor Points 1,200 / 75,000", "Times camped 58"); your own pins come back
  when test mode ends. The Journal's Alts tab shows the sample's standings and currencies.
  Result:
- **SM-PRE-3** (new, SMW-11) `/sm sim`, run the fishing trip to its end: its last two steps raise Stormwind by 250
  and Honor Points by 150, the windows and feeds follow, and the Journal's Log gains a line for each. Stop: your
  own reputations, currencies and Statistics are back, and the saved Log has no simulated line.
  Result:

## The six windows, end to end (SMW-12, 2026-11-26)

- **SM-SMW-1** (new, SMW-12) Open all six windows (`/sm professions`, `skills`, `stats`, `currencies`,
  `reputations`, `statistics`) and play for a while: no Lua error, and `/sm diagnostics` lists no rejected event
  (`UPDATE_FACTION`, `CURRENCY_DISPLAY_UPDATE`, `CRITERIA_UPDATE` among the accepted).
  Result:
- **SM-SMW-2** (new, SMW-12) `/sm help` lists the six window verbs; the README's Usage and FAQ match what you see
  (Character Stats are the paper doll's numbers, Statistics the Statistics tab's counters; no gold row).
  Result:

## Review fixes (SMW-REV, 2026-11-26)

- **SM-REV-1** (new, SMW-REV) Collapse Other in the character panel's Reputation tab, leave the panel on that tab
  and close it, then `/reload`: the Reputations window lists Other's factions at once, without opening the panel
  on another tab first, and the Reputation tab is still collapsed as you left it. Do the same on the Currency tab
  for the Currencies window.
  Result:
- **SM-REV-2** (new, SMW-REV) Collapse Other in the Reputation tab and close the panel. In combat, gain
  reputation with a faction you have not met yet: the Reputations window keeps every faction under Other while
  you fight, and the new faction joins the list as combat ends. Likewise earn a currency new to you in combat
  with a Currency tab header collapsed: the Currencies window keeps that header's currencies.
  Result:
- **SM-REV-3** (new, SMW-REV) Open the Statistics window on an unfolded category, close it, do something that
  category counts (camp, kill something), and open the window again: the new value shows at once. Hover the
  Statistics feed with a category unfolded in its tooltip, leave, change that statistic, hover again: the tooltip
  shows the new value.
  Result:
- **SM-REV-4** (new, SMW-REV) Tooltip style Classic. Hover the Skill Master Statistics feed, open Character in the
  tooltip, then click Wealth's chevron (one level in): Wealth unfolds. On the Reputations feed, click Steamwheedle
  Cartel's chevron (under Alliance or Horde): it folds and unfolds. A click on the chevron where it is drawn acts,
  at every depth.
  Result:
- **SM-REV-5** (new, SMW-REV) In the Statistics window, with every category folded, the title bar's control reads
  "Expand all headers": click it, and every category and sub-category opens with its values. It then reads
  "Collapse all headers": click it, and every category folds, the categories still listed. The Reputations and
  Currencies windows do the same with their headers; the Professions, Skills and Character Stats windows still
  collapse and expand their blocks ("Collapse all blocks").
  Result:
- **SM-REV-6** (new, SMW-REV) `/sm stats`: the Skill Master · Character Stats window's four blocks read Base &
  Combat, Spell & Regen, Defense & Resists and Utility, with no "Stats ·" in front; so do the Character Stats
  feed's tooltip sections in both styles. Detach one: the detached frame reads "Stats · Base & Combat" as before.
  Result:

## Owner feedback round 5 (R5-SM, 2026-11-26)

- **SM-R5-1** (new, R5-SM-01) Hover a fold chevron in each window (a block header's in Professions, a category's
  in Statistics, a header's in Reputations) and in the LDB tooltip (a section's chevron, a tree header's): no hint
  tooltip appears ("Fold this section in the tooltip", "Unfold", "Collapse this block" are gone). The other header
  marks (detach, sort, filter) still show theirs.
  Result:
- **SM-R5-2** (new, R5-SM-02) In the Professions window, click a block header's title or the empty band right of
  it: the block collapses, and a second click opens it. In the Statistics window, click a category's name (not
  its chevron): it unfolds; click a sub-category's name one level in: it unfolds too. Do the same in the LDB
  tooltip, Tooltip style Main window (a section header's band, a Statistics category's row) and Classic (anywhere
  on a header line, a nested one included): each folds and unfolds in the tooltip alone, the window untouched.
  The footer reads "Click a header to fold".
  Result:
- **SM-R5-3** (new, R5-SM-03) Pin two professions and a stat (row menu, Pin to the ... broker), and a reputation:
  each pinned row shows a small pin mark at the right end of its name column, in its window and in its feed's
  LDB tooltip (both its Pinned section and its own section). The marks stand in one column whatever the names'
  lengths, a long name stops short of the mark, and the bars do not move. Switch Tooltips > Tooltip style to
  Classic and hover the feed again: each pinned line shows the mark just left of its mini bar (R5-REV). Unpin
  one: its mark goes at once.
  Result:
- **SM-R5-4** (new, R5-SM-04) Put the six Skill Master feeds on your display bar (Titan Panel or the like): each
  draws its own icon (Professions an anvil and hammer, Skills a sword, Character Stats the Strength icon,
  Currencies a pile of coins, Reputations a guild tabard, Statistics a note), none a green or blank square and
  none the Ka0s logo. The addon's own control broker (Ka0s Skill Master) and the minimap button keep the logo.
  Result:
- **SM-R5-5** (new, R5-SM-05) With every window closed, `/sm toggle`: all six windows open (Professions where the
  old window stood, each other where you last dropped it). `/sm toggle` again: all six close. Open one window
  (`/sm statistics`) and `/sm toggle`: it closes and nothing else opens. `/sm professions` opens and closes the
  Professions window alone; so do the minimap button's Show window and its key binding (Options → Keybindings →
  Ka0s Skill Master → Toggle Professions window). `/sm help` lists `toggle` as "Show or hide every Skill Master
  window".
  Result:
- **SM-R5-6** (new, R5-SM-06) With Leatherworking, Skinning, Cooking, First Aid and Fishing learned, open the
  Professions and Skills windows and hover the Skill Master feed in both tooltip styles: each profession is listed
  once (the client lists each twice, a parent and a child line), and none shows up again under Other.
  Result:
- **SM-R5-7** (new, R5-SM-07) `/sm toggle` to open all six windows, then play for a while: gain reputation and a
  currency, skill up, fight, level if you can, unfold categories in the Statistics and Reputations windows, and
  hover every feed in both tooltip styles. No Lua error, and `/sm diagnostics` lists no rejected event. `/sm toggle`
  closes all six.
  Result:

## Owner feedback round 5, addendum A1 (R5-SM-08..12, 2026-11-26)

- **SM-R5-8** (new, R5-SM-08) Detach Primary Professions (its header's detach mark) and Reputations, then drag
  Reputations onto the bottom edge of Primary until they join into one "Primary · Reputations" window. A resize
  grip shows in its bottom-right corner: drag it wider and narrower; the window follows, the height stays the
  rows', and on release it keeps the new width (`/reload`: still that width). Drag Reputations onto Primary's right
  edge instead (two columns): the grip widens both columns together. `/sm lock`: the grip hides; `/sm unlock`: it
  is back. Right-click the band, Unmerge all: each window has its own grip again at its own old width.
  Result:
- **SM-R5-9** (new, R5-SM-09) `/sm reputations`: each header (Alliance, Steamwheedle Cartel, Other) shows the detach
  mark at its right end. Click Alliance's: a window titled "Alliance" opens with Darnassus, Gnomeregan Exiles,
  Ironforge and Stormwind, and the Reputations window no longer lists Alliance or those four. Drag it somewhere,
  collapse it with its chevron, resize it with its grip, then `/reload`: it comes back where you left it, collapsed
  and at that width. Drag it onto a detached Primary Professions window's edge: they join ("Primary · Alliance").
  Click its dock mark (or the joined window's Dock all): Alliance is back in the Reputations window in its place.
  `/sm statistics`: open Character and detach Wealth (a nested category): a "Wealth" window shows its statistics
  even with Character folded again in the Statistics window; detach Character too and its window lists its own
  rows, Consumables, Reputation and Gear but not Wealth. `/sm currencies`: detach Player vs. Player: Honor Points
  moves to its own window. Hover each feed: its tooltip still shows the whole tree and no detach mark. With
  Alliance and Player vs. Player still detached, log in an alt on the same profile that lacks one (a Horde
  character, or one with no Honor Points): no empty "Alliance" or "Player vs. Player" window shows; back on the
  first character, both windows are where you left them.
  Result:
- **SM-R5-10** (new, R5-SM-10) `/reload`, then `/sm journal`, Log tab: no reputation or currency row appears for the
  login itself. Kill a few mobs that give reputation, and earn or spend a currency (Honor Points, a Merchant's
  Favor): each kill's reputation is its own row (the faction's name in the Name column, "+5" or the like in
  Change), each currency change its own row, a spend reading negative ("-20"). When a standing changes (say
  Friendly to Honored), that row reads "+25, Honored". Skill-ups still log beside them, newest first. Keep the
  Journal open while you kill: each row appears as it happens, without closing and reopening the Journal.
  Result:
- **SM-R5-11** (new, R5-SM-11) `/sm journal`, Log tab: the headers read DATE, TIME, NAME, CHANGE, ZONE. Hover one: a
  tooltip says "No filter" and "Click to filter this column." Click NAME: a menu offers Everything, Skill-ups,
  Reputations, Currencies and a submenu per kind of the names in the range; pick Reputations: only faction rows
  remain, the NAME header turns the accent color with a small funnel beside it, the summary card reads
  "Reputation · All time · filtered" with the net change (signed), and a Clear filters button appears under New
  session. Click ZONE and pick a zone: both filters apply together. Try DATE (Today, Yesterday, a listed day), TIME
  (Morning and the like) and CHANGE (Gains, Losses, Standing changes). Click Clear filters: every row is back, the
  headers return to their color and the button goes. `/reload`: the Log opens unfiltered.
  Result:
- **SM-R5-12** (new, R5-SM-12) The rest of the Journal: with nothing logged (Clear log, then accept), the Log reads
  "Nothing logged yet."; pick Current session after an older row exists: "Nothing logged in this range." Clear log
  asks "Clear this character's Journal log? Every skill-up, reputation and currency row is removed." Filter NAME to
  Reputations: the ETA to cap card reads "The filter leaves no skill-ups to time." Alts tab, Reputations and
  Currencies sub-tabs on a character with none recorded: "No character has a reputation (currency) recorded yet."; the
  footer reads "Snapshots update on login, logout and every skill, reputation or currency change." Settings →
  Journal: *Skill-ups to keep* says the Log keeps as many reputation and currency changes besides, and *Log shows*
  names skill-ups, reputation and currency changes. `/sm test` (test mode): the Log shows Honor Points +34, an
  Ironforge row "+25, Revered", a Darkmoon Prize Ticket spend "-8" and a Stormwind gain among the sample skill-ups.
  `/sm diagnostics`: the model line counts skill-ups, reputation and currency rows apart.
  Result:
