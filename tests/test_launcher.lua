-- tests/test_launcher.lua — one LDB object, registered on enable, its menu onto the verbs' handlers.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("launcher: the object is the brand, the 128 px logo, registered once OnEnable runs", function()
    NS.db.profile.skin.pickerSeen = true
    NS.addon:OnEnable()
    assertTrue(NS.Launcher:IsRegistered(), "registered")
    local obj = NS.Launcher:Object()
    assertEqual(obj.label, "Ka0s Skill Master")
    assertEqual(obj.icon, NS.Constants.LOGO_ICON_PATH)
    assertEqual(obj.type, "launcher")
end)

test("launcher: left-click opens the settings panel through the same opener as /sm config", function()
    local real, opened = NS.OpenOptionsPanel, 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    NS.Launcher:Object().OnClick(nil, "LeftButton")
    NS.OpenOptionsPanel = real
    assertEqual(opened, 1)
end)
