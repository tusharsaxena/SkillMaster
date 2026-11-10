local _, NS = ...
-- modules/StatData.lua — the character's stats in four groups (base, spell, defense, utility), each
-- scaled against its reference with its markers (design §5.2, §6.3, plan Task 2.3). Reads the client
-- through feature-detected APIs only; a stat whose API is absent is left out (clients-§3). Sends
-- STATS_UPDATED(model), throttled to 0.2 s.
--
-- Model: { base = { entry... }, spell = {...}, defense = {...}, utility = {...} }, each entry
--   { key, label, value, display, pct, ref, raw?, markers = { { at, value, label } } },
-- where pct = value / ref x 100 (unclamped: the bar clamps) and a marker's `at` is the same scale.

NS.StatData = {}
local S = NS.StatData
local Perf = NS.Perf

local floor, max, min, huge = math.floor, math.max, math.min, math.huge

S.GROUPS = { "base", "spell", "defense", "utility" }
S.THROTTLE = 0.2       -- seconds between an event and the send
S.SPEED_TICK = 0.5     -- seconds between speed reads while a speed display is visible
S.RUN_YARDS = 7        -- yards/s at 100% run speed
S.SCHOOLS = { 2, 3, 4, 5, 6, 7 }   -- holy .. arcane; physical (1) is not a spell school
S.EQUIPPED_SLOTS = 19

-- Each API read as a bare global (never called here), so presence is a lookup, not a call, and a
-- name a client lacks reads nil instead of raising (clients-§3).
S.APIS = {
    UnitStat                   = function() return UnitStat end,
    UnitAttackPower            = function() return UnitAttackPower end,
    UnitRangedAttackPower      = function() return UnitRangedAttackPower end,
    GetCritChance              = function() return GetCritChance end,
    GetRangedCritChance        = function() return GetRangedCritChance end,
    GetHitModifier             = function() return GetHitModifier end,
    GetRangedHitModifier       = function() return GetRangedHitModifier end,
    GetSpellHitModifier        = function() return GetSpellHitModifier end,
    GetSpellCritChance         = function() return GetSpellCritChance end,
    GetSpellBonusDamage        = function() return GetSpellBonusDamage end,
    GetSpellBonusHealing       = function() return GetSpellBonusHealing end,
    GetManaRegen               = function() return GetManaRegen end,
    UnitArmor                  = function() return UnitArmor end,
    UnitDefenseSkill           = function() return UnitDefenseSkill end,
    GetDodgeChance             = function() return GetDodgeChance end,
    GetParryChance             = function() return GetParryChance end,
    GetBlockChance             = function() return GetBlockChance end,
    UnitResistance             = function() return UnitResistance end,
    -- Through NS.Compat (T5.2): the simulator's seam answers the speed while a session runs.
    GetUnitSpeed               = function() return type(GetUnitSpeed) == "function" and NS.Compat.UnitSpeed or nil end,
    GetInventoryItemDurability = function() return GetInventoryItemDurability end,
}

local function resolve(name)
    local get = S.APIS[name]
    local fn = get and get()
    if type(fn) == "function" then return fn end
    return nil
end

-- WoW Forever answers some stat reads as secret numbers while the addon's code is tainted (measured
-- 2026-11-10: UnitStat inside an AceTimer callback). A secret cannot be compared or added, so num()
-- turns one away like a non-number and notes it; read() then keeps the stat's last plain value.
local secretSeen = false
local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) and true or false end

local function num(v)
    if isSecret(v) then secretSeen = true return nil end
    if type(v) == "number" then return v end
    return nil
end

-- ── calcs: an API's returns -> value[, raw] ─────────────────────────────────────────────────────

--- Physical damage reduction against a level-equal attacker, capped at 75% (vanilla formula).
local function mitigation(armor, level)
    local pct = armor / (armor + 400 + 85 * level) * 100
    return min(max(pct, 0), 75)
end

local function bestSchool(fn)
    local best
    for _, school in ipairs(S.SCHOOLS) do
        local v = num(fn(school))
        if v and (not best or v > best) then best = v end
    end
    return best
end

--- The lowest current/max of every equipped slot with durability; 100 when none has any.
local function lowestDurability(fn)
    local lowest = huge
    for slot = 1, S.EQUIPPED_SLOTS do
        local cur, most = fn(slot)
        if num(cur) and num(most) and most > 0 then lowest = min(lowest, cur / most * 100) end
    end
    if lowest == huge then return 100 end
    return lowest
end

