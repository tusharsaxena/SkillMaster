-- tests/test_template_rows.lua — the template settings as presets plus Custom (feedback round 1,
-- FB-2): no string row anywhere in the schema renders as LibKa0s's empty dropdown, a preset writes
-- its template, Custom keeps and edits free text, and a stored string matching no preset reads as
-- Custom with its text in the box.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local EMPTY = "renders as an empty dropdown"
local CUSTOM = NS.CUSTOM_PRESET

local function aceGUI() return M.__libs["AceGUI-3.0"] end

local function rowFor(path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
end

--- The widgets of `wtype` labeled `label` created after index `from` of the factory's list: what
--- one render drew. Only the Broker page draws these labels while the Bars page sits on its first
--- tab.
local function widgets(from, wtype, label)
    local out = {}
    local created = aceGUI().__created
    for i = from + 1, #created do
        local w = created[i]
        if w.type == wtype and w.labelText == label and not w.__released then out[#out + 1] = w end
    end
    return out
end

local function emptyDropdownLines()
    local out = {}
    for _, line in ipairs(M.__printed()) do
        if line:find(EMPTY, 1, true) then out[#out + 1] = line end
    end
    return out
end

--- Show `name` and draw it from the stored values now (a page already drawn by an earlier case
--- repaints only what a refresh asks for).
local function showPage(name)
    local panel = M.__subcategories[name]
    panel:Show()
    panel:__fire("OnShow")
    NS.Helpers.RefreshAllPanels()
    M.__fireTimers()
    return panel
end

local function hidePage(panel)
    panel:Hide()
    panel:__fire("OnHide")
    M.__fireTimers()
end

local function restoreBroker()
    NS.ForgetCustomTemplates()
    NS.SetByPath("broker.template", NS.defaults.profile.broker.template)
    NS.SetByPath("bars.textTemplate", NS.defaults.profile.bars.textTemplate)
end

test("templates: no string row in the whole schema renders as an empty dropdown", function()
    -- red under: a `type = "string"` row with neither `values` nor `dialogControl` (LibKa0s
    -- Options' EMPTY_DROPDOWN, the line the owner's 2026-11-10 log carried for five rows).
    local bad = {}
    for _, row in ipairs(NS.Schema) do
        if row.type == "string" and not row.skipRender and row.values == nil and row.dialogControl == nil then
            bad[#bad + 1] = tostring(row.path)
        end
    end
    table.sort(bad)
    assertEqual(#bad, 0, "empty dropdowns: " .. table.concat(bad, ", "))
end)

test("templates: the Broker page renders with no empty-dropdown line, one dropdown for the feed", function()
    restoreBroker()
    M.__resetPrinted()
    local from = #aceGUI().__created
    local panel = showPage("Broker")
    assertEqual(#emptyDropdownLines(), 0, table.concat(emptyDropdownLines(), " | "))
    for _, label in ipairs({ "Feed text" }) do
        local dd = widgets(from, "Dropdown", label)
        assertEqual(#dd, 1, label .. ": one presets dropdown")
        assertTrue(next(dd[1].list) ~= nil, label .. ": the dropdown lists its presets")
        assertTrue(dd[1].list[CUSTOM] ~= nil, label .. ": and Custom")
    end
    assertEqual(#widgets(from, "EditBox", "Custom text"), 0, "a preset shows no text box")
    hidePage(panel)
end)

test("templates: every template row's default is one of its presets", function()
    assertEqual(NS.GetSetting("broker.preset"), NS.defaults.profile.broker.template, "the feed")
    assertEqual(NS.GetSetting("bars.textPreset"), NS.defaults.profile.bars.textTemplate, "the bar text")
end)

test("templates: picking a preset writes its template", function()
    restoreBroker()
    assertTrue(NS.SetByPath("broker.preset", "{pinned}"))
    assertEqual(NS.db.profile.broker.template, "{pinned}", "the stored value is the template string")
    assertEqual(NS.GetSetting("broker.preset"), "{pinned}", "and the picker reads that preset")
    assertTrue(NS.SetByPath("bars.textPreset", "{rank} / {max}"))
    assertEqual(NS.Bar.ResolveStyle("row").template, "{rank} / {max}", "the bars draw it")
    assertEqual(NS.Bar.Text(107, 25, 150, NS.Bar.ResolveStyle("row").template), "107 / 150")
    restoreBroker()
end)

test("templates: Custom keeps the text, and the box edits it", function()
    restoreBroker()
    local before = NS.db.profile.broker.template
    assertTrue(NS.SetByPath("broker.preset", CUSTOM))
    assertEqual(NS.db.profile.broker.template, before, "choosing Custom writes nothing")
    assertEqual(NS.GetSetting("broker.preset"), CUSTOM, "the picker reads Custom")
    assertTrue(NS.SetByPath("broker.template", "{equippedWeapon} Lv {level}"))
    assertEqual(NS.db.profile.broker.template, "{equippedWeapon} Lv {level}")
    assertEqual(NS.GetSetting("broker.preset"), CUSTOM, "free text stays Custom")
    restoreBroker()
end)

test("templates: a stored string matching no preset reads as Custom, its text in the box", function()
    restoreBroker()
    NS.db.profile.broker.template = "{stat:armor} / {stat:dodge}"
    assertEqual(NS.GetSetting("broker.preset"), CUSTOM)
    local from = #aceGUI().__created
    local panel = showPage("Broker")
    local boxes = widgets(from, "EditBox", "Custom text")
    assertEqual(#boxes, 1, "one box: the feed's")
    assertEqual(boxes[1].text, "{stat:armor} / {stat:dodge}")
    -- The box commits on Enter, through the write seam.
    boxes[1]:__fire("OnEnterPressed", "{stat:speed}")
    assertEqual(NS.db.profile.broker.template, "{stat:speed}")
    hidePage(panel)
    restoreBroker()
end)

test("templates: choosing Custom in the dropdown reveals the box; a preset hides it again", function()
    restoreBroker()
    local from = #aceGUI().__created
    local panel = showPage("Broker")
    local dd = widgets(from, "Dropdown", "Feed text")[1]
    from = #aceGUI().__created
    dd:__fire("OnValueChanged", CUSTOM)
    M.__fireTimers()   -- the switched section re-renders on the next frame
    local boxes = widgets(from, "EditBox", "Custom text")
    assertEqual(#boxes, 1, "Custom shows the box")
    assertEqual(boxes[1].text, NS.defaults.profile.broker.template, "holding the current text")
    dd = widgets(from, "Dropdown", "Feed text")[1]
    from = #aceGUI().__created
    dd:__fire("OnValueChanged", "{pinned}")
    M.__fireTimers()
    assertEqual(NS.db.profile.broker.template, "{pinned}")
    assertEqual(#widgets(from, "Dropdown", "Feed text"), 1, "the page drew again")
    assertEqual(#widgets(from, "EditBox", "Custom text"), 0, "a preset hides it")
    hidePage(panel)
    restoreBroker()
end)

test("templates: the page's Defaults lets go of Custom and restores the shipped template", function()
    restoreBroker()
    NS.SetByPath("broker.preset", CUSTOM)
    NS.SetByPath("broker.template", "{level}")
    NS.Helpers.RestoreDefaults("broker")
    M.__fireTimers()
    assertEqual(NS.db.profile.broker.template, NS.defaults.profile.broker.template)
    assertEqual(NS.GetSetting("broker.preset"), NS.defaults.profile.broker.template)
    assertFalse(rowFor("broker.preset").get() == CUSTOM)
    restoreBroker()
end)

test("templates: the bar text's presets are named by what they draw for 107 +25 / 150", function()
    local texts = {}
    for _, v in ipairs(rowFor("bars.textPreset").values) do texts[v.value] = v.text end
    assertEqual(texts["{rank} {bonus} / {max}"], "107 +25 / 150", "the shipped default")
    assertEqual(texts["{rank} / {max}"], "107 / 150")
    assertEqual(texts["{rank} {bonus} / {max} ({pct}%)"], "107 +25 / 150 (71%)")
    assertEqual(texts["{left} to go"], "43 to go")
    assertTrue(texts[CUSTOM] ~= nil, "and Custom")
    assertEqual(rowFor("bars.textTemplate").dialogControl, "EditBox", "the box is the stored row")
end)
