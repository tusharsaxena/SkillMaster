-- tests/test_journal.lua — the Journal window (design §6.4): its standalone-window chrome, the two
-- tabs, the Log list with its range picker and side cards (FB-32), the alts matrix with its mini
-- bars, characters across and a sub-tab per main-window block (FB-33), and `/sm journal`.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local J, SL = NS.Journal, NS.SessionLog

local function forgetAll()
    for key in pairs(NS.db.global.characters) do NS.db.global.characters[key] = nil end
end

local function activeRows(p)
    local out = {}
    for _, row in ipairs(p.pool.active) do out[#out + 1] = row end
    return out
end

test("journal: /sm journal toggles it, through the one toggle handler", function()
    J.Hide()
    NS.Slash:OnSlash("journal")
    assertTrue(J.IsShown(), "shown")
    NS.Slash:OnSlash("journal")
    assertFalse(J.IsShown(), "hidden again")
end)

test("journal: the chrome is the shared one: the title, the wrapped close control, the window tier", function()
    J.Show()
    local f = J.Frame()
    assertEqual(f.title:GetText(), "Skill Master \194\183 Journal")
    assertTrue(f.close ~= nil, "the close control was built through NS.MakeCloseButton")
    assertEqual(f:GetFrameStrata(), NS.Constants.LAYERS.STRATA.WINDOW)
    local found = false
    for _, name in ipairs(M.UISpecialFrames) do if name == J.FRAME_NAME then found = true end end
    assertTrue(found, "Escape closes the Journal (UISpecialFrames)")
    J.Hide()
end)

test("journal: the tabs switch panels: Log first, then Alts", function()
    J.Show()
    J.SelectTab("log")
    local f = J.Frame()
    assertEqual(f.tabs.log.text:GetText(), "Log", "the whole log, not a session log (FB-32)")
    assertTrue(f.logPanel:IsShown() and not f.altsPanel:IsShown(), "the log tab shows its panel")
    assertTrue(J.SelectTab("alts"))
    assertTrue(f.altsPanel:IsShown() and not f.logPanel:IsShown(), "the alts tab shows its panel")
    assertFalse(J.SelectTab("nope"), "an unknown tab is refused")
    assertEqual(J.SelectedTab(), "alts")
    J.SelectTab("log")
    J.Hide()
end)

test("journal: the log lists skill-ups newest first, with the session's gains, and Clear empties it", function()
    SL:Clear()
    SL:NewSession(M.time() - 600)
    SL:Add("bows", 80, 81, M.time() - 300, "Loch Modan")
    SL:Add("fishing", 106, 107, M.time() - 200, "Loch Modan")
    J.Show()
    J.SelectTab("log")
    local p = J.Frame().logPanel
    local rows = activeRows(p)
    assertEqual(#rows, 2)
    assertEqual(rows[1].entry.key, "fishing", "newest first")
    assertEqual(rows[1].cols[4]:GetText(), "106 -> 107")
    assertEqual(rows[1].cols[5]:GetText(), "Loch Modan")
    assertEqual(p.session.value:GetText(), "+2")
    assertFalse(p.empty:IsShown(), "no empty state with entries")
    p.clear:GetScript("OnClick")(p.clear)
    M.StaticPopupDialogs.SKILLMASTER_CLEAR_LOG.OnAccept()   -- the confirmation (review F-005)
    assertEqual(#SL:Entries(), 0, "Clear log cleared the store")
    assertEqual(#activeRows(p), 0, "and the list")
    assertTrue(p.empty:IsShown(), "the empty state shows")
    J.Hide()
end)

test("journal: a SKILLS_UPDATED repaints an open log", function()
    SL:Clear()
    J.Show()
    J.SelectTab("log")
    SL:Add("bows", 81, 82)
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, NS.SkillData:Model())
    assertEqual(#activeRows(J.Frame().logPanel), 1)
    SL:Clear()
    J.Hide()
end)

local function twoAlts()
    NS.db.global.characters["PvE-Ember Ironsong"] = {
        name = "Ember Ironsong", class = "HUNTER", className = "Hunter", race = "Dwarf", level = 22,
        skills = { leatherworking = { name = "Leatherworking", category = "primary", rank = 146, max = 150 },
                   bows = { name = "Bows", category = "weapon", rank = 80, max = 110 } },
    }
    NS.db.global.characters["PvE-Quill Ashbrook"] = {
        name = "Quill Ashbrook", class = "WARRIOR", className = "Warrior", race = "Human", level = 41,
        skills = { mining = { name = "Mining", category = "primary", rank = 212, max = 225 } },
    }
end

--- The column index of character `key` in the open Alts tab.
local function columnOf(p, key)
    for c, item in ipairs(p.list) do if item.key == key then return c end end
end

local function rowOf(p, key)
    for _, row in ipairs(activeRows(p)) do if row.key == key then return row end end
end

test("journal: the alts matrix has a column per character, a row per skill, a mini bar per skill it has", function()
    -- red under: the pre-FB-33 grid, a row per character and a column per skill
    forgetAll()
    twoAlts()
    J.Show()
    J.SelectTab("alts")
    J.SelectFilter("primary")
    local p = J.Frame().altsPanel
    -- Every primary profession shows (owner feedback round 4: unlearned rows too), Bows does not.
    local primaries = 0
    for _, cat in pairs(NS.SkillCatalog) do if cat.category == "primary" then primaries = primaries + 1 end end
    assertEqual(#p.rows, primaries, "Primary lists every profession, learned or not, and not Bows")
    local c = columnOf(p, "PvE-Ember Ironsong")
    assertTrue(c ~= nil and p.heads[c]:IsShown(), "a column per character")
    local lw, mining = rowOf(p, "leatherworking"), rowOf(p, "mining")
    assertEqual(lw.label:GetText(), "Leatherworking", "the row's label is the skill")
    assertEqual(lw.cells[c].value:GetText(), "146/150")
    assertTrue(lw.cells[c].bar:IsShown(), "a mini bar for a skill it has")
    assertTrue(math.abs(lw.cells[c].bar.geom.fill - 146 / 150) < 1e-9, "the shared bar widget draws it (NS.Bar)")
    assertTrue(lw.cells[c].bar.style.key == "mini" and not lw.cells[c].bar.style.showText, "the mini style: no text")
    assertTrue(mining.cells[c].unlearned:IsShown() and not mining.cells[c].value:IsShown()
        and not mining.cells[c].dash:IsShown(), "Unlearned for a profession it has not (round 4)")
    assertEqual(mining.cells[c].unlearned:GetText(), "Unlearned")
    assertFalse(lw.cells[3].value:IsShown() or lw.cells[3].dash:IsShown(), "no third character: an empty column")
    J.SelectFilter("weapon")
    -- The hunter's and the warrior's trainable weapons (NS.ClassWeapons_Forever), Riding excluded.
    local weapons = {}
    for _, cls in ipairs({ "HUNTER", "WARRIOR" }) do
        for _, k in ipairs(NS.ClassWeapons_Forever[cls]) do
            if NS.SkillCatalog[k].category == "weapon" then weapons[k] = true end
        end
    end
    local nWeapons = 0
    for _ in pairs(weapons) do nWeapons = nWeapons + 1 end
    assertEqual(#p.rows, nWeapons, "Weapon Skills lists every weapon either character can train")
    local wands = false
    for _, k in ipairs(p.rows) do if k == "wands" then wands = true end end
    assertFalse(wands, "no Wands: neither a hunter nor a warrior trains them")
    local bows, cq = rowOf(p, "bows"), columnOf(p, "PvE-Quill Ashbrook")
    assertTrue(bows.cells[cq].unlearned:IsShown(), "the warrior can train Bows: Unlearned")
    J.SelectFilter("other")
    local lock = false
    for _, k in ipairs(p.rows) do if k == "lockpicking" then lock = true end end
    assertFalse(lock, "no Lockpicking without a rogue")
    assertFalse(J.SelectFilter("nope"))
    J.SelectFilter("primary")
    J.SelectTab("log")
    J.Hide()
    forgetAll()
end)

test("journal: the alts sub-tabs are the main window's blocks, in its order", function()
    -- red under: the three Professions / Weapons / Other chips
    assertEqual(table.concat(J.FILTER_ORDER, ","), table.concat(NS.BLOCKS, ","))
    J.Show()
    local p = J.Frame().altsPanel
    for _, id in ipairs(NS.BLOCKS) do assertTrue(p.chips[id] ~= nil, "a chip for " .. id) end
    assertEqual(p.chips.stats_defense.text:GetText(), "Defense & Resists")
    local right = 0
    for _, chip in pairs(p.chips) do
        local _, _, _, x = chip:GetPoint(1)
        right = math.max(right, (x or 0) + chip:GetWidth())
    end
    assertTrue(right <= J.MIN_W - 24, "the eight chips fit the panel at the default width: " .. right)
    J.Hide()
end)

test("journal: a stats sub-tab lists every stat of its block; a snapshot without stats reads a dash", function()
    -- red under: alts snapshots without stats, or a stats tab built from the snapshots alone
    forgetAll()
    twoAlts()
    NS.db.global.characters["PvE-Ember Ironsong"].stats = {
        strength = { group = "base", value = 88, display = "88", pct = 60 },
    }
    J.Show()
    J.SelectTab("alts")
    J.SelectFilter("stats_base")
    local p = J.Frame().altsPanel
    local want = 0
    for _, def in ipairs(NS.STAT_DEFS) do if def.group == "base" then want = want + 1 end end
    local keys = J.AltRows(p.list, "stats_base")
    assertEqual(#keys, want, "every Base & Combat stat the main window's block reads")
    local str = rowOf(p, "strength")
    local ember, quill = columnOf(p, "PvE-Ember Ironsong"), columnOf(p, "PvE-Quill Ashbrook")
    assertEqual(str.label:GetText(), "Strength")
    assertEqual(str.cells[ember].value:GetText(), "88")
    assertTrue(str.cells[ember].bar:IsShown(), "a stat it has draws a mini bar")
    assertTrue(math.abs(str.cells[ember].bar.geom.fill - 0.6) < 1e-9, "at the stat's own scale (pct)")
    assertTrue(str.cells[quill].dash:IsShown(), "an old snapshot with no stats: a dash")
    J.SelectFilter("primary")
    J.SelectTab("log")
    J.Hide()
    forgetAll()
end)

test("journal: a character's name is two lines in its column; the rest is the header's tooltip", function()
    -- red under: the whole name on one line wider than the column, or no header tooltip
    assertEqual(select(1, J.NameLines("Ember Ironsong", "PvE")), "Ember")
    assertEqual(select(2, J.NameLines("Ember Ironsong", "PvE")), "Ironsong")
    local one, two, isRealm = J.NameLines("Zug", "PvP")
    assertTrue(one == "Zug" and two == "PvP" and isRealm, "a one-word name sits over its realm")
    assertEqual(J.RealmOf("PvE-Ember Ironsong", "Ember Ironsong"), "PvE")
    forgetAll()
    twoAlts()
    J.Show()
    J.SelectTab("alts")
    local p = J.Frame().altsPanel
    local head = p.heads[columnOf(p, "PvE-Ember Ironsong")]
    assertEqual(head.line1:GetText(), "Ember")
    assertEqual(head.line2:GetText(), "Ironsong")
    assertTrue(head.line1:GetWidth() <= J.COL_W and not head.line1:CanWordWrap(), "truncated to the column")
    local lines = {}
    rawset(M.GameTooltip, "AddLine", function(_, s) lines[#lines + 1] = s end)
    head:GetScript("OnEnter")(head)
    rawset(M.GameTooltip, "AddLine", nil)
    head:GetScript("OnLeave")(head)
    assertFalse(M.GameTooltip:IsShown(), "and the tooltip goes with the pointer")
    local all = table.concat(lines, "|")
    assertTrue(all:find("Ember Ironsong", 1, true) ~= nil, "the whole name: " .. all)
    assertTrue(all:find("Lv 22 Dwarf Hunter", 1, true) ~= nil, "level, race and class: " .. all)
    assertTrue(all:find("Realm: PvE", 1, true) ~= nil, "the realm: " .. all)
    J.SelectTab("log")
    J.Hide()
    forgetAll()
end)

test("journal: right-click on a character's name asks before forgetting it", function()
    forgetAll()
    NS.db.global.characters["PvE-Tamsin Reedwhistle"] = { name = "Tamsin Reedwhistle", level = 17, skills = {} }
    J.Show()
    J.SelectTab("alts")
    local head = J.Frame().altsPanel.heads[1]
    M.__popups = {}
    head:GetScript("OnMouseUp")(head, "RightButton")
    assertEqual(M.__popups[1], "SKILLMASTER_FORGET_ALT")
    M.StaticPopupDialogs.SKILLMASTER_FORGET_ALT.OnAccept(nil, "PvE-Tamsin Reedwhistle")
    assertTrue(NS.db.global.characters["PvE-Tamsin Reedwhistle"] == nil, "forgotten on accept")
    J.SelectTab("log")
    J.Hide()
end)

test("journal: an unlocked drag saves the drop point; Reset position forgets it", function()
    J.Show()
    local f = J.Frame()
    local realGetPoint = f.GetPoint
    f.GetPoint = function() return "TOPLEFT", M.UIParent, "TOPLEFT", 12, -34 end
    f:GetScript("OnDragStop")(f)
    f.GetPoint = realGetPoint
    local p = NS.db.profile.journal.point
    assertEqual(p and p.x, 12)
    J.ResetPosition()
    assertFalse(NS.db.profile.journal.point, "forgotten")
    J.Hide()
end)

test("journal: the stand-down hides it", function()
    J.Show()
    NS.SetByPath("enabled", false)
    assertFalse(J.IsShown(), "hidden by the stand-down")
    assertFalse(J.Show(), "and Show refuses while stood down")
    NS.SetByPath("enabled", true)
end)

test("journal: durations and ETAs read as the mockup writes them", function()
    assertEqual(J.FormatDuration(6720), "1 h 52 m")
    assertEqual(J.FormatDuration(300), "5 m")
    assertEqual(J.FormatETA(1800), "~30 m")
    assertEqual(J.FormatETA(5 * 3600), "~5 h")
    assertEqual(J.FormatETA(nil), nil)
end)

-- ── FB-32: the Log tab ───────────────────────────────────────────────────────────────────────

local DAY = 86400

--- A log over five days of history and this session, the range stored as `range`.
local function history(range)
    local now = M.time()
    SL:Clear()
    SL:NewSession(now - 600)
    SL:Add("bows", 70, 71, now - 40 * DAY, "Elwynn Forest")      -- all time only
    SL:Add("bows", 71, 72, now - 10 * DAY, "Elwynn Forest")      -- 30 days
    SL:Add("bows", 72, 73, now - 5 * DAY, "Westfall")            -- 7 days
    SL:Add("bows", 73, 74, now - 2 * DAY, "Westfall")            -- 3 days
    SL:Add("fishing", 106, 107, now - 3600, "Loch Modan")       -- 1 day
    SL:Add("fishing", 107, 108, now - 300, "Loch Modan")        -- this session
    SL:Add("fishing", 108, 110, now - 200, "Loch Modan")        -- this session
    NS.SetByPath("journal.range", range)
end

test("journal: the Log has a Date column beside the time, and every column keeps to its width", function()
    -- red under: the four columns (Time, Skill, Change, Zone) with no date
    history("all")
    J.Show()
    J.SelectTab("log")
    local p = J.Frame().logPanel
    local heads = {}
    for i, fs in ipairs(p.headers) do heads[i] = fs:GetText() end
    assertEqual(table.concat(heads, ","), "Date,Time,Skill,Change,Zone")
    local rows = activeRows(p)
    local oldest = rows[#rows]
    assertEqual(oldest.cols[1]:GetText(), os.date("%m/%d/%y", oldest.entry.t), "the date")
    assertEqual(oldest.cols[2]:GetText(), os.date("%H:%M", oldest.entry.t), "and the time apart")
    for i, fs in ipairs(oldest.cols) do
        assertFalse(fs:CanWordWrap(), "column " .. i .. " truncates rather than wraps")
        if i ~= 3 then assertTrue(fs:GetWidth() > 0, "column " .. i .. " has a fixed width") end
    end
    -- At the default width the fixed columns leave the Skill column room (the list is 414 wide).
    local list = J.MIN_W - 24 - 190 - 12
    assertTrue(98 + (70 + 100 + 14) < list - 80, "the Skill column keeps 80 px or more")
    NS.SetByPath("journal.range", "session")
    SL:Clear()
    J.Hide()
end)

test("journal: the range picker narrows the Log and its summary; the choice is stored per profile", function()
    -- red under: a Log that lists every entry and sums this session whatever the range
    local want = { session = { 2, 3 }, ["1d"] = { 3, 4 }, ["3d"] = { 4, 5 }, ["7d"] = { 5, 6 },
                   ["30d"] = { 6, 7 }, all = { 7, 8 } }
    J.Show()
    J.SelectTab("log")
    local p = J.Frame().logPanel
    assertTrue(p.range ~= nil and type(p.range.SetOptions) == "function", "a LibKa0s dropdown")
    for _, range in ipairs(J.RANGE_ORDER) do
        history("session")
        assertTrue(J.SelectRange(range), range)
        assertEqual(NS.db.profile.journal.range, range, "stored in the profile")
        assertEqual(#activeRows(p), want[range][1], range .. ": the rows in range")
        assertEqual(p.session.value:GetText(), "+" .. want[range][2], range .. ": the points in range")
        assertEqual(p.range.text:GetText(), J.RangeLabel(range), range .. ": the picker shows it")
    end
    -- The card says what it counts (owner feedback round 4: "+78 / 38.4 skill-ups / day" read as noise).
    assertEqual(p.session.title:GetText(), "Skill-ups \194\183 All time")
    assertTrue(p.session.rate:GetText():find("^Average: [%d.]+ a day over %d+ days?$") ~= nil, p.session.rate:GetText())
    assertFalse(J.SelectRange("nope"), "an unknown range is refused")
    -- The picker's own pick goes the same way.
    p.range.onSelect("7d")
    assertEqual(NS.db.profile.journal.range, "7d")
    assertEqual(#activeRows(p), 5)
    NS.SetByPath("journal.range", "session")
    SL:Clear()
    J.Hide()
end)

test("journal: the range is a schema row on the Journal page with the six choices", function()
    local row
    for _, r in ipairs(NS.Schema) do if r.path == "journal.range" then row = r end end
    assertTrue(row ~= nil, "a schema row")
    assertEqual(row.page, "journal")
    assertEqual(row.default, "all", "All time by default (owner feedback round 4)")
    local vals = {}
    for i, v in ipairs(row.values) do vals[i] = v.value end
    assertEqual(table.concat(vals, ","), "session,1d,3d,7d,30d,all")
end)

test("journal: the ETA note wraps inside its card", function()
    -- red under: a one-line note wider than the card (no width, no wrap)
    SL:Clear()
    J.Show()
    J.SelectTab("log")
    local card = J.Frame().logPanel.eta
    assertTrue(card.none:IsShown(), "no ETA yet: the note shows")
    assertTrue(card.none:CanWordWrap(), "it wraps")
    assertTrue(card.none:GetWidth() > 0 and card.none:GetWidth() <= 190 - 20, "inside the card's padding")
    J.Hide()
end)

-- ── FB-33: the Alts tab's leftovers and the resize grip ──────────────────────────────────────

test("journal: schemaVersion 5 turns a stored pre-FB-33 filter into its block", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["Round3-Old"] = { journal = { filter = "weapons" } }
    sv.profiles["Round3-Pro"] = { journal = { filter = "professions" } }
    sv.profiles["Round3-Other"] = { journal = { filter = "other" } }
    local saved = NS.db.global.schemaVersion
    NS.db.global.schemaVersion = 4
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION, "the runner reaches the newest step")
    assertEqual(sv.profiles["Round3-Old"].journal.filter, "weapon", "Weapons is the Weapon Skills block")
    assertEqual(sv.profiles["Round3-Pro"].journal.filter, "primary", "Professions opens on Primary")
    assertEqual(sv.profiles["Round3-Other"].journal.filter, "other", "Other is a block id already")
    sv.profiles["Round3-Old"], sv.profiles["Round3-Pro"], sv.profiles["Round3-Other"] = nil, nil, nil
    NS.db.global.schemaVersion = saved
end)

test("journal: a grab pins the window by its top-left, and the release saves that point with the size", function()
    -- red under: StartSizing on a CENTER-anchored frame (the default place), which grows the
    -- window about its center, two pixels a pixel, and reads as a leap
    NS.db.profile.journal.point, NS.db.profile.journal.size = false, false
    J.Show()
    local f = J.Frame()
    local points = {}
    rawset(f, "GetLeft", function() return 300 end)
    rawset(f, "GetTop", function() return 700 end)
    rawset(f, "SetPoint", function(_, ...) points[#points + 1] = { ... } end)
    rawset(f, "GetPoint", function() return "TOPLEFT", M.UIParent, "BOTTOMLEFT", 300, 700 end)
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    local pin = points[#points]
    assertEqual(f.__sizingCount > 0 and pin and pin[1], "TOPLEFT", "pinned by its top-left before sizing")
    assertTrue(pin[2] == M.UIParent and pin[3] == "BOTTOMLEFT" and pin[4] == 300 and pin[5] == 700,
        "where it stood")
    f:__setGeom(700, 480)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    for _, k in ipairs({ "GetLeft", "GetTop", "SetPoint", "GetPoint" }) do rawset(f, k, nil) end
    local saved = NS.db.profile.journal.point
    assertTrue(saved and saved.point == "TOPLEFT" and saved.relPoint == "BOTTOMLEFT", "the drop point follows")
    assertEqual(NS.db.profile.journal.size and NS.db.profile.journal.size.w, 700)
    NS.db.profile.journal.point, NS.db.profile.journal.size = false, false
    J.ResetPosition()
    J.Hide()
end)

test("journal: a saved size beyond the screen comes back on it; a wider window shows more characters", function()
    J.Show()
    local f = J.Frame()
    local sizes = {}
    rawset(f, "SetSize", function(_, w, h) sizes[#sizes + 1] = w .. "x" .. h end)
    M.UIParent:__setGeom(1600, 900)
    NS.db.profile.journal.size = { w = 4000, h = 3000 }
    J.ApplySize()
    rawset(f, "SetSize", nil)
    M.UIParent.__geomLive = nil
    assertEqual(sizes[1], "1600x900", "clamped to the screen")
    assertEqual(J.VisibleAltCols(), J.MAX_COLS, "as many characters as fit, up to the built columns")
    J.Relayout(J.MIN_W, J.MIN_H)
    assertEqual(J.VisibleAltCols(), 5, "five at the default width")
    NS.db.profile.journal.size = false
    J.Hide()
end)

-- ── owner feedback round 4 ───────────────────────────────────────────────────────────────────

test("journal: the Log table scrolls by a bar that shows only while it overflows", function()
    -- red under: a table scrolled by the wheel alone, nothing on screen saying there is more
    local now = M.time()
    SL:Clear()
    SL:NewSession(now - 600)
    NS.SetByPath("journal.range", "all")
    J.Show()
    J.SelectTab("log")
    local p = J.Frame().logPanel
    assertFalse(p.scroll:IsShown(), "an empty log: no bar")
    for i = 1, J.VisibleLogRows() + 10 do SL:Add("bows", i, i + 1, now - 500 + i, "Westfall") end
    J.Render()
    assertTrue(p.scroll:IsShown(), "more rows than fit: the bar shows")
    assertEqual(p.scroll.maxOffset, 10)
    p.scroll:GetScript("OnValueChanged")(p.scroll, 4)
    assertEqual(p.scroll.offset, 4, "a drag scrolls the table")
    assertEqual(activeRows(p)[1].entry.new, J.VisibleLogRows() + 10 - 4 + 1, "four rows down from the newest")
    assertEqual(p.headers[5]:GetWidth(), 150, "the Zone column is 150 px wide")
    SL:Clear()
    J.Hide()
end)

test("journal: the Alts table scrolls by a bar too", function()
    forgetAll()
    twoAlts()
    J.Show()
    J.SelectTab("alts")
    J.SelectFilter("weapon")
    local p = J.Frame().altsPanel
    local over = #p.rows - J.VisibleAltRows()
    assertTrue(over > 0, "the default size overflows Weapon Skills for a hunter and a warrior")
    assertTrue(p.scroll:IsShown())
    assertEqual(p.scroll.maxOffset, over)
    p.scroll:GetScript("OnValueChanged")(p.scroll, 1)
    assertEqual(activeRows(p)[1].key, p.rows[2], "one row down")
    J.SelectFilter("primary")
    J.SelectTab("log")
    J.Hide()
    forgetAll()
end)
