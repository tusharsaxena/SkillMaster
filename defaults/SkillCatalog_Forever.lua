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
--   tradeSkill      true when the line has its own profession window on WoW Forever with no open
--                   spell (Skinning and Fishing: Camping recipes, owner feedback round 3); a click
--                   opens it by skill-line ID (NS.Compat.OpenTradeSkill), else the Skills tab
--   name            the enUS skill-line name, a locale key (locales/enUS.lua)
--   aliases         more enUS line names for the same key (the racial riding lines), locale keys
--   order           the row order inside a category for synthesized (unlearned) rows
--   skillLineID     the skill line's ID (SkillLine.dbc), matched before the name (localization-§4)
--   aliasIDs        the aliases' skill-line IDs (the racial riding lines)
--   openSpellID     the open spell's ID; its localized name (NS.Compat.SpellName) is what is cast
--   icon            the row's in-game icon, an Interface\Icons\ path (unverified in game)
--   iconSpellID     the spell whose runtime texture is the icon, first (a profession's), or nil
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
    skinning        = gather("Skinning", "primary", 8),   -- tradeSkill, below
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
-- rank's ID answers the rank-free localized name, which casts the highest rank known). The skill-line
-- IDs a `/sm probe` showed (build 70862, 2026-11-10) all match: every profession, secondary and weapon line,
-- Defense 95. The rest, and the open spells, are still unverified on WoW Forever.
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
-- Skinning and Fishing open their own window on WoW Forever (seen in game, owner feedback round 3,
-- 2026-11-11), by no spell: the window opens by the skill-line ID.
for _, key in ipairs({ "skinning", "fishing" }) do
    NS.SkillCatalog[key].tradeSkill, NS.SkillCatalog[key].opensSkillsTab = true, false
end
for key, id in pairs(OPEN_SPELL_IDS) do NS.SkillCatalog[key].openSpellID = id end
-- The row icons (owner feedback round 2, FB-14): an in-game Interface\Icons\ texture per line,
-- never a LibKa0s glyph. A profession draws its own spell's runtime texture first (iconSpellID,
-- through NS.Compat.SpellTexture: the Apprentice rank, or the gathering spell for Herbalism,
-- Mining and Skinning), and this static path where the client answers none. A weapon line and the
-- Other lines have no spell, so the path is the closest classic-era icon. Every name is from the
-- 1.x icon set (all of it persists in the modern client), and every one is UNVERIFIED until seen
-- in game on WoW Forever.
local ICONS = {
    alchemy = "Trade_Alchemy", blacksmithing = "Trade_BlackSmithing", enchanting = "Trade_Engraving",
    engineering = "Trade_Engineering", herbalism = "Spell_Nature_NatureTouchGrow",
    leatherworking = "Trade_LeatherWorking", mining = "Trade_Mining", skinning = "INV_Misc_Pelt_Wolf_01",
    tailoring = "Trade_Tailoring",
    cooking = "INV_Misc_Food_15", firstAid = "Spell_Holy_SealOfSacrifice", fishing = "Trade_Fishing",
    axes = "INV_Axe_04", twoHandedAxes = "INV_Axe_09", bows = "INV_Weapon_Bow_05",
    crossbows = "INV_Weapon_Crossbow_01", daggers = "INV_Weapon_ShortBlade_05", fistWeapons = "INV_Gauntlets_04",
    guns = "INV_Weapon_Rifle_01", maces = "INV_Mace_01", twoHandedMaces = "INV_Hammer_09",
    polearms = "INV_Spear_06", staves = "INV_Staff_08", swords = "INV_Sword_04",
    twoHandedSwords = "INV_Sword_39", thrown = "INV_ThrowingKnife_02", unarmed = "Ability_GolemThunderClap",
    wands = "INV_Wand_01",
    defense = "Ability_Defend", lockpicking = "INV_Misc_Key_03", riding = "Ability_Mount_RidingHorse",
}
-- The spells whose texture is a profession's icon: the open spells, but Mining's is Mining (2575),
-- not Smelting, and the gathering lines' are Herb Gathering, Skinning and Fishing. Unverified.
local ICON_SPELL_IDS = {
    alchemy = 2259, blacksmithing = 2018, enchanting = 7411, engineering = 4036, leatherworking = 2108,
    tailoring = 3908, cooking = 2550, firstAid = 3273, mining = 2575, herbalism = 2366,
    skinning = 8613, fishing = 7620,
}
-- The icon an unknown ("other:<name>") line draws.
NS.SKILL_ICON_UNKNOWN = "Interface\\Icons\\INV_Misc_QuestionMark"
for key, name in pairs(ICONS) do NS.SkillCatalog[key].icon = "Interface\\Icons\\" .. name end
for key, id in pairs(ICON_SPELL_IDS) do NS.SkillCatalog[key].iconSpellID = id end

-- Horse, Wolf, Tiger, Ram, Raptor, Mechanostrider, Undead Horsemanship, Kodo.
NS.SkillCatalog.riding.aliasIDs = { 148, 149, 150, 152, 533, 553, 554, 713 }

-- The Skills-tab headers whose lines the design leaves out (design §3: armor proficiencies,
-- languages, class spell-school lines). A catalog name under one of them is still read
-- (a rogue's Lockpicking sits under Class Skills); any other line under them is skipped.
NS.SkillExcludedHeaders = { "Class Skills", "Armor Proficiencies", "Languages" }
