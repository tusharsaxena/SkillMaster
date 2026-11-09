-- tests/test_keybinds.lua — the Show window key binding (launcher-§6).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("keybinds: Bindings.xml is one CLICK line in this addon's category, no header, no default", function()
    local list = T.assertBindingsXml("Bindings.xml", {
        category = "BINDING_HEADER_SKILLMASTER",
        commands = NS.BINDINGS,
        brand    = NS.Constants.BRAND,
        env      = M,
    })
    assertEqual(#list, 1)
end)

test("keybinds: the bound button runs the window's one toggle handler", function()
    NS.MainWindow.Hide()
    local button = NS.MainWindow.__toggleButton
    assertTrue(button ~= nil, "the binding button exists by its permanent name")
    button:GetScript("OnClick")(button, "LeftButton")
    assertTrue(NS.MainWindow.IsShown(), "one press shows the window")
    button:GetScript("OnClick")(button, "LeftButton")
    assertTrue(not NS.MainWindow.IsShown(), "a second press hides it")
end)
