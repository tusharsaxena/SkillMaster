-- tests/test_round6.lua — the owner's round-6 feedback (2026-11-13): the toasts in the cap toast's
-- look, test mode's cues on the Journal and the LDB tooltip, the header marks at one size and one
-- vertical center, the sort mark's menu, every block expanded on a new profile, the thresholds'
-- two switches, the trainer popup's Set waypoint button and its next-rank-and-above trainers.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local A = NS.Alerts

local function entry(key, name, kind, rank, max)
    return { key = key, name = name, category = kind == "weapon" and "weapon" or "primary", kind = kind,
             rank = rank, max = max, tempPoints = 0, modifier = 0, learned = true }
end

--- The real toast library on a fresh instance, alerts settings for the case, then everything back.
local function withToast(settings, fn)
    local savedToast, savedAlerts, savedSkill, savedLevel = A.toast, NS.db.profile.alerts, NS.SkillData, M.UnitLevel
    M.UnitLevel = function() return 22 end   -- a weapon cap of 110
    NS.db.profile.alerts = { cap = true, weapon = true, weaponGap = 25, sound = false, point = false, skillUp = true }
    for k, v in pairs(settings or {}) do NS.db.profile.alerts[k] = v end
    A.Reset()
    A.toast = A.NewToast()
    local ok, err = pcall(fn)
    A.toast:Clear()
    A.toast, NS.db.profile.alerts, NS.SkillData, M.UnitLevel = savedToast, savedAlerts, savedSkill, savedLevel
    A.Reset()
    if not ok then error(err, 0) end
end

local function hexOf(token)
    local r, g, b = NS.Skin.Color(token)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

-- ── R6-1: the gap and skill-up toasts in the cap toast's look ────────────────────────────────

test("round6 toast: the gap and skill-up toasts wear the cap toast's skin shell, no tint or edge of their own", function()
    local daggers = entry("daggers", "Daggers", "weapon", 74, 110)
    withToast(nil, function()
        A.CheckGap(daggers)
        local gap = A.toast:FrameFor("weapon:daggers")
        assertTrue(gap ~= nil, "the gap toast is up")
        A.CheckSkillUp(entry("bows", "Bows", "weapon", 81, 110))
        local up = A.toast:FrameFor("skillup")
        assertTrue(up ~= nil, "the skill-up toast is up")
        for _, f in ipairs({ gap, up }) do
            assertTrue(not (f.skmTint and f.skmTint:IsShown()), "no kind tint over the skin's background")
            for _, t in ipairs(f.skmEdges or {}) do assertFalse(t:IsShown(), "no kind edge over the skin's border") end
            -- A recorder on the icon's SetSize (the kit records frame geometry only on opt-in), then
            -- the toast drawn again.
            local w
            rawset(f.skmIcon, "SetSize", function(_, width) w = width end)
            A.Build(f, f.skmPayload)
            rawset(f.skmIcon, "SetSize", nil)
            assertEqual(w, A.ICON, "the cap toast's icon size")
        end
    end)
end)

test("round6 toast: the value stays red or green and carries its delta in brackets", function()
    local daggers = entry("daggers", "Daggers", "weapon", 74, 110)
    withToast(nil, function()
        A.CheckGap(daggers)
        local f = A.toast:FrameFor("weapon:daggers")
        local bad = hexOf("sem.bad")
        assertEqual(f.skmTitle:GetText(), "Daggers " .. bad .. "74 / 110 (-36)|r")
        assertTrue(f.skmLabel:GetText():find(bad, 1, true) == 1, "the small label keeps its semantic color")
        A.CheckSkillUp(entry("bows", "Bows", "weapon", 81, 110))
        f = A.toast:FrameFor("skillup")
        assertEqual(f.skmTitle:GetText(), "Bows " .. hexOf("sem.good") .. "81 / 110 (+1)|r")
    end)
end)

test("round6 toast: test mode's gap and skill-up toasts take the same look", function()
    NS.Preview.Apply(true)
    local ok, err = pcall(function()
        local byKey = {}
        for _, t in ipairs(A.TestToasts()) do byKey[t.key] = t.payload end
        assertTrue(byKey["test:weapon"] ~= nil and byKey["test:skillup"] ~= nil, "the sample draws both")
        withToast(nil, function()
            for _, key in ipairs({ "test:weapon", "test:skillup" }) do
                A.toast:Show(byKey[key], { key = key, sticky = true })
                local f = A.toast:FrameFor(key)
                assertTrue(f ~= nil, key .. " is up")
                assertTrue(not (f.skmTint and f.skmTint:IsShown()), key .. ": no kind tint")
                assertTrue(f.skmTitle:GetText():find("%(%p%d+%)|r$") ~= nil, key .. ": the delta in brackets")
            end
        end)
    end)
    NS.Preview.Apply(false)
    if not ok then error(err, 0) end
end)

