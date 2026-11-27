-- tests/test_r5_feedback.lua — the owner's round 5 feedback on the six windows and brokers (items R5-SM-01..07
-- of Ka0sAddonsCommonTasks docs/2026-11-26-OWNER_FEEDBACK_ROUND5/00_PLAN.md): no hint tooltip on a fold chevron,
-- the whole header row folds, a pin mark on each pinned row, an icon per display broker, `/cl toggle` showing
-- or hiding every window, no profession listed twice, and a session with every window open raising nothing.
-- Test mode's sample fills every window and feed, so each case reads no live client state.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Br, BP = NS.Broker, NS.BrokerPanel

-- The client's standing names, as tests/test_reputations.lua mocks them.
local LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

--- `fn` with test mode on (the sample character in every window and feed); everything put back after.
local function withSample(fn)
    local saved = { M.GetText, M.UnitSex, M.UnitFactionGroup }
    M.GetText = function(key) return LABELS[tonumber(tostring(key):match("(%d+)$"))] end
    M.UnitSex = function() return 2 end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    local folds, char = NS.db.profile.tooltips.ldb.folds, NS.db.char.fold
    NS.db.profile.tooltips.ldb.folds, NS.db.char.fold = { blocks = {}, nodes = {} }, {}
    if not NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    -- Test mode's folds are the session's (modules/Tree.lua): each case starts from the defaults.
    for _, fid in ipairs({ "currencies", "reputations", "statistics" }) do
        local store = NS.Tree.Store(fid)
        for k in pairs(store) do store[k] = nil end
    end
    local ok, err = pcall(fn)
    Br.HideTooltip()
    Br.SetFeed(Br.DEFAULT_FEED)
    NS.Windows.HideAll()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    NS.db.profile.tooltips.ldb.folds, NS.db.char.fold = folds, char
    M.GetText, M.UnitSex, M.UnitFactionGroup = saved[1], saved[2], saved[3]
    M.__fireTimers()
    if not ok then error(err, 0) end
end

--- `fn` with the LDB tooltip in `style` ("window" or "classic"); the style put back after.
local function withStyle(style, fn)
    local ldb = NS.db.profile.tooltips.ldb
    local saved = ldb.style
    ldb.style = style
    local ok, err = pcall(fn)
    Br.HideTooltip()
    ldb.style = saved
    if not ok then error(err, 0) end
end

local function shownWindow(fid)
    local W = NS.Windows.Get(fid)
    W.Show()
    W.Refresh(true)
    return W
end

