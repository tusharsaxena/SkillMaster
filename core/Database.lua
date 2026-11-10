local addonName, NS = ...
-- core/Database.lua — the AceDB store and the schemaVersion migration runner (savedvariables-§1).
-- The defaults tree is defaults/Profile.lua's NS.defaults, read at InitDB time.

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = 2

--- 1 -> 2 (feedback round 1, FB-3): one Rows show for skill and stat rows. A stored
--- `stats.display` moves to `bars.rowDisplay` and the old key goes. Only a value other than the
--- default "both" is a player's choice (savedvariables-§1: AceDB copies a default into the stored
--- table, so presence proves nothing); "both" is the new key's default too, so it is dropped. A
--- `bars.rowDisplay` already stored wins. A fresh profile carries neither key and passes through.
local function rowDisplayFromStats(_, profile)
    local stats = type(profile) == "table" and profile.stats
    if type(stats) ~= "table" or stats.display == nil then return end
    local mode = stats.display
    stats.display = nil
    if mode ~= "bar" and mode ~= "text" then return end
    if type(profile.bars) ~= "table" then profile.bars = {} end
    if profile.bars.rowDisplay == nil then profile.bars.rowDisplay = mode end
end

-- Each step is idempotent against a fresh default profile. A profile-scoped step sets
-- `perProfile = true` and runs for every stored profile.
local STEPS = {
    { to = 1, run = function() end },   -- 0 -> 1: pre-versioning, a no-op
    { to = 2, run = rowDisplayFromStats, perProfile = true },
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
