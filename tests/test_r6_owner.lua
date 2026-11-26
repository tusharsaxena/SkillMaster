-- tests/test_r6_owner.lua — owner feedback round 6 (Ka0sAddonsCommonTasks docs/2026-11-27-OWNER_FEEDBACK_ROUND6/).
-- R6-SM-01: "Rename secondary skills to secondary professions": every label Skill Master gives that group reads
-- Secondary Professions; the client's own Skills-tab header ("Secondary Skills") is game data and still files
-- Cooking, First Aid and Fishing there, and the block's id, its saved settings and its short label stay.
-- R6-SM-02: the Journal Log's Type column (below).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ---------------------------------------------------------------------------------------------
-- R6-SM-01: Secondary Professions
-- ---------------------------------------------------------------------------------------------

local function skill(key, name, category, rank, max)
    return { key = key, name = name, category = category, rank = rank, max = max, tempPoints = 0,
             modifier = 0, learned = true }
end

local function withWorld(fn)
    local B = NS.Blocks
    local skills = { byKey = { fishing = skill("fishing", "Fishing", "secondary", 107, 150),
                               skinning = skill("skinning", "Skinning", "primary", 122, 150) },
                     order = { primary = { "skinning" }, secondary = { "fishing" }, weapon = {}, other = {} } }
    local stats = { base = {}, spell = {}, defense = {}, utility = {} }
    local savedSource = B.source
    B.source = function() return skills, stats end
    local ok, err = pcall(fn)
    B.source = savedSource
    NS.MainWindow.Hide()
    if not ok then error(err, 0) end
end

test("r6 sm-01: the group's title reads Secondary Professions; its id and short label stay", function()
    local d = NS.BlockDefs.secondary
    assertEqual(d.title, "Secondary Professions", "the window's group header")
    assertEqual(NS.Blocks.HomeTitle("secondary"), "Secondary Professions", "in its own family's window and feed")
    assertEqual(d.short, "Secondary", "the short label (Alts sub-tab, merged title) unchanged")
    assertEqual(d.id, "secondary", "the id the saved settings key on")
    assertTrue(NS.defaults.profile.layout.blocks.secondary ~= nil, "the saved block settings keep their key")
end)

test("r6 sm-01: a detached Secondary window is titled Secondary Professions", function()
    withWorld(function()
        local B, D = NS.Blocks, NS.Detached
        B:Detach("secondary")
        local ok, err = pcall(function()
            assertEqual(D.Frame("secondary").title:GetText(), "Secondary Professions")
        end)
        B:Dock("secondary")
        if not ok then error(err, 0) end
    end)
end)

test("r6 sm-01: the settings labels and the Professions window's binding tip say secondary professions", function()
    assertEqual(NS.FindSchemaRow("broker.tooltip.sections.secondary").label, "Secondary professions",
        "the Professions feed's tooltip section")
    local swatch = NS.FindSchemaRow("bars.colors.secondary")
    assertEqual(swatch.label, "Secondary professions", "the bar color swatch")
    assertTrue(swatch.desc:find("secondary profession's bar", 1, true) ~= nil, swatch.desc)
    local tip = NS.BINDINGS[1].tooltip   -- the family order's first: Professions
    assertEqual(tip, "Shows or hides the Professions window: primary and secondary professions.", "the binding's tip")
end)

test("r6 sm-01: the client's own header, Secondary Skills, still files its lines in the Secondary group", function()
    local SD = NS.SkillData
    local model = SD.Build({ { rec = { name = "Fishing", rank = 107, max = 150, tempPoints = 0, modifier = 0 },
                                             header = "Secondary Skills" } }, { classFile = "HUNTER", level = 20 })
    assertEqual(model.byKey.fishing and model.byKey.fishing.category, "secondary")
end)

-- ---------------------------------------------------------------------------------------------
-- R6-SM-02: the Journal Log's Type column
-- ---------------------------------------------------------------------------------------------

local J, SL, JF = NS.Journal, NS.SessionLog, NS.JournalFilters
local LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

