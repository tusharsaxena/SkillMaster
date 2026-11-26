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

-- ---------------------------------------------------------------------------------------------
-- R6-SM-04: the Alts cells' tooltips ("Add tooltips here, which should match the tooltip from the main window"),
-- none on an unlearned cell, which reads "-"
-- ---------------------------------------------------------------------------------------------

local RT = NS.RowTooltip
local ALT_KEY = "Samplerealm-Samplehunter Mockstride"

-- One alt (a level 22 Alliance dwarf hunter) with a skill of each kind, a stat, a faction and a currency; the
-- Journal open on the Alts tab. The tooltip's lines are recorded off GameTooltip. Everything put back after.
local function withAlt(fn)
    local saved = NS.db.global.characters
    NS.db.global.characters = {
        [ALT_KEY] = {
            name = "Samplehunter Mockstride", class = "HUNTER", className = "Hunter", race = "Dwarf", raceFile = "Dwarf",
            faction = "Alliance", level = 22,
            skills = { leatherworking = { name = "Leatherworking", category = "primary", rank = 146, max = 150 },
                       bows = { name = "Bows", category = "weapon", rank = 80, max = 110 } },
            stats = { strength = { group = "base", value = 61, display = "61", pct = 80 } },
            reps = { ["72"] = { name = "Stormwind", reaction = 6, standing = "Honored", value = 3000, max = 12000 } },
            currencies = { ["1901"] = { name = "Honor Points", quantity = 1200, maxQuantity = 75000 } },
        },
    }
    local tip = M.GameTooltip
    local rec = {}
    rawset(tip, "AddLine", function(_, l) rec[#rec + 1] = tostring(l) end)
    rawset(tip, "AddDoubleLine", function(_, l, r) rec[#rec + 1] = tostring(l) .. " | " .. tostring(r) end)
    local owner
    rawset(tip, "SetOwner", function(_, f) owner = f end)
    rawset(tip, "IsOwned", function(_, f) return owner == f end)
    J.Show()
    J.SelectTab("alts")
    local ok, err = pcall(fn, rec)
    J.SelectFilter("primary")
    J.SelectTab("log")
    J.Hide()
    rawset(tip, "AddLine", nil)
    rawset(tip, "AddDoubleLine", nil)
    rawset(tip, "SetOwner", nil)
    rawset(tip, "IsOwned", nil)
    tip:Hide()
    NS.db.global.characters = saved
    if not ok then error(err, 0) end
end

local function altCell(filter, key)
    J.SelectFilter(filter)
    local p = J.Frame().altsPanel
    local c
    for i, item in ipairs(p.list) do if item.key == ALT_KEY then c = i end end
    for _, row in ipairs(p.pool.active) do
        if row:IsShown() and row.key == key then return row.cells[c] end
    end
    error("no row " .. key .. " on " .. filter)
end

-- Hover `cell`: its lines, joined, and whether the tooltip showed.
local function hover(rec, cell)
    for i = #rec, 1, -1 do rec[i] = nil end
    M.GameTooltip:Hide()
    local enter = cell.hit:GetScript("OnEnter")
    if enter then enter(cell.hit) end
    return table.concat(rec, "\n"), M.GameTooltip:IsShown()
end

local function has(s, part) return s:find(part, 1, true) ~= nil end

test("r6 sm-04: an unlearned Alts cell reads '-' in the muted style, and has no tooltip", function()
    withAlt(function(rec)
        local cell = altCell("primary", "mining")
        assertTrue(cell.unlearned:IsShown(), "the hunter can learn Mining and has not")
        assertEqual(cell.unlearned:GetText(), "-", "renamed from Unlearned")
        local muted = NS.SkinColor("text.muted") or NS.SkinColor("sm.muted")
        assertEqual(rgb(cell.unlearned:GetTextColor()), rgb(muted[1], muted[2], muted[3]), "muted")
        local s, shown = hover(rec, cell)
        assertFalse(shown, "no tooltip on an unlearned cell")
        assertEqual(s, "", "and no line")
    end)
end)

test("r6 sm-04: a learned profession cell shows the main window's tooltip, from that character's snapshot", function()
    withAlt(function(rec)
        local cell = altCell("primary", "leatherworking")
        local s, shown = hover(rec, cell)
        assertTrue(shown, "a tooltip")
        local first = rec[1] or ""
        assertEqual(first, "Leatherworking | Primary", "the main window's title line")
        assertTrue(has(s, "146") and has(s, "150"), "its rank and max: " .. s)
        assertTrue(RT.Bar() ~= nil and RT.Bar():IsShown(), "the tooltip bar")
        assertTrue(math.abs(RT.Bar().geom.fill - 146 / 150) < 1e-9, "drawn from the snapshot")
        assertTrue(has(s, "Next rank"), "the next rank: " .. s)
        assertFalse(has(s, "Bonuses"), "no live bonuses for an alt")
        assertFalse(has(s, "This session"), "no session gains: the log is this character's")
        assertFalse(has(s, "Click") or has(s, "Arrow:") or has(s, "Right-click"), "no click hints in the grid")
        cell.hit:GetScript("OnLeave")(cell.hit)
        assertFalse(M.GameTooltip:IsShown(), "leaving hides it")
    end)
end)

test("r6 sm-04: a weapon cell measures the cap at that character's level", function()
    withAlt(function(rec)
        local s = hover(rec, altCell("weapon", "bows"))
        assertTrue(has(s, "Cap at their level | 110 (5 \195\151 22)"), s)
        assertFalse(has(s, "Cap at your level"), "not the player's level")
        assertTrue(has(s, "Below cap by | 30"), s)
    end)
end)

test("r6 sm-04: stat, reputation and currency cells show their windows' tooltips, no session line", function()
    withAlt(function(rec)
        local s = hover(rec, altCell("stats_base", "strength"))
        assertEqual(rec[1], "Strength | 61", "the stat's title line")
        assertTrue(RT.Bar():IsShown() and math.abs(RT.Bar().geom.fill - 0.8) < 1e-9, "its bar")
        assertFalse(has(s, "Click") or has(s, "Scale:"), "no hint, no live scale: " .. s)
        local savedGains = SL.KindGainsFor
        SL.KindGainsFor = function() return 50 end   -- this character's log has gains: not the alt's
        s = hover(rec, altCell("reputations", "72"))
        SL.KindGainsFor = savedGains
        assertEqual(rec[1], "Stormwind", "the faction")
        assertTrue(has(s, "Standing | Honored") and has(s, "Progress | 3,000 / 12,000"), s)
        assertFalse(has(s, "This session"), "no session line for an alt")
        s = hover(rec, altCell("currencies", "1901"))
        assertTrue(has(s, "Amount | 1,200") and has(s, "Cap | 75,000"), s)
    end)
end)

test("r6 sm-04: the main window's own tooltip keeps its bonuses, session and hint lines", function()
    local e = { key = "leatherworking", name = "Leatherworking", category = "primary", rank = 146, max = 150,
                modifier = 0, tempPoints = 0, learned = true }
    local live, alt = {}, {}
    for _, l in ipairs(RT.Lines(e, "skill", "row")) do live[#live + 1] = l.left or "" end
    for _, l in ipairs(RT.Lines(e, "skill", "none", { level = 22, faction = "Alliance", race = "Dwarf" })) do
        alt[#alt + 1] = l.left or ""
    end
    assertTrue(has(table.concat(live, "\n"), "Bonuses"), "the main window's")
    assertFalse(has(table.concat(alt, "\n"), "Bonuses"), "the alt's")
end)

test("r6 sm-04: an alt's next rank and trainer are asked for that character's level, faction and race", function()
    withAlt(function(rec)
        local Tr = NS.Trainers
        local saved, asked = Tr.NextRank, nil
        Tr.NextRank = function(self, ...) asked = { ... } return saved(self, ...) end
        local ok, err = pcall(hover, rec, altCell("primary", "leatherworking"))
        Tr.NextRank = saved
        if not ok then error(err, 0) end
        assertEqual(table.concat({ tostring(asked[4]), tostring(asked[5]), tostring(asked[6]) }, ","),
            "22,Alliance,Dwarf", "the alt's level, faction and race token")
    end)
end)

test("r6 sm-04: a snapshot keeps the race's token beside its localized name", function()
    local keys, savedChars, savedRace = NS.db.keys, NS.db.global.characters, M.UnitRace
    local char, realm = keys.char, keys.realm
    NS.db.global.characters = {}
    keys.char, keys.realm = "Samplenain Mockbeard", "Samplerealm"
    M.UnitRace = function() return "Nain", "Dwarf" end
    local ok, err = pcall(function()
        local r = NS.Alts:Snapshot(10)
        assertTrue(r ~= nil, "a record")
        assertEqual(r.race, "Nain", "the name, as before")
        assertEqual(r.raceFile, "Dwarf", "and the token")
    end)
    M.UnitRace = savedRace
    keys.char, keys.realm = char, realm
    NS.db.global.characters = savedChars
    if not ok then error(err, 0) end
end)

test("r6 review: a repaint under a hovered Alts cell redraws its tooltip, or hides it for a cell with none", function()
    withAlt(function(rec)
        local cell = altCell("primary", "leatherworking")
        hover(rec, cell)
        for i = #rec, 1, -1 do rec[i] = nil end
        NS.db.global.characters[ALT_KEY].skills.leatherworking.rank = 147
        J.Render()   -- a snapshot change, a scroll: the pooled cell is re-bound under the pointer
        assertTrue(M.GameTooltip:IsShown(), "still shown")
        assertTrue(has(table.concat(rec, "\n"), "147"), "redrawn from the new row: " .. table.concat(rec, "\n"))
        NS.db.global.characters[ALT_KEY].skills.leatherworking = nil
        J.Render()
        assertFalse(M.GameTooltip:IsShown(), "the cell has no row now: no tooltip left over")
    end)
end)
