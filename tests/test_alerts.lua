-- tests/test_alerts.lua — Alerts (plan Task 4.2): the rank-cap toast and chat line, the weapon-gap
-- toast once per skill per session, the switches, the click that sets a waypoint, the stand-down.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local A = NS.Alerts

local function entry(key, name, kind, rank, max)
    return { key = key, name = name, category = kind == "weapon" and "weapon" or "primary", kind = kind,
             rank = rank, max = max, tempPoints = 0, modifier = 0, learned = true }
end

--- A recording toast: what was shown, and the keys.
local function recorder()
    local r = { shown = {}, cleared = 0, refreshed = 0 }
    function r.Show(_, payload, opts) r.shown[#r.shown + 1] = { payload = payload, key = opts and opts.key } return true end
    function r.Clear() r.cleared = r.cleared + 1 end
    function r.Refresh() r.refreshed = r.refreshed + 1 end
    return r
end

--- Install skills, a recording toast, settings and an empty print log; run fn; put everything back.
local function withAlerts(w, fn)
    local savedSkill, savedToast, savedWp = NS.SkillData, A.toast, NS.Waypoints
    local savedFaction, savedRace, savedLevel = M.UnitFactionGroup, M.UnitRace, M.UnitLevel
    local savedAlerts = NS.db.profile.alerts
    NS.db.profile.alerts = { cap = true, weapon = true, weaponGap = 25, sound = false, point = false }
    for k, v in pairs(w.settings or {}) do NS.db.profile.alerts[k] = v end
    local skills = w.skills or {}
    NS.SkillData = { Get = function(_, key) return skills[key] end, Enable = function() end,
                     Model = function() return w.model end }
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.UnitRace = function() return "Dwarf", "Dwarf" end
    M.UnitLevel = function() return w.level or 22 end
    NS.Waypoints = w.waypoints
    local toast = recorder()
    A.toast = toast
    A.Reset()
    local before = #M.__printed()
    local ok, err = pcall(fn, toast, skills, function()
        local out = {}
        local all = M.__printed()
        for i = before + 1, #all do out[#out + 1] = all[i] end
        return out
    end)
    NS.SkillData, A.toast, NS.Waypoints = savedSkill, savedToast, savedWp
    M.UnitFactionGroup, M.UnitRace, M.UnitLevel = savedFaction, savedRace, savedLevel
    NS.db.profile.alerts = savedAlerts
    A.Reset()
    if not ok then error(err, 0) end
end

local function lw(rank, max) return { leatherworking = entry("leatherworking", "Leatherworking", "craft", rank, max) } end

test("test_alerts_cap_once: reaching the cap toasts once with the next trainer, and says it in chat", function()
    withAlerts({ skills = lw(150, 150) }, function(toast, _, printed)
        A.OnSkillUp("leatherworking", 149, 150)
        A.OnSkillUp("leatherworking", 149, 150)
        assertEqual(#toast.shown, 1, "one toast for one cap")
        local p = toast.shown[1].payload
        assertEqual(p.kind, "cap")
        assertEqual(p.title, "Leatherworking 150 / 150 · Journeyman cap")
        assertTrue(p.detail:find("Train Expert (Lv 20): ", 1, true) == 1, p.detail)
        assertTrue(p.trainer and p.trainer.city == "Ironforge", "the Dwarf's home city trainer first")
        assertEqual(toast.shown[1].key, "cap:leatherworking:150")
        local lines = printed()
        assertEqual(#lines, 1, "one chat line")
        assertTrue(lines[1]:find("Leatherworking 150 / 150", 1, true) ~= nil, lines[1])
        assertTrue(lines[1]:find(p.trainer.name, 1, true) ~= nil, "the chat line names the trainer")
    end)
end)

test("alerts: the cap alert comes back for the next cap, never twice for one", function()
    withAlerts({ skills = lw(150, 150) }, function(toast, skills)
        A.OnSkillUp("leatherworking", 149, 150)
        skills.leatherworking = entry("leatherworking", "Leatherworking", "craft", 225, 225)
        A.OnSkillUp("leatherworking", 224, 225)
        A.OnSkillUp("leatherworking", 224, 225)
        assertEqual(#toast.shown, 2)
        assertEqual(toast.shown[2].key, "cap:leatherworking:225")
    end)
end)

test("alerts: no cap alert below the cap, at the top rank, or when switched off", function()
    withAlerts({ skills = lw(149, 150) }, function(toast, skills)
        A.OnSkillUp("leatherworking", 148, 149)
        assertEqual(#toast.shown, 0, "below the cap")
        skills.leatherworking = entry("leatherworking", "Leatherworking", "craft", 300, 300)
        A.OnSkillUp("leatherworking", 299, 300)
        assertEqual(#toast.shown, 0, "Artisan has no next rank")
    end)
    withAlerts({ skills = lw(150, 150), settings = { cap = false } }, function(toast, _, printed)
        A.OnSkillUp("leatherworking", 149, 150)
        assertEqual(#toast.shown, 0, "switched off")
        assertEqual(#printed(), 0)
    end)
end)

local function daggers(rank, max) return { daggers = entry("daggers", "Daggers", "weapon", rank, max) } end

test("test_alerts_weapon_gap_threshold: a weapon skill weaponGap or more below its cap toasts", function()
    withAlerts({ skills = daggers(74, 110) }, function(toast)
        A.OnSkillUp("daggers", 73, 74)
        assertEqual(#toast.shown, 1, "36 below")
        local p = toast.shown[1].payload
        assertEqual(p.kind, "weapon")
        assertEqual(p.gap, 36)
        assertEqual(p.title, "Daggers 74 / 110")
        assertEqual(toast.shown[1].key, "weapon:daggers")
    end)
    withAlerts({ skills = daggers(85, 110) }, function(toast)
        A.OnSkillUp("daggers", 84, 85)
        assertEqual(#toast.shown, 1, "exactly 25 below is at the threshold")
    end)
    withAlerts({ skills = daggers(86, 110) }, function(toast)
        A.OnSkillUp("daggers", 85, 86)
        assertEqual(#toast.shown, 0, "24 below is under it")
    end)
    withAlerts({ skills = daggers(86, 110), settings = { weaponGap = 20 } }, function(toast)
        A.OnSkillUp("daggers", 85, 86)
        assertEqual(#toast.shown, 1, "the threshold is the profile's")
    end)
end)

test("alerts: the weapon-gap toast shows once per skill per session, and not when switched off", function()
    withAlerts({ skills = daggers(74, 110) }, function(toast)
        A.OnSkillUp("daggers", 73, 74)
        A.OnSkillUp("daggers", 74, 75)
        assertEqual(#toast.shown, 1)
    end)
    withAlerts({ skills = daggers(74, 110), settings = { weapon = false } }, function(toast)
        A.OnSkillUp("daggers", 73, 74)
        assertEqual(#toast.shown, 0)
    end)
end)

test("alerts: a level-up raising a weapon cap checks every weapon; the first model checks none", function()
    local model = { byKey = {}, order = { primary = {}, secondary = {}, weapon = { "daggers", "bows" }, other = {} } }
    model.byKey.daggers = entry("daggers", "Daggers", "weapon", 80, 105)
    model.byKey.bows = entry("bows", "Bows", "weapon", 104, 105)
    withAlerts({ model = model }, function(toast)
        A.OnSkillsUpdated(model)
        assertEqual(#toast.shown, 0, "login is not a level-up")
        model.byKey.daggers = entry("daggers", "Daggers", "weapon", 80, 110)
        model.byKey.bows = entry("bows", "Bows", "weapon", 104, 110)
        A.OnSkillsUpdated(model)
        assertEqual(#toast.shown, 1, "Daggers 30 below; Bows 6 below")
        assertEqual(toast.shown[1].key, "weapon:daggers")
    end)
end)

test("alerts: the bus delivers SKILL_UP to the alerts", function()
    withAlerts({ skills = lw(150, 150) }, function(toast)
        NS.bus:SendMessage(NS.MSG.SKILL_UP, "leatherworking", 149, 150)
        assertEqual(#toast.shown, 1)
    end)
end)

test("alerts: clicking the cap toast sets a waypoint when Waypoints exists, else prints directions", function()
    local got
    local wp = { Set = function(_, trainer) got = trainer return "native" end }
    withAlerts({ skills = lw(150, 150), waypoints = wp }, function(toast, _, printed)
        A.OnSkillUp("leatherworking", 149, 150)
        local before = #printed()
        A.OnToastClick(toast.shown[1].payload)
        assertTrue(got == toast.shown[1].payload.trainer, "Set gets the trainer record")
        assertEqual(#printed(), before, "no directions printed")
    end)
    withAlerts({ skills = lw(150, 150) }, function(toast, _, printed)
        A.OnSkillUp("leatherworking", 149, 150)
        local before = #printed()
        A.OnToastClick(toast.shown[1].payload)
        local lines = printed()
        assertEqual(#lines, before + 1, "one directions line")
        assertTrue(lines[#lines]:find(toast.shown[1].payload.trainer.name, 1, true) ~= nil, lines[#lines])
    end)
    withAlerts({ skills = daggers(74, 110) }, function(toast, _, printed)
        A.OnSkillUp("daggers", 73, 74)
        local before = #printed()
        A.OnToastClick(toast.shown[1].payload)
        assertEqual(#printed(), before, "a weapon toast's click does nothing")
    end)
end)

test("alerts: the real toast draws the cap payload with the mockup's lines", function()
    withAlerts({ skills = lw(150, 150) }, function()
        A.toast = A.NewToast()
        A.OnSkillUp("leatherworking", 149, 150)
        local stats = A.toast:Stats()
        assertEqual(stats.visible, 1)
        local f = A.toast:Frame()
        assertEqual(f.skmTitle:GetText(), "Leatherworking 150 / 150 · Journeyman cap")
        assertTrue(f.skmHint:GetText():find("waypoint", 1, true) ~= nil)
        assertTrue(f.skmPayload.kind == "cap")
        A.toast:Clear()
    end)
end)

test("alerts: the stand-down clears the toast; a profile reload refreshes it", function()
    withAlerts({}, function(toast)
        A.StandDown()
        A.Refresh()
        assertEqual(toast.cleared, 1)
        assertEqual(toast.refreshed, 1)
    end)
end)

test("alerts: the defaults carry every alerts key", function()
    local d = NS.defaults.profile.alerts
    assertEqual(d.cap, true)
    assertEqual(d.weapon, true)
    assertEqual(d.weaponGap, 25)
    assertEqual(d.sound, false)
    assertEqual(d.point, false)
end)