local function treeHeaders(rows)
    local out = {}
    for _, row in ipairs(rows) do if row.treeHeader then out[#out + 1] = row end end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- R5-SM-01: a fold chevron has no hint tooltip, in the windows and in the LDB tooltip
-- ---------------------------------------------------------------------------------------------

test("r5 sm-01: no fold chevron carries a hint tooltip, in any window or in the LDB tooltip", function()
    withSample(function()
        local seenTree = 0
        for _, fid in ipairs(NS.FAMILY_ORDER) do
            local W = shownWindow(fid)
            assertTrue(#W.Headers() > 0, fid .. ": a block header drawn")
            for _, h in ipairs(W.Headers()) do
                assertEqual(h.chevron.tip, nil, fid .. ": the block header's chevron says nothing on hover")
            end
            for _, row in ipairs(treeHeaders(W.Rows())) do
                seenTree = seenTree + 1
                assertEqual(row.fold.tip, nil, fid .. ": a tree header's chevron says nothing on hover")
            end
            W.Hide()
        end
        assertTrue(seenTree > 0, "the tree windows drew their headers")
        withStyle("window", function()
            local panelTree = 0
            for _, fid in ipairs(NS.FAMILY_ORDER) do
                Br.OnEnter(M.UIParent, fid)
                for _, h in ipairs(BP.Headers()) do
                    if h.id then assertEqual(h.chevron.tip, nil, fid .. ": the tooltip's section chevron") end
                end
                for _, row in ipairs(treeHeaders(BP.Rows())) do
                    panelTree = panelTree + 1
                    assertEqual(row.fold.tip, nil, fid .. ": the tooltip's tree chevron")
                end
            end
            assertTrue(panelTree > 0, "the tooltip drew tree headers")
        end)
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-02: a click anywhere on a collapsible header folds and unfolds it
-- ---------------------------------------------------------------------------------------------

local function headerFor(headers, id)
    for _, h in ipairs(headers) do if h.id == id then return h end end
    return nil
end

local function treeHeaderRow(rows, depth)
    for _, row in ipairs(rows) do
        if row.treeHeader and (row.tree.depth or 0) == depth then return row end
    end
    return nil
end

test("r5 sm-02: in a window, a click on a block header's body and on a tree header's row folds it, at every depth", function()
    withSample(function()
        local W = shownWindow("professions")
        local h = headerFor(W.Headers(), "primary")
        h:__fire("OnClick", "LeftButton")
        assertTrue(NS.Blocks.Settings("primary").collapsed, "the header's body collapsed the block")
        h = headerFor(W.Headers(), "primary")
        h:__fire("OnClick", "LeftButton")
        assertTrue(not NS.Blocks.Settings("primary").collapsed, "and opened it again")
        W.Hide()
        local S = shownWindow("statistics")
        local top = treeHeaderRow(S.Rows(), 0)
        local key = top.entry.nodeKey
        assertTrue(NS.Tree.IsFolded("statistics", key), "a category starts folded")
        top:__fire("OnClick", "LeftButton")
        assertTrue(not NS.Tree.IsFolded("statistics", key), "a click on its row unfolded it")
        S.Refresh(true)
        local child = treeHeaderRow(S.Rows(), 1)
        assertTrue(child ~= nil, "a sub-category header under it")
        local ckey = child.entry.nodeKey
        local was = NS.Tree.IsFolded("statistics", ckey)
        child:__fire("OnClick", "LeftButton")
        assertEqual(NS.Tree.IsFolded("statistics", ckey), not was, "one level in, the row folds too")
    end)
end)

test("r5 sm-02: in the Main window style LDB tooltip, a click on a section header's body or a tree header's row folds it", function()
    withSample(function()
        withStyle("window", function()
            Br.OnEnter(M.UIParent, "professions")
            local h = headerFor(BP.Headers(), "primary")
            local calls = {}
            rawset(h, "EnableMouse", function(_, on) calls[#calls + 1] = on end)
            Br.OnEnter(M.UIParent, "professions")
            rawset(h, "EnableMouse", nil)
            assertEqual(calls[#calls], true, "the header's body takes the pointer")
            h = headerFor(BP.Headers(), "primary")
            h:__fire("OnClick", "LeftButton")
            assertTrue(Br.TipFolded("primary"), "a click on the header folded the section in the tooltip")
            assertTrue(not NS.Blocks.Settings("primary").collapsed, "the window's collapse untouched")
            for _, k in ipairs({ "detach", "sort", "filter", "restore" }) do
                assertTrue(not h[k]:IsShown(), "no " .. k .. " mark in the tooltip")
            end
            Br.OnEnter(M.UIParent, "statistics")
            local top = treeHeaderRow(BP.Rows(), 0)
            local key = top.entry.nodeKey
            local store = Br.TipNodeStore("statistics")
            assertTrue(NS.Tree.IsFolded("statistics", key, store), "a category starts folded in the tooltip")
            local windowFold = NS.Tree.IsFolded("statistics", key)
            top:__fire("OnClick", "LeftButton")
            assertTrue(not NS.Tree.IsFolded("statistics", key, store), "a click on its row unfolded it")
            assertEqual(NS.Tree.IsFolded("statistics", key), windowFold, "the window's fold untouched")
            local child = treeHeaderRow(BP.Rows(), 1)
            assertTrue(child ~= nil, "the redraw lists a sub-category header")
            local ckey = child.entry.nodeKey
            local was = NS.Tree.IsFolded("statistics", ckey, store)
            child:__fire("OnClick", "LeftButton")
            assertEqual(NS.Tree.IsFolded("statistics", ckey, store), not was, "one level in, the row folds too")
            -- A leaf row still opens nothing.
            for _, row in ipairs(BP.Rows()) do
                if not row.treeHeader then
                    assertTrue(row:GetScript("OnClick") == nil, "a leaf row takes no click")
                end
            end
        end)
    end)
end)

--- The feed's own tooltip dressed as tests/test_broker.lua dresses it: a global name, its lines, and a
--- TextLeftN / TextRightN region per line (the addon finds a line by the frame's name, as in the client).
local function dressOwnTip()
    local tip = Br.Tip()
    if tip.GetName and tip:GetName() == Br.TIP_NAME and type(tip:NumLines()) == "number" then return tip end
    local name = Br.TIP_NAME
    tip.lines = {}
    rawset(tip, "GetName", function() return name end)
    rawset(tip, "NumLines", function(self) return #self.lines end)
    rawset(tip, "ClearLines", function(self) self.lines = {} end)
    rawset(tip, "SetOwner", function(self, o) self.lines, self.__owner = {}, o end)
    rawset(tip, "GetOwner", function(self) return self.__owner end)
    local function region(n)
        for _, side in ipairs({ "Left", "Right" }) do
            local key = name .. "Text" .. side .. n
            _G[key] = _G[key] or tip:CreateFontString()
        end
    end
    rawset(tip, "AddLine", function(self, text) self.lines[#self.lines + 1] = { text } region(#self.lines) end)
    rawset(tip, "AddDoubleLine", function(self, l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end)
    return tip
end

test("r5 sm-02: in the Classic LDB tooltip, a header line's hit spans the whole line, at every depth", function()
    withSample(function()
        withStyle("classic", function()
            dressOwnTip()
            for _ = 1, 2 do   -- the top categories open, then the ones under them
                Br.OnEnter(M.UIParent, "statistics")
                for _, c in ipairs(Br.Chevrons()) do
                    if c.row.node ~= nil then
                        NS.Tree.SetFolded("statistics", c.row.node, false, Br.TipNodeStore("statistics"))
                    end
                end
            end
            Br.OnEnter(M.UIParent, "statistics")
            local points, buttons = {}, {}
            for _, c in ipairs(Br.Chevrons()) do
                buttons[#buttons + 1] = c
                rawset(c, "SetPoint", function(self, p, rel, rp, x)
                    points[self] = points[self] or {}
                    points[self][p] = { rel = rel, rp = rp, x = x }
                end)
            end
            Br.OnEnter(M.UIParent, "statistics")
            for _, c in ipairs(buttons) do rawset(c, "SetPoint", nil) end
            local depths = {}
            for c, p in pairs(points) do
                depths[c.row.depth or 0] = true
                assertTrue(p.LEFT and p.LEFT.x == -2, "the hit starts at the line's left edge")
                assertTrue(p.RIGHT and p.RIGHT.rel == Br.Tip() and p.RIGHT.x == -4,
                    "and runs to the tooltip's right inset")
            end
            local seen = {}
            for d in pairs(depths) do seen[#seen + 1] = d end
            assertTrue(depths[0] and depths[1], "top and nested headers both measured: " .. table.concat(seen, ","))
        end)
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-03: a pin mark on each row pinned to its broker's title
-- ---------------------------------------------------------------------------------------------

local function pinnedNow(row)
    local fid = NS.Pins.FamilyOfRow(row)
    if not (fid and row.entry and row.entry.key) then return false end
    for _, k in ipairs(NS.Pins.List(fid)) do if k == row.entry.key then return true end end
    return false
end

--- Every row's pin mark matches its pin, at the name column's right end; answers how many rows are pinned.
local function checkPins(rows, where)
    local pinned = 0
    for _, row in ipairs(rows) do
        local want = pinnedNow(row)
        assertTrue(row.pin ~= nil, where .. ": every row has a pin mark")
        assertEqual(row.pin:IsShown() == true, want, where .. ": " .. tostring(row.entry.name or row.entry.label)
            .. (want and " is pinned: the mark shows" or " is not pinned: no mark"))
        if want then
            pinned = pinned + 1
            local p, rel, rp, x = row.pin:GetPoint(1)
            assertEqual(p, "RIGHT", where .. ": the mark's right edge")
            assertTrue(rel == row.name and rp == "LEFT", where .. ": measured from the name column's start")
            assertTrue(type(x) == "number" and x >= row.name:GetWidth() + NS.Rows.PIN_W,
                where .. ": at the column's right end, past the narrowed name, never after the text")
        end
    end
    return pinned
end

test("r5 sm-03: a pinned row shows the pin mark in every window, and only a pinned row", function()
    withSample(function()
        local pinned = 0
        for _, fid in ipairs(NS.FAMILY_ORDER) do
            local W = shownWindow(fid)
            -- The tree families' pins sit under folded headers: open every header first.
            local spec = NS.Families[fid]
            if spec.tree then
                for _ = 1, 3 do
                    for _, row in ipairs(W.Rows()) do
                        if row.treeHeader then NS.Tree.SetFolded(fid, row.entry.nodeKey, false) end
                    end
                    W.Refresh(true)
                end
            end
            pinned = pinned + checkPins(W.Rows(), fid)
            W.Hide()
        end
        assertTrue(pinned >= 2, "the sample's pinned skill and tree pins drew their marks: " .. pinned)
    end)
end)

test("r5 sm-03: a pinned row's name gives the mark its room, so a long name never runs under it", function()
    withSample(function()
        local W = shownWindow("professions")
        local R = NS.Rows
        -- Each pooled bar records where its left edge goes on the redraw (the pool hands the same rows back).
        local barLeft = {}
        local bars = {}
        for _, row in ipairs(W.Rows()) do
            bars[#bars + 1] = row.bar
            rawset(row.bar, "SetPoint", function(self, p, rel, _, x)
                if p == "LEFT" and rel ~= nil then barLeft[self] = x end
            end)
        end
        W.Refresh(true)
        for _, bar in ipairs(bars) do rawset(bar, "SetPoint", nil) end
        local any = false
        for _, row in ipairs(W.Rows()) do
            if pinnedNow(row) then
                any = true
                assertEqual(row.name:GetWidth(), R.NAME_W - R.PIN_W - R.PIN_GAP, "the name column less the mark")
                assertEqual(barLeft[row.bar], R.NAME_W + R.PAD, "the bar still starts past the whole column")
            else
                assertEqual(row.name:GetWidth(), R.NAME_W, "an unpinned row's name keeps the whole column")
            end
        end
        assertTrue(any, "the sample pins a profession")
    end)
end)

test("r5 sm-03: the LDB tooltip draws the pin mark on its pinned rows, its Pinned section's included", function()
    withSample(function()
        withStyle("window", function()
            local pinned = 0
            for _, fid in ipairs(NS.FAMILY_ORDER) do
                Br.OnEnter(M.UIParent, fid)
                pinned = pinned + checkPins(BP.Rows(), "tooltip " .. fid)
            end
            assertTrue(pinned >= 2, "the Pinned sections' rows carry it: " .. pinned)
        end)
    end)
end)

-- R5-REV: the Classic style is the LDB tooltip too: its pinned lines carry the mark, at a fixed spot (the name
-- column's right end, where the mini bar starts), and only its pinned lines.
test("r5 sm-03: the Classic LDB tooltip draws the pin mark on its pinned lines, and only those", function()
    withSample(function()
        withStyle("classic", function()
            local tip = dressOwnTip()
            local pinned = 0
            for _, fid in ipairs(NS.FAMILY_ORDER) do
                tip:ClearLines()
                local rows = Br.FillTooltip(tip, fid)
                local want = {}
                for _, k in ipairs(NS.Pins.List(fid)) do want[k] = true end
                local wantLines = {}
                for _, r in ipairs(rows) do
                    if r.key ~= nil and want[r.key] then wantLines[r.line] = true end
                end
                local got = {}
                for _, t in ipairs(Br.PinMarks(tip)) do
                    assertTrue(t:IsShown() == true, fid .. ": a drawn mark shows")
                    got[t.skmLine] = true
                    local p, rel, rp, x = t:GetPoint(1)
                    assertEqual(p, "RIGHT", fid .. ": the mark's right edge")
                    assertTrue(rel == _G[Br.TIP_NAME .. "TextLeft" .. t.skmLine] and rp == "LEFT",
                        fid .. ": measured from its line's left edge")
                    assertEqual(x, Br.NAME_W - NS.Rows.PIN_GAP, fid .. ": at the name column's end, never after the text")
                end
                for line in pairs(wantLines) do
                    assertTrue(got[line], fid .. ": pinned line " .. line .. " carries the mark")
                    pinned = pinned + 1
                end
                for line in pairs(got) do
                    assertTrue(wantLines[line], fid .. ": line " .. line .. " is not pinned: no mark")
                end
            end
            assertTrue(pinned >= 2, "the sample's pins drew their marks: " .. pinned)
            Br.ReleaseLines()
            assertEqual(#Br.PinMarks(tip), 0, "the marks go with the lines")
        end)
    end)
end)

test("r5 sm-03: pinning and unpinning a row shows and hides its mark at once", function()
    local char = NS.db.char
    local saved, savedModel = char.pins, NS.StatData.Model
    char.pins = {}
    -- The Character Stats window reads NS.StatData's model: one stat, whatever the mocks' scan answers.
    local crit = { key = "rangedCrit", label = "Ranged Crit", value = 9.1, display = "9.1%", pct = 30, markers = {} }
    local model = { base = { crit }, spell = {}, defense = {}, utility = {} }
    NS.StatData.Model = function() return model end
    local ok, err = pcall(function()
        local W = shownWindow("stats")
        local row = W.Rows()[1]
        assertTrue(row ~= nil and row.kind == "stat", "a stat row")
        local key = row.entry.key
        assertFalse(row.pin:IsShown(), "not pinned: no mark")
        NS.Pins.Toggle("stats", key)
        M.__fireTimers()
        local again
        for _, r in ipairs(W.Rows()) do if r.entry.key == key then again = r end end
        assertTrue(again.pin:IsShown(), "pinned: the mark shows")
        NS.Pins.Toggle("stats", key)
        M.__fireTimers()
        for _, r in ipairs(W.Rows()) do if r.entry.key == key then again = r end end
        assertFalse(again.pin:IsShown(), "unpinned: gone")
    end)
    NS.Windows.HideAll()
    char.pins, NS.StatData.Model = saved, savedModel
    M.__fireTimers()
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-04: each display broker draws an icon that says what it shows; the control broker keeps the logo
-- ---------------------------------------------------------------------------------------------

test("r5 sm-04: the six display brokers each draw their own in-game icon; the addon's control broker keeps the logo", function()
    local LDB = M.LibStub("LibDataBroker-1.1")
    local seen = {}
    for _, fid in ipairs(NS.FAMILY_ORDER) do
        local f = Br.FEEDS[fid]
        local obj = LDB:GetDataObjectByName(f.name)
        assertTrue(obj ~= nil, fid .. ": its feed is registered")
        assertTrue(obj.icon ~= NS.Constants.LOGO_ICON_PATH, fid .. ": not the Ka0s logo")
        assertEqual(obj.icon, NS.Families[fid].feed.icon, fid .. ": its family's icon")
        assertTrue(type(obj.icon) == "string" and obj.icon:find("^Interface\\Icons\\") ~= nil,
            fid .. ": a client icon texture, on both clients: " .. tostring(obj.icon))
        assertTrue(not seen[obj.icon], fid .. ": an icon of its own")
        seen[obj.icon] = true
    end
    if not NS.Launcher:IsRegistered() then NS.addon:OnEnable() end   -- registered on enable (tests/test_launcher.lua)
    assertEqual(NS.Launcher:Object().icon, NS.Constants.LOGO_ICON_PATH, "the control broker keeps the logo")
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-05: `/cl toggle` shows or hides every window; `/cl professions` is the Professions window's
-- ---------------------------------------------------------------------------------------------

local function shownSet()
    local out = {}
    for _, fid in ipairs(NS.FAMILY_ORDER) do
        if NS.Windows.Get(fid).IsShown() then out[#out + 1] = fid end
    end
    return table.concat(out, ",")
end

local ALL = table.concat(NS.FAMILY_ORDER, ",")

test("r5 sm-05: /cl toggle shows all six windows when none shows, and hides them all when any shows", function()
    NS.Windows.HideAll()
    local ok, err = pcall(function()
        NS.Slash:OnSlash("toggle")
        assertEqual(shownSet(), ALL, "none shown: every window opens")
        NS.Slash:OnSlash("toggle")
        assertEqual(shownSet(), "", "all shown: every window closes")
        NS.Slash:OnSlash("statistics")
        assertEqual(shownSet(), "statistics", "one window open")
        NS.Slash:OnSlash("toggle")
        assertEqual(shownSet(), "", "any shown: every window closes, the rest staying closed")
    end)
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end)

test("r5 sm-05: /cl professions, the Show window entry and its key binding toggle the Professions window alone", function()
    NS.Windows.HideAll()
    local ok, err = pcall(function()
        NS.Slash:OnSlash("professions")
        assertEqual(shownSet(), "professions", "/cl professions opens Professions alone")
        NS.Slash:OnSlash("professions")
        assertEqual(shownSet(), "", "and closes it")
        local button = NS.MainWindow.__toggleButton
        button:GetScript("OnClick")(button, "LeftButton")
        assertEqual(shownSet(), "professions", "the key binding is still the Professions window's")
        button:GetScript("OnClick")(button, "LeftButton")
        assertEqual(_G["BINDING_NAME_CLICK " .. NS.MainWindow.TOGGLE_BUTTON .. ":LeftButton"], "Toggle Professions window",
            "its label says so")
    end)
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end)

test("r5 sm-05: the help says /cl toggle is every window and /cl professions the Professions window", function()
    local desc = {}
    for _, row in ipairs(NS.COMMANDS) do desc[row[1]] = row[2] end
    assertEqual(desc.toggle, "Show or hide every Character Ledger window")
    assertEqual(desc.professions, "Show or hide the Professions window")
end)

test("r5 sm-05: /cl toggle under the perf hold opens nothing and says the capture line once", function()
    NS.Windows.HideAll()
    local saved, printed = NS.Print, {}
    local savedRefusal = NS.StoodDownRefusal
    NS.StoodDownRefusal = function() return "Not available during a performance capture." end
    NS.Print = function(line) printed[#printed + 1] = line end
    local ok, err = pcall(function()
        NS.Windows.ToggleAll()
        assertEqual(shownSet(), "", "nothing opens")
        assertEqual(#printed, 1, "one line, not one per window: " .. table.concat(printed, " | "))
    end)
    NS.Print, NS.StoodDownRefusal = saved, savedRefusal
    NS.Windows.HideAll()
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-06: the probe lists every profession twice (a parent line and a child line); no window or tooltip
-- draws a profession twice. The model already folds the child into its parent's row (modules/SkillData.lua
-- classify / addLearned, tests/test_skilldata.lua); this case pins it end to end on the probe's own list.
-- ---------------------------------------------------------------------------------------------

-- `/cl probe` on WoW Forever, 2026-11-26 (Ka0sAddonsCommonTasks docs/2026-11-26-OWNER_FEEDBACK_ROUND5/inputs/
-- SM_PROBE_2026-11-26.md): a Night Elf Hunter's Skills tab in order, each profession as the classic line
-- (parentSkillLineID 0) and a child line with the parent's ID and the same rank and max; Cooking's child first.
local PROBE = {
    { "Class Skills", { { "Beast Mastery", 1, 1, 50, 0 }, { "Marksmanship", 1, 1, 51, 0 }, { "Survival", 1, 1, 51, 0 } } },
    { "Professions", { { "Leatherworking", 121, 150, 165, 0 }, { "Leatherworking", 121, 150, 2945, 165 },
                       { "Skinning", 130, 150, 393, 0 }, { "Skinning", 130, 150, 2947, 393 } } },
    { "Secondary Skills", { { "Cooking", 60, 75, 2939, 185 }, { "Cooking", 60, 75, 185, 0 },
                            { "First Aid", 40, 75, 129, 0 }, { "First Aid", 40, 75, 2942, 129 },
                            { "Fishing", 33, 75, 356, 0 }, { "Fishing", 33, 75, 2943, 356 } } },
    { "Weapon Skills", { { "Bows", 80, 110, 45, 0 }, { "Daggers", 60, 110, 173, 0 } } },
    { "Armor Proficiencies", { { "Cloth", 1, 1, 415, 0 }, { "Leather", 1, 1, 414, 0 } } },
    { "Languages", { { "Common", 300, 300, 98, 0 }, { "Darnassian", 300, 300, 113, 0 } } },
}

local function probeLines()
    local lines = {}
    for _, h in ipairs(PROBE) do
        for _, l in ipairs(h[2]) do
            lines[#lines + 1] = { header = h[1], rec = { name = l[1], rank = l[2], max = l[3], tempPoints = 0,
                modifier = 0, skillLineID = l[4], parentSkillLineID = l[5] } }
        end
    end
    return lines
end

local PROFESSIONS = { "Leatherworking", "Skinning", "Cooking", "First Aid", "Fishing" }

local function countNames(rows)
    local n = {}
    for _, row in ipairs(rows) do
        local e = row.entry
        local name = e and (e.name or e.label)
        if name then n[name] = (n[name] or 0) + 1 end
    end
    return n
end

test("r5 sm-06: the probe's doubled profession lines draw each profession once, in the windows and the tooltip", function()
    local m = NS.SkillData.Build(probeLines(), { classFile = "HUNTER", level = 22 })
    for key in pairs(m.byKey) do
        assertTrue(key:find("^other:") == nil, "no child line lands in Other: " .. key)
    end
    for _, c in ipairs(NS.SkillData.CATEGORIES) do
        local seen = {}
        for _, key in ipairs(m.order[c]) do
            assertTrue(not seen[key], c .. ": " .. key .. " listed once")
            seen[key] = true
        end
    end
    assertEqual(m.byKey.cooking.rank, 60, "Cooking's child came first; one row, the same rank")
    local savedModel, savedSource = NS.SkillData.Model, Br.source
    NS.SkillData.Model = function() return m end
    local ok, err = pcall(function()
        NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, m)
        M.__fireTimers()
        local names = {}
        for _, fid in ipairs({ "professions", "skills" }) do
            for name, n in pairs(countNames(shownWindow(fid).Rows())) do names[name] = (names[name] or 0) + n end
        end
        for _, p in ipairs(PROFESSIONS) do
            assertEqual(names[p], 1, "the windows draw " .. p .. " once")
        end
        -- The feeds read this model as tests/test_round6.lua hands them one (NS.Broker.source).
        Br.source = function()
            return { model = m, statsModel = { base = {}, spell = {}, defense = {}, utility = {} }, statIndex = {},
                     gains = { total = 0, byKey = {} }, models = {} }
        end
        withStyle("window", function()
            Br.OnEnter(M.UIParent, "professions")
            local tip = countNames(BP.Rows())
            for _, p in ipairs(PROFESSIONS) do
                assertEqual(tip[p], 1, "the Main window style tooltip draws " .. p .. " once")
            end
        end)
        withStyle("classic", function()
            local lines = {}
            local tip = M.CreateFrame("GameTooltip", "CharacterLedgerR5ProbeTip", M.UIParent)
            function tip:AddLine(t) lines[#lines + 1] = t end
            function tip:AddDoubleLine(l) lines[#lines + 1] = l end
            function tip:NumLines() return #lines end
            Br.FillTooltip(tip, "professions")
            local text = table.concat(lines, "\n")
            for _, p in ipairs(PROFESSIONS) do
                local _, n = text:gsub(p:gsub("%s", "%%s"), "")
                assertEqual(n, 1, "the Classic tooltip lists " .. p .. " once")
            end
        end)
        Br.source = savedSource
    end)
    NS.Windows.HideAll()
    NS.SkillData.Model = savedModel
    Br.source = savedSource
    local live = NS.SkillData:Model()
    if live then NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, live) end   -- the feeds back on the live model
    M.__fireTimers()
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-07: every window open while playing raises no Lua error. A headless session on the probe's own shapes:
-- `/cl toggle` opens all six, the game's events fire as play sends them, every fold is clicked, every feed
-- hovered in both styles, then `/cl toggle` closes them all. Each step must run without an error.
-- ---------------------------------------------------------------------------------------------

local statsFx = dofile("tests/fixture_statistics.lua")

-- The probe's Reputation tab (all expanded): Alliance (469; isHeaderWithRep false, its standing fields filled
-- in), Steamwheedle Cartel, then Other (factionID 0) with an at-war Bloodsail Buccaneers at -8500.
local function probeFactions()
    local function f(id, name, reaction, cur, extra)
        local t = { factionID = id, name = name, isHeader = false, isChild = false, isHeaderWithRep = false,
                    isCollapsed = false, reaction = reaction, currentReactionThreshold = 0, nextReactionThreshold = 3000,
                    currentStanding = cur, atWarWith = false, isWatched = false, description = name }
        for k, v in pairs(extra or {}) do t[k] = v end
        return t
    end
    return {
        f(469, "Alliance", 5, 4200, { isHeader = true }),
        f(69, "Darnassus", 6, 9500, { isWatched = true }), f(54, "Gnomeregan Exiles", 5, 3100),
        f(47, "Ironforge", 5, 3300), f(72, "Stormwind", 5, 3400),
        f(169, "Steamwheedle Cartel", 4, 0, { isHeader = true }),
        f(21, "Booty Bay", 4, 100), f(577, "Everlook", 4, 100), f(369, "Gadgetzan", 4, 100),
        f(2827, "Powderfuse", 4, 0), f(470, "Ratchet", 4, 100),
        f(0, "Other", 4, 0, { isHeader = true }),
        f(529, "Argent Dawn", 4, 200), f(2586, "Azeroth Commerce Authority", 4, 0),
        f(87, "Bloodsail Buccaneers", 1, -8500, { atWarWith = true, currentReactionThreshold = -42000,
                                                  nextReactionThreshold = -6000 }),
        f(2740, "Kirin Tor", 4, 0),
    }
end

-- The probe's Currency tab: Player vs. Player -> Honor Points (85 / 25000); Professions & Tradeskills ->
-- Merchant's Favor (80, quality 2).
local function probeCurrencies()
    return {
        { name = "Player vs. Player", isHeader = true, isHeaderExpanded = true, currencyListDepth = 0, currencyID = 0,
          quantity = 0, maxQuantity = 0 },
        { name = "Honor Points", isHeader = false, currencyListDepth = 1, currencyID = 1792, quantity = 85,
          maxQuantity = 25000 },
        { name = "Professions & Tradeskills", isHeader = true, isHeaderExpanded = true, currencyListDepth = 0,
          currencyID = 0, quantity = 0, maxQuantity = 0 },
        { name = "Merchant's Favor", isHeader = false, currencyListDepth = 1, currencyID = 3402, quantity = 80,
          maxQuantity = 0, quality = 2 },
    }
end

local function installProbeClient()
    local reps, curs = probeFactions(), probeCurrencies()
    local byRep, byCur = {}, {}
    for _, r in ipairs(reps) do byRep[r.factionID] = r end
    for _, c in ipairs(curs) do byCur[c.currencyID] = c end
    local saved = { M.C_Reputation, M.C_CurrencyInfo, M.FACTION_BAR_COLORS, M.InCombatLockdown }
    M.C_Reputation = {
        GetNumFactions = function() return #reps end,
        GetFactionDataByIndex = function(i) return reps[i] end,
        GetFactionDataByID = function(id) return byRep[id] end,
        ExpandFactionHeader = function() end, CollapseFactionHeader = function() end,
    }
    M.C_CurrencyInfo = {
        GetCurrencyListSize = function() return #curs end,
        GetCurrencyListInfo = function(i) return curs[i] end,
        GetCurrencyInfo = function(id) return byCur[id] end,
        ExpandCurrencyList = function() end,
    }
    M.FACTION_BAR_COLORS = { [1] = { r = 0.8, g = 0.1, b = 0.1 }, [4] = { r = 1, g = 1, b = 0 },
                             [5] = { r = 0, g = 0.6, b = 0.1 }, [6] = { r = 0, g = 0.7, b = 0.2 } }
    local inCombat = false
    M.InCombatLockdown = function() return inCombat end
    local _, restoreStats = statsFx.install(M)
    return {
        reps = reps, curs = curs,
        combat = function(on) inCombat = on end,
        restore = function()
            restoreStats()
            M.C_Reputation, M.C_CurrencyInfo, M.FACTION_BAR_COLORS, M.InCombatLockdown = unpack(saved, 1, 4)
        end,
    }
end

test("r5 sm-07: all six windows open while playing raise no Lua error, and /cl toggle closes them all", function()
    local saved = { M.GetText, M.UnitSex }
    M.GetText = function(key) return LABELS[tonumber(tostring(key):match("(%d+)$"))] end
    M.UnitSex = function() return 2 end
    local savedFold, savedPins, savedLog = NS.db.char.fold, NS.db.char.pins, NS.db.char.log
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = {}, {}, {}
    local ldbFolds = NS.db.profile.tooltips.ldb.folds
    NS.db.profile.tooltips.ldb.folds = { blocks = {}, nodes = {} }
    NS.Windows.HideAll()
    NS.RepData:Reset()
    NS.CurrencyData:Reset()
    NS.StatisticsData:Reset()
    local client = installProbeClient()
    local step = "setup"
    local function run(name, fn, ...)
        step = name
        fn(...)
        M.__fireTimers()
    end
    local function fire(event, ...) return run(event, M.__fireEvent, event, ...) end
    local function clickEveryFold(fid)
        local W = NS.Windows.Get(fid)
        for _ = 1, 3 do
            W.Refresh(true)
            for _, row in ipairs(W.Rows()) do
                if row.treeHeader and NS.Tree.IsFolded(fid, row.entry.nodeKey) then
                    run(fid .. ": unfold " .. tostring(row.entry.name), row.GetScript(row, "OnClick"), row, "LeftButton")
                end
            end
        end
        for _, h in ipairs(W.Headers()) do
            run(fid .. ": collapse " .. tostring(h.id), h.GetScript(h, "OnClick"), h, "LeftButton")
        end
        W.Refresh(true)
        for _, h in ipairs(W.Headers()) do
            run(fid .. ": expand " .. tostring(h.id), h.GetScript(h, "OnClick"), h, "LeftButton")
        end
    end
    local ok, err = pcall(function()
        run("/cl toggle (open)", NS.Slash.OnSlash, NS.Slash, "toggle")
        assertEqual(shownSet(), ALL, "every window open")
        fire("PLAYER_ENTERING_WORLD", false, true)
        fire("SKILL_LINES_CHANGED")
        fire("CHAT_MSG_SKILL", "Your skill in Skinning has increased to 131.")
        fire("UPDATE_FACTION")
        client.reps[2].currentStanding = 9600
        fire("UPDATE_FACTION")
        client.curs[2].quantity = 90
        fire("CURRENCY_DISPLAY_UPDATE", 1792, 90, 5)
        fire("CRITERIA_UPDATE")
        fire("UNIT_STATS", "player")
        fire("UNIT_AURA", "player")
        fire("UNIT_INVENTORY_CHANGED", "player")
        fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
        fire("UPDATE_INVENTORY_DURABILITY")
        client.combat(true)
        fire("PLAYER_REGEN_DISABLED")
        fire("UPDATE_FACTION")
        fire("CURRENCY_DISPLAY_UPDATE")
        client.combat(false)
        fire("PLAYER_REGEN_ENABLED")
        fire("PLAYER_LEVEL_UP", 23)
        for _, fid in ipairs({ "currencies", "reputations", "statistics" }) do
            local W = NS.Windows.Get(fid)
            W.Refresh(true)
            assertTrue(#W.Rows() > 0, fid .. ": the window drew the probe's rows")
        end
        for _, fid in ipairs(NS.FAMILY_ORDER) do clickEveryFold(fid) end
        local R = NS.Windows.Get("reputations")
        R.Refresh(true)
        local names = countNames(R.Rows())
        assertEqual(names["Bloodsail Buccaneers"], 1, "every header unfolded: an at-war faction under Other drawn")
        for _, style in ipairs({ "window", "classic" }) do
            withStyle(style, function()
                if style == "classic" then dressOwnTip() end
                for _, fid in ipairs(NS.FAMILY_ORDER) do
                    run(style .. " tooltip: " .. fid, Br.OnEnter, M.UIParent, fid)
                end
                run(style .. " tooltip: leave", Br.OnLeave)
            end)
        end
        fire("CRITERIA_UPDATE")
        fire("PLAYER_LOGOUT")
        run("/cl toggle (close)", NS.Slash.OnSlash, NS.Slash, "toggle")
        assertEqual(shownSet(), "", "every window closed")
    end)
    NS.Windows.HideAll()
    Br.HideTooltip()
    client.restore()
    NS.RepData:Reset()
    NS.CurrencyData:Reset()
    NS.StatisticsData:Reset()
    M.__fireTimers()
    NS.db.char.fold, NS.db.char.pins, NS.db.char.log = savedFold, savedPins, savedLog
    NS.db.profile.tooltips.ldb.folds = ldbFolds
    M.GetText, M.UnitSex = saved[1], saved[2]
    if not ok then error(("at %s: %s"):format(step, tostring(err)), 0) end
end)
