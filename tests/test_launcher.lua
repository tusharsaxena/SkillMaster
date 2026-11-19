-- tests/test_launcher.lua — one LDB object, registered on enable, its menu onto the verbs' handlers.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
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

-- AD-81-SM (LibKa0s#81): the launcher menu's Journal entry, through the descriptor's extraEntries.

--- A headless MenuUtil whose rows keep their callbacks: CreateContextMenu runs the generator.
local function openMenu()
    local root = { rows = {} }
    local function row(kind, label, a, b)
        local e = { kind = kind, label = label, enabled = true }
        if kind == "checkbox" then e.isSelected, e.onSelect = a, b else e.onSelect = a end
        function e.SetEnabled(_, on) e.enabled = on and true or false end
        root.rows[#root.rows + 1] = e
        return e
    end
    function root.CreateTitle(_, label) return row("title", label) end
    function root.CreateCheckbox(_, label, isSelected, onSelect) return row("checkbox", label, isSelected, onSelect) end
    function root.CreateButton(_, label, onClick) return row("button", label, onClick) end
    local realMU = M.MenuUtil
    M.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    NS.Launcher:Object().OnClick(nil, "RightButton")
    M.MenuUtil = realMU
    return root.rows
end

local function labels(rows)
    local out = {}
    for _, r in ipairs(rows) do if r.kind ~= "title" then out[#out + 1] = r.label end end
    return table.concat(out, "|")
end

test("launcher: the menu carries a Journal checkbox after Show window and before Open settings", function()
    NS.db.profile.skin.pickerSeen = true
    NS.addon:OnEnable()
    local rows = openMenu()
    local text = labels(rows)
    assertTrue(text:find("Show window|Journal|Open settings", 1, true) ~= nil, text)
    local journal
    for _, r in ipairs(rows) do if r.label == "Journal" then journal = r end end
    assertEqual(journal.kind, "checkbox", "a checkbox: its tick is the Journal's state")
end)

test("launcher: the Journal entry's tick is the Journal's state and its click the journal verb's", function()
    NS.db.profile.skin.pickerSeen = true
    NS.addon:OnEnable()
    NS.Journal.Hide()
    local journal
    for _, r in ipairs(openMenu()) do if r.label == "Journal" then journal = r end end
    assertTrue(not journal.isSelected(), "unticked while the Journal is closed")
    journal.onSelect()
    assertTrue(NS.Journal.IsShown(), "the click opens the Journal")
    for _, r in ipairs(openMenu()) do if r.label == "Journal" then journal = r end end
    assertTrue(journal.isSelected(), "ticked while it is open")
    journal.onSelect()
    assertTrue(not NS.Journal.IsShown(), "a second click closes it")
end)
