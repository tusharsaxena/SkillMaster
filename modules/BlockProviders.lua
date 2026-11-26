local _, NS = ...
-- modules/BlockProviders.lua — the data providers the block engine dispatches on (item SMW-02 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md). A block's def names its provider by `source`
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

local function treeProvider(family, kind, modelOf)
    return {
        hiddenSet = family,
        model = modelOf,
        entries = function(m, _, _, folds)
            if type(m) ~= "table" or type(m.order) ~= "table" then return {} end
            return NS.Tree.Rows(m.order, family, kind, folds)
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
