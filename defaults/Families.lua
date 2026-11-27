local _, NS = ...
-- defaults/Families.lua — the six families, one window and one broker each (item SMW-02 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md; the spec's "Families and windows").
--
-- A family is what one of the character panel's tabs shows: Professions and Skills (the Skills tab,
-- split), Character Stats (the paper doll), Currencies, Reputations and Statistics (the Statistics tab:
-- counters such as Times camped, never "stats"). Each entry carries:
--   id, title      the window's title
--   short          its short name: the launcher entry's, the Layout > Windows subsection's (SMW-04)
--   blocks         its block ids, in default order (the tree families have one block each)
--   source         the data provider's key in NS.Blocks.PROVIDERS (modules/BlockProviders.lua)
--   rowKind        the row kind its rows carry ("skill", "stat", ...)
--   message        the NS.MSG key its model announces, read at CALL time (the newer ones land with their
--                  data modules)
--   tree           true for a family drawn by the tree row model (modules/Tree.lua)
--   noAlts         true for a family with no Journal Alts sub-tab (Statistics, the spec's call)
--   feed           its LibDataBroker feed: `name` (a display stores placements by it, so it never changes
--                  once shipped), `label` and `icon` (what the display draws beside the label: an in-game
--                  Interface\Icons\ texture that says what the feed shows, R5-SM-04, the owner's round 5; the
--                  addon's own control broker, core/LauncherSetup.lua, keeps the Ka0s logo)
-- The window's own defaults (position, size, columns) are its profile rows, `windows.<family>`
-- (defaults/Profile.lua), not part of this table.
--
-- Professions holds Primary and Secondary, Skills holds Weapon and Other (the spec's call). "Character Ledger Stats"
-- keeps its LibDataBroker name for Character Stats. The Professions feed was "Character Ledger" until the
-- owner renamed it "Character Ledger Professions" (R7-SM-02, owner feedback round 7), so each family's feed
-- names its family; a display that placed the old name shows the new one as a new feed.

local L = NS.L

-- The feeds' icons (R5-SM-04): names from the 1.x icon set, which the modern client and WoW Forever both
-- carry (as the row icons, defaults/SkillCatalog_Forever.lua). UNVERIFIED until seen on a display in game.
local function icon(name) return "Interface\\Icons\\" .. name end

NS.FAMILY_ORDER = { "professions", "skills", "stats", "currencies", "reputations", "statistics" }

local function family(id, t)
    t.id = id
    return t
end

NS.Families = {
    professions = family("professions", {
        title = L["Character Ledger \194\183 Professions"], short = L["Professions"], blocks = { "primary", "secondary" },
        source = "skills", rowKind = "skill", message = "SKILLS_UPDATED",
        feed = { name = "Character Ledger Professions", label = L["Character Ledger Professions"], icon = icon("Trade_BlackSmithing") },
    }),
    skills = family("skills", {
        title = L["Character Ledger \194\183 Skills"], short = L["Skills"], blocks = { "weapon", "other" },
        source = "skills", rowKind = "skill", message = "SKILLS_UPDATED",
        feed = { name = "Character Ledger Skills", label = L["Character Ledger Skills"], icon = icon("INV_Sword_04") },
    }),
    stats = family("stats", {
        title = L["Character Ledger \194\183 Character Stats"], short = L["Character Stats"],
        blocks = { "stats_base", "stats_spell", "stats_defense", "stats_utility" },
        source = "stats", rowKind = "stat", message = "STATS_UPDATED",
        feed = { name = "Character Ledger Stats", label = L["Character Ledger Stats"], icon = icon("Spell_Nature_Strength") },
    }),
    currencies = family("currencies", {
        title = L["Character Ledger \194\183 Currencies"], short = L["Currencies"], blocks = { "currencies" },
        source = "currencies", rowKind = "currency", message = "CURRENCIES_UPDATED", tree = true,
        feed = { name = "Character Ledger Currencies", label = L["Character Ledger Currencies"], icon = icon("INV_Misc_Coin_01") },
    }),
    reputations = family("reputations", {
        title = L["Character Ledger \194\183 Reputations"], short = L["Reputations"], blocks = { "reputations" },
        source = "reputations", rowKind = "reputation", message = "REPS_UPDATED", tree = true,
        feed = { name = "Character Ledger Reputations", label = L["Character Ledger Reputations"], icon = icon("INV_Shirt_GuildTabard_01") },
    }),
    statistics = family("statistics", {
        title = L["Character Ledger \194\183 Statistics"], short = L["Statistics"], blocks = { "statistics" },
        source = "statistics", rowKind = "statistic", message = "STATISTICS_UPDATED", tree = true, noAlts = true,
        feed = { name = "Character Ledger Statistics", label = L["Character Ledger Statistics"], icon = icon("INV_Misc_Note_01") },
    }),
}

-- block id -> family id
local OWNER = {}
for _, fid in ipairs(NS.FAMILY_ORDER) do
    for _, bid in ipairs(NS.Families[fid].blocks) do OWNER[bid] = fid end
end

--- The family that owns block `blockId`, or nil for an unknown id.
--- @return table|nil the family entry
function NS.FamilyOf(blockId)
    local fid = OWNER[blockId]
    return fid and NS.Families[fid] or nil
end

--- The families in their order (the launcher menu's, the slash verbs', the settings').
function NS.EachFamily()
    local i = 0
    return function()
        i = i + 1
        local fid = NS.FAMILY_ORDER[i]
        if fid then return fid, NS.Families[fid] end
    end
end
