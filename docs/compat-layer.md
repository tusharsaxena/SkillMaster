# Compat layer — Ka0s Skill Master

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

The last six (T5.2) exist for the simulator (preview-mode, H1): `core/SimSetup.lua` wraps the whole
table at load with LibKa0s-Sim-1.0's seam, and `modules/Simulator.lua` answers each one from its
simulated world while a session runs. A module reads them as `NS.Compat.Member(...)` at call time,
never through a captured local, and `tests/test_sim.lua` asserts `seam:Unwrapped()` is empty.

## Why both rungs stay

The kit's Forever API set (`tests/_kit/client_globals_forever.lua`) lists the skill list as
`C_SkillInfo.*` and none of the 1.12 globals. That set is best-effort, not a measurement, so the
1.12 rung is not dead code under compat's dead-fallback-rung rule until `/sm probe` answers
(`docs/forever-quirks.md`, the addon's assumed-API table). When the probe confirms which API the
client carries, delete the rung it rules out.

Tests: `tests/test_skilldata.lua` (`compat:` cases) drive all three shapes, the struct through
`C_SkillInfo`, the positional list through `C_SkillInfo` and through the 1.12 globals, and the
no-API case.
