local _, NS = ...
-- defaults/ClassWeapons_Forever.lua — the weapon skills each class can learn, and Riding, which
-- every class trains: SkillData synthesizes an unlearned row for each one the character lacks.
--
-- NS.ClassWeapons_Forever[classFile] = { catalog keys... }, keyed by UnitClass's second return.
--
-- Source: WoW Forever's own DB2 (wago.tools product wowf, build 1.60.1.71139; GitHub issue #10): a
-- class lists a weapon skill when that skill's SkillLineAbility row (the weapon spell) carries the
-- class in its ClassMask and a SkillRaceClassInfo row covers the class. All 83 vanilla entries hold;
-- Forever adds two vanilla lacked: Rogue Axes (SLA 248, SRCI 629/630) and Druid Polearms (SLA 2928,
-- SRCI 2483, from level 20). Riding: SLA 17539 / SRCI 2532, every class and race.

NS.DataMeta = NS.DataMeta or {}
NS.DataMeta.ClassWeapons_Forever = { source = "WoW Forever DB2 SkillLineAbility + SkillRaceClassInfo (wowf 1.60.1.71139)",
    verified = "wowf@1.60.1.71139" }

NS.ClassWeapons_Forever = {
    WARRIOR = { "axes", "twoHandedAxes", "bows", "crossbows", "daggers", "fistWeapons", "guns", "maces",
                "twoHandedMaces", "polearms", "staves", "swords", "twoHandedSwords", "thrown", "unarmed",
                "riding" },
    PALADIN = { "axes", "twoHandedAxes", "maces", "twoHandedMaces", "polearms", "swords", "twoHandedSwords",
                "unarmed", "riding" },
    HUNTER  = { "axes", "twoHandedAxes", "bows", "crossbows", "daggers", "fistWeapons", "guns", "polearms",
                "staves", "swords", "twoHandedSwords", "thrown", "unarmed", "riding" },
    ROGUE   = { "axes", "bows", "crossbows", "daggers", "fistWeapons", "guns", "maces", "swords", "thrown",
                "unarmed", "riding" },
    PRIEST  = { "daggers", "maces", "staves", "wands", "unarmed", "riding" },
    SHAMAN  = { "axes", "twoHandedAxes", "daggers", "fistWeapons", "maces", "twoHandedMaces", "staves",
                "unarmed", "riding" },
    MAGE    = { "daggers", "staves", "swords", "wands", "unarmed", "riding" },
    WARLOCK = { "daggers", "staves", "swords", "wands", "unarmed", "riding" },
    DRUID   = { "daggers", "fistWeapons", "maces", "twoHandedMaces", "polearms", "staves", "unarmed", "riding" },
}
