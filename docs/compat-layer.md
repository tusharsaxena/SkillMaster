# Compat layer — Ka0s Character Ledger

`core/Compat.lua` is the compat family's root and only file (compat). It owns every
version-variant client call the addon makes, normalizes the return shape, and decides nothing
about features. No `LibKa0s-Compat-1.0` member covers these calls, so every shim below is
hand-written; the family carries no library resolution yet.

`modules/Probe.lua` reads the same skill-list APIs raw, on purpose: its job is to report the
unnormalized return shape the owner sends back, so it is the one reader outside the family.

## `Compat.*` surface

| Compat function | Wraps | Contract |
|---|---|---|
| `Compat.NumSkillLines()` | `C_SkillInfo.GetNumSkillLines` → `GetNumSkillLines` (1.12) | The visible line count, headers included and collapsed children excluded; `0` when neither API exists |
| `Compat.SkillLineInfo(i)` | `C_SkillInfo.GetSkillLineInfo` → `GetSkillLineInfo` (1.12) | One record `{ name, isHeader, isExpanded, rank, tempPoints, modifier, max }` from either return shape: the modern struct (`skillName`, `isHeader`, `isExpanded`, `skillRank`, `numTempPoints`, `skillModifier`, `skillMaxRank`) or the 1.12 positional list. Flags are booleans (1.12 answers `1` / `nil`), numbers default to `0`; `nil` past the end or without an API |
| `Compat.SetSkillHeaderExpanded(i, open)` | `C_SkillInfo.ExpandSkillHeader` / `CollapseSkillHeader` → the 1.12 globals | Opens or closes header `i`; the lines below it shift. Answers `true` when a call ran. **Guarded** by the simulator's seam: `false` while a session runs |
| `Compat.PlayerLevel()` | `UnitLevel("player")` | The level, `0` without the API |
| `Compat.PlayerClass()` / `PlayerRace()` | `UnitClass` / `UnitRace` for the player | The localized name and the file token |
| `Compat.WeaponEnchantInfo()` | `C_Item.GetWeaponEnchantInfo` → `GetWeaponEnchantInfo` | The temp-enchant returns (`hasMain, mainExpirationMs, ...`); `nil` without either |
| `Compat.InventoryTooltipData(slot)` | `C_TooltipInfo.GetInventoryItem("player", slot)` | The data table and `true`, or `nil, false` without the API (the caller scans a tooltip) |
| `Compat.UnitSpeed(unit)` | `GetUnitSpeed` | current, run, flight, swim in yards/s; `nil` without the API |
| `Compat.SpellName(spellID)` | `C_Spell.GetSpellName`, then `GetSpellInfo` | the spell's localized name (the crafting overlay's cast, localization-§4); `nil` for an unknown ID or without either API |
| `Compat.SpellTexture(spellID)` | `C_Spell.GetSpellTexture`, then `GetSpellTexture` | the spell's icon (a file ID or a path): a profession row's icon (FB-14); `nil` for an unknown ID or without either API, and the row falls back to the catalog's static `icon` |
| `Compat.PlayerName()` | `UnitName("player")` | the player's name on the summary line (FB-17); `nil` without the API. The simulator answers the sample's |
| `Compat.MapWorldPos(mapID, x, y)` | `C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))` | a map point's (`x`, `y` as 0..1) world position: `instanceID, x, y` in yards (round 5, R5-15, the trainer popup's distances); `nil` for a secret or non-number argument or return, a raise (pcall), or without either API |
| `Compat.PlayerWorldPos()` | `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(mapID, "player")`, then `MapWorldPos` | the player's world position: `instanceID, x, y`; `nil` when the client knows no map or position (inside an instance), answers a secret, raises, or lacks an API |
| `Compat.TomTom()` | `C_AddOns.IsAddOnLoaded("TomTom")`, then the `TomTom` global and its `AddWaypoint` | the real TomTom addon's table, told by its folder name so another addon answering TomTom's API is ignored (round 7, R7-7), or nil; the bare `IsAddOnLoaded` is never called (AF-SM-TOMTOM) |
| `Compat.ClassIcon(classFile)` | `C_Texture.GetAtlasInfo("classicon-<class>")`, then `CLASS_ICON_TCOORDS` on `Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES` | `{ atlas }` where the client carries the atlas, else `{ file, coords }`, else `nil` (the summary line hides the icon). Pure: it reads no character, so the simulator passes it through |
| `Compat.OpenTradeSkill(skillLineID)` | `C_TradeSkillUI.OpenTradeSkill` under pcall | Opens a profession's window by its skill line; `true` when the client took the call and did not answer `false`, `false` without the API. Unverified on WoW Forever |
| `Compat.SelectSkillLine(i)` | `Compat.SKILL_SELECTORS` (`C_SkillInfo.SetSelectedSkill`, then `SetSelectedSkill`), first that exists, then `SkillFrame_SetSelection` / `SkillFrame_UpdateSkills` | Selects line `i` in Character -> Skills and lets the frame redraw; answers the name of the call that ran, or `nil`. Which selector Forever answers is unverified (`/cl probe` lists them) |
| `Compat.RefreshSkillsTab()` | Forever's `SkillsFrame`, `CharacterFrame`'s right pane and `EventRegistry` | Opens the collapsed detail pane, fires `SkillsFrame.NewSkillLineSelected` and refreshes each entry's highlight after a selection made outside the tab; `false` on a client without `SkillsFrame` |
| `Compat.TradeSkillLink(names)` | `C_SpellBook.GetSpellBookItemTradeSkillLink` by slot, with `GetNumSpellBookSkillLines` / `GetSpellBookSkillLineInfo` / `GetSpellBookItemName` | The trade link of the first spellbook spell named one of `names`, scanning past the skill lines' end until `Compat.PAST_LINES` (8) empty slots in a row, stopping at `Compat.MAX_BOOK_SLOT` (1000); `nil` when none is found or without the API |

`Compat.WeaponEnchantInfo` rests on two public helpers: `Compat.WeaponSlotCandidates()` (the
main-hand slot arguments to try, `Enum.WeaponSlot`'s first, then 16, 0 and 1; the first that does
not error is kept) and `Compat.NormalizeEnchant(...)` (a `C_Item` record, an array of them or the
1.12 positional list, returned in the 1.12 shape; `false` when there is no enchant).

PlayerLevel to SpellName (T5.2) and PlayerName (FB-17) exist for the simulator (preview-mode, H1): `core/SimSetup.lua` wraps the whole
table at load with LibKa0s-Sim-1.0's seam, and `modules/Simulator.lua` answers each one from its
simulated world while a session runs. A module reads them as `NS.Compat.Member(...)` at call time,
never through a captured local, and `tests/test_sim.lua` asserts `seam:Unwrapped()` is empty.

## Why both rungs stay

The kit's Forever API set (`tests/_kit/client_globals_forever.lua`) lists the skill list as
`C_SkillInfo.*` and none of the 1.12 globals. That set is best-effort, not a measurement, so the
1.12 rung is not dead code under compat's dead-fallback-rung rule until `/cl probe` answers
(`docs/forever-quirks.md`, the addon's assumed-API table). When the probe confirms which API the
client carries, delete the rung it rules out.

Tests: `tests/test_skilldata.lua` (`compat:` cases) drive all three shapes, the struct through
`C_SkillInfo`, the positional list through `C_SkillInfo` and through the 1.12 globals, and the
no-API case.
