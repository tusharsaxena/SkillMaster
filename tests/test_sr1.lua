-- tests/test_sr1.lua — smoke round 1 of the LibKa0s v1.105.0 run (Ka0sAddonsCommonTasks
-- docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/SR1_SMOKE_ROUND1.md), this addon's own windows:
--   ruling 3, every title-bar and header-strip control shows a one-line tooltip on hover, above it
--     (LibKa0s-Tooltip-1.0's AttachTitleTip: owned at ANCHOR_NONE, placed by PlaceAttached), in the
--     owner's `gtip.title`;
--   ruling 4, at rest every mark paints `icon.tint` and under the pointer `text.link`; the close X
--     rests in `close.rest` (which follows `icon.tint`) and lights `close.hot`; pinned per skin;
--   ruling 5, the block header band (`sm.headerBg`) resolves to `list.header.bg` in every skin.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local W, J, B, D, G, TP = NS.MainWindow, NS.Journal, NS.Blocks, NS.Detached, NS.Groups, NS.TrainerPopup
local Skin = M.LibStub("LibKa0s-Skin-1.0")

local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r or -1, g or -1, b or -1) end
local function token(name) return rgb(NS.Skin.Color(name)) end
local function tintOf(b)
    if b.icon then return rgb(b.icon:GetVertexColor()) end
    return rgb(b.glyph:GetTextColor())
end

--- A recording GameTooltip for one hover of `b`: answers the words and their color, or nil.
local function hoverTip(b)
    local saved = M.GameTooltip
    local rec = { shown = false }
    local tip = {
        SetOwner = function(_, owner, anchor) rec.owner, rec.anchor = owner, anchor end,
        SetText = function(_, s, r, g, bl) rec.text, rec.color = s, rgb(r, g, bl) end,
        AddLine = function(_, s, r, g, bl) rec.text, rec.color = rec.text or s, rec.color or rgb(r, g, bl) end,
        Show = function() rec.shown = true end,
        Hide = function() rec.shown = false end,
        IsOwned = function(_, f) return rec.owner == f end,
        ClearAllPoints = function() end,
        SetPoint = function(_, p, rel, relP) rec.point = p .. ">" .. tostring(relP) rec.rel = rel end,
        GetWidth = function() return nil end, GetHeight = function() return nil end,
    }
    M.GameTooltip = tip
    local ok, err = pcall(function()
        b:__fire("OnEnter")
        b:__fire("OnLeave")
    end)
    M.GameTooltip = saved
    if not ok then error(err, 0) end
    return rec
end

local function assertTip(b, what)
    assertTrue(b ~= nil, what .. ": the control exists")
    local rec = hoverTip(b)
    assertTrue(type(rec.text) == "string" and rec.text ~= "", what .. ": a tooltip on hover")
    assertEqual(rec.owner, b, what .. ": owned by the control")
    assertEqual(rec.anchor, "ANCHOR_NONE", what .. ": placed, never at a game anchor")
    assertEqual(rec.point, "BOTTOM>TOP", what .. ": above the control")
    assertEqual(rec.color, token("gtip.title"), what .. ": in the owner's gtip.title")
    assertTrue(rec.shown == false, what .. ": hidden on leave")
end

local function assertMarkColors(b, what)
    b:__fire("OnLeave")
    assertEqual(tintOf(b), token("icon.tint"), what .. ": icon.tint at rest")
    b:__fire("OnEnter")
    assertEqual(tintOf(b), token("text.link"), what .. ": text.link under the pointer")
    b:__fire("OnLeave")
    assertEqual(tintOf(b), token("icon.tint"), what .. ": icon.tint again")
end

local function assertCloseColors(b, what)
    b:__fire("OnLeave")
    assertEqual(tintOf(b), token("close.rest"), what .. ": close.rest at rest")
    assertEqual(token("close.rest"), token("icon.tint"), what .. ": which is the marks' icon.tint")
    b:__fire("OnEnter")
    assertEqual(tintOf(b), token("close.hot"), what .. ": close.hot under the pointer")
    b:__fire("OnLeave")
end

