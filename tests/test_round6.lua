-- tests/test_round6.lua — the owner's round-6 feedback (2026-11-13): the toasts in the cap toast's
-- look, test mode's cues on the Journal and the LDB tooltip, the header marks at one size and one
-- vertical center, the sort mark's menu and every block expanded on a new profile.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local A = NS.Alerts

local function entry(key, name, kind, rank, max)
    return { key = key, name = name, category = kind == "weapon" and "weapon" or "primary", kind = kind,
             rank = rank, max = max, tempPoints = 0, modifier = 0, learned = true }
end

--- The real toast library on a fresh instance, alerts settings for the case, then everything back.
local function withToast(settings, fn)
    local savedToast, savedAlerts, savedSkill, savedLevel = A.toast, NS.db.profile.alerts, NS.SkillData, M.UnitLevel
    M.UnitLevel = function() return 22 end   -- a weapon cap of 110
    NS.db.profile.alerts = { cap = true, weapon = true, weaponGap = 25, sound = false, point = false, skillUp = true }
    for k, v in pairs(settings or {}) do NS.db.profile.alerts[k] = v end
    A.Reset()
    A.toast = A.NewToast()
    local ok, err = pcall(fn)
    A.toast:Clear()
    A.toast, NS.db.profile.alerts, NS.SkillData, M.UnitLevel = savedToast, savedAlerts, savedSkill, savedLevel
    A.Reset()
    if not ok then error(err, 0) end
end

local function hexOf(token)
    local r, g, b = NS.Skin.Color(token)
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

-- ── R6-1: the gap and skill-up toasts in the cap toast's look ────────────────────────────────

test("round6 toast: the gap and skill-up toasts wear the cap toast's skin shell, no tint or edge of their own", function()
    local daggers = entry("daggers", "Daggers", "weapon", 74, 110)
    withToast(nil, function()
        A.CheckGap(daggers)
        local gap = A.toast:FrameFor("weapon:daggers")
        assertTrue(gap ~= nil, "the gap toast is up")
        A.CheckSkillUp(entry("bows", "Bows", "weapon", 81, 110))
        local up = A.toast:FrameFor("skillup")
        assertTrue(up ~= nil, "the skill-up toast is up")
        for _, f in ipairs({ gap, up }) do
            assertTrue(not (f.skmTint and f.skmTint:IsShown()), "no kind tint over the skin's background")
            for _, t in ipairs(f.skmEdges or {}) do assertFalse(t:IsShown(), "no kind edge over the skin's border") end
            -- A recorder on the icon's SetSize (the kit records frame geometry only on opt-in), then
            -- the toast drawn again.
            local w
            rawset(f.skmIcon, "SetSize", function(_, width) w = width end)
            A.Build(f, f.skmPayload)
            rawset(f.skmIcon, "SetSize", nil)
            assertEqual(w, A.ICON, "the cap toast's icon size")
        end
    end)
end)

test("round6 toast: the value stays red or green and carries its delta in brackets", function()
    local daggers = entry("daggers", "Daggers", "weapon", 74, 110)
    withToast(nil, function()
        A.CheckGap(daggers)
        local f = A.toast:FrameFor("weapon:daggers")
        local bad = hexOf("sem.bad")
        assertEqual(f.skmTitle:GetText(), "Daggers " .. bad .. "74 / 110 (-36)|r")
        assertTrue(f.skmLabel:GetText():find(bad, 1, true) == 1, "the small label keeps its semantic color")
        A.CheckSkillUp(entry("bows", "Bows", "weapon", 81, 110))
        f = A.toast:FrameFor("skillup")
        assertEqual(f.skmTitle:GetText(), "Bows " .. hexOf("sem.good") .. "81 / 110 (+1)|r")
    end)
end)

test("round6 toast: test mode's gap and skill-up toasts take the same look", function()
    NS.Preview.Apply(true)
    local ok, err = pcall(function()
        local byKey = {}
        for _, t in ipairs(A.TestToasts()) do byKey[t.key] = t.payload end
        assertTrue(byKey["test:weapon"] ~= nil and byKey["test:skillup"] ~= nil, "the sample draws both")
        withToast(nil, function()
            for _, key in ipairs({ "test:weapon", "test:skillup" }) do
                A.toast:Show(byKey[key], { key = key, sticky = true })
                local f = A.toast:FrameFor(key)
                assertTrue(f ~= nil, key .. " is up")
                assertTrue(not (f.skmTint and f.skmTint:IsShown()), key .. ": no kind tint")
                assertTrue(f.skmTitle:GetText():find("%(%p%d+%)|r$") ~= nil, key .. ": the delta in brackets")
            end
        end)
    end)
    NS.Preview.Apply(false)
    if not ok then error(err, 0) end
end)
