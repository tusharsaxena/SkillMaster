-- tests/test_bars_sizes.lua — the Bars page's sizes after the owner's round-2 follow-up: the
-- tooltip rows renamed for the tooltip each one sizes (Main window tooltip, LDB tooltip), a row
-- height for each tooltip, no Detached bar height (a detached block takes the main window's bar and
-- row heights, schemaVersion 4 drops the stored key), and the bar border's style companion off by
-- default (a documented options-ui-§16 deviation, docs/ARCHITECTURE.md).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()
end

local function schemaRow(path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

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

--- A font-string stand-in that records the heights it is told.
local function line(name)
    local fs = M.CreateFrame("Frame", name, M.UIParent)
    fs.heights = {}
    rawset(fs, "SetHeight", function(self, h) self.heights[#self.heights + 1] = h self.h = h end)
    rawset(fs, "GetHeight", function(self) return self.h or 12 end)
    _G[name] = fs
    return fs
end

--- A tooltip whose lines are recording font strings, both sides.
local function recordingTip()
    local name = "SkillMasterSizesTip"
    local tip = M.CreateFrame("GameTooltip", name, M.UIParent)
    tip.lines = {}
    function tip:GetName() return name end
    function tip:NumLines() return #self.lines end
    local function regions(n)
        if not rawget(_G, name .. "TextLeft" .. n) then line(name .. "TextLeft" .. n) end
        if not rawget(_G, name .. "TextRight" .. n) then line(name .. "TextRight" .. n) end
    end
    function tip:AddLine(text) self.lines[#self.lines + 1] = { text } regions(#self.lines) end
    function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } regions(#self.lines) end
    return tip
end

local function withSample(fn)
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
    NS.Preview.Apply(true)
    NS.MainWindow.Show()
    local ok, err = pcall(fn)
    NS.Helpers.RestoreDefaults("bars")
    if NS.Blocks.Settings("secondary").docked == false then NS.Blocks:Dock("secondary") end
    NS.MainWindow.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

-- ── the rows: names, and no Detached bar height ─────────────────────────────────────────────

test("bar sizes: each tooltip's heights sit in its own group on the Tooltips page, no detached height", function()
    -- Owner feedback round 4 moved the four rows off the Bars page to the Tooltips page.
    local want = {
        ["bars.tooltipHeight"]    = { NS.L["Main window tooltip"], NS.L["Bar height (px)"] },
        ["bars.tooltipRowHeight"] = { NS.L["Main window tooltip"], NS.L["Row height (px)"] },
        ["bars.miniHeight"]       = { NS.L["LDB tooltip"], NS.L["Bar height (px)"] },
        ["bars.brokerRowHeight"]  = { NS.L["LDB tooltip"], NS.L["Row height (px)"] },
    }
    for path, w in pairs(want) do
        local r = schemaRow(path)
        assertTrue(r ~= nil, path .. " has a row")
        assertEqual(r.page, "tooltips", path .. " is on the Tooltips page")
        assertEqual(r.group, w[1], path .. "'s group")
        assertEqual(r.label, w[2], path .. "'s label")
        assertEqual(r.default, NS.defaults.profile.bars[path:match("[^.]+$")], path .. "'s default agrees")
    end
    assertTrue(schemaRow("bars.compactHeight") == nil, "no Detached bar height row")
    assertTrue(NS.defaults.profile.bars.compactHeight == nil, "no compactHeight default")
end)

test("bar sizes: a detached block's bar and row take the main window's bar and row heights", function()
    withSample(function()
        if NS.Blocks.Settings("secondary").docked ~= false then NS.Blocks:Detach("secondary") end
        set("bars.height", 19)
        set("bars.rowHeight", 27)
        local d = detachedRow("fishing")
        assertTrue(d ~= nil, "the detached secondary block draws a Fishing row")
        assertEqual(d.bar.style.height, 19, "the detached bar is the main window's height")
        assertEqual(d.baseH, 27, "the detached row is the main window's row height")
        assertEqual(windowRow("leatherworking").baseH, 27, "as the window's row is")
    end)
end)

-- ── the row heights reach each tooltip, and go back to auto ─────────────────────────────────

test("bar sizes: LDB tooltip row height sizes every skill or stat line, and a release hands them back", function()
    withSample(function()
        set("bars.brokerRowHeight", 22)
        local tip = recordingTip()
        local rows = NS.Broker.FillTooltip(tip)
        assertTrue(#rows > 0, "the feed drew rows")
        for _, row in ipairs(rows) do
            local left = _G[tip:GetName() .. "TextLeft" .. row.line]
            local right = _G[tip:GetName() .. "TextRight" .. row.line]
            assertEqual(left.h, 22, "row " .. row.line .. "'s name")
            assertEqual(right.h, 22, "row " .. row.line .. "'s value")
        end
        assertTrue(_G[tip:GetName() .. "TextLeft1"].h == nil, "the title line keeps its own height")
        -- Never shorter than its bar.
        set("bars.brokerRowHeight", 10)
        set("bars.miniHeight", 16)
        rows = NS.Broker.FillTooltip(tip)
        assertEqual(_G[tip:GetName() .. "TextLeft" .. rows[1].line].h, 16, "the bar's height wins")
        NS.Broker.HideTooltip()   -- releases: every sized line back to auto
        NS.Broker.FillTooltip(recordingTip())
        NS.Broker.HideTooltip()
        for _, row in ipairs(rows) do
            assertEqual(_G[tip:GetName() .. "TextLeft" .. row.line].h, 0, "line " .. row.line .. " back to auto")
        end
    end)
end)

test("bar sizes: Main window tooltip row height sizes the bar's line, and a clear hands it back", function()
    withSample(function()
        for n = 1, 30 do if not rawget(_G, "GameTooltipTextLeft" .. n) then line("GameTooltipTextLeft" .. n) end end
        set("bars.tooltipRowHeight", 24)
        NS.RowTooltip.Show(windowRow("leatherworking"))
        local sized
        for n = 1, 30 do
            local fs = _G["GameTooltipTextLeft" .. n]
            if fs.h and fs.h > 0 then sized = fs end
        end
        assertTrue(sized ~= nil, "the bar's line was sized")
        assertEqual(sized.h, 24, "at the row height")
        M.GameTooltip:__fire("OnTooltipCleared")   -- the next owner's SetOwner, or a hide
        assertEqual(sized.h, 0, "cleared: back to auto height for the next tooltip")
        set("bars.tooltipRowHeight", 10)
        set("bars.tooltipHeight", 18)
        assertEqual(NS.Bar.TooltipRowHeight("tooltip"), 18, "never shorter than its bar")
        for n = 1, 30 do _G["GameTooltipTextLeft" .. n] = nil end
    end)
end)

-- ── schemaVersion 4: the stored detached height goes ────────────────────────────────────────

test("bar sizes: schemaVersion 4 drops a stored bars.compactHeight and keeps the rest", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["Sizes-Custom"] = { bars = { compactHeight = 17, height = 21 } }
    sv.profiles["Sizes-Fresh"] = {}
    NS.db.global.schemaVersion = 3
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION, "the runner reaches the newest step")
    assertTrue(NS.SCHEMA_VERSION >= 4, "step 4 is in the ladder")
    assertTrue(sv.profiles["Sizes-Custom"].bars.compactHeight == nil, "the stored detached height goes")
    assertEqual(sv.profiles["Sizes-Custom"].bars.height, 21, "the bar height is kept")
    assertTrue(sv.profiles["Sizes-Fresh"].bars == nil, "a profile with no bars passes this step (later steps may write it)")
    sv.profiles["Sizes-Custom"], sv.profiles["Sizes-Fresh"] = nil, nil
end)

-- ── the border's style companion: off by default (options-ui-§16 deviation) ─────────────────

test("bar sizes: Use the skin's border is off by default, so a skin's real style never beats Show border off", function()
    assertFalse(NS.defaults.profile.bars.borderStyleFromSkin, "defaults/Profile.lua")
    local r = schemaRow("bars.borderStyleFromSkin")
    assertTrue(r ~= nil, "the companion row")
    assertFalse(r.default, "the row's default agrees")
    local S = NS.Skin
    local prev = rawget(S, "BarBorder")
    rawset(S, "BarBorder", function(style, show, size, fromSkin)
        if fromSkin then return "Solid", true, 1 end   -- Azeroth / High Contrast / WoW Midnight
        return style, show, size
    end)
    local ok, err = pcall(function()
        assertEqual(NS.Bar.ResolveStyle("row").border, nil, "Show border off: no border under a real skin style")
        set("bars.borderStyleFromSkin", true)
        assertTrue(NS.Bar.ResolveStyle("row").border ~= nil, "opted in: the skin's style wins (skinning-§6)")
    end)
    rawset(S, "BarBorder", prev)
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
    if not ok then error(err, 0) end
end)

-- ── owner feedback round 4: the Tooltips page's widths and font sizes ───────────────────────

test("tooltips: a font size reaches a tooltip's lines and goes back to each line's own font", function()
    -- red under: a size written onto GameTooltip's shared font strings and never put back
    local name = "SkillMasterFontTip"
    local tip = M.CreateFrame("GameTooltip", name, M.UIParent)
    function tip:GetName() return name end
    function tip:NumLines() return 2 end
    local fonts = {}
    for n = 1, 2 do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local fs = { font = { "Fonts\\FRIZQT__.TTF", n == 1 and 14 or 12, "" } }
            function fs:GetFont() return self.font[1], self.font[2], self.font[3] end
            function fs:SetFont(face, size, flags) self.font = { face, size, flags } end
            _G[name .. side .. n] = fs
            fonts[side .. n] = fs
        end
    end
    NS.Chrome.TooltipFontSize(tip, 16, 1)
    assertEqual(fonts.TextLeft1.font[2], 18, "the title line 2 px larger")
    assertEqual(fonts.TextLeft2.font[2], 16)
    assertEqual(fonts.TextRight2.font[2], 16)
    NS.Chrome.TooltipFontSize(tip, 10, 1)   -- a second size before a clear keeps the first originals
    NS.Chrome.RestoreTooltipFonts(tip)
    assertEqual(fonts.TextLeft1.font[2], 14, "the title's own size back")
    assertEqual(fonts.TextLeft2.font[2], 12, "each line's own size back")
    for k in pairs(fonts) do _G[name .. k] = nil end
end)

test("tooltips: the row tooltip's bar takes Tooltips > Bar width; the LDB tooltip widens for its own", function()
    withSample(function()
        for n = 1, 30 do if not rawget(_G, "GameTooltipTextLeft" .. n) then line("GameTooltipTextLeft" .. n) end end
        set("tooltips.row.barWidth", 260)
        NS.RowTooltip.Show(windowRow("leatherworking"))
        local b = NS.RowTooltip.Bar()
        assertEqual(b.knownWidth, 260, "the bar at the stored width")
        M.GameTooltip:__fire("OnTooltipCleared")
        for n = 1, 30 do _G["GameTooltipTextLeft" .. n] = nil end
        local base = NS.Broker.MinWidth()
        set("tooltips.ldb.barWidth", NS.defaults.profile.tooltips.ldb.barWidth + 50)
        assertEqual(NS.Broker.MinWidth(), base + 50, "the LDB tooltip's least width follows its bar width")
        assertEqual(base, 380, "the default keeps the old 380 px tooltip")
        set("tooltips.row.barWidth", NS.defaults.profile.tooltips.row.barWidth)
        set("tooltips.ldb.barWidth", NS.defaults.profile.tooltips.ldb.barWidth)
    end)
end)
