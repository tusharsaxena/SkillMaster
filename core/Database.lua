local addonName, NS = ...
-- core/Database.lua — the AceDB store and the schemaVersion migration runner (savedvariables-§1).
-- The defaults tree is defaults/Profile.lua's NS.defaults, read at InitDB time.

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = 1

-- Each step is idempotent against a fresh default profile. A profile-scoped step sets
-- `perProfile = true` and runs for every stored profile.
local STEPS = {
    { to = 1, run = function() end },   -- 0 -> 1: pre-versioning, a no-op
}

function NS:InitDB()
    NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)
end

function NS:RunMigrations()
    local g, sv = NS.db.global, _G[addonName .. "DB"]
    local from = g.schemaVersion or 0
    for _, step in ipairs(STEPS) do
        if (g.schemaVersion or 0) < step.to then
            if step.perProfile then
                for _, profile in pairs(sv and sv.profiles or {}) do step.run(sv, profile) end
            else
                step.run(sv)
            end
            g.schemaVersion = step.to   -- the runner owns the stamp; reached only if the step returned
        end
    end
    if from ~= g.schemaVersion then NS.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion) end
end
