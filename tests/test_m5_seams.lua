-- tests/test_m5_seams.lua — the seams between the M5 tracks, wired at integration: the broker's
-- right-click reaching the T5.1 Broker page, the polish keys' settings rows (the under-row hint,
-- the tooltip helpers, the weapon block's compact filter), the Journal page's log length on T5.2's
-- log constructor, and the diagnostics sections reading test mode and the simulator.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function rowFor(path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
end

local function countLayoutChanged(fn)
    local seen = 0
    local target = NS.NewBusTarget()
    target:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() seen = seen + 1 end)
    local ok, err = pcall(fn)
    target:UnregisterMessage(NS.MSG.LAYOUT_CHANGED)
    if not ok then error(err, 0) end
    return seen
end

local function sectionText(name)
    for _, s in ipairs(NS.Diagnostics.Sections()) do
        if s[1] == name then
            local lines, out = {}, {}
            function out.add(_, _, fmt, ...)
                local args = { ... }
                for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
                lines[#lines + 1] = fmt:gsub("%%s", function() return table.remove(args, 1) end)
            end
            function out.joined(self, tag, lead, parts) return self:add(tag, "%s %s", lead, table.concat(parts, ", ")) end
            out.list = out.joined
            s[2](out)
            return table.concat(lines, "\n")
        end
    end
    error("no section " .. name)
end

-- ---------------------------------------------------------------------------------------------
-- The broker's right-click (polish) and the Broker page (T5.1)
-- ---------------------------------------------------------------------------------------------

test("m5 seam: the broker's right-click opens the registered Broker page through the library's opener", function()
    -- red under: a page key the settings pages never registered (the right-click would land on
    -- the main page), or an opener that never reaches Settings.OpenToCategory.
    local B = NS.Broker
    local declared = false
    for _, row in ipairs(NS.SchemaForPage(B.SETTINGS_PAGE)) do declared = declared or row.page == B.SETTINGS_PAGE end
    assertTrue(declared, "the Broker page declares rows under the key the broker opens")
    assertTrue(M.__subcategories[NS.L["Broker"]] ~= nil, "and registered its subcategory")
    local real, opened = M.Settings.OpenToCategory, 0
    M.Settings.OpenToCategory = function() opened = opened + 1 end
    local ok, result = pcall(M.__ldbObjects.SkillMaster_All.OnClick, nil, "RightButton")
    M.Settings.OpenToCategory = real
    assertTrue(ok, tostring(result))
    assertEqual(opened, 1, "one open, through the real NS.Helpers.OpenOptionsPanel")
end)

-- ---------------------------------------------------------------------------------------------
-- The polish keys' rows on the T5.1 pages
-- ---------------------------------------------------------------------------------------------

local function skinning()
    return { key = "skinning", name = "Skinning", category = "primary", rank = 122, max = 150, modifier = 0,
             tempPoints = 0, learned = true }
end

test("m5 seam: Skills > Hint under the row drives the row hint live, off by default", function()
    local row = rowFor("skills.helperHint")
    assertTrue(row ~= nil and row.page == "skills", "the hint has its row on the Skills page")
    assertFalse(NS.GetSetting("skills.helperHint"), "off by default (design §12 item 4)")
    assertEqual(NS.Rows.HelperHint(skinning()), nil)
    local seen = countLayoutChanged(function() NS.SetByPath("skills.helperHint", true) end)
    assertEqual(seen, 1, "the write repaints the rows once")
    assertEqual(NS.Rows.HelperHint(skinning()), "Skinning 122: mobs up to Lv 24")
    NS.SetByPath("skills.helperHint", false)
end)

test("m5 seam: Skills > Gathering and fishing hints switches the tooltip's helper lines, apart from the row hint", function()
    local function hasHelper()
        for _, l in ipairs(NS.RowTooltip.Lines(skinning(), "skill")) do
            if type(l.left) == "string" and l.left:find("mobs up to Lv", 1, true) then return true end
        end
        return false
    end
    local row = rowFor("skills.helperTooltip")
    assertTrue(row ~= nil and row.page == "skills", "the tooltip helpers have their own row")
    assertTrue(NS.GetSetting("skills.helperTooltip"), "on by default")
    assertTrue(hasHelper(), "the skinning breakpoint line is in the tooltip")
    NS.SetByPath("skills.helperTooltip", false)
    assertFalse(hasHelper(), "and leaves it with the row off")
    assertFalse(NS.GetSetting("skills.helperHint"), "without touching the under-row hint")
    NS.SetByPath("skills.helperTooltip", true)
end)

test("m5 seam: Layout > Weapon skills > Equipped and below cap only refilters the detached block live", function()
    local row = rowFor("layout.blocks.weapon.belowCapOnly")
    assertTrue(row ~= nil and row.page == "layout", "the compact filter has its row on the Layout page")
    local skills = { byKey = {
        guns   = { key = "guns", name = "Guns", category = "weapon", rank = 105, max = 110, modifier = 0, tempPoints = 0, learned = true },
        staves = { key = "staves", name = "Staves", category = "weapon", rank = 110, max = 110, modifier = 0, tempPoints = 0, learned = true },
    }, order = { primary = {}, secondary = {}, weapon = { "guns", "staves" }, other = {} } }
    local savedSource, savedLink, savedInfo = NS.Blocks.source, M.GetInventoryItemLink, M.GetItemInfoInstant
    NS.Blocks.source = function() return skills, { base = {}, spell = {}, defense = {}, utility = {} } end
    M.GetInventoryItemLink = function() return nil end
    local ok, err = pcall(function()
        NS.Blocks:Detach("weapon")
        local function keys()
            local out = {}
            for _, r in ipairs(NS.Detached.Rows("weapon")) do out[#out + 1] = r.entry and r.entry.key end
            return table.concat(out, ",")
        end
        assertEqual(keys(), "guns,staves", "off: every weapon row")
        NS.SetByPath("layout.blocks.weapon.belowCapOnly", true)
        assertEqual(keys(), "guns", "on: the capped, unequipped Staves leaves without a manual refresh")
        NS.SetByPath("layout.blocks.weapon.belowCapOnly", false)
        assertEqual(keys(), "guns,staves")
    end)
    NS.db.profile.layout.blocks.weapon.belowCapOnly = false
    NS.Blocks:Dock("weapon")
    NS.Blocks.source, M.GetInventoryItemLink, M.GetItemInfoInstant = savedSource, savedLink, savedInfo
    M.__fireTimers()
    if not ok then error(err, 0) end
end)

test("m5 seam: journal.size is the grip's drag state, never a row", function()
    assertEqual(rowFor("journal.size"), nil)
    assertTrue(rowFor("journal.keep") ~= nil and rowFor("journal.filter") ~= nil)
end)

-- ---------------------------------------------------------------------------------------------
-- The Journal page's log length (T5.1) on the T5.2 log constructor
-- ---------------------------------------------------------------------------------------------

test("m5 seam: Journal > log length caps the live log, also while a simulation's override is in place", function()
    local SL = NS.SessionLog
    local list = {}
    SL:Override(list, 1000)
    NS.SetByPath("journal.keep", 3)
    local ok, err = pcall(function()
        for i = 1, 5 do SL:Add("bows", 80 + i - 1, 80 + i, 1000 + i, "Loch Modan") end
        assertEqual(#list, 3, "the oldest two are dropped")
        assertEqual(list[1].new, 83)
        assertEqual(SL.Cap(), 3)
    end)
    NS.SetByPath("journal.keep", NS.defaults.profile.journal.keep)
    SL:Override(nil)
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- Diagnostics cover test mode and the simulator
-- ---------------------------------------------------------------------------------------------

test("m5 seam: diagnostics report test mode's sample data in state, model and sim", function()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    assertTrue(sectionText("state"):find("testMode=false simMode=false", 1, true) ~= nil, sectionText("state"))
    assertTrue(sectionText("sim"):find("preview data=false", 1, true) ~= nil)
    NS.ToggleTestMode()
    local ok, err = pcall(function()
        assertTrue(sectionText("state"):find("testMode=true", 1, true) ~= nil, sectionText("state"))
        assertTrue(sectionText("sim"):find("preview data=true", 1, true) ~= nil, sectionText("sim"))
        assertTrue(sectionText("model"):find("preview source=on", 1, true) ~= nil, sectionText("model"))
    end)
    if NS.IsTestMode() then NS.ToggleTestMode() end
    if not ok then error(err, 0) end
    assertTrue(sectionText("model"):find("preview source=off", 1, true) ~= nil)
end)
