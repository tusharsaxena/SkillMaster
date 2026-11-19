# Known limitations

Split out of [ARCHITECTURE.md](ARCHITECTURE.md) under documentation-§3 (Tier 2: Known Limitations over 60 lines).

- The broker tooltip's Classic style opens the character panel for a stat or Skills-tab row with a
  plain `ToggleCharacter` call, which on WoW Forever taints `CharacterFrame:OnShow` (the PlayerFrame
  status-bar secret compare, docs/forever-quirks.md, "The character panel and secret geometry"). The main window's rows go through the
  micro button instead, and so do the Main window style's rows in either *Open a row from* (round 7,
  R7-6; round 8, R8-1); the Classic style's rows have no secure overlay.
- The Main window style (round 7, R7-6) shows the window's row tooltip on the shared
  GameTooltip, placed beside the panel (AD-92-SM: `NS.Chrome.PlaceBeside` against the panel, the
  row's group; SM-TIP-6), so it no longer overlaps the panel. Both sit at TOOLTIP; if neither side
  of the panel has room the tooltip falls back to centered below it. The overlay over a panel row is laid at the hover and re-laid on a scroll; the panel
  never moves while it shows. Unverified in game.
- The Skills tab's switch and redraw after the secure open (`NS.Interact.ShowSkillsTab`,
  `NS.Compat.RefreshSkillsTab`) run tainted: `SkillsFrame:OnShow` reads the skill list under the
  addon's taint. Unverified in game whether any of its reads come back secret.
- An overlay is placed when its row is laid out, shown, scrolled, hovered, raised or dropped; while its
  window is being dragged it is taken down (`SecureOverlay:SetMoving`) and laid again at the drop,
  so a crafting row cannot be cast from mid-drag. A raise re-levels it on the host's mouse-down,
  `Raise` and `OnShow` and once more on the next frame; a window of the same strata raised above
  the host (the Journal) does not re-level the host's overlays.
  The hover lays it before the press, since the client gives a click to the frame under the press.
- The gathering and fishing helpers are tooltip lines, switched by `skills.helperTooltip` (Skills >
  General > Gathering and fishing hints), plus the optional one-line hint under the row,
  `skills.helperHint` (Skills > General > Hint under the row, off by default; design §12 item 4).
- No per-element font for the window, block headers, tooltips and toasts: they follow the skin and
  the Skin tab's overrides. Only the bars have their own font block.
- Two columns place each docked block in the shorter column so far, so the block order reads down
  the columns by height rather than strictly left to right.
- Broker displays that only call a data object's `OnTooltipShow` show no feed tooltip: the feed
  supplies `OnEnter` / `OnLeave` (its rows are clickable), not `OnTooltipShow`.
- The Alts matrix shows five characters across at the default width (more as the window widens,
  up to twelve); Shift + mouse wheel pages through the rest, the wheel alone through the rows.
- The Log's ranges reach only as far back as the stored log: `char.log` is a ring of the newest
  `journal.keep` skill-ups (500 by default, at most 2000), so *Last 30 days* and *All time* show
  the newest that many, whatever their age.
- The simulator plays one scenario (a fishing trip: six skill-ups, a lure on and off, a mount up
  and down) on test mode's sample character. Only the reads the simulated character needs go
  through the seam: the skill list, the player's level, class and race, the weapon enchant, the
  main hand's tooltip and the speed. The other stats, the buffs and the zone stay live during a
  session.
- Turning test mode on (round 5) shows the main window, the Journal and three sticky toasts from the
  sample character (a rank cap, a weapon gap, a skill up; `NS.Alerts.ShowTestToasts`, keys
  `test:cap`, `test:weapon`, `test:skillup`); turning it off takes the toasts down and hides each
  window test mode opened. The first-run skin picker previews through test mode, so it shows them too.
  The toast stack holds three (`A.STACK`).
