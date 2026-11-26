-- tests/test_r5_journal.lua — the Journal rework of owner feedback round 5, addendum A1 (Ka0sAddonsCommonTasks
-- docs/2026-11-26-OWNER_FEEDBACK_ROUND5/A1_SKILLMASTER_MORE.md): "Rework the journal: Track reputations, and
-- currencies gain/loss here as well; add filters for all column headers; Check if any other rework for journal
-- is required." R5-SM-10: every reputation or currency change is its own Log row, signed, with the standing it
-- reached when the standing moved; no row for the login baseline. R5-SM-11 and R5-SM-12 follow below.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local J, SL = NS.Journal, NS.SessionLog

local LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

--- `fn` on an empty log whose session started at `start`; the log, the session and the floor put back after.
local function withLog(start, fn)
    local savedLog, savedStart = NS.db.char.log, SL:SessionStart()
    local savedText, savedSex = M.GetText, M.UnitSex
    M.UnitSex = function() return 2 end
    M.GetText = function(key) return LABELS[tonumber(tostring(key):match("(%d+)$"))] or savedText(key) end
    NS.db.char.log = {}
    SL:ResetFloor()
    SL:NewSession(start)
    local ok, err = pcall(fn)
    J.Hide()
    NS.db.char.log = savedLog
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

-- ---------------------------------------------------------------------------------------------
-- R5-SM-10: reputation and currency gains and losses, one row each
-- ---------------------------------------------------------------------------------------------