-- ── R6-2: test mode's cues on the Journal and the LDB tooltip ────────────────────────────────

local J, B = NS.Journal, NS.Broker
local STRIP_TEXT = NS.L["Test mode: the skills shown are sample data."]

--- Record the y of `region`'s TOPLEFT anchor as production sets it (the kit records a frame's
--- points only on a texture): answers a reader of the last one set, and an undo.
local function spyTop(region)
    local y
    rawset(region, "SetPoint", function(_, point, _, _, _, dy) if point == "TOPLEFT" then y = dy end end)
    return function() return y end, function() rawset(region, "SetPoint", nil) end
end

--- Test mode on and off around fn, from a clean state; whatever fn raised is raised after.
local function withTestMode(fn)
    if NS.IsTestMode() then NS.ToggleTestMode() end
    NS.ToggleTestMode()
    local ok, err = pcall(fn)
    if NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    if not ok then error(err, 0) end
end

test("round6 test mode: the Journal shows the main window's strip and its body moves down under it", function()
    J.Show()
    local f = J.Frame()
    local rows = J.VisibleLogRows()
    local tabY, undoTab = spyTop(f.tabs.log)
    local panelY, undoPanel = spyTop(f.logPanel)
    local ok, err = pcall(function()
        assertTrue(not (f.strip and f.strip:IsShown()), "no strip outside test mode")
        local onTab, onPanel
        withTestMode(function()
            assertTrue(J.IsShown(), "the Journal, open before, stays open")
            assertTrue(f.strip ~= nil and f.strip:IsShown(), "the strip shows")
            assertEqual(f.strip.text:GetText(), STRIP_TEXT)
            onTab, onPanel = tabY(), panelY()
            assertTrue(onTab ~= nil and onPanel ~= nil, "the tabs and the body are placed again")
            assertTrue(J.VisibleLogRows() < rows, "the log fits the rows left under it")
        end)
        assertFalse(f.strip:IsShown(), "test mode off: the strip goes")
        local h = NS.Widgets.TEST_STRIP.HEIGHT
        assertEqual(onTab, tabY() - h, "the tabs sat the strip's height lower, and move back")
        assertEqual(onPanel, panelY() - h, "the body too")
        assertEqual(J.VisibleLogRows(), rows, "and the log's rows")
    end)
    undoTab()
    undoPanel()
    J.Hide()
    if not ok then error(err, 0) end
end)

