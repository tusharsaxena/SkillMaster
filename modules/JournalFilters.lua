local addonName, NS = ...
-- modules/JournalFilters.lua — the Journal Log's column filters (R5-SM-11, owner feedback round 5, addendum A1:
-- "add filters for all column headers"). Each of the Log's six column headers opens a menu of its filter:
--   Date    any day, today, yesterday, or one of the days the range holds (newest first)
--   Time    any time, or a part of the day (night 0-6, morning 6-12, afternoon 12-18, evening 18-24)
--   Type    a kind: skill-up, reputation (a standing change is one), currency (R6-SM-02, owner feedback round 6:
--           the kind filtering the Name header held until then)
--   Name    one name: the picked type's names, or with no type a submenu per kind present
--   Change  all, gains, losses, or the reputation changes that moved a standing
--   Zone    any zone, or one of the zones the range holds (most rows first)
-- Filters combine (every one must match), apply on top of the range picker, and are session-only: the window
-- opens unfiltered after a /reload. The Log draws an active header in the accent with the filter mark, the side
-- column offers Clear filters while any is on, and the summary and the ETA card count the filtered rows
-- (modules/Journal.lua).
--
-- NS.JournalFilters.Get(col) / .Set(col, value) / .Clear() / .Active([col]) / .Matches(e, ctx) / .Apply(list, ctx)
--   / .MenuRows(col, list, ctx) / .Menu(col, anchor, list, ctx) / .KindOf(e) / .KindLabel(kind) / .Summary(list)
--   / .Label(col)
-- `ctx` = { nameOf = fn(e) -> the name the Log shows, now = epoch seconds, onChange = fn() }.

NS.JournalFilters = {}
local JF = NS.JournalFilters
local L = NS.L

JF.COLUMNS = { "date", "time", "type", "name", "change", "zone" }
JF.KINDS = { "skill", "reputation", "currency" }
JF.MAX_CHOICES = 20   -- a menu lists at most this many days, names or zones (the shared menu does not scroll)

-- A kind's name in the Type column and its menu (singular, as a row reads), and in the Name menu's submenus (plural).
local KIND_LABEL = { skill = L["Skill-up"], reputation = L["Reputation"], currency = L["Currency"] }
local KIND_PLURAL = { skill = L["Skill-ups"], reputation = L["Reputations"], currency = L["Currencies"] }
local TIME_ORDER = { "night", "morning", "afternoon", "evening" }
local TIME_HOURS = { night = { 0, 6 }, morning = { 6, 12 }, afternoon = { 12, 18 }, evening = { 18, 24 } }
local TIME_LABEL = {
    night = L["Night (0:00 to 6:00)"], morning = L["Morning (6:00 to 12:00)"],
    afternoon = L["Afternoon (12:00 to 18:00)"], evening = L["Evening (18:00 to 24:00)"],
}
local CHANGE_ORDER = { "gain", "loss", "standing" }
local CHANGE_LABEL = { gain = L["Gains"], loss = L["Losses"], standing = L["Standing changes"] }

-- The filters in force, session-only: date, time, kind, name, change, zone (nil each: no filter). Session-only,
-- so the Type column (R6-SM-02) took the kind over from Name with nothing saved to migrate.
local filters = {}
-- The kind of the name filter in force (the Name menu knows it): a type picked drops a name of another, and the
-- summary counts a name's own kind with no type picked.
local nameKind

function JF.Get(key) return filters[key] end

--- Set filter `key` to `value` (nil clears it). Answers whether it changed.
function JF.Set(key, value)
    if filters[key] == value then return false end
    filters[key] = value
    if key == "name" then nameKind = nil end   -- set from outside the Name menu, its kind is not known
    return true
end

function JF.Clear()
    for k in pairs(filters) do filters[k] = nil end
    nameKind = nil
end

-- The filter keys each column's header owns: Type the kind, Name the name (R6-SM-02).
local OWNS = { date = { "date" }, time = { "time" }, type = { "kind" }, name = { "name" }, change = { "change" },
               zone = { "zone" } }

--- Whether column `col`'s filter is on, or with no column whether any is.
function JF.Active(col)
    for _, c in ipairs(col and { col } or JF.COLUMNS) do
        for _, k in ipairs(OWNS[c] or {}) do
            if filters[k] ~= nil then return true end
        end
    end
    return false
end

--- A row's kind: "skill" for a skill-up, else its own ("reputation", "currency").
function JF.KindOf(e) return e.kind or "skill" end