- While test mode is on (round 6) every surface says so: the main window and the Journal carry the
  amber test-mode strip under their titles (the Journal's tabs and body move down by its height), and
  the LDB tooltip carries the same line in `sem.warn` right under its title (`NS.Broker.AddTestModeLine`).
- Test mode's lure timer counts from when test mode turned on and is redrawn on the next repaint,
  not every second (the live ticker follows only live temp bonuses).
- On a client that is not enUS, the skill lines are matched on their skill-line ID when the
  client's record carries one; a positional (1.12-shaped) record has none, and its lines and the
  excluded headers are matched on the locale's strings, which only enUS ships today. Such a client
  sorts its lines into Other until the locale files are translated ([Documented deviations](ARCHITECTURE.md#documented-deviations)).
- A merged window's drags (round 5, R5-6b) measure frames' rects and the pointer in UIParent units;
  a rect the client answers secret, or not at all, gives no merge candidate, so such a drop is a plain
  move. A section's ghost and the side highlight sit one strata above the detached windows' strata
  (`LAYERS.STRATA_ABOVE`). A section dragged from a merged window can merge onto another window, but
  never onto its own group (dragged onto it, it splits at the drop or holds inside the leeway); moving a
  section within its own group is the menu's and the split mark's work, then a fresh merge. A sub-header
  dragged is assumed to swallow its click (the client fires no `OnClick` after an `OnDragStart`);
  unverified in game.
- The Weapon Skills filter (round 5, R5-10) reads the main hand, off hand and ranged slots as the
  equipped marker does (`NS.SkillHelpers.EquippedWeaponSkills`): an empty main hand is Unarmed, and
  a weapon whose item info is not cached yet names no skill until the next equipment change. A block
  its filter empties keeps its header and a muted line.
- The professions' At cap (needs training) filter (round 7, R7-1) asks `NS.Trainers:NextRank` per
  row, so it answers from the bundled rank ladders: a skill at its rank's cap with no ladder (none
  ships for it) never shows there. Unlearned rows show under All only. A stat section's Non-zero
  reads the row's shown value (no digit but 0: `0`, `0.0%`, `0 (0.0%)`), so a value that rounds to
  zero counts as zero.
- The trainer popup's "Also teaches" line (round 5, R5-14) wraps to four lines and the card grows by
  the line's measured height (`GetStringHeight`); a measure the client answers secret, nil or zero
  reads as one line. The card's tooltip always carries the whole list. Past
  `NS.TrainerPopup.MAX_HEIGHT` (600) the window stops growing and the cards scroll inside it (round
  6, R6-7, part of GitHub issue #4): a scroll frame, the mouse wheel (40 units a notch) and the
  Journal's skin scroll bar (`NS.Journal.MakeScrollBar`, resolved when the popup is first built),
  the cards narrowed by the bar's width while it shows; the wrap is kept.
- The trainer popup on a learned skill (round 6, R6-7) lists its next rank's trainers and every
  higher rank's, under one heading per rank (`Expert (225)`), the next rank first and nearest first
  inside a rank; a trainer who trains several of those ranks is listed once, under the lowest, and
  a rank with no trainer left has no heading. The data's rank lists decide who trains what
  (`defaults/Trainers_Forever.lua`): Nat Pagle is recorded as training Artisan Fishing only, so he
  shows under Artisan (300), not Expert. Unverified in game.
- The trainer popup's distances (round 5, R5-15) are measured from the map API's world positions
  (`NS.Compat.PlayerWorldPos`, `MapWorldPos`), straight-line yards inside one instance (continent),
  not a path. A trainer without coordinates (most profession trainers: the data gives only the weapon
  masters' x and y), one on another continent, or a player the client gives no position (inside an
  instance, a secret) shows no distance and sorts after the measured ones, in the data's order. The
  cards can reorder under the pointer as the player moves (once a second); the selected trainer stays
  selected. Computed here, not by another addon (the owner's call). Unverified in game.
- The trainer popup's Set waypoint button (round 6, R6-6) reads `Set waypoint` alone and is disabled
  whenever a waypoint could only go to chat (`NS.Waypoints:Blocked`): the data has no coordinates for
  the trainer (every profession trainer today), Waypoint method is Chat only, or the native pin API is
  not there. Its tooltip says which; Print to chat always works. A disabled button's
  tooltip needs `SetMotionScriptsWhileDisabled`, called when the client has it. Unverified in game.
- Skill Master's waypoint arrow (round 6, R6-11) shows only with a native pin set
  (`C_Map.SetUserWaypoint` on a map that takes one) and Show Skill Master's arrow on; off, the pin is
  super-tracked and the game's arrow points. With the real TomTom loaded (AF-SM-TOMTOM, owner img-19,
  2026-11-19), Set waypoint places a TomTom waypoint instead and TomTom's arrow points, never this
  one: TomTom takes the client's user waypoint over and clears it, which hid this arrow with the pin,
  so the native pin left nothing at all. TomTom is told by its folder name
  (`C_AddOns.IsAddOnLoaded("TomTom")`, `NS.Compat.TomTom`), so another addon that only answers
  TomTom's API (round 7's R7-7 case, which hid this arrow in the owner's game) is still ignored and
  gets the native pin. A TomTom whose `AddWaypoint` raises falls back to the native pin and this
  arrow. When TomTom wins, a native pin an earlier Set placed (before TomTom was enabled) is not
  cleared and may stay on the map beside TomTom's waypoint: the client's user waypoint may be one the
  player placed, and nothing tells Skill Master's from theirs, so the TomTom path leaves it alone
  (clear it from the world map). Test mode's sample arrow still shows with TomTom loaded. Its pin is set with
  `C_SuperTrack.SetSuperTrackedUserWaypoint(false)`, not just without the `true` call, so a pin the
  game was super-tracking loses its arrow too. The bearing assumes `GetWorldPosFromMapPos` answers x
  north and y west and `GetPlayerFacing` radians counter-clockwise from north (the retail
  convention); with no facing (nil or secret) the art hides and the yards stay, and with no distance
  (another continent, an instance) the trainer's name shows alone, dim. Arrival is 5 yd, straight
  line. A pin replaced elsewhere is noticed only where the client answers `C_Map.GetUserWaypoint`
  and a world place for it. Unverified in game. Since round 8 (R8-5) the frame, the math and the art
  are `LibKa0s-WaypointArrow-1.0`'s: whether its RLE TGAs load, which way `SetRotation` and the
  ground sheet's `SetTexCoord` turn, how Raised's shadow offset and the five looks read at scales 0.5
  to 2 are unverified in game. The outline is the library's fixed dark edge, baked into each look's
  overlay; it no longer follows the skin's `bar.border` (round 6 tinted it). Round 9 (R9-1..R9-3,
  `LibKa0s-WaypointArrow-1.0` version 2.2): the art is 1.25x the round-8 size at scale 1; the text
  takes the player's Font block rather than the skin's body and muted roles (the name alone is
  dimmed by alpha); the Share in chat line's shape (` /way <zone> x, y <trainer>`, a leading space
  so Enter posts it rather than running it as a command) is the library's and open for the owner,
  since the zone name is localized and not unique; the right-click menu, the Text block's faces and
  the position offsets at every scale are unverified in game (SM-DISP-60 to 63).
- The Main window style LDB tooltip's scroll bar (round 7, R7-4) is always drawn: with nothing to
  scroll it is disabled and its thumb spans the corridor in the skin's `scroll.thumbOff`, the
  facade's disabled tint (the main window's template bar stays drawn with its arrows disabled; the
  Journal's slider bar has no arrows, so the full-length dim thumb says the same). A skin switch while
  the tooltip is up repaints the thumb in `scroll.thumb` until the next hover redraws it. Unverified
  in game.
- Every client API the data modules use is assumed until `/sm probe` confirms it
  ([forever-quirks.md](forever-quirks.md), the addon's own section). The kit's Forever API set
  already lists the skill list as `C_SkillInfo.*` rather than the 1.12 globals.
