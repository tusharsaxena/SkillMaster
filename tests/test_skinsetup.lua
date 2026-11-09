-- tests/test_skinsetup.lua — the skin owner (skinning): registration, the stored choice, the verb.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("skin: this addon is a registered owner wearing its stored choice", function()
    local lib = M.LibStub("LibKa0s-Skin-1.0")
    assertTrue(lib:IsOwner("SkillMaster"), "RegisterOwner ran at load")
    local source, skin = lib:GetChoice("SkillMaster")
    local s2, k2 = NS.SkinChoice()
    assertEqual(source .. ":" .. skin, s2 .. ":" .. k2)
end)

test("skin: writing the skin row applies it through the owner", function()
    NS.SetByPath("skin.skin", "ka0s")
    local _, skin = M.LibStub("LibKa0s-Skin-1.0"):GetChoice("SkillMaster")
    assertEqual(skin, "ka0s")
    NS.SetByPath("skin.skin", NS.DEFAULT_SKIN)
end)

test("skin: the picker's preview is the test mode (skinning-§10)", function()
    local spec = NS.SkinPickerSpec()
    assertEqual(spec.preview.mode, "test")
    spec.preview.enter()
    assertTrue(NS.IsTestMode(), "enter turns test mode on")
    spec.preview.exit()
    assertTrue(not NS.IsTestMode(), "exit turns it off")
end)

test("skin: /skm skin opens the library's picker", function()
    local real, seen = NS.Helpers.SkinVerb, nil
    NS.Helpers.SkinVerb = function(spec) seen = spec return {}, nil end
    NS.Slash:OnSlash("skin")
    NS.Helpers.SkinVerb = real
    assertTrue(seen ~= nil and seen.owner == "SkillMaster", "the verb handed the library this owner's spec")
end)
