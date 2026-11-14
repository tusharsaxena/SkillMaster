-- tests/test_round6.lua — the owner's round-6 feedback (2026-11-13): the toasts in the cap toast's
-- look, test mode's cues on the Journal and the LDB tooltip, the header marks at one size and one
-- vertical center, the sort mark's menu, every block expanded on a new profile, the thresholds'
-- two switches, the trainer popup's Set waypoint button and its next-rank-and-above trainers, and
-- Skill Master's own waypoint arrow (R6-11).
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

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

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
    assertTrue(sv.profiles["R6-Fresh"].bars == nil, "a profile with no bars passes this step (later steps may write it)")
    sv.profiles["R6-Off"], sv.profiles["R6-On"], sv.profiles["R6-Fresh"] = nil, nil, nil
end)

-- ── R6-6: the Set waypoint button ────────────────────────────────────────────────────────────

local TP = NS.TrainerPopup

--- The popup on `key` with the native pin API or not, then everything back.
local function withTrainerPopup(key, opts, fn)
    local saved = { C_Map = M.C_Map, UiMapPoint = M.UiMapPoint }
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    if opts.native then
        M.C_Map = { SetUserWaypoint = function() end, CanSetUserWaypointOnMap = function() return true end }
        M.UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { id = id, x = x, y = y } end }
    else
        M.C_Map, M.UiMapPoint = nil, nil
    end
    TP.Show(key)
    local ok, err = pcall(fn, TP.Frame())
    TP.Hide()
    M.C_Map, M.UiMapPoint = saved.C_Map, saved.UiMapPoint
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
    withTrainerPopup("fistWeapons", { native = true }, function(f)
        assertEqual(f.waypoint.text:GetText(), "Set waypoint", "the map pin: no provider in brackets")
        assertTrue(f.waypoint:IsEnabled(), "the native pin: enabled")
        assertTrue(f.footer == nil, "no Waypoint order footer")
        assertEqual(tipText(f.waypoint), "", "no tooltip while it works")
    end)
end)

test("round6 waypoint: a trainer without coordinates disables the button and its tooltip says why", function()
    withTrainerPopup("fishing", { native = true }, function(f)
        local t = TP.Selected()
        assertTrue(t ~= nil and t.x == nil, "the fishing trainers carry no coordinates")
        assertEqual(f.waypoint.text:GetText(), "Set waypoint", "never Set waypoint (chat)")
        assertFalse(f.waypoint:IsEnabled(), "disabled: it could only print to chat")
        assertEqual(tipText(f.waypoint), "No map coordinates for this trainer yet; Print to chat gives directions.")
        assertTrue(f.print:IsEnabled(), "Print to chat still works")
    end)
    withTrainerPopup("fistWeapons", { native = true }, function(f)
        NS.SetByPath("waypoints.method", "chat")
        TP.Select(1)
        assertFalse(f.waypoint:IsEnabled(), "Waypoint method Chat only: disabled")
        assertTrue(tipText(f.waypoint):find("Chat only", 1, true) ~= nil, "its tooltip names the setting")
    end)
    withTrainerPopup("fistWeapons", {}, function(f)
        assertFalse(f.waypoint:IsEnabled(), "no map pin: disabled")
        assertTrue(tipText(f.waypoint):find("No map pin", 1, true) ~= nil, "its tooltip says so")
    end)
end)

