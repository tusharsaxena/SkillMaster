-- tests/test_round7.lua — the owner's round-7 feedback (2026-11-13): TomTom support removed, the
-- native pin and Skill Master's own arrow always (R7-7); the icon border's row color off on a new
-- profile (R7-2); no header meta text (R7-3); the LDB tooltips' titles (R7-5); the LDB
-- panel's scroll bar always drawn (R7-4).
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

-- ── R7-2: the icon border's row color, off on a new profile ──────────────────────────────────

test("round7 icon border: Use the row's color is off on a new profile, so the skin's icon border draws", function()
    assertEqual(NS.defaults.profile.icons.borderColorFromRow, false, "the default is off")
    assertEqual(NS.FindSchemaRow("icons.borderColorFromRow").default, false, "the row's default too")
    local saved = NS.db.profile.icons
    NS.db.profile.icons = setmetatable({}, { __index = NS.defaults.profile.icons })
    local rowColor = { 0.1, 0.9, 0.1, 1 }
    local st = NS.Rows.IconStyle(rowColor, 20)
    NS.db.profile.icons = saved
    assertTrue(st.border ~= rowColor, "not the row's color on a new profile")
    local r, g, b = NS.Skin.Color("icon.border")
    if r then
        assertTrue(math.abs(st.border[1] - r) < 1e-6 and math.abs(st.border[2] - g) < 1e-6
            and math.abs(st.border[3] - b) < 1e-6, "the skin's icon border")
    end
end)

test("round7 icon border: schemaVersion 12 keeps the row's color on every profile stored before", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R7-Old"] = { bars = { height = 15 } }
    sv.profiles["R7-Off"] = { icons = { borderColorFromRow = false } }
    sv.profiles["R7-Empty"] = {}
    NS.db.global.schemaVersion = 11
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 12, "step 12 is in the ladder")
    assertEqual(sv.profiles["R7-Old"].icons.borderColorFromRow, true, "an existing profile keeps the old default")
    assertEqual(sv.profiles["R7-Off"].icons.borderColorFromRow, false, "a stored choice stays")
    assertEqual(sv.profiles["R7-Empty"].icons.borderColorFromRow, true, "an empty stored profile is an existing one")
    -- A fresh install: no stamp was ever stored, so its profiles start on the new default.
    sv.profiles["R7-New"] = { bars = { height = 15 } }
    NS.db.global.schemaVersion = 0
    NS:RunMigrations()
    assertTrue(sv.profiles["R7-New"].icons == nil, "a fresh install starts with the row's color off")
    for _, k in ipairs({ "R7-Old", "R7-Off", "R7-Empty", "R7-New" }) do sv.profiles[k] = nil end
end)

-- ── R7-3: no header meta ─────────────────────────────────────────────────────────────────────

test("round7 header meta: no block header carries a line beside its title, Base & Combat included", function()
    assertTrue(NS.Blocks.Meta == nil, "no meta seam left")
    assertTrue(rawget(NS.L, "vs highest primary") == nil, "the dead locale key went")
    local pool = NS.Blocks.NewHeaderPool()
    local h = NS.Blocks.AcquireHeader(pool, M.UIParent)
    h:SetBlock("stats_base", false, true)
    assertTrue(h.meta == nil, "no meta font string on the header")
    assertEqual(h.title:GetText(), NS.BlockDefs.stats_base.title, "the title alone")
    h:SetBlock("weapon", true, false)
    assertTrue(h.collapsed and not h.docked, "SetBlock(id, collapsed, docked)")
    NS.Blocks.ReleaseHeaders(pool)
end)

-- ── R7-5: the LDB tooltips' titles ───────────────────────────────────────────────────────────

