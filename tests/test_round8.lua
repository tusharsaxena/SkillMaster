-- tests/test_round8.lua — the owner's round-8 feedback (2026-11-14): the header marks of a detached
-- or merged window in the main window header's color (R8-3); the LDB tooltip's headers without
-- their sort and filter marks (R8-4); the active filter as a filled badge (R8-2).
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
