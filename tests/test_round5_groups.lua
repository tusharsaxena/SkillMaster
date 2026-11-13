-- tests/test_round5_groups.lua — the owner's round-5 feedback (2026-11-13), R5-6: merged detached
-- windows. The pure model (NS.Groups.Model) on plain tables, then the owner and the merged window on
-- the mock frames: one window per group, its title, columns and sections, the split mark, the menu,
-- Collapse all and Dock all, a dock leaving its group, combat, the overlays, the style, the header
-- drag, the schemaVersion 6 step and the diagnostics lines.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local G, D, B, SO = NS.Groups, NS.Detached, NS.Blocks, NS.SecureOverlay
local Mo = G.Model

local function cols(g)
    local out = {}
    for c, col in ipairs(g.columns) do out[c] = table.concat(col, ",") end
    return table.concat(out, " | ")
end

-- ── the pure model ─────────────────────────────────────────────────────────────────────────

test("round5 groups model: two lone windows merged on a side make a group, left and right as columns", function()
    local groups = {}
    local gid = Mo.Merge(groups, "secondary", "primary", "right")
    assertEqual(gid, "g1", "the first free id")
    assertEqual(cols(groups.g1), "primary | secondary", "right: a column after the target's")
    groups = {}
    Mo.Merge(groups, "secondary", "primary", "left")
    assertEqual(cols(groups.g1), "secondary | primary", "left: a column before the target's")
end)

test("round5 groups model: top and bottom stack into the target's column", function()
    local groups = { g1 = { point = false, columns = { { "primary" }, { "stats_base" } } } }
    Mo.Merge(groups, "secondary", "g1", "bottom", 1)
    assertEqual(cols(groups.g1), "primary,secondary | stats_base", "bottom of column 1")
    Mo.Merge(groups, "weapon", "g1", "top", 2)
    assertEqual(cols(groups.g1), "primary,secondary | weapon,stats_base", "top of column 2")
    Mo.Merge(groups, "other", "stats_base", "bottom")
    assertEqual(cols(groups.g1), "primary,secondary | weapon,stats_base,other",
        "a grouped target block: its own column by default")
end)

test("round5 groups model: a dragged group merges whole, its columns kept beside, stacked above or below", function()
    local groups = {
        g1 = { point = false, columns = { { "primary" }, { "secondary" } } },
        g2 = { point = false, columns = { { "weapon" }, { "other" } } },
    }
    assertEqual(Mo.Merge(groups, "g2", "g1", "right"), "g1")
    assertTrue(groups.g2 == nil, "the dragged group is gone")
    assertEqual(cols(groups.g1), "primary | secondary | weapon | other", "its columns after the target's")
    groups = {
        g1 = { point = false, columns = { { "primary" } , { "secondary" } } },
        g2 = { point = false, columns = { { "weapon" }, { "other" } } },
    }
    Mo.Merge(groups, "g2", "g1", "top", 2)
    assertEqual(cols(groups.g1), "primary | weapon,other,secondary", "flattened above column 2")
end)

test("round5 groups model: a window is never merged into itself, and an unknown side is refused", function()
    local groups = { g1 = { point = false, columns = { { "primary", "secondary" } } } }
    assertTrue(Mo.Merge(groups, "g1", "g1", "right") == nil, "a group into itself")
    assertTrue(Mo.Merge(groups, "g1", "primary", "right") == nil, "a group into its own section")
    assertTrue(Mo.Merge(groups, "weapon", "weapon", "right") == nil, "a block into itself")
    assertTrue(Mo.Merge(groups, "weapon", "primary", "middle") == nil, "no such side")
    assertEqual(cols(groups.g1), "primary,secondary", "nothing changed")
end)

test("round5 groups model: a section moves within its own group, and a split group of one dissolves", function()
    local groups = { g1 = { point = false, columns = { { "primary", "secondary" }, { "weapon" } } } }
    Mo.Merge(groups, "primary", "weapon", "bottom")
    Mo.Normalize(groups)
    assertEqual(cols(groups.g1), "secondary | weapon,primary", "moved under weapon")
    assertTrue(Mo.Split(groups, "g1", "weapon"))
    assertFalse(Mo.Split(groups, "g1", "weapon"), "not in the group any more")
    Mo.Normalize(groups)
    assertEqual(cols(groups.g1), "secondary | primary")
    Mo.Split(groups, "g1", "primary")
    Mo.Normalize(groups)
    assertTrue(groups.g1 == nil, "a group of one is no group")
end)