-- A day's log at fixed local times on an empty log, the Journal open on the Log over all time, unfiltered: two
-- skill-ups, a faction's gain that reached Honored and its loss, a currency. Everything put back after.
local function withDay(fn)
    local t = M.time()
    local date = M.date or os.date
    local base = t - (tonumber(date("%H", t)) * 3600 + tonumber(date("%M", t)) * 60 + tonumber(date("%S", t)))
    local savedLog, savedStart, savedRange = NS.db.char.log, SL:SessionStart(), NS.db.profile.journal.range
    local savedText, savedSex = M.GetText, M.UnitSex
    M.UnitSex = function() return 2 end
    M.GetText = function(key) return LABELS[tonumber(tostring(key):match("(%d+)$"))] or savedText(key) end
    NS.db.char.log = {}
    SL:ResetFloor()
    SL:NewSession(base - 3600)
    NS.db.profile.journal.range = "all"
    JF.Clear()
    SL:Add("fishing", 50, 51, base + 2 * 3600, "Elwynn Forest")
    SL:AddChange("reputation", "72", "Stormwind", 8900, 9100, base + 9 * 3600, "Elwynn Forest", 5, 6)
    SL:AddChange("reputation", "72", "Stormwind", 9100, 9050, base + 10 * 3600, "Duskwood")
    SL:AddChange("currency", "1901", "Honor Points", 100, 113, base + 14 * 3600, "Duskwood")
    SL:Add("bows", 80, 81, base + 20 * 3600, "Duskwood")
    J.Show()
    J.SelectTab("log")
    local ok, err = pcall(fn)
    JF.Clear()
    J.Hide()
    NS.db.char.log = savedLog
    NS.db.profile.journal.range = savedRange
    SL:NewSession(savedStart)
    SL:ResetFloor()
    M.GetText, M.UnitSex = savedText, savedSex
    if not ok then error(err, 0) end
end

