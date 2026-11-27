local _, NS = ...
-- defaults/Preview_Forever.lua — test mode's sample character (preview-mode), the one the v1 mockups
-- draw: a level-22 Dwarf Hunter (Main, Journal and Tooltips .dc.html). Data only;
-- modules/Preview.lua builds the models from it through the live pipelines (SkillData.Build,
-- StatData.Build, Bonuses.Compute) at CALL time, and the simulator (modules/Simulator.lua) plays its
-- scripted session on the same character.
--
-- Field meanings:
--   character  who the sample is; `raceFile` and `classFile` are the client's file tokens. `sample`
--              is its row in the collection's shared people, LibKa0s-Sim-1.0's Sim.Sample("forever")
--              (LibKa0s#87): its name and realm come from that row (modules/Preview.lua), never here.
--   lines      the Skills tab as the client lists it: a `header` row, then { name, rank, max,
--              modifier? } per learned line. Names are the catalog's English names, localized
--              through NS.L when the model is built. Unlearned rows come from the class list.
--   temp       the temporary bonuses, each { skill, amount, label, seconds, source }: `seconds` is
--              the time left when test mode turns on.
--   stats      value per NS.STAT_DEFS key (a number, or { value, raw }), at the character's level.
--   log        the session's Log rows, newest first: a skill-up { ago = seconds before now, skill, old,
--              new, zone }, or a reputation's or currency's change { ago, rep | currency (its name), id,
--              old, new, zone[, from, to] (the standings a move crossed) } (R5-SM-12); `sessionAgo`
--              is when the session began.
--   alts       the other characters' snapshots, each skill { rank, max }; `sample` is each one's
--              shared row, as for the character.
--   pinned, mainHand  catalog English names: the broker's {pinned} and {equippedWeapon} skills.
--   reputations  the Reputation tab as the panel groups it (SMW-11): each top `header` { name, id, kids }, a
--              kid { name, id, reaction (1..8), standing (currentStanding) } or a sub-header (`header` with
--              its own kids, `withRep` and a standing for its own bar). The thresholds are the standard ones
--              (Neutral 0, Friendly 3,000, Honored 9,000, Revered 21,000, Exalted 42,000).
--   currencies the Currency tab (SMW-11): each `header` { name, kids }, a kid { name, id, quantity, max (0 no
--              cap), weekly?, earned?, icon }. Never gold (the owner's ruling).
--   statistics the Statistics tab (SMW-11): each category { id, name, parent (-1 a root), rows = { { statID,
--              name, quantity } } }, in the tab's order.
--   treePins   the tree feeds' {pinned} in test mode, one key per family (a factionID, a currencyID, a
--              statistic's "<categoryID>:<statID>").
--
-- Kept current at every release (preview-mode): every display element the release adds appears
-- here, and the data names Forever's content.

NS.Preview_Forever = {
    meta = {
        source   = "the v1 design mockups (docs/superpowers/specs/2026-11-10-skill-master-mockups/)",
        -- Not data that mirrors the game: test mode's fictional character. Sanity-checked for issue #10
        -- (2026-11-27): its Guns no longer carry a racial Forever does not have.
        verified = false,
    },

    character = {
        sample = 1, level = 22, race = "Dwarf", raceFile = "Dwarf",   -- Sim.Sample("forever") row 1
        class = "Hunter", classFile = "HUNTER", faction = "Alliance",
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
        { "Guns", 105, 110 },
        { "Staves", 1, 110 },
        { "Swords", 1, 110 },
        { "Two-Handed Axes", 107, 110 },
        { "Two-Handed Swords", 1, 110 },
        { "Unarmed", 4, 110 },
        { header = "Defenses" },
        { "Defense", 100, 110 },
    },

    -- The lure the Fishing row's teal segment and its 4:12 timer show. Guns carries no bonus: WoW
    -- Forever has no racial weapon-skill bonus (defaults/Racials_Forever.lua, GitHub issue #10).
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
    -- The broker's {pinned} and {equippedWeapon} in test mode (Broker.dc.html: "Fishing 107+25/150",
    -- "Guns 105+5/110"): the sample's own, never this character's store or gear.
    pinned   = "Fishing",
    mainHand = "Guns",
    log = {
        -- The Journal's reputation and currency rows (R5-SM-10, R5-SM-12): a gain that reached Revered, a gain, a
        -- spend. `rep` / `currency` name the row, `id` its key, `from` / `to` the standings a move crossed.
        { ago = 60,   skill = "Bows",            old = 80,  new = 81,  zone = "Loch Modan" },
        { ago = 180,  currency = "Honor Points", id = 1901, old = 1166, new = 1200, zone = "Loch Modan" },
        { ago = 240,  skill = "Fishing",         old = 106, new = 107, zone = "Loch Modan" },
        { ago = 600,  rep = "Ironforge", id = 47, old = 20985, new = 21010, from = 6, to = 7, zone = "Loch Modan" },
        { ago = 720,  skill = "Skinning",        old = 121, new = 122, zone = "Loch Modan" },
        { ago = 780,  skill = "Two-Handed Axes", old = 106, new = 107, zone = "Loch Modan" },
        { ago = 1200, currency = "Darkmoon Prize Ticket", id = 515, old = 20, new = 12, zone = "Ironforge" },
        { ago = 1500, skill = "Leatherworking",  old = 145, new = 146, zone = "Ironforge" },
        { ago = 1620, skill = "Leatherworking",  old = 144, new = 145, zone = "Ironforge" },
        { ago = 1860, skill = "Fishing",         old = 105, new = 106, zone = "Ironforge" },
        { ago = 2400, rep = "Stormwind", id = 72, old = 12647, new = 12672, zone = "Wetlands" },
        { ago = 2700, skill = "Defense",         old = 99,  new = 100, zone = "Wetlands" },
        { ago = 3720, skill = "Cooking",         old = 132, new = 133, zone = "Wetlands" },
        { ago = 4860, skill = "Skinning",        old = 120, new = 121, zone = "Wetlands" },
        { ago = 5580, skill = "Fishing",         old = 104, new = 105, zone = "Wetlands" },
        { ago = 6060, skill = "Skinning",        old = 119, new = 120, zone = "Wetlands" },
        { ago = 6480, skill = "Leatherworking",  old = 143, new = 144, zone = "Wetlands" },
        { ago = 6660, skill = "Fishing",         old = 103, new = 104, zone = "Wetlands" },
    },

    -- The tree families (SMW-11): a level-22 Dwarf's standings, a few currencies, a Statistics tab.
    reputations = {
        { header = "Alliance", id = 469, kids = {
            { name = "Ironforge", id = 47, reaction = 7, standing = 25300 },
            { name = "Stormwind", id = 72, reaction = 6, standing = 12672 },
            { name = "Gnomeregan Exiles", id = 54, reaction = 5, standing = 5200 },
            { name = "Darnassus", id = 69, reaction = 5, standing = 3450 },
        } },
        { header = "Steamwheedle Cartel", id = 169, kids = {
            { name = "Booty Bay", id = 21, reaction = 4, standing = 1450 },
            { name = "Gadgetzan", id = 369, reaction = 4, standing = 600 },
            { name = "Ratchet", id = 470, reaction = 4, standing = 300 },
        } },
        { header = "Other", id = 1169, kids = {
            { name = "Darkmoon Faire", id = 909, reaction = 4, standing = 250 },
        } },
    },
    currencies = {
        { header = "Player vs. Player", kids = {
            { name = "Honor Points", id = 1901, quantity = 1200, max = 75000, weekly = 10000, earned = 800,
              icon = 1455894 },
        } },
        { header = "Miscellaneous", kids = {
            { name = "Darkmoon Prize Ticket", id = 515, quantity = 12, max = 0, icon = 134481 },
        } },
    },
    statistics = {
        { id = 130, name = "Character", parent = -1, rows = {
            { statID = 1532, name = "Times camped", quantity = 58 },
            { statID = 1533, name = "Talent tree respecs", quantity = 0 },
        } },
        { id = 140, name = "Wealth", parent = 130, rows = {
            { statID = 328, name = "Total gold acquired", quantity = 412 },
            { statID = 1149, name = "Auctions posted", quantity = 33 },
        } },
        { id = 145, name = "Consumables", parent = 130, rows = {
            { statID = 346, name = "Beverages consumed", quantity = 71 },
            { statID = 344, name = "Bandages used", quantity = 14 },
        } },
        { id = 141, name = "Combat", parent = -1, rows = {
            { statID = 1197, name = "Total kills", quantity = 1840 },
        } },
        { id = 122, name = "Deaths", parent = -1, rows = {
            { statID = 60, name = "Total deaths", quantity = 9 },
        } },
    },
    treePins = { reputations = "72", currencies = "1901", statistics = "130:1532" },

    alts = {
        { sample = 5, level = 41,   -- row 5, the Warrior
          race = "Human", class = "WARRIOR", className = "Warrior",
          faction = "Alliance", updatedAgo = 86400 * 2,
          skills = { blacksmithing = { 218, 225 }, mining = { 212, 225 }, cooking = { 201, 225 },
                     fishing = { 150, 225 } } },
        { sample = 3, level = 17,   -- row 3, the Mage
          race = "Gnome", class = "MAGE", className = "Mage",
          faction = "Alliance", updatedAgo = 86400 * 5,
          skills = { tailoring = { 70, 75 }, cooking = { 62, 75 }, fishing = { 38, 75 } } },
        { sample = 2, level = 60,   -- row 2, the Paladin
          race = "Dwarf", class = "PALADIN", className = "Paladin",
          faction = "Alliance", updatedAgo = 86400 * 12,
          skills = { blacksmithing = { 300, 300 }, mining = { 300, 300 }, cooking = { 300, 300 },
                     fishing = { 265, 300 } } },
    },
}