--- A kind's label, as the Type column shows it: "Skill-up", "Reputation", "Currency" (R6-SM-02).
function JF.KindLabel(kind) return KIND_LABEL[kind or "skill"] or tostring(kind) end

local function day(t) return date("%Y-%m-%d", t) end

--- The local calendar's day before `t`'s, as day() names it: noon of `t`'s day less a day, so a 23- or 25-hour day
--- (a daylight-saving change) never skips or repeats one, as `t - 86400` did in the hour after a spring-forward.
local function dayBefore(t)
    local d = date("*t", t)
    return day(time({ year = d.year, month = d.month, day = d.day - 1, hour = 12 }))
end

local function delta(e) return (tonumber(e.new) or 0) - (tonumber(e.old) or 0) end

local MATCH = {
    date = function(e, v, ctx)
        local now = tonumber(ctx.now) or time()
        if v == "today" then return day(e.t) == day(now) end
        if v == "yesterday" then return day(e.t) == dayBefore(now) end
        return day(e.t) == v
    end,
    time = function(e, v)
        local h = tonumber(date("%H", e.t)) or 0
        local span = TIME_HOURS[v]
        return span ~= nil and h >= span[1] and h < span[2]
    end,
    kind = function(e, v) return JF.KindOf(e) == v end,
    name = function(e, v, ctx) return ctx.nameOf(e) == v end,
    change = function(e, v)
        if v == "gain" then return delta(e) > 0 end
        if v == "loss" then return delta(e) < 0 end
        return e.newReaction ~= nil
    end,
    zone = function(e, v) return (e.zone or "") == v end,
}

--- Whether Log row `e` passes every filter in force.
function JF.Matches(e, ctx)
    for k, v in pairs(filters) do
        local fn = MATCH[k]
        if fn and not fn(e, v, ctx) then return false end
    end
    return true
end

