local _, NS = ...
-- modules/RepData.lua — the reputations model (GitHub issue #6; item SMW-08 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md, the spec's "Reputations (#6)"), a sibling of
-- modules/SkillData.lua and modules/StatData.lua. It reads the client's faction list (NS.Compat, C_Reputation on
-- WoW Forever) into the character panel's own grouping and announces REPS_UPDATED; a standing that moved
-- between two reads is REP_CHANGED (the Journal's session gains).
--
-- model = { order = { entries, the panel's order }, byKey = { [key] = entry }, complete, built }
-- entry = { key (the factionID as a string), factionID, name, family, depth (0 a top header such as Alliance or
--   Other, 1 a sub-header such as Steamwheedle Cartel or a faction under a top header, 2 a faction under a
--   sub-header), header, nodeKey (a header's fold key), hasBar (a faction, or a sub-header with its own bar),
--   reaction (1..8), standing (the client's FACTION_STANDING_LABELn), value / max (the bar, from the current
--   threshold to the next), current (currentStanding), exalted, atWar, description, watched }
--
-- THE COLLAPSE TRAP (docs/forever-quirks.md): the list answers only the rows under open headers, and its headers
-- are the Reputation tab's. The FIRST build is a full read through modules/SharedList.lua (open, read, close
-- again bottom up; out of combat, never while ReputationFrame shows, a re-entry latch). Every later read goes by
-- id (GetFactionDataByID, the listed rows first), which touches no state; a listed faction the model does not
-- know (a new one) asks for a full read again. A read the moment refused (combat, the panel up) is partial and
-- retried when combat ends or the panel hides. This module never folds: the window's folds are its own
-- (modules/Tree.lua).
--
-- Events (a tracked bus target): UPDATE_FACTION (coalesced, RD.DEBOUNCE), PLAYER_ENTERING_WORLD (the first
-- build) and PLAYER_REGEN_ENABLED (a partial read's retry). Never a poll.
--
-- NS.RepData:Model() / :Get(key) / .Build(rows) (pure) / :Read() / :Refresh() / :Request(full) / :Reset() /
-- .BarValues(e) / .ValueText(e)

NS.RepData = {}
local RD = NS.RepData
local L = NS.L

RD.FAMILY, RD.KIND = "reputations", "reputation"
RD.DEBOUNCE = 0.2      -- seconds: one read per burst of UPDATE_FACTION
RD.MAX_REACTION = 8    -- Exalted (MAX_REPUTATION_REACTION): drawn as a full bar
RD.EVENTS = { "UPDATE_FACTION", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }

local function emptyModel() return { order = {}, byKey = {}, complete = false, built = false } end

local model = emptyModel()
local timer, wantFull, panelHooked

--- The model, or nil before the first read and while the list is empty (every surface then shows its empty line).
function RD:Model() return (model.built and #model.order > 0) and model or nil end
function RD:Get(key) return model.byKey[tostring(key)] end

--- Back to the before-the-first-read state (the suites).
function RD:Reset()
    model = emptyModel()
    timer, wantFull = nil, nil
end

--- Swap the model for `m` (an empty one when nil) and answer the one held: the simulator's start (SMW-11: its
--- world is read afresh) and stop (the live model back). Sends nothing, so no standing reads as moved.
function RD:Adopt(m)
    local old = model
    if timer and NS.addon then NS.addon:CancelTimer(timer) end
    model, timer, wantFull = m or emptyModel(), nil, nil
    return old
end

-- ---------------------------------------------------------------------------------------------
-- Building: the client's FactionData rows, in the panel's order, to entries
-- ---------------------------------------------------------------------------------------------

--- The bar of FactionData `d`: value and max from the current threshold to the next (Exalted full).
local function barOf(d)
    local reaction = tonumber(d.reaction) or 0
    local lo, hi = tonumber(d.currentReactionThreshold) or 0, tonumber(d.nextReactionThreshold) or 0
    if reaction >= RD.MAX_REACTION or hi <= lo then return 1, 1, true end
    local v = (tonumber(d.currentStanding) or lo) - lo
    return math.max(0, math.min(v, hi - lo)), hi - lo, false
end

--- One entry from FactionData `d` at `depth`.
function RD.Entry(d, depth)
    local id = tonumber(d.factionID)
    local header = d.isHeader == true
    local value, max, exalted = barOf(d)
    return {
        key = tostring(id or d.name), factionID = id, name = d.name or "", family = RD.FAMILY,
        depth = depth or 0, header = header, nodeKey = header and NS.Tree.NodeKey(RD.FAMILY, d) or nil,
        hasBar = not header or d.isHeaderWithRep == true,
        reaction = tonumber(d.reaction), standing = NS.Compat.FactionStandingLabel(d.reaction),
        value = value, max = max, exalted = exalted, current = tonumber(d.currentStanding),
        atWar = d.atWarWith == true, description = d.description, watched = d.isWatched == true,
    }
end

-- The panel's indentation from the two flags (Blizzard's ReputationFrame): a top header (header, not child) opens
-- a group; a sub-header (header, child) sits under it; a child under the sub-header; a plain faction (neither)
-- under the top header, closing the sub-header.
local function depthOf(d, ctx)
    local top = ctx.top and 1 or 0
    if d.isHeader and not d.isChild then
        ctx.top, ctx.sub = true, false
        return 0
    end
    if d.isHeader then
        ctx.sub = true
        return top
    end
    if d.isChild and ctx.sub then return top + 1 end
    ctx.sub = false
    return top
end

--- A model from FactionData rows in the panel's order (pure: the live read and the suites both build so).
function RD.Build(rows, complete)
    local m, ctx = emptyModel(), {}
    for _, d in ipairs(rows or {}) do
        if type(d) == "table" and (d.factionID or d.name) then
            local e = RD.Entry(d, depthOf(d, ctx))
            if not m.byKey[e.key] then
                m.order[#m.order + 1] = e
                m.byKey[e.key] = e
            end
        end
    end
    m.complete, m.built = complete ~= false, true
    return m
end

-- ---------------------------------------------------------------------------------------------
-- Reading: the first build in full, every later one by id
-- ---------------------------------------------------------------------------------------------

local function panel() return ReputationFrame end

RD.LIST = {
    name = "reputations",
    count = function() return NS.Compat.NumFactions() end,
    row = function(i) return NS.Compat.FactionDataByIndex(i) end,
    isClosed = function(r) return r.isHeader == true and r.isCollapsed == true end,
    key = function(r) return tostring(r.factionID or r.name) end,
    toggle = function(i, open) return NS.Compat.SetFactionHeaderExpanded(i, open) end,
    canToggle = function() return NS.Compat.CanToggleFactionHeaders() end,
    panel = panel,
}

-- The standings that moved since `old`, as REP_CHANGED (a first build announces none).
local function announceChanges(old, new)
    if not (old and old.built) then return end
    for _, e in ipairs(new.order) do
        local was = old.byKey[e.key]
        if was and e.current and was.current and e.current ~= was.current then
            NS.bus:SendMessage(NS.MSG.REP_CHANGED, e.key, was.current, e.current, e.name)
        end
    end
end

local function publish(m)
    local old = model
    model = m
    announceChanges(old, m)
    NS.bus:SendMessage(NS.MSG.REPS_UPDATED, m)
    return m
end

-- The panel is up: retry the full read as it hides (the one hook, made once; event-driven, never a poll).
local function retryOnPanelHide()
    local f = panel()
    if panelHooked or type(f) ~= "table" or type(f.HookScript) ~= "function" then return end
    panelHooked = true
    f:HookScript("OnHide", function()
        if not model.complete then RD:Request(true) end
    end)
end

--- The full read: every header opened, read, closed again (modules/SharedList.lua). Answers the model, or nil
--- while a read already runs.
function RD:Read()
    local rows, complete, why = NS.SharedList.Read(RD.LIST)
    if not rows then return nil end
    if why == "panel shown" then retryOnPanelHide() end
    NS.Debug("Reps", "full read: %d rows%s", #rows, complete and "" or (" (partial: " .. tostring(why) .. ")"))
    return publish(RD.Build(rows, complete))
end

-- The listed rows by id: the freshest answer for a faction under an open header, and whether any is new.
local function listed()
    local byId, unknown = {}, false
    for i = 1, NS.Compat.NumFactions() do
        local d = NS.Compat.FactionDataByIndex(i)
        local key = d and tostring(d.factionID or d.name)
        if key then
            byId[key] = d
            if not model.byKey[key] then unknown = true end
        end
    end
    return byId, unknown
end

--- The read after the first: each known faction again by id (the listed row first, then GetFactionDataByID,
--- else its last values), in the model's order, touching no list state. A listed faction the model does not
--- know asks for a full read instead.
function RD:Refresh()
    if not model.built then return RD:Read() end
    local byId, unknown = listed()
    if unknown then return RD:Read() end
    local m = emptyModel()
    for _, e in ipairs(model.order) do
        local d = byId[e.key] or (e.factionID and NS.Compat.FactionDataByID(e.factionID))
        local fresh = d and RD.Entry(d, e.depth) or e
        m.order[#m.order + 1] = fresh
        m.byKey[fresh.key] = fresh
    end
    m.complete, m.built = model.complete, true
    return publish(m)
end

local function pendingTimer()
    return timer ~= nil and NS.addon:TimeLeft(timer) > 0
end

local function flush()
    timer = nil
    local full = wantFull or not model.built or not model.complete
    wantFull = nil
    if full and NS.SharedList.Blocked(RD.LIST) == nil then return RD:Read() end
    return RD:Refresh()
end

--- One read RD.DEBOUNCE from now (a burst of events reads once); `full` asks for the full read.
function RD:Request(full)
    if full then wantFull = true end
    if pendingTimer() then return end
    timer = NS.addon:ScheduleTimer(flush, RD.DEBOUNCE)
end

local HANDLERS = {
    -- A header toggle of the read's own makes the client send this: the latch says so (SharedList.Busy).
    UPDATE_FACTION = function()
        if NS.SharedList.Busy(RD.LIST.name) then return end
        RD:Request(false)
    end,
    PLAYER_ENTERING_WORLD = function() RD:Request(true) end,
    -- Combat refused the full read: it runs as combat ends.
    PLAYER_REGEN_ENABLED = function() if model.built and not model.complete then RD:Request(true) end end,
}

--- Deliver one game event to its handler (the suites, the simulator). Answers how many ran.
function RD.OnEvent(event, ...)
    if NS.IsStoodDown() then return 0 end
    local fn = HANDLERS[event]
    if not fn then return 0 end
    fn(event, ...)
    return 1
end

RD.events = NS.NewBusTarget()
if RD.events then
    NS.SafeRegisterEvents(RD.events, RD.EVENTS, function(event, ...) RD.OnEvent(event, ...) end, NS.rejectedEvents)
end

-- ---------------------------------------------------------------------------------------------
-- The row kind: what a reputation row draws and says (modules/Tree.lua's kind spec)
-- ---------------------------------------------------------------------------------------------

--- "3,672 / 12,000"; "Exalted" alone at the top.
function RD.ValueText(e)
    if not e.hasBar then return "" end
    local standing = e.standing or ""
    if e.exalted then return standing end
    return L["%s %s / %s"]:format(standing, NS.Tree.Number(e.value), NS.Tree.Number(e.max))
end

local function color(e)
    return NS.Compat.FactionBarColor(e.reaction) or NS.SkinColor("sm.barFill")
end

--- The bar's values (the shared bar widget's shape), or nil for a header with no bar of its own.
function RD.BarValues(e)
    if not e.hasBar then return nil end
    return { value = e.value or 0, max = math.max(e.max or 1, 1), text = RD.ValueText(e), color = color(e) }
end

local function lines(e)
    local out = { { left = e.name, tone = "heading" } }
    if e.hasBar then
        out[#out + 1] = { left = L["Standing"], right = e.standing or "", tone = "muted", rightTone = "body" }
        if not e.exalted then
            out[#out + 1] = { left = L["Progress"], right = ("%s / %s"):format(NS.Tree.Number(e.value),
                NS.Tree.Number(e.max)), tone = "muted", rightTone = "body" }
        end
        out[#out + 1] = { bar = true }
    end
    if e.atWar then out[#out + 1] = { left = L["At war"], tone = "bad" } end
    if type(e.description) == "string" and e.description ~= "" then
        out[#out + 1] = { left = e.description, tone = "muted" }
    end
    local log = NS.SessionLog
    local g = log and log.KindGainsFor and log:KindGainsFor(RD.KIND, e.key) or 0
    if g ~= 0 then
        out[#out + 1] = { left = L["This session"], right = (g > 0 and "+" or "") .. NS.Tree.Number(g),
                          tone = "muted", rightTone = g > 0 and "good" or "bad" }
    end
    return out
end

NS.Tree.RegisterKind(RD.KIND, {
    family = RD.FAMILY,
    values = RD.BarValues,
    valueText = RD.ValueText,
    lines = lines,
    pinText = function(e) return ("%s %s"):format(e.name, RD.ValueText(e)) end,
    linkText = function(e) return ("[%s: %s]"):format(e.name, RD.ValueText(e)) end,
})
