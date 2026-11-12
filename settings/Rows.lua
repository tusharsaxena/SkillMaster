local _, NS = ...
-- settings/Rows.lua — the Rows page (owner feedback round 5, R5-11..R5-13): every skill and every stat
-- in one boxed list (settings/BoxList.lua), grouped under the main window's block headings in its
-- block order, each line its icon, its name and two eyes: the main window's Hide (`skills.hidden`,
-- `stats.hidden`: the window and the detached blocks) and the LDB tooltip's (`broker.tooltip.hiddenSkills`,
-- `broker.tooltip.hiddenStats`). A caption line on top names the two columns; each group's heading
-- carries one eye per column that shows that group's hidden rows again.
--
-- It replaced the Skills page's Professions and Weapons tabs, the Stats page (whose General tab drew
-- nothing: its one row was the undrawn whole-set row) and the Broker page's Tooltip skills and Tooltip
-- stats tabs. The paths are the ones those rows had, so nothing stored moved and no migration runs.
--
-- Each hide row reads and writes its set's entry through get / set (false clears the entry rather
-- than storing it), and an undrawn whole-set row per set (type `set`) lets the page's Defaults clear
-- a key with no row of its own (an "other:" skill the catalog does not know, review F-002). The row
-- menu's Hide (modules/Interact.lua) writes the same rows.
local L = NS.L
local H = NS.Helpers
local PAGE = "rows"
local GROUP = L["Show and hide"]

local Rows = {}
NS.OptionsRows = Rows

-- The two columns' widths: wide enough for their captions over a 16 px eye.
Rows.COLUMN_W, Rows.LABEL_W = 84, 0.62

-- Every hide write, from any actor (the page's eyes, the row menu's Hide, `/sm set`, a header's
-- restore eye), redraws the page: the library renders a page on screen now and marks a hidden one
-- owed a render for its next show (review, R5-followups: a write from elsewhere left a shown page's
-- eyes stale). Inside a bracket (a heading's show-all, the page's Defaults) the writes coalesce
-- into one render on the next frame, as NS.ApplyLook does.
local pending = false

local function render()
    pending = false
    local ctx = Rows.ctx
    if ctx then H.RefreshPanel(ctx, true) end
end

local function stale()
    if not Rows.ctx then return end
    local S = NS.SchemaRuntime
    if not (S and S.InBulk and S.InBulk() and NS.addon and NS.addon.ScheduleTimer) then return render() end
    if pending then return end
    pending = true
    NS.addon:ScheduleTimer(render, 0)
end

local function windowChanged()
    NS.ApplyLook()
    stale()
end

local function brokerRefresh()
    if NS.Broker and NS.Broker.Refresh then NS.Broker.Refresh() end
    stale()
end

local function windowSet(kind)
    local p = NS.db and NS.db.profile[kind]
    return p and p.hidden
end

local function tipSet(setKey)
    local b = NS.db and NS.db.profile.broker
    return b and b.tooltip and b.tooltip[setKey]
end

--- One entry's hide row in the set `setOf()` answers.
local function memberRow(path, setOf, key, label, desc, onChange)
    return {
        path = path, page = PAGE, group = GROUP, type = "bool", default = false, label = label, desc = desc,
        get = function()
            local set = setOf()
            return set ~= nil and set[key] == true
        end,
        set = function(v)
            local set = setOf()
            if set then set[key] = v and true or nil end
        end,
        onChange = onChange,
    }
end

local function setRow(path, desc, onChange)
    return { path = path, page = PAGE, group = GROUP, type = "set", default = {}, skipRender = true,
             label = L["Hidden rows"], desc = desc, onChange = onChange }
end

local WINDOW_DESC = L["Leave this row out of the window and the detached blocks. The row menu's Hide sets it too."]
local TIP_DESC = L["Leave this row out of the LDB tooltip. The tooltip's row menu's Hide sets it too."]

local function pair(rows, kind, key, name)
    local winKind, tipKey = kind == "stat" and "stats" or "skills", kind == "stat" and "hiddenStats" or "hiddenSkills"
    rows[#rows + 1] = memberRow(winKind .. ".hidden." .. key, function() return windowSet(winKind) end, key,
        L["Hide %s"]:format(name), WINDOW_DESC, windowChanged)
    rows[#rows + 1] = memberRow("broker.tooltip." .. tipKey .. "." .. key, function() return tipSet(tipKey) end, key,
        L["Hide %s in the LDB tooltip"]:format(name), TIP_DESC, brokerRefresh)
end

local rows = {
    setRow("skills.hidden", L["Every skill hidden from the window, as a set of keys."], windowChanged),
    setRow("stats.hidden", L["Every stat hidden from the window, as a set of keys."], windowChanged),
    setRow("broker.tooltip.hiddenSkills", L["Every skill the LDB tooltip leaves out, as a set of keys."], brokerRefresh),
    setRow("broker.tooltip.hiddenStats", L["Every stat the LDB tooltip leaves out, as a set of keys."], brokerRefresh),
}
for _, key in ipairs(NS.SortedSkillKeys) do pair(rows, "skill", key, L[NS.SkillCatalog[key].name]) end
for _, def in ipairs(NS.STAT_DEFS) do pair(rows, "stat", def.key, def.label) end
NS.RegisterSchemaRows(rows)

-- ---------------------------------------------------------------------------------------------
-- The model: one group per block, in the window's block order
-- ---------------------------------------------------------------------------------------------
local SKILL_CATS = { primary = true, secondary = true, weapon = true, other = true }
local STAT_GROUPS = { base = true, spell = true, defense = true, utility = true }

