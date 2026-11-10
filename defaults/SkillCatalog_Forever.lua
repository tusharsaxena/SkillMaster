local _, NS = ...
-- defaults/SkillCatalog_Forever.lua — every skill line Skill Master shows (design §2, goal 1): the
-- vanilla professions, the 16 weapon skill lines, Defense, Lockpicking and Riding.
--
-- NS.SkillCatalog[key] = { category, kind, tiers, openSpell, opensSkillsTab, name, aliases, order }
--   key             stable English camelCase, never shown
--   category        "primary" | "secondary" | "weapon" | "other"
--   kind            "craft" | "gather" | "weapon" | "defense" | "lockpicking" | "riding"
--   tiers           the rank caps a profession trains through, or nil
--   openSpell       the enUS spell whose cast opens the tradeskill window (T3.3), or nil
--   opensSkillsTab  true when a click opens Character -> Skills instead
--   name            the enUS skill-line name, a locale key (locales/enUS.lua)
--   aliases         more enUS line names for the same key (the racial riding lines), locale keys
--   order           the row order inside a category for synthesized (unlearned) rows
--   skillLineID     the skill line's ID (SkillLine.dbc), matched before the name (localization-§4)
--   aliasIDs        the aliases' skill-line IDs (the racial riding lines)
--   openSpellID     the open spell's ID; its localized name (NS.Compat.SpellName) is what is cast
-- NS.SkillLineIDToKey and NS.SkillNameToKey (modules/SkillData.lua) are built from these, the names
-- through NS.L: the ID when the client's record carries one, the localized name otherwise.
--
-- Source: the vanilla 1.12 skill list (Skills tab line names, weapon skill lines, profession rank
-- caps), as recorded for WoW Classic Era; not yet checked against WoW Forever in game.

NS.DataMeta = NS.DataMeta or {}
NS.DataMeta.SkillCatalog_Forever = { source = "vanilla 1.12 data (WoW Classic Era skill lines)", verified = false }

local PROF = { 75, 150, 225, 300 }

local function craft(name, category, order, openSpell)
    return { category = category, kind = "craft", tiers = PROF, name = name, order = order,
             openSpell = openSpell or name, opensSkillsTab = false }
end
local function gather(name, category, order, openSpell)
    return { category = category, kind = "gather", tiers = PROF, name = name, order = order,
             openSpell = openSpell, opensSkillsTab = openSpell == nil }
end
local function weapon(name, order)
    return { category = "weapon", kind = "weapon", name = name, order = order, opensSkillsTab = true }
end

NS.SkillCatalog = {
    -- Primary professions
    alchemy         = craft("Alchemy", "primary", 1),
    blacksmithing   = craft("Blacksmithing", "primary", 2),
    enchanting      = craft("Enchanting", "primary", 3),
    engineering     = craft("Engineering", "primary", 4),
    herbalism       = gather("Herbalism", "primary", 5),
    leatherworking  = craft("Leatherworking", "primary", 6),
    mining          = gather("Mining", "primary", 7, "Smelting"),
    skinning        = gather("Skinning", "primary", 8),
    tailoring       = craft("Tailoring", "primary", 9),
    -- Secondary skills
    cooking         = craft("Cooking", "secondary", 1),
    firstAid        = craft("First Aid", "secondary", 2),
    fishing         = gather("Fishing", "secondary", 3),
    -- Weapon skills: the 16 vanilla lines
    axes            = weapon("Axes", 1),
    twoHandedAxes   = weapon("Two-Handed Axes", 2),
    bows            = weapon("Bows", 3),
    crossbows       = weapon("Crossbows", 4),
    daggers         = weapon("Daggers", 5),
    fistWeapons     = weapon("Fist Weapons", 6),
    guns            = weapon("Guns", 7),
    maces           = weapon("Maces", 8),
    twoHandedMaces  = weapon("Two-Handed Maces", 9),
    polearms        = weapon("Polearms", 10),
    staves          = weapon("Staves", 11),
    swords          = weapon("Swords", 12),
    twoHandedSwords = weapon("Two-Handed Swords", 13),
    thrown          = weapon("Thrown", 14),
    unarmed         = weapon("Unarmed", 15),
    wands           = weapon("Wands", 16),
    -- Other
    defense     = { category = "other", kind = "defense", name = "Defense", order = 1, opensSkillsTab = true },
    lockpicking = { category = "other", kind = "lockpicking", name = "Lockpicking", order = 2, opensSkillsTab = true },
    riding      = { category = "other", kind = "riding", name = "Riding", order = 3, opensSkillsTab = true,
                    tiers = { 75, 150 },
                    -- 1.12 lists riding per race; any of them is the one Riding row.
                    aliases = { "Horse Riding", "Ram Riding", "Wolf Riding", "Tiger Riding", "Raptor Riding",
                                "Mechanostrider Piloting", "Undead Horsemanship", "Kodo Riding" } },
}

-- The skill-line IDs (SkillLine.dbc, vanilla) and the open spells' IDs (the Apprentice rank: any
-- rank's ID answers the rank-free localized name, which casts the highest rank known). Unverified on
-- WoW Forever until `/skm probe` (docs/midnight-quirks.md).
local SKILL_LINE_IDS = {
    alchemy = 171, blacksmithing = 164, enchanting = 333, engineering = 202, herbalism = 182,
    leatherworking = 165, mining = 186, skinning = 393, tailoring = 197,
    cooking = 185, firstAid = 129, fishing = 356,
    axes = 44, twoHandedAxes = 172, bows = 45, crossbows = 226, daggers = 173, fistWeapons = 473,
    guns = 46, maces = 54, twoHandedMaces = 160, polearms = 229, staves = 136, swords = 43,
    twoHandedSwords = 55, thrown = 176, unarmed = 162, wands = 228,
    defense = 95, lockpicking = 633, riding = 762,
}
local OPEN_SPELL_IDS = {
    alchemy = 2259, blacksmithing = 2018, enchanting = 7411, engineering = 4036, leatherworking = 2108,
    tailoring = 3908, cooking = 2550, firstAid = 3273, mining = 2656,   -- Mining opens by Smelting
}
for key, id in pairs(SKILL_LINE_IDS) do NS.SkillCatalog[key].skillLineID = id end
for key, id in pairs(OPEN_SPELL_IDS) do NS.SkillCatalog[key].openSpellID = id end
-- Horse, Wolf, Tiger, Ram, Raptor, Mechanostrider, Undead Horsemanship, Kodo.
NS.SkillCatalog.riding.aliasIDs = { 148, 149, 150, 152, 533, 553, 554, 713 }

-- The Skills-tab headers whose lines the design leaves out (design §3: armor proficiencies,
-- languages, class spell-school lines). A catalog name under one of them is still read
-- (a rogue's Lockpicking sits under Class Skills); any other line under them is skipped.
NS.SkillExcludedHeaders = { "Class Skills", "Armor Proficiencies", "Languages" }
