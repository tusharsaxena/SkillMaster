local _, NS = ...
-- modules/SessionLog.lua — the per-character log of skill-ups (design §5.2, plan Task 4.3): a ring of
-- the newest 500 { t, key, old, new, zone } in db.char.log, this session's gains, the session rate
-- (points an hour over a sliding window) and the per-skill ETA to the cap. Since R5-SM-10 every reputation
-- and currency change is a row of its own too ({ t, kind, key, name, old, new, zone[, oldReaction,
-- newReaction] }), and the ring keeps journal.keep of each sort: the skill-ups, and the changes besides, so a
-- reputation grind never pushes a skill-up out.
--
-- Hears SKILL_UP on its own tracked bus target, so the stand-down takes it down with every other
-- subscription. A session starts at login (this file's load) and again on "New session".
--
-- T5.2: one constructor makes the live log and the read-only views test mode shows
-- (`SL.View(entries, start, entryOf)`, modules/Preview.lua). `SL:Override(list, start)` points the
-- live log at a session-only list while a simulation runs, so a simulated skill-up never reaches
-- SavedVariables (preview-mode, H4); `SL:Override(nil)` puts db.char.log and the session back.

local CAP = 500        -- the default of journal.keep: entries kept per character (oldest dropped first)

--- The entries kept per character: the Journal page's row (journal.keep), else CAP.
local function cap()
    local n = NS.GetSetting and NS.db and tonumber(NS.GetSetting("journal.keep"))
    return n and n >= 1 and math.floor(n) or CAP
end
local WINDOW = 3600    -- seconds: Rate's default sliding window

-- A skill-up's points; a reputation or currency gain (an entry with a `kind`, SMW-08) is no skill point.
local function points(e)
    if e.kind then return 0 end
    return math.max((e.new or 0) - (e.old or 0), 0)
end

local function liveEntry(key) return NS.SkillData and NS.SkillData:Get(key) end

--- Trim `log` (oldest first) to `keep` skill-ups and `keep` reputation and currency changes (R5-SM-10), the
--- oldest of each sort going first, in place.
local function trimTo(log, keep)
    local skills, changes = 0, 0
    for _, e in ipairs(log) do
        if e.kind then changes = changes + 1 else skills = skills + 1 end
    end
    local dropS, dropC = math.max(skills - keep, 0), math.max(changes - keep, 0)
    if dropS == 0 and dropC == 0 then return end
    local out = {}
    for _, e in ipairs(log) do
        if e.kind and dropC > 0 then
            dropC = dropC - 1
        elseif not e.kind and dropS > 0 then
            dropS = dropS - 1
        else
            out[#out + 1] = e
        end
    end
    for i = #log, 1, -1 do log[i] = out[i] end
end

--- One log over `store()` (the list, or nil before the store exists), its session starting at
--- `start`; `entryOf(key)` answers the model entry the ETA reads.
local function newLog(store, start, entryOf)
    local SL = { CAP = CAP, WINDOW = WINDOW, Cap = cap }
    local sessionStart = start
    -- What the log held when this session first wrote to it: a profile switch to a lower
    -- journal.keep never trims below it (review F-015); only the setting's own write does (Trim).
    local floor

    --- Record one skill-up. Answers the stored entry, or nil for a malformed one.
    --- @param key string the skill's key   @param old number   @param new number
    --- @param t number|nil epoch seconds (now)   @param zone string|nil where it happened
    function SL:Add(key, old, new, t, zone)
        if type(key) ~= "string" or type(new) ~= "number" then return nil end
        local log = store()
        if not log then return nil end
        local e = { t = tonumber(t) or time(), key = key, old = tonumber(old) or (new - 1), new = new, zone = zone }
        floor = floor or #log
        log[#log + 1] = e
        trimTo(log, math.max(cap(), floor))
        return e
    end

    --- Record a reputation's or currency's change (SMW-08, SMW-09): `kind` its row kind, `key` its id, `name`
    --- what the Log shows. Each change is a row of its own (R5-SM-10, the owner's round 5: the Journal tracks
    --- every gain and loss), so the Log reads each kill's reputation and each currency spent, in time order. A
    --- reputation change that moved the standing keeps both standings (`oldReaction`, `newReaction`, 1..8); one
    --- that did not keeps neither. Answers the entry.
    function SL:AddChange(kind, key, name, old, new, t, zone, oldReaction, newReaction)
        if type(kind) ~= "string" or type(key) ~= "string" or type(new) ~= "number" then return nil end
        local log = store()
        if not log then return nil end
        local e = { t = tonumber(t) or time(), kind = kind, key = key, name = name, old = tonumber(old) or new,
                    new = new, zone = zone }
        local fromR, toR = tonumber(oldReaction), tonumber(newReaction)
        if fromR and toR and fromR ~= toR then e.oldReaction, e.newReaction = fromR, toR end
        floor = floor or #log
        log[#log + 1] = e
        trimTo(log, math.max(cap(), floor))
        return e
    end

    --- Trim to the newest `n` (the journal.keep row's onChange: the player lowered it).
    function SL:Trim(n)
        local log = store()
        n = tonumber(n)
        if not (log and n) then return end
        trimTo(log, n)
        floor = math.min(floor or #log, #log)
    end

    --- Forget the floor (a profile reload, the suites): the next write takes it again.
    function SL:ResetFloor() floor = nil end

    --- Every stored entry, oldest first (the live table: read, never write).
    function SL:Entries() return store() or {} end

    function SL:Clear()
        local log = store()
        if log then for i = #log, 1, -1 do log[i] = nil end end
    end

    function SL:SessionStart() return sessionStart end

    --- Start a new session at `t` (now): gains, rate and ETA count from here.
    function SL:NewSession(t) sessionStart = tonumber(t) or time() end

    --- The entries from `from` (epoch seconds; nil is this session's start), oldest first,
    --- optionally for one key. The Journal's range picker reads through it (FB-32).
    local function entriesSince(from, key)
        from = tonumber(from) or sessionStart
        local out = {}
        for _, e in ipairs(SL:Entries()) do
            if e.t >= from and (key == nil or e.key == key) then out[#out + 1] = e end
        end
        return out
    end
    local function sessionEntries(key) return entriesSince(nil, key) end

    --- Every entry since `from` (nil: this session's start), oldest first, optionally for one key.
    function SL:Since(from, key) return entriesSince(from, key) end

    --- The change of `kind`'s `key` this session (new minus old of its one entry), 0 with none.
    function SL:KindGainsFor(kind, key)
        local sum = 0
        for _, e in ipairs(entriesSince(nil, key)) do
            if e.kind == kind then sum = sum + ((e.new or 0) - (e.old or 0)) end
        end
        return sum
    end

    --- @param from number|nil epoch seconds the count starts at; nil is this session's start
    --- @return number the points gained this session (or since `from`), table points per key
    function SL:Gains(from)
        local total, byKey = 0, {}
        for _, e in ipairs(entriesSince(from)) do
            if not e.kind then
                local p = points(e)
                total = total + p
                byKey[e.key] = (byKey[e.key] or 0) + p
            end
        end
        return total, byKey
    end

    --- The points `key` gained this session (0 with none).
    function SL:GainsFor(key)
        local _, byKey = SL:Gains()
        return byKey[key] or 0
    end

    --- Points an hour over the last `windowSec` (3600) of this session; 0 before any time has
    --- passed. With `key`, that skill's points only (a row tooltip's "This session" line).
    --- @param now number|nil epoch seconds, for the suites
    function SL:Rate(windowSec, now, key)
        now = tonumber(now) or time()
        local span = math.min(tonumber(windowSec) or WINDOW, now - sessionStart)
        if span <= 0 then return 0 end
        local from, sum = now - span, 0
        for _, e in ipairs(sessionEntries(key)) do
            if e.t >= from then sum = sum + points(e) end
        end
        return sum / span * 3600
    end

    --- Seconds until `key` reaches its max at the rate its own gains this session (or since
    --- `from`) set, nil with fewer than two gains (one gain is no interval) or without a model
    --- entry; 0 at the cap.
    function SL:ETA(key, from)
        local list = entriesSince(from, key)
        if #list < 2 then return nil end
        local entry = entryOf(key)
        if not (entry and entry.max) then return nil end
        local remaining = entry.max - entry.rank
        if remaining <= 0 then return 0 end
        local gained = 0
        for i = 2, #list do gained = gained + points(list[i]) end
        local elapsed = list[#list].t - list[1].t
        if gained <= 0 or elapsed <= 0 then return nil end
        return remaining / (gained / elapsed)
    end

    return SL
end

-- ── the live log ─────────────────────────────────────────────────────────────────────────────

local override   -- the session-only list a running simulation logs into, or nil

local function dbStore()
    if override then return override end
    local c = NS.db and NS.db.char
    if not c then return nil end
    if type(c.log) ~= "table" then c.log = {} end
    return c.log
end

NS.SessionLog = newLog(dbStore, time(), liveEntry)
local SL = NS.SessionLog

--- A read-only view over `entries` (oldest first) with its session from `start`, the ETA reading
--- `entryOf(key)`: test mode's sample log.
function SL.View(entries, start, entryOf)
    return newLog(function() return entries end, tonumber(start) or time(), entryOf or liveEntry)
end

--- Log into `list` (a session-only table) from `start`, or, with nil, back into db.char.log with
--- the session that was running. Answers whether an override is now in place.
local saved
function SL:Override(list, start)
    if type(list) == "table" then
        if not override then saved = SL:SessionStart() end
        override = list
        SL:NewSession(tonumber(start) or time())
        return true
    end
    if override then
        override = nil
        if saved then SL:NewSession(saved) end
        saved = nil
    end
    return false
end

function SL:IsOverridden() return override ~= nil end

-- The one subscription: SKILL_UP(key, old, new), stamped with the clock and the zone.
local function onSkillUp(_, key, old, new)
    SL:Add(key, old, new, time(), GetZoneText and GetZoneText() or nil)
end

-- A faction's standing moved (SMW-08): REP_CHANGED(key, old, new, name, oldReaction, newReaction).
local function onRepChanged(_, key, old, new, name, oldReaction, newReaction)
    SL:AddChange("reputation", key, name, old, new, time(), GetZoneText and GetZoneText() or nil, oldReaction,
        newReaction)
end

-- A currency's amount moved (SMW-09): CURRENCY_CHANGED(key, old, new, name).
local function onCurrencyChanged(_, key, old, new, name)
    SL:AddChange("currency", key, name, old, new, time(), GetZoneText and GetZoneText() or nil)
end

SL.events = NS.NewBusTarget()
if SL.events then
    SL.events:RegisterMessage(NS.MSG.SKILL_UP, onSkillUp)
    SL.events:RegisterMessage(NS.MSG.REP_CHANGED, onRepChanged)
    SL.events:RegisterMessage(NS.MSG.CURRENCY_CHANGED, onCurrencyChanged)
end
