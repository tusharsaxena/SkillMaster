-- tests/test_round8.lua — the owner's round-8 feedback (2026-11-14): the header marks of a detached
-- or merged window in the main window header's color (R8-3); the LDB tooltip's headers without
-- their sort and filter marks (R8-4); the active filter as a filled badge (R8-2); Open a row from,
-- Full row or Go icon only, on the main window and the LDB tooltip (R8-1).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local B8, W8, D8, G8 = NS.Blocks, NS.MainWindow, NS.Detached, NS.Groups

--- Every block back on the window, All, expanded, no merged window; then the window hidden.
local function withBlocks(fn)
    local savedMenu = NS.Widgets.ContextMenu
    local ok, err = pcall(fn)
    NS.Widgets.ContextMenu = savedMenu
    for _, id in ipairs(NS.BLOCKS) do
        local s = NS.db.profile.layout.blocks[id]
        s.filter, s.docked, s.collapsed = "all", true, false
    end
    NS.db.profile.layout.groups = {}
    D8.Refresh()
    W8.Hide()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function header(id)
    for _, h in ipairs(W8.Headers()) do if h.id == id then return h end end
    return nil
end

local function color(token)
    local r, g, b = NS.Skin.Color(token)
    return ("%.3f,%.3f,%.3f"):format(r or -1, g or -1, b or -1)
end

local function tintOf(tex)
    local r, g, b = tex:GetVertexColor()
    return ("%.3f,%.3f,%.3f"):format(r or -1, g or -1, b or -1)
end

--- A color texture's fill (the mock keeps SetColorTexture's components).
local function fillOf(tex)
    local c = tex.__color or {}
    return ("%.3f,%.3f,%.3f"):format(c[1] or -1, c[2] or -1, c[3] or -1)
end

-- ── R8-3: a detached or merged window's marks in the main window header's color ──────────────

test("round8 header marks: a detached band's marks rest in the main window header's color", function()
    withBlocks(function()
        B8:Detach("weapon")
        M.__fireTimers()
        local f = D8.Frame("weapon")
        for _, k in ipairs({ "dock", "collapse", "sort", "filter", "restore" }) do
            assertEqual(f[k].restToken, "text.heading", k .. ": the title's color at rest")
            assertEqual(tintOf(f[k].icon), color("text.heading"), k .. ": drawn so")
        end
        assertEqual(f.filter.baseToken, "text.heading", "the filter's own rest color")
        -- Hover as on the window: icon.hot under the pointer, the title's color again after.
        f.sort:__fire("OnEnter")
        assertEqual(tintOf(f.sort.icon), color("icon.hot"), "hot under the pointer")
        f.sort:__fire("OnLeave")
        assertEqual(tintOf(f.sort.icon), color("text.heading"), "back at rest")
        -- A collapse and an expand repaint the chevron in the same color.
        B8:ToggleCollapsed("weapon")
        M.__fireTimers()
        assertEqual(tintOf(D8.Frame("weapon").collapse.icon), color("text.heading"), "collapsed, the same")
    end)
end)

test("round8 header marks: a merged window's band and section sub-headers match the main window header", function()
    withBlocks(function()
        local b = NS.db.profile.layout.blocks
        b.primary.docked, b.other.docked = false, false
        D8.Refresh()
        local gid = G8.Merge("primary", "other", "bottom")
        assertTrue(gid ~= nil, "merged")
        local f = G8.Frame(gid)
        for _, k in ipairs({ "dockAll", "collapseAll" }) do
            assertEqual(f[k].restToken, "text.heading", k .. ": the title's color at rest")
            assertEqual(tintOf(f[k].icon), color("text.heading"), k .. ": drawn so")
        end
        W8.Show()
        W8.Refresh(true)
        local main = header("secondary") or W8.Headers()[1]
        local sh = G8.Section(gid, "primary").header
        for _, k in ipairs({ "chevron", "sort", "filter" }) do
            assertEqual(sh[k].restToken, main[k].restToken, k .. ": the sub-header's as the window header's")
            assertEqual(tintOf(sh[k].icon), tintOf(main[k].icon), k .. ": drawn so")
        end
        assertEqual(sh.split.restToken, "text.heading", "split, as the window header's detach")
    end)
end)

-- ── R8-4: the LDB tooltip's headers carry no sort or filter mark ─────────────────────────────

local Br, BP = NS.Broker, NS.BrokerPanel

