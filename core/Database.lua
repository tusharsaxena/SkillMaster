local addonName, NS = ...
-- core/Database.lua — the AceDB store and the schemaVersion migration runner (savedvariables-§1).
-- The defaults tree is defaults/Profile.lua's NS.defaults, read at InitDB time.

-- The runner's target: the highest step's `to`.
NS.SCHEMA_VERSION = 10

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

--- 3 -> 4 (feedback round 2, the owner's rulings): no Detached bar height and no rank tier ticks. A
--- detached block's bar and row take the main window's Bar height and Row height, so a stored
--- `bars.compactHeight` goes; the ticks gave way to Rank tier colors (`bars.tierColors`, a new key
--- with its own default), so a stored `bars.ticks` goes. Nothing carries over.
local function retiredBarKeys(_, profile)
    local bars = type(profile) == "table" and profile.bars
    if type(bars) ~= "table" then return end
    bars.compactHeight = nil
    bars.ticks = nil
end

--- 4 -> 5 (owner feedback round 3, FB-33): the Alts sub-tabs are the main window's blocks, so a
--- stored `journal.filter` of "professions" or "weapons" names no sub-tab any more: it becomes the
--- block it opened on ("primary", "weapon"). "other" is a block id already and stays.
local LEGACY_FILTER = { professions = "primary", weapons = "weapon" }
local function journalFilterToBlock(_, profile)
    local j = type(profile) == "table" and profile.journal
    if type(j) ~= "table" then return end
    j.filter = LEGACY_FILTER[j.filter] or j.filter
end

--- 5 -> 6 (owner feedback round 5, R5-6): merged detached windows, `layout.groups` (a new key with
--- its own default {}). Nothing carries over; a stored `layout.groups` that is not a table goes (the
--- default answers), and a stored one is normalized against the profile's own blocks: a member that
--- is no detached block of this profile, a block in two groups, an empty column and a group of fewer
--- than two blocks go (modules/Groups.lua's NS.Groups.Model.Normalize, loaded by the time it runs).
local function groupsNormalized(_, profile)
    local layout = type(profile) == "table" and profile.layout
    if type(layout) ~= "table" or layout.groups == nil then return end
    if type(layout.groups) ~= "table" then layout.groups = nil return end
    local blocks = type(layout.blocks) == "table" and layout.blocks or {}
    NS.Groups.Model.Normalize(layout.groups, function(id)
        return NS.BlockDefs[id] ~= nil and type(blocks[id]) == "table" and blocks[id].docked == false
    end)
end

--- 6 -> 7 (owner feedback round 6, R6-4): the one Threshold markers switch becomes two, the window's
--- (`bars.markersWindow`, default off) and the row tooltip's (`bars.markersTooltip`, default on). A
--- stored `bars.markers = false` is the player's choice (AceDB strips the old default true), so it
--- carries to both; any other stored value goes and the new defaults answer.
local function markersSplit(_, profile)
    local bars = type(profile) == "table" and profile.bars
    if type(bars) ~= "table" or bars.markers == nil then return end
    if bars.markers == false then bars.markersWindow, bars.markersTooltip = false, false end
    bars.markers = nil
end

--- 7 -> 8 (owner feedback round 6, R6-10): the LDB tooltip's style, `tooltips.ldb.style`, a new key
--- whose default "window" is the main window's look, for new profiles only (owner: "as a default
--- setting for new profiles, can be customized later"). Every profile an earlier install stored keeps
--- the look it had: "classic", unless it already holds a style. An empty stored table is such a
--- profile too (AceDB keeps a never-customized profile as {}, and the step runs at OnInitialize,
--- before any new profile exists). Only a fresh install (`from` 0: no stamp was ever stored) passes
--- through, so its profiles start on the new look.
local function classicTooltipKept(_, profile, from)
    if (from or 0) == 0 or type(profile) ~= "table" then return end
    if type(profile.tooltips) ~= "table" then profile.tooltips = {} end
    local t = profile.tooltips
    if type(t.ldb) ~= "table" then t.ldb = {} end
    -- rawget: the active profile may already wear AceDB's defaults, whose "window" is no choice.
    if rawget(t.ldb, "style") == nil then t.ldb.style = "classic" end
end

--- 8 -> 9 (owner feedback round 6, R6-9): the stat blocks moved to their own feed, Skill Master Stats,
--- with a switch per stat block (`broker.tooltip.sections.stats_*`, new keys defaulting on). The old
--- Stats switch, `broker.tooltip.sections.stats`, names no section any more: a stored one goes.
local function statsSectionRetired(_, profile)
    local b = type(profile) == "table" and profile.broker
    local t = type(b) == "table" and b.tooltip
    local sections = type(t) == "table" and t.sections
    if type(sections) == "table" then sections.stats = nil end
end

--- 9 -> 10 (owner feedback round 6, review of R6-8): Spell and Defense default to expanded
--- (`layout.blocks.stats_spell/stats_defense.collapsed`, true -> false) for new profiles. AceDB
--- stripped the old default true, so a profile stored before R6-8 holds no value and would open both
--- blocks on upgrade: it is written the old true. A stored value is the player's choice and stays. A
--- fresh install (`from` 0) and a build already on the new default (`from` 7 or later: R6-8 landed
--- before step 7) pass through.
local OLD_COLLAPSED = { "stats_spell", "stats_defense" }
local function statsCollapseKept(_, profile, from)
    from = from or 0
    if from == 0 or from >= 7 or type(profile) ~= "table" then return end
    if type(profile.layout) ~= "table" then profile.layout = {} end
    if type(profile.layout.blocks) ~= "table" then profile.layout.blocks = {} end
    local blocks = profile.layout.blocks
    for _, id in ipairs(OLD_COLLAPSED) do
        if type(blocks[id]) ~= "table" then blocks[id] = {} end
        -- rawget: the active profile may already wear AceDB's defaults, whose false is no choice.
        if rawget(blocks[id], "collapsed") == nil then blocks[id].collapsed = true end
    end
end

-- Each step is idempotent against a fresh default profile. A profile-scoped step sets
-- `perProfile = true` and runs for every stored profile. A step is handed (sv, profile, from): `from`
-- is the stamp the run started at (0 on a fresh install).
local STEPS = {
    { to = 1, run = function() end },   -- 0 -> 1: pre-versioning, a no-op
    { to = 2, run = rowDisplayFromStats, perProfile = true },
    { to = 3, run = oneBrokerFeed, perProfile = true },
    { to = 4, run = retiredBarKeys, perProfile = true },
    { to = 5, run = journalFilterToBlock, perProfile = true },
    { to = 6, run = groupsNormalized, perProfile = true },
    { to = 7, run = markersSplit, perProfile = true },
    { to = 8, run = classicTooltipKept, perProfile = true },
    { to = 9, run = statsSectionRetired, perProfile = true },
    { to = 10, run = statsCollapseKept, perProfile = true },
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
                for _, profile in pairs(sv and sv.profiles or {}) do step.run(sv, profile, from) end
            else
                step.run(sv, nil, from)
            end
            g.schemaVersion = step.to   -- the runner owns the stamp; reached only if the step returned
        end
    end
    if from ~= g.schemaVersion then NS.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion) end
end
