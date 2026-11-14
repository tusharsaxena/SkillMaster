-- tests/test_round9.lua — the owner's round-9 feedback (2026-11-14) on the waypoint arrow, on
-- LibKa0s-WaypointArrow-1.0 version 2.2: the Text and Position blocks on the Waypoint arrow page
-- (R9-1), the right-click menu with Skill Master's own items (R9-2), the trainer's name as the label
-- line and the distance in Skill Master's words in both units (R9-3).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local WA, Wp, L = NS.WaypointArrow, NS.Waypoints, NS.L

--- A trainer at (50, 50) on map 1453, whose world rect is `w` x `w` yards (1000 by default), the
--- player at `player` (0..1 on 1453), the native pin API recorded and the waypoint settings at
--- their defaults with `over` laid on; then all back.
local function withArrow9(player, over, fn, w)
    local saved = { C_Map = M.C_Map, map = M.__map, UiMapPoint = M.UiMapPoint, C_SuperTrack = M.C_SuperTrack,
                    facing = M.__facing, wp = NS.db.profile.waypoints }
    local rec = { cleared = 0, superTrack = {} }
    M.__map = { player = player, worlds = { [1453] = { instance = 0, ox = 0, oy = 0, w = w or 1000, h = w or 1000 } } }
    M.C_Map = M.__newMapApi()
    M.C_Map.SetUserWaypoint = function(point) rec.point = point end
    M.C_Map.CanSetUserWaypointOnMap = function() return true end
    M.C_Map.ClearUserWaypoint = function() rec.cleared = rec.cleared + 1 end
    M.C_Map.HasUserWaypoint = function() return true end
    M.C_Map.GetUserWaypoint = function() return rec.point end
    M.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y)
        return { uiMapID = mapID, position = M.CreateVector2D(x, y) } end }
    M.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) rec.superTrack[#rec.superTrack + 1] = v end }
    M.__facing = 0
    local wp = {}
    for k, v in pairs(NS.defaults.profile.waypoints) do   -- tables copied, never shared
        wp[k] = type(v) == "table" and { unpack(v) } or v
    end
    wp.announce = false
    for k, v in pairs(over or {}) do wp[k] = v end
    NS.db.profile.waypoints = wp
    local trainer = { name = "Woo Ping", city = "Stormwind", mapID = 1453, x = 50, y = 50,
                      teaches = { "swords", "daggers" }, verified = true }
    local ok, err = pcall(fn, trainer, rec)
    WA.StandDown()
    if NS.TrainerPopup.IsShown() then NS.TrainerPopup.Hide() end
    M.C_Map, M.__map, M.UiMapPoint = saved.C_Map, saved.map, saved.UiMapPoint
    M.C_SuperTrack, M.__facing, NS.db.profile.waypoints = saved.C_SuperTrack, saved.facing, saved.wp
    WA.ApplySettings()
    if not ok then error(err, 0) end
end

local function tick() WA.Frame():__fire("OnUpdate", WA.THROTTLE + 0.001) end

local function textOf()
    for _, r in ipairs({ WA.Frame():GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then return r:GetText() end
    end
    return nil
end

local function item(id)
    for _, row in ipairs(WA.Instance():MenuItems()) do if row.id == id then return row end end
    return nil
end

-- ── R9-1: the Text and Position blocks ───────────────────────────────────────────────────────

test("round9 arrow: the Text and Position blocks sit under the look, at Skill Master's paths, on the library's defaults", function()
    local want = {
        { "waypoints.arrowFont", "font", L["Arrow text"] },
        { "waypoints.arrowFontSize", "fontSize", L["Arrow text"] },
        { "waypoints.arrowFontColor", "fontColor", L["Arrow text"] },
        { "waypoints.arrowFontClass", "useClassColorFont", L["Arrow text"] },
        { "waypoints.arrowFontFlags", "fontFlags", L["Arrow text"] },
        { "waypoints.arrowFontShadow", "fontShadow", L["Arrow text"] },
        { "waypoints.arrowFontFromSkin", "fontFromSkin", L["Arrow text"] },
        { "waypoints.arrowTextPosition", "textPosition", L["Arrow text"] },
        { "waypoints.arrowShowLabel", "showLabel", L["Arrow text"] },
        { "waypoints.arrowUnits", "distanceUnits", L["Arrow text"] },
        { "waypoints.arrowX", "x", L["Arrow position"] },
        { "waypoints.arrowY", "y", L["Arrow position"] },
        { "waypoints.arrowLock", "lock", L["Arrow position"] },
    }
    local at = {}
    for i, row in ipairs(NS.Schema) do at[row.path] = { row = row, i = i } end
    local D, PW = WA.lib.DEFAULTS, NS.defaults.profile.waypoints
    local last = at["waypoints.arrowScale"].i
    for _, w in ipairs(want) do
        local hit = at[w[1]]
        assertTrue(hit ~= nil, w[1] .. " is a schema row")
        assertEqual(hit.row.page, "trainers", w[1] .. " on the Trainers and Waypoints page")
        assertEqual(hit.row.subgroup, w[3], w[1] .. "'s subgroup")
        assertTrue(hit.i > last, w[1] .. " after the look and the rows before it")
        last = hit.i
        local leaf = w[1]:match("%.(.+)$")
        local def = D[w[2]]
        if def == nil then def = true end   -- fontFromSkin: the companion, on by default
        if type(def) == "table" then
            for k = 1, 4 do assertEqual(PW[leaf][k], def[k], w[1] .. " default") end
        else
            assertEqual(PW[leaf], def, w[1] .. " default is the library's")
        end
        assertTrue(WA.PATHS[w[2]] == w[1] or w[2] == "fontFromSkin", w[1] .. " is WA.PATHS." .. w[2])
    end
    assertEqual(NS.defaults.profile.waypoints.arrowFrame, nil, "the round-6 drag point is gone")
    local pos = at["waypoints.arrowTextPosition"].row
    assertEqual(pos.values[1].text, L["Below"], "the choices in Skill Master's words")
    assertEqual(at["waypoints.arrowLock"].row.label, L["Lock the arrow"])
end)

test("round9 arrow: the Position block's Reset position is a hook on its subgroup, handed to the page", function()
    local _, hooks = WA.SettingsRows({ page = "trainers", group = "G", subgroup = "S",
        positionSubgroup = L["Arrow position"] })
    local hook = hooks[L["Arrow position"]]
    assertEqual(type(hook), "function", "the Reset position button's hook")
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, { arrowX = 300, arrowY = -50 }, function(t)
        Wp:Set(t)
        local H, button = NS.Helpers, nil
        local realPair = H.InlineButtonPair
        H.InlineButtonPair = function(_, left) button = left end
        local ok, err = pcall(hook, {}, "G")
        H.InlineButtonPair = realPair
        if not ok then error(err, 0) end
        assertEqual(button and button.text, L["Reset position"], "the button, in Skill Master's words")
        button.onClick()
        assertEqual(NS.db.profile.waypoints.arrowX, 0, "X back to the default")
        assertEqual(NS.db.profile.waypoints.arrowY, 200, "Y back to the default")
        assertEqual(WA.Instance():Get("y"), 200, "and the arrow with them")
    end)
end)

test("round9 arrow: a drag writes the X and Y offsets through the settings seam", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        local f = WA.Frame()
        local writes, realSet = {}, NS.SetByPath
        NS.SetByPath = function(path, v, ...) writes[#writes + 1] = path return realSet(path, v, ...) end
        f.GetCenter = function() return 250, 500 end
        M.UIParent.GetCenter = function() return 200, 400 end
        local ok, err = pcall(function()
            f:__fire("OnDragStart")
            f:__fire("OnDragStop")
        end)
        NS.SetByPath, f.GetCenter, M.UIParent.GetCenter = realSet, nil, nil
        if not ok then error(err, 0) end
        assertEqual(table.concat(writes, ","), "waypoints.arrowX,waypoints.arrowY", "through NS.SetByPath")
        assertEqual(NS.db.profile.waypoints.arrowX, 50)
        assertEqual(NS.db.profile.waypoints.arrowY, 100)
        assertEqual(WA.Instance():Get("x"), 50, "the arrow reads them back")
    end)
end)

test("round9 arrow: the arrow's own Lock holds the drag; /sm lock no longer does", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        local f = WA.Frame()
        local savedLock = NS.db.profile.locked
        NS.db.profile.locked = true
        f.__userPlaced = nil
        f:__fire("OnDragStart")
        NS.db.profile.locked = savedLock
        assertTrue(f.__userPlaced == true, "/sm lock: the arrow still drags")
        f:__fire("OnDragStop")
        item("lock").onClick()
        assertEqual(NS.db.profile.waypoints.arrowLock, true, "the menu's Lock the arrow writes the setting")
        f.__userPlaced = nil
        f:__fire("OnDragStart")
        assertTrue(not f.__userPlaced, "locked: the drag never starts")
        assertEqual(item("lock").label, L["Unlock the arrow"], "the item reads Unlock while locked")
        item("lock").onClick()
        assertEqual(NS.db.profile.waypoints.arrowLock, false, "and Unlock turns it off")
    end)
end)

-- ── R9-2: the right-click menu ───────────────────────────────────────────────────────────────

test("round9 arrow: the menu is Clear first, the library's items, then Skill Master's, in the owner's order", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        local ids, labels = {}, {}
        for _, row in ipairs(WA.Instance():MenuItems()) do
            ids[#ids + 1] = row.id
            labels[#labels + 1] = row.label
        end
        assertEqual(table.concat(ids, ","), "clear,share,map,trainers,lock,reset,settings,hide")
        assertEqual(table.concat(labels, "|"), table.concat({ L["Clear waypoint"], L["Share in chat"],
            L["Show on map"], L["Show trainers"], L["Lock the arrow"], L["Reset position"],
            L["Arrow settings..."], L["Hide arrow"] }, "|"), "every word through Skill Master's locale")
        local opened = 0
        local W = NS.Widgets
        local realW = W.ContextMenu
        W.ContextMenu = function(_, rows) opened = #rows return nil end
        local ok, err = pcall(function() WA.Frame():__fire("OnMouseUp", "RightButton") end)
        W.ContextMenu = realW
        if not ok then error(err, 0) end
        assertEqual(opened, 8, "a right-click opens it")
        assertTrue(WA.IsShown(), "and clears nothing")
    end)
end)

test("round9 arrow: Clear waypoint clears the native pin, as the old right-click did", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t, rec)
        Wp:Set(t)
        item("clear").onClick()
        assertFalse(WA.IsShown(), "the arrow goes")
        assertEqual(rec.cleared, 1, "and the native pin")
    end)
end)