--- `list` (oldest first) narrowed to the rows every filter passes; `list` itself while none is on.
function JF.Apply(list, ctx)
    if next(filters) == nil then return list end
    local out = {}
    for _, e in ipairs(list) do
        if JF.Matches(e, ctx) then out[#out + 1] = e end
    end
    return out
end

--- What `list` (the filtered rows) sums to, for the summary card: the kind it counts and its total. Reputation
--- and currency rows sum their signed changes while the Type filter is theirs (or, with no type, the Name filter's
--- name is of theirs); otherwise the skill-ups' points.
function JF.Summary(list)
    local kind = filters.kind or (filters.name ~= nil and nameKind) or nil
    if kind ~= "reputation" and kind ~= "currency" then kind = "skill" end
    local total = 0
    for _, e in ipairs(list) do
        if JF.KindOf(e) == kind then
            total = total + (kind == "skill" and math.max(delta(e), 0) or delta(e))
        end
    end
    return kind, total
end

-- The distinct values `valueOf(e)` takes over `list`, most rows first then by name, at most MAX_CHOICES.
local function distinct(list, valueOf)
    local count, out = {}, {}
    for _, e in ipairs(list) do
        local v = valueOf(e)
        if v ~= nil and v ~= "" then
            if not count[v] then out[#out + 1] = v end
            count[v] = (count[v] or 0) + 1
        end
    end
    table.sort(out, function(a, b)
        if count[a] ~= count[b] then return count[a] > count[b] end
        return tostring(a) < tostring(b)
    end)
    while #out > JF.MAX_CHOICES do out[#out] = nil end
    return out
end

local function radio(label, key, value, ctx)
    return { value = tostring(value or "any"), label = label, radio = true,
             selected = function() return filters[key] == value end,
             onClick = function()
                 JF.Set(key, value)
                 if ctx.onChange then ctx.onChange() end
             end }
end

local MENUS = {}

function MENUS.date(list, ctx)
    local rows = { { title = true, label = L["Date"] }, radio(L["Any day"], "date", nil, ctx),
                   radio(L["Today"], "date", "today", ctx), radio(L["Yesterday"], "date", "yesterday", ctx) }
    -- The days the range holds, newest first.
    local days, seen = {}, {}
    for i = #list, 1, -1 do
        local d = day(list[i].t)
        if not seen[d] and #days < JF.MAX_CHOICES then seen[d], days[#days + 1] = true, { d = d, t = list[i].t } end
    end
    if #days > 0 then rows[#rows + 1] = { divider = true } end
    for _, x in ipairs(days) do rows[#rows + 1] = radio(date(L["%m/%d/%y"], x.t), "date", x.d, ctx) end
    return rows
end

function MENUS.time(_, ctx)
    local rows = { { title = true, label = L["Time"] }, radio(L["Any time"], "time", nil, ctx) }
    for _, k in ipairs(TIME_ORDER) do rows[#rows + 1] = radio(TIME_LABEL[k], "time", k, ctx) end
    return rows
end

-- The Type column (R6-SM-02): any type, or one kind. A kind picked drops a name of another kind.
function MENUS.type(_, ctx)
    local rows = { { title = true, label = L["Type"] }, radio(L["Any type"], "kind", nil, ctx) }
    for _, k in ipairs(JF.KINDS) do
        local row = radio(KIND_LABEL[k], "kind", k, ctx)
        local onClick = row.onClick
        row.onClick = function()
            if filters.name ~= nil and nameKind ~= k then filters.name, nameKind = nil, nil end
            onClick()
        end
        rows[#rows + 1] = row
    end
    return rows
end

-- One name of kind `k` as a radio: picking it sets the name alone (the Type filter stays as it is).
local function nameRadio(n, k, ctx)
    return { value = n, label = n, radio = true,
             selected = function() return filters.name == n end,
             onClick = function()
                 filters.name, nameKind = n, k
                 if ctx.onChange then ctx.onChange() end
             end }
end

local function namesOf(list, k, ctx)
    return distinct(list, function(e) return JF.KindOf(e) == k and ctx.nameOf(e) or nil end)
end

-- The Name column: any name, then the picked type's names flat, or with no type a submenu per kind present.
function MENUS.name(list, ctx)
    local rows = { { title = true, label = L["Name"] }, radio(L["Any name"], "name", nil, ctx) }
    local only = filters.kind
    if only then
        local names = namesOf(list, only, ctx)
        if #names > 0 then rows[#rows + 1] = { divider = true } end
        for _, n in ipairs(names) do rows[#rows + 1] = nameRadio(n, only, ctx) end
        return rows
    end
    local divided = false
    for _, k in ipairs(JF.KINDS) do
        local names = namesOf(list, k, ctx)
        if #names > 0 then
            if not divided then rows[#rows + 1] = { divider = true } divided = true end
            local sub = {}
            for _, n in ipairs(names) do sub[#sub + 1] = nameRadio(n, k, ctx) end
            rows[#rows + 1] = { value = "names:" .. k, label = L["One of the %s"]:format(KIND_PLURAL[k]), submenu = sub }
        end
    end
    return rows
end

function MENUS.change(_, ctx)
    local rows = { { title = true, label = L["Change"] }, radio(L["All"], "change", nil, ctx) }
    for _, k in ipairs(CHANGE_ORDER) do rows[#rows + 1] = radio(CHANGE_LABEL[k], "change", k, ctx) end
    return rows
end

function MENUS.zone(list, ctx)
    local rows = { { title = true, label = L["Zone"] }, radio(L["Any zone"], "zone", nil, ctx) }
    local zones = distinct(list, function(e) return e.zone end)
    if #zones > 0 then rows[#rows + 1] = { divider = true } end
    for _, z in ipairs(zones) do rows[#rows + 1] = radio(z, "zone", z, ctx) end
    return rows
end

--- Column `col`'s menu rows over `list` (the range's rows, before the filters: every choice the range offers).
function JF.MenuRows(col, list, ctx)
    local fn = MENUS[col]
    return fn and fn(list or {}, ctx) or {}
end

--- Open column `col`'s menu on `anchor` (its header).
function JF.Menu(col, anchor, list, ctx)
    local rows = JF.MenuRows(col, list, ctx)
    JF.menu = NS.Widgets and NS.Widgets.ContextMenu and NS.Widgets.ContextMenu(anchor, rows, { owner = addonName })
    return JF.menu
end

--- The words a header's tooltip says of its filter: the choice in force, or nil while none is.
function JF.Label(col)
    if col == "date" and filters.date then
        if filters.date == "today" then return L["Today"] end
        if filters.date == "yesterday" then return L["Yesterday"] end
        return filters.date
    end
    if col == "time" and filters.time then return TIME_LABEL[filters.time] end
    if col == "type" and filters.kind then return KIND_LABEL[filters.kind] end
    if col == "name" and filters.name then return filters.name end
    if col == "change" and filters.change then return CHANGE_LABEL[filters.change] end
    if col == "zone" and filters.zone then return filters.zone end
    return nil
end