local function tipSkill(key, name, category, rank, max)
    return { key = key, name = name, category = category, rank = rank, max = max, modifier = 0,
             tempPoints = 0, learned = true }
end

--- The feed's tooltip in the Main window style over a fixture, then everything put back.
local function withPanel(fn)
    local savedSource, p = Br.source, NS.db.profile.tooltips.ldb
    local savedStyle = p.style
    local byKey = {
        tailoring = tipSkill("tailoring", "Tailoring", "primary", 120, 150),
        bows      = tipSkill("bows", "Bows", "weapon", 80, 110),
        maces     = tipSkill("maces", "Maces", "weapon", 110, 110),
    }
    local v = { model = { byKey = byKey, order = { primary = { "tailoring" }, secondary = {},
                weapon = { "bows", "maces" }, other = {} } },
                statsModel = { base = {}, spell = {}, defense = {}, utility = {} }, statIndex = {},
                gains = { total = 0, byKey = {} } }
    Br.source = function() return v end
    p.style = "window"
    local ok, err = pcall(fn)
    Br.HideTooltip()
    Br.source, p.style = savedSource, savedStyle
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].filter = "all" end
    W8.Hide()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function panelHeader(id)
    for _, h in ipairs(BP.Headers()) do if h.id == id then return h end end
    return nil
end