test("round9 arrow: Show trainers opens the trainer popup on the skill its waypoint came from", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        assertEqual(WA.TrainerKey(), "swords", "without the popup: the first skill the trainer teaches")
        local P, shown = NS.TrainerPopup, nil
        local realShow, realShown, realKey, realList = P.Show, P.IsShown, P.Key, P.Trainers
        P.IsShown, P.Key, P.Trainers = function() return true end, function() return "daggers" end,
            function() return { t } end
        Wp:Set(t)
        P.IsShown, P.Key, P.Trainers = realShown, realKey, realList
        P.Show = function(key) shown = key end
        local ok, err = pcall(function() item("trainers").onClick() end)
        P.Show = realShow
        if not ok then error(err, 0) end
        assertEqual(shown, "daggers", "the popup's own skill, kept from its Set waypoint")
        assertFalse(item("trainers").disabled == true, "enabled with a trainer")
    end)
end)

test("round9 arrow: Arrow settings opens Trainers and Waypoints; Hide arrow turns Skill Master's arrow off", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t, rec)
        Wp:Set(t)
        local H, page = NS.Helpers, nil
        local realOpen = H.OpenOptionsPanel
        H.OpenOptionsPanel = function(key) page = key end
        local ok, err = pcall(function() item("settings").onClick() end)
        H.OpenOptionsPanel = realOpen
        if not ok then error(err, 0) end
        assertEqual(page, "trainers", "the Trainers and Waypoints page")
        item("hide").onClick()
        assertEqual(NS.db.profile.waypoints.arrow, false, "Show Skill Master's arrow is off")
        assertFalse(WA.IsShown(), "the arrow goes")
        assertEqual(rec.superTrack[#rec.superTrack], true, "and the game's own arrow takes the pin")
    end)
end)

