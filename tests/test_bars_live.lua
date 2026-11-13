-- tests/test_bars_live.lua — every Bars page row reaches the bars on screen (feedback round 1, FB-1).
-- The owner reported from WoW Forever that the Size, Fill, Background, Border, Text and Marks rows
-- had no visible effect. Each case writes a row through the panel's own write seam (the
-- descriptor's set, NS.SetByPath, which runs the row's onChange) and asserts what the DRAWN bar
-- regions now carry on a main-window row and a detached block's row, not
-- only the resolved style table the earlier cases read.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNear = T.assertNear

local W = 200   -- the width every bar under test is armed at, so Layout places real pixels

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()   -- a coalesced bulk send, if one was queued
end

--- Spy one bar: arm its width and record every SetHeight it is told, on the object itself (a
--- pooled bar is the same object after a relayout, so the spy survives it).
local function spy(bar)
    if rawget(bar, "__spied") then return bar end
    rawset(bar, "__spied", true)
    bar:__setGeom(W, 14)
    rawset(bar, "SetHeight", function(self, h) rawset(self, "__testH", h) end)
    return bar
end

--- A tooltip whose lines have the named regions the broker anchors its mini bars to.
local function recordingTip()
    local tip = M.CreateFrame("GameTooltip", "SkillMasterBarsLiveTip", M.UIParent)
    tip.lines = {}
    function tip:GetName() return "SkillMasterBarsLiveTip" end
    function tip:NumLines() return #self.lines end
    function tip:ClearLines() self.lines = {} end
    local function region(n)
        local name = "SkillMasterBarsLiveTipTextLeft" .. n
        _G[name] = _G[name] or M.CreateFrame("Frame", name, tip)
    end
    function tip:AddLine(text) self.lines[#self.lines + 1] = { text } region(#self.lines) end
    function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end
    return tip
end

--- Run `fn` with a LibSharedMedia that resolves every key to "lsm/<kind>/<key>" (the kit ships none).
local function withLSM(fn)
    local prev = M.__libs["LibSharedMedia-3.0"]
    M.__libs["LibSharedMedia-3.0"] = { Fetch = function(_, kind, key) return "lsm/" .. kind .. "/" .. key end }
    local ok, err = pcall(fn)
    M.__libs["LibSharedMedia-3.0"] = prev
    if not ok then error(err, 0) end
end

--- A learned skill row in the main window, by key.
local function windowRow(key)
    for _, row in ipairs(NS.MainWindow.Rows()) do
        if row.kind == "skill" and row.entry and row.entry.key == key then return row end
    end
end

local function detachedRow(key)
    for _, row in ipairs(NS.Detached.Rows("secondary") or {}) do
        if row.entry and row.entry.key == key then return row end
    end
end

--- The two bars a Bars-page row must reach: the window's Leatherworking row and the detached Fishing
--- row (the secondary block popped out, with the lure's timer). Spied in place. (The page's own
--- preview bar came off: owner feedback round 4.)
local function surfaces()
    local w, d = windowRow("leatherworking"), detachedRow("fishing")
    assertTrue(w ~= nil, "the window draws a Leatherworking row")
    assertTrue(d ~= nil, "the detached secondary block draws a Fishing row")
    return { window = spy(w.bar), detached = spy(d.bar) }
end

local function setUp()
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
    NS.Preview.Apply(true)          -- the sample character: Fishing 107 +25 / 150, a lure's timer
    NS.MainWindow.Show()
    if NS.Blocks.Settings("secondary").docked ~= false then NS.Blocks:Detach("secondary") end
    M.__fireTimers()
    return surfaces()
end

local function tearDown()
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
    if NS.Blocks.Settings("secondary").docked == false then NS.Blocks:Dock("secondary") end
    NS.MainWindow.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
end

--- A case on the three surfaces: set up, run, and ALWAYS tear down, so a red case leaves no sample
--- character or detached block behind for the suites after it.
local function case(name, fn)
    test(name, function()
        local ok, err = pcall(function() fn(setUp()) end)
        tearDown()
        if not ok then error(err, 0) end
    end)
end

local function each(bars, fn)
    for _, name in ipairs({ "window", "detached" }) do fn(bars[name], name) end
end

local function rgbaOf(region)
    local p = M.__paint(region)
    local c = p.texture and p.vertex or p.color
    return c
end

-- ---------------------------------------------------------------------------------------------
-- Size
-- ---------------------------------------------------------------------------------------------

case("bars live: the bar height reaches the window's rows and the detached blocks", function(bars)
    set("bars.height", 23)
    assertEqual(bars.window.__testH, 23, "the window's bar")
    assertEqual(bars.detached.__testH, 23, "the detached block's bar: one Bar height for both")
end)

case("bars live: the row height reaches every window row", function()
    local row = windowRow("leatherworking")
    local h
    rawset(row, "SetHeight", function(_, v) h = v end)
    set("bars.rowHeight", 31)
    assertEqual(h, 31, "the window's Fishing row")
    rawset(row, "SetHeight", nil)
end)

case("bars live: the tooltip and mini heights reach the row tooltip and the broker tooltip", function()
    set("bars.tooltipHeight", 15)
    NS.RowTooltip.Show(windowRow("leatherworking"))
    assertEqual(NS.RowTooltip.Bar().style.height, 15, "the row tooltip's bar")
    M.GameTooltip:Hide()
    set("bars.miniHeight", 12)
    NS.Broker.FillTooltip(recordingTip())
    local mini = NS.Broker.Bars()
    assertTrue(#mini > 0, "the broker tooltip drew mini bars")
    for _, b in ipairs(mini) do assertEqual(b.style.height, 12, "a broker mini bar") end
end)

-- ---------------------------------------------------------------------------------------------
-- Fill
-- ---------------------------------------------------------------------------------------------

case("bars live: fill direction anchors the fill on the right edge, and back", function(bars)
    set("bars.fillDirection", "RIGHT")
    each(bars, function(b, name)
        local point = b.fill:GetPoint(1)
        assertEqual(point, "TOPRIGHT", name .. ": the fill grows from the right")
    end)
    set("bars.fillDirection", "LEFT")
    each(bars, function(b, name) assertEqual((b.fill:GetPoint(1)), "TOPLEFT", name .. ": and from the left again") end)
end)

case("bars live: bar opacity scales the drawn fill's alpha", function(bars)
    set("bars.barAlpha", 0.4)
    each(bars, function(b, name)
        local c = rgbaOf(b.fill)
        assertNear(c[4], 0.4 * (b.fillColor[4] or 1), 1e-6, name .. ": the fill's alpha")
    end)
end)

case("bars live: the bar texture draws once its skin companion is off, and the skin's again once on", function(bars)
    local skinPath = {}
    each(bars, function(b, name) skinPath[name] = M.__paint(b.fill).texture end)
    withLSM(function()
        set("bars.barTextureFromSkin", false)
        set("bars.barTexture", "Ka0s Gradient")
        each(bars, function(b, name)
            assertEqual(M.__paint(b.fill).texture, "lsm/statusbar/Ka0s Gradient", name .. ": the picked texture")
        end)
    end)
    set("bars.barTextureFromSkin", true)
    each(bars, function(b, name)
        assertEqual(M.__paint(b.fill).texture, skinPath[name], name .. ": back on the skin's texture")
    end)
end)

case("bars live: the flat Bar color draws once Color mode is Flat and its companion is off", function(bars)
    set("bars.colorMode", "flat")
    set("bars.barColorFromSkin", false)
    set("bars.barColor", { 0.2, 0.4, 0.6, 1 })
    each(bars, function(b, name)
        local c = rgbaOf(b.fill)
        assertNear(c[1], 0.2, 1e-6, name .. ": red")
        assertNear(c[3], 0.6, 1e-6, name .. ": blue")
    end)
    set("bars.useClassColorBar", true)
    -- The class's red, or the stored swatch where the client answers no class (options-ui-§17).
    local r = M.LibStub("LibKa0s-Core-1.0").ClassColor("player") or 0.2
    each(bars, function(b, name) assertNear(rgbaOf(b.fill)[1], r, 1e-6, name .. ": the class color") end)
end)

case("bars live: the row tooltip's bar wears the row's own fill, so Color mode and the palette reach it", function()
    -- red under: a tooltip bar handed values with no color, drawn in the skin's flat fill whatever
    -- Color mode, the palette or Bar > Fill say.
    set("bars.colorMode", "flat")
    set("bars.barColorFromSkin", false)
    set("bars.barColor", { 0.3, 0.6, 0.9, 1 })
    NS.RowTooltip.Show(windowRow("leatherworking"))
    local c = rgbaOf(NS.RowTooltip.Bar().fill)
    assertNear(c[1], 0.3, 1e-6, "the tooltip bar's flat color")
    M.GameTooltip:Hide()
end)

-- ---------------------------------------------------------------------------------------------
-- Background and border
-- ---------------------------------------------------------------------------------------------

case("bars live: the background color draws once its companion is off", function(bars)
    set("bars.bgColorFromSkin", false)
    set("bars.bgColor", { 0.9, 0.1, 0.1, 0.5 })
    each(bars, function(b, name)
        local c = M.__paint(b.bg).color
        assertNear(c[1], 0.9, 1e-6, name .. ": the background's red")
        assertNear(c[4], 0.5, 1e-6, name .. ": and its alpha")
    end)
end)

case("bars live: turning the border off hides the drawn edges, and on shows them again", function(bars)
    set("bars.borderStyleFromSkin", false)
    set("bars.border", true)
    each(bars, function(b, name) assertTrue(b.edges[1]:IsShown(), name .. ": the border shows") end)
    set("bars.border", false)
    each(bars, function(b, name) assertFalse(b.edges[1]:IsShown(), name .. ": the border is hidden") end)
    set("bars.border", true)
    set("bars.borderSize", 3)
    each(bars, function(b, name)
        assertTrue(b.edges[1]:IsShown(), name .. ": shown again")
        assertEqual(b.edges[1]:GetHeight(), 3, name .. ": at the picked thickness")
    end)
    set("bars.borderColorFromSkin", false)
    set("bars.borderColor", { 0, 1, 0, 1 })
    each(bars, function(b, name) assertNear(M.__paint(b.edges[1]).color[2], 1, 1e-6, name .. ": the border color") end)
end)

-- ---------------------------------------------------------------------------------------------
-- Text
-- ---------------------------------------------------------------------------------------------

case("bars live: the bar text template and position reach the drawn text", function(bars)
    local tpl = "{pct}% ({left} left)"
    set("bars.textTemplate", tpl)
    each(bars, function(b, name)
        local v = b.values
        local want = NS.Bar.Text(v.value, v.bonus, v.max, tpl)
        assertTrue(want:find("left", 1, true) ~= nil, name .. ": the template renders")
        assertEqual(b.text:GetText(), want, name .. ": the drawn text follows the template")
    end)
    set("bars.textAnchor", "LEFT")
    each(bars, function(b, name) assertEqual((b.text:GetPoint(1)), "LEFT", name .. ": the text sits left") end)
end)

case("bars live: the font color and size draw once their companions are off", function(bars)
    set("bars.fontColorFromSkin", false)
    set("bars.fontColor", { 1, 0.5, 0, 1 })
    each(bars, function(b, name) assertNear(M.__paint(b.text).textColor[2], 0.5, 1e-6, name .. ": the text color") end)
    set("bars.fontFromSkin", false)
    set("bars.fontSize", 15)
    each(bars, function(b, name)
        local f = M.__paint(b.text).font
        assertEqual(f and f[2], 15, name .. ": the text size")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- Marks
-- ---------------------------------------------------------------------------------------------

local function shownCount(list)
    local n = 0
    for _, t in ipairs(list) do if t:IsShown() then n = n + 1 end end
    return n
end

case("bars live: Rank tier colors split the fill by tier on a scale to 300, and off restores it", function(bars)
    -- The window's Leatherworking (146 / 150) and the detached Fishing (107 / 150).
    each(bars, function(b, name)
        assertEqual(shownCount(b.segmentTextures), 0, name .. ": off by default, no segments")
        assertTrue(b.fill:IsShown(), name .. ": the one fill")
    end)
    set("bars.tierColors", true)
    each(bars, function(b, name)
        assertEqual(shownCount(b.segmentTextures), 2, name .. ": Apprentice and Journeyman")
        assertFalse(b.fill:IsShown(), name .. ": the segments take the fill's place")
        assertNear(b.geom.fill, b.values.value / 300, 1e-9, name .. ": to 300")
        local base = b.values.color
        local function paint(t) local p = M.__paint(t) return p.texture and p.vertex or p.color end
        local c1, c2 = paint(b.segmentTextures[1]), paint(b.segmentTextures[2])
        assertNear(c1[1], base[1], 1e-6, name .. ": Apprentice in the category's own color")
        assertNear(c2[3], base[3] * NS.Bar.TIER_SHADE[2], 1e-6, name .. ": Journeyman a shade darker")
        assertTrue(c2[1] < c1[1] or c1[1] == 0, name .. ": darker, not another hue")
    end)
    set("bars.tierColors", false)
    each(bars, function(b, name)
        assertEqual(shownCount(b.segmentTextures), 0, name .. ": off again")
        assertTrue(b.fill:IsShown(), name .. ": the fill is back")
    end)
end)

case("bars live: Rank tier colors works only under Color mode By category", function(bars)
    set("bars.tierColors", true)
    set("bars.colorMode", "progress")
    each(bars, function(b, name)
        assertEqual(shownCount(b.segmentTextures), 0, name .. ": By progress draws no tiers")
        assertNear(b.geom.fill, b.values.value / b.values.max, 1e-9, name .. ": on the cap again")
    end)
    set("bars.colorMode", "category")
    each(bars, function(b, name) assertEqual(shownCount(b.segmentTextures), 2, name .. ": back under By category") end)
end)

case("bars live: threshold markers hide on a stat's bar and come back", function()
    local bar
    for _, row in ipairs(NS.MainWindow.Rows()) do
        if row.kind == "stat" and row.entry and #(row.entry.markers or {}) > 0 then bar = spy(row.bar) break end
    end
    assertTrue(bar ~= nil, "a stat row with a marker is on screen")
    assertEqual(shownCount(bar.markerTextures), 0, "off in the window by default (R6-4)")
    set("bars.markersWindow", true)
    assertTrue(shownCount(bar.markerTextures) > 0, "its marker shows")
    set("bars.markersWindow", false)
    assertEqual(shownCount(bar.markerTextures), 0, "no marker")
end)

case("bars live: the expiry timer hides at once and comes back", function(bars)
    assertTrue(bars.detached.timer:IsShown(), "the lure's timer shows on the detached Fishing row")
    set("bars.timer", false)
    each(bars, function(b, name) assertFalse(b.timer:IsShown(), name .. ": no timer") end)
    set("bars.timer", true)
    assertTrue(bars.detached.timer:IsShown(), "the detached timer is back")
end)

case("bars live: the spark is off by default, shows when on and hides when off", function(bars)
    each(bars, function(b, name) assertFalse(b.spark:IsShown(), name .. ": off by default (feedback round 2)") end)
    set("bars.spark", true)
    each(bars, function(b, name) assertTrue(b.spark:IsShown(), name .. ": the spark rides the fill") end)
    set("bars.spark", false)
    each(bars, function(b, name) assertFalse(b.spark:IsShown(), name .. ": no spark") end)
    set("bars.spark", true)
    each(bars, function(b, name) assertTrue(b.spark:IsShown(), name .. ": the spark is back") end)
end)

-- ---------------------------------------------------------------------------------------------
-- The panel's own sliders
-- ---------------------------------------------------------------------------------------------

test("bars live: every Bars page slider commits while it moves, so a mouse wheel turn is written", function()
    -- red under: a release-only slider (AceGUI's OnMouseWheel fires OnValueChanged and no OnMouseUp).
    for _, row in ipairs(NS.SchemaForPage("bars")) do
        if row.type == "number" then assertEqual(row.commitOn, "change", row.path .. " commits live") end
    end
    local AG = M.LibStub("AceGUI-3.0")
    local panel = M.__subcategories["Bars"]
    panel:Show()
    panel:__fire("OnShow")
    local slider
    for i = #AG.__created, 1, -1 do
        local w = AG.__created[i]
        if w.type == "Slider" and w.labelText == NS.L["Bar height (px)"] then slider = w break end
    end
    assertTrue(slider ~= nil, "the Bar height slider is drawn")
    slider:__fire("OnValueChanged", 21)   -- a wheel notch, or a drag frame
    M.__fireTimers()
    assertEqual(NS.GetSetting("bars.height"), 21, "stored without a release")
    NS.Helpers.RestoreDefaults("bars")
    panel:Hide()
    panel:__fire("OnHide")
    M.__fireTimers()
end)
