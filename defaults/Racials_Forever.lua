local _, NS = ...
-- defaults/Racials_Forever.lua — the racial weapon-skill bonuses Bonuses attributes as permanent
-- (design §5.2, plan Task 2.2). Keyed by UnitRace's second return (the race file token), then by
-- the skill catalog's stable key (defaults/SkillCatalog_Forever.lua, T2.1).

NS.Racials_Forever = {
    source   = "vanilla 1.12 racial traits: Human Sword and Mace Specialization, Dwarf Gun "
        .. "Specialization, Orc Axe Specialization, Troll Bow and Throwing Weapon Specialization",
    -- Not checked in game yet: flips to true after the owner's Forever smoke pass.
    verified = false,
    byRace = {
        Human = { swords = 5, twoHandedSwords = 5, maces = 5, twoHandedMaces = 5 },
        Dwarf = { guns = 5 },
        Orc   = { axes = 5, twoHandedAxes = 5 },
        Troll = { bows = 5, thrown = 5 },
    },
}
