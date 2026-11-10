local _, NS = ...
-- core/UnitEventsSetup.lua — NS.UnitEvents: the one private frame that hears the player's UNIT_*
-- events through RegisterUnitEvent (events-frames-taint-§1's unit-filter carve-out), so a raid's
-- auras and stats are filtered by the client and never dispatched into Lua (review F-004).
--
-- NS.UnitEvents.Register(event, handler)  record a handler(event, unit, ...) at load
-- NS.UnitEvents.StandUp()                 register every recorded event for "player" (NS.RegisterRuntime)
-- NS.UnitEvents.StandDown()               UnregisterAllEvents (NS.StandDown)
-- NS.UnitEvents.Frame()                   the frame, nil before the first stand-up
--
-- The frame does RegisterUnitEvent and one dispatching OnEvent, nothing else; it stands down and up
-- under the addon's one latch (slash-commands-§7), never a second teardown path.

local UE = { handlers = {}, order = {} }
NS.UnitEvents = UE
local frame

function UE.Register(event, handler)
    if not UE.handlers[event] then UE.order[#UE.order + 1] = event end
    UE.handlers[event] = handler
end

local function onEvent(_, event, ...)
    local h = UE.handlers[event]
    if h then h(event, ...) end
end

function UE.StandUp()
    if not frame then
        frame = CreateFrame("Frame")
        frame:SetScript("OnEvent", onEvent)
    end
    for _, event in ipairs(UE.order) do
        NS.SafeRegisterUnitEvent(frame, event, NS.rejectedEvents, "player")
    end
end

function UE.StandDown()
    if frame then frame:UnregisterAllEvents() end
end

function UE.Frame() return frame end
