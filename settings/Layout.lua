local _, NS = ...
-- settings/Layout.lua — the Layout page (design §6.6): the main window's size and summary strip,
-- one subsection per block (show, dock, collapse, lock, scale), the detached windows' shared style
-- (round 5) and the block order, dragged through LibKa0s-Widgets-1.0's ReorderList (options-ui-§18).
--
-- `layout.blocks.<id>.docked`, `.collapsed` and `.order` are written only through NS.SetByPath
-- (architecture-§5): the block header, the detached frame's buttons, the drag list and `/sm set`
-- all call the seam, and the rows' `set` (NS.Blocks.StoreDocked / StoreCollapsed, which wait out
-- combat) or plain store (order, its onChange NS.Blocks.OrderChanged) does the rest. `.point`
-- stays drag-only geometry and has no row.
local H = NS.Helpers
local L = NS.L
local P = NS.defaults.profile.layout
local PAGE = "layout"
local WINDOW, BLOCKS, ORDER = L["Window"], L["Blocks"], L["Block order"]

local function row(t)
    t.page = PAGE
    return t
end

local rows = NS.Live({
    row({ path = "layout.width", group = WINDOW, type = "number", default = P.width, min = 320, max = 800, step = 10,
          label = L["Window width (px)"],
          desc = L["Width of the Skill Master window. Multiplied by Master scale on General > Master controls."] }),
    row({ path = "layout.maxHeight", group = WINDOW, type = "number", default = P.maxHeight, min = 200, max = 1200,
          step = 10, label = L["Window height (px)"],
          desc = L["Height of the Skill Master window; the rows scroll inside it."] }),
    row({ path = "layout.fitHeight", group = WINDOW, type = "bool", default = P.fitHeight,
          label = L["Shrink to fit the rows"],
          desc = L["Shrink the window when its rows take less than Window height, so it grows and shrinks as blocks expand and collapse."] }),
    row({ path = "layout.blockGap", group = WINDOW, type = "number", default = P.blockGap, min = 0, max = 20, step = 1,
          label = L["Block spacing (px)"], desc = L["Space between two docked blocks."] }),
    row({ path = "layout.summary", group = WINDOW, type = "bool", default = P.summary,
          label = L["Show summary strip"],
          desc = L["The line under the title: your level, this session's skill-ups and the next rank to train."] }),
    row({ path = "layout.columns", group = WINDOW, type = "number", default = P.columns,
          values = { { value = 1, text = L["One column"] }, { value = 2, text = L["Two columns"] } },
          label = L["Columns"],
          desc = L["Lay the docked blocks in one column, or in two side by side. Each column is Window width wide."] }),
})

-- The player's strata (frame-layering-§1): four values, and the library's one tooltip over them.
local STRATA = NS.Constants.LAYERS.STRATA_CHOICES
local STRATA_TEXT = { BACKGROUND = L["Background"], LOW = L["Low"], MEDIUM = L["Medium"], HIGH = L["High"] }
local strataValues = {}
for i, s in ipairs(STRATA) do strataValues[i] = { value = s, text = STRATA_TEXT[s] } end
local function strataDesc(what)
    local tip = H.StrataTooltip and H.StrataTooltip(STRATA) or ""
    return tip ~= "" and (what .. " " .. tip) or what
end
-- The window's own apply re-reads every stored look and re-syncs the crafting overlays.
local function applyWindow()
    if NS.MainWindow then NS.MainWindow.ApplySettings() end
    NS.ApplyLook()
end
rows[#rows + 1] = row({ path = "layout.strata", group = WINDOW, type = "string", default = P.strata,
    values = strataValues, label = L["Window strata"], onChange = applyWindow,
    desc = strataDesc(L["The Skill Master window's layer."]) })
NS.Live(rows)

-- ---------------------------------------------------------------------------------------------
-- The Detached windows tab (round 5, R5-7): one style for every detached window, and for a merged
-- group's window (modules/Detached.lua D.ApplyStyle). Every row's onChange is NS.ApplyLook: the
-- LAYOUT_CHANGED it sends re-renders every open detached window. The background is a background
-- swatch and its class companion (options-ui-§16: a group over a background is not a bar group), the
-- border the composed border block; each takes a "Use the skin's ..." companion, on by default
-- (skinning-§6). The strata row moved here from the Window tab (same path, nothing migrated).
-- ---------------------------------------------------------------------------------------------
local DETACHED = L["Detached windows"]
local PD = P.detached
local DWIN = L["Window"]
local classColor = { source = "player" }
local function detached(t)
    t.group, t.subgroup = DETACHED, t.subgroup or DWIN
    return row(t)
