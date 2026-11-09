-- tests/test_keybinds.lua — the key bindings, Show window and the Journal (launcher-§6).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("keybinds: Bindings.xml is two CLICK lines in this addon's category, no header, no default", function()
    local list = T.assertBindingsXml("Bindings.xml", {
        category = "BINDING_HEADER_SKILLMASTER",
        commands = NS.BINDINGS,
        brand    = NS.Constants.BRAND,
        env      = M,
    })
    assertEqual(#list, 2)
    assertEqual(NS.BINDINGS[1].command, "CLICK SkillMasterToggleWindow:LeftButton", "Show window is first")
    assertEqual(NS.BINDINGS[2].command, "CLICK SkillMasterToggleJournal:LeftButton")
    assertEqual(_G["BINDING_NAME_CLICK SkillMasterToggleWindow:LeftButton"], "Toggle skills window")
    assertEqual(_G["BINDING_NAME_CLICK SkillMasterToggleJournal:LeftButton"], "Toggle journal")
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

test("keybinds: the Journal button runs the Journal's one toggle handler", function()
    NS.Journal.Hide()
    local button = NS.MainWindow.__journalButton
    assertTrue(button ~= nil, "the Journal's binding button exists")
    assertEqual(button.__name, "SkillMasterToggleJournal", "the permanent name")
    assertEqual(button.__template, nil, "a plain button, no secure template")
    button:GetScript("OnClick")(button, "LeftButton")
    assertTrue(NS.Journal.IsShown(), "one press shows the Journal")
    button:GetScript("OnClick")(button, "LeftButton")
    assertTrue(not NS.Journal.IsShown(), "a second press hides it")
end)

test("keybinds: a Journal press while stood down refuses on the toggle verb's line", function()
    NS.Journal.Hide()
    NS.SetByPath("enabled", false)
    M.__resetPrinted()
    local button = NS.MainWindow.__journalButton
    button:GetScript("OnClick")(button, "LeftButton")
    local printed = M.__printed()
    NS.SetByPath("enabled", true)
    assertTrue(not NS.Journal.IsShown(), "the press showed the Journal while stood down")
    assertEqual(#printed, 1, "the press refuses on one line")
    assertTrue(printed[1]:find(NS.Slash:DisabledLine(), 1, true) ~= nil, printed[1])
end)
