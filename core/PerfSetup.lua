local addonName, NS = ...
-- core/PerfSetup.lua — NS.Perf from LibKa0s-Perf-1.0 (performance): the declared buckets, the
-- capture ring SkillMasterPerfDB, and the `perf` verb's act. No `decorate` hook: the library draws
-- the panel's close control from addonName.
--
-- LOAD-BEARING: before any module that takes `local Perf = NS.Perf` as a load-time upvalue.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
-- The library's JSON encoder for the probe's report (modules/Probe.lua); nil without the library.
NS.PerfEncodeJSON = lib and lib.EncodeJSON or nil
if not lib then
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        OnCommand = function()
            return { NS.L["%s, so performance measurement is unavailable."]:format(NS.LIBKA0S_MISSING) }
        end,
    }
    return
end

NS.Perf = lib:New({
    name      = addonName,
    addonName = addonName,
    title     = NS.Constants.BRAND,
    slash     = "/sm",
    version   = NS.version,
    sv        = addonName .. "PerfDB",
    -- Declared in report order. Each is reached by a real bracket (tests/test_perf.lua):
    buckets = {
        { key = "windowRender" },   -- modules/MainWindow.lua Render, one pass over the window body
        { key = "detachedRender" }, -- modules/Detached.lua Render, one detached block's rows
        { key = "skillScan" },      -- modules/SkillData.lua Scan: read the list, build the model
        { key = "statScan" },       -- modules/StatData.lua Scan: read every stat
        { key = "bonusRefresh" },   -- modules/Bonuses.lua Refresh: invalidate, the live-temp check
    },
    -- Each bracket closes before its module sends its message, so no bucket runs inside another.
    -- The stand-down latch: a capture holds `perf`, which is the same teardown as `disabled`.
    lifecycle = NS.Lifecycle,
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Perf", line) else NS.Print(line) end
    end,
    print   = function(line) NS.Print(line) end,
    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then NS.DebugLog:Show() end
    end,
})