end
-- Appended after the Blocks rows, so the tab follows the Blocks tab.
local detachedRows = {}
local function add(list)
    for _, r in ipairs(list) do detachedRows[#detachedRows + 1] = r end
end

add(NS.Live({
    detached({ path = "layout.detached.scale", type = "number", default = PD.scale, min = 0.5, max = 2, step = 0.05,
               label = L["Window scale"], commitOn = "change",
               desc = L["Scale of every detached window. Multiplies each block's own Block scale (Blocks tab)."] }),
    detached({ path = "layout.detached.alpha", type = "number", default = PD.alpha, min = 0, max = 1, step = 0.05,
               label = L["Window opacity"], commitOn = "change",
               desc = L["Opacity of every detached window, its rows and title band included."] }),
    detached({ path = "layout.detached.titleBand", type = "string", default = PD.titleBand,
               label = L["Title band"],
               desc = L["When a detached window shows its title band and its marks: always, only while the pointer is over the window, or never. With Never, a thin strip at the top stays the drag area; dock and collapse the block from the Blocks tab."],
               values = { { value = "always", text = L["Always"] }, { value = "hover", text = L["On hover"] },
                          { value = "never", text = L["Never"] } } }),
    detached({ path = "layout.detachedStrata", type = "string", default = P.detachedStrata,
               values = strataValues, label = L["Detached block strata"],
               desc = strataDesc(L["The layer every detached block's frame draws in."]) }),
}))

--- A "Use the skin's ..." companion for a composed block's `extra` (skinning-§6).
local function fromSkin(path, label, desc)
    return { path = path, page = PAGE, type = "bool", default = true, label = label, desc = desc }
end

add(NS.Live(H.ColorPair({
    prefix = "layout.detached.", page = PAGE, group = DETACHED, subgroup = L["Background"],
    key = "bgColor", companionKey = "useClassColorBg", label = L["Background color"],
    classColor = classColor,
    tooltips = { bgColor = L["The fill behind a detached window's rows. Not read while Use the skin's background is on."] },
    defaults = { bgColor = PD.bgColor, useClassColorBg = PD.useClassColorBg },
    extra = { fromSkin("layout.detached.bgFromSkin", L["Use the skin's background"],
        L["Fill every detached window as the skin fills its windows. Background color is not read while this is on."]) },
})))

add(NS.Live(H.BorderGroup({
    prefix = "layout.detached.", page = PAGE, group = DETACHED, subgroup = L["Border"], show = true,
    classColor = classColor, keys = { borderShow = "border" },
    tooltips = { borderColor = L["The edge of a detached window. Not read while Use the skin's border is on."] },
    defaults = { borderShow = PD.border, borderStyle = PD.borderStyle, borderSize = PD.borderSize,
                 borderColor = PD.borderColor, useClassColorBorder = PD.useClassColorBorder },
    extra = { fromSkin("layout.detached.borderFromSkin", L["Use the skin's border"],
        L["Edge every detached window as the skin edges its windows. Border style, thickness and color are not read while this is on."]) },
})))

local B = NS.Blocks
local sortValues = {}
for i, m in ipairs(B.SORTS) do sortValues[i] = { value = m, text = B.SORT_LABEL[m] } end
local filterValues = {}
for i, m in ipairs(B.FILTERS) do filterValues[i] = { value = m, text = B.FILTER_LABEL[m] } end

local function blockRows(id)
    local d, def = NS.BlockDefs[id], P.blocks[id]
    local base = "layout.blocks." .. id .. "."
    local function s() return B.Settings(id) end
    return {
        row({ path = base .. "shown", group = BLOCKS, subgroup = d.title, type = "bool", default = def.shown,
              label = L["Show this block"], desc = L["Show this block in the window, or in its own frame while detached."],
              onChange = NS.ApplyLook }),
        row({ path = base .. "docked", group = BLOCKS, subgroup = d.title, type = "bool", default = def.docked,
              label = L["Dock in the window"],
              desc = L["Off pops the block out into a frame of its own, as its header's detach button does."],
              get = function() return s().docked ~= false end,
              set = function(v) B.StoreDocked(id, v) end }),
        row({ path = base .. "collapsed", group = BLOCKS, subgroup = d.title, type = "bool", default = def.collapsed,
              label = L["Collapse"], desc = L["Show the block's header only, as a click on it does."],
              get = function() return s().collapsed == true end,
              set = function(v) B.StoreCollapsed(id, v) end }),
        row({ path = base .. "locked", group = BLOCKS, subgroup = d.title, type = "bool", default = def.locked,
              label = L["Lock this block"], desc = L["Stop the detached frame from being dragged."],
              onChange = NS.ApplyLook }),
        row({ path = base .. "sort", group = BLOCKS, subgroup = d.title, type = "string", default = def.sort,
              values = sortValues, label = L["Sort rows by"], onChange = B.Changed,
              desc = L["The order of the block's rows, here, in its detached frame and in the LDB tooltip. The sort mark on its header cycles it."] }),
        row({ path = base .. "scale", group = BLOCKS, subgroup = d.title, type = "number", default = def.scale,
              min = 0.5, max = 2, step = 0.05, label = L["Block scale"],
              desc = L["Scale of the block's own frame while it is detached."], onChange = NS.ApplyLook }),
        row({ path = base .. "order", group = ORDER, type = "number", default = def.order, skipRender = true,
              min = 1, max = #NS.BLOCKS, step = 1, label = L["Position: %s"]:format(d.title),
              desc = L["The block's place in the window, 1 at the top. Drag it on Layout > Block order."],
              normalize = function(v) v = tonumber(v) return v and math.floor(v) or nil end,
              onChange = B.OrderChanged }),
    }
end

for _, id in ipairs(NS.BLOCKS) do
    for _, r in ipairs(blockRows(id)) do rows[#rows + 1] = r end
    -- The weapon block's own filter for its detached compact preset (Detached.dc.html).
    if P.blocks[id].belowCapOnly ~= nil then
        rows[#rows + 1] = row({ path = "layout.blocks." .. id .. ".belowCapOnly", group = BLOCKS,
            subgroup = NS.BlockDefs[id].title, type = "bool", default = P.blocks[id].belowCapOnly,
            label = L["Equipped and below cap only"],
            desc = L["While detached, list only the weapons you have equipped and the skills still below their cap."],
            onChange = NS.ApplyLook })
    end
    -- The header's filter mark (round 5, R5-10): the weapon block's row filter.
    if B.FILTERABLE[id] then
        rows[#rows + 1] = row({ path = "layout.blocks." .. id .. ".filter", group = BLOCKS,
            subgroup = NS.BlockDefs[id].title, type = "string", default = P.blocks[id].filter,
            values = filterValues, label = L["Show rows"], onChange = B.Changed,
            desc = L["Which of the block's rows show, here, in its detached frame and in a merged window: all of them, the skills you have learned, the weapons you have equipped (main hand, off hand, ranged), or the learned skills still below their cap. The filter mark on its header picks it. The LDB tooltip is not filtered."] })
    end
