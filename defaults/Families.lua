local _, NS = ...
-- defaults/Families.lua — the six families, one window and one broker each (item SMW-02 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md; the spec's "Families and windows").
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
--   feed           its LibDataBroker feed: `name` (a display stores placements by it, so it never changes
--                  once shipped) and `label`
-- The window's own defaults (position, size, columns) are its profile rows, `windows.<family>`
-- (defaults/Profile.lua), not part of this table.
--
-- Professions holds Primary and Secondary, Skills holds Weapon and Other (the spec's call). "Skill Master"
-- and "Skill Master Stats" keep their LibDataBroker names for Professions and Character Stats.

local L = NS.L

NS.FAMILY_ORDER = { "professions", "skills", "stats", "currencies", "reputations", "statistics" }

local function family(id, t)
    t.id = id
    return t
end

NS.Families = {
    professions = family("professions", {
        title = L["Skill Master \194\183 Professions"], short = L["Professions"], blocks = { "primary", "secondary" },
        source = "skills", rowKind = "skill", message = "SKILLS_UPDATED",
        feed = { name = "Skill Master", label = L["Skill Master"] },
    }),
    skills = family("skills", {
        title = L["Skill Master \194\183 Skills"], short = L["Skills"], blocks = { "weapon", "other" },
        source = "skills", rowKind = "skill", message = "SKILLS_UPDATED",
        feed = { name = "Skill Master Skills", label = L["Skill Master Skills"] },
    }),
    stats = family("stats", {
        title = L["Skill Master \194\183 Character Stats"], short = L["Character Stats"],
        blocks = { "stats_base", "stats_spell", "stats_defense", "stats_utility" },
        source = "stats", rowKind = "stat", message = "STATS_UPDATED",
        feed = { name = "Skill Master Stats", label = L["Skill Master Character Stats"] },
    }),
    currencies = family("currencies", {
        title = L["Skill Master \194\183 Currencies"], short = L["Currencies"], blocks = { "currencies" },
        source = "currencies", rowKind = "currency", message = "CURRENCIES_UPDATED", tree = true,
        feed = { name = "Skill Master Currencies", label = L["Skill Master Currencies"] },
    }),
    reputations = family("reputations", {
        title = L["Skill Master \194\183 Reputations"], short = L["Reputations"], blocks = { "reputations" },
        source = "reputations", rowKind = "reputation", message = "REPS_UPDATED", tree = true,
        feed = { name = "Skill Master Reputations", label = L["Skill Master Reputations"] },
    }),
    statistics = family("statistics", {
        title = L["Skill Master \194\183 Statistics"], short = L["Statistics"], blocks = { "statistics" },
        source = "statistics", rowKind = "statistic", message = "STATISTICS_UPDATED", tree = true,
        feed = { name = "Skill Master Statistics", label = L["Skill Master Statistics"] },
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