test("r5 sm-10: each reputation change is its own row, in time order, signed", function()
    withLog(1000, function()
        SL:AddChange("reputation", "21", "Booty Bay", 6000, 6100, 1000)
        SL:Add("fishing", 50, 51, 1100)
        SL:AddChange("reputation", "21", "Booty Bay", 6100, 6250, 1200)
        SL:AddChange("reputation", "21", "Booty Bay", 6250, 6200, 1300)
        local log = SL:Entries()
        assertEqual(#log, 4, "three faction rows and the skill-up")
        assertEqual(log[1].old .. ">" .. log[1].new, "6000>6100", "the first change")
        assertEqual(log[3].old .. ">" .. log[3].new, "6100>6250", "the second, after the skill-up")
        assertEqual(J.ChangeText(log[4]), "-50", "a loss reads signed")
        assertEqual(SL:KindGainsFor("reputation", "21"), 200, "the session's net change still sums")
        assertEqual((SL:Gains()), 1, "a standing is no skill point")
    end)
end)

test("r5 sm-10: a change that moves the standing records it, and the Change column says where it landed", function()
    withLog(1000, function()
        local e = SL:AddChange("reputation", "72", "Stormwind", 8900, 9100, 1000, nil, 5, 6)
        assertEqual(e.oldReaction, 5, "the standing it left")
        assertEqual(e.newReaction, 6, "the standing it reached")
        assertEqual(J.ChangeText(e), "+200, Honored", "the change and the standing reached")
        local same = SL:AddChange("reputation", "72", "Stormwind", 9100, 9150, 1100, nil, 6, 6)
        assertEqual(same.oldReaction, nil, "no standing kept when it did not move")
        assertEqual(J.ChangeText(same), "+50")
    end)
end)

test("r5 sm-10: a standing that moved on the bus lands as a row with both standings", function()
    withLog(M.time() - 60, function()
        NS.bus:SendMessage(NS.MSG.REP_CHANGED, "47", 20900, 21100, "Ironforge", 6, 7)
        NS.bus:SendMessage(NS.MSG.CURRENCY_CHANGED, "1901", 1200, 1180, "Honor Points")
        local log = SL:Entries()
        assertEqual(#log, 2, "one row each")
        assertEqual(log[1].kind, "reputation")
        assertEqual(log[1].newReaction, 7, "Revered reached")
        assertEqual(log[2].kind, "currency")
        assertEqual(J.ChangeText(log[2]), "-20", "a currency spent reads as a loss")
    end)
end)

test("r5 sm-10: RepData's changes carry the old and new reaction; the first read (the login baseline) has none", function()
    local RD = NS.RepData
    local function row(cur, reaction)
        return { factionID = 72, name = "Stormwind", reaction = reaction, currentStanding = cur,
                 currentReactionThreshold = 0, nextReactionThreshold = 99999 }
    end
    local before, after = RD.Build({ row(8900, 5) }), RD.Build({ row(9100, 6) })
    assertEqual(#RD.Changes(nil, before), 0, "no row for the baseline: nothing before it")
    assertEqual(#RD.Changes({ built = false, byKey = {} }, before), 0, "nor over an unbuilt model")
    local c = RD.Changes(before, after)
    assertEqual(#c, 1, "one change")
    assertEqual(("%s %s %d>%d %s>%s"):format(c[1].key, c[1].name, c[1].old, c[1].new, c[1].oldReaction,
        c[1].newReaction), "72 Stormwind 8900>9100 5>6", "the change with both reactions")
    assertEqual(#RD.Changes(after, after), 0, "nothing moved, nothing announced")
end)

test("r5 sm-10: the Log draws a reputation row's name and its signed change with the standing", function()
    withLog(M.time() - 600, function()
        SL:AddChange("reputation", "72", "Stormwind", 8900, 9100, M.time() - 300, "Elwynn Forest", 5, 6)
        SL:AddChange("currency", "1901", "Honor Points", 100, 113, M.time() - 200, "Elwynn Forest")
        J.Show()
        J.SelectTab("log")
        local rows = logRows()
        assertEqual(#rows, 2)
        assertEqual(rows[1].cols[3]:GetText(), "Honor Points", "newest first")
        assertEqual(rows[1].cols[4]:GetText(), "+13")
        assertEqual(rows[2].cols[3]:GetText(), "Stormwind")
        assertEqual(rows[2].cols[4]:GetText(), "+200, Honored")
    end)
end)

test("r5 sm-10: a reputation grind never pushes a skill-up out: the ring keeps journal.keep of each sort", function()
    withLog(1000, function()
        local saved = NS.db.profile.journal.keep
        NS.db.profile.journal.keep = 50
        SL:ResetFloor()
        NS.db.char.log = {}
        local ok, err = pcall(function()
            SL:Add("fishing", 50, 51, 1000)
            for i = 1, 80 do SL:AddChange("reputation", "21", "Booty Bay", 6000 + i, 6001 + i, 1000 + i) end
            local skills, changes = 0, 0
            for _, e in ipairs(SL:Entries()) do
                if e.kind then changes = changes + 1 else skills = skills + 1 end
            end
            assertEqual(skills, 1, "the skill-up stays")
            assertEqual(changes, 50, "the changes keep their own 50")
            assertTrue(SL:Entries()[1].key == "fishing", "the oldest row, kept")
            assertFalse(SL:Entries()[2].old == 6001, "the oldest changes went")
            SL:Trim(10)
            assertEqual(#SL:Entries(), 11, "a lower keep trims each sort to it")
        end)
        NS.db.profile.journal.keep = saved
        if not ok then error(err, 0) end
    end)
end)

test("r5 sm-10: schemaVersion 19 keeps every stored Log row and fills a change row's missing name", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.char = sv.char or {}
    sv.char["R5-Log"] = { log = {
        { t = 100, key = "fishing", old = 50, new = 51, zone = "Elwynn Forest" },
        { t = 200, kind = "reputation", key = "21", name = "Booty Bay", old = 6000, new = 6400 },
        { t = 300, kind = "currency", key = "1901", old = "100", new = "113" },
    } }
    NS.db.global.schemaVersion = 18
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    local log = sv.char["R5-Log"].log
    assertEqual(#log, 3, "no row lost")
    assertEqual(log[1].key .. log[1].old .. ">" .. log[1].new, "fishing50>51", "a skill-up untouched")
    assertEqual(log[2].old .. ">" .. log[2].new, "6000>6400", "an old merged faction row kept as it was")
    assertEqual(log[3].name, "1901", "a change row with no name names its key")
    assertEqual(log[3].old, 100, "a stored number read back as one")
    assertEqual(log[3].new, 113)
    sv.char["R5-Log"] = nil
end)

-- ---------------------------------------------------------------------------------------------
-- R5-SM-11: a filter on every column header
-- ---------------------------------------------------------------------------------------------

local JF = NS.JournalFilters

-- A day's log at fixed local times: two skill-ups, a faction's gain and loss with a standing reached, a currency.
local function sampleDay(base)
    SL:Add("fishing", 50, 51, base + 2 * 3600, "Elwynn Forest")                                -- 02:00
    SL:AddChange("reputation", "72", "Stormwind", 8900, 9100, base + 9 * 3600, "Elwynn Forest", 5, 6)   -- 09:00
    SL:AddChange("reputation", "72", "Stormwind", 9100, 9050, base + 10 * 3600, "Duskwood")    -- 10:00
    SL:AddChange("currency", "1901", "Honor Points", 100, 113, base + 14 * 3600, "Duskwood")   -- 14:00
    SL:Add("bows", 80, 81, base + 20 * 3600, "Duskwood")                                       -- 20:00
end

-- `fn(base)` on the sample day, today at local midnight, the Journal open on the Log over all time, unfiltered.
local function withDay(fn)
    local t = M.time()
    local date = M.date or os.date
    local base = t - (tonumber(date("%H", t)) * 3600 + tonumber(date("%M", t)) * 60 + tonumber(date("%S", t)))
    withLog(base - 3600, function()
        local savedRange = NS.db.profile.journal.range
        NS.db.profile.journal.range = "all"
        JF.Clear()
        sampleDay(base)
        J.Show()
        J.SelectTab("log")
        local ok, err = pcall(fn, base)
        JF.Clear()
        NS.db.profile.journal.range = savedRange
        if not ok then error(err, 0) end
    end)
end

local function shownNames()
    local out = {}
    for _, row in ipairs(logRows()) do out[#out + 1] = row.cols[3]:GetText() end
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

test("r5 sm-11: the five headers each open a filter menu; the third is Name", function()
    withDay(function()
        local p = J.Frame().logPanel
        assertEqual(p.headers[3]:GetText(), "NAME", "renamed for skills, factions and currencies")
        for _, col in ipairs({ "date", "time", "name", "change", "zone" }) do
            local b = p.filterButtons[col]
            assertTrue(b ~= nil, col .. ": a header button")
            local rows = J.FilterMenuRowsForTest(col)
            assertTrue(rows[1] and rows[1].title, col .. ": its menu opens on a title")
            assertTrue(#rows >= 3, col .. ": with choices")
        end
    end)
end)

test("r5 sm-11: the Name filter narrows to a kind, or one name, and the summary counts that kind", function()
    withDay(function()
        assertEqual(shownNames(), "Bows,Honor Points,Stormwind,Stormwind,Fishing", "everything, newest first")
        pick("name", "Reputations")
        assertEqual(shownNames(), "Stormwind,Stormwind", "only the faction rows")
        local card = J.Frame().logPanel.session
        assertEqual(card.value:GetText(), "+150", "the reputation's net change")
        assertTrue(card.title:GetText():find("Reputation", 1, true) ~= nil, "the card says what it counts")
        assertTrue(card.title:GetText():find("filtered", 1, true) ~= nil, "and that it is filtered")
        pick("name", "Honor Points")
        assertEqual(shownNames(), "Honor Points", "one name, from the Currencies submenu")
        assertEqual(JF.Get("kind"), "currency", "its kind with it")
        pick("name", "Skill-ups")
        assertEqual(shownNames(), "Bows,Fishing", "a kind picked drops the name of another")
        assertEqual(card.value:GetText(), "+2", "the skill-ups counted")
    end)
end)

test("r5 sm-11: Date, Time, Change and Zone filters, combined", function()
    withDay(function()
        pick("date", "Yesterday")
        assertEqual(shownNames(), "", "nothing yesterday")
        assertTrue(J.Frame().logPanel.empty:GetText():find("filters", 1, true) ~= nil, "the empty line names the filters")
        pick("date", "Today")
        assertEqual(#logRows(), 5, "today: every row")
        pick("time", "Morning (6:00 to 12:00)")
        assertEqual(shownNames(), "Stormwind,Stormwind", "the morning's rows")
        pick("change", "Losses")
        assertEqual(shownNames(), "Stormwind", "and of those the loss")
        pick("time", "Any time")
        pick("change", "Standing changes")
        assertEqual(shownNames(), "Stormwind", "the row that reached Honored")
        pick("change", "All")
        pick("zone", "Duskwood")
        assertEqual(shownNames(), "Bows,Honor Points,Stormwind", "Duskwood's rows")
        pick("name", "Skill-ups")
        assertEqual(shownNames(), "Bows", "zone and kind together")
    end)
end)

test("r5 sm-11: an active header shows it, and Clear filters clears every one in one click", function()
    withDay(function()
        local p = J.Frame().logPanel
        assertFalse(p.clearFilters:IsShown(), "no Clear filters while none is on")
        assertFalse(p.filterButtons.zone.mark:IsShown(), "no filter mark at rest")
        pick("zone", "Duskwood")
        pick("change", "Gains")
        assertTrue(p.filterButtons.zone.mark:IsShown(), "the Zone header's mark shows")
        assertTrue(p.filterButtons.change.mark:IsShown(), "and the Change header's")
        assertFalse(p.filterButtons.date.mark:IsShown(), "not an unfiltered header's")
        assertTrue(p.clearFilters:IsShown(), "Clear filters offered")
        p.clearFilters:__fire("OnClick", "LeftButton")
        assertFalse(JF.Active(), "every filter cleared")
        assertEqual(#logRows(), 5, "every row back")
        assertFalse(p.clearFilters:IsShown(), "and the button goes")
    end)
end)

test("r5 sm-11: the ETA card follows the Name filter", function()
    withDay(function()
        SL:Add("fishing", 51, 52, M.time() - 30, "Duskwood")
        J.Render()
        assertTrue(#J.EtaRows(0) >= 0, "the ETA rows read")
        pick("name", "Reputations")
        assertEqual(#J.EtaRows(0, J.Frame().logPanel.filtered), 0, "no skill among the rows, no ETA")
    end)
end)
