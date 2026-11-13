-- tests/test_polish.lua — the M3/M4 review leftovers (M5 polish): the broker tooltip's owner check
-- and footer, the detached weapon block's equipped/below-cap filter and marker, the one-line
-- gathering hint, the secure overlays following a raise and a drag, and the Journal's resize grip.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, D, W, SO, J, R = NS.Broker, NS.Detached, NS.MainWindow, NS.SecureOverlay, NS.Journal, NS.Rows
local LAYERS = NS.Constants.LAYERS

local function skill(key, name, category, rank, max, modifier, learned)
    return { key = key, name = name, category = category, kind = NS.SkillCatalog[key] and NS.SkillCatalog[key].kind,
             rank = rank, max = max, tempPoints = 0, modifier = modifier or 0, learned = learned ~= false }
end

-- The mockup's Dwarf Hunter (Detached.dc.html's weapon block): Guns equipped, Two-Handed Axes and
-- Daggers below the cap, Staves at it, Fist Weapons not learned.
local function fixture()
    local byKey = {
        tailoring     = skill("tailoring", "Tailoring", "primary", 146, 150),
        skinning      = skill("skinning", "Skinning", "primary", 122, 150),
        mining        = skill("mining", "Mining", "primary", 70, 75),
        fishing       = skill("fishing", "Fishing", "secondary", 107, 150, 25),
        guns          = skill("guns", "Guns", "weapon", 105, 110, 5),
        daggers       = skill("daggers", "Daggers", "weapon", 74, 110),
        twoHandedAxes = skill("twoHandedAxes", "Two-Handed Axes", "weapon", 107, 110),
        staves        = skill("staves", "Staves", "weapon", 110, 110),
        fistWeapons   = skill("fistWeapons", "Fist Weapons", "weapon", 0, 0, 0, false),
    }
    local skills = { byKey = byKey, order = {
        primary = { "tailoring", "skinning", "mining" }, secondary = { "fishing" },
        weapon = { "guns", "daggers", "twoHandedAxes", "staves", "fistWeapons" }, other = {} } }
    return skills, { base = {}, spell = {}, defense = {}, utility = {} }
end

local SWAPPED = { "InCombatLockdown", "UnitLevel", "UnitRace", "GetInventoryItemLink", "GetItemInfoInstant",
                  "GetZoneText", "C_Map" }

--- Guns in the ranged slot, nothing in the main hand: "unarmed" and "guns" are the equipped skills.
local function equipGuns()
    M.GetInventoryItemLink = function(_, slot)
        if slot == 18 then return "|Hitem:2508|h[Old Blunderbuss]|h" end
    end
    M.GetItemInfoInstant = function() return 2508, "Weapon", "Guns", "INVTYPE_RANGEDRIGHT", 0, 2, 3 end
end

local function withWorld(fn)
    local skills, stats = fixture()
    local saved, savedSource = {}, NS.Blocks.source
    for _, k in ipairs(SWAPPED) do saved[k] = M[k] end
    NS.Blocks.source = function() return skills, stats end
    M.InCombatLockdown = function() return false end
    M.UnitLevel = function() return 22 end
    M.UnitRace = function() return "Dwarf", "Dwarf" end
    equipGuns()
    local ok, err = pcall(fn, skills, stats)
    W.Hide()
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].docked = true end
    NS.db.profile.layout.blocks.weapon.belowCapOnly = false
    NS.db.profile.skills.helperHint = false
    D.Refresh()
    for _, k in ipairs(SWAPPED) do M[k] = saved[k] end
    NS.Blocks.source = savedSource
    SO:Sync()
    if not ok then error(err, 0) end
end

local function keysOf(rows)
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = row.entry and row.entry.key end
    return table.concat(out, ",")
end

local function rowIn(rows, key)
    for _, row in ipairs(rows) do if row.entry and row.entry.key == key then return row end end
end

-- ---------------------------------------------------------------------------------------------
-- 1. The broker tooltip's leave poll never hides a tooltip another frame owns
-- ---------------------------------------------------------------------------------------------

