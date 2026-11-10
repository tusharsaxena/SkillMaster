local _, _ = ...
-- tests/test_m6_fixes.lua — the M6 audit and review fixes (docs/audits/2026-11-10, docs/reviews/2026-11-10):
-- every layout and hide write reaches the one seam (SM-01, F-002), and the review's behavior fixes.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, I = NS.Blocks, NS.Interact

--- Run `fn` with NS.SetByPath wrapped: answers the paths written, in order, and the LAYOUT_CHANGED
--- count, both over the whole of `fn`.
local function throughSeam(fn)
    local paths, seen = {}, 0
    local real = NS.SetByPath
    NS.SetByPath = function(path, ...)
        paths[#paths + 1] = path
        return real(path, ...)
    end
    local target = NS.NewBusTarget()
    target:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() seen = seen + 1 end)
    local ok, err = pcall(fn)
    target:UnregisterMessage(NS.MSG.LAYOUT_CHANGED)
    NS.SetByPath = real
    if not ok then error(err, 0) end
    return paths, seen
end

local function has(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

test("SM-01: a header-click collapse is stored through NS.SetByPath and sends one LAYOUT_CHANGED", function()
    -- red under: B:SetCollapsed writing layout.blocks.<id>.collapsed straight into the profile
    local s = NS.db.profile.layout.blocks.weapon
    local paths, seen = throughSeam(function() B:ToggleCollapsed("weapon") end)
    assertTrue(s.collapsed, "stored")
    assertTrue(has(paths, "layout.blocks.weapon.collapsed"), "through the seam")
    assertEqual(seen, 1, "one LAYOUT_CHANGED")
    paths = throughSeam(function() B:ToggleCollapsed("weapon") end)
    assertFalse(s.collapsed, "expanded again")
    assertTrue(has(paths, "layout.blocks.weapon.collapsed"), "the expand too")
end)

test("SM-01: the dock buttons (detach, dock) are stored through NS.SetByPath", function()
    -- red under: B:Detach / B:Dock writing layout.blocks.<id>.docked straight into the profile
    local s = NS.db.profile.layout.blocks.other
    local paths, seen = throughSeam(function() B:Detach("other") end)
    assertFalse(s.docked, "detached")
    assertTrue(has(paths, "layout.blocks.other.docked"), "detach through the seam")
    assertEqual(seen, 1, "one LAYOUT_CHANGED")
    paths, seen = throughSeam(function() B:Dock("other") end)
    assertTrue(s.docked, "docked")
    assertTrue(has(paths, "layout.blocks.other.docked"), "dock through the seam")
    assertEqual(seen, 1, "one LAYOUT_CHANGED")
end)

test("SM-01: a drag move renumbers every changed block through the seam with one LAYOUT_CHANGED", function()
    -- red under: B:Move assigning B.Settings(id).order in a loop
    local before = B.Ordered()
    local paths, seen = throughSeam(function() assertTrue(B:Move(1, 3), "moved") end)
    local after = B.Ordered()
    assertEqual(after[3], before[1], "the dragged block lands at 3")
    assertEqual(seen, 1, "one LAYOUT_CHANGED for the whole drag")
    assertTrue(has(paths, "layout.blocks." .. before[1] .. ".order"), "the moved block's order")
    assertTrue(has(paths, "layout.blocks." .. before[2] .. ".order"), "a shifted block's order")
    for i, id in ipairs(after) do assertEqual(NS.db.profile.layout.blocks[id].order, i, id .. " renumbered") end
    throughSeam(function() B:Move(3, 1) end)
    assertEqual(table.concat(B.Ordered(), ","), table.concat(before, ","), "moved back")
end)

test("SM-01: the row menu's Hide is stored through NS.SetByPath", function()
    -- red under: hideRow writing NS.db.profile.skills.hidden[key] directly
    local row = { kind = "skill", entry = { key = "guns", name = "Guns", rank = 1, max = 5 } }
    local hide
    for _, r in ipairs(I.MenuRows(row)) do if r.value == "hide" then hide = r end end
    local paths, seen = throughSeam(function() hide.onClick("hide", hide) end)
    assertTrue(NS.db.profile.skills.hidden.guns, "hidden")
    assertTrue(has(paths, "skills.hidden.guns"), "through the seam")
    assertTrue(seen >= 1, "the look repaints")
    NS.SetByPath("skills.hidden.guns", false)
    assertEqual(NS.db.profile.skills.hidden.guns, nil, "cleared, not stored as false")
end)

test("F-002: a hidden skill the catalog does not know is shown again by the Skills page Defaults", function()
    -- red under: no settings row reaching skills.hidden as a set (the key stays hidden until a profile reset)
    local row = { kind = "skill", entry = { key = "other:Jewelcrafting", name = "Jewelcrafting", rank = 1, max = 5 } }
    local hide
    for _, r in ipairs(I.MenuRows(row)) do if r.value == "hide" then hide = r end end
    local paths = throughSeam(function() hide.onClick("hide", hide) end)
    assertTrue(NS.db.profile.skills.hidden["other:Jewelcrafting"], "hidden")
    assertTrue(#paths >= 1, "through the seam")
    NS.SchemaRuntime.BulkRun("reset", "skills", function()
        for _, r in ipairs(NS.SchemaForPage("skills")) do NS.ApplyDefault(r) end
    end)
    assertEqual(NS.db.profile.skills.hidden["other:Jewelcrafting"], nil, "the page Defaults shows it again")
end)

test("F-012: standing up re-reads the stats and the bonuses, so no simulated value outlives a disable", function()
    -- red under: an NS.StandUp without NS.StatData:Request() / NS.Bonuses.Refresh() (the Simulator's
    -- stand-down cleanup returns before its own re-read, modules/Simulator.lua)
    local SD, BO = NS.StatData, NS.Bonuses
    local realReq, realRef, asked, refreshed = SD.Request, BO.Refresh, 0, 0
    SD.Request = function(...) asked = asked + 1 return realReq(...) end
    BO.Refresh = function(...) refreshed = refreshed + 1 return realRef(...) end
    local ok, err = pcall(function()
        NS.SetByPath("enabled", false)
        asked, refreshed = 0, 0
        NS.SetByPath("enabled", true)
    end)
    SD.Request, BO.Refresh = realReq, realRef
    if not ok then error(err, 0) end
    assertTrue(asked >= 1, "the stats are re-read on stand-up")
    assertTrue(refreshed >= 1, "the bonuses are re-read on stand-up")
end)

-- F-001 (localization-§4): a deDE client answers German names; the IDs still match.
local function deLine(name, id, rank, max, header)
    return { rec = { name = name, skillLineID = id, isHeader = false, rank = rank, tempPoints = 0, modifier = 0,
                     max = max }, header = header }
end

test("F-001: a skill line is matched on its skill-line ID, so a German client's lines land on their rows", function()
    -- red under: SkillData classifying on the localized name alone (Angeln lands in Other as other:Angeln)
    local m = NS.SkillData.Build({
        deLine("Angeln", 356, 107, 150, "Sekundäre Fertigkeiten"),
        deLine("Lederverarbeitung", 165, 146, 150, "Berufe"),
        deLine("Schusswaffen", 46, 105, 110, "Waffenfertigkeiten"),
        deLine("Widderreiten", 152, 75, 75, "Sekundäre Fertigkeiten"),
    }, { classFile = "HUNTER", level = 22 })
    assertTrue(m.byKey.fishing ~= nil and m.byKey.fishing.rank == 107, "Angeln is Fishing")
    assertEqual(m.byKey.leatherworking and m.byKey.leatherworking.category, "primary", "a profession is primary")
    assertTrue(m.byKey.guns ~= nil and m.byKey.guns.learned, "a learned weapon is not shown as Not learned")
    assertTrue(m.byKey.riding ~= nil, "a racial riding line is the one Riding row")
    assertEqual(m.byKey["other:Angeln"], nil, "nothing lands in Other")
    assertEqual(#m.order.other, 1, "Other holds Riding only")
end)

test("F-001: the adapter carries the struct's skill-line ID", function()
    local saved = M.C_SkillInfo
    M.C_SkillInfo = {
        GetNumSkillLines = function() return 1 end,
        GetSkillLineInfo = function() return { skillName = "Angeln", skillLineID = 356, skillRank = 1, skillMaxRank = 75 } end,
    }
    local r = NS.Compat.SkillLineInfo(1)
    M.C_SkillInfo = saved
    assertEqual(r.skillLineID, 356)
end)

test("F-001: a crafting overlay casts the open spell by the name its spell ID resolves to", function()
    -- red under: SecureOverlay's spellFor reading L[cat.openSpell] (the enUS name) before the ID
    local saved = M.C_Spell
    local ids = {}
    M.C_Spell = { GetSpellName = function(id) ids[#ids + 1] = id return id == 2259 and "Alchimie" or nil end }
    local spell = NS.SecureOverlay.SpellFor({ kind = "skill", entry = { key = "alchemy", learned = true } })
    local mining = NS.SecureOverlay.SpellFor({ kind = "skill", entry = { key = "mining", learned = true } })
    M.C_Spell = saved
    assertEqual(spell, "Alchimie", "the localized name from the ID")
    assertEqual(ids[1], 2259, "asked by ID")
    assertEqual(mining, "Smelting", "no name for the ID: the locale key's")
    assertEqual(NS.SecureOverlay.SpellFor({ kind = "skill", entry = { key = "guns", learned = true } }), nil)
end)

test("F-003: a data repaint keeps a shown detached frame where it is (a drag is not re-anchored)", function()
    -- red under: Blocks' STATS_UPDATED / SKILLS_UPDATED repaint calling NS.Detached.Refresh() with
    -- applyPoint on every shown frame
    B:Detach("stats_base")
    local f = NS.Detached.Frame("stats_base")
    assertTrue(f and f:IsShown(), "detached and shown")
    local cleared = 0
    local real = f.ClearAllPoints
    f.ClearAllPoints = function(self, ...) cleared = cleared + 1 return real(self, ...) end
    local ok, err = pcall(function()
        NS.bus:SendMessage(NS.MSG.STATS_UPDATED, NS.StatData:Scan())
        NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, NS.SkillData:Model())
    end)
    f.ClearAllPoints = real
    B:Dock("stats_base")
    if not ok then error(err, 0) end
    assertEqual(cleared, 0, "a data message re-anchored the detached frame")
end)

test("F-003: the speed ticker rescans only when the speed changed", function()
    -- red under: S:WatchSpeed's ticker calling S:Request() on every tick
    local SD = NS.StatData
    local realReq, realSpeed, asked = SD.Request, NS.Compat.UnitSpeed, 0
    local speed = 7
    SD.Request = function() asked = asked + 1 end
    NS.Compat.UnitSpeed = function() return speed, 7, 7, 4.7 end
    local ok, err = pcall(function()
        SD:SpeedTick()
        asked = 0
        SD:SpeedTick()
        SD:SpeedTick()
        assertEqual(asked, 0, "an unchanged speed asks for no rescan")
        speed = 14
        SD:SpeedTick()
        assertEqual(asked, 1, "a changed speed asks for one")
    end)
    SD.Request, NS.Compat.UnitSpeed = realReq, realSpeed
    if not ok then error(err, 0) end
end)