test("round8 ldb tooltip: its headers carry no sort or filter mark, on All or a narrowing filter", function()
    withPanel(function()
        Br.OnEnter(M.UIParent)
        assertTrue(#BP.Headers() > 0, "the panel drew its headers")
        for _, h in ipairs(BP.Headers()) do
            assertFalse(h.sort:IsShown(), h.id .. ": no sort mark")
            assertFalse(h.filter:IsShown(), h.id .. ": no filter mark")
            assertTrue(h.chevron:IsShown(), h.id .. ": the chevron still says the window's collapse")
        end
        assertTrue(NS.SetByPath("layout.blocks.weapon.filter", "belowCap"))
        M.__fireTimers()
        Br.OnEnter(M.UIParent)
        local weapon = panelHeader("weapon")
        assertFalse(weapon.filter:IsShown(), "no filter mark while the filter narrows")
        assertFalse(weapon.sort:IsShown(), "and no sort mark")
        local keys = {}
        for _, row in ipairs(BP.Rows()) do if row.entry then keys[row.entry.key] = true end end
        assertTrue(keys.bows and not keys.maces, "the rows still follow the window's filter")
    end)
end)

test("round8 ldb tooltip: the main window's headers keep their sort and filter marks", function()
    withPanel(function()
        Br.OnEnter(M.UIParent)   -- the panel's headers first: its own pool, never the window's
        W8.Show()
        W8.Refresh(true)
        assertTrue(#W8.Headers() > 0, "the window drew its headers")
        for _, h in ipairs(W8.Headers()) do
            assertTrue(h.sort:IsShown(), h.id .. ": the sort mark")
            assertTrue(h.filter:IsShown(), h.id .. ": the filter mark")
        end
    end)
end)

-- ── R8-2: an active filter as the filled badge ────────────────────────────────────────────────

local C8 = NS.Chrome

local function longSide(tex)
    local w, h = tex:GetSize()
    return math.max(w or 0, h or 0)
end

--- `mark` (a filter mark) on All: the funnel alone in its rest color, at the header marks' size.
local function assertPlain(mark, where)
    assertTrue(not (mark.badge and mark.badge:IsShown()), where .. ": no badge on All")
    assertEqual(tintOf(mark.icon), color(mark.baseToken), where .. ": the funnel in its rest color")
    assertEqual(longSide(mark.icon), C8.INK_SIZE, where .. ": the header marks' size")
end

--- `mark` narrowing: a solid square in its rest color, the funnel on it in the header's background.
local function assertBadge(mark, where)
    assertTrue(mark.badge ~= nil and mark.badge:IsShown(), where .. ": the badge")
    local w, h = mark.badge:GetSize()
    assertEqual(w, C8.BADGE_SIZE, where .. ": the badge's width")
    assertEqual(h, C8.BADGE_SIZE, where .. ": a square")
    assertTrue(C8.BADGE_SIZE <= C8.SIZE, where .. ": inside the control, the other marks' footprint")
    assertEqual(fillOf(mark.badge), color(mark.baseToken), where .. ": the square in the mark's rest color")
    assertEqual(tintOf(mark.icon), color(C8.BADGE_INK_TOKEN), where .. ": the funnel in the header's background")
    assertEqual(longSide(mark.icon), C8.BADGE_INK, where .. ": the funnel inset on the square")
    assertEqual(mark.restToken, mark.baseToken, where .. ": no accent tint any more")
    local badgeLayer, iconLayer = mark.badge:GetDrawLayer(), mark.icon:GetDrawLayer()
    assertTrue(badgeLayer == "ARTWORK" and iconLayer == "OVERLAY", where .. ": the square under the funnel")
    assertTrue(mark.tip:find(NS.L["Showing: %s. Click to filter."]:match("^[^%%]+"), 1, true) ~= nil, where .. ": the tip still names it")
end

test("round8 filter badge: the window header's funnel on a solid square while it narrows, hover readable", function()
    withBlocks(function()
        W8.Show()
        W8.Refresh(true)
        local id = W8.Headers()[1].id
        assertPlain(header(id).filter, id)
        assertTrue(NS.SetByPath("layout.blocks." .. id .. ".filter", B8.FiltersOf(id)[2]))
        M.__fireTimers()
        local mark = header(id).filter
        assertBadge(mark, id)
        -- Under the pointer the square goes hot and the funnel stays dark on it.
        mark:__fire("OnEnter")
        assertEqual(fillOf(mark.badge), color("icon.hot"), "the square hot under the pointer")
        assertEqual(tintOf(mark.icon), color(C8.BADGE_INK_TOKEN), "the funnel still dark on it")
        mark:__fire("OnLeave")
        assertEqual(fillOf(mark.badge), color(mark.baseToken), "the square at rest again")
        assertTrue(NS.SetByPath("layout.blocks." .. id .. ".filter", "all"))
        M.__fireTimers()
        assertPlain(header(id).filter, id .. " back on All")
    end)
end)

test("round8 filter badge: a detached band and a merged sub-header wear the same badge", function()
    withBlocks(function()
        B8:Detach("stats_spell")
        M.__fireTimers()
        local f = D8.Frame("stats_spell")
        assertPlain(f.filter, "detached")
        assertTrue(NS.SetByPath("layout.blocks.stats_spell.filter", "nonZero"))
        M.__fireTimers()
        assertBadge(D8.Frame("stats_spell").filter, "detached")
        NS.db.profile.layout.blocks.primary.docked = false
        D8.Refresh()
        local gid = G8.Merge("primary", "stats_spell", "bottom")
        assertTrue(gid ~= nil, "merged")
        assertPlain(G8.Section(gid, "primary").header.filter, "merged primary")
        assertTrue(NS.SetByPath("layout.blocks.primary.filter", "belowCap"))
        M.__fireTimers()
        assertBadge(G8.Section(gid, "primary").header.filter, "merged primary")
        assertBadge(G8.Section(gid, "stats_spell").header.filter, "merged stats_spell")
    end)
end)

-- ── R8-1: Open a row from, Full row (the default) or Go icon only ─────────────────────────────
-- Blacksmithing is the main window's crafting row here and Enchanting the LDB tooltip's: no other
-- suite arms either, so their overlays (made once, never destroyed) are this file's alone.

local SO8, I8, R8, RT8, L8 = NS.SecureOverlay, NS.Interact, NS.Rows, NS.RowTooltip, NS.L

local function sk8(key, name, category, rank, max)
    return { key = key, name = name, category = category, kind = NS.SkillCatalog[key] and NS.SkillCatalog[key].kind,
             rank = rank, max = max, tempPoints = 0, modifier = 0, learned = true }
end

local SWAP8 = { "InCombatLockdown", "IsShiftKeyDown", "ToggleCharacter", "ChatEdit_InsertLink", "CharacterMicroButton",
                "GetCursorPosition" }

--- Swap the click globals for recorders: out of combat, Shift up, no micro button (a weapon or stat
--- row then opens by its plain click), the panel opens and the links recorded. Answers the world
--- and the put-back.
local function clickWorld()
    local saved = {}
    for _, k in ipairs(SWAP8) do saved[k] = M[k] end
    M.InCombatLockdown = function() return false end
    M.IsShiftKeyDown = function() return false end
    M.CharacterMicroButton = nil
    M.GetCursorPosition = function() return 400, 300 end
    local world = { opened = {}, linked = {} }
    M.ToggleCharacter = function(tab) world.opened[#world.opened + 1] = tab end
    M.ChatEdit_InsertLink = function(text) world.linked[#world.linked + 1] = text return true end
    return world, function() for _, k in ipairs(SWAP8) do M[k] = saved[k] end end
end

local function closeMenus()
    if NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end
    if I8.menu and I8.menu.__fire then I8.menu:__fire("OnHide") end
end

--- The main window over a fixture (Blacksmithing, Guns, the Hit stat), Open a row from = `openFrom`;
--- every block docked again, no merged window, everything put back after.
local function withWindowRows(openFrom, fn)
    local byKey = { blacksmithing = sk8("blacksmithing", "Blacksmithing", "primary", 120, 150),
                    guns = sk8("guns", "Guns", "weapon", 105, 110) }
    local skills = { byKey = byKey, order = { primary = { "blacksmithing" }, secondary = {}, weapon = { "guns" }, other = {} } }
    local stats = { base = { { key = "hit", label = "Hit", value = 2, display = "2.0%", pct = 22.2, ref = 9, markers = {} } },
                    spell = {}, defense = {}, utility = {} }
    local lay, savedSource = NS.db.profile.layout, B8.source
    local savedFrom = lay.openFrom
    B8.source = function() return skills, stats end
    lay.openFrom = openFrom
    local world, putBack = clickWorld()
    W8.Show()
    W8.Refresh(true)
    local ok, err = pcall(fn, world)
    W8.Hide()
    closeMenus()
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].docked = true end
    NS.db.profile.layout.groups = {}
    D8.Refresh()
    putBack()
    B8.source, lay.openFrom = savedSource, savedFrom
    SO8:Sync()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function rowIn(rows, key)
    for _, row in ipairs(rows) do if row.entry and row.entry.key == key then return row end end
    return nil
end

local function windowRow(key) return rowIn(W8.Rows(), key) end

--- `f` answers the rect (left, top, w, h) at scale 1; undone by unplace.
local function place8(f, l, t, w, h)
    rawset(f, "GetLeft", function() return l end)
    rawset(f, "GetTop", function() return t end)
    rawset(f, "GetEffectiveScale", function() return 1 end)
    f:__setGeom(w, h)
end

local function unplace8(f)
    for _, k in ipairs({ "GetLeft", "GetTop", "GetEffectiveScale" }) do rawset(f, k, nil) end
    f.__geomLive = nil
end

local function valuesOf(row)
    local v, t = {}, {}
    for _, val in ipairs(row.values) do v[#v + 1], t[#t + 1] = val.value, val.text end
    return table.concat(v, ","), table.concat(t, ",")
end

test("round8 open a row from: Layout > Window's Open a row from, Full row by default; the LDB tooltip's too", function()
    assertEqual(NS.defaults.profile.layout.openFrom, "row", "a main window row opens from anywhere on it")
    local row = NS.FindSchemaRow("layout.openFrom")
    assertTrue(row ~= nil, "the schema row")
    assertEqual(row.page, "layout")
    assertEqual(row.group, L8["Window"])
    assertEqual(row.label, L8["Open a row from"])
    assertEqual(row.default, "row")
    local values, texts = valuesOf(row)
    assertEqual(values, "row,icon")
    assertEqual(texts, L8["Full row"] .. "," .. L8["Go icon only"])
    assertEqual(NS.defaults.profile.tooltips.ldb.openFrom, "row", "the LDB tooltip's (R7-6) defaults to Full row")
    local ldb = NS.FindSchemaRow("tooltips.ldb.openFrom")
    assertEqual(ldb.default, "row")
    values, texts = valuesOf(ldb)
    assertEqual(values, "row,icon")
    assertEqual(texts, L8["Full row"] .. "," .. L8["Go icon only"], "the same two choices, named the same")
end)

test("round8 open a row from: Full row lays the crafting cast over the whole row, Go icon only over the icon", function()
    local US = M.UIParent
    for _, mode in ipairs({ "row", "icon" }) do
        withWindowRows(mode, function()
            local row = windowRow("blacksmithing")
            assertTrue(SO8.CoverFor(row) == (mode == "row" and row or row.act), mode .. ": what the overlay covers")
            place8(row, 100, 500, 300, 20)
            place8(row.act, 378, 499, 18, 18)
            rawset(US, "GetEffectiveScale", function() return 1 end)
            local size = {}
            local ok, err = pcall(function()
                row:__fire("OnEnter")   -- made on the first hover; the size recorded on the next
                local b = SO8.Overlay("blacksmithing")
                SO8:Unhover(row)
                rawset(b, "SetSize", function(_, w, h) size.w, size.h = w, h end)
                row:__fire("OnEnter")
                rawset(b, "SetSize", nil)
                assertTrue(b ~= nil and b:IsShown() and b.row == row, mode .. ": armed on the hover")
                assertEqual(b.kind, "spell", mode .. ": the crafting cast")
                assertEqual(size.w, mode == "row" and 300 or 18, mode .. ": the overlay's width")
                assertEqual(size.h, mode == "row" and 20 or 18, mode .. ": its height")
                assertTrue(b:GetFrameLevel() > row:GetFrameLevel(), mode .. ": above the row")
            end)
            unplace8(row)
            unplace8(row.act)
            rawset(US, "GetEffectiveScale", nil)
            SO8:Unhover(row)
            if not ok then error(err, 0) end
        end)
    end
end)

test("round8 open a row from: a Full row click opens what the go icon opens; Go icon only, the row opens nothing", function()
    withWindowRows("row", function(world)
        windowRow("guns"):__fire("OnClick", "LeftButton")
        windowRow("hit"):__fire("OnClick", "LeftButton")
        assertEqual(table.concat(world.opened, ","), "SkillsFrame,PaperDollFrame", "the Skills tab, the paper doll")
    end)
    withWindowRows("icon", function(world)
        windowRow("guns"):__fire("OnClick", "LeftButton")
        windowRow("hit"):__fire("OnClick", "LeftButton")
        assertEqual(#world.opened, 0, "the row itself opens nothing")
        windowRow("guns").act:__fire("OnClick", "LeftButton")
        assertEqual(table.concat(world.opened, ","), "SkillsFrame", "its go icon does")
    end)
end)

test("round8 open a row from: shift-click links and right-click opens the menu in both modes, on the row and its overlay", function()
    for _, mode in ipairs({ "row", "icon" }) do
        withWindowRows(mode, function(world)
            local menus, realMenu = 0, I8.Menu
            I8.Menu = function() menus = menus + 1 end
            local ok, err = pcall(function()
                local guns = windowRow("guns")
                guns:__fire("OnClick", "RightButton")
                M.IsShiftKeyDown = function() return true end
                guns:__fire("OnClick", "LeftButton")
                local row = windowRow("blacksmithing")
                row:__fire("OnEnter")
                local b = SO8.Overlay("blacksmithing")
                assertTrue(b ~= nil and b:IsShown(), mode .. ": armed")
                b:GetScript("PostClick")(b, "LeftButton", false)
                M.IsShiftKeyDown = function() return false end
                b:GetScript("PostClick")(b, "RightButton", false)
                assertEqual(#world.linked, 2, mode .. ": the row and the overlay each link")
                assertEqual(#world.opened, 0, mode .. ": a shift-click or right-click opens nothing")
                assertEqual(menus, 2, mode .. ": the row and the overlay each open the menu")
                SO8:Unhover(row)
            end)
            I8.Menu = realMenu
            if not ok then error(err, 0) end
        end)
    end
end)

test("round8 open a row from: the crafting overlay casts on a plain left click only, never in combat", function()
    withWindowRows("row", function()
        local row = windowRow("blacksmithing")
        row:__fire("OnEnter")
        local b = SO8.Overlay("blacksmithing")
        local attr, sets = { type1 = "unset" }, 0
        rawset(b, "SetAttribute", function(_, k, v) attr[k], sets = v, sets + 1 end)
        local ok, err = pcall(function()
            local pre = b:GetScript("PreClick")
            assertTrue(pre ~= nil, "a PreClick on the cast")
            M.IsShiftKeyDown = function() return true end
            pre(b, "LeftButton", true)
            assertEqual(attr.type1, nil, "a shift-click links: no cast")
            M.IsShiftKeyDown = function() return false end
            pre(b, "RightButton", true)
            assertEqual(attr.type1, nil, "a right-click opens the menu: no cast")
            pre(b, "LeftButton", true)
            assertEqual(attr.type1, "spell", "a plain left click casts")
            M.InCombatLockdown = function() return true end
            local before = sets
            pre(b, "LeftButton", true)
            assertEqual(sets, before, "no attribute is written in combat")
            M.InCombatLockdown = function() return false end
        end)
        rawset(b, "SetAttribute", nil)
        SO8:Unhover(row)
        if not ok then error(err, 0) end
    end)
end)

test("round8 open a row from: in combat a Full row arms nothing and its click says why; armed again after", function()
    withWindowRows("row", function(world)
        M.__fireEvent("PLAYER_REGEN_DISABLED")
        M.InCombatLockdown = function() return true end
        local row = windowRow("blacksmithing")
        row:__fire("OnEnter")
        local b = SO8.Overlay("blacksmithing")
        assertTrue(b == nil or not b:IsShown(), "nothing armed in combat")
        M.__resetPrinted()
        row:__fire("OnClick", "LeftButton")
        assertEqual(#M.__printed(), 1, "one line says why the profession cannot open in combat")
        M.__resetPrinted()
        windowRow("hit"):__fire("OnClick", "LeftButton")
        assertEqual(#world.opened, 0, "never a tainted panel in combat")
        assertEqual(#M.__printed(), 1, "one line says why")
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        b = SO8.Overlay("blacksmithing")
        assertTrue(b ~= nil and b:IsShown() and b.row == row, "armed again after combat, the row still hovered")
        assertTrue(SO8.CoverFor(row) == row, "over the whole row")
        SO8:Unhover(row)
    end)
end)

test("round8 open a row from: detached and merged windows follow the main window's setting", function()
    withWindowRows("row", function(world)
        B8:Detach("weapon")
        M.__fireTimers()
        local guns = rowIn(D8.Rows("weapon"), "guns")
        assertTrue(guns ~= nil, "the detached weapon row")
        assertEqual(R8.OpenFrom(guns), "row")
        guns:__fire("OnClick", "LeftButton")
        assertEqual(table.concat(world.opened, ","), "SkillsFrame", "the detached row opens from anywhere on it")
        NS.db.profile.layout.blocks.primary.docked = false
        D8.Refresh()
        local gid = G8.Merge("primary", "weapon", "bottom")
        assertTrue(gid ~= nil, "merged")
        local row = rowIn(G8.Rows(gid), "blacksmithing")
        assertTrue(row ~= nil, "the merged window's crafting row")
        row:__fire("OnEnter")
        local b = SO8.Overlay("blacksmithing")
        assertTrue(b ~= nil and b:IsShown() and b.row == row, "armed over the merged row")
        assertTrue(SO8.CoverFor(row) == row, "over the whole row")
        SO8:Unhover(row)
        NS.db.profile.layout.openFrom = "icon"
        assertEqual(R8.OpenFrom(row), "icon", "Go icon only reaches the merged window")
        assertTrue(SO8.CoverFor(row) == row.act, "the overlay back on the icon")
        guns = rowIn(G8.Rows(gid), "guns")
        guns:__fire("OnClick", "LeftButton")
        assertEqual(#world.opened, 1, "and its row opens nothing")
    end)
end)

test("round8 open a row from: the row tooltip's click hint says the mode", function()
    local e = sk8("blacksmithing", "Blacksmithing", "primary", 120, 150)
    local stat = { key = "hit", label = "Hit", value = 2, display = "2.0%", pct = 22.2, markers = {} }
    local function hintOf(entry, kind, mode)
        local lines = RT8.Lines(entry, kind, mode)
        return lines[#lines].left
    end
    assertEqual(hintOf(e, "skill", "row"), L8["Click: open the profession \194\183 Shift-click: link \194\183 Right-click: menu"])
    assertEqual(hintOf(e, "skill", "icon"), L8["Arrow: open the profession \194\183 Shift-click: link \194\183 Right-click: menu"])
    assertEqual(hintOf(stat, "stat", "row"), L8["Click: character panel \194\183 Shift-click: link \194\183 Right-click: menu"])
    assertEqual(hintOf(stat, "stat", "icon"), L8["Arrow: character panel \194\183 Shift-click: link \194\183 Right-click: menu"])
    for _, mode in ipairs({ "row", "icon" }) do
        withWindowRows(mode, function()
            local got, real = nil, RT8.Lines
            RT8.Lines = function(entry, kind, from) got = from return real(entry, kind, from) end
            local ok, err = pcall(function() windowRow("guns"):__fire("OnEnter") end)
            RT8.Lines = real
            windowRow("guns"):__fire("OnLeave")
            if not ok then error(err, 0) end
            assertEqual(got, mode, mode .. ": a hovered row's tooltip names its mode")
        end)
    end
end)

-- The LDB tooltip's Main window style (R7-6's setting, Full row by default since round 8).

local function withLdb(openFrom, fn)
    local p = NS.db.profile.tooltips.ldb
    local saved = { source = Br.source, style = p.style, from = p.openFrom, open = Br.OpenRow }
    local byKey = { enchanting = tipSkill("enchanting", "Enchanting", "primary", 120, 150),
                    maces = tipSkill("maces", "Maces", "weapon", 100, 110) }
    local v = { model = { byKey = byKey, order = { primary = { "enchanting" }, secondary = {},
                weapon = { "maces" }, other = {} } },
                statsModel = { base = {}, spell = {}, defense = {}, utility = {} }, statIndex = {},
                gains = { total = 0, byKey = {} } }
    Br.source = function() return v end
    p.style, p.openFrom = "window", openFrom
    local world, putBack = clickWorld()
    local ok, err = pcall(fn, world)
    Br.OpenRow = saved.open
    local f = BP.Frame()
    Br.HideTooltip()
    f:__fire("OnHide")
    Br.source, p.style, p.openFrom = saved.source, saved.style, saved.from
    putBack()
    SO8:Sync()
    closeMenus()
    if not ok then error(err, 0) end
end

local function recordOpenRow8()
    local got = {}
    Br.OpenRow = function(r, button) got[#got + 1] = r.kind .. ":" .. r.key .. ":" .. tostring(button) end
    return got
end

test("round8 open a row from: the LDB tooltip's Full row arms the cast over the whole row and opens from anywhere", function()
    withLdb("row", function(world)
        assertEqual(Br.OpenFrom(), "row")
        Br.OnEnter(M.UIParent)
        assertTrue(BP.Armed(), "the overlay scans the panel's rows in both modes")
        local row = rowIn(BP.Rows(), "enchanting")
        assertEqual(R8.OpenFrom(row), "row", "the panel's row follows the tooltip's setting")
        row:__fire("OnEnter")
        local b = SO8.Overlay("enchanting")
        assertTrue(b ~= nil and b:IsShown() and b.row == row, "armed on the hover")
        assertTrue(SO8.CoverFor(row) == row, "over the whole row")
        local got = recordOpenRow8()
        b:GetScript("PostClick")(b, "RightButton", false)
        assertEqual(table.concat(got, ","), "skill:enchanting:RightButton", "the overlay's right-click: the row menu")
        SO8:Unhover(row)
        local maces = rowIn(BP.Rows(), "maces")
        maces:__fire("OnClick", "LeftButton")
        assertEqual(table.concat(world.opened, ","), "SkillsFrame", "a plain click opens what the go icon opens")
        assertEqual(#got, 1, "not the Classic row's open")
        maces:__fire("OnClick", "RightButton")
        M.IsShiftKeyDown = function() return true end
        maces:__fire("OnClick", "LeftButton")
        M.IsShiftKeyDown = function() return false end
        assertEqual(table.concat(got, ",", 2), "skill:maces:RightButton,skill:maces:LeftButton", "the menu, the link")
        local footer = BP.Frame().footer:GetText()
        assertEqual(footer, Br.FooterText("row"))
        assertTrue(footer:find("shift-click to link", 1, true) ~= nil, "the footer names the link")
        assertTrue(footer:find("go icon", 1, true) == nil, "and no go icon")
    end)
end)

test("round8 open a row from: the LDB tooltip's Go icon only keeps the cast on the icon and the row inert", function()
    withLdb("icon", function(world)
        Br.OnEnter(M.UIParent)
        local row = rowIn(BP.Rows(), "enchanting")
        assertEqual(R8.OpenFrom(row), "icon")
        assertTrue(SO8.CoverFor(row) == row.act, "over the go icon")
        local maces = rowIn(BP.Rows(), "maces")
        maces:__fire("OnClick", "LeftButton")
        assertEqual(#world.opened, 0, "the row's plain click opens nothing")
        maces.act:__fire("OnClick", "LeftButton")
        assertEqual(table.concat(world.opened, ","), "SkillsFrame", "its go icon does")
        assertEqual(BP.Frame().footer:GetText(), Br.FooterText("icon"))
    end)
end)
