-- tests/test_round6.lua — the owner's round-6 feedback (2026-11-13): the toasts in the cap toast's
-- look, test mode's cues on the Journal and the LDB tooltip, the header marks at one size and one
-- vertical center, the sort mark's menu and every block expanded on a new profile.
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
