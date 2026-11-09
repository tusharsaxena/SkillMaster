local _, NS = ...
-- defaults/Preview_Forever.lua — test mode's sample character (preview-mode), the one the v1 mockups
-- draw: Ember Ironsong, a level-22 Dwarf Hunter (Main, Journal and Tooltips .dc.html). Data only;
-- modules/Preview.lua builds the models from it through the live pipelines (SkillData.Build,
-- StatData.Build, Bonuses.Compute) at CALL time, and the simulator (modules/Simulator.lua) plays its
-- scripted session on the same character.
--
-- Field meanings:
--   character  who the sample is; `raceFile` and `classFile` are the client's file tokens.
--   lines      the Skills tab as the client lists it: a `header` row, then { name, rank, max,
--              modifier? } per learned line. Names are the catalog's English names, localized
--              through NS.L when the model is built. Unlearned rows come from the class list.
--   temp       the temporary bonuses, each { skill, amount, label, seconds, source }: `seconds` is
--              the time left when test mode turns on.
--   stats      value per NS.STAT_DEFS key (a number, or { value, raw }), at the character's level.
--   log        the session's skill-ups, newest first, each { ago = seconds before now, skill, old,
--              new, zone }; `sessionAgo` is when the session began.
--   alts       the other characters' snapshots, each skill { rank, max }.
--
-- Kept current at every release (preview-mode): every display element the release adds appears
-- here, and the data names Forever's content.

NS.Preview_Forever = {
    meta = {
        source   = "the v1 design mockups (docs/superpowers/specs/2026-11-10-skill-master-mockups/)",
        verified = false,
    },

    character = {
        name = "Ember Ironsong", level = 22, race = "Dwarf", raceFile = "Dwarf",
        class = "Hunter", classFile = "HUNTER", faction = "Alliance", realm = "PvP",
    },

    lines = {
        { header = "Professions" },
        { "Leatherworking", 146, 150 },
        { "Skinning", 122, 150 },
        { header = "Secondary Skills" },
        { "Cooking", 133, 150 },
        { "First Aid", 121, 150 },
        { "Fishing", 107, 150, modifier = 25 },
        { header = "Weapon Skills" },
        { "Axes", 1, 110 },
        { "Bows", 81, 110 },
        { "Crossbows", 1, 110 },
        { "Daggers", 74, 110 },
        { "Guns", 105, 110, modifier = 5 },
        { "Staves", 1, 110 },
        { "Swords", 1, 110 },
        { "Two-Handed Axes", 107, 110 },
        { "Two-Handed Swords", 1, 110 },
        { "Unarmed", 4, 110 },
        { header = "Defenses" },
        { "Defense", 100, 110 },
    },

    -- The lure the Fishing row's teal segment and its 4:12 timer show. Guns' +5 is the Dwarf racial
    -- (defaults/Racials_Forever.lua), attributed by the same breakdown as live.
    temp = {
        { skill = "Fishing", amount = 25, label = "Shiny Bauble", seconds = 252, source = "enchant" },
    },

    stats = {
        strength = 48, agility = 112, stamina = 86, intellect = 41, spirit = 52,
        attackPower = 164, rangedAttackPower = 248,
        meleeCrit = 7.42, rangedCrit = 9.12, meleeHit = 2, rangedHit = 2,
        spellDamage = 0, spellHealing = 0, spellCrit = 1.8, spellHit = 0, manaRegen = 9,
        armor = { 26.5, 820 }, defense = 100, dodge = 6.8, parry = 0,
        fireResist = 0, natureResist = 10, frostResist = 0, shadowResist = 0, arcaneResist = 0,
        speed = 0, runSpeed = 100, swimSpeed = 67, durability = 82,
    },

    sessionAgo = 6720,   -- 1 h 52 m
    last = { skill = "Bows", new = 81 },
    log = {
        { ago = 60,   skill = "Bows",            old = 80,  new = 81,  zone = "Loch Modan" },
        { ago = 240,  skill = "Fishing",         old = 106, new = 107, zone = "Loch Modan" },
        { ago = 720,  skill = "Skinning",        old = 121, new = 122, zone = "Loch Modan" },
        { ago = 780,  skill = "Two-Handed Axes", old = 106, new = 107, zone = "Loch Modan" },
        { ago = 1500, skill = "Leatherworking",  old = 145, new = 146, zone = "Ironforge" },
        { ago = 1620, skill = "Leatherworking",  old = 144, new = 145, zone = "Ironforge" },
        { ago = 1860, skill = "Fishing",         old = 105, new = 106, zone = "Ironforge" },
        { ago = 2700, skill = "Defense",         old = 99,  new = 100, zone = "Wetlands" },
        { ago = 3720, skill = "Cooking",         old = 132, new = 133, zone = "Wetlands" },
        { ago = 4860, skill = "Skinning",        old = 120, new = 121, zone = "Wetlands" },
        { ago = 5580, skill = "Fishing",         old = 104, new = 105, zone = "Wetlands" },
        { ago = 6060, skill = "Skinning",        old = 119, new = 120, zone = "Wetlands" },
        { ago = 6480, skill = "Leatherworking",  old = 143, new = 144, zone = "Wetlands" },
        { ago = 6660, skill = "Fishing",         old = 103, new = 104, zone = "Wetlands" },
    },

    alts = {
        { name = "Quill Ashbrook", level = 41, race = "Human", class = "WARRIOR", className = "Warrior",
          faction = "Alliance", updatedAgo = 86400 * 2,
          skills = { blacksmithing = { 218, 225 }, mining = { 212, 225 }, cooking = { 201, 225 },
                     fishing = { 150, 225 } } },
        { name = "Tamsin Reedwhistle", level = 17, race = "Gnome", class = "MAGE", className = "Mage",
          faction = "Alliance", updatedAgo = 86400 * 5,
          skills = { tailoring = { 70, 75 }, cooking = { 62, 75 }, fishing = { 38, 75 } } },
        { name = "Brannoch Deepvale", level = 60, race = "Dwarf", class = "PALADIN", className = "Paladin",
          faction = "Alliance", updatedAgo = 86400 * 12,
          skills = { blacksmithing = { 300, 300 }, mining = { 300, 300 }, cooking = { 300, 300 },
                     fishing = { 265, 300 } } },
    },
}
