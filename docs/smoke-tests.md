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
| Waypoints (no TomTom, round 7) | SM-DISP-7, SM-OPT-5, SM-SEAM-2, SM-DISP-47 |
| Each skin | SM-SKIN-1, SM-SKIN-2 |
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
  of its sort mark, no other header does; its tooltip reads `Showing: All. Click to filter.` Click it:
  a menu under the mark, Show, then All (ticked), Learned, Equipped, Below cap. Learned: the
  not-learned weapons leave. Equipped: only the main hand, off hand and ranged weapons' skills stay,
  and the funnel turns the accent color; swap the main-hand weapon for another type: the block follows
  at once. Unequip the main hand with Equipped on and no Unarmed row: the header stays, with
  `No rows match this filter.` under it. Below cap: only learned skills under their cap. Click the
  mark again with the menu open: it closes. Detach the block: the band carries the funnel; merge it
  with another detached block: its sub-header carries it, the other section's does not. Layout >
  Blocks > Weapon Skills > Show rows shows the same choice. `/reload` and a profile switch: the
  filter is the profile's. The LDB tooltip still lists every weapon.
- **SM-DISP-30** (round 5, R5-14: the trainer popup's wrap) Open the trainer popup on an unlearned
  weapon (Fist Weapons, Staves): a weapon master's `Also teaches:` line wraps onto a second line
  inside its card instead of being cut off, the card is taller by that line and the window by every
  such card; the buttons stay below the last card. Hover a card: a tooltip with the
  trainer's name, place and the whole `Also teaches` list.
- **SM-DISP-31** (round 5, R5-15: the trainer distance) In Stormwind, open the trainer popup on an
  unlearned weapon: each weapon master in a city on your continent shows `N yd` under its cost, the
  nearest first; one on the other continent, or without coordinates, shows none and comes last.
  Walk towards another trainer with the popup open: within about a second the yards change and the
  cards reorder; the trainer you selected stays selected. Compare one card's yards with Skill Master's
  arrow (roughly equal: a straight line). Enter an instance (or a battleground) with the popup open: no
  distances, no error.
- **SM-DISP-39** (round 6, R6-10) On a new profile, hover the broker feed: the tooltip looks like the
  main window, as wide as it, in the skin's shell with the title band (Skill Master, the session's
  gains at the right): the window's block headers (chevron, title, the sort mark; the funnel on
  Weapon Skills), its rows (icon, name, the bar with its text inside it, the action mark at the
  right end), at the window's row height and fonts, the footer hints under them. Collapse Weapon
  Skills in the window, hover again: its header shows the right chevron and no rows. Set the weapon
  filter to Learned and the sort to Value, highest first: the tooltip follows both. Click a header,
  its chevron or its marks: nothing happens. Left-click a weapon row: Skills opens; right-click it:
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
  does not show, and Skill Master's solid chevron shows above the screen's center with the yards
  under it in the skin's body font. Turn on the spot: the chevron turns to keep pointing at the
  trainer (turn left and it turns right). Face the trainer: it points straight up. Far away (300 yd
  or more) it is the skin's accent; walk in: it shades into the skin's green by 30 yd. Within about
  5 yd it goes, the map pin clears and chat says `You have arrived: <trainer>`.
- **SM-DISP-44** (round 6, R6-11) With the arrow up: hover it: the tooltip names the trainer and the
  place with `Right-click to clear the waypoint. Drag to move the arrow.` Drag it elsewhere, `/reload`
  and set a waypoint again: it shows where you left it. `/sm lock`: it no longer drags. Right-click it:
  it goes and the map pin clears. Set it again and click elsewhere on the world map to place your own
  pin: the arrow goes. Set it again and pick another trainer's Set waypoint: the arrow points at the
  new one. Enter an instance (or ride to another continent): the art goes and the trainer's name
  shows alone, dimmed. Enter combat: it stays.
- **SM-DISP-45** (round 6, R6-11) Trainers and Waypoints: Arrow scale 1.5: the arrow grows at once.
  Untick Show Skill Master's arrow with it up: it goes and the game's own arrow points at the pin;
  set a waypoint again: the game's arrow, no Skill Master arrow. Tick it again.
- **SM-DISP-46** (the R6-11 review) A waypoint set and Skill Master's arrow up. Press
  Alt+Z twice: the arrow comes back and still turns as you turn and counts the yards down (walk in:
  `You have arrived` still prints). Make a second profile with Show Skill Master's arrow off and
  switch to it with the arrow up: it goes and the game's own arrow points at the pin. Switch back,
  set the waypoint, then switch to a profile whose arrow is at scale 2 and dragged elsewhere: the
  arrow takes that scale and place at once.
- **SM-DISP-47** (round 7, R7-7: no TomTom) With TomTom, or an addon that answers TomTom's API (the
  owner's case), loaded: Set waypoint on a weapon master gives the map pin and Skill Master's solid
  chevron, never TomTom's arrow; `/sm test` shows the sample chevron too. Untick Show Skill Master's
  arrow and set it again: the map pin with the game's own arrow. Trainers and Waypoints > Waypoint
  method offers Map pin and Chat only, no TomTom entry. A profile that had TomTom first or Map pin
  stored reads Map pin after the upgrade.
- **SM-DISP-37** (round 6, R6-6) Open the trainer popup on an unlearned weapon: the primary button
  reads `Set waypoint` (no `(map pin)` or `(chat)`), no `Waypoint order:` line sits under the buttons and the window ends a pad below them.
  Open it on Fishing's next rank (profession trainers carry no coordinates): `Set waypoint` is grayed
  in the skin's disabled look and does nothing; hover it: `No map coordinates for this trainer yet;
  Print to chat gives directions.` Print to chat prints them. Trainers and Waypoints > Waypoint method
  Chat only: the button is disabled on a weapon master too, its tooltip naming the setting.
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
- **SM-OPT-14** (round 2; the Rows page since round 5) Rows: one boxed row per skill, its
  icon and name, the eyes on the right; click the Window eye: the row dims and the skill leaves the window,
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
  reads `Click label: toggle window · Right-click label: options · Rows: click to open, right-click for the menu`;
  right-click the feed opens the settings on the Broker page (the main page until it exists).

## Launcher and settings

- **SM-LDB-1** The minimap button shows the logo. Left-click opens the settings; right-click shows
  Enabled, Locked, Test mode, Sim mode, Show window. Hovering shows the status tooltip.
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
  the chat line, no map pin and no arrow. Turn Mark unverified trainers off: no "(unverified)".
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
- **SM-TEST-4** (round 6, R6-11) `/sm test`: Skill Master's waypoint arrow shows,
  pointing up and to the left at a sample weapon master with `240 yd` under it; no map pin is set.
  Drag it where you want it. `/sm test` again: it goes (a waypoint you had set before test mode comes
  back). Enter combat in test mode: it goes with the rest.
- **SM-TEST-5** (the R6-11 review) Set a trainer waypoint (the arrow points at it),
  then `/sm test` and right-click the sample arrow: the sample goes and the arrow points at the real
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