local function logRows()
    local out = {}
    for _, row in ipairs(J.Frame().logPanel.pool.active) do
        if row:IsShown() then out[#out + 1] = row end
    end
    return out
end

local function column(i)
    local out = {}
    for _, row in ipairs(logRows()) do out[#out + 1] = row.cols[i]:GetText() end
    return table.concat(out, ",")
end

local function pick(col, label)
    for _, r in ipairs(J.FilterMenuRowsForTest(col)) do
        if r.label == label and r.onClick then r.onClick() return r end
        for _, s in ipairs(r.submenu or {}) do
            if s.label == label then s.onClick() return s end
        end
    end
    error("no menu row " .. label .. " under " .. col)
end

local function labels(col)
    local out = {}
    for _, r in ipairs(J.FilterMenuRowsForTest(col)) do
        if r.label and not r.title then out[#out + 1] = r.label .. (r.submenu and ">" or "") end
    end
    return table.concat(out, ",")
end

test("r6 sm-02: the Log has a Type column after Time: Skill-up, Reputation (a standing change too), Currency", function()
    withDay(function()
        local p = J.Frame().logPanel
        local heads = {}
        for i, fs in ipairs(p.headers) do heads[i] = fs:GetText() end
        assertEqual(table.concat(heads, ","), "DATE,TIME,TYPE,NAME,CHANGE,ZONE")
        assertEqual(column(3), "Skill-up,Currency,Reputation,Reputation,Skill-up", "each row's type, newest first")
        assertEqual(column(4), "Bows,Honor Points,Stormwind,Stormwind,Fishing", "the names beside them")
        assertEqual(column(5), "80 -> 81,+13,-50,+200, Honored,50 -> 51", "a standing change is a Reputation row")
        assertEqual(J.TypeText({ key = "fishing" }), "Skill-up")
        assertFalse(logRows()[1].cols[3]:CanWordWrap(), "the type truncates rather than wraps")
    end)
end)

test("r6 sm-02: the Type header filters by kind; Name keeps the names, of the picked type only", function()
    withDay(function()
        assertEqual(JF.COLUMNS[3], "type", "the filters follow the columns")
        assertEqual(labels("type"), "Any type,Skill-up,Reputation,Currency")
        pick("type", "Reputation")
        assertEqual(column(4), "Stormwind,Stormwind", "only the faction rows")
        assertTrue(JF.Active("type"), "the Type header is on")
        assertFalse(JF.Active("name"), "the Name header is not")
        local card = J.Frame().logPanel.session
        assertEqual(card.value:GetText(), "+150", "the summary counts the reputation's net change")
        assertEqual(labels("name"), "Any name,Stormwind", "Name lists the picked type's names, flat")
        pick("name", "Stormwind")
        assertEqual(JF.Get("kind"), "reputation", "a name keeps the type")
        pick("type", "Skill-up")
        assertEqual(JF.Get("name"), nil, "a type picked drops a name of another type")
        assertEqual(column(4), "Bows,Fishing")
        pick("type", "Any type")
        assertFalse(JF.Active("type"))
        assertEqual(labels("name"), "Any name,One of the Skill-ups>,One of the Reputations>,One of the Currencies>",
            "with no type, a submenu per type present")
        pick("name", "Honor Points")
        assertEqual(column(4), "Honor Points", "one name")
        assertFalse(JF.Active("type"), "the name leaves the Type filter alone")
        assertEqual(card.value:GetText(), "+13", "and the summary counts the name's own kind")
        pick("name", "Any name")
        assertFalse(JF.Active(), "every filter off")
        assertEqual(#logRows(), 5)
    end)
end)

test("r6 sm-02: the Journal is wide enough at its minimum for every column and the side cards", function()
    assertTrue(J.MIN_W >= 820, "the minimum width rose for the Type column: " .. J.MIN_W)
    local widths = J.LogColumnWidths(J.MIN_W)
    assertEqual(#widths, 6, "six columns")
    -- What each column's longest cell needs in the body font: "12/31/26", "23:59", "Reputation", a 20-letter
    -- faction ("Hydraxian Waterlords"), "+2,500, Revered", a long zone ("Hillsbrad Foothills").
    local need = { 46, 30, 74, 140, 100, 140 }
    for i, w in ipairs(widths) do
        assertTrue(w >= need[i], ("column %d is %d px at the minimum, needs %d"):format(i, w, need[i]))
    end
    assertTrue(J.LogColumnWidths(720)[4] < need[4], "the old 720 would have cut the Name column")
    J.Show()
    local f = J.Frame()
    local minW = f:GetResizeBounds()
    assertEqual(minW, J.MIN_W, "the grip never goes narrower")
    local sizes = {}
    rawset(f, "SetSize", function(_, w, h) sizes[#sizes + 1] = w .. "x" .. h end)
    local saved = NS.db.profile.journal.size
    NS.db.profile.journal.size = { w = 720, h = 500 }
    J.ApplySize()
    NS.db.profile.journal.size = { w = J.MIN_W + 100, h = 500 }
    J.ApplySize()
    rawset(f, "SetSize", nil)
    NS.db.profile.journal.size = saved
    J.Hide()
    assertEqual(table.concat(sizes, ","), J.MIN_W .. "x500," .. (J.MIN_W + 100) .. "x500",
        "an old 720 size comes back at the new minimum; a larger one is kept")
end)

-- ---------------------------------------------------------------------------------------------
-- R6-SM-03: every type its own color ("Give every type a unique color")
-- ---------------------------------------------------------------------------------------------

local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r, g, b) end

test("r6 sm-03: each Type cell is drawn in its kind's own color, three distinct, none the muted style", function()
    withDay(function()
        local want = {}
        for _, k in ipairs(JF.KINDS) do
            local c = JF.KindColor(k)
            assertTrue(type(c) == "table", "a color for " .. k)
            want[JF.KindLabel(k)] = rgb(c[1], c[2], c[3])
        end
        local muted = NS.SkinColor("text.muted") or NS.SkinColor("sm.muted")
        local seen = {}
        for _, row in ipairs(logRows()) do
            local fs = row.cols[3]
            local got = rgb(fs:GetTextColor())
            assertEqual(got, want[fs:GetText()], "the " .. fs:GetText() .. " cell's color")
            assertTrue(got ~= rgb(muted[1], muted[2], muted[3]), "no longer the muted style")
            seen[fs:GetText()] = got
        end
        assertTrue(seen["Skill-up"] ~= seen["Reputation"] and seen["Skill-up"] ~= seen["Currency"]
            and seen["Reputation"] ~= seen["Currency"], "three distinct colors")
        assertEqual(rgb(logRows()[1].cols[1]:GetTextColor()), rgb(muted[1], muted[2], muted[3]), "DATE stays muted")
    end)
end)

test("r6 sm-03: the type colors are readable on the dark Journal and far apart from each other", function()
    local cs = {}
    for _, k in ipairs(JF.KINDS) do
        local c = JF.KindColor(k)
        -- Relative luminance well above the window's near-black backing.
        assertTrue(0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3] > 0.35, k .. " is bright enough")
        cs[#cs + 1] = c
    end
    for i = 1, #cs do
        for j = i + 1, #cs do
            local d = math.abs(cs[i][1] - cs[j][1]) + math.abs(cs[i][2] - cs[j][2]) + math.abs(cs[i][3] - cs[j][3])
            assertTrue(d > 0.4, ("kinds %d and %d stand apart (%.2f)"):format(i, j, d))
        end
    end
end)

test("r6 sm-03: the Type filter menu lists each type in its own color; Any type stays plain", function()
    withDay(function()
        local byLabel = {}
        for _, r in ipairs(J.FilterMenuRowsForTest("type")) do if r.label then byLabel[r.label] = r end end
        assertEqual(byLabel["Any type"].color, nil, "Any type in the menu's own text color")
        for _, k in ipairs(JF.KINDS) do
            local row, c = byLabel[JF.KindLabel(k)], JF.KindColor(k)
            assertTrue(row ~= nil and row.color ~= nil, "a color on " .. k)
            assertEqual(rgb(row.color[1], row.color[2], row.color[3]), rgb(c[1], c[2], c[3]), k .. " as its cells")
        end
    end)
end)
