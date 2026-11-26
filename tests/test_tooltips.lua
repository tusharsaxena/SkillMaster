-- tests/test_tooltips.lua — where Skill Master's own tooltips open (LibKa0s#92, AD-92-SM of
-- Ka0sAddonsCommonTasks docs/2026-11-17-LIBKA0S_V1_105_ADOPTION/; WowAddonStandards
-- standalone-windows, *Tooltip placement*, and launcher-§7).
--
-- Every tooltip this addon places itself is owned at ANCHOR_NONE, filled, shown and then placed by
-- LibKa0s-Tooltip-1.0 through NS.Chrome's three placers:
--   BODY, beside the window group (PlaceBeside): a skill or stat row (main window, detached HUD,
--     merged window, broker panel; the group is GroupOf, the row's outermost frame), a Journal
--     column header (the Journal), a trainer card (the trainer popup), the waypoint arrow (the HUD
--     display is the arrow itself);
--   CHROME, attached above (PlaceAttached): the trainer popup's Set waypoint button (a modal's
--     action control);
--   LAUNCHER, toward the screen's center (PlaceLauncher): the broker feed's tooltip on its cell.
-- Each was owned at a game anchor before (ANCHOR_RIGHT, ANCHOR_TOP, ANCHOR_BOTTOM: a corner or edge
-- offset of the control, which the rule retires). Without the library, or on unreadable geometry,
-- the tooltip attaches centered above its element, never at the cursor.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local W, J, TP, WA, Br, C = T.windows, NS.Journal, NS.TrainerPopup, NS.WaypointArrow, NS.Broker, NS.Chrome

