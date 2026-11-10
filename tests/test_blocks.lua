-- tests/test_blocks.lua — blocks, rows and the main window body (plan Task 3.2): the block list, the
-- detach/dock round trip, the unlearned row and the persisted collapse.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, R, W, D = NS.Blocks, NS.Rows, NS.MainWindow, NS.Detached

local function skill(key, name, category, rank, max, modifier, learned)
    return { key = key, name = name, category = category, kind = NS.SkillCatalog[key] and NS.SkillCatalog[key].kind,
             rank = rank, max = max, tempPoints = 0, modifier = modifier or 0, learned = learned ~= false }
end

-- The mockup's Dwarf Hunter, trimmed: one row per category and one unlearned weapon.
local function fixture()
    local byKey = {
        leatherworking = skill("leatherworking", "Leatherworking", "primary", 146, 150),
        fishing        = skill("fishing", "Fishing", "secondary", 107, 150, 25),
        guns           = skill("guns", "Guns", "weapon", 105, 110, 5),
        fistWeapons    = skill("fistWeapons", "Fist Weapons", "weapon", 0, 0, 0, false),
        defense        = skill("defense", "Defense", "other", 100, 110),
    }
    local skills = { byKey = byKey, order = { primary = { "leatherworking" }, secondary = { "fishing" },
                                               weapon = { "guns", "fistWeapons" }, other = { "defense" } } }
    local stats = { base = { { key = "agility", label = "Agility", value = 112, display = "112", pct = 100,
                               ref = 112, markers = {} } },
                    spell = {}, defense = {}, utility = {} }
    return skills, stats
end

local function withWorld(fn)
    local skills, stats = fixture()
    local savedSource = B.source
    local savedFaction, savedRace = M.UnitFactionGroup, M.UnitRace
    B.source = function() return skills, stats end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.UnitRace = function() return "Dwarf", "Dwarf" end
    local ok, err = pcall(fn, skills, stats)
    B.source = savedSource
    M.UnitFactionGroup, M.UnitRace = savedFaction, savedRace
    W.Hide()
    if not ok then error(err, 0) end
end