local function entry(kind, key, name)
    local winKind, tipKey = kind == "stat" and "stats" or "skills", kind == "stat" and "hiddenStats" or "hiddenSkills"
    return { kind = kind, key = key, name = name, icon = NS.Rows.Icon(kind, key),
             windowPath = winKind .. ".hidden." .. key, tipPath = "broker.tooltip." .. tipKey .. "." .. key }
end

--- { { id, title, rows = { { kind, key, name, icon, windowPath, tipPath } ... } } ... }, one group per
--- block in NS.Blocks.Ordered(); a skill under its category's block, a stat under its group's.
function Rows.Groups()
    local out = {}
    for _, id in ipairs(NS.Blocks.Ordered()) do
        local d = NS.BlockDefs[id]
        local g = { id = id, title = d.title, rows = {} }
        if d.source == "skills" then
            for _, key in ipairs(NS.SortedSkillKeys) do
                local c = NS.SkillCatalog[key]
                if (SKILL_CATS[c.category] and c.category or "other") == d.filter then
                    g.rows[#g.rows + 1] = entry("skill", key, L[c.name])
                end
            end
        else
            for _, def in ipairs(NS.STAT_DEFS) do
                if (STAT_GROUPS[def.group] and def.group or "utility") == d.filter then
                    g.rows[#g.rows + 1] = entry("stat", def.key, def.label)
                end
            end
        end
        out[#out + 1] = g
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The render
-- ---------------------------------------------------------------------------------------------

local function hidden(path) return NS.GetSetting(path) == true end

-- An eye's write redraws the page through its row's onChange (stale above), so a click renders once.
local function toggle(path, was)
    return function() NS.SetByPath(path, not was) end
end

--- Show every hidden row of `g` in one column, as one act (one LAYOUT_CHANGED, one render).
local function showAll(paths)
    return function()
        local entries = {}
        for i, p in ipairs(paths) do entries[i] = { path = p, value = false } end
        NS.SchemaRuntime.SetMany(entries, { act = "show", scope = PAGE })
    end
end

local function hiddenIn(g, field)
    local out = {}
    for _, r in ipairs(g.rows) do
        if hidden(r[field]) then out[#out + 1] = r[field] end
    end
    return out
end

local function groupMark(eye, paths, title)
    local none = #paths == 0
    return { image = eye, dimmed = none, onClick = not none and showAll(paths) or nil, title = title,
             tooltip = none and L["Nothing in this group is hidden here."]
                 or L["%d hidden. Click to show them again."]:format(#paths) }
end

local function rowMark(eye, path, name, was, where)
    return { image = eye, dimmed = was, onClick = toggle(path, was),
             title = (was and L["Show %s"] or L["Hide %s"]):format(name), tooltip = where }
end

function Rows.Render(ctx)
    Rows.ctx = ctx
    Rows.order = table.concat(NS.Blocks.Ordered(), ",")
    local scroll = H.EnsureScroll(ctx)
    if not scroll then return end
    H.TextRow(ctx, L["The first eye hides a row from the window and the detached blocks, the second from the LDB tooltip; a dimmed eye is hidden there. A row hidden from both is dimmed. A heading's eyes show its group's hidden rows again."])
    if H.AddSpacer then H.AddSpacer(scroll, 4) end
    local list = NS.OptionsList.Begin(ctx, { actionWidth = Rows.COLUMN_W, labelWidth = Rows.LABEL_W })
    local eye = NS.Icon and NS.Icon("eye")
    NS.OptionsList.Header(scroll, list, { text = "", columns = { { text = L["Window"] }, { text = L["LDB tooltip"] } } })
    for _, g in ipairs(Rows.Groups()) do
        NS.OptionsList.Header(scroll, list, { text = g.title, heading = true, columns = {
            groupMark(eye, hiddenIn(g, "windowPath"), L["Show in the window"]),
            groupMark(eye, hiddenIn(g, "tipPath"), L["Show in the LDB tooltip"]),
        } })
        for _, r in ipairs(g.rows) do
            local inWin, inTip = hidden(r.windowPath), hidden(r.tipPath)
            NS.OptionsList.Row(scroll, list, {
                text = r.name, icon = r.icon, dimmed = inWin and inTip,
                actions = {
                    rowMark(eye, r.windowPath, r.name, inWin, WINDOW_DESC),
                    rowMark(eye, r.tipPath, r.name, inTip, TIP_DESC),
                },
            })
        end
    end
    NS.OptionsList.Finish(list, scroll)
end

-- The groups follow the window's block order: a reorder (Layout > Block order's drag, `/sm set
-- layout.blocks.<id>.order`, a profile switch) redraws the page, shown now or hidden at its next
-- show (review, R5-followups). Every LAYOUT_CHANGED is checked; only a changed order renders.
local function orderChanged()
    if Rows.ctx and Rows.order ~= table.concat(NS.Blocks.Ordered(), ",") then
        Rows.order = table.concat(NS.Blocks.Ordered(), ",")
        H.RefreshPanel(Rows.ctx, true)
    end
end

if NS.NewBusTarget then
    Rows.events = NS.NewBusTarget()
    if Rows.events then Rows.events:RegisterMessage(NS.MSG.LAYOUT_CHANGED, orderChanged) end
end

NS.RegisterSchemaPage(PAGE, L["Rows"], {
    tabs = { { key = GROUP, label = GROUP, render = function(ctx) Rows.Render(ctx) end } },
    beforeRender = NS.OptionsList.Cancel,
    defaultsTooltip = L["Show every skill and stat again, in the window and in the LDB tooltip: both hidden sets are cleared, on this profile."],
})