--- A tooltip that records its lines (tests/test_broker.lua's shape): tip.lines[n] = { left, right }.
local function recordingTip()
    local tip = M.CreateFrame("GameTooltip", "SkillMasterRound6Tip", M.UIParent)
    tip.lines = {}
    function tip:GetName() return "SkillMasterRound6Tip" end
    function tip:NumLines() return #self.lines end
    function tip:ClearLines() self.lines = {} end
    local function region(n)
        local name = "SkillMasterRound6TipTextLeft" .. n
        _G[name] = _G[name] or M.CreateFrame("Frame", name, tip)
    end
    function tip:AddLine(text) self.lines[#self.lines + 1] = { text } region(#self.lines) end
    function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end
    return tip
end

local function tipLines(tip)
    local out = {}
    for _, l in ipairs(tip.lines) do out[#out + 1] = l[1] or "" end
    return out
end

test("round6 test mode: the LDB tooltip says test mode under its title while it is on", function()
    local tip = recordingTip()
    B.FillTooltip(tip)
    for _, line in ipairs(tipLines(tip)) do
        assertTrue(line:find(STRIP_TEXT, 1, true) == nil, "no test-mode line outside test mode")
    end
    tip:ClearLines()
    withTestMode(function()
        B.FillTooltip(tip)
        local lines = tipLines(tip)
        assertTrue((lines[2] or ""):find(STRIP_TEXT, 1, true) ~= nil, "the line right under the title: " .. tostring(lines[2]))
        tip:ClearLines()
        assertTrue(B.AddTestModeLine(tip) == true, "the helper adds it")
        assertEqual(tip:NumLines(), 1)
    end)
    tip:ClearLines()
    assertTrue(B.AddTestModeLine(tip) == false and tip:NumLines() == 0, "off: the helper adds nothing")
end)

-- ── R6-3: every header mark one size and one vertical center ─────────────────────────────────

local C, D, G, W = NS.Chrome, NS.Detached, NS.Groups, NS.MainWindow

--- The ink box of a shipped TGA (32-bit, RLE or raw, either origin): { left, top, right, bottom }
--- in pixels over every pixel with any alpha, the way C.INK was measured.
local function inkOf(file)
    local fh = assert(io.open(file, "rb"), file)
    local data = fh:read("*a")
    fh:close()
    local idLen, cmapType, imgType = data:byte(1), data:byte(2), data:byte(3)
    assert(cmapType == 0 and (imgType == 2 or imgType == 10), file .. ": a true-color TGA")
    local w, h = data:byte(13) + data:byte(14) * 256, data:byte(15) + data:byte(16) * 256
    assert(data:byte(17) == 32, file .. ": 32 bits a pixel")
    local topDown = (data:byte(18) % 64) >= 32
    local pos, n, total = 19 + idLen, 0, w * h
    local l, t, r, b = w, h, -1, -1
    local function put(alpha)
        if alpha > 0 then
            local x, y = n % w, math.floor(n / w)
            if not topDown then y = h - 1 - y end
            l, t, r, b = math.min(l, x), math.min(t, y), math.max(r, x), math.max(b, y)
        end
        n = n + 1
    end
    while n < total do
        if imgType == 2 then
            put(data:byte(pos + 3))
            pos = pos + 4
        else
            local head = data:byte(pos)
            pos = pos + 1
            local count = head % 128 + 1
            if head >= 128 then
                local alpha = data:byte(pos + 3)
                pos = pos + 4
                for _ = 1, count do put(alpha) end
            else
                for _ = 1, count do
                    put(data:byte(pos + 3))
                    pos = pos + 4
                end
            end
        end
    end
    return { l, t, r + 1, b + 1 }, w
end

--- The repo path of a catalog mark's art: NS.Icon's extensionless client path, made a file.
local function artFile(icon)
    local path = NS.Icon(icon)
    return path and (path:gsub("^Interface\\AddOns\\[^\\]+\\", ""):gsub("\\", "/") .. ".tga")
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

--- One mark as a header draws it: fitted, its ink cropped exactly, its longer side C.INK_SIZE,
--- centered on its control.
local function checkMark(where, b)
    if not (b and b.icon) then return 0 end
    assertTrue(b.fit == true, where .. ": built as a header mark")
    local icon
    for name in pairs(C.INK) do if NS.Icon(name) == b.icon:GetTexture() then icon = name end end
    assertTrue(icon ~= nil, where .. ": its art has an ink box (" .. tostring(b.icon:GetTexture()) .. ")")
    local w, h = b.icon:GetSize()
    assertTrue(near(math.max(w, h), C.INK_SIZE), ("%s: %s's longer side is %d, drew %gx%g"):format(where, icon, C.INK_SIZE, w, h))
    local point, rel, relPoint, x, y = b.icon:GetPoint(1)
    assertTrue(point == "CENTER" and rel == b and relPoint == "CENTER" and x == 0 and y == 0, where .. ": centered on its control")
    local box = C.INK[icon]
    local l, r, t, btm = box[1] / 64, box[3] / 64, box[2] / 64, box[4] / 64
    -- The client's eight-value answer: the corners UL, LL, UR, LR, each x then y.
    local c = { b.icon:GetTexCoord() }
    local upright = near(c[1], l) and near(c[2], t) and near(c[5], r) and near(c[4], btm)
    local turned = near(c[1], r) and near(c[2], btm) and near(c[5], l) and near(c[4], t)
    assertTrue(upright or turned, where .. ": " .. icon .. " cropped to its ink box")
    return 1
end

test("round6 header marks: every ink box is the shipped art's own", function()
    for icon, box in pairs(C.INK) do
        local file = artFile(icon)
        assertTrue(file ~= nil, icon .. ": a declared mark")
        local ink, size = inkOf(file)
        assertEqual(size, 64, icon .. ": a 64 px square")
        assertEqual(table.concat(box, ","), table.concat(ink, ","), icon .. "'s ink box (" .. file .. ")")
    end
end)

test("round6 header marks: the window header, a detached band, a merged band and a sub-header draw every mark fitted", function()
    local layout = NS.db.profile.layout
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(function()
        local n = 0
        -- The window's header: the weapon block shows the filter mark; one hidden row shows restore.
        NS.db.profile.skills.hidden = NS.db.profile.skills.hidden or {}
        NS.db.profile.skills.hidden.daggers = true
        W.Render()
        local h = W.HeaderFor("weapon")
        assertTrue(h ~= nil, "the weapon block's header")
        for _, k in ipairs({ "chevron", "filter", "sort", "detach", "restore" }) do
            n = n + checkMark("header " .. k, h[k])
        end
        assertTrue(h.filter:IsShown() and h.restore:IsShown(), "the filter and restore marks show")
        -- A detached band.
        layout.blocks.weapon.docked = false
        D.Refresh()
        local f = D.Frame("weapon")
        for _, k in ipairs({ "dock", "collapse", "sort", "filter", "restore" }) do
            n = n + checkMark("band " .. k, f[k])
        end
        -- A merged window's band and its sections' sub-headers.
        layout.blocks.secondary.docked = false
        D.Refresh()
        local gid = G.Merge("weapon", "secondary", "bottom")
        local g = G.Frame(gid)
        for _, k in ipairs({ "dockAll", "collapseAll" }) do n = n + checkMark("merged band " .. k, g[k]) end
        local sh = G.Section(gid, "weapon").header
        for _, k in ipairs({ "chevron", "filter", "sort", "split" }) do
            n = n + checkMark("sub-header " .. k, sh[k])
        end
        assertTrue(n >= 16, "every surface's marks checked, " .. n)
    end)
    NS.db.profile.skills.hidden.daggers = nil
    layout.groups = {}
    layout.blocks.weapon.docked, layout.blocks.secondary.docked = true, true
    D.Refresh()
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end)

-- ── R6-5: the sort mark's menu ───────────────────────────────────────────────────────────────

--- The sort mark `mark` opens the filter mark's menu on itself: a title, one radio row per order
--- (the current one ticked), and a row's click stores its order through the seam. `redraw` answers
--- the mark again after a layout (a pooled header can change).
local function checkSortMenu(where, id, mark, redraw)
    local Bk = NS.Blocks
    local real, opened = NS.Widgets.ContextMenu, nil
    NS.Widgets.ContextMenu = function(anchor, rows, opts) opened = { anchor = anchor, rows = rows, opts = opts } return {} end
    local ok, err = pcall(function()
        assertEqual(mark.tip, NS.L["Sorted: %s. Click to sort."]:format(Bk.SORT_LABEL.name), where .. ": the tip names the order")
        mark:__fire("OnClick", "LeftButton")
        assertTrue(opened ~= nil and opened.anchor == mark, where .. ": the click opens a menu on the mark")
        assertEqual(Bk.SortOf(id), "name", where .. ": the click alone changes nothing")
        local rows = opened.rows
        assertTrue(rows[1].title == true, where .. ": a title row first")
        assertEqual(#rows, #Bk.SORTS + 1, where .. ": one row per order")
        for i, mode in ipairs(Bk.SORTS) do
            local r = rows[i + 1]
            assertTrue(r.radio == true and r.value == mode and r.label == Bk.SORT_LABEL[mode], where .. ": " .. mode)
            assertEqual(r.selected(), mode == "name", where .. ": " .. mode .. " ticked only when current")
        end
        rows[4].onClick()   -- Value, lowest first
        M.__fireTimers()
        assertEqual(Bk.SortOf(id), "valueAsc", where .. ": the row's order")
        assertEqual(NS.db.profile.layout.blocks[id].sort, "valueAsc", where .. ": stored through the seam")
        assertTrue(rows[4].selected() and not rows[2].selected(), where .. ": the tick follows")
        local again = redraw()
        assertEqual(again.tip, NS.L["Sorted: %s. Click to sort."]:format(Bk.SORT_LABEL.valueAsc), where .. ": the redrawn tip")
        assertEqual(again.icon:GetTexture(), NS.Icon(Bk.SORT_ICON.valueAsc), where .. ": and its mark")
    end)
    NS.Widgets.ContextMenu = real
    NS.db.profile.layout.blocks[id].sort = "name"
    if not ok then error(err, 0) end
end

test("round6 sort menu: the sort mark opens a menu of every order on the header, the band and the sub-header", function()
    local layout = NS.db.profile.layout
    for _, id in ipairs(NS.BLOCKS) do layout.blocks[id].sort = "name" end
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(function()
        W.Render()
        checkSortMenu("header", "weapon", W.HeaderFor("weapon").sort, function()
            W.Render()
            return W.HeaderFor("weapon").sort
        end)
        layout.blocks.weapon.docked = false
        D.Refresh()
        checkSortMenu("band", "weapon", D.Frame("weapon").sort, function()
            D.Render("weapon")
            return D.Frame("weapon").sort
        end)
        layout.blocks.secondary.docked = false
        D.Refresh()
        local gid = G.Merge("weapon", "secondary", "bottom")
        checkSortMenu("sub-header", "secondary", G.Section(gid, "secondary").header.sort, function()
            G.Render(gid)
            return G.Section(gid, "secondary").header.sort
        end)
    end)
    layout.groups = {}
    layout.blocks.weapon.docked, layout.blocks.secondary.docked = true, true
    for _, id in ipairs(NS.BLOCKS) do layout.blocks[id].sort = "name" end
    D.Refresh()
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end)

-- ── R6-8: every block expanded on a new profile ──────────────────────────────────────────────

test("round6 expanded: a new profile has every block expanded, in the window and the LDB tooltip", function()
    for _, id in ipairs(NS.BLOCKS) do
        assertEqual(NS.defaults.profile.layout.blocks[id].collapsed, false, id .. " expanded by default")
    end
end)

-- ── R6-4: thresholds off in the window, on in the row tooltip ────────────────────────────────

local function schemaRow(path)
    for _, r in ipairs(NS.Schema) do if r.path == path then return r end end
end

test("round6 thresholds: two switches, off in the window and on in the row tooltip, on the Bars page", function()
    local P = NS.defaults.profile.bars
    assertEqual(P.markersWindow, false, "the window's default")
    assertEqual(P.markersTooltip, true, "the row tooltip's default")
    assertTrue(P.markers == nil and schemaRow("bars.markers") == nil, "the one old switch is gone")
    for path, def in pairs({ ["bars.markersWindow"] = false, ["bars.markersTooltip"] = true }) do
        local r = schemaRow(path)
        assertTrue(r ~= nil, path .. " has a row")
        assertEqual(r.page, "bars", path .. " on the Bars page, where the old switch was")
        assertEqual(r.group, NS.L["Marks"], path .. " under Marks")
        assertEqual(r.default, def, path .. "'s row default agrees")
    end
end)

test("round6 thresholds: the tooltip bar follows its own switch, every other bar the window's", function()
    local Bar = NS.Bar
    NS.Helpers.RestoreDefaults("bars")
    for _, k in ipairs({ "row", "compact", "mini" }) do
        assertFalse(Bar.ResolveStyle(k).showMarkers, k .. ": off by default")
    end
    assertTrue(Bar.ResolveStyle("tooltip").showMarkers, "the row tooltip's bar: on by default")
    NS.SetByPath("bars.markersWindow", true)
    NS.SetByPath("bars.markersTooltip", false)
    for _, k in ipairs({ "row", "compact", "mini" }) do
        assertTrue(Bar.ResolveStyle(k).showMarkers, k .. ": the window switch on")
    end
    assertFalse(Bar.ResolveStyle("tooltip").showMarkers, "the row tooltip's switch off")
    NS.Helpers.RestoreDefaults("bars")
end)

test("round6 thresholds: the row tooltip lists the thresholds only while its switch is on", function()
    local e = { key = "hit", label = "Hit", display = "2.0%", pct = 22.2, ref = 9,
                markers = { { at = 55.6, value = 5, label = "vs same level" } } }
    local function joined()
        local t = {}
        for _, l in ipairs(NS.RowTooltip.Lines(e, "stat")) do t[#t + 1] = l.left or "" end
        return table.concat(t, "\n")
    end
    assertTrue(joined():find("vs same level", 1, true) ~= nil, "listed by default")
    NS.SetByPath("bars.markersTooltip", false)
    assertTrue(joined():find("vs same level", 1, true) == nil, "gone with the switch off")
    NS.Helpers.RestoreDefaults("bars")
end)

test("round6 thresholds: the window legend's threshold entry shows only with the window switch on", function()
    NS.Helpers.RestoreDefaults("bars")
    W.Show()
    W.Render()
    local lg = W.Frame().legend
    assertFalse(lg.markerTex:IsShown(), "no threshold mark by default")
    assertFalse(lg.markerLabel:IsShown(), "no threshold label by default")
    NS.SetByPath("bars.markersWindow", true)
    M.__fireTimers()
    W.Render()
    assertTrue(lg.markerTex:IsShown() and lg.markerLabel:IsShown(), "the entry with the switch on")
    NS.Helpers.RestoreDefaults("bars")
    M.__fireTimers()
    W.Render()
    W.Hide()
end)

test("round6 thresholds: schemaVersion 7 carries a stored false to both switches and drops the old key", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R6-Off"] = { bars = { markers = false, height = 21 } }
    sv.profiles["R6-On"] = { bars = { markers = true } }
    sv.profiles["R6-Fresh"] = {}
    NS.db.global.schemaVersion = 6
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION, "the runner reaches the newest step")
    assertTrue(NS.SCHEMA_VERSION >= 7, "step 7 is in the ladder")
    local off, on = sv.profiles["R6-Off"].bars, sv.profiles["R6-On"].bars
    assertEqual(off.markersWindow, false, "off carries to the window")
    assertEqual(off.markersTooltip, false, "off carries to the row tooltip")
    assertTrue(off.markers == nil and on.markers == nil, "the old key goes")
    assertEqual(off.height, 21, "the rest is kept")
    assertTrue(on.markersWindow == nil and on.markersTooltip == nil, "the old default leaves the new defaults to answer")
    assertTrue(next(sv.profiles["R6-Fresh"]) == nil, "a fresh profile passes through")
    sv.profiles["R6-Off"], sv.profiles["R6-On"], sv.profiles["R6-Fresh"] = nil, nil, nil
end)

-- ── R6-6: the Set waypoint button ────────────────────────────────────────────────────────────

local TP = NS.TrainerPopup

--- The popup on `key` with TomTom or not, the native pin API or not, then everything back.
local function withTrainerPopup(key, opts, fn)
    local saved = { TomTom = M.TomTom, C_Map = M.C_Map, UiMapPoint = M.UiMapPoint }
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.TomTom = opts.tomtom and { AddWaypoint = function() return {} end } or nil
    if opts.native then
        M.C_Map = { SetUserWaypoint = function() end, CanSetUserWaypointOnMap = function() return true end }
        M.UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { id = id, x = x, y = y } end }
    else
        M.C_Map, M.UiMapPoint = nil, nil
    end
    TP.Show(key)
    local ok, err = pcall(fn, TP.Frame())
    TP.Hide()
    M.TomTom, M.C_Map, M.UiMapPoint = saved.TomTom, saved.C_Map, saved.UiMapPoint
    M.UnitFactionGroup = savedFaction
    NS.SetByPath("waypoints.method", NS.defaults.profile.waypoints.method)
    if not ok then error(err, 0) end
end

local function tipText(owner)
    local saved = M.GameTooltip
    local lines = {}
    local tip = { SetOwner = function() end, Show = function() end, IsOwned = function() return false end,
                  AddLine = function(_, s) lines[#lines + 1] = s end }
    M.GameTooltip = tip
    owner:GetScript("OnEnter")(owner)
    M.GameTooltip = saved
    return table.concat(lines, "\n")
end

test("round6 waypoint: the button reads Set waypoint whatever the provider, and no footer is left", function()
    withTrainerPopup("fistWeapons", { tomtom = true }, function(f)
        assertEqual(f.waypoint.text:GetText(), "Set waypoint", "TomTom loaded: no provider in brackets")
        assertTrue(f.waypoint:IsEnabled(), "a trainer with coordinates and TomTom: enabled")
        assertTrue(f.footer == nil, "no Waypoint order footer")
        assertEqual(tipText(f.waypoint), "", "no tooltip while it works")
    end)
    withTrainerPopup("fistWeapons", { native = true }, function(f)
        assertEqual(f.waypoint.text:GetText(), "Set waypoint", "the map pin: the same label")
        assertTrue(f.waypoint:IsEnabled(), "the native pin: enabled")
    end)
end)

test("round6 waypoint: a trainer without coordinates disables the button and its tooltip says why", function()
    withTrainerPopup("fishing", { tomtom = true, native = true }, function(f)
        local t = TP.Selected()
        assertTrue(t ~= nil and t.x == nil, "the fishing trainers carry no coordinates")
        assertEqual(f.waypoint.text:GetText(), "Set waypoint", "never Set waypoint (chat)")
        assertFalse(f.waypoint:IsEnabled(), "disabled: it could only print to chat")
        assertEqual(tipText(f.waypoint), "No map coordinates for this trainer yet; Print to chat gives directions.")
        assertTrue(f.print:IsEnabled(), "Print to chat still works")
    end)
    withTrainerPopup("fistWeapons", { tomtom = true }, function(f)
        NS.SetByPath("waypoints.method", "chat")
        TP.Select(1)
        assertFalse(f.waypoint:IsEnabled(), "Waypoint method Chat only: disabled")
        assertTrue(tipText(f.waypoint):find("Chat only", 1, true) ~= nil, "its tooltip names the setting")
    end)
    withTrainerPopup("fistWeapons", {}, function(f)
        assertFalse(f.waypoint:IsEnabled(), "no TomTom and no map pin: disabled")
        assertTrue(tipText(f.waypoint):find("No TomTom", 1, true) ~= nil, "its tooltip says so")
    end)
end)

test("round6 waypoint: the window ends a pad under the buttons, shorter by the old footer", function()
    withTrainerPopup("fistWeapons", { tomtom = true }, function(f)
        local h, y
        f.SetHeight = function(_, v) h = v end
        f.waypoint.SetPoint = function(_, point, _, _, _, oy) if point == "TOPLEFT" then y = oy end end
        TP.Relayout()
        f.SetHeight, f.waypoint.SetPoint = nil, nil
        assertTrue(y ~= nil, "the buttons were placed")
        assertEqual(h, -y + 26 + 10, "the buttons' top, their height and one pad")
    end)
end)

-- ── R6-7: the next rank's trainers and every higher rank's ───────────────────────────────────

local TR = NS.Trainers

local function names(list)
    local out = {}
    for i, t in ipairs(list) do out[i] = t.name end
    return table.concat(out, ",")
end

test("round6 trainer ranks: NextRank groups the next rank's trainers and every higher rank's, the next first", function()
    local nr = TR:NextRank("fishing", 150, 150, 30, "Alliance", "Human")
    assertEqual(nr.rankName, "Expert")
    assertTrue(nr.higher, "Artisan is above Expert")
    assertEqual(#nr.groups, 2, "Expert and Artisan")
    assertEqual(nr.groups[1].rankName, "Expert"); assertEqual(nr.groups[1].cap, 225)
    assertEqual(names(nr.groups[1].trainers), "Old Man Heming")
    assertEqual(nr.groups[2].rankName, "Artisan"); assertEqual(nr.groups[2].cap, 300)
    assertEqual(names(nr.groups[2].trainers), "Nat Pagle")
    assertEqual(names(nr.trainers), "Old Man Heming", "the next rank's own list is unchanged")
    local top = TR:NextRank("fishing", 225, 225, 40, "Alliance", "Human")
    assertFalse(top.higher, "Artisan is the top")
    assertEqual(#top.groups, 1)
end)

test("round6 trainer ranks: a trainer is listed once, under the lowest rank it trains, and an emptied rank goes", function()
    local nr = TR:NextRank("blacksmithing", 75, 75, 20, "Alliance", "Human")
    assertEqual(nr.rankName, "Journeyman")
    local seen, ranks = {}, {}
    for _, g in ipairs(nr.groups) do
        ranks[#ranks + 1] = g.rankName
        for _, t in ipairs(g.trainers) do
            assertTrue(not seen[t], t.name .. " listed once")
            seen[t] = true
        end
    end
    -- The Journeyman and Expert blacksmiths both train 150: all under Journeyman; Expert is left empty.
    assertEqual(table.concat(ranks, ","), "Journeyman,Artisan")
    local therum
    for _, t in ipairs(nr.groups[1].trainers) do if t.name == "Therum Deepforge" then therum = t end end
    assertTrue(therum ~= nil, "an Expert blacksmith under Journeyman")
    assertEqual(names(nr.groups[2].trainers), "Brikk Keencraft", "the Artisan teacher under Artisan")
end)

--- The popup on `key`, learned at `rank` / `max` (the blocks' model), then everything back.
local function withRankPopup(key, rank, max, fn)
    local Bl = NS.Blocks
    local savedSource, savedFaction, savedRace, savedLevel = Bl.source, M.UnitFactionGroup, M.UnitRace, M.UnitLevel
    local savedMax = TP.MAX_HEIGHT
    local skills = { byKey = { [key] = { key = key, rank = rank, max = max, learned = true, category = "secondary" } },
                     order = { primary = {}, secondary = { key }, weapon = {}, other = {} } }
    Bl.source = function() return skills, { base = {}, spell = {}, defense = {}, utility = {} } end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.UnitRace = function() return "Human", "Human" end
    M.UnitLevel = function() return 40 end
    TP.Show(key)
    local ok, err = pcall(fn, TP.Frame())
    TP.Hide()
    TP.MAX_HEIGHT = savedMax
    Bl.source, M.UnitFactionGroup, M.UnitRace, M.UnitLevel = savedSource, savedFaction, savedRace, savedLevel
    if not ok then error(err, 0) end
end

local function headingTexts()
    local out = {}
    for i, h in ipairs(TP.Headings()) do out[i] = h:GetText() end
    return table.concat(out, ",")
end

test("round6 trainer ranks: the popup lists Expert and Artisan trainers under their headings, the intro says or higher", function()
    withRankPopup("fishing", 150, 150, function(f)
        assertEqual(f.title:GetText(), "Train: Fishing (Expert)")
        assertEqual(f.intro:GetText(), "Trainers for your faction (Alliance) who train Fishing to Expert (225) or higher:")
        assertEqual(headingTexts(), "Expert (225),Artisan (300)")
        assertEqual(names(TP.Trainers()), "Old Man Heming,Nat Pagle", "the next rank first")
        assertEqual(#TP.Cards(), 2, "one card each")
    end)
    withRankPopup("fishing", 225, 225, function(f)
        assertEqual(f.intro:GetText(), "Trainers for your faction (Alliance) who train Fishing to Artisan (300):",
            "no or higher at the top rank")
        assertEqual(headingTexts(), "Artisan (300)")
    end)
end)

test("round6 trainer ranks: nearest first inside each rank, the ranks kept in order, re-sorted each second", function()
    local function t(name, x, y)
        return { name = name, faction = "Alliance", city = "Stormwind", mapID = 1453, x = x, y = y,
                 teaches = { "fishing" }, verified = true }
    end
    local far, close, artisan = t("Far", 50, 50), t("Near", 10, 10), t("ArtisanNear", 10, 11)
    local savedNext, savedMap, savedApi = TR.NextRank, M.__map, M.C_Map
    TR.NextRank = function()
        return { rankName = "Expert", cap = 225, higher = true, trainers = { far, close },
                 groups = { { rankName = "Expert", cap = 225, trainers = { far, close } },
                            { rankName = "Artisan", cap = 300, trainers = { artisan } } } }
    end
    M.__map = { player = { mapID = 1453, x = 0.1, y = 0.12 },
                worlds = { [1453] = { instance = 0, ox = 0, oy = 0, w = 1000, h = 1000 } } }
    M.C_Map = M.__newMapApi()
    local ok, err = pcall(withRankPopup, "fishing", 150, 150, function()
        assertEqual(names(TP.Trainers()), "Near,Far,ArtisanNear", "the nearest Artisan trainer stays under Artisan")
        TP.Select(2)   -- Far
        M.__map.player = { mapID = 1453, x = 0.5, y = 0.52 }
        M.__fireTimers()
        assertEqual(names(TP.Trainers()), "Far,Near,ArtisanNear", "the player walked to Far: re-sorted inside Expert")
        assertEqual(TP.Selected().name, "Far", "the selection follows its trainer")
        assertEqual(TP.Cards()[1].dist:GetText(), NS.L["%d yd"]:format(20))
    end)
    TR.NextRank, M.__map, M.C_Map = savedNext, savedMap, savedApi
    if not ok then error(err, 0) end
end)

test("round6 trainer ranks: past the max height the cards scroll under a skin scroll bar, the wheel and the bar drive it", function()
    withRankPopup("blacksmithing", 75, 75, function(f)
        local h
        f.SetHeight = function(_, v) h = v end
        TP.Relayout()
        assertFalse(f.scrollBar:IsShown(), "everything fits: no scroll bar")
        assertEqual(select(2, TP.Scroll()), 0)
        TP.MAX_HEIGHT = 200
        TP.Relayout()
        f.SetHeight = nil
        assertEqual(h, 200, "the window stops at the max height")
        assertTrue(f.scrollBar:IsShown(), "the scroll bar shows")
        local _, most = TP.Scroll()
        assertTrue(most > 0, "the list overflows")
        f.list:GetScript("OnMouseWheel")(f.list, -1)
        assertEqual((TP.Scroll()), 40, "a wheel notch down scrolls")
        TP.SetScroll(most + 500)
        assertEqual((TP.Scroll()), most, "clamped to the overflow")
        f.scrollBar:GetScript("OnValueChanged")(f.scrollBar, 3)
        assertEqual((TP.Scroll()), 3, "the bar drives the offset")
        assertTrue(f.scrollBar.track ~= nil and f.scrollBar.thumb ~= nil, "the Journal's skinned bar")
    end)
end)