S.CALC = {
    first = function(fn) return num(fn()) end,
    -- UnitStat(unit, i): base, effective, posBuff, negBuff.
    stat = function(fn, def) return num(select(2, fn("player", def.arg))) end,
    -- Unit(Ranged)AttackPower(unit): base, posBuff, negBuff.
    attackPower = function(fn)
        local base, pos, neg = fn("player")
        if not num(base) then return nil end
        return base + (num(pos) or 0) + (num(neg) or 0)
    end,
    bestSchool = function(fn) return bestSchool(fn) end,
    -- GetManaRegen(): base and casting regen per second; shown per 5 s.
    mp5 = function(fn) local v = num(fn()) return v and v * 5 end,
    -- UnitArmor(unit): base, effective, armor, posBuff, negBuff. Value is the mitigation %.
    armor = function(fn, _, ctx)
        local armor = num(select(2, fn("player")))
        if not armor then return nil end
        return mitigation(armor, ctx.level), armor
    end,
    -- UnitDefenseSkill(unit): base, modifier (assumed; Forever's name for 1.12's UnitDefense).
    defense = function(fn)
        local base, mod = fn("player")
        if not num(base) then return nil end
        return base + (num(mod) or 0)
    end,
    -- UnitResistance(unit, school): base, total, bonus, minus.
    resist = function(fn, def) return num(select(2, fn("player", def.arg))) end,
    -- GetUnitSpeed(unit): current, run, flight, swim (yards/s).
    speed = function(fn, def)
        local v = num(select(def.arg, fn("player")))
        return v and v / S.RUN_YARDS * 100
    end,
    durability = function(fn) return lowestDurability(fn) end,
}

-- ── references, markers, display ───────────────────────────────────────────────────────────────

local NAMED_REFS = {
    skillCap  = function(ctx) return 5 * ctx.level end,
    resistCap = function(ctx) return 5 * (ctx.level + 3) end,
}

local function refValue(ref, ctx)
    if type(ref) == "number" then return ref end
    local named = NAMED_REFS[ref]
    return named and named(ctx) or nil
end

