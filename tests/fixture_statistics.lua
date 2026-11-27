-- tests/fixture_statistics.lua — the character panel's Statistics tab as the mocks answer it (SMW-10 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md), in Forever's shapes: GetStatisticsCategoryList (a
-- table ordered by numeric key), GetCategoryInfo (name, parent; -1 a root), GetCategoryNumAchievements,
-- GetStatistic(categoryID, index) -> quantity, skip, statID (Retail's one-argument form raises) and
-- GetAchievementInfo(statID) (the name second). Shared by tests/test_statistics.lua and tests/perf.lua.
--
-- local fx = dofile("tests/fixture_statistics.lua")
-- local spy, restore = fx.install(M[, tree])   -- tree: fx.small() (the default) or fx.large(cats, perCat)
-- spy.calls[name] counts each API's calls; spy.stat[statID] = quantity changes a value; restore() puts the
-- mocks back.

local fx = {}

local NAMES = { "GetStatisticsCategoryList", "GetCategoryInfo", "GetCategoryNumAchievements", "GetStatistic",
                "GetAchievementInfo" }

--- Character (130): Times camped, Talent tree respecs (0: "--"), a skipped row; under it Wealth (140): Total
--- gold acquired, Auctions posted; and Consumables (141). Then Combat (150), a root of its own.
function fx.small()
    return {
        { id = 130, name = "Character", parent = -1, rows = {
            { statID = 9001, name = "Times camped", quantity = 58 },
            { statID = 9002, name = "Talent tree respecs", quantity = 0 },
            { statID = 9003, name = "Hidden row", quantity = 7, skip = true },
        } },
        { id = 140, name = "Wealth", parent = 130, rows = {
            { statID = 9101, name = "Total gold acquired", quantity = 123456 },
            { statID = 9102, name = "Auctions posted", quantity = 33 },
        } },
        { id = 141, name = "Consumables", parent = 130, rows = {
            { statID = 9201, name = "Bandages used", quantity = "12" },
        } },
        { id = 150, name = "Combat", parent = -1, rows = {
            { statID = 9301, name = "Total kills", quantity = 1200 },
        } },
    }
end

--- `cats` categories (every fifth a root, the others under the root before them) of `perCat` rows each: about
--- 1000 rows at fx.large(40, 25), the size of Retail's whole Statistics tab.
function fx.large(cats, perCat)
    local tree, root = {}, -1
    for c = 1, cats do
        local id = 1000 + c
        local parent = -1
        if c % 5 == 1 then root = id else parent = root end
        local rows = {}
        for r = 1, perCat do
            rows[r] = { statID = id * 100 + r, name = ("Statistic %d.%d"):format(c, r), quantity = c * r }
        end
        tree[c] = { id = id, name = ("Category %d"):format(c), parent = parent, rows = rows }
    end
    return tree
end

function fx.install(M, tree)
    tree = tree or fx.small()
    local saved = {}
    for i, n in ipairs(NAMES) do saved[i] = M[n] end
    local spy = { calls = {}, stat = {} }
    local byId, byStat = {}, {}
    for _, c in ipairs(tree) do
        byId[c.id] = c
        for _, r in ipairs(c.rows) do byStat[r.statID] = r end
    end
    spy.tree, spy.byId, spy.byStat = tree, byId, byStat
    local function count(name) spy.calls[name] = (spy.calls[name] or 0) + 1 end
    M.GetStatisticsCategoryList = function()
        count("GetStatisticsCategoryList")
        local out = {}
        for i, c in ipairs(tree) do out[i * 2] = c.id end   -- sparse numeric keys, as Blizzard allows for
        return out
    end
    M.GetCategoryInfo = function(id)
        count("GetCategoryInfo")
        local c = byId[id]
        if c then return c.name, c.parent end
        return nil
    end
    M.GetCategoryNumAchievements = function(id)
        count("GetCategoryNumAchievements")
        local c = byId[id]
        return c and #c.rows or 0
    end
    M.GetStatistic = function(cat, index)
        count("GetStatistic")
        if index == nil then error("Usage: GetStatistic(categoryID, index)") end
        local c = byId[cat]
        local r = c and c.rows[index]
        if not r then return nil end
        local q = spy.stat[r.statID]
        if q == nil then q = r.quantity end
        return q, r.skip or false, r.statID
    end
    M.GetAchievementInfo = function(statID)
        count("GetAchievementInfo")
        local r = byStat[statID]
        return statID, r and r.name or nil
    end
    local function restore()
        for i, n in ipairs(NAMES) do M[n] = saved[i] end
    end
    return spy, restore
end

return fx
