local _, NS = ...
-- modules/BlockProviders.lua — the data providers the block engine dispatches on (item SMW-02 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md). A block's def names its provider by `source`
-- (NS.BlockDefs[id].source, the family's `source` in defaults/Families.lua), and modules/Blocks.lua reads
-- NS.Blocks.PROVIDERS[source] at CALL time instead of branching on skills or stats, so a new family adds a
-- provider here and no branch there. Each provider is:
--   model()                          the live model, nil while it has none
--   entries(model, filter, isHidden) the rows block `filter` shows: { kind, entry } each, in model order
--   hiddenSet                        the profile key of its hidden set (`<hiddenSet>.hidden`, the Rows page)
--   groupOf(key, modelOf)            the block filter a hidden key belongs to (B.HiddenKeys); `modelOf()`
--                                    answers the model, read on first need

local B = NS.Blocks
local P = {}
B.PROVIDERS = P

-- ---------------------------------------------------------------------------------------------
-- skills: Primary, Secondary, Weapon and Other (NS.SkillData)
-- ---------------------------------------------------------------------------------------------

P.skills = {
    hiddenSet = "skills",
    model = function()
        local SD = NS.SkillData
        return SD and type(SD.Model) == "function" and SD:Model() or nil
    end,
    entries = function(skills, category, isHidden)
        local out = {}
        local showUnlearned = not (NS.db and NS.db.profile.skills.showUnlearned == false)
        for _, key in ipairs(skills and skills.order[category] or {}) do
            local e = skills.byKey[key]
            if e and not isHidden("skills", key) and (e.learned ~= false or showUnlearned) then
                out[#out + 1] = { kind = "skill", entry = e }
            end
        end
        return out
    end,
    -- a skill's catalog category, else its model category
    groupOf = function(key, modelOf)
        local cat = NS.SkillCatalog[key]
        if cat and cat.category then return cat.category end
        local skills = modelOf()
        local e = skills and skills.byKey and skills.byKey[key]
        return e and e.category
    end,
}

-- ---------------------------------------------------------------------------------------------
-- stats: the four Character Stats blocks (NS.StatData)
-- ---------------------------------------------------------------------------------------------

P.stats = {
    hiddenSet = "stats",
    model = function()
        local ST = NS.StatData
        return ST and type(ST.Model) == "function" and (ST:Model() or ST:Scan()) or nil
    end,
    entries = function(stats, group, isHidden)
        local out = {}
        for _, e in ipairs(stats and stats[group] or {}) do
            if not isHidden("stats", e.key) then out[#out + 1] = { kind = "stat", entry = e } end
        end
        return out
    end,
    -- a stat's group, from its definition
    groupOf = function(key)
        for _, sd in ipairs(NS.STAT_DEFS or {}) do
            if sd.key == key then return sd.group end
        end
        return nil
    end,
}

-- ---------------------------------------------------------------------------------------------
-- The tree families (SMW-08..10): one block each, its rows its model's tree under the folds (modules/Tree.lua).
-- A tree model is { order = { entries in the panel's order }, byKey = { [key] = entry } }; a provider answers
-- no rows until its data module has built one. No hidden set: a tree row is never hidden from its window.
-- ---------------------------------------------------------------------------------------------

-- A detached sub-category (R5-SM-09, modules/SubBlocks.lua) is the block whose `filter` is its header's node key:
-- its rows are the header's subtree, rebased to depth 0. A window (`folds` nil: the window's own folds) leaves out
-- every sub-category detached from it; the LDB tooltip (its own folds) keeps the whole tree.
local function treeProvider(family, kind, modelOf)
    return {
        hiddenSet = family,
        model = modelOf,
        entries = function(m, node, _, folds)
            if type(m) ~= "table" or type(m.order) ~= "table" then return {} end
            local SB = NS.SubBlocks
            local order, base = m.order, 0
            if node ~= nil then order, base = SB.Subtree(order, node) end
            if folds == nil then order = SB.Without(order, family) end
            local rows = NS.Tree.Rows(order, family, kind, folds)
            if base > 0 then
                for _, r in ipairs(rows) do
                    r.depth = r.depth - base
                    r.indent = r.depth * NS.Tree.INDENT
                end
            end
            return rows
        end,
        groupOf = function() return nil end,
    }
end
B.TreeProvider = treeProvider

P.currencies = treeProvider("currencies", "currency", function()
    local CD = NS.CurrencyData
    return CD and CD:Model() or nil
end)

P.reputations = treeProvider("reputations", "reputation", function()
    local RD = NS.RepData
    return RD and RD:Model() or nil
end)

-- Statistics (SMW-10): the same tree, read lazily. The block laying its rows asks NS.StatisticsData:Open with the
-- folds it draws under (the window's, or the LDB tooltip's own), so only an unfolded category's rows are ever
-- read; a sample model (test mode, the simulator) is drawn as it is.
local statistics = treeProvider("statistics", "statistic", function()
    local SD = NS.StatisticsData
    return SD and SD:Model() or nil
end)
local drawTree = statistics.entries
statistics.entries = function(m, filter, isHidden, folds)
    local SD = NS.StatisticsData
    if SD and SD.Live(m) then
        -- A detached category reads its rows whatever the window's folds say of it and the categories above it.
        local read = folds
        if filter ~= nil and folds == nil then
            local used = SD:Use(true)
            read = NS.SubBlocks.OpenStore(used and used.order, "statistics", filter)
        end
        m = SD:Open(read)
    end
    return drawTree(m, filter, isHidden, folds)
end
P.statistics = statistics
