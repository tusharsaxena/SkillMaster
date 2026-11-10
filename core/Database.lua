local addonName, NS = ...
-- core/Database.lua — the AceDB store and the schemaVersion migration runner (savedvariables-§1).
-- The defaults tree is defaults/Profile.lua's NS.defaults, read at InitDB time.

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = 3

--- 1 -> 2 (feedback round 1, FB-3): one Rows show for skill and stat rows. A stored
--- `stats.display` moves to `bars.rowDisplay` and the old key goes. Only a value other than the
--- default "both" is a player's choice (savedvariables-§1: AceDB copies a default into the stored
--- table, so presence proves nothing); "both" is the new key's default too, so it is dropped. A
--- `bars.rowDisplay` already stored as "bar" or "text" wins (the active profile carries the copied
--- default "both", which is not a choice). A fresh profile carries neither key and passes through.
local function rowDisplayFromStats(_, profile)
    local stats = type(profile) == "table" and profile.stats
    if type(stats) ~= "table" or stats.display == nil then return end
    local mode = stats.display
    stats.display = nil
    if mode ~= "bar" and mode ~= "text" then return end
    if type(profile.bars) ~= "table" then profile.bars = {} end
    -- The active profile already holds the copied default "both"; only another stored value wins.
    local kept = profile.bars.rowDisplay
    if kept == nil or kept == "both" then profile.bars.rowDisplay = mode end
end

--- 2 -> 3 (feedback round 2, FB-12): one broker feed. A stored `broker.templates.all` becomes
--- `broker.template`, and the whole `broker.templates` table goes with the Professions, Weapons and
--- Stats feeds' templates. A `broker.template` already stored as something other than the default
--- wins (the active profile carries the copied default, which is not a choice). A profile with no
--- `broker.templates` passes through. `broker.presets.*` were session-only and never stored.
local function oneBrokerFeed(_, profile)
    local broker = type(profile) == "table" and profile.broker
    if type(broker) ~= "table" or broker.templates == nil then return end
    local old = type(broker.templates) == "table" and broker.templates.all or nil
    broker.templates = nil
    if type(old) ~= "string" then return end
    local kept = broker.template
    if kept == nil or kept == NS.defaults.profile.broker.template then broker.template = old end
end

-- Each step is idempotent against a fresh default profile. A profile-scoped step sets
-- `perProfile = true` and runs for every stored profile.
local STEPS = {
    { to = 1, run = function() end },   -- 0 -> 1: pre-versioning, a no-op
    { to = 2, run = rowDisplayFromStats, perProfile = true },
    { to = 3, run = oneBrokerFeed, perProfile = true },
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