test("broker: the leave poll hides GameTooltip only while the feed still owns it", function()
    -- red under: a poll that hides GameTooltip without asking tip:GetOwner() == the feed's cell.
    local tip = M.GameTooltip
    local cell = M.CreateFrame("Frame", nil, M.UIParent)
    local other = M.CreateFrame("Frame", nil, M.UIParent)
    local savedOwner, savedSet, savedOver = tip.GetOwner, tip.SetOwner, tip.IsMouseOver
    local current
    rawset(tip, "SetOwner", function(_, f) current = f end)
    rawset(tip, "GetOwner", function() return current end)
    rawset(tip, "IsMouseOver", function() return false end)
    cell.IsMouseOver = function() return false end
    M.__fireTimers()
    NS.SetByPath("tooltips.ldb.style", "classic")   -- round 6: the Classic style draws on GameTooltip
    NS.SetByPath("broker.tooltip.skin", false)   -- the plain tooltip is the shared GameTooltip

    B.OnEnter(cell)
    assertTrue(tip:IsShown(), "the feed's tooltip shows")
    B.OnLeave()
    tip:SetOwner(other, "ANCHOR_RIGHT")   -- another addon takes GameTooltip before the poll runs
    tip:Show()
    M.__now = M.__now + 1
    M.__fireTimers()
    assertTrue(tip:IsShown(), "a tooltip another frame owns is left alone")

    B.OnEnter(cell)
    B.OnLeave()
    M.__now = M.__now + 1
    M.__fireTimers()
    assertFalse(tip:IsShown(), "the feed's own tooltip hides once the pointer has left")

    rawset(tip, "GetOwner", savedOwner)
    rawset(tip, "SetOwner", savedSet)
    rawset(tip, "IsMouseOver", savedOver)
    tip:Hide()
    NS.SetByPath("broker.tooltip.skin", NS.defaults.profile.broker.tooltip.skin)
    NS.SetByPath("tooltips.ldb.style", NS.defaults.profile.tooltips.ldb.style)
end)

-- ---------------------------------------------------------------------------------------------
-- 2. The broker tooltip's footer and the feed's right-click
-- ---------------------------------------------------------------------------------------------

