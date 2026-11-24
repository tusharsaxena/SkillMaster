-- tests/test_dropdown_selected.lua — every menu in Skill Master that marks a selected entry paints
-- that entry apart (FB2-SM-01 of Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH, decision D3).
--
-- The owner, 2026-11-24: "make the current selected always be a different color than the other
-- texts - e.g. gold in ka0s default ... Check this for all addons that have a similar pattern".
-- The rule is the library's (LibKa0s-Widgets-1.0, WidgetsDropdown minor 4): a selected row paints
-- W.SelectedColor(owner), `menu.textSel` while it stands off `menu.text`, else Ka0s Default's gold.
-- This addon draws no menu of its own: the Journal's range picker is a W.Dropdown and the sort,
-- filter, row, group and broker menus are W.ContextMenu. The cases open the range picker and the
-- sort menu (a radio row per order) under Ka0s Default, Obsidian and Azeroth (the one shipped skin
-- that takes the gold fallback) and check the selected row against a plain row and the rule.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "SkillMaster"
local SKINS = { "ka0s", "obsidian", "azeroth" }
local GOLD = { 1, 0.82, 0 }   -- Ka0s Default's selected gold, the fallback

local function skinLib() return M.LibStub("LibKa0s-Skin-1.0") end
local function widgets() return M.LibStub("LibKa0s-Widgets-1.0") end
local function rgb(c) return ("%.3f,%.3f,%.3f"):format(c[1] or -1, c[2] or -1, c[3] or -1) end
local function painted(b) return M.__paint(b.fs).textColor or {} end

local shared   -- the shared menu frame, once sharedMenu found it

--- Close the shared menu as the client does: Hide, then its OnHide, which drops its GLOBAL_MOUSE_DOWN
--- registration (the mock's Hide fires no script, and a stale registration fails the disable suite).
local function closeMenu()
    widgets().CloseMenu()
    if shared and shared.__fire then shared:__fire("OnHide") end
end

--- Run `fn(key)` under each skin in SKINS, then put the stored choice back.
local function underSkins(fn)
    local lib = skinLib()
    local source, current = lib:GetChoice(OWNER)
    local ok, err = pcall(function()
        for _, key in ipairs(SKINS) do
            lib:SetChoice(OWNER, source, key)
            fn(key)
        end
    end)
    lib:SetChoice(OWNER, source, current)
    closeMenu()
    if not ok then error(err, 0) end
end

--- The shared menu every dropdown and ContextMenu opens (W.ContextMenu answers it).
local function sharedMenu()
    local anchor = M.CreateFrame("Frame", nil, M.UIParent)
    shared = widgets().ContextMenu(anchor, { { label = "x", onClick = function() end } }, { owner = OWNER })
    closeMenu()
    return shared
end

--- The selected row against the plain row and the rule's color.
local function checkRows(key, sel, plain, where)
    local W = widgets()
    local want = W.SelectedColor and { W.SelectedColor(OWNER) } or GOLD
    assertEqual(rgb(painted(sel)), rgb(want), key .. ": " .. where .. "'s selected row is W.SelectedColor")
    assertTrue(rgb(painted(sel)) ~= rgb(painted(plain)), key .. ": " .. where .. "'s selected row differs from a plain row")
    assertEqual(rgb(painted(plain)), rgb(NS.SkinColor("menu.text") or {}), key .. ": " .. where .. "'s plain row is menu.text")
    if key == "azeroth" then
        -- Azeroth's own accent stands 16.3 CIEDE2000 off its menu text, under the floor of 20.
        assertEqual(rgb(painted(sel)), rgb(GOLD), key .. ": " .. where .. "'s selected row is the gold fallback")
    end
end

test("dropdown selected: the Journal's range picker paints its selected range apart", function()
    -- red under WidgetsDropdown minor 3: Azeroth's selection painted its gold accent, 16.3 off its
    -- parchment menu text, so the selected range read like the rest.
    local J = NS.Journal
    J.Show()
    J.SelectTab("log")
    local dd = J.Frame().logPanel.range
    assertTrue(dd ~= nil, "the range picker")
    local menu = sharedMenu()
    local ok, err = pcall(underSkins, function(key)
        dd:SelectValue(NS.Journal.RANGE_ORDER[1])
        dd:__fire("OnClick")
        assertTrue(menu:IsShown(), key .. ": the picker opened the shared menu")
        checkRows(key, menu.buttons[1], menu.buttons[2], "the range picker")
        closeMenu()
    end)
    J.Hide()
    if not ok then error(err, 0) end
end)

test("dropdown selected: the sort menu's current order (a radio row) paints apart", function()
    -- red under WidgetsDropdown minor 3: a ticked ContextMenu row kept menu.text beside its tick.
    local B = NS.Blocks
    sharedMenu()
    local anchor = M.CreateFrame("Button", nil, M.UIParent)
    local saved = NS.db.profile.layout.blocks.weapon.sort
    NS.db.profile.layout.blocks.weapon.sort = "name"
    local ok, err = pcall(underSkins, function(key)
        local menu = B.SortMenu("weapon", anchor)
        assertTrue(menu ~= nil and menu:IsShown(), key .. ": the sort menu opened")
        -- rows: the title, then one per order; "name" is B.SORTS[1], the current one.
        assertEqual(B.SORTS[1], "name")
        checkRows(key, menu.buttons[2], menu.buttons[3], "the sort menu")
        closeMenu()
    end)
    NS.db.profile.layout.blocks.weapon.sort = saved
    if not ok then error(err, 0) end
end)

test("dropdown selected: Azeroth's selection is the gold fallback, not its accent", function()
    local lib = skinLib()
    local source, current = lib:GetChoice(OWNER)
    lib:SetChoice(OWNER, source, "azeroth")
    local W = widgets()
    assertTrue(type(W.SelectedColor) == "function", "W.SelectedColor, the shared menu's selected color")
    local r, g, b = W.SelectedColor(OWNER)
    lib:SetChoice(OWNER, source, current)
    assertEqual(rgb({ r, g, b }), rgb(GOLD), "Azeroth's selected row is Ka0s Default's gold")
end)
