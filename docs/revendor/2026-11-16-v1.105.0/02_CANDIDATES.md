# 02 Candidates, LibKa0s v1.101.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.101.0..v1.105.0`; LibKa0s CHANGELOG.md, the v1.102.0 to v1.105.0 blocks; the run bundle's `03_ADOPTION_PLAN.md` and research note R8 (SkillMaster row).

**Class A, delivered on the copy alone**
- The debug console: plain-text Copy, the 24 px Widgets footer, the title-bar marks on `HeaderButtons` (DebugLog minor 23, Window minor 5; LibKa0s#79, #90, #86).
- The drag strip's tooltip fallback is attached below the strip, never the cursor (WidgetsDragHandleTip minor 1, LibKa0s#92 part B).
- The skin picker queue (OptionsSkinPickerQueue 1, OptionsSkinPicker 12), SkinDefs 28 / SkinDefsOthers 10 (#82 floors), Launcher 11, PerfPanel 14, SimPanel 11 / SimPanelRender 4, IconBrowser 2, Charts 2, Callout 4 (not consumed).
- Kit revision 57 (`mock_screen.lua`, the frame hold).

**Class B, host change required (owed in phase [3], planned only; not offered here)**
- **#80, `W.Bar`.** LibKa0s v1.105.0 promoted this addon's `modules/Bar.lua` as `W.Bar` (WidgetsBar minor 1). Candidate: swap `NS.Bar` for `W.Bar`, delete `modules/Bar.lua`, remap the bonus tokens. Not adopted here.
- **#81, Launcher `extraEntries`.** Candidate: a **Journal** entry on the launcher.
- **#92, tooltip placement.** 8 `SetOwner`/anchor sites (R8: RIGHT 3, TOP 2, NONE 2, BOTTOM 1, plus 1 cursor ref) across Bonuses, Broker, Chrome, Journal, RowTooltip, TrainerPopup and WaypointArrow move onto `Tooltip.PlaceBeside` / `PlaceAttached`.
- **#88, docked test/sim strip.** Four undocked strips (`modules/BrokerPanel.lua:263`, `modules/Journal.lua:865`, `modules/MainWindow.lua:255,262`); candidate `dock = "title"`.
- **#89, `W.Footer`.** The hand-built footer in `modules/BrokerPanel.lua` (`frame.footer` FontString).
- **#86, `W.HeaderButtons`.** The addon-owned windows (Journal, MainWindow, TrainerPopup) move their title marks onto the strip, with settings on each.
- **#79, reports.** `/sm probe` (settings/Slash.lua:45) and any journal read-out are candidates for `D:Report`; `/sm list` stays in chat (the reserved list verb). Confirm each verb against its handler.
- **#82, host owner tokens.** Check the block-header detach mark's own `*.hot` alias against the new floors (green today).
- **#87, `Sim.Sample(client)`.** Only if the simulator draws sample names; to confirm at adoption.

**Not applicable / settled:** #85 Callout: declined, standing (SkillMaster#5); the run's recommended decision is **never**.

**Class C, whole-module**: Tooltip (through #92), Role, Charts, Compat, Glow, IconBrowser, Item, not looked up.

**Blockers (3g)**: one, the DebugLog stub's `Report`/`Serialize`, fixed in the re-vendor commit (01_DELTA.md).
