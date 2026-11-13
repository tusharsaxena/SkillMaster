-- tests/test_round7.lua — the owner's round-7 feedback (2026-11-13): TomTom support removed, the
-- native pin and Skill Master's own arrow always (R7-7).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ── R7-7: no TomTom ──────────────────────────────────────────────────────────────────────────

local WA, Wp = NS.WaypointArrow, NS.Waypoints

--- The native pin API recorded, a TomTom-shaped global (another addon answering TomTom's API, as
--- in the owner's game), the arrow on; then all back.
local function withTomTomShaped(fn)
    local saved = { C_Map = M.C_Map, UiMapPoint = M.UiMapPoint, C_SuperTrack = M.C_SuperTrack,
                    TomTom = rawget(_G, "TomTom"), map = M.__map, wp = NS.db.profile.waypoints }
    local rec = { set = 0, superTrack = {}, tomtom = 0 }
    rawset(_G, "TomTom", { AddWaypoint = function() rec.tomtom = rec.tomtom + 1 return {} end })
    M.__map = { player = { mapID = 1453, x = 0.4, y = 0.5 },
                worlds = { [1453] = { instance = 0, ox = 0, oy = 0, w = 1000, h = 1000 } } }
    M.C_Map = M.__newMapApi()
    M.C_Map.SetUserWaypoint = function(point) rec.set = rec.set + 1 rec.point = point end
    M.C_Map.CanSetUserWaypointOnMap = function() return true end
    M.C_Map.ClearUserWaypoint = function() end
    M.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y)
        return { uiMapID = mapID, position = M.CreateVector2D(x, y) } end }
    M.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) rec.superTrack[#rec.superTrack + 1] = v end }
    NS.db.profile.waypoints = { method = "auto", announce = false, arrow = true, arrowScale = 1,
                                arrowFrame = { point = false } }
    local trainer = { name = "Woo Ping", faction = "Alliance", city = "Stormwind", mapID = 1453,
                      x = 50, y = 50, teaches = { "swords" }, verified = true }
    local ok, err = pcall(fn, trainer, rec)
    WA.StandDown()
    M.C_Map, M.UiMapPoint, M.C_SuperTrack, M.__map = saved.C_Map, saved.UiMapPoint, saved.C_SuperTrack, saved.map
    rawset(_G, "TomTom", saved.TomTom)
    NS.db.profile.waypoints = saved.wp
    if not ok then error(err, 0) end
end

test("round7 no TomTom: a TomTom-shaped global is ignored; the native pin and Skill Master's arrow always", function()
    withTomTomShaped(function(t, rec)
        assertEqual(Wp:Method(t), "native", "the map pin, never TomTom")
        assertEqual(Wp:Set(t), "native")
        assertEqual(rec.tomtom, 0, "TomTom's AddWaypoint is never called")
        assertEqual(rec.set, 1, "the native pin is set")
        assertEqual(rec.superTrack[#rec.superTrack], false, "not super-tracked while our arrow points")
        assertTrue(WA.Wanted(), "the arrow is wanted whatever TomTom-shaped global exists")
        assertTrue(WA.IsShown(), "Skill Master's arrow shows")
    end)
end)

test("round7 no TomTom: the arrow off super-tracks the pin (the client's arrow)", function()
    withTomTomShaped(function(t, rec)
        NS.db.profile.waypoints.arrow = false
        assertEqual(Wp:Set(t), "native")
        assertEqual(rec.superTrack[#rec.superTrack], true, "super-tracked")
        assertFalse(WA.IsShown(), "no arrow of ours")
    end)
end)

test("round7 no TomTom: /sm test shows the sample arrow while the arrow setting is on", function()
    withTomTomShaped(function()
        WA.ShowTest()
        assertTrue(WA.IsShown(), "test mode's sample arrow shows")
        assertTrue(WA.Target() ~= nil, "on a sample trainer")
        WA.HideTest()
        assertFalse(WA.IsShown())
        NS.db.profile.waypoints.arrow = false
        WA.ShowTest()
        assertFalse(WA.IsShown(), "the arrow off: no sample")
    end)
end)

test("round7 no TomTom: Waypoint method offers the map pin and chat only, no TomTom label", function()
    local row = NS.FindSchemaRow("waypoints.method")
    assertTrue(row ~= nil, "the row")
    local values = {}
    for _, v in ipairs(row.values) do
        values[#values + 1] = v.value
        assertTrue(not tostring(v.text):find("TomTom", 1, true), "no TomTom label: " .. tostring(v.text))
    end
    assertEqual(table.concat(values, ","), "auto,chat")
    assertTrue(not row.desc:find("TomTom", 1, true), "the tooltip names no TomTom")
    assertEqual(NS.defaults.profile.waypoints.method, "auto", "the default is unchanged")
end)

test("round7 no TomTom: schemaVersion 11 folds a stored tomtom or native method into auto", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R7-TomTom"] = { waypoints = { method = "tomtom", announce = false } }
    sv.profiles["R7-Native"] = { waypoints = { method = "native" } }
    sv.profiles["R7-Chat"] = { waypoints = { method = "chat" } }
    sv.profiles["R7-None"] = { bars = { height = 15 } }
    NS.db.global.schemaVersion = 10
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 11, "step 11 is in the ladder")
    assertEqual(sv.profiles["R7-TomTom"].waypoints.method, nil, "tomtom: the default auto answers")
    assertEqual(sv.profiles["R7-TomTom"].waypoints.announce, false, "the rest is kept")
    assertEqual(sv.profiles["R7-Native"].waypoints.method, nil, "native: the default auto answers")
    assertEqual(sv.profiles["R7-Chat"].waypoints.method, "chat", "Chat only is a choice and stays")
    assertTrue(sv.profiles["R7-None"].waypoints == nil, "a profile without one passes through")
    for _, k in ipairs({ "R7-TomTom", "R7-Native", "R7-Chat", "R7-None" }) do sv.profiles[k] = nil end
end)