test("round6 waypoint: the window ends a pad under the buttons, shorter by the old footer", function()
    withTrainerPopup("fistWeapons", { native = true }, function(f)
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

-- ── R6-10: the LDB tooltip in the main window's style ───────────────────────────────────────

local Br, BP = NS.Broker, NS.BrokerPanel

local function tipSkill(key, name, category, rank, max, learned)
    return { key = key, name = name, category = category, rank = rank, max = max, modifier = 0,
             tempPoints = 0, learned = learned ~= false }
end

local function tipModels()
    local byKey = {
        tailoring = tipSkill("tailoring", "Tailoring", "primary", 120, 150),
        cooking   = tipSkill("cooking", "Cooking", "secondary", 60, 75),
        bows      = tipSkill("bows", "Bows", "weapon", 80, 110),
        swords    = tipSkill("swords", "Swords", "weapon", 0, 0, false),
        defense   = tipSkill("defense", "Defense", "other", 100, 110),
    }
    local crit = { key = "rangedCrit", label = "Ranged Crit", value = 9.1, display = "9.1%", pct = 30, markers = {} }
    local stats = { base = { crit }, spell = {}, defense = {}, utility = {} }
    return {
        model = { byKey = byKey, order = { primary = { "tailoring" }, secondary = { "cooking" },
                  weapon = { "bows", "swords" }, other = { "defense" } } },
        statsModel = stats, statIndex = { rangedCrit = crit },
        gains = { total = 3, byKey = {} },
    }
end

--- The feed's tooltip shown in `style` over a fixture source, then everything put back.
local function withFeedTip(style, fn)
    local savedSource, p = Br.source, NS.db.profile
    local savedStyle, savedHeight, savedFrom = p.tooltips.ldb.style, p.tooltips.ldb.height, p.tooltips.ldb.openFrom
    local v = tipModels()
    Br.source = function() return v end
    p.tooltips.ldb.style = style
    local ok, err = pcall(fn, v)
    Br.HideTooltip()
    Br.source = savedSource
    p.tooltips.ldb.style, p.tooltips.ldb.height, p.tooltips.ldb.openFrom = savedStyle, savedHeight, savedFrom
    p.layout.blocks.weapon.filter, p.layout.blocks.weapon.collapsed = "all", false
    if NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end
    if not ok then error(err, 0) end
end

local function panelRow(key)
    for _, row in ipairs(BP.Rows()) do
        if row.entry and row.entry.key == key then return row end
    end
    return nil
end

test("round6 ldb look: a new profile draws the Main window style on its own TOOLTIP frame, the window's size", function()
    local LD = NS.defaults.profile.tooltips.ldb
    assertEqual(LD.style, "window", "new profiles start on the window's look")
    assertEqual(LD.width, NS.defaults.profile.layout.width, "the window's default width")
    assertEqual(LD.height, NS.defaults.profile.layout.maxHeight, "the window's default height")
    withFeedTip("window", function()
        assertEqual(Br.Style(), "window")
        local f = Br.Tip()
        assertTrue(f == BP.Frame(), "the panel is the tooltip")
        assertTrue(f ~= M.GameTooltip and f ~= Br.OwnTip(), "never a GameTooltip")
        assertEqual(f:GetFrameStrata(), "TOOLTIP")
        assertEqual(BP.ContentWidth(), NS.MainWindow.ContentWidth(), "one Width draws the window's body")
        Br.OnEnter(M.UIParent)
        assertTrue(f:IsShown(), "it shows on the feed's hover")
        assertEqual(f.title:GetText(), Br.FEEDS.skills.title, "the feed's tooltip title (R7-5)")
        assertEqual(f.footer:GetText(), Br.FooterText(), "the footer hints stay")
    end)
    withFeedTip("classic", function()
        assertEqual(Br.Style(), "classic")
        assertTrue(Br.Tip() ~= BP.Frame(), "Classic keeps the tooltip lines")
    end)
end)

test("round6 ldb look: the window's headers and rows, the bar with its text inside and the mark at its right", function()
    withFeedTip("window", function()
        Br.OnEnter(M.UIParent)
        local ids = {}
        for _, h in ipairs(BP.Headers()) do ids[#ids + 1] = h.id end
        assertEqual(table.concat(ids, ","), "primary,secondary,weapon,other", "the shown sections, in the window's order")
        local row = panelRow("tailoring")
        assertTrue(row ~= nil, "a window row")
        assertTrue(row.bar:IsShown(), "the shared bar")
        assertTrue(row.act:IsShown(), "the row's mark")
        assertEqual(row.baseH, NS.db.profile.bars.rowHeight, "the window's row height")
        assertTrue(row:GetParent() == BP.Frame().content, "in the panel's scrolled body")
        assertTrue(panelRow("rangedCrit") == nil, "no stats in the skills feed (R6-9)")
        Br.OnEnter(M.UIParent, "stats")
        assertTrue(panelRow("rangedCrit") ~= nil, "the stats feed draws the stat blocks")
        Br.OnEnter(M.UIParent)
    end)
end)

test("round6 ldb look: a block collapsed in the window is a collapsed header here, and nothing on a header acts", function()
    withFeedTip("window", function()
        NS.db.profile.layout.blocks.weapon.collapsed = true
        Br.OnEnter(M.UIParent)
        local weapon
        for _, h in ipairs(BP.Headers()) do if h.id == "weapon" then weapon = h end end
        assertTrue(weapon ~= nil and weapon.collapsed == true, "the header says collapsed (chevron right)")
        assertTrue(panelRow("bows") == nil, "and draws no rows")
        assertFalse(weapon.detach:IsShown(), "no detach mark")
        assertFalse(weapon.restore:IsShown(), "no restore mark")
        -- A recorder on the pooled header's EnableMouse, then the tooltip drawn again.
        local calls = {}
        rawset(weapon, "EnableMouse", function(_, on) calls[#calls + 1] = on end)
        Br.OnEnter(M.UIParent)
        rawset(weapon, "EnableMouse", nil)
        assertEqual(calls[1], false, "the header takes no click")
    end)
end)

test("round6 ldb look: a row's left click opens and its right click opens the row menu", function()
    withFeedTip("window", function()
        -- Round 8, R8-1: Full row opens as the go icon does (both modes: test_round7, test_round8).
        NS.db.profile.tooltips.ldb.openFrom = "row"
        Br.OnEnter(M.UIParent)
        local saved, got = Br.OpenRow, {}
        local savedOpen, opened = NS.Interact.Open, {}
        Br.OpenRow = function(r, button) got[#got + 1] = r.kind .. ":" .. r.key .. ":" .. tostring(button) end
        NS.Interact.Open = function(r) opened[#opened + 1] = r.entry.key end
        local row = panelRow("tailoring")
        local ok, err = pcall(function()
            row:__fire("OnClick", "LeftButton")
            row:__fire("OnClick", "RightButton")
        end)
        Br.OpenRow, NS.Interact.Open = saved, savedOpen
        if not ok then error(err, 0) end
        assertEqual(table.concat(opened, ","), "tailoring", "the left click opens what the go icon opens")
        assertEqual(table.concat(got, ","), "skill:tailoring:RightButton", "the right click opens the row menu")
    end)
end)

test("round6 ldb look: the window's weapon filter and sort reach both styles", function()
    withFeedTip("window", function()
        NS.db.profile.layout.blocks.weapon.filter = "learned"
        Br.OnEnter(M.UIParent)
        assertTrue(panelRow("bows") ~= nil and panelRow("swords") == nil, "Main window: Learned leaves Swords out")
    end)
    withFeedTip("classic", function()
        NS.db.profile.layout.blocks.weapon.filter = "learned"
        local lines = {}
        local tip = M.CreateFrame("GameTooltip", "SkillMasterR6Tip", M.UIParent)
        function tip:AddLine(t) lines[#lines + 1] = t end
        function tip:AddDoubleLine(l) lines[#lines + 1] = l end
        function tip:NumLines() return #lines end
        Br.FillTooltip(tip)
        local text = table.concat(lines, "\n")
        assertTrue(text:find("Bows", 1, true) ~= nil and text:find("Swords", 1, true) == nil, "Classic too: " .. text)
    end)
end)

test("round6 ldb look: past its Height the body scrolls, by the wheel and by the skin's scroll bar", function()
    withFeedTip("window", function()
        Br.OnEnter(M.UIParent)
        local f = BP.Frame()
        assertEqual(select(2, BP.Scroll()), 0, "the default Height fits the fixture")
        assertFalse(f.scrollBar:IsEnabled(), "while it fits the bar is drawn disabled (round 7, R7-4)")
        NS.db.profile.tooltips.ldb.height = 120
        Br.OnEnter(M.UIParent)
        local _, most = BP.Scroll()
        assertTrue(most > 0, "the body overflows")
        assertTrue(f.scrollBar:IsShown(), "the scroll bar shows")
        f.list:GetScript("OnMouseWheel")(f.list, -1)
        assertEqual((BP.Scroll()), math.min(40, most), "a wheel notch scrolls")
        f.scrollBar:GetScript("OnValueChanged")(f.scrollBar, 1)
        assertEqual((BP.Scroll()), 1, "the bar drives the offset")
    end)
end)

test("round6 ldb look: the row menu draws above the tooltip in both styles, and goes back as it hides", function()
    for _, style in ipairs({ "window", "classic" }) do
        withFeedTip(style, function()
            Br.OnEnter(M.UIParent)
            local tip = Br.Tip()
            local m = Br.RowMenu({ kind = "skill", key = "tailoring" }, tip)
            assertTrue(m ~= nil, style .. ": the menu opens")
            assertEqual(m:GetFrameStrata(), "TOOLTIP", style .. ": in the tooltip's strata")
            assertTrue(m:GetFrameLevel() > tip:GetFrameLevel(), style .. ": above the tooltip")
            assertTrue(Br.MenuOpen(), style .. ": the tooltip stays up while the menu is open")
            m:Hide()
            m:__fire("OnHide")
            assertEqual(m:GetFrameStrata(), "FULLSCREEN_DIALOG", style .. ": the library's strata again")
            assertFalse(Br.MenuOpen())
        end)
    end
end)

test("round6 ldb look: the classic-only rows are dimmed in the Main window style, width and height in Classic", function()
    local function row(path) return NS.FindSchemaRow(path) end
    withFeedTip("window", function()
        assertTrue(row("tooltips.ldb.fontSize").disabledIf(), "font size: Classic only")
        assertTrue(row("tooltips.ldb.barWidth").disabledIf(), "bar width: Classic only")
        assertTrue(row("broker.tooltip.skin").disabledIf(), "the skin switch: Classic only")
        assertFalse(row("tooltips.ldb.width").disabledIf(), "width: this style's")
    end)
    withFeedTip("classic", function()
        assertTrue(row("tooltips.ldb.height").disabledIf(), "height: the Main window style's")
        assertFalse(row("tooltips.ldb.fontSize").disabledIf())
    end)
end)

test("round6 ldb look: schemaVersion 8 keeps every stored profile on Classic; a fresh install starts on it new", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R6-Old"] = { bars = { height = 15 } }
    sv.profiles["R6-Chose"] = { tooltips = { ldb = { style = "window" } } }
    sv.profiles["R6-Empty"] = {}
    NS.db.global.schemaVersion = 7
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 8, "step 8 is in the ladder")
    assertEqual(sv.profiles["R6-Old"].tooltips.ldb.style, "classic", "an existing profile keeps today's look")
    assertEqual(sv.profiles["R6-Chose"].tooltips.ldb.style, "window", "a stored style is kept")
    assertEqual(sv.profiles["R6-Empty"].tooltips.ldb.style, "classic", "an empty stored profile is an existing one (review)")
    -- A fresh install: no stamp was ever stored, so the step leaves its profiles to the new default.
    sv.profiles["R6-New"] = { bars = { height = 15 } }
    NS.db.global.schemaVersion = 0
    NS:RunMigrations()
    assertTrue(sv.profiles["R6-New"].tooltips == nil, "a fresh install starts on the Main window style")
    for _, k in ipairs({ "R6-Old", "R6-Chose", "R6-Empty", "R6-New" }) do sv.profiles[k] = nil end
end)

-- ── R6-9: the Skill Master Stats feed ────────────────────────────────────────────────────────

local function statsTip()
    local lines = {}
    local tip = M.CreateFrame("GameTooltip", "SkillMasterR6StatsTip", M.UIParent)
    function tip:AddLine(t) lines[#lines + 1] = t end
    function tip:AddDoubleLine(l, r) lines[#lines + 1] = l .. " " .. tostring(r) end
    function tip:NumLines() return #lines end
    return tip, lines
end

test("round6 stats feed: a second data source, its tooltip the four stat blocks, its clicks the skills feed's", function()
    local obj = M.__ldbObjects[Br.STATS_NAME]
    assertTrue(obj ~= nil and obj == Br.StatsObject(), "Skill Master Stats is registered")
    assertEqual(obj.type, "data source")
    assertEqual(obj.label, "Skill Master Stats")
    assertTrue(obj.OnClick == Br.OnClick, "the same label clicks")
    assertEqual(table.concat(Br.STAT_SECTIONS, ","), "stats_base,stats_spell,stats_defense,stats_utility")
    for _, id in ipairs(Br.STAT_SECTIONS) do
        assertEqual(NS.defaults.profile.broker.tooltip.sections[id], true, id .. " on by default")
    end
    withFeedTip("window", function()
        obj.OnEnter(M.UIParent)
        assertEqual(Br.Feed(), "stats")
        assertEqual(BP.Frame().title:GetText(), "Skill Master \194\183 Stats")
        local ids = {}
        for _, h in ipairs(BP.Headers()) do ids[#ids + 1] = h.id end
        assertEqual(table.concat(ids, ","), "stats_base", "the stat blocks with rows, no skill block")
        assertTrue(panelRow("tailoring") == nil, "no skills in the stats feed")
        M.__ldbObjects[Br.NAME].OnEnter(M.UIParent)
        assertEqual(Br.Feed(), "skills", "the skills feed's hover takes it back")
    end)
    withFeedTip("classic", function()
        local tip, lines = statsTip()
        Br.FillTooltip(tip, "stats")
        local text = table.concat(lines, "\n")
        assertTrue(text:find("Skill Master \194\183 Stats", 1, true) ~= nil and text:find("Ranged Crit", 1, true) ~= nil, text)
        assertTrue(text:find("Tailoring", 1, true) == nil, "Classic: no skills either")
        NS.db.profile.broker.tooltip.hiddenStats = { rangedCrit = true }   -- the Rows page's LDB tooltip eye
        tip, lines = statsTip()
        Br.FillTooltip(tip, "stats")
        NS.db.profile.broker.tooltip.hiddenStats = {}
        assertTrue(table.concat(lines, "\n"):find("Ranged Crit", 1, true) == nil, "a stat's tooltip Hide reaches the stats feed")
        Br.FillTooltip(statsTip(), "skills")
    end)
end)

test("round6 stats feed: a stat row's menu pins its stat to the feed per character; with none it reads Stats", function()
    local crit = tipModels().statIndex.rangedCrit
    NS.bus:SendMessage(NS.MSG.STATS_UPDATED, { base = { crit }, spell = {}, defense = {}, utility = {} })
    local saved = NS.db.char.pinnedStat
    NS.db.char.pinnedStat = false
    Br.Refresh()
    assertEqual(Br.StatsText(), "Stats", "nothing pinned")
    local pin
    for _, r in ipairs(NS.Interact.MenuRows({ kind = "stat", entry = crit })) do
        if r.value == "pin" then pin = r end
    end
    assertTrue(pin ~= nil and pin.label == "Pin to the broker feed", "the stat row menu offers the pin")
    assertFalse(pin.selected(), "not pinned yet")
    pin.onClick()
    assertEqual(NS.db.char.pinnedStat, "rangedCrit", "stored per character")
    assertEqual(Br.StatsText(), "Ranged Crit 9.1%", "the feed shows the pinned stat at once")
    assertTrue(pin.selected(), "ticked")
    assertTrue(NS.db.char.pinned ~= "rangedCrit", "the skills feed's pin is apart")
    pin.onClick()
    assertEqual(Br.StatsText(), "Stats", "a second click unpins")
    NS.db.char.pinnedStat = saved
    Br.Refresh()
end)

test("round6 stats feed: schemaVersion 9 drops a stored Stats section switch, the stat blocks' switches answer", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R6-Stats"] = { broker = { tooltip = { sections = { stats = true, weapon = false } } } }
    sv.profiles["R6-Fresh9"] = {}
    NS.db.global.schemaVersion = 8
    NS:RunMigrations()
    assertTrue(NS.SCHEMA_VERSION >= 9, "step 9 is in the ladder")
    local sections = sv.profiles["R6-Stats"].broker.tooltip.sections
    assertTrue(sections.stats == nil, "the old switch goes")
    assertEqual(sections.weapon, false, "the rest is kept")
    -- Step 9 alone: a later step (12, R7-2) writes an existing profile's icon default.
    assertTrue(sv.profiles["R6-Fresh9"].broker == nil, "a fresh profile passes step 9 through")
    sv.profiles["R6-Stats"], sv.profiles["R6-Fresh9"] = nil, nil
end)

-- ── R6 review: the fixes from the round's review ─────────────────────────────────────────────

test("round6 review: the Main window style's test strip opens its menu above the tooltip, and it ends test mode", function()
    withFeedTip("window", function()
        withTestMode(function()
            Br.OnEnter(M.UIParent)
            local panel = BP.Frame()
            local strip = panel.strip
            assertTrue(strip ~= nil and strip:IsShown(), "the strip shows in test mode")
            strip:__fire("OnMouseUp", "RightButton")
            local m = BP.StripMenu()
            assertTrue(m ~= nil and m:IsShown(), "a right-click opens the strip's menu")
            assertEqual(m:GetFrameStrata(), "TOOLTIP", "in the tooltip's strata")
            assertTrue(m:GetFrameLevel() > panel:GetFrameLevel(), "above the tooltip")
            assertTrue(Br.MenuOpen(), "the tooltip stays up while it is open")
            local rows = BP.StripMenuRows()
            assertEqual(#rows, 1)
            assertEqual(rows[1].value, "END_TEST")
            rows[1].onClick(rows[1].value, rows[1])
            assertFalse(NS.IsTestMode(), "End test ends test mode")
            m:Hide()
            m:__fire("OnHide")
            assertFalse(Br.MenuOpen())
            -- The kit's Hide fires no OnHide: release the test-mode rows (their bar timers) as the client does.
            Br.HideTooltip()
            panel:__fire("OnHide")
        end)
    end)
end)

test("round6 review: the Set waypoint button keeps the skin's hover look beside its own tooltip", function()
    withTrainerPopup("fistWeapons", { native = true }, function(f)
        local function rgb(b) local r, g, bl = b.text:GetTextColor() return ("%.3f,%.3f,%.3f"):format(r, g, bl) end
        f.waypoint:GetScript("OnLeave")(f.waypoint)   -- the rest look (the mock fires no OnEnable)
        local rest = rgb(f.waypoint)
        f.waypoint:GetScript("OnEnter")(f.waypoint)
        assertTrue(rgb(f.waypoint) ~= rest, "the hover repaints the label, as Print to chat's does")
        f.waypoint:GetScript("OnLeave")(f.waypoint)
        assertEqual(rgb(f.waypoint), rest, "and leaving puts it back")
        f.print:GetScript("OnLeave")(f.print)
        local pRest = rgb(f.print)
        f.print:GetScript("OnEnter")(f.print)
        assertTrue(rgb(f.print) ~= pRest, "Print to chat's hover, for the comparison")
        f.print:GetScript("OnLeave")(f.print)
    end)
end)

test("round6 review: schemaVersion 8 keeps an empty stored profile on Classic too; only a fresh install starts new", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R6-Untouched"] = {}
    NS.db.global.schemaVersion = 7
    NS:RunMigrations()
    local p = sv.profiles["R6-Untouched"]
    assertEqual(p.tooltips and p.tooltips.ldb and p.tooltips.ldb.style, "classic", "an empty stored profile is an existing one")
    sv.profiles["R6-Untouched"] = {}
    NS.db.global.schemaVersion = 0
    NS:RunMigrations()
    assertTrue(sv.profiles["R6-Untouched"].tooltips == nil, "a fresh install's profile starts on the Main window style")
    sv.profiles["R6-Untouched"] = nil
end)

test("round6 review: schemaVersion 10 keeps Spell and Defense collapsed on a profile from before R6-8", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R6-Old10"] = { bars = { height = 15 } }
    sv.profiles["R6-Open10"] = { layout = { blocks = { stats_spell = { collapsed = false, order = 3 } } } }
    sv.profiles["R6-Empty10"] = {}
    NS.db.global.schemaVersion = 6
    NS:RunMigrations()
    assertTrue(NS.SCHEMA_VERSION >= 10, "step 10 is in the ladder")
    local old = sv.profiles["R6-Old10"].layout.blocks
    assertEqual(old.stats_spell.collapsed, true, "Spell stays collapsed, the old default")
    assertEqual(old.stats_defense.collapsed, true, "Defense too")
    assertTrue(old.stats_base == nil and old.weapon == nil, "no other block is written")
    local open = sv.profiles["R6-Open10"].layout.blocks
    assertEqual(open.stats_spell.collapsed, false, "an expanded block the player chose stays expanded")
    assertEqual(open.stats_spell.order, 3, "and keeps the rest")
    assertEqual(open.stats_defense.collapsed, true)
    assertEqual(sv.profiles["R6-Empty10"].layout.blocks.stats_spell.collapsed, true, "an empty stored profile is existing")
    -- A build already on the R6-8 default (stamp 7 or later) and a fresh install pass through.
    for _, from in ipairs({ 7, 9, 0 }) do
        sv.profiles["R6-Later10"] = { bars = { height = 15 } }
        NS.db.global.schemaVersion = from
        NS:RunMigrations()
        assertTrue(sv.profiles["R6-Later10"].layout == nil, "from " .. from .. ": nothing written")
    end
    for _, k in ipairs({ "R6-Old10", "R6-Open10", "R6-Empty10", "R6-Later10" }) do sv.profiles[k] = nil end
end)

-- ── R6-11: Skill Master's own waypoint arrow ─────────────────────────────────────────────────

local WA, Wp = NS.WaypointArrow, NS.Waypoints

--- A trainer at (50, 50) on map 1453, whose world rect is 1000 x 1000 yards from the origin, the
--- native pin API recorded, and the player at `player` (0..1 on 1453); then all back.
local function withArrow(player, fn)
    local saved = { C_Map = M.C_Map, map = M.__map, UiMapPoint = M.UiMapPoint,
                    C_SuperTrack = M.C_SuperTrack, facing = M.__facing, wp = NS.db.profile.waypoints }
    local rec = { set = 0, cleared = 0, superTrack = {}, has = true }
    M.__map = { player = player, worlds = { [1453] = { instance = 0, ox = 0, oy = 0, w = 1000, h = 1000 } } }
    M.C_Map = M.__newMapApi()
    M.C_Map.SetUserWaypoint = function(point) rec.set = rec.set + 1 rec.point = point rec.has = true end
    M.C_Map.CanSetUserWaypointOnMap = function() return true end
    M.C_Map.ClearUserWaypoint = function() rec.cleared = rec.cleared + 1 rec.has = false end
    M.C_Map.HasUserWaypoint = function() return rec.has end
    M.C_Map.GetUserWaypoint = function() return rec.point end
    M.UiMapPoint = { CreateFromCoordinates = function(mapID, x, y)
        return { uiMapID = mapID, position = M.CreateVector2D(x, y) } end }
    M.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(v) rec.superTrack[#rec.superTrack + 1] = v end }
    M.__facing = 0
    NS.db.profile.waypoints = { method = "auto", announce = false, arrow = true, arrowScale = 1,
                                arrowFrame = { point = false } }
    local trainer = { name = "Woo Ping", faction = "Alliance", city = "Stormwind", subzone = "Trade District",
                      mapID = 1453, x = 50, y = 50, teaches = { "swords" }, verified = true }
    local ok, err = pcall(fn, trainer, rec)
    WA.StandDown()
    M.C_Map, M.__map, M.UiMapPoint = saved.C_Map, saved.map, saved.UiMapPoint
    M.C_SuperTrack, M.__facing, NS.db.profile.waypoints = saved.C_SuperTrack, saved.facing, saved.wp
    if not ok then error(err, 0) end
end

local function tick() WA.Frame():__fire("OnUpdate", WA.THROTTLE + 0.001) end

-- The arrow's regions by role (round 8, R8-5: the frame is LibKa0s-WaypointArrow-1.0's): the body
-- the color tints (the old fill), the untinted overlay, raised's shadow and the distance text.
local function parts()
    local f = WA.Frame()
    local box = f:GetChildren()
    local out = { frame = f }
    for _, r in ipairs({ box:GetRegions() }) do
        local _, sub = r:GetDrawLayer()
        if sub == 0 then out.shadow = r elseif sub == 1 then out.body = r elseif sub == 2 then out.overlay = r end
    end
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then out.text = r end
    end
    return out
end

test("round6 arrow: the rotation is bearing minus facing, counter-clockwise from north (x north, y west)", function()
    -- Round 8, R8-5: the math is the library's now; the same cases hold it.
    local Rot = WA.lib.Rotation
    assertTrue(near(Rot(0, 0, 100, 0, 0), 0), "target due north, facing north: straight ahead")
    assertTrue(near(Rot(0, 0, 0, 100, 0), math.pi / 2), "target due west: a quarter turn left")
    assertTrue(near(Rot(0, 0, 0, -100, 0), -math.pi / 2), "target due east: a quarter turn right")
    assertTrue(near(Rot(0, 0, 100, 0, math.pi / 2), -math.pi / 2), "facing west, target north: to the right")
    assertTrue(near(math.abs(Rot(0, 0, -100, 0, 0)), math.pi), "target due south: behind")
    assertTrue(near(Rot(0, 0, 100, 0, 2 * math.pi - 0.1), 0.1), "kept inside one turn")
    assertEqual(Rot(0, 0, 100, 0, nil), nil, "no facing: no rotation")
    local restore = T.kit.installSecretValue()
    local ok, got = pcall(Rot, 0, 0, 100, 0, T.kit.secret(1))
    restore()
    assertTrue(ok, "a secret facing must not raise: " .. tostring(got))
    assertEqual(got, nil, "a secret facing is no facing")
end)

test("round6 arrow: the fill blends from the skin's accent at 300 yd to its sem.good at 30 yd", function()
    -- Round 8, R8-5: "Use the skin's colors" on (the default) draws these two, through the library.
    local far, good = NS.Bar.Color("text.accent"), NS.Bar.Color("sem.good")
    local Lib = WA.lib
    local cFar, cNear = WA.Instance():Colors()
    local function blend(yards) return { Lib.Mix(cFar, cNear, Lib.Fade(yards)) } end
    for i = 1, 3 do
        assertTrue(near(cFar[i], far[i]) and near(cNear[i], good[i]), "the skin's accent and sem.good")
        assertTrue(near(blend(300)[i], far[i]) and near(blend(4000)[i], far[i]), "the accent at 300 yd or more")
        assertTrue(near(blend(30)[i], good[i]) and near(blend(3)[i], good[i]), "sem.good at 30 yd or less")
        assertTrue(near(blend(165)[i], (far[i] + good[i]) / 2), "halfway between at 165 yd")
    end
end)

test("round6 arrow: a waypoint sets the native pin unsuper-tracked and shows the arrow on it", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        assertEqual(Wp:Set(t), "native")
        assertEqual(rec.set, 1, "the native pin is still set")
        assertEqual(rec.superTrack[#rec.superTrack], false, "and not super-tracked: the game's arrow goes away")
        assertTrue(WA.IsShown(), "Skill Master's arrow shows")
        assertEqual(WA.Target(), t)
        local p = parts()
        local f = p.frame
        assertTrue(f:GetScript("OnUpdate") ~= nil, "its OnUpdate runs while shown")
        assertEqual(f:GetFrameStrata(), "MEDIUM")
        assertTrue(f:IsClampedToScreen(), "clamped")
        assertEqual(p.text:GetText(), NS.L["%d yd"]:format(100), "the yards under the art")
        assertTrue(p.body:IsShown() and near(p.body:GetRotation(), 0), "target due north, facing north: up")
        -- Round 8, R8-5: the library's Raised look by default, its art under libs\LibKa0s.
        local media = "Interface\\AddOns\\SkillMaster\\libs\\LibKa0s\\media\\waypoint\\"
        assertEqual(p.body:GetTexture(), media .. "arrow-fill", "the tinted body")
        assertEqual(p.overlay:GetTexture(), media .. "raised-overlay", "Raised's overlay")
        assertTrue(p.shadow:IsShown(), "and its shadow")
    end)
end)

test("round6 arrow: Show Skill Master's arrow off keeps the old behavior", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        NS.db.profile.waypoints.arrow = false
        assertEqual(Wp:Set(t), "native")
        assertEqual(rec.superTrack[#rec.superTrack], true, "the native pin is super-tracked")
        assertFalse(WA.IsShown(), "no arrow of ours")
        NS.db.profile.waypoints.arrow = true
        assertEqual(Wp:Set(t), "native")
        assertTrue(WA.IsShown())
    end)
end)

test("round6 arrow: the arrow follows the player's facing and place, throttled, and turns color by distance", function()
    withArrow({ mapID = 1453, x = 0.5, y = 0.4 }, function(t)
        Wp:Set(t)
        local p = parts()
        local f = p.frame
        assertTrue(near(p.body:GetRotation(), math.pi / 2), "target due west: a quarter turn left")
        M.__facing = math.pi / 2
        f:__fire("OnUpdate", WA.THROTTLE / 2)
        assertTrue(near(p.body:GetRotation(), math.pi / 2), "inside the throttle: not re-measured")
        f:__fire("OnUpdate", WA.THROTTLE / 2 + 0.001)
        assertTrue(near(p.body:GetRotation(), 0), "facing west now: straight ahead")
        M.__map.player = { mapID = 1453, x = 0.5, y = 0.48 }   -- 20 yd east of the trainer
        tick()
        assertEqual(p.text:GetText(), NS.L["%d yd"]:format(20))
        local c, good = { p.body:GetVertexColor() }, NS.Bar.Color("sem.good")
        assertTrue(near(c[1], good[1]) and near(c[2], good[2]) and near(c[3], good[3]), "sem.good within 30 yd")
    end)
end)

test("round6 arrow: no facing hides the art and keeps the distance; no distance shows the name alone, dim", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t)
        Wp:Set(t)
        local p = parts()
        M.__facing = nil
        tick()
        assertFalse(p.body:IsShown() or p.overlay:IsShown() or p.shadow:IsShown(), "no facing: no art")
        assertEqual(p.text:GetText(), NS.L["%d yd"]:format(100), "the distance stays")
        local restore = T.kit.installSecretValue()
        M.__facing = T.kit.secret(1)
        local ok, err = pcall(tick)
        restore()
        assertTrue(ok, "a secret facing must not raise: " .. tostring(err))
        assertFalse(p.body:IsShown(), "a secret facing: no art")
        M.__facing = 0
        M.__map.player = nil   -- an instance: the client knows no map
        tick()
        assertFalse(p.body:IsShown(), "no distance: no art")
        assertEqual(p.text:GetText(), "Woo Ping", "the trainer's name alone")
        local c, muted = { p.text:GetTextColor() }, NS.Bar.Color("text.muted")
        assertTrue(near(c[1], muted[1]) and near(c[2], muted[2]) and near(c[3], muted[3]), "dim, in the muted role")
        assertTrue(WA.IsShown(), "the arrow stays up")
    end)
end)

test("round6 arrow: within 5 yd the arrow hides, the pin clears and chat says you have arrived", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        Wp:Set(t)
        local before = #M.__printed()
        M.__map.player = { mapID = 1453, x = 0.5, y = 0.504 }   -- 4 yd away
        tick()
        assertFalse(WA.IsShown(), "arrived: the arrow hides")
        assertEqual(rec.cleared, 1, "the native pin is cleared")
        assertTrue(WA.Frame():GetScript("OnUpdate") == nil, "its OnUpdate is off")
        local all = M.__printed()
        assertTrue(#all > before and tostring(all[#all]):find("You have arrived: Woo Ping", 1, true) ~= nil,
            "the arrival line")
    end)
end)

test("round6 arrow: right-click clears the waypoint; a cleared or replaced native pin hides the arrow", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        Wp:Set(t)
        WA.Frame():__fire("OnMouseUp", "RightButton")
        assertFalse(WA.IsShown(), "right-click hides it")
        assertEqual(rec.cleared, 1, "and clears the native pin")
        Wp:Set(t)
        M.__fireEvent("USER_WAYPOINT_UPDATED")
        assertTrue(WA.IsShown(), "our own pin's update keeps it")
        rec.point = M.UiMapPoint.CreateFromCoordinates(1453, 0.1, 0.1)
        M.__fireEvent("USER_WAYPOINT_UPDATED")
        assertFalse(WA.IsShown(), "a pin placed elsewhere hides it")
        Wp:Set(t)
        rec.has = false
        M.__fireEvent("USER_WAYPOINT_UPDATED")
        assertFalse(WA.IsShown(), "a pin cleared elsewhere hides it")
        local other = { name = "Other", mapID = 1453, x = 10, y = 10 }
        Wp:Set(t)
        Wp:Set(other)
        assertEqual(WA.Target(), other, "a new trainer waypoint retargets it")
    end)
end)

test("round6 arrow: a drag saves the point on the profile; the profile's lock refuses it", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t)
        Wp:Set(t)
        local f = WA.Frame()
        local placed
        f.GetPoint = function() return "TOPLEFT", M.UIParent, "TOPLEFT", 40, -60 end
        f.SetPoint = function(_, point) placed = point end
        f:__fire("OnDragStart")
        f:__fire("OnDragStop")
        local p = NS.db.profile.waypoints.arrowFrame.point
        assertEqual(p.point, "TOPLEFT"); assertEqual(p.x, 40); assertEqual(p.y, -60)
        local savedLock = NS.db.profile.locked
        NS.db.profile.locked = true
        f.__userPlaced = nil
        f:__fire("OnDragStart")
        NS.db.profile.locked = savedLock
        assertTrue(not f.__userPlaced, "locked: the drag never starts")
        f:Hide()
        WA.Show(t)
        f.GetPoint, f.SetPoint = nil, nil
        assertEqual(placed, "TOPLEFT", "the saved point is where it shows again")
    end)
end)

test("round6 arrow: test mode shows it on a sample trainer at a sample distance, writes nothing, and takes it down", function()
    withArrow(nil, function()
        local before = NS.db.profile.waypoints.arrowFrame.point
        WA.ShowTest()
        assertTrue(WA.IsShown(), "the sample arrow shows")
        local sample = WA.Target()
        assertTrue(sample ~= nil and sample.mapID ~= nil and sample.x ~= nil, "on a sample trainer with coordinates")
        local p = parts()
        local f = p.frame
        tick()
        assertEqual(p.text:GetText(), NS.L["%d yd"]:format(WA.lib.SAMPLE_YARDS), "at the sample distance")
        assertTrue(p.body:IsShown() and near(p.body:GetRotation(), WA.lib.SAMPLE_ROTATION), "at the sample angle")
        assertEqual(NS.db.profile.waypoints.arrowFrame.point, before, "nothing written")
        WA.HideTest()
        assertFalse(WA.IsShown(), "test mode's end takes it down")
        assertTrue(f:GetScript("OnUpdate") == nil, "its OnUpdate off")
    end)
end)

test("round6 arrow: /sm test raises and lowers the arrow with test mode's other surfaces", function()
    withArrow(nil, function()
        NS.ToggleTestMode()
        local on = WA.IsShown()
        NS.ToggleTestMode()
        assertTrue(on, "test mode on: the arrow shows")
        assertFalse(WA.IsShown(), "test mode off: it hides")
    end)
end)

test("round6 arrow: turning the arrow off hands the pin back to the game's arrow; the scale applies at once", function()
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        Wp:Set(t)
        local f, scale = WA.Frame(), nil
        f.SetScale = function(_, v) scale = v end
        NS.SetByPath("waypoints.arrowScale", 1.5)
        f.SetScale = nil
        assertEqual(scale, 1.5, "the scale at once")
        NS.SetByPath("waypoints.arrow", false)
        assertFalse(WA.IsShown(), "off: the arrow hides")
        assertEqual(rec.superTrack[#rec.superTrack], true, "and the native pin is super-tracked again")
    end)
end)

-- ── R6-11 review ─────────────────────────────────────────────────────────────────────────────

test("round6 arrow review: a hide and show of its parent (Alt-Z, a cinematic) leaves the arrow ticking", function()
    -- red under: an OnHide that removes the OnUpdate, with no OnShow putting it back. The client
    -- fires OnHide on a shown child when UIParent hides; the frame is still IsShown() after.
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t)
        Wp:Set(t)
        local p = parts()
        local f = p.frame
        f:__fire("OnHide")
        f:__fire("OnShow")
        assertTrue(f:GetScript("OnUpdate") ~= nil, "the OnUpdate still runs once the parent is back")
        M.__facing = math.pi / 2
        tick()
        assertTrue(near(p.body:GetRotation(), -math.pi / 2), "and the arrow still turns with the player")
    end)
end)

-- A scratch profile seeded with `waypoints` (the skin picker already closed); the active profile
-- comes back whatever happens.
local function withWaypointProfile(name, waypoints, fn)
    local db = NS.db
    local before = db:GetCurrentProfile()
    db.sv.profiles[name] = { skin = { pickerSeen = true }, waypoints = waypoints }
    local ok, err = pcall(fn, db)
    db:SetProfile(before)
    db.sv.profiles[name] = nil
    NS.HideSkinPicker()
    if not ok then error(err, 0) end
end

test("round6 arrow review: a profile switch to one with the arrow off hands the pin back to the game's arrow", function()
    -- red under: a reloadProfile that never calls NS.WaypointArrow.ApplySettings.
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        Wp:Set(t)
        assertTrue(WA.IsShown())
        withWaypointProfile("R6-ArrowOff", { arrow = false }, function(db)
            db:SetProfile("R6-ArrowOff")
            assertFalse(WA.IsShown(), "the new profile's arrow is off: ours hides")
            assertEqual(rec.superTrack[#rec.superTrack], true, "and the native pin is super-tracked")
        end)
    end)
end)

test("round6 arrow review: a profile switch re-applies the shown arrow's scale and position", function()
    -- red under: a reloadProfile that never calls NS.WaypointArrow.ApplySettings, or an
    -- ApplySettings that sets the scale but not the point.
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t)
        Wp:Set(t)
        local f = WA.Frame()
        local scale, placed
        f.SetScale = function(_, v) scale = v end
        f.SetPoint = function(_, point) placed = point end
        local ok, err = pcall(withWaypointProfile, "R6-ArrowPlace",
            { arrow = true, arrowScale = 2,
              arrowFrame = { point = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 40, y = -60 } } },
            function(db)
                db:SetProfile("R6-ArrowPlace")
                assertTrue(WA.IsShown(), "the arrow stays up")
                assertEqual(scale, 2, "the new profile's scale")
                assertEqual(placed, "TOPLEFT", "and its saved point")
            end)
        f.SetScale, f.SetPoint = nil, nil
        if not ok then error(err, 0) end
    end)
end)

test("round6 arrow review: right-clicking test mode's sample over a real waypoint brings the real arrow back", function()
    -- red under: a Clear that drops the sample and takes the frame down with the real target still
    -- set, so HideTest (state.test already nil) returns before pointing at it again.
    withArrow({ mapID = 1453, x = 0.4, y = 0.5 }, function(t, rec)
        Wp:Set(t)
        WA.ShowTest()
        assertTrue(WA.Target() ~= t, "the sample shows over the real waypoint")
        WA.Frame():__fire("OnMouseUp", "RightButton")
        assertEqual(rec.cleared, 0, "the sample's right-click clears no pin")
        assertTrue(WA.IsShown(), "the real waypoint's arrow comes back")
        assertEqual(WA.Target(), t, "pointing at the real trainer")
        WA.HideTest()
        assertTrue(WA.IsShown() and WA.Target() == t, "test mode's end keeps it")
        assertTrue(WA.Frame():GetScript("OnUpdate") ~= nil, "and ticking")
    end)
end)
