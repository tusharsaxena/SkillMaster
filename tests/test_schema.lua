-- tests/test_schema.lua — the schema, the single write seam and the minimap row's inversion.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("schema: every row resolves against the defaults tree", function()
    assertEqual(NS.ValidateSchema(), 0)
end)

test("schema: every row carries a group, a label and a desc (options-ui-§13)", function()
    for _, row in ipairs(NS.Schema) do
        assertTrue(type(row.group) == "string", tostring(row.path) .. " has no group")
        assertTrue(type(row.label) == "string", tostring(row.path) .. " has no label")
        assertTrue(type(row.desc) == "string" or type(row.tooltip) == "string", tostring(row.path) .. " has no desc")
    end
end)

test("schema: the Master controls come first, General visibility omitted, Test mode present", function()
    local paths = {}
    for i, row in ipairs(NS.Schema) do paths[row.path] = i end
    assertEqual(paths.enabled, 1, "Enable Skill Master opens the General page")
    assertTrue(paths.visibility == nil, "no General visibility row: the window is opened by the player")
    assertTrue(paths["state.testMode"] ~= nil, "Test mode row")
    assertTrue(paths[NS.Constants.MINIMAP_PATH] ~= nil, "Minimap button row")
end)

test("schema: a write through the seam lands in the profile and reaches its reaction", function()
    NS.SetByPath("scale", 1.5)
    assertEqual(NS.db.profile.scale, 1.5)
    assertEqual(NS.GetSetting("scale"), 1.5)
    NS.SetByPath("scale", 1)
end)

test("schema: the minimap row says SHOWN while LibDBIcon's stored key says hidden (launcher-§3)", function()
    NS.SetByPath(NS.Constants.MINIMAP_PATH, false)
    assertTrue(NS.db.global.minimap.hide == true, "hide stored")
    assertFalse(NS.GetSetting(NS.Constants.MINIMAP_PATH))
    assertTrue(NS.db.global.minimap.shown == nil, "no `shown` twin is stored")
    NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
    assertFalse(NS.db.global.minimap.hide)
end)

test("schema: the reset-all veto keeps the minimap row and every profile row out of the walk", function()
    NS.SetByPath(NS.Constants.MINIMAP_PATH, false)
    NS.SetByPath("locked", true)
    NS.Helpers.RestoreAllDefaults()
    -- The reset re-arms the first-run picker, whose preview is test mode: close it quietly.
    NS.db.profile.skin.pickerSeen = true
    NS.HideSkinPicker()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    assertTrue(NS.db.global.minimap.hide == true, "the minimap row survived Reset all settings")
    assertFalse(NS.GetSetting("locked"), "the profile reset restored `locked`")
    NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
end)
