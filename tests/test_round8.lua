-- tests/test_round8.lua — the owner's round-8 feedback (2026-11-14): the header marks of a detached
-- or merged window in the main window header's color (R8-3).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

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
