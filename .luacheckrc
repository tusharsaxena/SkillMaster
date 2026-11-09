std = "lua51"
max_line_length = false
codes = true

-- Only vendored and frozen trees are out of scope; the test tree is linted (lint).
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }
ignore = { "212/self", "212/event" }

globals = {
  "SkillMasterDB",               -- the SavedVariables write target
  "SkillMasterPerfDB",           -- the perf capture ring (core/PerfSetup.lua, performance-§5)
  "StaticPopupDialogs",          -- the reset confirmation (settings/General.lua)
  "BINDING_HEADER_SKILLMASTER",  -- the key binding's category title (modules/MainWindow.lua)
  "UISpecialFrames",             -- Escape closes the main window (modules/MainWindow.lua)
}

read_globals = {
  "_G", "LibStub",
  "CreateFrame", "UIParent",
  "InCombatLockdown",
  "C_AddOns",
  "debugprofilestop",            -- the perf bracket's clock (performance-§2)
  "Settings", "StaticPopup_Show", "YES", "NO",
  -- the probe's reads (modules/Probe.lua): the skill list, the build, and every API it reports on
  "GetBuildInfo", "GetLocale", "GetNumSkillLines", "GetSkillLineInfo", "ExpandSkillHeader",
  "CollapseSkillHeader", "GetWeaponEnchantInfo", "IsAddOnLoaded", "C_Map", "GetUnitSpeed",
  "GetSpellBonusDamage", "GetSpellCritChance", "GetHitModifier", "GetSpellHitModifier",
  "GetCombatRating", "GetCritChance", "GetRangedCritChance", "GetDodgeChance", "GetParryChance",
  "GetBlockChance", "UnitResistance", "CastSpellByName", "C_SkillInfo", "C_Item",
  -- the skill model (modules/SkillData.lua): the class, the level and the debounce clock
  "UnitClass", "UnitLevel", "GetTime",
  -- T2.4: the trainer lookups and helpers read the player's faction, race, level and zone
  "UnitFactionGroup", "UnitRace", "GetZoneText",
  -- T2.2 Bonuses (modules/Bonuses.lua): the clock, the race, tooltips and buffs
  "C_TooltipInfo", "C_UnitAuras", "issecretvalue",
  -- M3 the display (modules/Chrome.lua .. modules/Waypoints.lua): the tooltip, the character frame,
  -- chat linking, the modifier keys and the waypoint providers (TomTom, the native user waypoint)
  "GameTooltip", "ToggleCharacter", "ChatEdit_InsertLink", "ChatFrame_OpenChat", "IsShiftKeyDown",
  "TomTom", "UiMapPoint", "C_SuperTrack",
  -- T4.1 Broker (modules/Broker.lua): the main hand's weapon class
  "GetInventoryItemLink", "GetItemInfoInstant",
}

-- T4.3: the session log's clock and zone, the alt snapshot's identity reads, the Journal's popup,
-- class colors, tooltip and shift-wheel.
files["modules/SessionLog.lua"] = { read_globals = { "time", "GetZoneText" } }
files["modules/Alts.lua"] = { read_globals = { "time", "UnitClass", "UnitRace", "UnitFactionGroup", "UnitLevel" } }
files["modules/Journal.lua"] = {
  read_globals = { "time", "date", "RAID_CLASS_COLORS", "GameTooltip", "IsShiftKeyDown" },
}

-- The harness global is declared here, not in read_globals, so addon source cannot reach it (lint).
files["tests/"] = {
  globals = { "_G.SKM_TEST" },
}

-- T2.3: StatData's feature-detected stat readers (modules/StatData.lua, S.APIS).
files["modules/StatData.lua"] = {
  read_globals = {
    "UnitStat", "UnitAttackPower", "UnitRangedAttackPower", "GetCritChance", "GetRangedCritChance",
    "GetHitModifier", "GetRangedHitModifier", "GetSpellHitModifier", "GetSpellCritChance",
    "GetSpellBonusDamage", "GetSpellBonusHealing", "GetManaRegen", "UnitArmor", "UnitDefenseSkill",
    "GetDodgeChance", "GetParryChance", "GetBlockChance", "UnitResistance", "GetUnitSpeed",
    "GetInventoryItemDurability", "UnitLevel",
  },
}
