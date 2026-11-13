-- tests/test_options.lua — the settings pages (plan Task 5.1, design §6.6, mockup "Options"): every
-- page in order, a row for every display setting, the live apply, the Bars page's preview bar, the
-- un-hide rows, the per-block rows through NS.Blocks and the library-absent row counts.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNear = T.assertNear
local loadDegraded = dofile("tests/degraded_env.lua")

local function rowFor(path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
    return nil
end

-- A leaf is a value, or a color (an array of numbers): what one control sets.
local function isLeaf(v)
    return type(v) ~= "table" or type(v[1]) == "number"
end

local function eachLeaf(t, prefix, fn)
    for k, v in pairs(t) do
        local path = prefix .. k
        if isLeaf(v) then fn(path, v) else eachLeaf(v, path .. ".", fn) end
    end
end

-- Named non-setting state (docs/ARCHITECTURE.md): geometry only a drag writes, never a row (the
-- detached frames' and the Journal's drop point, and the Journal's size from its resize grip).
local NOT_SETTINGS = { point = true, size = true }

local function leafName(path) return path:match("([^%.]+)$") end

test("test_options_every_bar_style_key_has_row", function()
    -- red under: a bars.* or layout.* default with no row on any page (a look nobody can change).
    local missing = {}
    for _, root in ipairs({ "bars", "layout" }) do
        eachLeaf(NS.defaults.profile[root], root .. ".", function(path)
            if not NOT_SETTINGS[leafName(path)] and not rowFor(path) then missing[#missing + 1] = path end
        end)
    end
    table.sort(missing)
    assertEqual(#missing, 0, "no row for: " .. table.concat(missing, ", "))
end)

test("options: every display default outside bars and layout has a row too", function()
    local missing = {}
    for _, root in ipairs({ "skills", "stats", "alerts", "broker", "journal", "waypoints", "trainers" }) do
        eachLeaf(NS.defaults.profile[root], root .. ".", function(path)
            if not NOT_SETTINGS[leafName(path)] and not rowFor(path) then missing[#missing + 1] = path end
        end)
    end
    table.sort(missing)
    assertEqual(#missing, 0, "no row for: " .. table.concat(missing, ", "))
end)

test("options: the pages register in the mockup's order, General first and Profiles last", function()
    local want = { "General", "Layout", "Bars", "Skills", "Rows", "Broker", "Alerts", "Journal",
                   "Trainers and Waypoints" }
    for _, name in ipairs(want) do
        assertTrue(M.__subcategories[name] ~= nil, name .. " registered a subcategory")
    end
    local keys = {}
    for _, row in ipairs(NS.Schema) do keys[row.page] = true end
    for _, page in ipairs({ "general", "layout", "bars", "skills", "rows", "broker", "alerts", "journal",
                            "trainers" }) do
        assertTrue(keys[page], page .. " declares rows")
    end
end)

test("options: a look row applies live through LAYOUT_CHANGED and reaches the window's bars", function()
    local seen = 0
    local target = NS.NewBusTarget()
    target:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() seen = seen + 1 end)
    NS.SetByPath("bars.height", 18)
    target:UnregisterMessage(NS.MSG.LAYOUT_CHANGED)
    assertEqual(seen, 1, "one LAYOUT_CHANGED per write")
    assertEqual(NS.Bar.ResolveStyle("row").height, 18)
    NS.SetByPath("bars.height", NS.defaults.profile.bars.height)
end)

test("options: a reset of a whole page sends one LAYOUT_CHANGED, not one per row", function()
    local seen = 0
    local target = NS.NewBusTarget()
    target:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() seen = seen + 1 end)
    NS.SetByPath("bars.height", 20)
    seen = 0
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
    target:UnregisterMessage(NS.MSG.LAYOUT_CHANGED)
    assertEqual(seen, 1, "the bulk reset coalesces")
    assertEqual(NS.GetSetting("bars.height"), NS.defaults.profile.bars.height)
end)

test("options: a hidden skill has a row that un-hides it", function()
    NS.db.profile.skills.hidden.bows = true
    assertTrue(NS.GetSetting("skills.hidden.bows") == true, "the row reads the row menu's hide")
    NS.SetByPath("skills.hidden.bows", false)
    assertTrue(NS.db.profile.skills.hidden.bows == nil, "un-hiding clears the entry")
    NS.db.profile.stats.hidden.agility = true
    NS.SetByPath("stats.hidden.agility", false)
    assertTrue(NS.db.profile.stats.hidden.agility == nil, "and a stat's")
    assertTrue(rowFor("skills.hidden.leatherworking") ~= nil, "every catalog skill has one")
    assertTrue(rowFor("stats.hidden.durability") ~= nil, "every stat has one")
end)

test("options: the per-block rows go through NS.Blocks (detach, dock, collapse, order)", function()
    local B = NS.Blocks
    local s = B.Settings("weapon")
    NS.SetByPath("layout.blocks.weapon.docked", false)
    assertFalse(s.docked, "the row detached the block")
    NS.SetByPath("layout.blocks.weapon.docked", true)
    assertTrue(s.docked, "and docked it again")
    NS.SetByPath("layout.blocks.weapon.collapsed", true)
    assertTrue(s.collapsed)
    NS.SetByPath("layout.blocks.weapon.collapsed", false)
    B:Move(3, 1)
    assertEqual(B.Docked()[1], "weapon", "a move renumbers the order")
    assertEqual(NS.GetSetting("layout.blocks.weapon.order"), 1)
    NS.Helpers.RestoreDefaults("layout")
    M.__fireTimers()
    assertEqual(B.Docked()[1], "primary", "the page's Defaults restores the order")
    assertEqual(B.Docked()[3], "weapon")
end)

test("options: a hidden block leaves the window and the detached frames", function()
    NS.SetByPath("layout.blocks.other.shown", false)
    for _, id in ipairs(NS.Blocks.Docked()) do assertTrue(id ~= "other", "not docked") end
    for _, id in ipairs(NS.Blocks.Undocked()) do assertTrue(id ~= "other", "not detached") end
    NS.SetByPath("layout.blocks.other.shown", true)
end)

test("options: the waypoint method preference decides the provider", function()
    local Wp = NS.Waypoints
    local t = { name = "Woo Ping", city = "Stormwind", mapID = 1453, x = 57.1, y = 57.7 }
    local savedTomTom = rawget(_G, "TomTom")
    rawset(_G, "TomTom", { AddWaypoint = function() end })
    assertEqual(Wp:Method(t), "tomtom", "auto prefers TomTom")
    NS.SetByPath("waypoints.method", "chat")
    assertEqual(Wp:Method(t), "chat", "chat only")
    NS.SetByPath("waypoints.method", "auto")
    rawset(_G, "TomTom", savedTomTom)
end)

test("options: the unverified mark follows its row", function()
    local Wp = NS.Waypoints
    local t = { name = "Woo Ping", city = "Stormwind", verified = false }
    assertTrue(Wp:Directions(t):find("unverified", 1, true) ~= nil)
    NS.SetByPath("trainers.unverified", false)
    assertTrue(Wp:Directions(t):find("unverified", 1, true) == nil)
    NS.SetByPath("trainers.unverified", true)
end)

test("options: the bar text template and the timer and marker switches reach the bar", function()
    local bar = NS.Bar.Create(M.UIParent, "row")
    bar:SetValues{ value = 107, max = 150, bonus = 25, bonusKind = "temp" }
    assertEqual(bar.text:GetText(), "107 +25 / 150", "the default template draws the old text")
    NS.SetByPath("bars.textTemplate", "{pct}% ({left} left)")
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    bar:SetValues{ value = 75, max = 150 }
    assertEqual(bar.text:GetText(), "50% (75 left)")
    NS.SetByPath("bars.textTemplate", NS.defaults.profile.bars.textTemplate)
    NS.SetByPath("bars.timer", false)
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    bar:SetTimer(M.GetTime() + 60)
    assertFalse(bar.timer:IsShown(), "no timer while the switch is off")
    NS.SetByPath("bars.timer", true)
    NS.SetByPath("bars.markersWindow", true)
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    bar:SetValues{ value = 50, max = 100, markers = { { at = 9, label = "cap" } } }
    assertEqual(#bar.geom.markers, 1, "a marker while the window switch is on")
    NS.SetByPath("bars.markersWindow", false)
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    bar:SetValues{ value = 50, max = 100, markers = { { at = 9, label = "cap" } } }
    assertEqual(#bar.geom.markers, 0, "no markers while the switch is off")
end)

test("options: the flat color mode draws the Bar color, or the skin's while its companion is on", function()
    NS.SetByPath("bars.colorMode", "flat")
    NS.SetByPath("bars.barColorFromSkin", false)
    NS.SetByPath("bars.barColor", { 0.1, 0.2, 0.3, 1 })
    local c = NS.Rows.FillColor({ key = "bows", rank = 10, max = 100, category = "weapon" })
    assertNear(c[1], 0.1, 1e-9, "the player's flat color")
    NS.SetByPath("bars.barColorFromSkin", true)
    c = NS.Rows.FillColor({ key = "bows", rank = 10, max = 100, category = "weapon" })
    assertEqual(c, NS.Bar.Color("sm.barFill"), "the skin's fill")
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
end)

test("options: the Bars page has no preview bar (owner feedback round 4)", function()
    -- red under: the pinned Fishing 107 +25 / 150 preview above the page's strip
    local panel = M.__subcategories["Bars"]
    assertTrue(panel ~= nil, "Bars registered")
    panel:Show()
    panel:__fire("OnShow")
    assertTrue(NS.OptionsPreview == nil, "no preview module")
    local page
    for _, pg in ipairs(NS.SchemaPages or {}) do if pg.key == "bars" or pg.id == "bars" then page = pg end end
    assertTrue(page == nil or page.header == nil, "no pinned header on the page")
    panel:Hide()
    panel:__fire("OnHide")
    M.__fireTimers()
end)

test("options: every new page renders on its first show without raising", function()
    for _, name in ipairs({ "Layout", "Skills", "Rows", "Broker", "Alerts", "Journal", "Trainers and Waypoints" }) do
        local panel = M.__subcategories[name]
        local ok, err = pcall(function()
            panel:Show()
            panel:__fire("OnShow")
        end)
        assertTrue(ok, name .. ": " .. tostring(err))
        panel:Hide()
        panel:__fire("OnHide")
    end
    M.__fireTimers()   -- the library's deferred repaints, so no timer outlives the case
end)

test("options: the journal's length is honored", function()
    NS.SetByPath("journal.keep", 50)
    assertEqual(NS.SessionLog.Cap(), 50)
    NS.SetByPath("journal.keep", 500)
end)

test("options: the library-absent load keeps every hand-written row; the composers' rows are the gap", function()
    -- options-ui-§1: pin the full count, the degraded count and the delta, attributed to the
    -- composers (Master controls, the Bars page's bar, background, border and font blocks, the
    -- Trainers page's name color pair, and Layout > Detached windows' background pair and border block).
    local NS2 = loadDegraded()
    local full, degraded = #NS.Schema, #NS2.Schema
    -- Round 5 (R5-7): Layout > Detached windows, three hand-written rows (scale, opacity, title band)
    -- and nine composed (the background pair and its skin companion, the border block and its).
    -- Round 5 (R5-10): the weapon block's Show rows filter, one hand-written row in both counts.
    -- Round 5 (R5-11..R5-13): the Rows page took every Hide row and the four whole-set rows over from
    -- the Skills, Stats and Broker pages one for one, same paths: neither count moves (delta 0).
    -- Round 6 (R6-4): Bars > Marks' Threshold markers split into a window and a row-tooltip switch,
    -- hand-written: +1 in both counts, the delta unmoved.
    -- Round 6 (R6-10): Tooltips > LDB tooltip's Tooltip style, Width and Height, hand-written: +3 in
    -- both counts, the delta unmoved.
    -- Round 6 (R6-9): the Broker page's Stats section switch gave way to the stats feed's four stat
    -- block switches, hand-written: -1 +4 = +3 in both counts, the delta unmoved.
    assertEqual(full, 337, "the full schema (round 6: the stats feed's four section switches)")
    assertEqual(degraded, 284, "the library-absent schema")
    assertEqual(full - degraded, 53, "Master controls (8, Sim mode among them), the Bars blocks (25), the icon border block (8), the trainer name color (3) and the detached background and border (9)")
end)
