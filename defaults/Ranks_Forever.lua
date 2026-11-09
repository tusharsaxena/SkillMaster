local _, NS = ...
-- defaults/Ranks_Forever.lua — the trainable rank ladders: each rank's cap, level gate, skill gate
-- and training cost (copper), and which ladder each skill key climbs (design §8).
--
-- Unverified until the owner's smoke pass (verified = false). Weapon skills have no ranks (their
-- cap is 5 x level, modules/Helpers.lua), and Lockpicking rises with the rogue's level, so neither
-- has a ladder.

local L = NS.L

local SOURCE_PROFESSION = "warcraft.wiki.gg/wiki/Artisan (pre-BfA rank gates); costs vanilla 1.12 data"
local SOURCE_RIDING = "vanilla 1.12 data (riding 75 at 40 for 90g, 150 at 60 for 900g; plan Task 2.4)"

NS.Ranks_Forever = {
    profession = {
        verified = false, source = SOURCE_PROFESSION,
        { rankName = L["Apprentice"], cap = 75,  minLevel = 5,  minSkill = 0,   cost = 10 },
        { rankName = L["Journeyman"], cap = 150, minLevel = 10, minSkill = 50,  cost = 500 },
        { rankName = L["Expert"],     cap = 225, minLevel = 20, minSkill = 125, cost = 10000 },
        { rankName = L["Artisan"],    cap = 300, minLevel = 35, minSkill = 200, cost = 50000 },
    },
    riding = {
        verified = false, source = SOURCE_RIDING,
        { rankName = L["Apprentice"], cap = 75,  minLevel = 40, minSkill = 0,  cost = 900000 },
        { rankName = L["Journeyman"], cap = 150, minLevel = 60, minSkill = 75, cost = 9000000 },
    },
}

-- Skill key (the SkillCatalog's stable camelCase keys, T2.1) -> its ladder.
NS.RankLadderFor_Forever = {
    alchemy = "profession", blacksmithing = "profession", enchanting = "profession",
    engineering = "profession", herbalism = "profession", leatherworking = "profession",
    mining = "profession", skinning = "profession", tailoring = "profession",
    cooking = "profession", firstAid = "profession", fishing = "profession",
    riding = "riding",
}