end
for _, r in ipairs(detachedRows) do rows[#rows + 1] = r end
NS.RegisterSchemaRows(rows)

-- ---------------------------------------------------------------------------------------------
-- The Block order tab: one boxed, draggable row per block (options-ui-§18), drawn as ConsumableMaster's
-- Priority list is (settings/BoxList.lua, feedback round 2): the handle, the block's name, and an eye
-- that shows or hides it (Blocks > Show this block). The controller is canceled before anything is
-- drawn (the page's beforeRender).
-- ---------------------------------------------------------------------------------------------
local Order = {}
NS.OptionsBlockOrder = Order

function Order.Cancel(ctx) NS.OptionsList.Cancel(ctx) end

local function toggleShown(ctx, id)
    return function()
        local path = "layout.blocks." .. id .. ".shown"
        if NS.SetByPath(path, B.Settings(id).shown == false) then H.RefreshPanel(ctx, true) end
    end
end

function Order.Render(ctx)
    local scroll = H.EnsureScroll(ctx)
    if not scroll then return end
    H.Section(ctx, ORDER)
    H.TextRow(ctx, L["Drag a block by its handle to move it. The eye shows or hides it; a hidden block keeps its place."])
    if H.AddSpacer then H.AddSpacer(scroll, 4) end
    local list = NS.OptionsList.Begin(ctx, {
        onMove = function(from, to)
            if B:Move(from, to) then H.RefreshPanel(ctx, true) end
        end,
    })
    local eye = NS.Icon and NS.Icon("eye")
    for _, id in ipairs(B.Ordered()) do
        local hidden = B.Settings(id).shown == false
        NS.OptionsList.Row(scroll, list, {
            text = NS.BlockDefs[id].title, dimmed = hidden,
            actions = { {
                image = eye, dimmed = hidden, onClick = toggleShown(ctx, id),
                title = hidden and L["Show this block"] or L["Hide this block"],
                tooltip = L["Show this block in the window, or in its own frame while detached."],
            } },
        })
    end
    NS.OptionsList.Finish(list, scroll)
end

NS.RegisterSchemaPage(PAGE, L["Layout"], {
    tabs = { { key = ORDER, label = ORDER, render = function(ctx) Order.Render(ctx) end } },
    beforeRender = Order.Cancel,
    defaultsTooltip = L["Restore every Layout setting on this profile to its default: the window, every block and the block order."],
})
