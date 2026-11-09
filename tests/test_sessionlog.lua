-- tests/test_sessionlog.lua — SessionLog: the per-character ring of skill-ups, the session gains, the
-- rate and the per-skill ETA (design §5.2, plan Task 4.3).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNear = T.test, T.assertEqual, T.assertTrue, T.assertNear
local SL = NS.SessionLog

--- Answer `ranks[key]` as the model's entry for the length of `fn`.
local function withModel(ranks, fn)
    local real = NS.SkillData.Get
    NS.SkillData.Get = function(_, key)
        local r = ranks[key]
        if not r then return nil end
        return { key = key, rank = r[1], max = r[2], learned = true }
    end
    local ok, err = pcall(fn)
    NS.SkillData.Get = real
    if not ok then error(err, 0) end
end

test("test_sessionlog_ring_cap: the log keeps the newest 500 skill-ups in db.char.log", function()
    SL:Clear()
    for i = 1, SL.CAP + 10 do SL:Add("bows", i, i + 1, 1000 + i) end
    local log = SL:Entries()
    assertEqual(#log, SL.CAP, "capped at 500")
    assertEqual(log[1].old, 11, "the ten oldest went first")
    assertEqual(log[#log].new, SL.CAP + 11, "the newest is last")
    assertTrue(NS.db.char.log == log, "the ring lives in db.char.log")
    SL:Clear()
    assertEqual(#SL:Entries(), 0, "Clear empties it")
end)

test("test_sessionlog_eta: (max - rank) / the skill's own rate over this session's gains", function()
    SL:Clear()
    SL:NewSession(1000)
    SL:Add("skinning", 99, 100, 900)    -- before the session: not counted
    SL:Add("skinning", 100, 101, 1000)
    SL:Add("skinning", 101, 102, 1060)
    SL:Add("skinning", 102, 103, 1120)
    SL:Add("fishing", 50, 51, 1100)     -- one gain: no rate yet
    withModel({ skinning = { 103, 150 }, fishing = { 51, 75 }, bows = { 150, 150 } }, function()
        -- two points over 120 s is one point a minute; 47 to go is 47 minutes.
        assertNear(SL:ETA("skinning"), 47 * 60, 1e-6)
        assertEqual(SL:ETA("fishing"), nil, "fewer than two gains has no ETA")
        assertEqual(SL:ETA("unknown"), nil, "no gains, no ETA")
    end)
    SL:Add("bows", 148, 149, 1130)
    SL:Add("bows", 149, 150, 1140)
    withModel({ bows = { 150, 150 } }, function()
        assertEqual(SL:ETA("bows"), 0, "a skill at its cap is there")
    end)
    SL:Clear()
end)

test("sessionlog: Gains counts points this session, per skill too; Rate is points an hour", function()
    SL:Clear()
    SL:NewSession(10000)
    SL:Add("bows", 79, 80, 9000)
    SL:Add("bows", 80, 81, 10100)
    SL:Add("fishing", 106, 108, 10200)   -- a two-point jump in one scan
    local total, byKey = SL:Gains()
    assertEqual(total, 3)
    assertEqual(byKey.bows, 1)
    assertEqual(byKey.fishing, 2)
    -- 3 points in the session's 1800 s is 6 an hour; the last 1650 s hold only fishing's 2.
    assertNear(SL:Rate(3600, 11800), 6, 1e-6)
    assertNear(SL:Rate(1650, 11800), 2 / 1650 * 3600, 1e-6)
    assertEqual(SL:Rate(3600, 10000), 0, "no time has passed")
    SL:Clear()
end)

test("sessionlog: a SKILL_UP on the bus lands in the log with the zone", function()
    SL:Clear()
    local zone = M.__context.zone
    M.__context.zone = "Loch Modan"
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "bows", 80, 81)
    M.__context.zone = zone
    local log = SL:Entries()
    assertEqual(#log, 1)
    assertEqual(log[1].key, "bows")
    assertEqual(log[1].old, 80)
    assertEqual(log[1].new, 81)
    assertEqual(log[1].zone, "Loch Modan")
    assertTrue(type(log[1].t) == "number", "stamped with the clock")
    SL:Clear()
end)

test("sessionlog: a malformed skill-up is refused, never stored", function()
    SL:Clear()
    assertEqual(SL:Add(nil, 1, 2), nil)
    assertEqual(SL:Add("bows", 1, "x"), nil)
    assertEqual(#SL:Entries(), 0)
end)
