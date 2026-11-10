-- tests/test_fb2_chrome.lua — owner feedback round 2, the chrome tasks (plan FB-14..FB-17): the
-- rows' in-game icons, the attach mark turned from the detach mark, Expand all / Collapse all in the
-- window's header, and the character's name and class icon on the summary line.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, R, W, D = NS.Blocks, NS.Rows, NS.MainWindow, NS.Detached

local ICONS = "Interface\\Icons\\"

local function skill(key, name, category, rank, max, learned)
    return { key = key, name = name, category = category, rank = rank, max = max, tempPoints = 0,
             modifier = 0, learned = learned ~= false }
end

local function fixture()
    local byKey = {
        leatherworking = skill("leatherworking", "Leatherworking", "primary", 146, 150),
        fishing        = skill("fishing", "Fishing", "secondary", 107, 150),
        guns           = skill("guns", "Guns", "weapon", 105, 110),
        ["other:Jewelcrafting"] = skill("other:Jewelcrafting", "Jewelcrafting", "other", 5, 75),
    }
    local skills = { byKey = byKey, order = { primary = { "leatherworking" }, secondary = { "fishing" },
                                               weapon = { "guns" }, other = { "other:Jewelcrafting" } } }
    local stats = { base = { { key = "agility", label = "Agility", value = 112, display = "112", pct = 100,
                               ref = 112, markers = {} } },
                    spell = {}, defense = {}, utility = {} }
    return skills, stats
end

local function withWorld(fn)
    local skills, stats = fixture()
    local savedSource = B.source
    B.source = function() return skills, stats end
    local ok, err = pcall(fn, skills, stats)
    B.source = savedSource
    W.Hide()
    if not ok then error(err, 0) end
end

--- Swap NS.Compat[name] for `fn` while `body` runs.
local function withCompat(name, fn, body)
    local saved = NS.Compat[name]
    NS.Compat[name] = fn
    local ok, err = pcall(body)
    NS.Compat[name] = saved
    if not ok then error(err, 0) end
end

--- Set mock globals while `body` runs (nil clears one), then put the old values back.
local function withGlobals(values, body)
    local saved = {}
    for k in pairs(values) do saved[k] = M[k] end
    for k, v in pairs(values) do if v == false then M[k] = nil else M[k] = v end end
    local ok, err = pcall(body)
    for k in pairs(values) do M[k] = saved[k] end
    if not ok then error(err, 0) end
end

-- ── FB-14: in-game icons ──────────────────────────────────────────────────────────────────────