test("round7 titles: the two feeds' tooltips read Skill Master · Professions and Skills and Skill Master · Stats", function()
    local Br = NS.Broker
    local SKILLS, STATS = "Skill Master \194\183 Professions and Skills", "Skill Master \194\183 Stats"
    assertEqual(Br.FEEDS.skills.title, SKILLS)
    assertEqual(Br.FEEDS.stats.title, STATS)
    -- Both styles read B.Heading: the Main window style's panel title and the Classic tooltip's first line.
    local lines = {}
    local tip = M.CreateFrame("GameTooltip", "SkillMasterR7TitleTip", M.UIParent)
    function tip:AddLine(s) lines[#lines + 1] = s end
    function tip:AddDoubleLine(l, r) lines[#lines + 1] = l .. " " .. tostring(r) end
    function tip:NumLines() return #lines end
    Br.FillTooltip(tip, "skills")
    assertTrue(lines[1]:find(SKILLS, 1, true) ~= nil, "Classic skills title: " .. tostring(lines[1]))
    assertEqual((Br.Heading()), SKILLS, "the panel's title")
    lines = {}
    Br.FillTooltip(tip, "stats")
    assertTrue(lines[1]:find(STATS, 1, true) ~= nil, "Classic stats title: " .. tostring(lines[1]))
    assertEqual((Br.Heading()), STATS)
    Br.FillTooltip(tip, "skills")
    -- The LibDataBroker names and labels a display stores by are unchanged.
    assertEqual(Br.NAME, "Skill Master")
    assertEqual(Br.STATS_NAME, "Skill Master Stats")
    assertEqual(Br.Object().label, "Skill Master")
    assertEqual(Br.StatsObject().label, "Skill Master Stats")
end)

-- ── R7-4: the LDB panel's scroll bar is always drawn ─────────────────────────────────────────

local function sameRGB(got, r, g, b)
    return got ~= nil and math.abs(got[1] - r) < 1e-6 and math.abs(got[2] - g) < 1e-6 and math.abs(got[3] - b) < 1e-6
end

test("round7 scroll bar: an always-shown bar is drawn disabled while nothing scrolls, enabled once it does", function()
    local bar = NS.Journal.MakeScrollBar(M.UIParent, function() end, { alwaysShown = true })
    M.__paintFrame(bar)
    bar:__setGeom(16, 300)
    bar:Sync(0, 0)
    assertTrue(bar:IsShown(), "nothing scrolls: still drawn, so the gutter is never empty")
    assertFalse(bar:IsEnabled(), "and disabled")
    assertEqual(select(2, bar.thumb:GetSize()), 300, "the thumb spans the whole corridor")
    local off = { NS.Skin.Color("scroll.thumbOff") }
    assertTrue(sameRGB(M.__paint(bar.thumb).color, off[1], off[2], off[3]), "in the skin's disabled thumb tint")
    bar:Sync(120, 10)
    assertTrue(bar:IsShown() and bar:IsEnabled(), "it scrolls: enabled")
    assertEqual(select(2, bar.thumb:GetSize()), 36, "the thumb back to its size")
    local on = { NS.Skin.Color("scroll.thumb") }
    assertTrue(sameRGB(M.__paint(bar.thumb).color, on[1], on[2], on[3]), "in the skin's thumb color")
    -- The Journal's and the trainer popup's bars keep hiding while nothing scrolls.
    local plain = NS.Journal.MakeScrollBar(M.UIParent, function() end)
    plain:Sync(0, 0)
    assertFalse(plain:IsShown(), "a plain bar hides")
end)

test("round7 scroll bar: the LDB panel builds its bar always shown", function()
    local p = NS.db.profile.tooltips.ldb
    local savedStyle = p.style
    p.style = "window"
    NS.BrokerPanel.Fill()
    local f = NS.BrokerPanel.Frame()
    p.style = savedStyle
    assertTrue(f.scrollBar ~= nil and f.scrollBar.alwaysShown == true, "the panel's bar is always shown")
    assertTrue(f.scrollBar:IsShown(), "drawn after a fill")
    if select(2, NS.BrokerPanel.Scroll()) == 0 then
        assertFalse(f.scrollBar:IsEnabled(), "disabled while the body fits")
    end
    NS.Broker.HideTooltip()
end)
