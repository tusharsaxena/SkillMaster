# Smoke tests — Ka0s Skill Master

In-game checks on **WoW Forever** (client 1.60.1). The owner runs them; an agent never marks one
passed (clients-§6, testing). Each check names what to do and what you should see.

## Load

- **SM-LOAD-1** Log in on Forever. The AddOns list shows Ka0s Skill Master with its logo; no Lua error.
- **SM-LOAD-2** On a **Retail** client, open the AddOns list. Ka0s Skill Master is **not listed**
  (the `ExcludeLoadGameType: standard` gate, clients-§9). This also settles the open evolution the
  standard recorded for the Forever load gate.
- **SM-LOAD-3** On a fresh profile the skin picker opens once, previewing in test mode; it defaults to
  WoW Forever. Apply or close it; it does not open again on that profile.

## Window

- **SM-WIN-1** `/skm toggle` opens the window titled Skill Master; Escape and the close button hide it.
- **SM-WIN-2** Drag it, `/reload`: it reopens where it was dropped. `/skm lock`: it no longer drags.
- **SM-WIN-3** `/skm test`: an amber band says the skills shown are sample data. Enter combat: the
  band disappears and test mode is off.
- **SM-WIN-4** Bind a key under Options → Keybindings → Ka0s Skill Master; it toggles the window.

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
- **SM-DISP-8** Open the window and the Journal over it, then click the window: it comes to the
  front and a crafting row still opens its profession (the overlay was re-leveled above the rows).
  Drag the window by its title: no invisible button is left at the old place, and at the drop
  clicking Leatherworking opens it.
- **SM-DISP-9** Detach the Weapon block: the equipped weapon (a Dwarf Hunter's Guns) reads
  `▸ Guns` in gold. With `layout.blocks.weapon.belowCapOnly` on, only the equipped weapon and the
  skills below their cap show; swap weapons and the marker follows. With `skills.helperHint` on, the
  Skinning, Mining, Herbalism and Fishing rows carry one muted hint line under the bar.
- **SM-DISP-7** An unlearned weapon row reads `Not learned · <trainer>, <city> · 10s`. Its Go button
  (or a click) opens the trainer popup: the faction's weapon masters, the unverified warning. Set
  waypoint with TomTom loaded (a TomTom arrow), without it (a map pin), and Print to chat.
## Journal

- **SM-JRN-1** `/skm journal` opens "Skill Master · Journal" with Session Log and Alts tabs; Escape and
  the close mark close it; drag it, `/reload`, and it opens where it was dropped.
- **SM-JRN-4** Drag the Journal's bottom-right grip continuously: the window follows the pointer
  without lag and never gets smaller than it opened; release: more log rows show. `/reload`: it
  opens at the dragged size. Lock the window (`/skm lock`): the grip does nothing.
- **SM-JRN-2** Gain a skill point: a row appears at the top of Session Log with the time, the skill,
  `old → new` and the zone, and the session card counts it. A second gain of the same skill gives it
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
  Enabled, Locked, Test mode, Show window. Hovering shows the status tooltip.
- **SM-CFG-1** Settings → AddOns → Ka0s Skill Master: the landing page lists the slash commands; General
  has Master controls, Skin and Keybindings tabs; Profiles works.
- **SM-CFG-2** Uncheck Minimap button: the button hides, and Reset all settings does not bring it back.

## Disabled

- **SM-OFF-1** `/skm disable`: the window hides, `/skm toggle` answers one disabled line, the key
  binding does nothing, the right-click menu grays all but Enabled. `/skm enable` restores it.

## Probe

- **SM-PROBE-1** `/skm probe`: a copy window opens with a JSON report, `skillLines` holding every
  skill (a collapsed header in the Skills tab is collapsed again afterwards). Copy it and send it to
  the author; it settles the assumed rows in `docs/midnight-quirks.md`.

## Skins and diagnostics

- **SM-SKIN-1** `/skm skin`: pick Ka0s Default, Apply. The window and the debug console change look.
- **SM-DIAG-1** `/skm diagnostics`: the report appears in the debug console with the five sections.