test("round9 arrow review: under test mode's sample Show trainers is off, as the library's Show on map is", function()
    -- red under: menuItems ignoring the library's target, so the sample's trainer opened the popup.
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        WA.ShowTest()
        assertTrue(WA.Target() ~= t, "the sample shows over the real waypoint")
        assertEqual(item("map").disabled, true, "the library's Show on map is off")
        assertEqual(item("trainers").disabled, true, "and so is Show trainers")
        WA.HideTest()
        assertFalse(item("trainers").disabled == true, "the real waypoint back: on again")
    end)
end)

test("round9 arrow review: Arrow settings is off in combat, with the combat tooltip", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        local realCombat = M.InCombatLockdown
        M.InCombatLockdown = function() return true end
        local ok, row = pcall(item, "settings")
        M.InCombatLockdown = realCombat
        if not ok then error(row, 0) end
        assertEqual(row.disabled, true, "off in combat")
        assertEqual(row.tooltip, L["Not available in combat."], "and says why")
        assertFalse(item("settings").disabled == true, "out of combat: on")
    end)
end)

test("round9 arrow review: a drag, the menu's Lock and Reset position refresh the open settings panel", function()
    -- red under: setSetting writing through NS.SetByPath alone, so the Position sliders kept the
    -- old values until the page was shown again.
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        local H, f = NS.Helpers, WA.Frame()
        local refreshed, realRefresh = 0, H.RefreshScalars
        H.RefreshScalars = function() refreshed = refreshed + 1 end
        f.GetCenter = function() return 250, 500 end
        M.UIParent.GetCenter = function() return 200, 400 end
        local ok, err = pcall(function()
            f:__fire("OnDragStart")
            f:__fire("OnDragStop")
            assertTrue(refreshed >= 1, "the drag refreshes the panel")
            local n = refreshed
            item("lock").onClick()
            assertTrue(refreshed > n, "the menu's Lock does")
            n = refreshed
            item("reset").onClick()
            assertTrue(refreshed > n, "and Reset position does")
        end)
        H.RefreshScalars, f.GetCenter, M.UIParent.GetCenter = realRefresh, nil, nil
        if not ok then error(err, 0) end
    end)
