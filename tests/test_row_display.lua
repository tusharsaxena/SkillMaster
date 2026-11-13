-- tests/test_row_display.lua — Rows show (bars.rowDisplay, feedback round 1 FB-3): one setting for
-- skill rows and stat rows alike, in all three modes, on the window's rows (the detached blocks
-- lay the same rows, NS.Blocks.LayRows) and the broker tooltip's lines; and the schemaVersion 2
-- step that moves a stored stats.display onto it once.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local FISHING = { key = "fishing", name = "Fishing", category = "secondary", rank = 107, max = 150,
                  modifier = 25, tempPoints = 0, learned = true }
local AGILITY = { key = "agility", label = "Agility", value = 112, display = "112", pct = 60, markers = {} }

local function withMode(mode, fn)
    NS.SetByPath("bars.rowDisplay", mode)
    local pool = NS.Rows.NewPool()
    local ok, err = pcall(fn, NS.Rows.Acquire(pool, M.UIParent, "row"))
    NS.Rows.ReleaseAll(pool)
    NS.SetByPath("bars.rowDisplay", NS.defaults.profile.bars.rowDisplay)
    if not ok then error(err, 0) end
end

test("rows show: one setting on the Bars page's Text tab, and stats.display is gone", function()
    local found, old
    for _, row in ipairs(NS.Schema) do
        if row.path == "bars.rowDisplay" then found = row end
        if row.path == "stats.display" then old = row end
    end
    assertTrue(found ~= nil, "bars.rowDisplay has a row")
    assertEqual(found.page, "bars")
    assertEqual(found.group, NS.L["Text"])
    assertEqual(#found.values, 3)
    assertTrue(old == nil, "stats.display has no row")
    assertTrue(NS.defaults.profile.stats.display == nil, "nor a default")
    assertEqual(NS.defaults.profile.bars.rowDisplay, "both")
end)

test("rows show: Bar and value draws a skill row's bar and its text, and a stat row's", function()
    withMode("both", function(row)
        row:SetSkill(FISHING)
        assertTrue(row.bar:IsShown(), "the skill's bar")
        assertFalse(row.where:IsShown())
        assertEqual(row.bar.text:GetText(), "107 +25 / 150")
        row:SetStat(AGILITY)
        assertTrue(row.bar:IsShown(), "the stat's bar")
        assertFalse(row.where:IsShown())
        assertEqual(row.bar.text:GetText(), "112")
    end)
end)

test("rows show: Bar only draws the bar with no text, for skills and stats", function()
    withMode("bar", function(row)
        row:SetSkill(FISHING)
        assertTrue(row.bar:IsShown())
        assertEqual(row.bar.text:GetText(), "", "a skill bar says nothing")
        assertFalse(row.where:IsShown())
        row:SetStat(AGILITY)
        assertTrue(row.bar:IsShown())
        assertEqual(row.bar.text:GetText(), "", "a stat bar says nothing")
    end)
end)

test("rows show: Value only draws the value in the bar's place, for skills and stats", function()
    withMode("text", function(row)
        row:SetSkill(FISHING)
        assertFalse(row.bar:IsShown(), "no skill bar")
        assertTrue(row.where:IsShown())
        assertEqual(row.where:GetText(), "107 +25 / 150", "the skill's text, by the bar text template")
        NS.SetByPath("bars.textTemplate", "{rank} / {max}")
        row:SetSkill(FISHING)
        assertEqual(row.where:GetText(), "107 / 150", "the template still shapes it")
        NS.SetByPath("bars.textTemplate", NS.defaults.profile.bars.textTemplate)
        row:SetStat(AGILITY)
        assertFalse(row.bar:IsShown(), "no stat bar")
        assertEqual(row.where:GetText(), "112")
        -- Back to both: the same pooled row draws its bar again and drops the value line.
        NS.SetByPath("bars.rowDisplay", "both")
        row:SetSkill(FISHING)
        assertTrue(row.bar:IsShown())
        assertFalse(row.where:IsShown())
    end)
end)

test("rows show: an unlearned skill keeps its trainer line in every mode", function()
    local unlearned = { key = "swords", name = "Swords", category = "weapon", rank = 0, max = 0,
                        modifier = 0, tempPoints = 0, learned = false }
    for _, mode in ipairs({ "both", "bar", "text" }) do
        withMode(mode, function(row)
            row:SetSkill(unlearned)
            assertFalse(row.bar:IsShown(), mode)
            assertTrue(row.where:IsShown(), mode)
            assertTrue(row.where:GetText():find(NS.L["Not learned"], 1, true) ~= nil, mode)
        end)
    end
end)

-- ── the broker tooltip's lines ───────────────────────────────────────────────────────────────

local function recordingTip()
    local tip = M.CreateFrame("GameTooltip", "SkillMasterRowsShowTip", M.UIParent)
    tip.lines = {}
    function tip:GetName() return "SkillMasterRowsShowTip" end
    function tip:NumLines() return #self.lines end
    function tip:ClearLines() self.lines = {} end
    local function region(n)
        local name = "SkillMasterRowsShowTipTextLeft" .. n
        _G[name] = _G[name] or M.CreateFrame("Frame", name, tip)
    end
    function tip:AddLine(text) self.lines[#self.lines + 1] = { text } region(#self.lines) end
    function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end
    return tip
end

local function publish()
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, {
        byKey = { fishing = FISHING }, order = { primary = {}, secondary = { "fishing" }, weapon = {}, other = {} },
    })
    NS.bus:SendMessage(NS.MSG.STATS_UPDATED, { base = { AGILITY }, spell = {}, defense = {}, utility = {} })
end

--- The right-hand text of the line whose left text names `name`.
local function valueOf(tip, name)
    for _, l in ipairs(tip.lines) do
        if l[2] ~= nil and tostring(l[1]):find(name, 1, true) then return l[2] end
    end
end

test("rows show: the broker tooltip's skill and stat lines honor it", function()
    M.__fireTimers()
    publish()
    local B = NS.Broker
    local want = { both = { bars = 1, value = true }, bar = { bars = 1, value = false },
                   text = { bars = 0, value = true } }
    -- One section at a time, so the bar count is that line's: Secondary (Fishing) on the skills feed,
    -- then Base & Combat on the stats feed (round 6, R6-9).
    local sections = NS.db.profile.broker.tooltip.sections
    local all, saved = {}, {}
    for _, id in ipairs(B.SECTIONS) do all[#all + 1] = id end
    for _, id in ipairs(B.STAT_SECTIONS) do all[#all + 1] = id end
    for _, id in ipairs(all) do saved[id] = sections[id] end
    for _, mode in ipairs({ "both", "bar", "text" }) do
        NS.SetByPath("bars.rowDisplay", mode)
        for _, section in ipairs({ "secondary", "stats_base" }) do
            for _, id in ipairs(all) do sections[id] = id == section end
            local tip = recordingTip()
            B.FillTooltip(tip, section == "stats_base" and "stats" or "skills")
            local name = section == "stats_base" and "Agility" or "Fishing"
            local value = valueOf(tip, name)
            assertEqual(B.BarsDrawn(), want[mode].bars, mode .. " " .. section .. ": mini bars")
            assertEqual(value ~= nil and value ~= "", want[mode].value, mode .. " " .. section .. ": value "
                .. tostring(value))
        end
    end
    for _, id in ipairs(all) do sections[id] = saved[id] end
    B.FillTooltip(recordingTip(), "skills")
    NS.SetByPath("bars.rowDisplay", NS.defaults.profile.bars.rowDisplay)
end)

-- ── the schemaVersion 2 step ─────────────────────────────────────────────────────────────────

test("rows show: schemaVersion 2 moves a stored stats.display once, in every stored profile", function()
    local sv = rawget(_G, "SkillMasterDB")   -- the raw SavedVariables the runner walks
    assertTrue(type(sv) == "table", "the SavedVariables table")
    sv.profiles = sv.profiles or {}
    sv.profiles["RowsShow-Text"] = { stats = { display = "text", hidden = {} } }
    sv.profiles["RowsShow-Bar"] = { stats = { display = "bar" }, bars = { height = 18 } }
    sv.profiles["RowsShow-Both"] = { stats = { display = "both" } }
    sv.profiles["RowsShow-Kept"] = { stats = { display = "text" }, bars = { rowDisplay = "bar" } }
    sv.profiles["RowsShow-Fresh"] = {}
    NS.db.global.schemaVersion = 1
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION, "the runner reaches the code's target")
    local p = sv.profiles
    assertEqual(p["RowsShow-Text"].bars.rowDisplay, "text", "a non-active profile is reached")
    assertTrue(p["RowsShow-Text"].stats.display == nil, "the old key goes")
    assertEqual(p["RowsShow-Bar"].bars.rowDisplay, "bar")
    assertEqual(p["RowsShow-Bar"].bars.height, 18, "the rest of bars is kept")
    assertTrue(p["RowsShow-Both"].bars == nil, "the default moves nothing")
    assertTrue(p["RowsShow-Both"].stats.display == nil)
    assertEqual(p["RowsShow-Kept"].bars.rowDisplay, "bar", "a stored rowDisplay wins")
    assertTrue(next(p["RowsShow-Fresh"]) == nil, "a fresh profile passes through unchanged")
    -- Once: the stamp is past the step, so a stats.display written back later is not moved again.
    p["RowsShow-Both"].stats.display = "text"
    NS:RunMigrations()
    assertEqual(p["RowsShow-Both"].stats.display, "text", "the step ran once")
    for _, k in ipairs({ "RowsShow-Text", "RowsShow-Bar", "RowsShow-Both", "RowsShow-Kept", "RowsShow-Fresh" }) do
        p[k] = nil
    end
end)

-- The verifier's case: AceDB copies the default "both" into the ACTIVE profile's stored table, so a
-- step that moved only into an absent key would skip it and drop the player's choice.
test("rows show: schemaVersion 2 moves the active profile's stats.display past the copied default", function()
    local p = NS.db.profile
    p.stats.display = "text"
    assertEqual(p.bars.rowDisplay, "both", "the copied default is present before the step")
    NS.db.global.schemaVersion = 1
    NS:RunMigrations()
    assertEqual(p.bars.rowDisplay, "text", "the active profile's choice moved")
    assertTrue(p.stats.display == nil, "the old key goes")
    p.bars.rowDisplay = "both"
end)