test("round5 groups model: Normalize drops refused, repeated and malformed members, empty columns and groups", function()
    local groups = {
        g1 = { point = false, columns = { { "primary", "nope", "primary" }, {}, { "secondary" } } },
        g2 = { columns = { { "secondary", "weapon" } } },   -- secondary is g1's already
        g3 = "junk",
        g4 = { point = false, columns = "junk" },
    }
    Mo.Normalize(groups, function(id) return NS.BlockDefs[id] ~= nil end)
    assertEqual(cols(groups.g1), "primary | secondary", "the unknown, the repeat and the empty column gone")
    assertTrue(groups.g2 == nil, "left with weapon alone: dissolved")
    assertTrue(groups.g3 == nil and groups.g4 == nil, "malformed groups gone")
    local kept = groups.g1.columns
    Mo.Normalize(groups)
    assertTrue(groups.g1.columns == kept, "a well-formed group keeps its tables")
    assertEqual(Mo.Find(groups, "secondary"), "g1")
    assertEqual(Mo.NewId(groups), "g2")
end)

-- ── the owner and the merged window ────────────────────────────────────────────────────────

local IDS = { "primary", "secondary", "weapon", "stats_base" }

-- The sample character, the four blocks detached, every block and group put back afterwards.
local function withMerged(fn)
    local layout = NS.db.profile.layout
    NS.Preview.Apply(true)
    for _, id in ipairs(IDS) do layout.blocks[id].docked = false end
    layout.groups = {}
    D.Refresh()
    local ok, err = pcall(fn, layout)
    layout.groups = {}
    for _, id in ipairs(NS.BLOCKS) do
        layout.blocks[id].docked, layout.blocks[id].collapsed, layout.blocks[id].point = true, false, false
    end
    layout.blocks.stats_spell.collapsed, layout.blocks.stats_defense.collapsed = false, false
    M.InCombatLockdown = function() return false end
    D.Refresh()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

