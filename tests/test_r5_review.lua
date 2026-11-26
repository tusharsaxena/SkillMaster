-- tests/test_r5_review.lua — the independent review of the round 5 addendum A1 branch (R5-SM-08..12; Ka0sAddonsCommonTasks
-- docs/2026-11-26-OWNER_FEEDBACK_ROUND5/A1_SKILLMASTER_MORE.md). Each case pins one confirmed finding (R5-REV).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual
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
