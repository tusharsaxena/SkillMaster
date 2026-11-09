local _, NS = ...
-- core/PoolSetup.lua — NS.Pool from LibKa0s-Pool-1.0: the free/active widget pools the skill rows
-- and bars (T3.1, T3.2) are drawn from. The ARRAY shape is used (New / Acquire / ReleaseAll).

local lib = LibStub and LibStub("LibKa0s-Pool-1.0", true)
if lib then
    NS.Pool = lib
    return
end

-- Degrade, never error: the same members, holding frames in plain lists.
NS.Pool = {
    New = function() return { free = {}, active = {} } end,
    Acquire = function(pool, factory)
        local obj = table.remove(pool.free) or factory()
        pool.active[#pool.active + 1] = obj
        return obj
    end,
    ReleaseAll = function(pool, before)
        for i = #pool.active, 1, -1 do
            local obj = pool.active[i]
            if before then before(obj) end
            if obj.Hide then obj:Hide() end
            pool.free[#pool.free + 1] = obj
            pool.active[i] = nil
        end
    end,
    Counts = function(pool) return #pool.active, #pool.free end,
    NewKeyed = function() return { free = {}, active = {} } end,
    AcquireKeyed = function(pool, key, factory)
        local obj = pool.active[key] or table.remove(pool.free) or factory()
        pool.active[key] = obj
        return obj
    end,
    ReleaseAllKeyed = function(pool, before)
        for key, obj in pairs(pool.active) do
            if before then before(obj) end
            if obj.Hide then obj:Hide() end
            pool.free[#pool.free + 1] = obj
            pool.active[key] = nil
        end
    end,
    CountsKeyed = function(pool)
        local n = 0
        for _ in pairs(pool.active) do n = n + 1 end
        return n, #pool.free
    end,
}
