local _, NS = ...
-- defaults/Ranks_Forever.lua — the trainable rank ladders: each rank's cap, level gate, skill gate
-- and training cost (copper), and which ladder each skill key climbs (design §8).
--
-- Validated from the sources for GitHub issue #10 (the owner, 2026-11-27: no in-game trainer visits).
-- Caps: each rank spell's description and SpellEffect 118 in WoW Forever's DB2 (wowf 1.60.1.71139),
-- e.g. Alchemy 2259/3101/3464/11611, Riding 33388/33391. Skill gates: the pre-BfA rule, confirmed by
-- the Expert books' ItemSparse RequiredSkillRank (125) and the Artisan quests' skill (225, ForeverDB
-- `qx`). Level gates: the Forever profession guides (games.gg 2026-11-23, boostroom 2026-11-10) and
-- the books' ItemSparse RequiredLevel. Trainer fees are in no source (DB2 has no SkillTiers on this
-- build, ForeverDB no profession trainer lists), so `cost` is the vanilla value, listed in `unsourced`
-- and shown nowhere (the popup shows each trainer's own cost). Weapon skills have no ranks (their
-- cap is 5 x level, modules/Helpers.lua), and Lockpicking rises with the rogue's level, so neither
-- has a ladder.

local L = NS.L

local SOURCE_PROFESSION = "WoW Forever DB2 rank spells (caps); warcraft.wiki.gg/wiki/Artisan (skill gates); "
    .. "games.gg and boostroom Forever profession guides (level gates)"
local SOURCE_SECONDARY = "WoW Forever DB2: Expert from a book (ItemSparse 16072/16083/16084: skill 125, level 0, "
    .. "Fishing 20), Artisan from a quest (skill 225, quest min level 35; no fee)"
local SOURCE_RIDING = "WoW Forever DB2 spells 33388/33391 (caps); method.gg and games.gg Forever mount guides "
    .. "(riding 75 at 40 for 100g, 150 at 60 for 1000g)"

NS.Ranks_Forever = {
    profession = {
        verified = "wowf@1.60.1.71139", source = SOURCE_PROFESSION, unsourced = { "cost", "Apprentice minLevel" },
        { rankName = L["Apprentice"], cap = 75,  minLevel = 5,  minSkill = 0,   cost = 10 },
        { rankName = L["Journeyman"], cap = 150, minLevel = 10, minSkill = 50,  cost = 500 },
        { rankName = L["Expert"],     cap = 225, minLevel = 20, minSkill = 125, cost = 10000 },
        { rankName = L["Artisan"],    cap = 300, minLevel = 35, minSkill = 200, cost = 50000 },
    },
    -- Cooking, First Aid and Fishing: Apprentice and Journeyman from a trainer, Expert from a book
    -- (the vendors in defaults/Trainers_Forever.lua), Artisan from a quest at skill 225 (no fee).
    secondary = {
        verified = "wowf@1.60.1.71139", source = SOURCE_SECONDARY, unsourced = { "cost", "Apprentice minLevel" },
        { rankName = L["Apprentice"], cap = 75,  minLevel = 5,  minSkill = 0,   cost = 10 },
        { rankName = L["Journeyman"], cap = 150, minLevel = 10, minSkill = 50,  cost = 500 },
        { rankName = L["Expert"],     cap = 225, minLevel = 0,  minSkill = 125, cost = 10000 },
        { rankName = L["Artisan"],    cap = 300, minLevel = 35, minSkill = 225, cost = 0 },
    },
    -- Fishing as secondary, but its Expert book (16083) asks level 20 (ItemSparse RequiredLevel).
    fishing = {
        verified = "wowf@1.60.1.71139", source = SOURCE_SECONDARY, unsourced = { "cost", "Apprentice minLevel" },
        { rankName = L["Apprentice"], cap = 75,  minLevel = 5,  minSkill = 0,   cost = 10 },
        { rankName = L["Journeyman"], cap = 150, minLevel = 10, minSkill = 50,  cost = 500 },
        { rankName = L["Expert"],     cap = 225, minLevel = 20, minSkill = 125, cost = 10000 },
        { rankName = L["Artisan"],    cap = 300, minLevel = 35, minSkill = 225, cost = 0 },
    },
    riding = {
        verified = "wowf@1.60.1.71139", source = SOURCE_RIDING,
        { rankName = L["Apprentice"], cap = 75,  minLevel = 40, minSkill = 0,  cost = 1000000 },
        { rankName = L["Journeyman"], cap = 150, minLevel = 60, minSkill = 75, cost = 10000000 },
    },
}

-- Skill key (the SkillCatalog's stable camelCase keys, T2.1) -> its ladder.
NS.RankLadderFor_Forever = {
    alchemy = "profession", blacksmithing = "profession", enchanting = "profession",
    engineering = "profession", herbalism = "profession", leatherworking = "profession",
    mining = "profession", skinning = "profession", tailoring = "profession",
    cooking = "secondary", firstAid = "secondary", fishing = "fishing",
    riding = "riding",
}
