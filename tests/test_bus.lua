-- tests/test_bus.lua — the message catalog (architecture-§4).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local EXPECTED = {
    SKILLS_UPDATED = "Ka0s_SkillMaster_SkillsUpdated",
    SKILL_UP = "Ka0s_SkillMaster_SkillUp",
    STATS_UPDATED = "Ka0s_SkillMaster_StatsUpdated",
    BONUSES_UPDATED = "Ka0s_SkillMaster_BonusesUpdated",
    LAYOUT_CHANGED = "Ka0s_SkillMaster_LayoutChanged",
    SIM_TICK = "Ka0s_SkillMaster_SimTicked",
}

test("bus: the six messages are declared once, PascalCase on the wire", function()
    for key, wire in pairs(EXPECTED) do assertEqual(NS.MSG[key], wire, key) end
end)

test("bus: the catalog is strict, so a misspelled constant raises instead of going silent", function()
    local ok = pcall(function() return NS.MSG.SKILL_UPP end)
    assertTrue(not ok, "NS.MSG.SKILL_UPP answered instead of raising")
end)

test("bus: a subscriber on its own target receives a published message", function()
    local target = NS.NewBusTarget()
    local got
    target:RegisterMessage(NS.MSG.SKILL_UP, function(_, key, old, new) got = { key, old, new } end)
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "bows", 80, 81)
    assertEqual(got and table.concat(got, ","), "bows,80,81")
    target:UnregisterAllMessages()
end)
