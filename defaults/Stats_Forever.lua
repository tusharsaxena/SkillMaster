local _, NS = ...
-- defaults/Stats_Forever.lua — the stat catalog StatData reads (design §5.2, §6.3, plan Task 2.3): per
-- stat its group, the client API behind it, its reference (the value a full bar stands for), its
-- markers and its display format. Data only; modules/StatData.lua reads it at CALL time.
--
-- Field meanings:
--   key     stable English camelCase id ({stat:<key>} in the broker templates).
--   group   "base" | "spell" | "defense" | "utility" (the four stat blocks).
--   api     the client function's name; StatData resolves it, and a stat whose API is absent is
--           left out of the result (clients-§3), never faked.
--   calc    how StatData turns the API's returns into the value (modules/StatData.lua, CALC).
--   arg     the extra argument the API takes (a UnitStat index, a resistance school).
--   ref     a number, "maxInGroup" (the highest value among the group's maxInGroup stats),
--           "cap" (the highest marker), "skillCap" (5 x level) or "resistCap" (5 x (level + 3)).
--   markers { { value = number | named ref, label, minLevel? } }; a marker below minLevel is dropped.
--   fmt     "int" | "pct" (one decimal) | "pct0" (whole percent) | "armor" (raw armor + mitigation).
--
-- Every row is unverified until the owner's smoke pass on Forever (docs/forever-quirks.md, the
-- assumed-API table): the shapes are vanilla 1.12's.

local L = NS.L

NS.STATS_FOREVER_META = {
    source   = "vanilla 1.12 paper-doll formulas and API shapes; references per the design (§6.3, plan T2.3)",
    verified = false,
}

local HIT_MARKERS = {
    { value = 5, label = L["vs same level"] },
    { value = 9, label = L["vs raid boss"] },
}
local SPEED_MARKERS = { { value = 100, label = L["normal run speed"] } }
local RESIST_MARKERS = { { value = "resistCap", label = L["resist cap"] } }

