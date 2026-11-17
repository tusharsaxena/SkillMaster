Delta: LibKa0s v1.101.0 -> v1.105.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 43ea2bd, a local tag, not yet on origin). Run under item RV-SM of Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/` (the copy and bundle half of `/dev-copilot:wow-revendor-libka0s` 2.10.0; adoption is that run's phase [3]).

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` named v1.101.0 before the roll (CLAUDE.md:40).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = f6b5551; its CLAUDE.md names v1.101.0. They agree, and no CLAUDE.md roll since.
- Payload before the copy equalled the library at v1.101.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.101.0 extract printed nothing beyond the icons and voice packs the declaration prunes (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.101.0..v1.105.0` is 37 commits; tags in it: v1.102.0, v1.103.0, v1.104.0, v1.105.0. `git -C ../LibKa0s diff --shortstat v1.101.0 v1.105.0`: 173 files changed, 132025 insertions(+), 1332 deletions(-).
- Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-11-14-v1.101.0`, states base v1.99.0, and the provenance before its re-vendor (f6b5551) was v1.99.0. ok, no correction.

## 3b/3c Per-file minors that moved (old = this addon, new = v1.105.0)
```
Core.lua  old: local MAJOR, MINOR = "LibKa0s-Core-1.0", 17  new: 18
Tooltip.lua  old:   new: local MAJOR, MINOR = "LibKa0s-Tooltip-1.0", 1
Callout.lua  old: 3  new: 4
CalloutSettings.lua  old: local SETTINGS_MINOR = 4  new: 5
Charts.lua  old: 1  new: 2
SkinDefs.lua  old: local DEFS_MINOR = 27  new: 28
SkinDefsOthers.lua  old: local OTHERS_MINOR = 9  new: 10
Widgets.lua  old: 26  new: 27
WidgetsDropdown.lua  old: local DROPDOWN_MINOR = 1  new: 2
WidgetsReorder.lua  old: local REORDER_MINOR = 6  new: 7
WidgetsDragHandle.lua  old: local DRAG_MINOR = 13  new: 14
WidgetsDragHandleTip.lua  old:   new: local DRAGTIP_MINOR = 1
WidgetsCopyWindow.lua  old: local COPY_MINOR = 5  new: 6
WidgetsHeader.lua  old:   new: local HEADER_MINOR = 1
WidgetsBar.lua  old:   new: local BAR_MINOR = 1
DebugLog.lua  old: 22  new: 23
DebugLogDiagnostics.lua  old: local DIAG_MINOR = 10  new: 11
DebugLogWindow.lua  old: local WINDOW_MINOR = 4  new: 5
Launcher.lua  old: 10  new: 11
OptionsSkinPicker.lua  old: local PICKER_MINOR = 11  new: 12
OptionsSkinPickerQueue.lua  old:   new: local QUEUE_MINOR = 1
IconBrowserWindow.lua  old: local WINDOW_MINOR = 1  new: 2
IconBrowser.lua  old: local BROWSER_MINOR = 1  new: 2
PerfPanel.lua  old: local PANEL_MINOR = 13  new: 14
Sim.lua  old: 2  new: 3
SimPanel.lua  old: local SIM_PANEL_MINOR = 10  new: 11
SimPanelRender.lua  old: local RENDER_MINOR = 3  new: 4
```
(3c's loop over the tag's `LibKa0s/LibKa0s.xml`, rows whose two columns differ.) An empty `old:` is a file new in this range (Tooltip, WidgetsDragHandleTip, WidgetsHeader, WidgetsBar, OptionsSkinPickerQueue). Every other file matched v1.101.0 before the copy, so there is no cross-major skew. No file was removed upstream (`diff -rq` shows no `Only in libs/LibKa0s` line), so nothing in `libs/` was deleted by hand. The kit gains `mock_screen.lua`.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` and `diff -rq` of both payloads against the v1.105.0 extract printed nothing (content clean, bytes clean). After the prune the only differences are the undeclared icons and the voice packs under `media/sounds/` (`LibKa0s sounds: none.`). `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` over the addon's own source (not libs, not tests):
```
core/Bus.lua:8            LibKa0s-Bus-1.0
core/CoreSetup.lua:12     LibKa0s-Core-1.0
core/DebugLogSetup.lua:8  LibKa0s-DebugLog-1.0
core/EnvSetup.lua:4       LibKa0s-Env-1.0
core/LauncherSetup.lua:8  LibKa0s-Launcher-1.0
core/LifecycleSetup.lua:7 LibKa0s-Lifecycle-1.0
core/MediaSetup.lua:10    LibKa0s-Media-1.0
core/PerfSetup.lua:8      LibKa0s-Perf-1.0
core/PoolSetup.lua:5      LibKa0s-Pool-1.0
core/SimSetup.lua:9       LibKa0s-Sim-1.0
core/SkinSetup.lua:9      LibKa0s-Skin-1.0
core/WidgetsSetup.lua:7   LibKa0s-Widgets-1.0
modules/Alerts.lua:26     LibKa0s-Toast-1.0
modules/Bar.lua:47        LibKa0s-Core-1.0
modules/Diagnostics.lua:33 LibKa0s-Skin-1.0
modules/Simulator.lua:24  LibKa0s-Sim-1.0
modules/WaypointArrow.lua:34 LibKa0s-WaypointArrow-1.0
settings/BoxList.lua:41   LibKa0s-Widgets-1.0
settings/OptionsSetup.lua:16 LibKa0s-Options-1.0
settings/Schema.lua:182   LibKa0s-Schema-1.0
settings/Slash.lua:6      LibKa0s-Slash-1.0
```
Majors in the payload with no lookup here: Callout (declined, standing, SkillMaster#5), Charts, Compat, Glow, IconBrowser, Item, Role, and the new Tooltip.

## 3f Kit revision
```
testkit/framework.lua:20:Kit.VERSION = 57   (new)
tests/_kit/framework.lua:20:Kit.VERSION = 56 (old)
```
Kit revision 57 pairs with v1.105.0, and both payloads are copied whole in one commit (the pairing rule). The kit-57 frame hold turned nothing red here.

## 3g Contract delta and Blockers
Majors that moved a minor and that this addon looks up: Core, Skin, Widgets, DebugLog, Launcher, Options (skin picker), Perf, Sim. `__Attach*` sites in this addon: none (`grep -rn '__Attach'` outside libs and the kit).

**Blocker 1, surface parity (one stub member pair the release added).** `tests/test_surface_parity.lua` ("parity: the DebugLog stub carries the whole live surface") went red after the copy: `Report is missing (live: function); Serialize is missing (live: function)`. DebugLog minor 23 adds both instance members (LibKa0s `docs/api/DebugLog/version-23.11.1.5-docs.md`:50-63, "What a host owes at its re-vendor"). Fixed in this commit: `core/DebugLogSetup.lua`'s library-absent stub gains the library's suggested `Report` (the report streamed to chat with no pointer) and `Serialize` (one line).

Checked and not red: the Options stub already carries `SideTabs` (settings/OptionsSetup.lua:213); the Sim stub is not red on `SAMPLE`/`Sample`; Compat is not looked up; the loader list is derived from the XML, so the new payload files needed no hand-written line; the per-skin `icon.hot` pins (`tests/test_round2_icons.lua:231,250`) stay green under SkinDefs 28 / SkinDefsOthers 10. No other suite moved, and `modules/Bar.lua` is untouched (its promotion as `W.Bar` is adoption, phase [3]).

## 3h Unrecorded vendored tags
The listing (vendored since the store's horizon 2026-11-14: v1.99.0 v1.101.0; recorded: v1.99.0 v1.101.0) prints nothing. No span bundle is owed.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 41, the next non-blank line under the provenance line, 26 names (Open Iconic and `ph:` Phosphor). Kept as written. `LibKa0s sounds: none.` (CLAUDE.md:42) kept as written.
- Prune, `lua <scratch>/tools/prune-icons.lua .`: icons kept 28 of 5840 files (26 declared plus the sets' licenses), removing the 5812 undeclared icon files the whole copy brought back; sounds none, removing all 362 voice-pack files. A second run removed 0.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` prints nothing. Nothing to fix.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none.
