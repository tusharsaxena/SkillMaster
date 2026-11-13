-- tests/test_round7.lua — the owner's round-7 feedback (2026-11-13): TomTom support removed, the
-- native pin and Skill Master's own arrow always (R7-7); the icon border's row color off on a new
-- profile (R7-2); no header meta text (R7-3); the LDB tooltips' titles (R7-5); the LDB
-- panel's scroll bar always drawn (R7-4); a filter on every block (R7-1); an LDB tooltip row opening
-- from its go icon, the default, or the whole row (R7-6).
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

-- R7 review: the longer title must not draw over the gains text in the Main window style.
test("round7 titles: the panel's title never overlaps its gains text, centered while it fits", function()
    local p = NS.db.profile.tooltips.ldb
    local savedStyle, savedWidth = p.style, p.width
    p.style = "window"
    local f = NS.BrokerPanel.Frame()
    local tw, gw = 0, 0
    f.title.GetStringWidth = function() return tw end
    f.gains.GetStringWidth = function() return gw end
    local function anchors(fs)
        local out = {}
        for i = 1, #fs.__points do out[#out + 1] = fs.__points[i][1] end
        return table.concat(out, ",")
    end
    -- Width 300 (the minimum): the 235 px title and the 85 px gains cannot both fit centered.
    p.width = 300
    tw, gw = 235, 85
    NS.BrokerPanel.Fill()
    assertEqual(anchors(f.title), "TOPLEFT,RIGHT", "bound from the left edge to the gains text")
    local _, rel, relPoint = f.title:GetPoint(2)
    assertTrue(rel == f.gains and relPoint == "LEFT", "the title's right edge stops at the gains text")
    assertEqual(f.title.__justifyH, "LEFT")
    assertFalse(f.title.__wordWrap, "one line: a title too long for its room truncates")
    -- A wide panel: the title centered over the frame, as the main window's.
    p.width = 600
    NS.BrokerPanel.Fill()
    assertEqual(anchors(f.title), "TOP", "centered while it clears the gains text")
    assertEqual(f.title.__justifyH, "CENTER")
    p.style, p.width = savedStyle, savedWidth
    f.title.GetStringWidth, f.gains.GetStringWidth = nil, nil
    NS.Broker.HideTooltip()
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

-- ── R7-1: a filter on every block ────────────────────────────────────────────────────────────

local B7, W7, D7, G7 = NS.Blocks, NS.MainWindow, NS.Detached, NS.Groups

local function sk(key, name, category, rank, max, learned)
    return { key = key, name = name, category = category, rank = rank, max = max, modifier = 0,
             tempPoints = 0, learned = learned ~= false }
end

-- Tailoring at its Journeyman cap (a rank to train), Alchemy at the top rank (none), Mining below
-- its cap, Herbalism not learned; Cooking at cap with a rank, Fishing below; Defense below cap,
-- Lockpicking at its cap, Riding not learned. Each stat group: a non-zero row and its zero rows.
local function r7Models()
    local byKey = {
        tailoring = sk("tailoring", "Tailoring", "primary", 150, 150),
        alchemy   = sk("alchemy", "Alchemy", "primary", 300, 300),
        mining    = sk("mining", "Mining", "primary", 90, 150),
        herbalism = sk("herbalism", "Herbalism", "primary", 0, 0, false),
        cooking   = sk("cooking", "Cooking", "secondary", 75, 75),
        fishing   = sk("fishing", "Fishing", "secondary", 40, 75),
        swords    = sk("swords", "Swords", "weapon", 80, 110),
        defense   = sk("defense", "Defense", "other", 100, 110),
        lockpick  = sk("lockpick", "Lockpicking", "other", 50, 50),
        riding    = sk("riding", "Riding", "other", 0, 0, false),
    }
    local function st(key, value, display) return { key = key, label = key, value = value, display = display, pct = value, markers = {} } end
    local stats = {
        base    = { st("str", 54, "54"), st("rap", 0, "0") },
        spell   = { st("sdmg", 0, "0"), st("scrit", 0, "0.0%"), st("mp5", 12, "12") },
        defense = { st("armor", 0, "0 (0.0%)"), st("fire", 15, "15") },
        utility = { st("speed", 0, "0%") },
    }
    local skills = { byKey = byKey, order = {
        primary = { "tailoring", "alchemy", "mining", "herbalism" }, secondary = { "cooking", "fishing" },
        weapon = { "swords" }, other = { "defense", "lockpick", "riding" } } }
    return skills, stats
end

--- The fixture models as the window's source, NextRank answering a rank only for the skills that
--- have one (Tailoring, Cooking, Mining), then every block's filter put back to All.
local function withR7(fn)
    local skills, stats = r7Models()
    local saved = { B7.source, NS.Trainers.NextRank, NS.Widgets.ContextMenu }
    local HAS = { tailoring = true, cooking = true, mining = true }
    B7.source = function() return skills, stats end
    NS.Trainers.NextRank = function(_, key) return HAS[key] and { rankName = "Next", cap = 999 } or nil end
    local ok, err = pcall(fn, skills, stats)
    B7.source, NS.Trainers.NextRank, NS.Widgets.ContextMenu = saved[1], saved[2], saved[3]
    for _, id in ipairs(NS.BLOCKS) do
        local s = NS.db.profile.layout.blocks[id]
        s.filter, s.docked, s.collapsed = "all", true, false
    end
    NS.db.profile.layout.groups = {}
    D7.Refresh()
    W7.Hide()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function keys(list)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = r.entry.key end
    return table.concat(out, ",")
end

local function setF(id, mode)
    local ok, err = NS.SetByPath("layout.blocks." .. id .. ".filter", mode)
    assertTrue(ok, id .. " " .. mode .. ": " .. tostring(err))
end

test("round7 filters: each block's own set, a Show rows row for every block, All by default", function()
    local want = {
        primary = "all,belowCap,atCap", secondary = "all,belowCap,atCap",
        weapon = "all,learned,equipped,belowCap", other = "all,learned,belowCap",
        stats_base = "all,nonZero", stats_spell = "all,nonZero", stats_defense = "all,nonZero", stats_utility = "all,nonZero",
    }
    for _, id in ipairs(NS.BLOCKS) do
        assertEqual(table.concat(B7.FiltersOf(id), ","), want[id], id .. ": its set")
        assertEqual(NS.defaults.profile.layout.blocks[id].filter, "all", id .. ": All on a new profile")
        local row = NS.FindSchemaRow("layout.blocks." .. id .. ".filter")
        assertTrue(row ~= nil, id .. ": a Layout > Blocks Show rows row")
        assertEqual(row.default, "all")
        local values = {}
        for _, v in ipairs(row.values) do values[#values + 1] = v.value end
        assertEqual(table.concat(values, ","), want[id], id .. ": the dropdown is the menu")
        assertTrue(type(row.desc) == "string" and row.desc ~= "" and not row.desc:find("not filtered", 1, true),
            id .. ": its tooltip, which no longer says the LDB tooltip is unfiltered")
        local menu = {}
        for _, r in ipairs(B7.FilterMenuRows(id)) do if r.radio then menu[#menu + 1] = r.value end end
        assertEqual(table.concat(menu, ","), want[id], id .. ": the header menu")
    end
    assertEqual(B7.FILTER_LABEL.atCap, NS.L["At cap (needs training)"])
    assertEqual(B7.FILTER_LABEL.nonZero, NS.L["Non-zero"])
end)

test("round7 filters: Primary and Secondary narrow to below cap or at cap with a rank to train; unlearned is All only", function()
    withR7(function()
        assertEqual(keys(B7.Entries("primary")), "tailoring,alchemy,mining,herbalism", "All")
        setF("primary", "belowCap")
        local e, removed = B7.Entries("primary")
        assertEqual(keys(e), "mining", "below cap: learned and under its rank's max")
        assertEqual(removed, 3)
        setF("primary", "atCap")
        assertEqual(keys(B7.Entries("primary")), "tailoring", "at cap with a higher rank; Alchemy's top rank is out, Herbalism too")
        setF("secondary", "atCap")
        assertEqual(keys(B7.Entries("secondary")), "cooking")
        setF("secondary", "belowCap")
        assertEqual(keys(B7.Entries("secondary")), "fishing")
        assertFalse(B7:SetFilter("primary", "learned"), "a filter outside the set is refused")
        NS.db.profile.layout.blocks.primary.filter = "equipped"
        assertEqual(B7.FilterOf("primary"), "all", "a stored filter the set does not offer reads All")
    end)
end)

test("round7 filters: Other skills offers Learned and Below cap", function()
    withR7(function()
        setF("other", "learned")
        assertEqual(keys(B7.Entries("other")), "defense,lockpick")
        setF("other", "belowCap")
        assertEqual(keys(B7.Entries("other")), "defense")
        assertFalse(B7:SetFilter("other", "equipped"), "no Equipped on Other skills")
    end)
end)

test("round7 filters: a stat section's Non-zero leaves out 0 and 0% rows, an emptied one keeps its muted line", function()
    withR7(function()
        setF("stats_base", "nonZero")
        assertEqual(keys(B7.Entries("stats_base")), "str")
        setF("stats_spell", "nonZero")
        local e, removed = B7.Entries("stats_spell")
        assertEqual(keys(e), "mp5", "0 and 0.0% out")
        assertEqual(removed, 2)
        setF("stats_defense", "nonZero")
        assertEqual(keys(B7.Entries("stats_defense")), "fire", "0 (0.0%) armor out")
        setF("stats_utility", "nonZero")
        e, removed = B7.Entries("stats_utility")
        assertEqual(#e, 0)
        assertEqual(B7.FilterNote(e, removed), NS.L["No rows match this filter."], "the muted line")
    end)
end)

test("round7 filters: every window header carries the funnel, the filled badge while it narrows, and its menu", function()
    withR7(function()
        W7.Show()
        W7.Refresh(true)
        local seen = {}
        for _, h in ipairs(W7.Headers()) do
            seen[#seen + 1] = h.id
            assertTrue(h.filter:IsShown(), h.id .. ": the filter mark")
            assertEqual(h.filter.restToken, "text.heading", h.id .. ": the title's tint on All")
        end
        assertEqual(#seen, #NS.BLOCKS, "every block drew a header")
        local opened
        NS.Widgets.ContextMenu = function(anchor, rows) opened = { anchor = anchor, rows = rows } return {} end
        local h
        for _, x in ipairs(W7.Headers()) do if x.id == "stats_utility" then h = x end end
        h.filter:__fire("OnClick", "LeftButton")
        assertTrue(opened ~= nil and opened.anchor == h.filter, "the stat header's funnel opens the menu")
        for _, r in ipairs(opened.rows) do if r.value == "nonZero" then r.onClick() end end
        M.__fireTimers()
        assertEqual(NS.db.profile.layout.blocks.stats_utility.filter, "nonZero", "the pick is stored")
        for _, x in ipairs(W7.Headers()) do if x.id == "stats_utility" then h = x end end
        assertEqual(h.filter.badgeToken, "text.heading", "the filled badge while it narrows (round 8, R8-2)")
        assertTrue(h.note:IsShown() and h.note:GetText() == NS.L["No rows match this filter."], "the emptied stat block's muted line")
        assertTrue(h.filter.tip:find(NS.L["Non-zero"], 1, true) ~= nil, "the tip names it: " .. tostring(h.filter.tip))
    end)
end)

test("round7 filters: a detached stat frame and a merged section carry the mark and follow the filter", function()
    withR7(function()
        B7:Detach("stats_spell")
        M.__fireTimers()
        local f = D7.Frame("stats_spell")
        assertTrue(f.filter ~= nil and f.filter:IsShown(), "the detached band's funnel")
        setF("stats_spell", "nonZero")
        M.__fireTimers()
        assertEqual(#D7.Rows("stats_spell"), 1, "the detached rows follow")
        NS.db.profile.layout.blocks.primary.docked = false
        D7.Refresh()
        local gid = G7.Merge("primary", "stats_spell", "bottom")
        assertTrue(gid ~= nil, "merged")
        local sh = G7.Section(gid, "primary").header
        assertTrue(sh.filter:IsShown(), "the merged sub-header's funnel")
        setF("primary", "atCap")
        M.__fireTimers()
        assertEqual(G7.Section(gid, "primary").header.filter.badgeToken, "text.heading", "the filled badge (round 8, R8-2)")
    end)
end)

test("round7 filters: both LDB tooltip styles honor every block's filter", function()
    local Br, BP = NS.Broker, NS.BrokerPanel
    withR7(function(skills, stats)
        local savedSource, p = Br.source, NS.db.profile.tooltips.ldb
        local savedStyle = p.style
        Br.source = function() return { model = skills, statsModel = stats, statIndex = {}, gains = { total = 0, byKey = {} } } end
        local ok, err = pcall(function()
            setF("primary", "atCap")
            setF("stats_spell", "nonZero")
            setF("stats_utility", "nonZero")
            p.style = "window"
            Br.OnEnter(M.UIParent)
            local drawn = {}
            for _, row in ipairs(BP.Rows()) do if row.entry then drawn[row.entry.key] = true end end
            assertTrue(drawn.tailoring and not drawn.mining and not drawn.alchemy, "Main window style: Primary at cap")
            local primary
            for _, h in ipairs(BP.Headers()) do if h.id == "primary" then primary = h end end
            assertFalse(primary.filter:IsShown(), "no funnel on the panel's header (round 8, R8-4)")
            Br.OnEnter(M.UIParent, "stats")
            drawn = {}
            for _, row in ipairs(BP.Rows()) do if row.entry then drawn[row.entry.key] = true end end
            assertTrue(drawn.mp5 and not drawn.sdmg and not drawn.scrit, "Main window style: Non-zero stats")
            local util
            for _, h in ipairs(BP.Headers()) do if h.id == "stats_utility" then util = h end end
            assertTrue(util ~= nil and util.note:IsShown(), "an emptied stat section keeps its header and muted line")
            p.style = "classic"
            local lines = {}
            local tip = M.CreateFrame("GameTooltip", "SkillMasterR7FilterTip", M.UIParent)
            function tip:AddLine(t) lines[#lines + 1] = t end
            function tip:AddDoubleLine(l) lines[#lines + 1] = l end
            function tip:NumLines() return #lines end
            Br.FillTooltip(tip, "skills")
            local text = table.concat(lines, "\n")
            assertTrue(text:find("Tailoring", 1, true) and not text:find("Mining", 1, true), "Classic: Primary at cap: " .. text)
            lines = {}
            Br.FillTooltip(tip, "stats")
            text = table.concat(lines, "\n")
            assertTrue(text:find("mp5", 1, true) and not text:find("sdmg", 1, true), "Classic: Non-zero stats: " .. text)
            assertTrue(text:find(NS.L["No rows match this filter."], 1, true) ~= nil, "Classic: an emptied stat section's muted line")
        end)
        Br.HideTooltip()
        Br.source, p.style = savedSource, savedStyle
        Br.FillTooltip(M.CreateFrame("GameTooltip", "SkillMasterR7FeedReset", M.UIParent), "skills")   -- the skills feed again
        if not ok then error(err, 0) end
    end)
end)

-- ── R7-6: an LDB tooltip row opens from its go icon (the default) or the whole row ──────────
-- Engineering is the crafting row: no other suite arms it, so its overlay (made once, never
-- destroyed) is this file's alone.

local Br6, BP6, SO6, I6 = NS.Broker, NS.BrokerPanel, NS.SecureOverlay, NS.Interact

local function r6Source()
    local byKey = {
        engineering = sk("engineering", "Engineering", "primary", 120, 150),
        cooking   = sk("cooking", "Cooking", "secondary", 60, 75),
        swords    = sk("swords", "Swords", "weapon", 80, 110),
    }
    local model = { byKey = byKey, order = { primary = { "engineering" }, secondary = { "cooking" },
                    weapon = { "swords" }, other = {} } }
    return { model = model, statsModel = { base = {}, spell = {}, defense = {}, utility = {} },
             statIndex = {}, gains = { total = 0, byKey = {} } }
end

--- The Main window style over a fixture source, `openFrom` set, out of combat, Shift up; every
--- swapped global and setting put back, the panel hidden (its OnHide fired: the fake's Hide fires
--- none) and the overlays synced.
local function withGo(openFrom, fn)
    local p = NS.db.profile.tooltips.ldb
    local saved = { source = Br6.source, style = p.style, from = p.openFrom, combat = M.InCombatLockdown,
                    shift = M.IsShiftKeyDown, open = Br6.OpenRow }
    local v = r6Source()
    Br6.source = function() return v end
    p.style, p.openFrom = "window", openFrom
    M.InCombatLockdown = function() return false end
    M.IsShiftKeyDown = function() return false end
    local ok, err = pcall(fn, v)
    Br6.OpenRow = saved.open
    local f = BP6.Frame()
    Br6.HideTooltip()
    f:__fire("OnHide")
    Br6.source, p.style, p.openFrom = saved.source, saved.style, saved.from
    M.InCombatLockdown, M.IsShiftKeyDown = saved.combat, saved.shift
    SO6:Sync()
    if NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end
    if not ok then error(err, 0) end
end

local function goRow(key)
    for _, row in ipairs(BP6.Rows()) do if row.entry and row.entry.key == key then return row end end
end

local function recordOpenRow()
    local got = {}
    Br6.OpenRow = function(r, button) got[#got + 1] = r.kind .. ":" .. r.key .. ":" .. tostring(button) end
    return got
end

test("round7 go icon: Open a row from defaults to The go icon, Main window style only", function()
    assertEqual(NS.defaults.profile.tooltips.ldb.openFrom, "icon", "every profile starts on the go icon")
    local row = NS.FindSchemaRow("tooltips.ldb.openFrom")
    assertTrue(row ~= nil, "the Tooltips > LDB tooltip row")
    assertEqual(row.page, "tooltips")
    assertEqual(row.default, "icon")
    local values = {}
    for _, val in ipairs(row.values) do values[#values + 1] = val.value end
    assertEqual(table.concat(values, ","), "icon,row")
    local p = NS.db.profile.tooltips.ldb
    local style = p.style
    p.style = "classic"
    assertTrue(row.disabledIf() == true, "dimmed in the Classic style")
    assertEqual(Br6.OpenFrom(), "row", "Classic rows always open from the whole row")
    p.style = "window"
    assertFalse(row.disabledIf() == true)
    assertEqual(Br6.OpenFrom(), "icon")
    p.style = style
end)

test("round7 go icon: the row's left click opens nothing; shift-click and right-click stay on the row", function()
    withGo("icon", function()
        Br6.OnEnter(M.UIParent)
        local got = recordOpenRow()
        local row = goRow("cooking")
        row:__fire("OnClick", "LeftButton")
        assertEqual(#got, 0, "a plain left click on the row opens nothing")
        row:__fire("OnClick", "RightButton")
        M.IsShiftKeyDown = function() return true end
        row:__fire("OnClick", "LeftButton")
        assertEqual(table.concat(got, ","), "skill:cooking:RightButton,skill:cooking:LeftButton", "the menu, then the link")
        assertEqual(BP6.Frame().footer:GetText(), Br6.FooterText("icon"), "the footer says the go icon opens")
        assertTrue(Br6.FooterText("icon"):find("go icon", 1, true) ~= nil)
    end)
end)

test("round7 go icon: the whole row mode opens from the row, the icon a glyph, no overlay", function()
    withGo("row", function()
        local enabled = {}
        Br6.OnEnter(M.UIParent)
        local row = goRow("engineering")
        rawset(row.act, "EnableMouse", function(_, on) enabled[#enabled + 1] = on end)
        Br6.OnEnter(M.UIParent)
        rawset(row.act, "EnableMouse", nil)
        assertEqual(enabled[#enabled], false, "the icon takes no mouse")
        local got = recordOpenRow()
        row = goRow("engineering")
        row:__fire("OnClick", "LeftButton")
        assertEqual(table.concat(got, ","), "skill:engineering:LeftButton", "the whole row opens")
        assertFalse(BP6.Armed(), "no overlay is laid over these rows")
        row:__fire("OnEnter")
        local b = SO6.Overlay("engineering")
        assertTrue(b == nil or b.row ~= row or not b:IsShown(), "a hover arms nothing")
        assertEqual(BP6.Frame().footer:GetText(), Br6.FooterText("row"))
    end)
end)

test("round7 go icon: a hovered crafting row's icon gets the window's secure cast; the panel's hide disarms it", function()
    withGo("icon", function()
        local enabled = {}
        Br6.OnEnter(M.UIParent)
        local row = goRow("engineering")
        rawset(row.act, "EnableMouse", function(_, on) enabled[#enabled + 1] = on end)
        Br6.OnEnter(M.UIParent)
        rawset(row.act, "EnableMouse", nil)
        assertEqual(enabled[#enabled], true, "the go icon takes the mouse")
        row = goRow("engineering")
        assertTrue(BP6.Armed(), "the panel shows in the go icon mode")
        row:__fire("OnEnter")
        local b = SO6.Overlay("engineering")
        assertTrue(b ~= nil and b:IsShown(), "armed on the hover")
        assertTrue(b.row == row, "over the panel's row")
        assertEqual(b.kind, "spell", "the crafting cast (type1 spell)")
        assertEqual(b:GetFrameStrata(), "TOOLTIP", "the panel's strata, the top")
        assertTrue(b:GetFrameLevel() > row:GetFrameLevel(), "above the row")
        -- The overlay's right-click is the panel row's (its row menu over the tooltip).
        local got = recordOpenRow()
        b:GetScript("PostClick")(b, "RightButton", false)
        assertEqual(table.concat(got, ","), "skill:engineering:RightButton", "the panel row's own menu")
        -- A scroll re-lays it; the panel's hide takes it down.
        local syncs, real = 0, SO6.Sync
        SO6.Sync = function(...) syncs = syncs + 1 return real(...) end
        BP6.SetScroll(0)
        SO6.Sync = real
        assertTrue(syncs > 0, "a scroll re-syncs the overlay")
        local f = BP6.Frame()
        f:Hide()
        f:__fire("OnHide")
        assertFalse(b:IsShown(), "never armed after the panel hides")
        assertTrue(b.row == nil)
    end)
end)

test("round7 go icon: in combat a hover arms nothing and the icon's click says why, as the window's", function()
    withGo("icon", function()
        Br6.OnEnter(M.UIParent)
        M.__fireEvent("PLAYER_REGEN_DISABLED")
        M.InCombatLockdown = function() return true end
        local row = goRow("engineering")
        local b = SO6.Overlay("engineering")
        local moves = 0
        if b then
            for _, name in ipairs({ "SetPoint", "Show", "SetFrameLevel" }) do
                local realFn = b[name]
                rawset(b, name, function(...) moves = moves + 1 return realFn(...) end)
            end
        end
        row:__fire("OnEnter")
        assertEqual(moves, 0, "nothing moves or shows an overlay in combat")
        assertTrue(b == nil or not b:IsShown(), "disarmed")
        M.__resetPrinted()
        row.act:__fire("OnClick", "LeftButton")
        assertEqual(#M.__printed(), 1, "one line says why it cannot open in combat")
        if b then for _, name in ipairs({ "SetPoint", "Show", "SetFrameLevel" }) do rawset(b, name, nil) end end
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        b = SO6.Overlay("engineering")
        assertTrue(b ~= nil and b:IsShown() and b.row == row, "armed again after combat, the row still hovered")
    end)
end)

test("round7 go icon: a tooltip row's shift-click links it into chat", function()
    withGo("row", function()
        Br6.OnEnter(M.UIParent)
        local linked, real = {}, I6.Link
        I6.Link = function(r) linked[#linked + 1] = r.kind .. ":" .. r.entry.key end
        M.IsShiftKeyDown = function() return true end
        local ok, err = pcall(Br6.OpenRow, { kind = "skill", key = "swords" }, "LeftButton")
        I6.Link = real
        if not ok then error(err, 0) end
        assertEqual(table.concat(linked, ","), "skill:swords", "linked, not opened")
    end)
end)
