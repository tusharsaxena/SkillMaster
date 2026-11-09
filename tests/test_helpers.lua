-- tests/test_helpers.lua — the gathering and fishing helpers: skinnable mob level, minable and
-- herbable nodes, a zone's fishing need, the weapon-skill cap (plan Task 2.4).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

test("test_helpers_skinnable_level: 122 -> 24, 100 -> 20, 50 -> 15, 1 -> 10", function()
    local H = NS.SkillHelpers
    assertEqual(H.SkinnableLevel(122), 24)
    assertEqual(H.SkinnableLevel(100), 20)
    assertEqual(H.SkinnableLevel(50), 15)
    assertEqual(H.SkinnableLevel(1), 10)
end)

test("test_helpers_fishing_need_unknown_nil: a zone the table lacks answers nil", function()
    assertNil(NS.SkillHelpers.FishingNeed("Nowhere In Particular"))
    assertNil(NS.SkillHelpers.FishingNeed(nil))
end)

test("helpers: FishingNeed answers the getaway-free skill for a known zone", function()
    local H = NS.SkillHelpers
    assertEqual(H.FishingNeed("Elwynn Forest"), 25)
    assertEqual(H.FishingNeed("Westfall"), 75)
    assertEqual(H.FishingNeed("Stranglethorn Vale"), 225)
    assertEqual(H.FishingNeed("Silithus"), 425)
end)

test("helpers: FishingNeed prefers the uiMapID over the name", function()
    assertEqual(NS.SkillHelpers.FishingNeed("a localized name", 1436), 75)
end)

test("helpers: Nodes lists what the rank can gather and the next node up", function()
    local r = NS.SkillHelpers.Nodes("mining", 130)
    local got = {}
    for _, n in ipairs(r.gatherable) do got[n.name] = true end
    assertTrue(got["Copper Vein"] and got["Tin Vein"] and got["Iron Deposit"], "130 mines iron")
    assertTrue(not got["Gold Vein"], "gold wants 155")
    assertEqual(r.next.name, "Indurium Mineral Vein")
    assertEqual(r.next.need, 150)
end)

test("helpers: Nodes at the top has no next node, and an unknown key answers nil", function()
    local r = NS.SkillHelpers.Nodes("herbalism", 300)
    assertNil(r.next)
    assertEqual(r.gatherable[#r.gatherable].name, "Black Lotus")
    assertNil(NS.SkillHelpers.Nodes("tailoring", 100))
end)

test("helpers: WeaponCap is five per level", function()
    assertEqual(NS.SkillHelpers.WeaponCap(22), 110)
    assertEqual(NS.SkillHelpers.WeaponCap(60), 300)
end)

test("helpers: FishingNeedHere reads the map ID first, then the zone text", function()
    M.C_Map = M.C_Map or {}
    local saved = M.C_Map.GetBestMapForUnit
    M.C_Map.GetBestMapForUnit = function() return 1434 end
    assertEqual(NS.SkillHelpers.FishingNeedHere(), 225)
    M.C_Map.GetBestMapForUnit = function() return nil end
    M.__context.zone = "Feralas"
    assertEqual(NS.SkillHelpers.FishingNeedHere(), 300)
    M.C_Map.GetBestMapForUnit = saved
end)
