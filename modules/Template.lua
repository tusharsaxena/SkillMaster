local _, NS = ...
-- modules/Template.lua — the broker feed text templates (design §6.7, plan Task 4.1).
-- NS.Template.Render(tpl, ctx) -> string replaces each {token} with its value from ctx; a token
-- it does not know, or one whose data is missing, renders empty. Pure: it reads only ctx.
--
-- ctx = { skills = <SkillData model>, stat = { [statKey] = <StatData entry> }, gains = n,
--         last = { key, new } | nil, pinned = key | nil, level = n, mainHand = skill key | nil }

NS.Template = {}
local Tpl = NS.Template

-- The tokens, for the Broker settings page's hint line (T5.1).
Tpl.TOKENS = { "{pinned}", "{gains}", "{last}", "{lowestProf}", "{equippedWeapon}", "{skill:<key>}",
               "{stat:<key>}", "{level}" }

-- A stat alias stands for the highest of several StatData keys ("{stat:crit}" in the default).
Tpl.STAT_ALIASES = {
    crit = { "meleeCrit", "rangedCrit", "spellCrit" },
    hit  = { "meleeHit", "rangedHit", "spellHit" },
}

--- "Fishing 107+25/150"; an unlearned skill is its name alone; nil for no entry.
function Tpl.FormatSkill(e)
    if type(e) ~= "table" then return nil end
    if not e.learned then return e.name end
    local mod = tonumber(e.modifier) or 0
    local bonus = ""
    if mod > 0 then bonus = "+" .. mod elseif mod < 0 then bonus = tostring(mod) end
    return ("%s %d%s/%d"):format(e.name or "", e.rank or 0, bonus, e.max or 0)
end

local function skillEntry(ctx, key)
    local m = ctx.skills
    return key and type(m) == "table" and type(m.byKey) == "table" and m.byKey[key] or nil
end

local function ratio(e)
    if not e.max or e.max <= 0 then return 1 end
    return (e.rank or 0) / e.max
end

local function lowestIn(ctx, category)
    local m = ctx.skills
    if not (type(m) == "table" and type(m.order) == "table") then return nil end
    local best
    for _, key in ipairs(m.order[category] or {}) do
        local e = m.byKey[key]
        if e and e.learned and (not best or ratio(e) < ratio(best)) then best = e end
    end
    return best
end

--- The learned primary profession furthest from its cap, else the secondary one.
function Tpl.LowestProfession(ctx)
    return lowestIn(ctx, "primary") or lowestIn(ctx, "secondary")
end

local function statEntry(ctx, key)
    local index = ctx.stat
    if type(index) ~= "table" then return nil end
    if index[key] then return index[key] end
    local best
    for _, k in ipairs(Tpl.STAT_ALIASES[key] or {}) do
        local e = index[k]
        if e and (not best or (e.value or 0) > (best.value or 0)) then best = e end
    end
    return best
end

local function pinnedEntry(ctx)
    local key = ctx.pinned or (type(ctx.last) == "table" and ctx.last.key) or nil
    return skillEntry(ctx, key) or Tpl.LowestProfession(ctx)
end

local function lastText(ctx)
    local last = ctx.last
    local e = type(last) == "table" and skillEntry(ctx, last.key)
    if not e then return nil end
    return ("%s %d"):format(e.name or "", last.new or e.rank or 0)
end

-- name -> function(ctx, arg) -> string | nil. `arg` is the text after the colon, or nil.
local RESOLVE = {
    pinned         = function(ctx) return Tpl.FormatSkill(pinnedEntry(ctx)) end,
    gains          = function(ctx) return ctx.gains and tostring(ctx.gains) or nil end,
    last           = lastText,
    lowestProf     = function(ctx) return Tpl.FormatSkill(Tpl.LowestProfession(ctx)) end,
    equippedWeapon = function(ctx) return Tpl.FormatSkill(skillEntry(ctx, ctx.mainHand)) end,
    skill          = function(ctx, arg) return Tpl.FormatSkill(skillEntry(ctx, arg)) end,
    stat           = function(ctx, arg)
        local e = arg and statEntry(ctx, arg)
        return e and e.display or nil
    end,
    level          = function(ctx) return ctx.level and tostring(ctx.level) or nil end,
}
-- The tokens that take an argument; every other one refuses it.
local TAKES_ARG = { skill = true, stat = true }

local function resolveToken(ctx, name, colon, arg)
    local fn = RESOLVE[name]
    if not fn then return "" end
    local hasArg = colon == ":"
    if hasArg ~= (TAKES_ARG[name] == true) or (not hasArg and arg ~= "") then return "" end
    local ok, out = pcall(fn, ctx, hasArg and arg or nil)
    if not ok or out == nil then return "" end
    return tostring(out)
end

--- Render `tpl` against `ctx`. A non-string template renders "".
--- @return string
function Tpl.Render(tpl, ctx)
    if type(tpl) ~= "string" then return "" end
    ctx = type(ctx) == "table" and ctx or {}
    local out = tpl:gsub("{(%w+)(:?)([^{}]*)}", function(name, colon, arg)
        return resolveToken(ctx, name, colon, arg)
    end)
    return out
end