NS.STAT_DEFS = {
    -- Base + melee/ranged.
    { key = "strength",  group = "base", api = "UnitStat", calc = "stat", arg = 1, ref = "maxInGroup", fmt = "int", label = L["Strength"] },
    { key = "agility",   group = "base", api = "UnitStat", calc = "stat", arg = 2, ref = "maxInGroup", fmt = "int", label = L["Agility"] },
    { key = "stamina",   group = "base", api = "UnitStat", calc = "stat", arg = 3, ref = "maxInGroup", fmt = "int", label = L["Stamina"] },
    { key = "intellect", group = "base", api = "UnitStat", calc = "stat", arg = 4, ref = "maxInGroup", fmt = "int", label = L["Intellect"] },
    { key = "spirit",    group = "base", api = "UnitStat", calc = "stat", arg = 5, ref = "maxInGroup", fmt = "int", label = L["Spirit"] },
    { key = "attackPower",       group = "base", api = "UnitAttackPower",       calc = "attackPower", ref = 400, fmt = "int", label = L["Attack Power"] },
    { key = "rangedAttackPower", group = "base", api = "UnitRangedAttackPower", calc = "attackPower", ref = 400, fmt = "int", label = L["Ranged Attack Power"] },
    { key = "meleeCrit",  group = "base", api = "GetCritChance",        calc = "first", ref = 30,    fmt = "pct", label = L["Melee Crit"] },
    { key = "rangedCrit", group = "base", api = "GetRangedCritChance",  calc = "first", ref = 30,    fmt = "pct", label = L["Ranged Crit"] },
    { key = "meleeHit",   group = "base", api = "GetHitModifier",       calc = "first", ref = "cap", fmt = "pct", label = L["Melee Hit"],  markers = HIT_MARKERS },
    { key = "rangedHit",  group = "base", api = "GetRangedHitModifier", calc = "first", ref = "cap", fmt = "pct", label = L["Ranged Hit"], markers = HIT_MARKERS },

    -- Spell + regen. Spell damage, healing and regen references are the design's "(call)" defaults.
    { key = "spellDamage",  group = "spell", api = "GetSpellBonusDamage",  calc = "bestSchool", ref = 500,   fmt = "int", label = L["Spell Damage"] },
    { key = "spellHealing", group = "spell", api = "GetSpellBonusHealing", calc = "first",      ref = 1000,  fmt = "int", label = L["Bonus Healing"] },
    { key = "spellCrit",    group = "spell", api = "GetSpellCritChance",   calc = "bestSchool", ref = 30,    fmt = "pct", label = L["Spell Crit"] },
    { key = "spellHit",     group = "spell", api = "GetSpellHitModifier",  calc = "first",      ref = "cap", fmt = "pct", label = L["Spell Hit"],
      markers = { { value = 16, label = L["vs raid boss"] } } },
    { key = "manaRegen",    group = "spell", api = "GetManaRegen",         calc = "mp5",        ref = 100,   fmt = "int", label = L["Mana Regen (per 5 s)"] },

    -- Defense + resists.
    { key = "armor",   group = "defense", api = "UnitArmor",        calc = "armor",   ref = "cap",      fmt = "armor", label = L["Armor"],
      markers = { { value = 75, label = L["cap"] } } },
    { key = "defense", group = "defense", api = "UnitDefenseSkill", calc = "defense", ref = "skillCap", fmt = "int",   label = L["Defense"],
      markers = { { value = 440, label = L["crit immunity vs bosses"], minLevel = 60 } } },
    { key = "dodge", group = "defense", api = "GetDodgeChance", calc = "first", ref = 30, fmt = "pct", label = L["Dodge"] },
    { key = "parry", group = "defense", api = "GetParryChance", calc = "first", ref = 30, fmt = "pct", label = L["Parry"] },
    { key = "block", group = "defense", api = "GetBlockChance", calc = "first", ref = 30, fmt = "pct", label = L["Block"] },
    { key = "fireResist",   group = "defense", api = "UnitResistance", calc = "resist", arg = 2, ref = "resistCap", fmt = "int", label = L["Fire Resistance"],   markers = RESIST_MARKERS },
    { key = "natureResist", group = "defense", api = "UnitResistance", calc = "resist", arg = 3, ref = "resistCap", fmt = "int", label = L["Nature Resistance"], markers = RESIST_MARKERS },
    { key = "frostResist",  group = "defense", api = "UnitResistance", calc = "resist", arg = 4, ref = "resistCap", fmt = "int", label = L["Frost Resistance"],  markers = RESIST_MARKERS },
    { key = "shadowResist", group = "defense", api = "UnitResistance", calc = "resist", arg = 5, ref = "resistCap", fmt = "int", label = L["Shadow Resistance"], markers = RESIST_MARKERS },
    { key = "arcaneResist", group = "defense", api = "UnitResistance", calc = "resist", arg = 6, ref = "resistCap", fmt = "int", label = L["Arcane Resistance"], markers = RESIST_MARKERS },

    -- Utility. GetUnitSpeed answers current, run, flight, swim in yards/s; 7 yards/s is 100%. The
    -- run return is the mount's speed while mounted, so no separate mount row.
    { key = "speed",     group = "utility", api = "GetUnitSpeed", calc = "speed", arg = 1, ref = 200, fmt = "pct0", label = L["Speed"],      markers = SPEED_MARKERS },
    { key = "runSpeed",  group = "utility", api = "GetUnitSpeed", calc = "speed", arg = 2, ref = 200, fmt = "pct0", label = L["Run Speed"],  markers = SPEED_MARKERS },
    { key = "swimSpeed", group = "utility", api = "GetUnitSpeed", calc = "speed", arg = 4, ref = 200, fmt = "pct0", label = L["Swim Speed"], markers = SPEED_MARKERS },
    { key = "durability", group = "utility", api = "GetInventoryItemDurability", calc = "durability", ref = 100, fmt = "pct0", label = L["Durability"],
      markers = { { value = 20, label = L["repair"] } } },
}