test("broker: the footer reads as the mockup; a right-click opens the Broker settings page", function()
    local lines = {}
    local tip = M.CreateFrame("GameTooltip", "SkillMasterPolishTip", M.UIParent)
    function tip:AddLine(t) lines[#lines + 1] = t end
    function tip:AddDoubleLine(l) lines[#lines + 1] = l end
    function tip:NumLines() return #lines end
    B.FillTooltip(tip)
    local footer = lines[#lines]
    assertTrue(footer:find("Click label: toggle window \194\183 Right-click label: options \194\183 Rows: click to open, right-click for the menu",
        1, true) ~= nil, footer)

    local H, opened = NS.Helpers, {}
    local savedOpen, savedNS = H.OpenOptionsPanel, NS.OpenOptionsPanel
    rawset(H, "OpenOptionsPanel", function(page) opened[#opened + 1] = tostring(page) return true end)
    NS.OpenOptionsPanel = function() opened[#opened + 1] = "main" end
    M.__ldbObjects["Skill Master"].OnClick(nil, "RightButton")
    assertEqual(table.concat(opened, ","), "broker", "the Broker page, by its page key")

    -- No page opener (the library absent): the main panel; no opener at all: nothing, no error.
    rawset(H, "OpenOptionsPanel", nil)
    M.__ldbObjects["Skill Master"].OnClick(nil, "RightButton")
    assertEqual(table.concat(opened, ","), "broker,main")
    NS.OpenOptionsPanel = nil
    M.__ldbObjects["Skill Master"].OnClick(nil, "RightButton")
    rawset(H, "OpenOptionsPanel", savedOpen)
    NS.OpenOptionsPanel = savedNS
    assertEqual(B.SETTINGS_PAGE, "broker")
end)

-- ---------------------------------------------------------------------------------------------
-- 3. The detached compact preset: only equipped + below-cap, and the equipped marker
-- ---------------------------------------------------------------------------------------------

test("helpers: the equipped weapon skills read the main hand, off hand and ranged slots", function()
    withWorld(function()
        local eq = NS.SkillHelpers.EquippedWeaponSkills()
        assertTrue(eq.guns and eq.unarmed, "guns in the ranged slot, an empty main hand is unarmed")
        assertFalse(eq.daggers ~= nil, "nothing else")
        assertEqual(B.MainHandSkill(), "unarmed", "the broker's main hand reads the same helper")
    end)
end)

test("detached: the weapon block marks the equipped weapon; the compact filter keeps equipped + below-cap", function()
    -- red under: a filter that keeps a capped or unlearned weapon, drops the equipped one, or a
    -- marker that is lost on a values-only refresh.
    withWorld(function()
        NS.db.profile.layout.blocks.weapon.docked = false
        D.Refresh()
        local rows = D.Rows("weapon")
        assertEqual(keysOf(rows), "guns,daggers,twoHandedAxes,staves,fistWeapons", "the filter is off by default")
        local guns = rowIn(rows, "guns")
        assertEqual(guns.name:GetText(), "> Guns", "the equipped weapon carries the marker")
        assertEqual(rowIn(rows, "daggers").name:GetText(), "Daggers")
        D.RefreshValues()
        assertEqual(guns.name:GetText(), "> Guns", "kept through a values-only refresh")

        NS.db.profile.layout.blocks.weapon.belowCapOnly = true
        D.Refresh()
        assertEqual(keysOf(D.Rows("weapon")), "guns,daggers,twoHandedAxes",
            "the capped Staves and the unlearned Fist Weapons are filtered out")

        -- Daggers equipped and Guns at its cap: the equipped one stays even at the cap.
        M.GetInventoryItemLink = function(_, slot) if slot == 16 then return "|Hitem:2092|h[Worn Dagger]|h" end end
        M.GetItemInfoInstant = function() return 2092, "Weapon", "Daggers", "INVTYPE_WEAPON", 0, 2, 15 end
        NS.Blocks.Data().byKey.daggers.rank = 110
        D.Refresh()
        assertEqual(keysOf(D.Rows("weapon")), "guns,daggers,twoHandedAxes")
        assertEqual(rowIn(D.Rows("weapon"), "guns").name:GetText(), "Guns", "the marker follows the equipment")

        NS.db.profile.layout.blocks.weapon.docked = true
        D.Refresh()
        local pool = R.NewPool()
        local row = R.Acquire(pool, M.UIParent, "row")
        row:SetSkill(NS.Blocks.Data().byKey.guns)
        assertEqual(row.name:GetText(), "Guns", "a pooled row is unmarked once released and re-acquired")
        R.ReleaseAll(pool)
    end)
end)

test("detached: an equipment change redraws a shown weapon block", function()
    withWorld(function()
        NS.db.profile.layout.blocks.weapon.docked = false
        D.Refresh()
        assertEqual(rowIn(D.Rows("weapon"), "guns").name:GetText(), "> Guns")
        M.GetInventoryItemLink = function() return nil end
        M.__fireEvent("PLAYER_EQUIPMENT_CHANGED", 18)
        assertEqual(rowIn(D.Rows("weapon"), "guns").name:GetText(), "Guns")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- 4. The optional one-line gathering / fishing hint under a row
-- ---------------------------------------------------------------------------------------------

test("rows: the gathering hint is off by default and reads NS.SkillHelpers when on", function()
    -- red under: a hint drawn with skills.helperHint off, or one that does not come from the helpers.
    withWorld(function(skills)
        assertFalse(NS.db.profile.skills.helperHint, "off by default")
        assertEqual(R.HelperHint(skills.byKey.skinning), nil, "no hint while off")
        NS.db.profile.skills.helperHint = true
        assertEqual(R.HelperHint(skills.byKey.skinning), "Skinning 122: mobs up to Lv 24")
        local mining = R.HelperHint(skills.byKey.mining)
        assertTrue(mining ~= nil and mining:find("75", 1, true) ~= nil, tostring(mining))
        M.GetZoneText = function() return "Loch Modan" end
        M.C_Map = nil
        local need = NS.SkillHelpers.FishingNeedHere()
        assertTrue(need ~= nil, "the fixture zone is in the fishing table")
        local fish = R.HelperHint(skills.byKey.fishing)
        assertTrue(fish:find("Loch Modan", 1, true) ~= nil and fish:find(tostring(need), 1, true) ~= nil, fish)
        assertEqual(R.HelperHint(skills.byKey.guns), nil, "a weapon has no gathering hint")
        assertEqual(R.HelperHint(skills.byKey.tailoring), nil, "nor a craft")
        M.GetZoneText = function() return "Nowhere Known" end
        assertTrue(R.HelperHint(skills.byKey.fishing) ~= nil, "a zone the table lacks still says so, one line")
    end)
end)

test("rows: a hinted row is one line taller and shows its hint; the setting off hides it", function()
    withWorld(function(skills)
        local pool = R.NewPool()
        local h = NS.db.profile.bars.rowHeight
        local heights = {}
        local row = R.Acquire(pool, M.UIParent, "row")
        rawset(row, "SetHeight", function(self, v) heights[#heights + 1] = v self.__h = v end)
        rawset(row, "GetHeight", function(self) return self.__h end)
        NS.db.profile.skills.helperHint = true
        R.ReleaseAll(pool)
        row = R.Acquire(pool, M.UIParent, "row")
        row:SetSkill(skills.byKey.skinning)
        assertTrue(row.hint:IsShown(), "the hint shows")
        assertEqual(row.hint:GetText(), "Skinning 122: mobs up to Lv 24")
        assertEqual(row:GetHeight(), h + R.HINT_H, "one hint line taller")
        row:SetSkill(skills.byKey.guns)
        assertFalse(row.hint:IsShown(), "no hint on a weapon row")
        assertEqual(row:GetHeight(), h)
        NS.db.profile.skills.helperHint = false
        row:SetSkill(skills.byKey.skinning)
        assertFalse(row.hint:IsShown(), "hidden with the setting off")
        assertEqual(row:GetHeight(), h)
        R.ReleaseAll(pool)
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- 5. The secure overlays follow a raise and a drag
-- ---------------------------------------------------------------------------------------------

test("secure overlay: raising the window re-levels its overlays above the rows (out of combat only)", function()
    -- red under: an overlay left at the old level after the window is raised, or a re-level in combat.
    withWorld(function()
        W.Show()
        rowIn(W.Rows(), "tailoring"):__fire("OnEnter")   -- only the hovered crafting row is armed
        local f, lw = W.Frame(), SO.Overlay("tailoring")
        assertTrue(lw ~= nil and lw:IsShown(), "armed")
        f:SetFrameLevel(40)               -- a toplevel window raised by a click
        f:__fire("OnMouseDown", "LeftButton")
        assertEqual(lw:GetFrameLevel(), 40 + LAYERS.LEVEL.SECURE, "re-leveled with the window")
        f:SetFrameLevel(60)
        f:Raise()
        f:__fire("OnShow")
        assertEqual(lw:GetFrameLevel(), 60 + LAYERS.LEVEL.SECURE, "and on show")
        M.InCombatLockdown = function() return true end
        f:SetFrameLevel(80)
        f:__fire("OnMouseDown", "LeftButton")
        assertEqual(lw:GetFrameLevel(), 60 + LAYERS.LEVEL.SECURE, "nothing moves in combat")
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        assertEqual(lw:GetFrameLevel(), 80 + LAYERS.LEVEL.SECURE, "caught up after combat")
        f:SetFrameLevel(LAYERS.LEVEL.SECURE)
    end)
end)

test("secure overlay: a row click raises too; a detached frame's mouse-down re-levels its overlays", function()
    withWorld(function()
        W.Show()
        rowIn(W.Rows(), "tailoring"):__fire("OnEnter")
        local f, lw = W.Frame(), SO.Overlay("tailoring")
        f:SetFrameLevel(30)
        local row = rowIn(W.Rows(), "skinning")
        row:__fire("OnMouseDown", "LeftButton")
        assertEqual(lw:GetFrameLevel(), 30 + LAYERS.LEVEL.SECURE, "a click on a row raises the window")
        W.Hide()
        NS.db.profile.layout.blocks.primary.docked = false
        D.Refresh()
        local df = D.Frame("primary")
        rowIn(D.Rows("primary"), "tailoring"):__fire("OnEnter")
        df:SetFrameLevel(12)
        df:__fire("OnMouseDown", "LeftButton")
        assertEqual(lw:GetFrameLevel(), 12 + LAYERS.LEVEL.SECURE, "over the detached frame's row")
    end)
end)

test("secure overlay: a dragged window's overlays come down for the drag and back at the drop", function()
    -- red under: an overlay left live at the old place while its window moves (it trails the drag).
    withWorld(function()
        W.Show()
        rowIn(W.Rows(), "tailoring"):__fire("OnEnter")
        local f, lw = W.Frame(), SO.Overlay("tailoring")
        assertTrue(lw:IsShown())
        NS.SetByPath("locked", false)
        f:GetScript("OnDragStart")(f)
        assertFalse(lw:IsShown(), "no overlay trails the window during the drag")
        f:GetScript("OnDragStop")(f)
        assertTrue(lw:IsShown(), "re-synced over the row at the drop")

        NS.Blocks:Detach("primary")   -- LAYOUT_CHANGED: the window lets go of the rows too
        local df = D.Frame("primary")
        rowIn(D.Rows("primary"), "tailoring"):__fire("OnEnter")   -- the detached frame's own row
        assertTrue(lw:IsShown() and lw.row.entry.key == "tailoring")
        df:GetScript("OnDragStart")(df)
        assertFalse(lw:IsShown(), "a detached frame's too")
        df:GetScript("OnDragStop")(df)
        assertTrue(lw:IsShown())
        NS.db.profile.layout.blocks.primary.point = false
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- 6. The Journal's resize grip (standalone-windows, Resizing)
-- ---------------------------------------------------------------------------------------------

test("journal: a grip drag lays out at most once per frame and redraws once, after the release", function()
    -- red under: a handler that runs the full redraw (J.Render) from OnSizeChanged, a layout pass
    -- per size change rather than per frame, or a size written before the release.
    J.Show()
    local f = J.Frame()
    local grip = f.resizeGrip
    assertTrue(grip ~= nil, "the Journal has a resize grip")
    local minW, minH = f:GetResizeBounds()
    assertEqual(minW, 720, "never narrower than its default (720 since round 4)")
    assertEqual(minH, 420, "never shorter")
    NS.db.profile.journal.size = false

    local realRender, realRelayout = J.Render, J.Relayout
    local renders, layouts = 0, 0
    J.Render = function(...) renders = renders + 1 return realRender(...) end
    J.Relayout = function(...) layouts = layouts + 1 return realRelayout(...) end
    local driver = f.resizeDriver
    local function frameTick() driver:__fire("OnUpdate", 0.016) end

    grip:__fire("OnMouseDown", "LeftButton")
    local perFrame = {}
    for i = 1, 3 do
        local before = layouts
        for step = 1, 3 do
            f:__setGeom(640 + i * 30 + step, 420 + i * 40 + step)
            f:__fire("OnSizeChanged", f:GetWidth(), f:GetHeight())
        end
        frameTick()
        perFrame[i] = layouts - before
    end
    assertEqual(renders, 0, "no full redraw while sizing")
    assertFalse(NS.db.profile.journal.size, "the size is not written per tick")
    for i = 1, 3 do assertTrue(perFrame[i] <= 1, "frame " .. i .. " ran " .. perFrame[i] .. " layout passes") end
    grip:__fire("OnMouseUp", "LeftButton")
    frameTick()
    assertEqual(renders, 1, "the full redraw runs once, after the release")
    local size = NS.db.profile.journal.size
    assertEqual(size and size.w, 733)
    assertEqual(size and size.h, 543)
    assertEqual(J.VisibleLogRows(), math.floor((543 - 58 - 12 - 20) / 18), "the taller window shows more rows")

    J.Render, J.Relayout = realRender, realRelayout
    J.Hide()
end)

test("journal: the saved size is restored, clamped to the minimum; locked refuses the grip", function()
    J.Show()
    local f = J.Frame()
    local sizes = {}
    rawset(f, "SetSize", function(_, w, h) sizes[#sizes + 1] = w .. "x" .. h end)
    NS.db.profile.journal.size = { w = 300, h = 900 }
    J.ApplySize()
    NS.db.profile.journal.size = { w = 800, h = 500 }
    J.ApplySize()
    rawset(f, "SetSize", nil)
    assertEqual(table.concat(sizes, ","), "720x900,800x500")

    NS.SetByPath("locked", true)
    local before = f.__sizingCount
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    assertEqual(f.__sizingCount, before, "a locked Journal does not resize")
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    NS.SetByPath("locked", false)
    NS.db.profile.journal.size = false
    J.Hide()
end)
