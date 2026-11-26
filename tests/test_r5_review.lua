-- tests/test_r5_review.lua — the independent review of the round 5 addendum A1 branch (R5-SM-08..12; Ka0sAddonsCommonTasks
-- docs/2026-11-26-OWNER_FEEDBACK_ROUND5/A1_SKILLMASTER_MORE.md). Each case pins one confirmed finding (R5-REV).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local SL = NS.SessionLog

--- `fn` on an empty log, journal.keep at `keep`; the log, the keep and the floor put back after.
local function withKeep(keep, fn)
    local savedLog, savedKeep = NS.db.char.log, NS.db.profile.journal.keep
    NS.db.profile.journal.keep = keep
    NS.db.char.log = {}
    SL:ResetFloor()
    local ok, err = pcall(fn)
    NS.db.char.log, NS.db.profile.journal.keep = savedLog, savedKeep
    SL:ResetFloor()
    if not ok then error(err, 0) end
end

local function counts()
    local skills, changes = 0, 0
    for _, e in ipairs(SL:Entries()) do
        if e.kind then changes = changes + 1 else skills = skills + 1 end
    end
    return skills, changes
end

-- R5-REV: the floor (what the log held at a session's first write) was the whole log's length but bounded each
-- sort, so every login let the reputation rows grow by the skill-ups' count again: the ring never held its keep.
test("r5 review: the Log keeps journal.keep of each sort across sessions; a login never lets one sort grow", function()
    withKeep(50, function()
        for i = 1, 50 do SL:Add("fishing", i, i + 1, 1000 + i) end
        for i = 1, 50 do SL:AddChange("reputation", "21", "Booty Bay", i, i + 1, 2000 + i) end
        assertEqual(select(2, counts()), 50, "the first session holds 50 changes")
        for session = 1, 3 do
            SL:ResetFloor()   -- a /reload or the next login: the floor is taken again at the first write
            for i = 1, 60 do SL:AddChange("reputation", "21", "Booty Bay", i, i + 1, 3000 + session * 100 + i) end
        end
        local skills, changes = counts()
        assertEqual(skills, 50, "the skill-ups stay")
        assertEqual(changes, 50, "the changes stay at their keep, session after session")
    end)
end)

test("r5 review: a lower keep from a profile switch still never trims a sort below what it held", function()
    withKeep(50, function()
        for i = 1, 40 do SL:Add("fishing", i, i + 1, 1000 + i) end
        for i = 1, 30 do SL:AddChange("reputation", "21", "Booty Bay", i, i + 1, 2000 + i) end
        SL:ResetFloor()
        NS.db.profile.journal.keep = 10   -- the profile switch: no Trim call
        SL:Add("fishing", 99, 100, 5000)
        SL:AddChange("reputation", "21", "Booty Bay", 99, 100, 5001)
        local skills, changes = counts()
        assertEqual(skills, 40, "the skill-ups held at the session's first write")
        assertEqual(changes, 30, "the changes held, each sort its own floor")
    end)
end)

-- R5-REV: the open Journal repainted on a skill pass and a layout change only, so a reputation or currency row
-- logged while it showed stayed off the Log (and the Alts tab stale) until something else redrew it.
test("r5 review: the open Journal's Log shows a reputation or currency change as it lands", function()
    withKeep(500, function()
        local J = NS.Journal
        local savedRange = NS.db.profile.journal.range
        NS.db.profile.journal.range = "all"
        local ok, err = pcall(function()
            J.Show()
            J.SelectTab("log")
            local function names()
                local out = {}
                for _, row in ipairs(J.Frame().logPanel.pool.active) do
                    if row:IsShown() then out[#out + 1] = row.cols[4]:GetText() end
                end
                return table.concat(out, ",")
            end
            assertEqual(names(), "", "an empty Log")
            -- RepData's publish: REP_CHANGED (the log's row), then REPS_UPDATED.
            NS.bus:SendMessage(NS.MSG.REP_CHANGED, "72", 8900, 9100, "Stormwind", 5, 6)
            NS.bus:SendMessage(NS.MSG.REPS_UPDATED, nil)
            assertEqual(names(), "Stormwind", "the faction's row drawn at once")
            NS.bus:SendMessage(NS.MSG.CURRENCY_CHANGED, "1901", 100, 113, "Honor Points")
            NS.bus:SendMessage(NS.MSG.CURRENCIES_UPDATED, nil)
            assertTrue(names():find("Honor Points", 1, true) ~= nil, "and the currency's")
        end)
        J.Hide()
        NS.db.profile.journal.range = savedRange
        M.__fireTimers()
        if not ok then error(err, 0) end
    end)
end)

-- R5-REV: Yesterday was the calendar day of now minus 86400 s, which skips a day in the first hour after a
-- 23-hour (spring-forward) day: just after midnight on 9 March 2026 in a US zone it named 7 March. It is the
-- local calendar's day before now's (run with TZ=America/New_York to see the old reading fail).
test("r5 review: the Yesterday filter is the calendar's day before, across a daylight-saving change", function()
    local JF = NS.JournalFilters
    local now = os.time({ year = 2026, month = 3, day = 9, hour = 0, min = 30 })
    local ctx = { now = now, nameOf = function(e) return e.key end }
    local function at(day, hour) return { t = os.time({ year = 2026, month = 3, day = day, hour = hour }) } end
    JF.Clear()
    JF.Set("date", "yesterday")
    local ok, err = pcall(function()
        assertTrue(JF.Matches(at(8, 12), ctx), "8 March, noon: yesterday")
        assertTrue(JF.Matches(at(8, 23), ctx), "8 March, late: yesterday")
        assertTrue(not JF.Matches(at(7, 12), ctx), "7 March: the day before yesterday")
        assertTrue(not JF.Matches(at(9, 0), ctx), "9 March: today")
    end)
    JF.Clear()
    if not ok then error(err, 0) end
end)

-- R5-REV: a detached sub-category is stored on the profile (shared by every character by default), but the trees
-- differ per character: a faction header (Alliance on a Horde alt), a currency group the alt never earned, a header
-- renamed by another locale. Such a sub-category drew an empty window titled by its stored name, and docking it
-- there docked it for every character. Its window now stays hidden while the model read in full lacks the header,
-- its row kept, and a merged window leaves its section and its title part out.
test("r5 review: a detached sub-category this character's tree lacks shows no window, and keeps its row", function()
    local SB, D, G = NS.SubBlocks, NS.Detached, NS.Groups
    local layout = NS.db.profile.layout
    local savedSex, savedFaction = M.UnitSex, M.UnitFactionGroup
    M.UnitSex = function() return 2 end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    layout.subs, layout.groups = {}, {}
    if not NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    local ok, err = pcall(function()
        local here = SB.Detach("reputations", "469", "Alliance")
        local gone = SB.Detach("reputations", "67", "Horde")   -- another character's header: not in this tree
        M.__fireTimers()
        assertTrue(D.Frame(here) ~= nil and D.Frame(here):IsShown(), "a header the tree has: its window")
        assertTrue(D.Frame(gone) == nil or not D.Frame(gone):IsShown(), "a header it lacks: no window")
        assertTrue(layout.subs[gone] ~= nil, "its row kept for the character that has it")
        -- Merged with a header the tree has: no section and no title part for the absent one.
        local gid = G.Merge(gone, here, "bottom")
        M.__fireTimers()
        assertTrue(gid ~= nil, "the two merge")
        assertEqual(G.Title(gid), "Alliance", "the title names what draws")
        local f = G.Frame(gid)
        assertTrue(f.sections[here] ~= nil, "the present section draws")
        assertEqual(f.sections[gone], nil, "the absent one does not")
    end)
    layout.subs, layout.groups = {}, {}
    D.Refresh()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    M.UnitSex, M.UnitFactionGroup = savedSex, savedFaction
    M.__fireTimers()
    if not ok then error(err, 0) end
end)
