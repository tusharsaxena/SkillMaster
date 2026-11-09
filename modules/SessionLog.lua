local _, NS = ...
-- modules/SessionLog.lua — the per-character log of skill-ups (design §5.2, plan Task 4.3): a ring of
-- the newest 500 { t, key, old, new, zone } in db.char.log, this session's gains, the session rate
-- (points an hour over a sliding window) and the per-skill ETA to the cap.
--
-- Hears SKILL_UP on its own tracked bus target, so the stand-down takes it down with every other
-- subscription. A session starts at login (this file's load) and again on "New session".

NS.SessionLog = {}
local SL = NS.SessionLog

SL.CAP = 500        -- the default of journal.keep: entries kept per character (oldest dropped first)

--- The entries kept per character: the Journal page's row (journal.keep), else SL.CAP.
function SL.Cap()
    local n = NS.GetSetting and NS.db and tonumber(NS.GetSetting("journal.keep"))
    return n and n >= 1 and math.floor(n) or SL.CAP
end
SL.WINDOW = 3600    -- seconds: Rate's default sliding window

local sessionStart = time()

local function store()
    local c = NS.db and NS.db.char
    if not c then return nil end
    if type(c.log) ~= "table" then c.log = {} end
    return c.log
end

--- Record one skill-up. Answers the stored entry, or nil for a malformed one.
--- @param key string the skill's key   @param old number   @param new number
--- @param t number|nil epoch seconds (now)   @param zone string|nil where it happened
function SL:Add(key, old, new, t, zone)
    if type(key) ~= "string" or type(new) ~= "number" then return nil end
    local log = store()
    if not log then return nil end
    local e = { t = tonumber(t) or time(), key = key, old = tonumber(old) or (new - 1), new = new, zone = zone }
    log[#log + 1] = e
    local cap = SL.Cap()
    while #log > cap do table.remove(log, 1) end
    return e
end

--- Every stored entry, oldest first (the live table: read, never write).
function SL:Entries() return store() or {} end

function SL:Clear()
    local log = store()
    if log then for i = #log, 1, -1 do log[i] = nil end end
end

function SL:SessionStart() return sessionStart end

--- Start a new session at `t` (now): gains, rate and ETA count from here.
function SL:NewSession(t) sessionStart = tonumber(t) or time() end

--- This session's entries, oldest first, optionally for one key.
local function sessionEntries(key)
    local out, log = {}, SL:Entries()
    for _, e in ipairs(log) do
        if e.t >= sessionStart and (key == nil or e.key == key) then out[#out + 1] = e end
    end
    return out
end

local function points(e) return math.max((e.new or 0) - (e.old or 0), 0) end

--- @return number the points gained this session, table points per key
function SL:Gains()
    local total, byKey = 0, {}
    for _, e in ipairs(sessionEntries()) do
        local p = points(e)
        total = total + p
        byKey[e.key] = (byKey[e.key] or 0) + p
    end
    return total, byKey
end

--- The points `key` gained this session (0 with none).
function SL:GainsFor(key)
    local _, byKey = SL:Gains()
    return byKey[key] or 0
end

--- Points an hour over the last `windowSec` (3600) of this session; 0 before any time has passed.
--- With `key`, that skill's points only (a row tooltip's "This session" line).
--- @param now number|nil epoch seconds, for the suites
function SL:Rate(windowSec, now, key)
    now = tonumber(now) or time()
    local span = math.min(tonumber(windowSec) or SL.WINDOW, now - sessionStart)
    if span <= 0 then return 0 end
    local from, sum = now - span, 0
    for _, e in ipairs(sessionEntries(key)) do
        if e.t >= from then sum = sum + points(e) end
    end
    return sum / span * 3600
end

--- Seconds until `key` reaches its max at the rate its own gains this session set, nil with fewer
--- than two gains (one gain is no interval) or without a model entry; 0 at the cap.
function SL:ETA(key)
    local list = sessionEntries(key)
    if #list < 2 then return nil end
    local entry = NS.SkillData and NS.SkillData:Get(key)
    if not (entry and entry.max) then return nil end
    local remaining = entry.max - entry.rank
    if remaining <= 0 then return 0 end
    local gained = 0
    for i = 2, #list do gained = gained + points(list[i]) end
    local elapsed = list[#list].t - list[1].t
    if gained <= 0 or elapsed <= 0 then return nil end
    return remaining / (gained / elapsed)
end

-- The one subscription: SKILL_UP(key, old, new), stamped with the clock and the zone.
local function onSkillUp(_, key, old, new)
    SL:Add(key, old, new, time(), GetZoneText and GetZoneText() or nil)
end

SL.events = NS.NewBusTarget()
if SL.events then SL.events:RegisterMessage(NS.MSG.SKILL_UP, onSkillUp) end