--- The markers that apply at the player's level, with their values resolved.
local function liveMarkers(def, ctx)
    local out = {}
    for _, m in ipairs(def.markers or {}) do
        local value = refValue(m.value, ctx)
        if value and ctx.level >= (m.minLevel or 0) then
            out[#out + 1] = { value = value, label = m.label }
        end
    end
    return out
end

local function capOf(markers)
    local cap
    for _, m in ipairs(markers) do if not cap or m.value > cap then cap = m.value end end
    return cap
end

local FORMATS = {
    int   = function(e) return ("%d"):format(floor(e.value + 0.5)) end,
    pct   = function(e) return ("%.1f%%"):format(e.value) end,
    pct0  = function(e) return ("%d%%"):format(floor(e.value + 0.5)) end,
    armor = function(e) return ("%d (%.1f%%)"):format(e.raw or 0, e.value) end,
}

local function scale(v, ref)
    if not ref or ref <= 0 then return 0 end
    return v / ref * 100
end

--- Set ref, pct and each marker's `at` once the reference is known.
local function finish(e, ref)
    e.ref = ref or 0
    e.pct = scale(e.value, ref)
    for _, m in ipairs(e.markers) do m.at = scale(m.value, ref) end
    e.display = (FORMATS[e.fmt] or FORMATS.int)(e)
    e.fmt = nil
end

local function entryOf(def, ctx, value, raw)
    return { key = def.key, label = def.label, value = value, raw = raw, fmt = def.fmt,
             markers = liveMarkers(def, ctx), refSpec = def.ref }
end

-- The last plain { value, raw } per stat key, for a read the client answered secret.
S.__last = {}

--- A secret read: the stat's last plain value marked stale, or nil before any plain read.
local function lastPlain(def, ctx)
    local last = S.__last[def.key]
    if not last then return nil end
    local e = entryOf(def, ctx, last[1], last[2])
    e.stale = true
    return e
end

--- One def -> an unfinished entry, or nil when its API is absent or answers nothing. A secret
--- answer keeps the last plain value (stale) until a later scan reads it plain again.
local function read(def, ctx)
    local fn, calc = resolve(def.api), S.CALC[def.calc or "first"]
    if not (fn and calc) then return nil end
    secretSeen = false
    local ok, value, raw = pcall(calc, fn, def, ctx)
    if ok and num(value) and not isSecret(raw) then
        S.__last[def.key] = { value, raw }
        return entryOf(def, ctx, value, raw)
    end
    if secretSeen or isSecret(value) or isSecret(raw) then
        S.sawSecret = true
        return lastPlain(def, ctx)
    end
    return nil
end

--- The highest value among a group's "maxInGroup" entries.
local function groupMax(entries)
    local best = 0
    for _, e in ipairs(entries) do
        if e.refSpec == "maxInGroup" and e.value > best then best = e.value end
    end
    return best
end

local function resolveRef(e, ctx, gmax)
    if e.refSpec == "maxInGroup" then return gmax end
    if e.refSpec == "cap" then return capOf(e.markers) end
    return refValue(e.refSpec, ctx)
end

local function finishGroup(entries, ctx)
    local gmax = groupMax(entries)
    for _, e in ipairs(entries) do
        finish(e, resolveRef(e, ctx, gmax))
        e.refSpec = nil
    end
end

-- ── the scan ───────────────────────────────────────────────────────────────────────────────────

--- The scan's level, through NS.Compat (the simulator's seam answers the sample character's).
function S.LevelOf()
    local level = num(NS.Compat.PlayerLevel())
    return (level and level > 0) and level or 1
end

local function context()
    return { level = S.LevelOf() }
end

--- The model and its key index from `pick(def) -> unfinished entry|nil`, over every def in order.
local function assemble(ctx, pick)
    local model, index = {}, {}
    for _, group in ipairs(S.GROUPS) do model[group] = {} end
    for _, def in ipairs(NS.STAT_DEFS or {}) do
        local e = model[def.group] and pick(def)
        if e then
            local list = model[def.group]
            list[#list + 1] = e
            index[e.key] = e
        end
    end
    for _, group in ipairs(S.GROUPS) do finishGroup(model[group], ctx) end
    return model, index
end

--- Read every stat the client can give. Answers the model and keeps it for Model() / Get().
function S:Scan()
    local t0 = Perf.on and debugprofilestop()
    local ctx = context()
    self.sawSecret = false
    self.model, self.index = assemble(ctx, function(def) return read(def, ctx) end)
    if t0 then Perf.Note("statScan", debugprofilestop() - t0) end
    return self.model
end

--- A model from `values[key]` (a number, or { value, raw }) for a character at `level`, through
--- the same references, markers and display as Scan. Pure: test mode's sample character.
function S.Build(values, level)
    local ctx = { level = tonumber(level) or 1 }
    return assemble(ctx, function(def)
        local v = values[def.key]
        if type(v) == "table" and num(v[1]) then return entryOf(def, ctx, v[1], v[2]) end
        if num(v) then return entryOf(def, ctx, v) end
        return nil
    end)
end

function S:Model() return self.model end
function S:Get(key) return self.index and self.index[key] or nil end

-- ── events, the throttle and the speed ticker ──────────────────────────────────────────────────

S.EVENTS = {
    "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_DAMAGE",
    "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_DURABILITY",
    -- Not in the plan's list but load-bearing: the references follow the level, and the first
    -- model is built on entering the world.
    "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    -- Leaving combat: a read answered secret in combat is plain again (WoW Forever, 2026-11-10).
    "PLAYER_REGEN_ENABLED",
}

local function pending(handle)
    return handle ~= nil and NS.addon:TimeLeft(handle) > 0
end

local function flush()
    S.timer = nil
    NS.bus:SendMessage(NS.MSG.STATS_UPDATED, S:Scan())
end

--- Ask for a rescan; a burst inside the throttle window sends once. A handle a stand-down
--- canceled reads as not pending, so the next event schedules again.
function S:Request()
    if pending(self.timer) then return end
    self.timer = NS.addon:ScheduleTimer(flush, S.THROTTLE)
end

local function onEvent(event, unit)
    if NS.IsStoodDown() then return end   -- a stray dispatch after the stand-down does nothing
    if event:sub(1, 5) == "UNIT_" and unit ~= "player" then return end
    S:Request()
end

--- Run the 0.5 s speed read while a stat display showing speed is visible (the display calls
--- this on show and hide). Answers whether the ticker runs.
function S:WatchSpeed(on)
    if on and not pending(self.ticker) then
        self.ticker = NS.addon:ScheduleRepeatingTimer(function() S:SpeedTick() end, S.SPEED_TICK)
    elseif not on and self.ticker then
        NS.addon:CancelTimer(self.ticker)
        self.ticker = nil
    end
    return self:IsWatchingSpeed()
end

function S:IsWatchingSpeed() return pending(self.ticker) end

--- One tick: read the speed alone, and ask for a rescan only when it moved (review F-003), so a
--- standing character costs one call every 0.5 s rather than a full stat pass.
function S:SpeedTick()
    local current, run = NS.Compat.UnitSpeed("player")
    if isSecret(current) or isSecret(run) then return false end
    local sig = tostring(current) .. "/" .. tostring(run)
    if sig == self.lastSpeed then return false end
    self.lastSpeed = sig
    self:Request()
    return true
end

-- A tracked bus target: the stand-down takes these registrations down and the stand-up replays
-- them (LibKa0s-Bus-1.0); the timers live on the addon object, which the stand-down cancels.
-- The UNIT_* events are the player's alone, on NS.UnitEvents' frame (registered for "player" on
-- stand-up); the rest on the bus target.
S.events = NS.NewBusTarget()
local plain = {}
for _, event in ipairs(S.EVENTS) do
    if event:sub(1, 5) == "UNIT_" then NS.UnitEvents.Register(event, onEvent) else plain[#plain + 1] = event end
end
if S.events then NS.SafeRegisterEvents(S.events, plain, onEvent, NS.rejectedEvents) end