test("round5 groups: a merge draws one window, the sections' own frames hidden, the title their short names", function()
    withMerged(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        assertEqual(gid, "g1", "the merge answers its group")
        assertEqual(G.Of("primary"), "g1")
        assertEqual(G.Of("secondary"), "g1")
        local f = G.Frame(gid)
        assertTrue(f ~= nil and f:IsShown(), "the merged window shows")
        assertFalse(D.Frame("primary"):IsShown(), "the target's own window hides")
        assertFalse(D.Frame("secondary"):IsShown(), "the dragged one's too")
        assertTrue(D.Frame("weapon"):IsShown(), "a block left out keeps its window")
        assertEqual(G.Title(gid), "Primary \194\183 Secondary", "the Journal's short labels, joined")
        assertEqual(f.title:GetText(), G.Title(gid), "on the band")
        assertEqual(NS.Journal.FilterLabel("stats_base"), NS.BlockDefs.stats_base.short, "one table for both")
        assertTrue(#G.Rows(gid) > 0, "the sections' rows draw in the window")
        assertTrue(G.Section(gid, "primary") ~= nil and G.Section(gid, "secondary") ~= nil, "a sub-header per section")
        assertEqual(G.Section(gid, "secondary").col, 1, "stacked in one column")
        assertTrue(G.Section(gid, "secondary").y > G.Section(gid, "primary").y, "below the target")
    end)
end)

test("round5 groups: left and right merges make columns, each the detached width, the header spanning them", function()
    withMerged(function()
        local widths = {}
        local gid = G.Merge("stats_base", "primary", "right")
        local f = G.Frame(gid)
        rawset(f, "SetWidth", function(_, w) widths[#widths + 1] = w end)
        G.Render(gid)
        assertEqual(widths[#widths], 2 * D.WIDTH, "two columns")
        assertEqual(G.Section(gid, "stats_base").col, 2, "the dragged block in a column right of the target")
        G.Merge("weapon", gid, "left")
        G.Render(gid)
        assertEqual(widths[#widths], 3 * D.WIDTH, "three columns")
        assertEqual(G.Section(gid, "weapon").col, 1, "a column left of the rest")
        rawset(f, "SetWidth", nil)
    end)
end)

test("round5 groups: each sub-header carries a chevron, the title, the sort mark and the split mark", function()
    withMerged(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        local sh = G.Section(gid, "secondary").header
        assertEqual(sh.title:GetText(), NS.BlockDefs.secondary.title)
        assertTrue(sh.chevron ~= nil and sh.sort ~= nil and sh.split ~= nil, "the four parts")
        assertEqual(sh.split.tip, NS.L["Split this section from the group"])
        local real, rows = NS.Widgets.ContextMenu, nil
        NS.Widgets.ContextMenu = function(_, r) rows = r return {} end
        sh.sort:__fire("OnClick", "LeftButton")
        NS.Widgets.ContextMenu = real
        for _, r in ipairs(rows or {}) do if r.value == "value" then r.onClick() end end
        assertEqual(B.SortOf("secondary"), "value", "the sort mark's menu sets the block's order")
        NS.db.profile.layout.blocks.secondary.sort = "name"
        sh.chevron:__fire("OnClick", "LeftButton")
        assertTrue(NS.db.profile.layout.blocks.secondary.collapsed, "the chevron collapses the section")
        assertTrue(G.Of("secondary") == gid, "still merged")
    end)
end)

test("round5 groups: the split mark pops the section out beside the group, and a group of one dissolves", function()
    withMerged(function(layout)
        local gp = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 100, y = 700 }
        local gid = G.Merge("secondary", "primary", "right", { point = gp })
        assertEqual(layout.groups[gid].point.x, 100, "the given point")
        G.Section(gid, "secondary").header.split:__fire("OnClick", "LeftButton")
        assertTrue(G.Of("secondary") == nil and G.Of("primary") == nil, "split: the group of one dissolved")
        assertTrue(layout.groups[gid] == nil, "and is gone from the profile")
        assertFalse(G.Frame(gid) ~= nil and G.Frame(gid):IsShown(), "its window hides")
        assertTrue(D.Frame("secondary"):IsShown() and D.Frame("primary"):IsShown(), "both their own windows again")
        local p = layout.blocks.secondary.point
        assertEqual(p.point, "TOPLEFT")
        assertEqual(p.x, 100 + 2 * D.WIDTH + G.GAP, "right of the group's two columns")
        assertFalse(layout.blocks.secondary.docked, "still detached")
    end)
end)

test("round5 groups: a split at a drop point lands there; a three-section group stays a group", function()
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        G.Merge("weapon", gid, "right")
        assertTrue(G.Split(gid, "weapon", { point = "CENTER", relPoint = "CENTER", x = 5, y = 6 }))
        assertEqual(cols(layout.groups[gid]), "primary,secondary", "two sections left")
        assertEqual(layout.blocks.weapon.point.x, 5, "the drop point")
        assertTrue(G.Split(gid, "stats_base") == nil, "not a section of it")
    end)
end)

test("round5 groups: the menu splits, unmerges and docks, from a sub-header or the band", function()
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        G.Merge("weapon", gid, "bottom")
        local function row(rows, value)
            for _, r in ipairs(rows) do if r.value == value then return r end end
        end
        local band = G.MenuRows(gid, nil)
        assertTrue(row(band, "split").disabled and row(band, "dock").disabled, "a section's rows off on the band")
        assertFalse(row(band, "unmerge").disabled == true or row(band, "dockAll").disabled == true)
        local rows = G.MenuRows(gid, "weapon")
        assertEqual(rows[1].label, NS.BlockDefs.weapon.title, "titled by the section")
        row(rows, "split").onClick()
        assertTrue(G.Of("weapon") == nil, "Split from the group")
        G.Merge("weapon", gid, "bottom")
        row(G.MenuRows(gid, "weapon"), "dock").onClick()
        assertTrue(layout.blocks.weapon.docked, "Dock in the main window")
        assertTrue(G.Of("weapon") == nil, "and out of the group")
        row(G.MenuRows(gid, nil), "unmerge").onClick()
        assertTrue(layout.groups[gid] == nil, "Unmerge all")
        assertFalse(layout.blocks.primary.docked or layout.blocks.secondary.docked, "each its own window")
        gid = G.Merge("secondary", "primary", "bottom")
        row(G.MenuRows(gid, nil), "dockAll").onClick()
        assertTrue(layout.blocks.primary.docked and layout.blocks.secondary.docked, "Dock all in the main window")
        assertTrue(layout.groups[gid] == nil, "no group left")
    end)
end)

test("round5 groups: a right-click on a sub-header or the band opens the menu", function()
    withMerged(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        local seen = {}
        local real = NS.Widgets.ContextMenu
        NS.Widgets.ContextMenu = function(_, rows) seen[#seen + 1] = rows[1].label return {} end
        local ok, err = pcall(function()
            G.Section(gid, "primary").header:__fire("OnClick", "RightButton")
            G.Frame(gid).band:__fire("OnClick", "RightButton")
        end)
        NS.Widgets.ContextMenu = real
        if not ok then error(err, 0) end
        assertEqual(seen[1], NS.BlockDefs.primary.title, "the sub-header's menu")
        assertEqual(seen[2], G.Title(gid), "the band's menu")
        assertFalse(NS.db.profile.layout.blocks.primary.collapsed, "a right-click collapses nothing")
    end)
end)

test("round5 groups: a block docked by any path leaves its group", function()
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        G.Merge("weapon", gid, "bottom")
        assertTrue(B:Dock("weapon"), "the seam's dock")
        assertTrue(G.Of("weapon") == nil, "left the group")
        assertEqual(cols(layout.groups[gid]), "primary,secondary")
        NS.SetByPath("layout.blocks.secondary.docked", true)   -- /sm set
        assertTrue(layout.groups[gid] == nil, "a group of one dissolved")
        assertTrue(D.Frame("primary"):IsShown(), "the last block its own window again")
    end)
end)

test("round5 groups: Collapse all collapses every section, then expands them; Dock all docks every one", function()
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        local f = G.Frame(gid)
        f.collapseAll:__fire("OnClick", "LeftButton")
        assertTrue(layout.blocks.primary.collapsed and layout.blocks.secondary.collapsed, "all collapsed")
        assertEqual(#G.Rows(gid), 0, "no rows while every section is collapsed")
        f.collapseAll:__fire("OnClick", "LeftButton")
        assertFalse(layout.blocks.primary.collapsed or layout.blocks.secondary.collapsed, "all expanded")
        f.dockAll:__fire("OnClick", "LeftButton")
        assertTrue(layout.blocks.primary.docked and layout.blocks.secondary.docked, "all docked")
        assertFalse(f:IsShown(), "the merged window hides")
    end)
end)

test("round5 groups: a merge, a split and an unmerge in combat wait for its end", function()
    withMerged(function(layout)
        M.InCombatLockdown = function() return true end
        assertEqual(G.Merge("secondary", "primary", "bottom"), false, "queued")
        assertTrue(G.Of("primary") == nil, "nothing merged in combat")
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        local gid = G.Of("primary")
        assertTrue(gid ~= nil and G.Of("secondary") == gid, "merged after combat")
        M.InCombatLockdown = function() return true end
        assertEqual(G.Split(gid, "secondary"), false, "a split queued")
        assertEqual(G.Unmerge(gid), false, "an unmerge queued")
        assertTrue(layout.groups[gid] ~= nil, "still merged in combat")
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        assertTrue(layout.groups[gid] == nil, "unmade after combat")
    end)
end)

test("round5 groups: a hovered crafting row in a merged window gets its overlay, over the merged window", function()
    withMerged(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        local f = G.Frame(gid)
        local craft
        for _, row in ipairs(G.Rows(gid)) do
            if SO.KindFor(row) == "spell" then craft = row break end
        end
        assertTrue(craft ~= nil, "the sample character has a crafting profession")
        SO:Hover(craft)
        local b = SO.Overlay(SO.KeyFor(craft))
        assertTrue(b ~= nil and b:IsShown() and b.row == craft, "armed over the merged window's row")
        SO:SetMoving(f, true)
        assertFalse(b:IsShown(), "down while the merged window is dragged")
        SO:SetMoving(f, false)
        assertTrue(b:IsShown(), "laid again at the drop")
        SO:Unhover(craft)
    end)
end)

test("round5 groups: the merged window takes the Detached windows style", function()
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        local was = layout.detached.alpha
        NS.SetByPath("layout.detached.alpha", 0.5)
        local a = G.Frame(gid):GetAlpha()
        NS.SetByPath("layout.detached.alpha", was)
        assertTrue(type(a) == "number" and math.abs(a - 0.5) < 1e-6, "the window's opacity, got " .. tostring(a))
    end)
end)

-- The frame's rect, answered in UIParent units at scale 1.
local function placed(f, l, t, w, h)
    rawset(f, "GetLeft", function() return l end)
    rawset(f, "GetTop", function() return t end)
    rawset(f, "GetRight", function() return l + w end)
    rawset(f, "GetBottom", function() return t - h end)
    rawset(f, "GetEffectiveScale", function() return 1 end)
end
local GEOM = { "GetLeft", "GetTop", "GetRight", "GetBottom", "GetEffectiveScale" }
local function unplaced(f) for _, k in ipairs(GEOM) do rawset(f, k, nil) end end

test("round5 groups: the band drags the window and its drop is the group's point; locked, it stays", function()
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        local f = G.Frame(gid)
        placed(M.UIParent, 0, 768, 1024, 768)
        placed(f, 300, 500, 280, 200)
        local ok, err = pcall(function()
            f.band:__fire("OnDragStart")
            assertTrue(f.dragging == true, "the band starts the drag")
            f.band:__fire("OnDragStop")
            local p = layout.groups[gid].point
            assertEqual(p.point, "TOPLEFT")
            assertEqual(p.relPoint, "BOTTOMLEFT")
            assertEqual(p.x, 300)
            assertEqual(p.y, 500)
            NS.db.profile.locked = true
            f.band:__fire("OnDragStart")
            assertTrue(f.dragging == nil, "locked: no drag")
        end)
        NS.db.profile.locked = false
        unplaced(f)
        unplaced(M.UIParent)
        if not ok then error(err, 0) end
    end)
end)

test("round5 groups: a merge on the left keeps the target where it stood", function()
    withMerged(function(layout)
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(M.UIParent, 0, 768, 1024, 768)
        placed(tf, 400, 600, D.WIDTH, 150)
        placed(df, 100, 300, D.WIDTH, 120)
        local ok, err = pcall(function()
            local gid = G.Merge("secondary", "primary", "left")
            local p = layout.groups[gid].point
            assertEqual(p.x, 400 - D.WIDTH, "one column's width left of the target")
            assertEqual(p.y, 600, "level with it")
        end)
        unplaced(tf)
        unplaced(df)
        unplaced(M.UIParent)
        if not ok then error(err, 0) end
    end)
end)

-- The height a block not collapsed takes as a section: its sub-header and its rows' two pads (the
-- kit's rows answer no height of their own).
local function sectionH() return G.SUB_H + 2 * D.ROW_PAD end

test("round5 groups: a window dropped on a group's top raises the group by the dropped section, not the group", function()
    -- red under: a mergePoint that measures windowOf(dragged) after the model moved it, which is
    -- the target group's own frame (the group jumped up by its own height).
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        local f, df = G.Frame(gid), D.Frame("weapon")
        placed(M.UIParent, 0, 768, 1024, 768)
        placed(f, 300, 600, D.WIDTH, 300)
        placed(df, 100, 300, D.WIDTH, 120)
        local ok, err = pcall(function()
            assertEqual(G.Merge("weapon", gid, "top"), gid, "into the group")
            local p = layout.groups[gid].point
            assertEqual(p.x, 300, "the column stays")
            assertEqual(p.y, 600 + sectionH(), "up by the weapon section alone")
        end)
        unplaced(f)
        unplaced(df)
        unplaced(M.UIParent)
        if not ok then error(err, 0) end
    end)
end)

test("round5 groups: a section dragged onto a window's top raises the new group by that section", function()
    -- red under: the same mergePoint, which read the dragged section's window after the move (the
    -- section's own hidden frame, or its old merged window) instead of the section as it was drawn.
    withMerged(function(layout)
        local gid = G.Merge("secondary", "primary", "bottom")
        G.Merge("stats_base", gid, "bottom")
        local f, tf = G.Frame(gid), D.Frame("weapon")
        placed(M.UIParent, 0, 768, 1024, 768)
        placed(f, 100, 700, D.WIDTH, 400)
        placed(tf, 500, 400, D.WIDTH, 120)
        local ok, err = pcall(function()
            local into = G.Merge("secondary", "weapon", "top")
            assertTrue(into ~= nil and into ~= gid, "a new group")
            local p = layout.groups[into].point
            assertEqual(p.x, 500, "level with the weapon window's left")
            assertEqual(p.y, 400 + sectionH(), "up by the secondary section alone")
        end)
        unplaced(f)
        unplaced(tf)
        unplaced(M.UIParent)
        if not ok then error(err, 0) end
    end)
end)

test("round5 groups: two merges dropped in one combat both happen when it ends", function()
    -- red under: one AfterCombat key for every merge, the second drop replacing the first.
    withMerged(function()
        M.InCombatLockdown = function() return true end
        assertEqual(G.Merge("secondary", "primary", "bottom"), false, "the first queued")
        assertEqual(G.Merge("weapon", "stats_base", "right"), false, "the second queued")
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        local a, b = G.Of("primary"), G.Of("stats_base")
        assertTrue(a ~= nil and G.Of("secondary") == a, "the first merge ran")
        assertTrue(b ~= nil and G.Of("weapon") == b and b ~= a, "and the second")
    end)
end)

-- ── one style for detached and merged windows (R5-7) ───────────────────────────────────────

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- A merged window of primary and secondary under `fn(f, gid)`, every style key put back after.
local function withStyledGroup(fn)
    local style = NS.db.profile.layout.detached
    local saved = {}
    for k, v in pairs(style) do saved[k] = v end
    withMerged(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        local ok, err = pcall(fn, G.Frame(gid), gid)
        for k in pairs(style) do style[k] = nil end
        for k, v in pairs(saved) do style[k] = v end
        NS.bus:SendMessage(NS.MSG.LAYOUT_CHANGED)
        if not ok then error(err, 0) end
    end)
end

local function set(path, v) assertTrue(NS.SetByPath(path, v) ~= false, "the seam takes " .. path) end

-- The body's offset below the window's top and the band's height, as the merged window's render
-- places them (the kit's frames keep neither).
local function groupBodyTop(f, gid)
    local y, h
    rawset(f.body, "SetPoint", function(_, _, _, _, _, oy) y = y or oy end)
    rawset(f.band, "SetHeight", function(_, v) h = v end)
    G.Render(gid)
    rawset(f.body, "SetPoint", nil)
    rawset(f.band, "SetHeight", nil)
    return y, h
end

test("round5 groups style: the merged window's background and border follow the Detached windows tab", function()
    withStyledGroup(function(f)
        assertFalse(f.styleBg:IsShown(), "the skin's fill by default")
        set("layout.detached.bgColor", { 0.1, 0.2, 0.3, 0.4 })
        set("layout.detached.bgFromSkin", false)
        assertTrue(f.styleBg:IsShown(), "the swatch's fill shows")
        local c = rawget(f.styleBg, "__color")
        assertTrue(c ~= nil and near(c[1], 0.1) and near(c[4], 0.4), "in the swatch's color")
        local function ownShown()
            for _, e in ipairs(f.styleEdge.edges) do if e:IsShown() then return true end end
            return false
        end
        assertFalse(ownShown(), "the skin's edge by default")
        set("layout.detached.borderFromSkin", false)
        assertTrue(D.ShellOpts(f).noBorder == true, "the skin's edge off")
        assertTrue(ownShown(), "the window's own edge on")
    end)
end)

test("round5 groups style: Title band Never hides the merged band and keeps a drag strip", function()
    withStyledGroup(function(f, gid)
        assertTrue(f.title:IsShown() and f.dockAll:IsShown() and f.collapseAll:IsShown(), "the band shows by default")
        set("layout.detached.titleBand", "never")
        assertFalse(f.title:IsShown() or f.dockAll:IsShown() or f.collapseAll:IsShown(), "no title, no marks")
        local y, h = groupBodyTop(f, gid)
        assertEqual(y, -D.GRIP_H, "the body starts below the drag strip")
        assertEqual(h, D.GRIP_H, "the band's drag target is the strip")
        set("layout.detached.titleBand", "always")
        assertTrue(f.title:IsShown() and f.dockAll:IsShown(), "the band back")
    end)
end)

test("round5 groups style: Title band On hover shows the merged band while the pointer is over it", function()
    withStyledGroup(function(f, gid)
        local over = false
        rawset(f, "IsMouseOver", function() return over end)
        set("layout.detached.titleBand", "hover")
        local poll = f:GetScript("OnUpdate")
        assertTrue(poll ~= nil, "the merged window polls the pointer")
        assertFalse(f.title:IsShown() or f.dockAll:IsShown(), "hidden with the pointer away")
        assertEqual(groupBodyTop(f, gid), -D.TitleHeight(f), "the body stays below the band")
        over = true
        poll(f, 1)
        assertTrue(f.title:IsShown() and f.dockAll:IsShown() and f.collapseAll:IsShown(), "shown with the pointer over")
        over = false
        poll(f, 1)
        assertFalse(f.title:IsShown(), "hidden again when it leaves")
        rawset(f, "IsMouseOver", nil)
    end)
end)

-- ── the store: schemaVersion 6 and the diagnostics ─────────────────────────────────────────

test("round5 groups: schemaVersion 6 normalizes a stored layout.groups and drops a malformed one", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["Round5-Groups"] = { layout = {
        blocks = { primary = { docked = false }, secondary = { docked = false }, weapon = { docked = true } },
        groups = { g1 = { point = false, columns = { { "primary", "weapon" }, { "secondary" } } },
                   g2 = { columns = { { "weapon" } } } },
    } }
    sv.profiles["Round5-Junk"] = { layout = { groups = "junk" } }
    sv.profiles["Round5-None"] = { layout = { width = 400 } }
    local saved = NS.db.global.schemaVersion
    NS.db.global.schemaVersion = 5
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION, "the runner reaches the newest step")
    assertEqual(NS.SCHEMA_VERSION, 6)
    local g = sv.profiles["Round5-Groups"].layout.groups
    assertEqual(cols(g.g1), "primary | secondary", "the docked weapon block dropped")
    assertTrue(g.g2 == nil, "a group of a docked block alone gone")
    assertTrue(sv.profiles["Round5-Junk"].layout.groups == nil, "not a table: the default answers")
    assertTrue(sv.profiles["Round5-None"].layout.groups == nil, "nothing added")
    sv.profiles["Round5-Groups"], sv.profiles["Round5-Junk"], sv.profiles["Round5-None"] = nil, nil, nil
    NS.db.global.schemaVersion = saved
end)

test("round5 groups: the diagnostics' layout section names each group and each block's", function()
    withMerged(function()
        local gid = G.Merge("secondary", "primary", "right")
        local lines = {}
        local out = {
            add = function(_, _, fmt, ...)
                local args = { ... }
                for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
                lines[#lines + 1] = fmt:format(unpack(args, 1, select("#", ...)))
            end,
            joined = function() end, list = function() end,
        }
        for _, sec in ipairs(NS.Diagnostics.Sections()) do
            if sec[1] == "layout" then sec[2](out) end
        end
        local text = table.concat(lines, "\n")
        assertTrue(text:find("layout groups=1", 1, true) ~= nil, "the count")
        assertTrue(text:find("group " .. gid .. " columns=primary | secondary point=", 1, true) ~= nil, "the group")
        assertTrue(text:find("block primary .- group=" .. gid) ~= nil, "a member names its group")
        assertTrue(text:find("block weapon .- group=%-") ~= nil, "a lone block none")
    end)
end)