end)

test("round9 arrow: the tooltip says right-click opens the menu, and drops the drag hint while locked", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        local lines = {}
        local tip = M.GameTooltip
        local realAdd = tip.AddLine
        tip.AddLine = function(self, s, ...) lines[#lines + 1] = s return realAdd(self, s, ...) end
        local ok, err = pcall(function()
            WA.Frame():__fire("OnEnter")
            local unlocked = lines[#lines]
            NS.SetByPath("waypoints.arrowLock", true)
            WA.Frame():__fire("OnEnter")
            assertEqual(unlocked, L["Right-click for options. Drag to move the arrow."])
            assertEqual(lines[#lines], L["Right-click for options."], "locked: no drag hint")
        end)
        tip.AddLine = realAdd
        if not ok then error(err, 0) end
    end)
end)

-- ── R9-3: the label line and the units ───────────────────────────────────────────────────────

test("round9 arrow: Show the trainer's name adds the trainer as the second line", function()
    withArrow9({ mapID = 1453, x = 0.4, y = 0.5 }, nil, function(t)
        Wp:Set(t)
        tick()
        assertEqual(textOf(), L["%d yd"]:format(100), "off by default: the distance alone")
        NS.SetByPath("waypoints.arrowShowLabel", true)
        tick()
        assertEqual(textOf(), L["%d yd"]:format(100) .. "\n" .. "Woo Ping", "the trainer's name under it")
    end)
end)

test("round9 arrow: compact units read thousands of yards in Skill Master's words", function()
    withArrow9({ mapID = 1453, x = 0.08, y = 0.5 }, { arrowUnits = "compact" }, function(t)
        Wp:Set(t)
        tick()
        assertEqual(textOf(), L["%.1fk yd"]:format(4.2), "4200 yd reads 4.2k yd")
        NS.SetByPath("waypoints.arrowUnits", "yards")
        tick()
        assertEqual(textOf(), L["%d yd"]:format(4200), "yards: the whole number")
    end, 10000)
end)