local function contains(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

local function rowsOf(category)
    local n = 0
    for _, row in ipairs(W.Rows()) do
        if row.entry and row.entry.category == category then n = n + 1 end
    end
    return n
end

test("blocks: the eight blocks, four skill categories then four stat groups", function()
    assertEqual(table.concat(NS.BLOCKS, ","),
        "primary,secondary,weapon,other,stats_base,stats_spell,stats_defense,stats_utility")
    for _, id in ipairs(NS.BLOCKS) do
        local def = NS.BlockDefs[id]
        assertEqual(def.id, id)
        assertTrue(def.source == "skills" or def.source == "stats", id .. " source")
        assertTrue(type(def.title) == "string" and def.title ~= "", id .. " title")
        assertTrue(type(NS.db.profile.layout.blocks[id]) == "table", id .. " has its layout row")
    end
end)

test("test_blocks_detach_dock_roundtrip: a block leaves the window, gets its own frame and comes back", function()
    -- red under: a Detach that does not persist `docked`, leaves the block in the window, or a Dock
    -- that forgets the block's place in the order.
    withWorld(function()
        local sent = 0
        local target = NS.NewBusTarget()
        target:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() sent = sent + 1 end)
        W.Show()
        local before = table.concat(B.Docked(), ",")
        assertTrue(contains(B.Docked(), "weapon"), "docked by default")
        assertTrue(rowsOf("weapon") > 0, "its rows are in the window")

        B:Detach("weapon")
        local s = NS.db.profile.layout.blocks.weapon
        assertFalse(s.docked, "persisted as detached")
        assertFalse(contains(B.Docked(), "weapon"), "out of the window's list")
        assertEqual(rowsOf("weapon"), 0, "and out of the window's rows")
        local f = D.Frame("weapon")
        assertTrue(f ~= nil and f:IsShown(), "its own frame shows")
        assertEqual(f:GetFrameStrata(), NS.Constants.LAYERS.STRATA.HUD)
        assertTrue(#D.Rows("weapon") > 0, "the detached frame draws the block's rows")
        assertTrue(sent >= 1, "LAYOUT_CHANGED sent")

        B:Dock("weapon")
        assertTrue(s.docked, "docked again")
        assertFalse(f:IsShown(), "the detached frame hides")
        assertEqual(table.concat(B.Docked(), ","), before, "back in its old place")
        assertTrue(rowsOf("weapon") > 0, "its rows are back in the window")
        target:UnregisterMessage(NS.MSG.LAYOUT_CHANGED)
    end)
end)

test("blocks: a detached frame saves its drop point; locked refuses the drag", function()
    withWorld(function()
        B:Detach("secondary")
        local f = D.Frame("secondary")
        local started = 0
        f.StartMoving = function() started = started + 1 end
        NS.SetByPath("locked", true)
        f:GetScript("OnDragStart")(f)
        assertEqual(started, 0, "locked")
        NS.SetByPath("locked", false)
        f:GetScript("OnDragStart")(f)
        assertEqual(started, 1, "unlocked")
        f.GetPoint = function() return "TOPLEFT", M.UIParent, "TOPLEFT", 12, -34 end
        f:GetScript("OnDragStop")(f)
        local p = NS.db.profile.layout.blocks.secondary.point
        assertEqual(p and p.x, 12)
        assertEqual(p and p.y, -34)
        B:Dock("secondary")
        NS.db.profile.layout.blocks.secondary.point = false
    end)
end)

test("test_rows_unlearned_variant: an unlearned skill is a dimmed row with its trainer and a Go button", function()
    withWorld(function(skills)
        local pool = R.NewPool()
        local row = R.Acquire(pool, M.UIParent, "row")
        row:SetSkill(skills.byKey.fistWeapons)
        assertEqual(row.name:GetText(), "Fist Weapons")
        assertFalse(row.bar:IsShown(), "no bar")
        assertTrue(row.where:IsShown(), "the trainer line shows")
        local text = row.where:GetText()
        assertTrue(text:find("Not learned", 1, true) ~= nil, text)
        assertTrue(text:find("Ironforge", 1, true) ~= nil, "the Alliance weapon master's city: " .. text)
        assertTrue(text:find("10s", 1, true) ~= nil, "the cost: " .. text)
        assertTrue(row.go:IsShown(), "the Go button shows")
        assertTrue(row:GetAlpha() < 1, "dimmed")

        row:SetSkill(skills.byKey.guns)
        assertTrue(row.bar:IsShown(), "a learned row draws its bar")
        assertFalse(row.go:IsShown(), "and no Go button")
        assertFalse(row.where:IsShown())
        assertEqual(row:GetAlpha(), 1)
        assertEqual(row.bar.text:GetText(), "105 +5 / 110")
        R.ReleaseAll(pool)
    end)
end)

test("rows: money and the riding trainer line", function()
    assertEqual(R.Money(1000), "10s")
    assertEqual(R.Money(900000), "90g")
    assertEqual(R.Money(15050), "1g 50s 50c")
    withWorld(function()
        local text = R.UnlearnedText(skill("riding", "Riding", "other", 0, 0, 0, false))
        assertTrue(text:find("Ultham Ironhorn", 1, true) ~= nil, text)
        assertTrue(text:find("Lv 40", 1, true) ~= nil, text)
        assertTrue(text:find("90g", 1, true) ~= nil, text)
    end)
end)

test("rows: the color modes", function()
    local e = skill("leatherworking", "Leatherworking", "primary", 146, 150)
    local bars = NS.db.profile.bars
    bars.colorMode = "category"
    bars.colors.fromSkin = false
    assertEqual(R.FillColor(e), bars.colors.primary)
    bars.colors.fromSkin = true
    assertEqual(R.FillColor(e), NS.Bar.Color("sm.cat.primary"), "a category color that follows the skin")
    bars.colorMode = "progress"
    assertTrue(type(R.FillColor(e)) == "table")
    bars.colorMode = "likelihood"
    assertTrue(type(R.FillColor(e)) == "table")
    bars.colorMode = "category"
end)

test("test_mainwindow_collapsed_persisted: collapsing a block is stored, survives a re-render and the header toggles it", function()
    -- red under: a collapse kept on the header frame (lost when the pooled header is reused) rather
    -- than in profile.layout.blocks[id].collapsed.
    withWorld(function()
        W.Show()
        assertTrue(rowsOf("weapon") > 0, "precondition: the weapon rows show")
        B:SetCollapsed("weapon", true)
        assertTrue(NS.db.profile.layout.blocks.weapon.collapsed, "stored in the profile")
        W.Render()
        W.Render()
        assertEqual(rowsOf("weapon"), 0, "no weapon rows while collapsed")
        local header = W.HeaderFor("weapon")
        assertTrue(header ~= nil and header.collapsed, "the header says collapsed")
        header:GetScript("OnClick")(header, "LeftButton")
        assertFalse(NS.db.profile.layout.blocks.weapon.collapsed, "the header click expands it")
        assertTrue(rowsOf("weapon") > 0, "rows back")
    end)
end)

test("mainwindow: the title bar carries lock, journal, settings and close; the summary and legend show", function()
    withWorld(function()
        W.Show()
        local f = W.Frame()
        assertTrue(f.lockButton ~= nil and f.journalButton ~= nil and f.settingsButton ~= nil, "controls")
        assertTrue(f.close ~= nil, "close")
        local was = NS.GetSetting("locked")
        f.lockButton:GetScript("OnClick")(f.lockButton)
        assertEqual(NS.GetSetting("locked"), not was, "the lock control flips Locked")
        NS.SetByPath("locked", was)
        assertTrue(f.summary:GetText():find("Lv", 1, true) ~= nil, "the summary names the level")
        assertTrue(f.legend ~= nil, "the legend")
    end)
end)

test("mainwindow: an empty model shows the empty state, and data hides it", function()
    local savedSource = B.source
    B.source = function() return { byKey = {}, order = { primary = {}, secondary = {}, weapon = {}, other = {} } },
        { base = {}, spell = {}, defense = {}, utility = {} } end
    W.Show()
    assertTrue(W.Frame().empty:IsShown(), "empty state")
    B.source = savedSource
    W.Hide()
    withWorld(function()
        W.Show()
        assertFalse(W.Frame().empty:IsShown(), "rows instead")
    end)
end)

test("mainwindow: a skin switch restyles every bar, header and icon well, not only the values", function()
    -- red under: a skin switch keeps the row set, so the window took its values-only path and the
    -- bars' background, edges, ticks and text, the block headers and the icon wells kept the old skin
    withWorld(function()
        W.Show()
        local Skin = M.LibStub("LibKa0s-Skin-1.0")
        local source, current = Skin:GetChoice("SkillMaster")
        local other
        for _, def in ipairs(Skin:Skins()) do if def.key ~= current then other = def.key break end end
        assertTrue(other ~= nil, "a second skin to switch to")
        local styled, headerPaints, wellPaints = 0, 0, 0
        local rows = W.Rows()
        assertTrue(#rows > 0, "rows to restyle")
        local realStyle = {}
        for _, row in ipairs(rows) do
            local real = row.bar.ApplyStyle
            realStyle[row] = real
            row.bar.ApplyStyle = function(bar, s) styled = styled + 1 return real(bar, s) end
            local wr = row.iconBg.SetColorTexture
            row.iconBg.SetColorTexture = function(t, ...) wellPaints = wellPaints + 1 return wr(t, ...) end
        end
        local header = W.HeaderFor("weapon")
        local hr = header.bg.SetColorTexture
        header.bg.SetColorTexture = function(t, ...) headerPaints = headerPaints + 1 return hr(t, ...) end
        local ok, err = pcall(function() Skin:SetChoice("SkillMaster", source, other) end)
        Skin:SetChoice("SkillMaster", source, current)
        for _, row in ipairs(rows) do row.bar.ApplyStyle, row.iconBg.SetColorTexture = realStyle[row], nil end
        header.bg.SetColorTexture = nil
        if not ok then error(err, 0) end
        assertTrue(styled >= #rows, ("every bar restyled (%d of %d)"):format(styled, #rows))
        assertTrue(wellPaints >= #rows, "every icon well repainted")
        assertTrue(headerPaints >= 1, "the block header repainted")
    end)
end)