test("fb14: every catalog skill and every stat carries an in-game icon path", function()
    local n = 0
    for key, def in pairs(NS.SkillCatalog) do
        assertTrue(type(def.icon) == "string" and def.icon:sub(1, #ICONS) == ICONS, key .. " has an icon")
        n = n + 1
    end
    assertTrue(n >= 31, "the whole catalog")
    for _, def in ipairs(NS.STAT_DEFS) do
        assertTrue(type(def.icon) == "string" and def.icon:sub(1, #ICONS) == ICONS, def.key .. " has an icon")
    end
    assertEqual(NS.SkillCatalog.leatherworking.icon, ICONS .. "Trade_LeatherWorking")
    assertEqual(NS.SkillCatalog.skinning.icon, ICONS .. "INV_Misc_Pelt_Wolf_01")
    assertEqual(NS.SkillCatalog.guns.icon, ICONS .. "INV_Weapon_Rifle_01")
end)

test("fb14: a profession's icon is its spell's texture first, the catalog's path without one", function()
    local asked
    withCompat("SpellTexture", function(id) asked = id return 136247 end, function()
        assertEqual(R.Icon("skill", "leatherworking"), 136247, "the runtime spell texture")
        assertEqual(asked, NS.SkillCatalog.leatherworking.iconSpellID)
        assertEqual(R.Icon("skill", "guns"), ICONS .. "INV_Weapon_Rifle_01", "a weapon line has no spell")
    end)
    withCompat("SpellTexture", function() return nil end, function()
        assertEqual(R.Icon("skill", "leatherworking"), ICONS .. "Trade_LeatherWorking", "the static fallback")
    end)
    assertEqual(R.Icon("skill", "other:Jewelcrafting"), ICONS .. "INV_Misc_QuestionMark", "an unknown line")
    assertEqual(R.Icon("stat", "agility"), NS.STAT_DEFS[2].icon)
    assertEqual(R.Icon("stat", "nope"), ICONS .. "INV_Misc_QuestionMark")
end)

test("fb14: Compat.SpellTexture reads C_Spell first, then the global, else nil", function()
    withGlobals({ C_Spell = { GetSpellTexture = function(id) return "cs" .. id end } }, function()
        assertEqual(NS.Compat.SpellTexture(1), "cs1")
    end)
    withGlobals({ C_Spell = false, GetSpellTexture = function(id) return "g" .. id end }, function()
        assertEqual(NS.Compat.SpellTexture(2), "g2")
    end)
    withGlobals({ C_Spell = false, GetSpellTexture = false }, function()
        assertEqual(NS.Compat.SpellTexture(3), nil)
    end)
end)

test("fb14: the row's icon is a trimmed texture, not two letters", function()
    withWorld(function(skills, stats)
        local pool = R.NewPool()
        local row = R.Acquire(pool, M.UIParent, "row")
        withCompat("SpellTexture", function() return nil end, function()
            row:SetSkill(skills.byKey.guns)
        end)
        assertEqual(row.initials, nil, "no text glyph")
        assertEqual(row.icon:GetTexture(), ICONS .. "INV_Weapon_Rifle_01")
        local l = row.icon:GetTexCoord()
        assertTrue(math.abs(l - 0.07) < 1e-6, "trimmed by the standard 0.07..0.93")
        assertFalse(row.icon:IsDesaturated(), "a learned row in color")
        row:SetSkill(skill("fistWeapons", "Fist Weapons", "weapon", 0, 0, false))
        assertTrue(row.icon:IsDesaturated(), "an unlearned row's icon is gray")
        row:SetStat(stats.base[1])
        assertEqual(row.icon:GetTexture(), R.Icon("stat", "agility"))
        assertFalse(row.icon:IsDesaturated())
        R.ReleaseAll(pool)
    end)
end)

-- ── FB-15: the attach mark ────────────────────────────────────────────────────────────────────

local function corners(tex) return table.concat({ tex:GetTexCoord() }, ",") end
local UPRIGHT, TURNED = "0,0,0,1,1,0,1,1", "1,1,1,0,0,1,0,0"

test("fb15: the attach mark is the detach mark turned 180 degrees", function()
    local pool = B.NewHeaderPool()
    local h = B.AcquireHeader(pool, M.UIParent)
    h:SetBlock("weapon", "", false, true)
    local detachPath = h.detach.icon:GetTexture()
    assertEqual(detachPath, NS.Icon("external-link"))
    assertEqual(corners(h.detach.icon), UPRIGHT, "detach upright")
    h:SetBlock("weapon", "", false, false)
    assertEqual(h.detach.icon:GetTexture(), detachPath, "attach is the same art")
    assertEqual(corners(h.detach.icon), TURNED, "turned on both axes")
    h:SetBlock("weapon", "", false, true)
    assertEqual(corners(h.detach.icon), UPRIGHT, "a pooled header set back is upright again")
    B.ReleaseHeaders(pool)
    withWorld(function()
        B:Detach("secondary")
        local f = D.Frame("secondary")
        assertEqual(f.dock.icon:GetTexture(), detachPath, "the detached frame's dock control")
        assertEqual(corners(f.dock.icon), TURNED)
        B:Dock("secondary")
    end)
end)

-- ── FB-16: Expand all / Collapse all ─────────────────────────────────────────────────────────

test("fb16: Collapse all and Expand all drive every docked block's collapse", function()
    withWorld(function()
        W.Show()
        local f = W.Frame()
        assertTrue(f.collapseAllButton ~= nil and f.expandAllButton ~= nil, "both buttons")
        assertEqual(f.collapseAllButton.icon:GetTexture(), NS.Icon("fullscreen-exit"))
        assertEqual(f.expandAllButton.icon:GetTexture(), NS.Icon("fullscreen-enter"))
        assertTrue(NS.Icon("fullscreen-enter") ~= nil, "the declared, shipped icon")
        assertTrue(type(f.collapseAllButton.tip) == "string" and type(f.expandAllButton.tip) == "string")
        f.collapseAllButton:GetScript("OnClick")(f.collapseAllButton, "LeftButton")
        for _, id in ipairs(B.Docked()) do assertTrue(B.Settings(id).collapsed, id .. " collapsed") end
        local hdr = W.HeaderFor("weapon")
        assertTrue(hdr ~= nil and hdr.collapsed, "the headers redraw collapsed")
        f.expandAllButton:GetScript("OnClick")(f.expandAllButton, "LeftButton")
        for _, id in ipairs(B.Docked()) do assertFalse(B.Settings(id).collapsed, id .. " expanded") end
    end)
end)

test("fb16: SetAllCollapsed leaves the detached blocks alone and answers how many it changed", function()
    withWorld(function()
        B:Detach("secondary")
        B.Settings("secondary").collapsed = false
        local n = B:SetAllCollapsed(true)
        assertTrue(n > 0, "changed some")
        assertFalse(B.Settings("secondary").collapsed, "the detached block keeps its own state")
        assertEqual(B:SetAllCollapsed(true), 0, "nothing left to change")
        B:SetAllCollapsed(false)
        B:Dock("secondary")
    end)
end)

-- ── FB-17: the character on the summary line ─────────────────────────────────────────────────

test("fb17: the class icon's source: the atlas where the client has it, else the class sheet", function()
    withGlobals({ C_Texture = { GetAtlasInfo = function(name) return name == "classicon-hunter" and {} or nil end } },
        function()
            local icon = NS.Compat.ClassIcon("HUNTER")
            assertEqual(icon and icon.atlas, "classicon-hunter")
        end)
    withGlobals({ C_Texture = false, CLASS_ICON_TCOORDS = { HUNTER = { 0, 0.25, 0.25, 0.5 } } }, function()
        local icon = NS.Compat.ClassIcon("HUNTER")
        assertEqual(icon and icon.file, "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        assertEqual(table.concat(icon.coords, ","), "0,0.25,0.25,0.5")
    end)
    withGlobals({ C_Texture = { GetAtlasInfo = function() return nil end },
                  CLASS_ICON_TCOORDS = { HUNTER = { 0, 0.25, 0.25, 0.5 } } }, function()
        assertTrue(NS.Compat.ClassIcon("HUNTER").file ~= nil, "an atlas the client lacks falls to the sheet")
    end)
    withGlobals({ C_Texture = false, CLASS_ICON_TCOORDS = false }, function()
        assertEqual(NS.Compat.ClassIcon("HUNTER"), nil, "neither: no icon")
    end)
    assertEqual(NS.Compat.ClassIcon(nil), nil)
end)

test("fb17: test mode's summary line names the sample character with its class icon", function()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    NS.ToggleTestMode()
    local ok, err = pcall(function()
        local id = W.Identity()
        assertEqual(id.name, "Ember Ironsong")
        assertEqual(id.classFile, "HUNTER")
        local who = W.SummaryParts(NS.Blocks.Data())
        assertEqual(who, "Lv 22 \194\183 Dwarf Hunter", "the level line keeps its text")
        withGlobals({ C_Texture = { GetAtlasInfo = function() return {} end } }, function()
            W.Show()
            local f = W.Frame()
            assertEqual(f.summaryName:GetText(), "Ember Ironsong")
            assertTrue(f.summary:GetText():find("Lv 22", 1, true) ~= nil, f.summary:GetText())
            assertTrue(f.summaryIcon:IsShown(), "the class icon shows")
            assertEqual(f.summaryIcon:GetAtlas(), "classicon-hunter")
        end)
        withGlobals({ C_Texture = false, CLASS_ICON_TCOORDS = false }, function()
            W.Render()
            assertFalse(W.Frame().summaryIcon:IsShown(), "no icon source: the icon hides")
        end)
    end)
    W.Hide()
    NS.ToggleTestMode()
    if not ok then error(err, 0) end
end)

test("fb17: live, the name is the player's through NS.Compat", function()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    withCompat("PlayerName", function() return "Tester" end, function()
        assertEqual(W.Identity().name, "Tester")
    end)
end)