--- Spy on the library's three placers while `fn` runs; answers the calls.
local function spyPlacers(fn)
    local Tip = M.LibStub("LibKa0s-Tooltip-1.0")
    local calls = {}
    local beside, attached, launcher = Tip.PlaceBeside, Tip.PlaceAttached, Tip.PlaceLauncher
    Tip.PlaceBeside = function(tip, el, group, opts)
        calls[#calls + 1] = { kind = "beside", tip = tip, el = el, group = group }
        return beside(tip, el, group, opts)
    end
    Tip.PlaceAttached = function(tip, el, opts)
        calls[#calls + 1] = { kind = "attached", tip = tip, el = el }
        return attached(tip, el, opts)
    end
    Tip.PlaceLauncher = function(tip, el, opts)
        calls[#calls + 1] = { kind = "launcher", tip = tip, el = el }
        return launcher(tip, el, opts)
    end
    local ok, err = pcall(fn, calls)
    Tip.PlaceBeside, Tip.PlaceAttached, Tip.PlaceLauncher = beside, attached, launcher
    if not ok then error(err, 0) end
    return calls
end

--- A recording GameTooltip while `fn(tip)` runs: SetOwner's anchor and the points it is given.
local function withTip(fn)
    local saved = M.GameTooltip
    local rec = { points = {} }
    local tip = setmetatable({}, { __index = saved })
    tip.SetOwner = function(_, owner, anchor) rec.owner, rec.anchor = owner, anchor; rec.points = {} end
    tip.GetOwner = function() return rec.owner end
    tip.IsOwned = function(_, f) return rec.owner == f end
    tip.ClearAllPoints = function() rec.points = {} end
    tip.SetPoint = function(_, p, rel, relP, x, y)
        rec.points[#rec.points + 1] = { p, rel, relP, x, y }
    end
    M.GameTooltip = tip
    local ok, err = pcall(fn, tip, rec)
    M.GameTooltip = saved
    if not ok then error(err, 0) end
    return rec
end

--- Hover with `fire()` under the spy and the recording tooltip: answers the calls, the record and
--- the tooltip.
local function hover(fire)
    local rec, tip
    local calls = spyPlacers(function()
        rec = withTip(function(t) tip = t; fire() end)
    end)
    return calls, rec, tip
end

--- One placement on `calls`: the last call, of `kind`, on the game tooltip and the element `el`.
local function assertPlaced(calls, rec, tip, kind, el, what)
    local c = calls[#calls]
    assertTrue(c ~= nil, what .. ": a placer is called")
    assertEqual(c.kind, kind, what .. ": by the " .. kind .. " placer")
    assertTrue(c.tip == tip, what .. ": on the game tooltip")
    assertTrue(c.el == el, what .. ": against the hovered element")
    assertEqual(rec.anchor, "ANCHOR_NONE", what .. ": owned at ANCHOR_NONE, never a game anchor")
    assertTrue(rec.owner == el, what .. ": owned by the hovered element")
    return c
end

local function rowIn(rows, key)
    for _, row in ipairs(rows) do if row.entry and row.entry.key == key then return row end end
    return rows[1]
end

-- ---------------------------------------------------------------------------------------------
-- 1. The body elements: beside the window group
-- ---------------------------------------------------------------------------------------------

test("tooltips: a main window row opens beside the window (PlaceBeside), never at ANCHOR_RIGHT", function()
    -- red under: GameTooltip:SetOwner(row, "ANCHOR_RIGHT") in RowTooltip.Show, the corner offset.
    NS.Preview.Apply(true)
    W.Show()
    W.Refresh(true)
    local ok, err = pcall(function()
        local row = rowIn(W.Rows(), "tailoring")
        assertTrue(row ~= nil and row.entry ~= nil, "the window draws rows")
        local calls, rec, tip = hover(function() row:__fire("OnEnter") end)
        local c = assertPlaced(calls, rec, tip, "beside", row, "a main window row")
        assertTrue(c.group == nil, "the group is the row's window (GroupOf)")
        row:__fire("OnLeave")
    end)
    W.Hide()
    NS.Preview.Apply(false)
    if not ok then error(err, 0) end
end)

test("tooltips: a detached block's row opens beside the detached display (PlaceBeside, GroupOf)", function()
    -- red under: the row tooltip's ANCHOR_RIGHT, on a HUD display's row as on the window's.
    NS.Preview.Apply(true)
    local b = NS.db.profile.layout.blocks
    b.primary.docked = false
    NS.Detached.Refresh()
    local ok, err = pcall(function()
        local row = rowIn(NS.Detached.Rows("primary"), "tailoring")
        assertTrue(row ~= nil and row.entry ~= nil, "the detached frame draws rows")
        local calls, rec, tip = hover(function() row:__fire("OnEnter") end)
        local c = assertPlaced(calls, rec, tip, "beside", row, "a detached row")
        assertTrue(c.group == nil, "the group is the whole display (GroupOf)")
        row:__fire("OnLeave")
    end)
    b.primary.docked = true
    NS.Detached.Refresh()
    NS.Preview.Apply(false)
    if not ok then error(err, 0) end
end)

test("tooltips: a Journal column header opens beside the Journal (PlaceBeside), never at ANCHOR_BOTTOM", function()
    -- red under: GameTooltip:SetOwner(head, "ANCHOR_BOTTOM") in the Journal's onHeadEnter.
    local chars = NS.db.global.characters
    local saved = {}
    for k, v in pairs(chars) do saved[k] = v end
    chars["Samplerealm-Samplehunter Mockstride"] = {
        name = "Samplehunter Mockstride", class = "HUNTER", className = "Hunter", race = "Dwarf", level = 22,
        skills = { leatherworking = { name = "Leatherworking", category = "primary", rank = 146, max = 150 } },
    }
    J.Show()
    J.SelectTab("alts")
    local ok, err = pcall(function()
        local p = J.Frame().altsPanel
        local head
        for c, item in ipairs(p.list) do if item.key == "Samplerealm-Samplehunter Mockstride" then head = p.heads[c] end end
        assertTrue(head ~= nil, "the character's column header")
        local calls, rec, tip = hover(function() head:GetScript("OnEnter")(head) end)
        local c = assertPlaced(calls, rec, tip, "beside", head, "a Journal column header")
        assertTrue(c.group == J.Frame(), "the Journal is the window group")
        head:GetScript("OnLeave")(head)
    end)
    J.SelectTab("log")
    J.Hide()
    for k in pairs(chars) do chars[k] = nil end
    for k, v in pairs(saved) do chars[k] = v end
    if not ok then error(err, 0) end
end)

--- The trainer popup open on a skill with trainers, for `fn`.
local function withPopup(fn)
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    TP.Show("fistWeapons")
    local ok, err = pcall(fn)
    TP.Hide()
    M.UnitFactionGroup = savedFaction
    if not ok then error(err, 0) end
end

test("tooltips: a trainer card opens beside the popup (PlaceBeside), never at ANCHOR_RIGHT", function()
    -- red under: GameTooltip:SetOwner(self, "ANCHOR_RIGHT") in the popup's onCardEnter.
    withPopup(function()
        local card = TP.Cards()[1]
        assertTrue(card ~= nil and card.trainer ~= nil, "the popup lists a trainer")
        local calls, rec, tip = hover(function() card:GetScript("OnEnter")(card) end)
        local c = assertPlaced(calls, rec, tip, "beside", card, "a trainer card")
        assertTrue(c.group == TP.Frame(), "the popup is the window group")
        card:GetScript("OnLeave")(card)
    end)
end)

test("tooltips: the popup's disabled Set waypoint button attaches its reason above it (PlaceAttached), never ANCHOR_TOP", function()
    -- red under: GameTooltip:SetOwner(self, "ANCHOR_TOP") on the Set waypoint button's hover.
    withPopup(function()
        local b = TP.Frame().waypoint
        local savedText = b.blockedText
        b.blockedText = "the reason"
        local ok, err = pcall(function()
            local calls, rec, tip = hover(function() b:__fire("OnEnter") end)
            assertPlaced(calls, rec, tip, "attached", b, "the Set waypoint button")
        end)
        b:__fire("OnLeave")
        b.blockedText = savedText
        if not ok then error(err, 0) end
    end)
end)

test("tooltips: the waypoint arrow opens beside itself, the whole HUD display (PlaceBeside), never ANCHOR_RIGHT", function()
    -- red under: GameTooltip:SetOwner(f, "ANCHOR_RIGHT") in the arrow's onEnter.
    local wp = NS.db.profile.waypoints
    local savedArrow = wp.arrow
    wp.arrow = true
    WA.ShowTest()
    local ok, err = pcall(function()
        local f = WA.Frame()
        assertTrue(f ~= nil and WA.Target() ~= nil, "the sample arrow shows")
        local calls, rec, tip = hover(function() f:__fire("OnEnter") end)
        local c = assertPlaced(calls, rec, tip, "beside", f, "the waypoint arrow")
        assertTrue(c.group == f, "the arrow is its display's whole group")
        f:__fire("OnLeave")
    end)
    WA.HideTest()
    wp.arrow = savedArrow
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- 2. The broker feed's tooltip: the launcher shape, on its cell
-- ---------------------------------------------------------------------------------------------

test("tooltips: the broker feed's tooltip is placed on its cell toward the screen's center (PlaceLauncher), in both styles", function()
    -- red under: the hand-written TOP / BOTTOM anchor in Broker's anchor(), with no horizontal side.
    local scr = dofile("tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
    local cell = scr.frame{ left = 1800, bottom = 1050, width = 100, height = 20 }
    local tt, bt = NS.db.profile.tooltips.ldb, NS.db.profile.broker.tooltip
    local savedStyle, savedSkin = tt.style, bt.skin
    local ok, err = pcall(function()
        -- Classic, unskinned: the shared GameTooltip (the recorder stands in for it).
        tt.style, bt.skin = "classic", false
        local calls, rec, tip = hover(function() Br.OnEnter(cell) end)
        assertPlaced(calls, rec, tip, "launcher", cell, "the Classic feed tooltip")
        local p = rec.points[#rec.points]
        assertTrue(p ~= nil, "a point is written")
        assertEqual(p[1] .. ">" .. p[3], "TOPRIGHT>BOTTOMRIGHT", "a top-right cell opens down and to the left")
        assertTrue(p[2] == cell and p[5] == -2, "on the cell, TIP_GAP under it")
        Br.HideTooltip()
        -- Main window style: the broker panel, placed the same way on the cell.
        tt.style = "window"
        calls = spyPlacers(function() Br.OnEnter(cell) end)
        local c = calls[#calls]
        assertTrue(c ~= nil and c.kind == "launcher", "the panel is placed by the launcher placer")
        assertTrue(c.tip == Br.Tip() and c.el == cell, "the panel, on the cell")
        Br.HideTooltip()
    end)
    tt.style, bt.skin = savedStyle, savedSkin
    scr.restore()
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- 3. Where a body tooltip lands, on the kit's fake screen (the standard's Verification SHOULD)
-- ---------------------------------------------------------------------------------------------

local GEOM = { "GetLeft", "GetBottom", "GetRight", "GetTop", "GetWidth", "GetHeight", "GetEffectiveScale", "GetParent" }

--- Put `frame` at `l, b` (own units, scale 1), `w` x `h`, under `parent`, for the fake screen;
--- answers a function that puts the frame's own fields back.
local function at(frame, l, b, w, h, parent)
    local saved = {}
    for _, k in ipairs(GEOM) do saved[k] = rawget(frame, k) end
    rawset(frame, "GetLeft", function() return l end)
    rawset(frame, "GetBottom", function() return b end)
    rawset(frame, "GetRight", function() return l + w end)
    rawset(frame, "GetTop", function() return b + h end)
    rawset(frame, "GetWidth", function() return w end)
    rawset(frame, "GetHeight", function() return h end)
    rawset(frame, "GetEffectiveScale", function() return 1 end)
    rawset(frame, "GetParent", function() return parent or M.UIParent end)
    return function() for _, k in ipairs(GEOM) do rawset(frame, k, saved[k]) end end
end

--- Hover a main window row with the window at `winLeft` (300 wide) on a 1920x1080 screen and a
--- 250x90 tooltip: answers the tooltip's screen rect.
local function rowOnScreen(winLeft)
    local scr = dofile("tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
    local tip = scr.tooltip{ width = 250, height = 90 }
    local saved = M.GameTooltip
    NS.Preview.Apply(true)
    W.Show()
    W.Refresh(true)
    local win, row = W.Frame(), rowIn(W.Rows(), "tailoring")
    local putWin = at(win, winLeft, 300, 300, 400)
    local putRow = at(row, winLeft + 6, 580, 288, 20, win)
    M.GameTooltip = tip
    local ok, err = pcall(function() row:__fire("OnEnter") end)
    M.GameTooltip = saved
    local l, b, r, t = scr.rectOf(tip)
    putRow()
    putWin()
    W.Hide()
    NS.Preview.Apply(false)
    scr.restore()
    if not ok then error(err, 0) end
    return l, b, r, t
end

test("tooltips: on the fake screen a row's tooltip opens right of the window when it fits, its top level with the row", function()
    local l, _, _, t = rowOnScreen(400)
    assertEqual(l, 700 + 2, "TIP_GAP right of the window's right edge")
    assertEqual(t, 600, "level with the row's top")
end)

test("tooltips: on the fake screen a row's tooltip opens left of the window when the right does not fit", function()
    local _, _, r, t = rowOnScreen(1500)
    assertEqual(r, 1500 - 2, "TIP_GAP left of the window's left edge")
    assertEqual(t, 600, "level with the row's top")
end)

-- ---------------------------------------------------------------------------------------------
-- 4. The library-absent rung, and the guard
-- ---------------------------------------------------------------------------------------------

test("tooltips: without the library a mark's tooltip attaches centered above it, never at a game anchor", function()
    -- red under: the library-absent mark tooltip's SetOwner(self, "ANCHOR_TOP").
    local mark = C.IconButton(M.UIParent, "info", "i", nil, "Some words")
    local savedGet = M.LibStub.GetLibrary
    M.LibStub.GetLibrary = function(self, name, silent)
        if name == "LibKa0s-Tooltip-1.0" then return nil end
        return savedGet(self, name, silent)
    end
    local ok, rec = pcall(withTip, function() mark:__fire("OnEnter") end)
    mark:__fire("OnLeave")
    M.LibStub.GetLibrary = savedGet
    if not ok then error(rec, 0) end
    assertEqual(rec.anchor, "ANCHOR_NONE", "owned at ANCHOR_NONE")
    local p = rec.points[#rec.points]
    assertTrue(p ~= nil, "a point is written")
    assertEqual(p[1] .. ">" .. p[3], "BOTTOM>TOP", "centered above the mark")
    assertTrue(p[2] == mark and p[4] == 0 and p[5] == 2, "on the mark, TIP_GAP above it")
end)

test("tooltips: the addon's own Lua names no game tooltip anchor but ANCHOR_NONE (no cursor, no corner offset)", function()
    -- red under: any ANCHOR_RIGHT / ANCHOR_TOP / ANCHOR_BOTTOM / ANCHOR_CURSOR left in the addon's code.
    local bad = {}
    for _, path in ipairs(T.loadedAddonFiles) do
        if path:match("%.lua$") then
            local fh = io.open(path, "r")
            if fh then
                local n = 0
                for line in fh:lines() do
                    n = n + 1
                    local code = line:gsub("%-%-.*$", "")
                    for anchor in code:gmatch("ANCHOR_[%u_]+") do
                        if anchor ~= "ANCHOR_NONE" then bad[#bad + 1] = ("%s:%d %s"):format(path, n, anchor) end
                    end
                end
                fh:close()
            end
        end
    end
    assertEqual(table.concat(bad, "; "), "", "no game anchor but ANCHOR_NONE")
end)
