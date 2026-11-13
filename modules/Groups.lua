local addonName, NS = ...
-- modules/Groups.lua — merged detached windows (owner feedback round 5, R5-6): two or more detached
-- blocks drawn as ONE window. The model, its one owner and the merged window's frame.
--
-- A group is profile.layout.groups[gid] = { point = { point, relPoint, x, y } | false,
-- columns = { { id, id, ... }, ... } }: ordered columns side by side, each an ordered list of block
-- ids stacked top to bottom. Membership is derived from the groups (a block is in at most one), and a
-- member is always a detached block (layout.blocks.<id>.docked false). A group of one is no group:
-- it dissolves, and its last block is a plain detached window again, at its own stored point
-- (layout.blocks.<id>.point, kept while it is grouped). Docking a block (NS.Blocks.StoreDocked)
-- takes it out of its group. layout.groups is named non-setting state (architecture-§5): this module
-- is its one owner and every write goes through it (Merge, Split, Unmerge, Leave, the header drag's
-- savePoint, and the normalization that drops a member no longer detached).
--
-- The merged window: one title band whose title joins the sections' short names
-- (NS.BlockDefs[id].short) with " · ", truncated to the band; its marks Collapse all (the chevron)
-- and Dock all (the attach mark, external-link turned 180, as on a detached window). Each section
-- has a sub-header: its chevron, title, sort mark (the block's sort cycle) and split mark
-- (fullscreen-enter: pop the section out as its own window, placed beside the group). A right-click
-- on a sub-header or the band opens the menu: Split from the group, Unmerge all, Dock in the main
-- window, Dock all in the main window. The window takes the shared Detached windows style
-- (NS.Detached.ApplyStyle, R5-7) and moves by its band (the frame is the drag area, as a detached
-- window's is). Merges, splits and unmerges move rows the crafting overlays are synced over, so in
-- combat they wait (NS.SecureOverlay:AfterCombat); the overlays scan this window's rows and follow it.
--
-- The drag that merges (a window dragged to another's side) and drags a section out is
-- modules/GroupsSnap.lua's; it calls the API below.
--
-- NS.Groups.Model: the pure model over a plain groups table (the suites drive it headless):
--   .Find(groups, id) -> gid, col, index / .Members(group) / .Ids(groups) / .NewId(groups)
--   .Merge(groups, dragged, target, side, col) -> gid / .Split(groups, gid, id) / .Remove(groups, id)
--   .Normalize(groups, valid)
-- NS.Groups.Merge(dragged, target, side, opts) -> gid | false (waits for combat) | nil (refused)
-- NS.Groups.Split(gid, id, point) / .Unmerge(gid) / .Leave(id) / .DockAll(gid) / .CollapseAll(gid)
-- NS.Groups.Of(id) / .All() / .Columns(gid) / .Members(gid) / .Title(gid)
-- NS.Groups.Refresh(anchor) / .Render(gid) / .RefreshValues() / .StandDown() / .Frame(gid) /
--   .Rows(gid) / .Shown() / .Section(gid, id) / .MenuRows(gid, id) / .Menu(gid, id)
-- The drag's reads (modules/GroupsSnap.lua): .UIRect(f) / .PointAt(x, y, scale) / .BlockScale(id) /
--   .IsLocked(gid) / .SavePoint(f)

NS.Groups = {}
local G = NS.Groups
local L = NS.L
local LAYERS = NS.Constants.LAYERS
local Perf = NS.Perf

G.SIDES = { top = true, bottom = true, left = true, right = true }
G.SUB_H = 20       -- a section's sub-header, px
G.GAP = 8          -- px between a group and the section split out beside it
G.SEPARATOR = " \194\183 "   -- between two short names in the title

-- ---------------------------------------------------------------------------------------------
-- The pure model: plain tables in, plain tables out (no frame, no profile)
-- ---------------------------------------------------------------------------------------------

local M = {}
G.Model = M

--- The group ids of `groups`, sorted (a stable order to draw and report in).
function M.Ids(groups)
    local out = {}
    for gid in pairs(groups or {}) do out[#out + 1] = gid end
    table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
    return out
end

--- The first free id: "g1", "g2", ...
function M.NewId(groups)
    local n = 1
    while groups["g" .. n] ~= nil do n = n + 1 end
    return "g" .. n
end

--- Where block `id` sits: its group's id, its column and its place in the column; nil when lone.
function M.Find(groups, id)
    for _, gid in ipairs(M.Ids(groups)) do
        local g = groups[gid]
        for c, col in ipairs(type(g) == "table" and type(g.columns) == "table" and g.columns or {}) do
            for i, member in ipairs(type(col) == "table" and col or {}) do
                if member == id then return gid, c, i end
            end
        end
    end
    return nil
end

--- A group's block ids, column by column, top to bottom.
function M.Members(g)
    local out = {}
    for _, col in ipairs(g and g.columns or {}) do
        for _, id in ipairs(col) do out[#out + 1] = id end
    end
    return out
end

--- Take block `id` out of whatever group holds it (its column may be left empty: Normalize drops
--- it). Answers the group it left.
function M.Remove(groups, id)
    local gid, c, i = M.Find(groups, id)
    if gid then table.remove(groups[gid].columns[c], i) end
    return gid
end

local function copyColumns(cols)
    local out = {}
    for c, col in ipairs(cols) do
        out[c] = {}
        for i, id in ipairs(col) do out[c][i] = id end
    end
    return out
end

--- Merge `dragged` (a block id or a group id) into `target` (a block id, lone or grouped, or a group
--- id) on `side`: "top" / "bottom" stack the dragged blocks at the top or the bottom of the target's
--- column `col` (a grouped target block's own column by default, else the first), "left" / "right"
--- add the dragged window's columns before the first or after the last. A dragged group merges whole
--- and is gone after; a lone target becomes a new group. Answers the target group's id, or nil for a
--- refusal (an unknown side, a window merged into itself). Normalize afterwards.
function M.Merge(groups, dragged, target, side, col)
    if not G.SIDES[side] or dragged == nil or target == nil or dragged == target then return nil end
    local draggedGroup = type(groups[dragged]) == "table"
    local targetGid = type(groups[target]) == "table" and target or nil
    local targetCol
    if not targetGid then
        local gid, c = M.Find(groups, target)
        targetGid, targetCol = gid, c
    end
    if draggedGroup and targetGid == dragged then return nil end
    local cols
    if draggedGroup then
        cols = copyColumns(groups[dragged].columns)
        groups[dragged] = nil
    else
        -- A block already in the target's group moves within it (its old place emptied first).
        M.Remove(groups, dragged)
        cols = { { dragged } }
    end
    if not targetGid then
        targetGid = M.NewId(groups)
        groups[targetGid] = { point = false, columns = { { target } } }
        targetCol = 1
    end
    local tcols = groups[targetGid].columns
    if side == "left" then
        for i = #cols, 1, -1 do table.insert(tcols, 1, cols[i]) end
    elseif side == "right" then
        for _, c in ipairs(cols) do tcols[#tcols + 1] = c end
    else
        local c = math.max(1, math.min(tonumber(col) or targetCol or 1, #tcols))
        local flat = M.Members({ columns = cols })
        local into = tcols[c]
        if side == "top" then
            for i = #flat, 1, -1 do table.insert(into, 1, flat[i]) end
        else
            for _, id in ipairs(flat) do into[#into + 1] = id end
        end
    end
    return targetGid
end

--- Take block `id` out of group `gid`. Answers whether it was there. Normalize afterwards (a group
--- left with one block dissolves).
function M.Split(groups, gid, id)
    if M.Find(groups, id) ~= gid then return false end
    M.Remove(groups, id)
    return true
end

--- Make `groups` well formed, in place: a malformed group goes; a member `valid(id)` refuses (an
--- unknown or docked block), or already seen in an earlier group, is dropped; an empty column goes;
--- a group left with fewer than two blocks dissolves. Answers `groups`.
function M.Normalize(groups, valid)
    local seen = {}
    for _, gid in ipairs(M.Ids(groups)) do
        local g = groups[gid]
        local cols, n, dropped = {}, 0, false
        if type(g) == "table" and type(g.columns) == "table" then
            for _, col in ipairs(g.columns) do
                local keep = {}
                for _, id in ipairs(type(col) == "table" and col or {}) do
                    if type(id) == "string" and not seen[id] and (not valid or valid(id)) then
                        seen[id] = true
                        keep[#keep + 1] = id
                    else
                        dropped = true
                    end
                end
                if #keep > 0 then cols[#cols + 1] = keep; n = n + #keep else dropped = true end
                if type(col) ~= "table" or #keep ~= #col then dropped = true end
            end
        end
        if n < 2 then
            groups[gid] = nil
        else
            -- Rebuilt only when something went: a well-formed group keeps its tables.
            if dropped then g.columns = cols end
            if type(g.point) ~= "table" then g.point = false end
        end
    end
    return groups
end

-- ---------------------------------------------------------------------------------------------
-- The owner: profile.layout.groups, written here alone
-- ---------------------------------------------------------------------------------------------

local function store()
    local layout = NS.db and NS.db.profile.layout
    if not layout then return {} end
    if type(layout.groups) ~= "table" then layout.groups = {} end
    return layout.groups
end

local function valid(id)
    local s = NS.Blocks.Settings(id)
    return s ~= nil and s.docked == false
end

--- The stored groups, normalized (a member docked by any path leaves it here).
function G.All() return M.Normalize(store(), valid) end

--- The group block `id` is merged into, or nil.
function G.Of(id)
    return (M.Find(G.All(), id))
end

function G.Columns(gid)
    local g = G.All()[gid]
    return g and g.columns or {}
end

function G.Members(gid) return M.Members(G.All()[gid]) end

--- The window's title: its sections' short names joined by " · ".
function G.Title(gid)
    local parts = {}
    for _, id in ipairs(G.Members(gid)) do
        local d = NS.BlockDefs[id]
        parts[#parts + 1] = d and d.short or id
    end
    return table.concat(parts, G.SEPARATOR)
end

local function whenSafe(key, fn)
    local SO = NS.SecureOverlay
    if SO and SO.AfterCombat then return SO:AfterCombat(key, fn) end
    fn()
    return true
end

local function changed() NS.Blocks.Changed() end

-- ---------------------------------------------------------------------------------------------
-- Geometry: rects in UIParent units, points against UIParent's bottom-left. A client that answers no
-- number (the suites' frames) or a secret one gets the stored-point fallbacks.
-- ---------------------------------------------------------------------------------------------

local function plain(v)
    return type(v) == "number" and not (type(issecretvalue) == "function" and issecretvalue(v))
end

-- The frame's left, top, right and bottom in UIParent units, or nil.
local function uiRect(f)
    if not f then return nil end
    local l, t, r, b = f:GetLeft(), f:GetTop(), f:GetRight(), f:GetBottom()
    local es, us = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not (plain(l) and plain(t) and plain(r) and plain(b) and plain(es) and plain(us)) or us == 0 then return nil end
    local k = es / us
    return l * k, t * k, r * k, b * k
end
G.UIRect = uiRect   -- the snapping driver reads it

-- A point for a frame of relative scale `scale` whose top-left lands at (x, y) UIParent units.
local function pointAt(x, y, scale)
    scale = (plain(scale) and scale > 0) and scale or 1
    return { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = x / scale, y = y / scale }
end

local function groupScale() return tonumber(NS.Detached.Style().scale) or 1 end

local function blockScale(id)
    return (tonumber(NS.Blocks.Settings(id).scale) or 1) * groupScale()
end
G.PointAt, G.BlockScale = pointAt, blockScale   -- a section dragged out lands at its drop (GroupsSnap)

local function copyPoint(p)
    if type(p) ~= "table" then return false end
    return { point = p.point, relPoint = p.relPoint or p.point, x = tonumber(p.x) or 0, y = tonumber(p.y) or 0 }
end

-- A stored point in the pointAt form (offsets from UIParent's bottom-left to the top-left), or nil.
local function topLeft(p)
    if type(p) == "table" and p.point == "TOPLEFT" and p.relPoint == "BOTTOMLEFT" then return p end
    return nil
end

local frames = {}     -- [gid] = the merged window drawing it
local spare = {}      -- frames whose group went, for the next group

function G.Frame(gid) return frames[gid] end

-- The window `target` (a block id or a group id) is on screen as.
local function windowOf(target)
    if frames[target] then return frames[target] end
    local gid = G.Of(target)
    if gid and frames[gid] then return frames[gid] end
    return NS.Detached.Frame(target)
end

-- How tall block `id` stands as a section of a merged window, unscaled: its sub-header and, unless
-- collapsed, its rows as drawn now (in its merged window, else in its own).
local function sectionExtent(id)
    local gid = G.Of(id)
    local sec = gid and frames[gid] and frames[gid].sections and frames[gid].sections[id]
    if sec and plain(sec.h) then return sec.h end
    if NS.Blocks.Settings(id).collapsed then return G.SUB_H end
    local f = NS.Detached.Frame(id)
    local h = f and f.rowsH
    return G.SUB_H + (plain(h) and h or 0)
end

-- The height `dragged` (a block or a group, flattened into one column) adds on top of a column.
local function stackedExtent(dragged)
    local g = G.All()[dragged]
    local h = 0
    for _, id in ipairs(g and M.Members(g) or { dragged }) do h = h + sectionExtent(id) end
    return h
end

-- Where a group made or widened by a merge sits: the target window's top-left (`rect`, measured
-- before the merge moved anything), moved left by the columns added on the left or up by the
-- sections stacked on top (`stacked`), so the target stays where it is.
local function mergePoint(groups, gid, target, side, before, rect, stacked)
    local tl, tt = rect and rect[1], rect and rect[2]
    local gs = groupScale()
    if tl then
        if side == "left" then
            local added = #(groups[gid].columns) - before
            tl = tl - added * NS.Detached.WIDTH * gs
        elseif side == "top" then
            tt = tt + stacked * gs
        end
        return pointAt(tl, tt, gs)
    end
    -- No geometry: a new group keeps the target's own point; an old one stays where it was.
    local g = groups[gid]
    if g.point then return g.point end
    local own = frames[target] == nil and NS.Blocks.Settings(target)
    return copyPoint(own and own.point)
end

--- Merge `dragged` (a detached block or a group) into `target` (a detached block, grouped or not,
--- or a group) on `side` ("top" | "bottom" | "left" | "right"). `opts.col` is the target column a
--- top or bottom merge stacks into, `opts.point` the group's point (else the target stays put).
--- Answers the group's id; false when it waits for the end of combat; nil when refused.
function G.Merge(dragged, target, side, opts)
    opts = opts or {}
    if not G.SIDES[side] then return nil end
    local function known(x) return x ~= nil and (G.All()[x] ~= nil or valid(x)) end
    if not (known(dragged) and known(target)) then return nil end
    local result
    -- One queued request per dragged window (a second drop in the same combat keeps the first's).
    local ran = whenSafe("group:merge:" .. tostring(dragged), function()
        local groups = G.All()
        local tg = groups[target] and target or M.Find(groups, target)
        local before = tg and #groups[tg].columns or 1
        -- Measured before the model moves anything: after it, windowOf(dragged) is the target's.
        local rect = { uiRect(windowOf(target)) }
        local stacked = side == "top" and stackedExtent(dragged) or 0
        local gid = M.Merge(groups, dragged, target, side, opts.col)
        if not gid then return end
        M.Normalize(groups, valid)
        if groups[gid] then
            groups[gid].point = copyPoint(opts.point) or mergePoint(groups, gid, target, side, before, rect, stacked)
                or false
        end
        result = groups[gid] and gid or nil
        NS.Debug("Layout", "merged %s into %s (%s): %s", tostring(dragged), tostring(gid), side, G.Title(gid))
        changed()
    end)
    if not ran then return false end
    return result
end

-- Where section `id` of group `gid` stands now, as its own window's point: the section's top-left
-- (the drawn sub-header's, else the stored group point plus the section's column and place).
local function sectionPoint(gid, id)
    local f, bs = frames[gid], blockScale(id)
    local sec = f and f.sections and f.sections[id]
    local l, t = uiRect(sec and sec.header)
    if l then return pointAt(l, t, bs) end
    local gp = topLeft((G.All()[gid] or {}).point)
    if not (gp and sec) then return nil end
    local gs = groupScale()
    return pointAt((gp.x + (sec.col - 1) * NS.Detached.WIDTH) * gs, (gp.y - (f.top or 0) - sec.y) * gs, bs)
end

-- Beside the group, right of its last column, level with the section.
local function besidePoint(gid, id)
    local f, bs = frames[gid], blockScale(id)
    local sec = f and f.sections and f.sections[id]
    local _, t, r = uiRect(f)
    local _, st = uiRect(sec and sec.header)
    if r then return pointAt(r + G.GAP, st or t, bs) end
    local gp = topLeft((G.All()[gid] or {}).point)
    if not gp then return nil end
    local gs = groupScale()
    local cols = #G.Columns(gid)
    local y = gp.y - ((f and f.top or 0) + (sec and sec.y or 0))
    return pointAt((gp.x + cols * NS.Detached.WIDTH + G.GAP) * gs, y * gs, bs)
end

--- Pop section `id` out of group `gid` as its own detached window at `point` (the drop point of a
--- sub-header dragged out), else beside the group. A group left with one section dissolves. Answers
--- true when done, false when it waits for the end of combat, nil when `id` is not in `gid`.
function G.Split(gid, id, point)
    if G.Of(id) ~= gid then return nil end
    return whenSafe("group:split:" .. id, function()
        local p = point or besidePoint(gid, id)   -- read while the group still stands
        local groups = G.All()
        if not M.Split(groups, gid, id) then return end
        if p then NS.Detached.StorePoint(id, p) end
        M.Normalize(groups, valid)
        NS.Debug("Layout", "split %s from %s", id, gid)
        changed()
    end)
end

--- Unmerge group `gid`: every section its own detached window where it stands now. Answers true when
--- done, false when it waits for the end of combat, nil for no such group.
function G.Unmerge(gid)
    if not G.All()[gid] then return nil end
    return whenSafe("group:unmerge:" .. gid, function()
        local groups = G.All()
        for _, id in ipairs(M.Members(groups[gid])) do
            local p = sectionPoint(gid, id)
            if p then NS.Detached.StorePoint(id, p) end
        end
        groups[gid] = nil
        NS.Debug("Layout", "unmerged %s", gid)
        changed()
    end)
end

--- Block `id` leaves its group, quietly (NS.Blocks.StoreDocked: the dock's own LAYOUT_CHANGED follows).
function G.Leave(id)
    local groups = store()
    local gid = M.Remove(groups, id)
    M.Normalize(groups, valid)
    return gid
end

--- Dock every section of group `gid` in the main window (the Dock all mark and menu row).
function G.DockAll(gid) return NS.Blocks:DockAll(G.Members(gid)) end

--- Collapse every section of group `gid`, or expand them all when every one is collapsed already.
function G.CollapseAll(gid)
    local ids = G.Members(gid)
    local any = false
    for _, id in ipairs(ids) do
        if not NS.Blocks.Settings(id).collapsed then any = true end
    end
    return NS.Blocks:SetCollapsedFor(ids, any)
end

-- ---------------------------------------------------------------------------------------------
-- The right-click menu (LibKa0s-Widgets-1.0 ContextMenu, as the row menu: modules/Interact.lua)
-- ---------------------------------------------------------------------------------------------

--- The menu's rows for group `gid`, opened on section `id`'s sub-header (nil: on the band).
function G.MenuRows(gid, id)
    local d = id and NS.BlockDefs[id]
    return {
        { title = true, label = d and d.title or G.Title(gid) },
        { value = "split", label = L["Split from the group"], disabled = id == nil,
          onClick = function() if id then G.Split(gid, id) end end },
        { value = "unmerge", label = L["Unmerge all"], onClick = function() G.Unmerge(gid) end },
        { value = "dock", label = L["Dock in the main window"], disabled = id == nil,
          onClick = function() if id then NS.Blocks:Dock(id) end end },
        { value = "dockAll", label = L["Dock all in the main window"], onClick = function() G.DockAll(gid) end },
    }
end

function G.Menu(gid, id, anchor)
    G.menu = NS.Widgets.ContextMenu(anchor or frames[gid], G.MenuRows(gid, id), { owner = addonName, cursor = true })
    return G.menu
end

-- ---------------------------------------------------------------------------------------------
-- The merged window
-- ---------------------------------------------------------------------------------------------

local function isLocked(gid)
    if NS.GetSetting("locked") then return true end
    for _, id in ipairs(G.Members(gid)) do
        if NS.Blocks.Settings(id).locked == true then return true end
    end
    return false
end
G.IsLocked = isLocked

-- The header drag's writer of the group's point.
local function savePoint(f)
    local g = f.gid and store()[f.gid]
    if not g then return end
    local l, t = uiRect(f)
    if l then g.point = pointAt(l, t, groupScale()) return end
    local point, _, relPoint, x, y = f:GetPoint(1)
    if type(point) ~= "string" then return end
    g.point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end
G.SavePoint = savePoint   -- the snapping driver's drop calls it

local function onDragStart(f)
    if not f.gid or isLocked(f.gid) then return end
    f:StartMoving()
    f.dragging = true
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(f, true) end
    -- The drag that merges: this window dropped on another's side (modules/GroupsSnap.lua).
    if NS.GroupsSnap then NS.GroupsSnap.BeginWindow(f, f.gid) end
end

local function onDragStop(f)
    if not f.dragging then return end
    f.dragging = nil
    f:StopMovingOrSizing()
    savePoint(f)
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(f, false) end
    if NS.GroupsSnap then NS.GroupsSnap.Drop() end
end
G.OnDragStart, G.OnDragStop = onDragStart, onDragStop

local function applyPoint(f, g)
    local p = g.point
    f:ClearAllPoints()
    if type(p) == "table" and type(p.point) == "string" then
        f:SetPoint(p.point, UIParent, p.relPoint or p.point, tonumber(p.x) or 0, tonumber(p.y) or 0)
    else
        f:SetPoint("TOPLEFT", UIParent, "CENTER", 240, 200)
    end
    f:SetFrameStrata(NS.Detached.Strata())
end

local function paintSubBg(sh)
    local c = NS.Bar.Color("sm.headerBg")
    if c then sh.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

local function onSubClick(sh, button)
    local f = sh.owner
    if button == "RightButton" then G.Menu(f.gid, sh.id, sh) return end
    NS.Blocks:ToggleCollapsed(sh.id)
end

-- A sub-header dragged out of the window splits its section off past the leeway (GroupsSnap).
local function onSubDragStart(sh)
    local f = sh.owner
    if not (f.gid and sh.id) or isLocked(f.gid) or not NS.GroupsSnap then return end
    NS.GroupsSnap.BeginSection(sh, f.gid, sh.id)
end

local function onSubDragStop()
    if NS.GroupsSnap then NS.GroupsSnap.Drop() end
end

-- A section's sub-header: chevron, title, filter mark (the weapon block's, round 5, R5-10), sort
-- mark, split mark; and the muted line an emptied filter shows under it.
local function buildSub(f)
    local sh = CreateFrame("Button", nil, f.body)
    sh.owner = f
    sh:SetHeight(G.SUB_H)
    sh:RegisterForClicks("AnyUp")
    sh.bg = sh:CreateTexture(nil, "BACKGROUND")
    sh.bg:SetAllPoints(sh)
    sh.chevron = NS.Chrome.HeaderMark(sh, "chevron-down", "v", function() NS.Blocks:ToggleCollapsed(sh.id) end)
    sh.chevron:SetPoint("LEFT", sh, "LEFT", 4, 0)
    sh.title = sh:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sh.title:SetPoint("LEFT", sh.chevron, "RIGHT", 2, 0)
    NS.Skin.Text(sh.title, "heading")
    sh.split = NS.Chrome.HeaderMark(sh, "fullscreen-enter", "^",
        function() G.Split(f.gid, sh.id) end, L["Split this section from the group"])
    NS.Chrome.SetRestToken(sh.split, "text.heading")
    sh.split:SetPoint("RIGHT", sh, "RIGHT", -4, 0)
    sh.sort = NS.Chrome.HeaderMark(sh, "list", "=", function() NS.Blocks:CycleSort(sh.id) end)
    NS.Chrome.SetRestToken(sh.sort, "text.heading")
    sh.sort:SetPoint("RIGHT", sh.split, "LEFT", -4, 0)
    sh.filter = NS.Chrome.HeaderMark(sh, NS.Blocks.FILTER_ICON, "Y", function(b) NS.Blocks.FilterMenu(sh.id, b) end)
    sh.filter.baseToken = "text.heading"
    NS.Chrome.SetRestToken(sh.filter, sh.filter.baseToken)
    sh.filter:SetPoint("RIGHT", sh.sort, "LEFT", -4, 0)
    sh.filter:Hide()
    sh.note = NS.Detached.NewNote(sh)
    sh:SetScript("OnClick", onSubClick)
    sh:RegisterForDrag("LeftButton")
    sh:SetScript("OnDragStart", onSubDragStart)
    sh:SetScript("OnDragStop", onSubDragStop)
    return sh
end

local function setSub(sh, id)
    sh.id = id
    paintSubBg(sh)   -- every layout, so a skin switch reaches a pooled sub-header
    sh.title:SetText(NS.BlockDefs[id].title)
    local collapsed = NS.Blocks.Settings(id).collapsed
    NS.Chrome.SetIcon(sh.chevron, collapsed and "chevron-right" or "chevron-down", collapsed and ">" or "v")
    local mode = NS.Blocks.SortOf(id)
    NS.Chrome.SetIcon(sh.sort, NS.Blocks.SORT_ICON[mode], "=")
    sh.sort.tip = L["Sorted: %s. Click for the next order."]:format(NS.Blocks.SORT_LABEL[mode])
    NS.Blocks.PaintFilter(sh.filter, id)
    sh.note:Hide()
end

local function onBandClick(band, button)
    if button == "RightButton" then G.Menu(band.owner.gid, nil, band) end
end

local function buildBand(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    NS.Skin.Text(f.title, "heading")
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.title:SetJustifyH("LEFT")
    -- The attach mark: external-link turned 180 degrees, a detached window's dock mark.
    f.dockAll = NS.Chrome.HeaderMark(f, "external-link", "-", function() G.DockAll(f.gid) end,
        L["Dock every section in the main window"])
    NS.Chrome.SetIcon(f.dockAll, "external-link", "-", true)
    f.collapseAll = NS.Chrome.HeaderMark(f, "chevron-down", "v", function() G.CollapseAll(f.gid) end,
        L["Collapse or expand every section"])
    -- The band's own click target (under the marks): a right-click opens the menu, a drag moves the
    -- window as the frame's own does.
    f.band = CreateFrame("Button", nil, f)
    f.band.owner = f
    f.band:RegisterForClicks("RightButtonUp")
    f.band:RegisterForDrag("LeftButton")
    f.band:SetScript("OnClick", onBandClick)
    f.band:SetScript("OnDragStart", function() onDragStart(f) end)
    f.band:SetScript("OnDragStop", function() onDragStop(f) end)
    f.band:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    f.dockAll:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    f.collapseAll:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    NS.Skin.Header(f, { title = f.title, align = "LEFT", right = { f.dockAll, f.collapseAll } })
    if not f.dockAll:GetPoint(1) then
        f.dockAll:SetPoint("TOPRIGHT", f, "TOPRIGHT", -NS.Detached.PAD, -2)
        f.collapseAll:SetPoint("RIGHT", f.dockAll, "LEFT", -2, 0)
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -5)
    end
end

local function build()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata(LAYERS.STRATA.HUD)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", onDragStart)
    f:SetScript("OnDragStop", onDragStop)
    if NS.SecureOverlay then NS.SecureOverlay:Follow(f) end
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    f.cols = {}
    f.rowPool = NS.Rows.NewPool()
    f.subPool = NS.Pool.New()
    f.sections = {}
    NS.Skin.Shell(f)
    buildBand(f)
    f.ownScale = 1
    f.bandParts = { f.title, f.dockAll, f.collapseAll }
    return f
end

-- Column `c`'s host inside the body, `width` wide.
local function column(f, c, width)
    local host = f.cols[c]
    if not host then
        host = CreateFrame("Frame", nil, f.body)
        f.cols[c] = host
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", f.body, "TOPLEFT", (c - 1) * width, 0)
    host:SetWidth(width)
    host:Show()
    return host
end

local function release(f)
    NS.Rows.ReleaseAll(f.rowPool)
    NS.Pool.ReleaseAll(f.subPool, function(sh) sh:Hide() sh:ClearAllPoints() end)
    f.sections = {}
end

-- One column's sections from `y`: each sub-header, then its rows unless collapsed. Answers the y
-- under the last.
local function layColumn(f, c, ids, host)
    local D = NS.Detached
    local y = 0
    for _, id in ipairs(ids) do
        local sh = NS.Pool.Acquire(f.subPool, function() return buildSub(f) end)
        sh:SetParent(host)
        sh:ClearAllPoints()
        sh:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
        sh:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -y)
        sh:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CONTENT + 1)
        sh:Show()
        setSub(sh, id)
        local sec = { header = sh, col = c, y = y }
        f.sections[id] = sec
        y = y + G.SUB_H
        if not NS.Blocks.Settings(id).collapsed then
            y = D.LayEntries(id, host, f.rowPool, y, sh.note)
        end
        sec.h = y - sec.y   -- its drawn extent (a top merge raises a group by it)
    end
    return y
end

--- Draw group `gid` into its window: the title, every column's sections and the window's size.
function G.Render(gid)
    local f = frames[gid]
    local g = G.All()[gid]
    if not (f and g) then return end
    local t0 = Perf.on and debugprofilestop()
    local D = NS.Detached
    release(f)
    local width = D.WIDTH
    local ncols = #g.columns
    f:SetWidth(ncols * width)
    f.title:SetText(G.Title(gid))
    -- Truncated to the band: the marks' room off the right (two marks and the pad).
    f.title:SetWidth(math.max(40, ncols * width - 16 - 2 * (NS.Chrome.SIZE or 18) - 3 * D.PAD))
    local any = false
    for _, id in ipairs(M.Members(g)) do
        if not NS.Blocks.Settings(id).collapsed then any = true end
    end
    NS.Chrome.SetIcon(f.collapseAll, any and "chevron-down" or "chevron-right", any and "v" or ">")
    D.ApplyStyle(f)
    local tallest = 0
    for c, ids in ipairs(g.columns) do
        tallest = math.max(tallest, layColumn(f, c, ids, column(f, c, width)))
    end
    for c = ncols + 1, #f.cols do f.cols[c]:Hide() end
    local top = D.TopHeight(f)
    f.top = top
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    f.body:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
    f.body:SetHeight(math.max(tallest, 1))
    for c = 1, ncols do f.cols[c]:SetHeight(math.max(tallest, 1)) end
    f.band:ClearAllPoints()
    f.band:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.band:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.band:SetHeight(top)
    f:SetHeight(top + tallest + D.PAD)
    f:SetMovable(not isLocked(gid))
    if t0 then Perf.Note("detachedRender", debugprofilestop() - t0) end   -- a merged window is a detached one
end

local function hideFrame(gid)
    local f = frames[gid]
    if not f then return end
    release(f)
    f:Hide()
    f.gid = nil
    frames[gid] = nil
    spare[#spare + 1] = f
end

--- Show every stored group's window and hide the rest; nothing shows while stood down. `anchor ==
--- false` (a data repaint) leaves a window already on screen where it is.
function G.Refresh(anchor)
    local down = NS.IsStoodDown and NS.IsStoodDown()
    local groups = down and {} or G.All()
    for gid in pairs(frames) do
        if not groups[gid] then hideFrame(gid) end
    end
    for _, gid in ipairs(M.Ids(groups)) do
        local f = frames[gid]
        local fresh = f == nil
        if fresh then
            f = table.remove(spare) or build()
            f.gid = gid
            frames[gid] = f
        end
        if fresh or anchor ~= false or not f:IsShown() then applyPoint(f, groups[gid]) end
        f:Show()
        G.Render(gid)
    end
end

--- The group ids whose window is on screen, sorted.
function G.Shown()
    local out = {}
    for _, gid in ipairs(M.Ids(frames)) do
        if frames[gid]:IsShown() then out[#out + 1] = gid end
    end
    return out
end

--- The rows group `gid`'s window is showing (the overlays scan them; the suites read them).
function G.Rows(gid)
    local f = frames[gid]
    return f and f.rowPool.active or {}
end

--- Section `id` of group `gid` as drawn: { header, col, y }, or nil.
function G.Section(gid, id)
    local f = frames[gid]
    return f and f.sections[id]
end

--- Redraw the shown rows' values without moving anything.
function G.RefreshValues()
    local lookup
    for _, f in pairs(frames) do
        if f:IsShown() then
            lookup = lookup or NS.Blocks.Lookup(NS.Blocks.Data())
            NS.Rows.RefreshValues(f.rowPool, lookup)
        end
    end
end

--- Stand-down: every merged window hidden, its rows parked.
function G.StandDown()
    if NS.GroupsSnap then NS.GroupsSnap.Cancel() end
    for _, f in pairs(frames) do
        release(f)
        f:Hide()
    end
end