--- Every window this addon draws, open, each window's title-bar / header-strip controls by name.
local function withWindows(fn)
    local wasLocked = NS.GetSetting("locked")
    local savedMenu = NS.Widgets.ContextMenu
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    NS.Preview.Apply(true)
    W.Show()
    W.Refresh(true)
    J.Show()
    TP.Show("fistWeapons")
    B:Detach("weapon")
    M.__fireTimers()
    local b = NS.db.profile.layout.blocks
    b.primary.docked, b.other.docked = false, false
    D.Refresh()
    local gid = G.Merge("primary", "other", "bottom")
    M.__fireTimers()
    local main = W.Frame()
    local header = W.Headers()[1]
    local band = D.Frame("weapon")
    local merged = G.Frame(gid)
    local sub = G.Section(gid, "primary").header
    local windows = {
        { name = "the main window", close = main.close,
          marks = { main.lockButton, main.journalButton, main.settingsButton, main.toggleAllButton } },
        { name = "the journal", close = J.Frame().close, marks = { J.Frame().lockButton } },
        { name = "the trainer popup", close = TP.Frame().close, marks = {} },
        { name = "a block header", marks = { header.chevron, header.detach, header.sort, header.filter } },
        { name = "a detached block's band", marks = { band.dock, band.collapse, band.sort, band.filter } },
        { name = "a merged window's band", marks = { merged.dockAll, merged.collapseAll } },
        { name = "a merged section's sub-header", marks = { sub.chevron, sub.split, sub.sort, sub.filter } },
    }
    local ok, err = pcall(fn, windows)
    TP.Hide()
    J.Hide()
    for _, id in ipairs(NS.BLOCKS) do
        local s = NS.db.profile.layout.blocks[id]
        s.filter, s.docked, s.collapsed = "all", true, false
    end
    NS.db.profile.layout.groups = {}
    D.Refresh()
    W.Hide()
    NS.Preview.Apply(false)
    NS.Widgets.ContextMenu = savedMenu
    M.UnitFactionGroup = savedFaction
    NS.SetByPath("locked", wasLocked and true or false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function skinKeys()
    local keys = {}
    for _, s in ipairs(Skin:Skins()) do keys[#keys + 1] = s.key end
    return keys
end

local function inSkin(key, fn)
    local was = NS.GetSetting("skin.skin")
    NS.SetByPath("skin.skin", key)
    M.__fireTimers()
    local ok, err = pcall(fn)
    NS.SetByPath("skin.skin", was or NS.DEFAULT_SKIN)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local WINDOW_NAMES = { "the main window", "the journal", "the trainer popup", "a block header",
    "a detached block's band", "a merged window's band", "a merged section's sub-header" }

for idx, name in ipairs(WINDOW_NAMES) do
    test(("sr1 title-bar tips: every control of %s shows its tooltip above it, in gtip.title"):format(name), function()
        withWindows(function(windows)
            local w = windows[idx]
            assertEqual(w.name, name, "the window table and the names agree")
            if w.close then assertTip(w.close, w.name .. " close") end
            for i, b in ipairs(w.marks) do assertTip(b, w.name .. " mark " .. i) end
        end)
    end)
end

test("sr1 title-bar colors: every mark icon.tint at rest and text.link hot, the close close.rest and close.hot, in Ka0s Default and every other skin", function()
    local keys = skinKeys()
    assertTrue(#keys >= 2 and keys[1] == "ka0s", "Ka0s Default and at least one more skin")
    for _, key in ipairs(keys) do
        inSkin(key, function()
            withWindows(function(windows)
                for _, w in ipairs(windows) do
                    if w.close then assertCloseColors(w.close, key .. ": " .. w.name .. " close") end
                    for i, b in ipairs(w.marks) do assertMarkColors(b, key .. ": " .. w.name .. " mark " .. i) end
                end
            end)
        end)
    end
end)

test("sr1 title-bar colors: a narrowing filter keeps its filled badge (a state color) at rest", function()
    withWindows(function()
        local id = W.Headers()[1].id
        assertTrue(NS.SetByPath("layout.blocks." .. id .. ".filter", B.FiltersOf(id)[2]))
        M.__fireTimers()
        local mark
        for _, h in ipairs(W.Headers()) do if h.id == id then mark = h.filter end end
        assertTrue(mark.badge ~= nil and mark.badge:IsShown(), "the badge shows while the filter narrows")
        assertEqual(mark.badgeToken, "icon.tint", "the badge in the marks' rest color")
        assertTrue(NS.SetByPath("layout.blocks." .. id .. ".filter", "all"))
        M.__fireTimers()
    end)
end)

test("sr1 header bands: sm.headerBg resolves to list.header.bg in every skin", function()
    local keys = skinKeys()
    assertTrue(#keys >= 9, "the nine shipped skins: " .. #keys)
    for _, key in ipairs(keys) do
        inSkin(key, function()
            local _, applied = Skin:GetChoice(NS.ADDON_NAME or "SkillMaster")
            assertEqual(applied, key, "the skin applied")
            local want = { NS.Skin.Color("list.header.bg") }
            local got = { NS.Skin.Color("sm.headerBg") }
            assertTrue(want[1] ~= nil, key .. ": list.header.bg resolves")
            for i = 1, 4 do
                assertTrue(math.abs((got[i] or -1) - want[i]) < 1e-6, key .. ": component " .. i .. " is list.header.bg's")
            end
            local h
            W.Show()
            W.Refresh(true)
            h = W.Headers()[1]
            local r, g, b, a = h.bg:GetVertexColor()
            local c = h.bg.__color
            if c then r, g, b, a = c[1], c[2], c[3], c[4] end
            assertEqual(rgb(r, g, b), rgb(want[1], want[2], want[3]), key .. ": the block header's band paints it")
            assertTrue(math.abs((a or 1) - (want[4] or 1)) < 1e-6, key .. ": with its alpha")
            W.Hide()
        end)
    end
end)
