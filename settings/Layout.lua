local addonName, NS = ...
-- settings/Layout.lua — the Layout page (design §6.6): the main window's size and summary strip,
-- one subsection per block (show, dock, collapse, lock, scale) and the block order, dragged through
-- LibKa0s-Widgets-1.0's ReorderList (options-ui-§18).
--
-- `layout.blocks.<id>.docked`, `.collapsed` and `.order` are NS.Blocks' state (docs/ARCHITECTURE.md):
-- their rows read and write through NS.Blocks (Dock / Detach / SetCollapsed / SetOrder), so a row,
-- the block's own header and `/skm set` take one path, and a dock in combat waits as the header's
-- does. `.point` stays drag-only geometry and has no row.
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
          step = 10, label = L["Maximum window height (px)"],
          desc = L["The window grows with its rows up to this height, then scrolls."] }),
    row({ path = "layout.blockGap", group = WINDOW, type = "number", default = P.blockGap, min = 0, max = 20, step = 1,
          label = L["Block spacing (px)"], desc = L["Space between two docked blocks."] }),
    row({ path = "layout.summary", group = WINDOW, type = "bool", default = P.summary,
          label = L["Show summary strip"],
          desc = L["The line under the title: your level, this session's skill-ups and the next rank to train."] }),
})

local B = NS.Blocks

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
              set = function(v) if v then B:Dock(id) else B:Detach(id) end end }),
        row({ path = base .. "collapsed", group = BLOCKS, subgroup = d.title, type = "bool", default = def.collapsed,
              label = L["Collapse"], desc = L["Show the block's header only, as a click on it does."],
              get = function() return s().collapsed == true end,
              set = function(v) B:SetCollapsed(id, v) end }),
        row({ path = base .. "locked", group = BLOCKS, subgroup = d.title, type = "bool", default = def.locked,
              label = L["Lock this block"], desc = L["Stop the detached frame from being dragged."],
              onChange = NS.ApplyLook }),
        row({ path = base .. "scale", group = BLOCKS, subgroup = d.title, type = "number", default = def.scale,
              min = 0.5, max = 2, step = 0.05, label = L["Block scale"],
              desc = L["Scale of the block's own frame while it is detached."], onChange = NS.ApplyLook }),
        row({ path = base .. "order", group = ORDER, type = "number", default = def.order, skipRender = true,
              min = 1, max = #NS.BLOCKS, step = 1, label = L["Position: %s"]:format(d.title),
              desc = L["The block's place in the window, 1 at the top. Drag it on Layout > Block order."],
              get = function() return s().order end,
              set = function(v) B:SetOrder(id, v) end }),
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
end
NS.RegisterSchemaRows(rows)

-- ---------------------------------------------------------------------------------------------
-- The Block order tab: one draggable row per block (options-ui-§18). The controller is canceled
-- before anything is drawn, and the rows hold nothing of their own on AceGUI's frames: the label is
-- a Label widget and the handle and box are the library's, given back by Cancel.
-- ---------------------------------------------------------------------------------------------
local STRIDE, ROW_H, GUTTER = 30, 26, 36
local Order = {}
NS.OptionsBlockOrder = Order

function Order.Cancel(ctx)
    if ctx.skmReorder then ctx.skmReorder:Cancel() end
    ctx.skmReorder = nil
end

local function widgets()
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    return W and W.ReorderList and W or nil
end

local function slot(AceGUI, scroll, text, dim)
    local g = AceGUI:Create("SimpleGroup")
    g:SetLayout("Flow")
    g:SetFullWidth(true)
    g:SetHeight(STRIDE)
    local pad = AceGUI:Create("Label")
    pad:SetWidth(GUTTER)
    pad:SetText(" ")
    g:AddChild(pad)
    local label = AceGUI:Create("Label")
    label:SetText(text)
    local muted = dim and NS.Bar.Color("sm.muted")   -- a hidden block reads dimmed, in the skin's muted
    if muted and label.SetColor then label:SetColor(muted[1], muted[2], muted[3]) end
    g:AddChild(label)
    scroll:AddChild(g)
    return g
end

function Order.Render(ctx)
    Order.Cancel(ctx)
    local AceGUI = NS.AceGUI or (LibStub and LibStub("AceGUI-3.0", true))
    local scroll = H.EnsureScroll(ctx)
    if not (AceGUI and scroll) then return end
    H.TextRow(ctx, L["Drag a block by its handle to move it. Hidden blocks keep their place."])
    local W = widgets()
    local list = W and W.ReorderList({
        stride = STRIDE, owner = addonName, handleIcon = NS.Icon and NS.Icon("move") or nil,
        handleTooltip = L["Drag to reorder"],
        onMove = function(from, to)
            if B:Move(from, to) then H.RefreshPanel(ctx, true) end
        end,
    })
    ctx.skmReorder = list
    for _, id in ipairs(B.Ordered()) do
        local hidden = B.Settings(id).shown == false
        local g = slot(AceGUI, scroll, NS.BlockDefs[id].title, hidden)
        if list then list:AddRow(g.frame, { ghostText = NS.BlockDefs[id].title, height = ROW_H, dimmed = hidden }) end
    end
    if list then list:Finish(scroll.content or scroll.frame) end
end

NS.RegisterSchemaPage(PAGE, L["Layout"], {
    tabs = { { key = ORDER, label = ORDER, render = function(ctx) Order.Render(ctx) end } },
    beforeRender = Order.Cancel,
    defaultsTooltip = L["Restore every Layout setting on this profile to its default: the window, every block and the block order."],
})
