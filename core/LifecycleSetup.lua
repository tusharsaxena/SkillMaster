local addonName, NS = ...
-- core/LifecycleSetup.lua — the one stand-down latch (LibKa0s-Lifecycle-1.0, slash-commands-§7):
-- the `disabled` hold and the perf harness's `perf` hold, one teardown path for both.
--
-- LOAD-BEARING: publishes NS.Lifecycle, which core/PerfSetup.lua hands LibKa0s-Perf-1.0 at load.

local lib = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

--- True while any hold keeps the addon stood down.
function NS.IsStoodDown()
    return NS.Lifecycle ~= nil and NS.Lifecycle:IsDown() == true
end

--- The one hold-aware refusal helper (slash-commands-§7, "Which refusal, by hold"): the line a
--- stood-down feature prints, or nil while standing up.
function NS.StoodDownRefusal()
    local latch = NS.Lifecycle
    if latch == nil or latch:IsDown() ~= true then return nil end
    if latch:IsHeld(NS.HOLD_DISABLED) then return NS.Slash:DisabledLine() end
    return NS.L["Not available during a performance capture."]
end

--- Move the `disabled` hold to match the stored `enabled` row.
function NS.SyncEnabledHold()
    NS.Lifecycle:Set(NS.HOLD_DISABLED, NS.GetSetting("enabled") == false)
end

-- The teardown and rebuild. NS.StandDown / NS.StandUp are defined in core/SkillMaster.lua and
-- reached at call time.
if not lib then
    local held, down = {}, false
    local function reevaluate()
        local any = next(held) ~= nil
        if any == down then return false end
        down = any
        if any then NS.StandDown() else NS.StandUp() end
        return true
    end
    NS.Lifecycle = {
        name       = addonName,
        Hold       = function(_, key) held[key] = true; return reevaluate() end,
        Release    = function(_, key) held[key] = nil;  return reevaluate() end,
        Set        = function(self, key, on) if on then return self:Hold(key) end return self:Release(key) end,
        IsHeld     = function(_, key) return held[key] == true end,
        IsDown     = function() return down end,
        Holds      = function()
            local out = {}
            for k in pairs(held) do out[#out + 1] = k end
            table.sort(out)
            return out
        end,
        Reevaluate = function() return reevaluate() end,
        PrintHolds = function(self)
            local holds = self:Holds()
            NS.Print(addonName .. ": " .. (#holds > 0 and table.concat(holds, ", ") or "no holds"))
            return true
        end,
    }
    NS.HOLD_DISABLED = "disabled"
    NS.HOLD_PERF     = "perf"
    return
end

NS.HOLD_DISABLED = lib.HOLD_DISABLED
NS.HOLD_PERF     = lib.HOLD_PERF
NS.Lifecycle = lib:New({
    name      = addonName,
    standDown = function() NS.StandDown() end,
    standUp   = function() NS.StandUp() end,
    print     = function(line) NS.Print(line) end,
    -- The library logs every edge with its holds; the callbacks write no edge line of their own.
    debug     = function(tag, message) NS.Debug(tag, "%s", message) end,
})
