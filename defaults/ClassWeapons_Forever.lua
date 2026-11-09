local _, NS = ...
-- defaults/ClassWeapons_Forever.lua — the weapon skills each class can learn, and Riding, which
-- every class trains: SkillData synthesizes an unlearned row for each one the character lacks.
--
-- NS.ClassWeapons_Forever[classFile] = { catalog keys... }, keyed by UnitClass's second return.
--
-- Source: the vanilla 1.12 class weapon proficiencies (weapon masters and class trainers), as
-- recorded for WoW Classic Era; polearms are a druid line only from 2.0 and are left out here.
-- Not yet checked against WoW Forever in game.

NS.DataMeta = NS.DataMeta or {}
NS.DataMeta.ClassWeapons_Forever = { source = "vanilla 1.12 data (class weapon proficiencies)", verified = false }

NS.ClassWeapons_Forever = {
    WARRIOR = { "axes", "twoHandedAxes", "bows", "crossbows", "daggers", "fistWeapons", "guns", "maces",
                "twoHandedMaces", "polearms", "staves", "swords", "twoHandedSwords", "thrown", "unarmed",
                "riding" },
    PALADIN = { "axes", "twoHandedAxes", "maces", "twoHandedMaces", "polearms", "swords", "twoHandedSwords",
                "unarmed", "riding" },
    HUNTER  = { "axes", "twoHandedAxes", "bows", "crossbows", "daggers", "fistWeapons", "guns", "polearms",
                "staves", "swords", "twoHandedSwords", "thrown", "unarmed", "riding" },
    ROGUE   = { "bows", "crossbows", "daggers", "fistWeapons", "guns", "maces", "swords", "thrown", "unarmed",
                "riding" },
    PRIEST  = { "daggers", "maces", "staves", "wands", "unarmed", "riding" },
    SHAMAN  = { "axes", "twoHandedAxes", "daggers", "fistWeapons", "maces", "twoHandedMaces", "staves",
                "unarmed", "riding" },
    MAGE    = { "daggers", "staves", "swords", "wands", "unarmed", "riding" },
    WARLOCK = { "daggers", "staves", "swords", "wands", "unarmed", "riding" },
    DRUID   = { "daggers", "fistWeapons", "maces", "twoHandedMaces", "staves", "unarmed", "riding" },
}
