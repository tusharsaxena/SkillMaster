local _, NS = ...
-- modules/Alts.lua — every character's skills, snapshotted into db.global.characters (design §5.2,
-- §7, plan Task 4.3): on SKILLS_UPDATED (debounced) and at PLAYER_LOGOUT.
--
-- record = { name, class, className, race, level, faction, updated, skills = { [key] = { name,
--   category, rank, max } } }, learned rows only.
-- THE KEY (forever-quirks-§4): "<realm>-<name>" from AceDB 40's db.keys, which is the ruleset
-- ("PvP") and the character's WHOLE two-word name ("Traxex Silentshot") on Forever. The store never
-- derives them again: UnitName's second return is the surname there, not a realm.
-- A.View(list): a read-only stand-in with List / Forget over `list` (test mode's sample alts).

NS.Alts = {}
local A = NS.Alts

A.DEBOUNCE = 2   -- seconds: one snapshot per burst of skill passes

local function store()
    local g = NS.db and NS.db.global
    if not g then return nil end
    if type(g.characters) ~= "table" then g.characters = {} end
    return g.characters
end

--- This character's store key, or nil before AceDB has its keys.
function A:Key()
    local keys = NS.db and NS.db.keys
    local realm, char = keys and keys.realm, keys and keys.char
    if type(realm) ~= "string" or type(char) ~= "string" or char == "" then return nil end
    return realm .. "-" .. char
end

--- The model's learned rows as the snapshot's skills table; nil when the model has none (a list
--- not loaded yet at login reads empty, and must not wipe the last good snapshot).
local function learnedSkills()
    local m = NS.SkillData and NS.SkillData:Model()
    if not (m and m.byKey) then return nil end
    local out, any = {}, false
    for key, e in pairs(m.byKey) do
        if e.learned then
            out[key] = { name = e.name, category = e.category, rank = e.rank, max = e.max }
            any = true
        end
    end
    return any and out or nil
end

--- Write this character's record now. Answers the record, or nil without a key.
--- @param t number|nil epoch seconds (now)
function A:Snapshot(t)
    -- A simulated character is never snapshotted: nothing a simulation does writes to
    -- SavedVariables (preview-mode, H4).
    if NS.Sim and NS.Sim:IsActive() then return nil end
    local key, chars = A:Key(), store()
    if not (key and chars) then return nil end
    local rec = chars[key] or {}
    local className, classFile = UnitClass("player")
    rec.name = NS.db.keys.char
    rec.class, rec.className = classFile, className
    rec.race = UnitRace and UnitRace("player") or rec.race
    rec.faction = UnitFactionGroup and UnitFactionGroup("player") or rec.faction
    rec.level = UnitLevel("player")
    rec.updated = tonumber(t) or time()
    rec.skills = learnedSkills() or rec.skills or {}
    chars[key] = rec
    return rec
end

--- Every stored character as { key, record, isCurrent }: this character first, then by name.
function A:List()
    local out, current = {}, A:Key()
    for key, rec in pairs(store() or {}) do
        out[#out + 1] = { key = key, record = rec, isCurrent = key == current }
    end
    table.sort(out, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent end
        local an, bn = tostring(a.record.name or a.key), tostring(b.record.name or b.key)
        if an ~= bn then return an < bn end
        return a.key < b.key
    end)
    return out
end

--- A read-only stand-in over `list` ({ key, record, isCurrent }, in display order): test mode's
--- sample alts (modules/Preview.lua). Forget refuses, because there is nothing stored to drop.
function A.View(list)
    return {
        List   = function() return list end,
        Forget = function() return false end,
    }
end

--- Drop a character's record. Answers true when there was one.
function A:Forget(key)
    local chars = store()
    if not (chars and key and chars[key]) then return false end
    chars[key] = nil
    return true
end

-- ── subscriptions ────────────────────────────────────────────────────────────────────────────

local pending

--- One snapshot A.DEBOUNCE from now, unless one is waiting. A stand-down cancels every timer, so a
--- handle that no longer has time left is a dropped one, not a waiting one.
function A:RequestSnapshot()
    if NS.Sim and NS.Sim:IsActive() then return end   -- a simulated pass asks for nothing (H4)
    if pending and NS.addon:TimeLeft(pending) > 0 then return end
    pending = NS.addon:ScheduleTimer(function()
        pending = nil
        A:Snapshot()
    end, A.DEBOUNCE)
end

A.events = NS.NewBusTarget()
if A.events then
    A.events:RegisterMessage(NS.MSG.SKILLS_UPDATED, function() A:RequestSnapshot() end)
    NS.SafeRegisterEvent(A.events, "PLAYER_LOGOUT", function() A:Snapshot() end, NS.rejectedEvents)
end
