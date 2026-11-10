local addonName, NS = ...
-- core/Bus.lua — every message name, declared once (architecture-§4), and the bus record that
-- stands subscriptions down and back up with the addon (LibKa0s-Bus-1.0).
--
-- A misspelled literal is a message nobody receives and nothing goes red; through these constants
-- the same typo is a nil name, and the Catalog makes a publisher's typo raise too.

local Bus = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
    -- Degrade, never error: a target stub with the library table's surface. It keeps its targets,
    -- so the stand-down still takes every event and message down (slash-commands-§7, review
    -- F-010); the degraded load re-registers nothing on stand-up (a /reload brings it back).
    Bus = {
        New = function(_, d)
            local targets = {}
            return {
                name = d and d.name,
                NewTarget = function()
                    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
                    if not AceEvent then return nil end
                    local t = {}
                    AceEvent:Embed(t)
                    targets[#targets + 1] = t
                    return t
                end,
                StandDown = function()
                    for _, t in ipairs(targets) do
                        t:UnregisterAllEvents()
                        t:UnregisterAllMessages()
                    end
                    return #targets
                end,
                StandUp   = function() return 0, {} end,
            }
        end,
        Catalog = function(_, messages) return messages end,
    }
end
NS.__busLib = Bus   -- the surface-parity case reads the stub through this

-- The one publisher target (SendMessage fans out to every receiver).
NS.bus = NS.bus or {}
LibStub("AceEvent-3.0"):Embed(NS.bus)

-- Every consumer registers on its OWN target from here (CallbackHandler keys by message+target).
NS.busRecord = Bus:New{ name = addonName, isDown = function() return NS.IsStoodDown() end }
function NS.NewBusTarget() return NS.busRecord:NewTarget() end
function NS.BusStandDown() return NS.busRecord:StandDown() end
function NS.BusStandUp()
    local replayed, rejected = NS.busRecord:StandUp()
    if #rejected > 0 then NS.Debug("Bus", "rejected on stand-up: %s", table.concat(rejected, ", ")) end
    return replayed
end

-- <Event> is PascalCase and names what happened (naming-cheatsheet). Senders and payloads:
NS.MSG = Bus.Catalog(addonName, {
    -- modules/SkillData.lua (T2.1). Payload: the skills model.
    SKILLS_UPDATED  = "Ka0s_SkillMaster_SkillsUpdated",
    -- modules/SkillData.lua (T2.1). Payload: key, old rank, new rank.
    SKILL_UP        = "Ka0s_SkillMaster_SkillUp",
    -- modules/StatData.lua (T2.3). Payload: the stats model.
    STATS_UPDATED   = "Ka0s_SkillMaster_StatsUpdated",
    -- modules/Bonuses.lua (T2.2). No payload; readers ask NS.Bonuses:Breakdown(key).
    BONUSES_UPDATED = "Ka0s_SkillMaster_BonusesUpdated",
    -- modules/Blocks.lua (T3.2), after a dock, detach, reorder or a layout setting. No payload.
    LAYOUT_CHANGED  = "Ka0s_SkillMaster_LayoutChanged",
    -- the simulator (T5.2). Payload: the step's name.
    SIM_TICK        = "Ka0s_SkillMaster_SimTicked",
})
