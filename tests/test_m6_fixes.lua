local _, _ = ...
-- tests/test_m6_fixes.lua — the M6 audit and review fixes (docs/audits/2026-11-10, docs/reviews/2026-11-10):
-- every layout and hide write reaches the one seam (SM-01, F-002), and the review's behavior fixes.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, I = NS.Blocks, NS.Interact
local loadDegraded = dofile("tests/degraded_env.lua")

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

test("F-002: a hidden skill the catalog does not know is shown again by the Rows page Defaults", function()
    -- red under: no settings row reaching skills.hidden as a set (the key stays hidden until a profile reset)
    local row = { kind = "skill", entry = { key = "other:Jewelcrafting", name = "Jewelcrafting", rank = 1, max = 5 } }
    local hide
    for _, r in ipairs(I.MenuRows(row)) do if r.value == "hide" then hide = r end end
    local paths = throughSeam(function() hide.onClick("hide", hide) end)
    assertTrue(NS.db.profile.skills.hidden["other:Jewelcrafting"], "hidden")
    assertTrue(#paths >= 1, "through the seam")
    NS.SchemaRuntime.BulkRun("reset", "rows", function()
        for _, r in ipairs(NS.SchemaForPage("rows")) do NS.ApplyDefault(r) end
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

test("F-004: every UNIT_* event is registered for the player alone, so a raid's auras never reach Lua", function()
    -- red under: Bonuses or StatData registering UNIT_AURA / UNIT_STATS / ... with RegisterEvent
    -- (every unit's change dispatched and thrown away in the handler)
    NS.SetByPath("enabled", true)
    local seen = {}
    for _, r in ipairs(M.__registrations()) do
        if r.kind ~= "message" and tostring(r.event):sub(1, 5) == "UNIT_" then
            seen[r.event] = true
            assertEqual(r.unit, "player", r.event .. " is registered for every unit")
        end
    end
    for _, ev in ipairs({ "UNIT_AURA", "UNIT_INVENTORY_CHANGED", "UNIT_STATS", "UNIT_ATTACK_POWER",
                          "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_DAMAGE" }) do
        assertTrue(seen[ev], ev .. " is registered")
    end
end)

test("F-011: the stat caps follow the level NS.Compat answers (the simulated character's in a session)", function()
    -- red under: StatData's context() reading UnitLevel("player") past the simulator's seam
    local real = NS.Compat.PlayerLevel
    NS.Compat.PlayerLevel = function() return 7 end
    local realUL = M.UnitLevel
    M.UnitLevel = function() return 60 end
    local ok, err = pcall(function()
        assertEqual(NS.StatData.LevelOf(), 7, "the scan's level is the seam's, not UnitLevel's 60")
    end)
    NS.Compat.PlayerLevel, M.UnitLevel = real, realUL
    if not ok then error(err, 0) end
end)

test("F-005: Clear log asks first, and only an accept clears the stored history", function()
    -- red under: the Clear log button calling J.ClearLog() directly
    local J = NS.Journal
    NS.db.char.log = { { t = 1, key = "fishing", old = 1, new = 2 } }
    J.Show()
    J.SelectTab("log")
    M.__popups = {}
    local clear = J.Frame().logPanel.clear
    clear:GetScript("OnClick")(clear, "LeftButton")
    assertEqual(M.__popups[1], "SKILLMASTER_CLEAR_LOG", "a confirmation")
    assertEqual(#NS.db.char.log, 1, "nothing cleared before the accept")
    M.StaticPopupDialogs.SKILLMASTER_CLEAR_LOG.OnAccept()
    assertEqual(#NS.db.char.log, 0, "cleared on accept")
    J.Hide()
end)

test("F-014: a log row from another day shows its date as well as its time", function()
    -- red under: bindLogRow formatting every row as date("%H:%M"). Since FB-32 the date is a
    -- column of its own, on every row, and the range picker must reach back to the older row.
    local J = NS.Journal
    local now = (M.time or os.time)()
    NS.db.char.log = { { t = now - 3 * 86400, key = "fishing", old = 1, new = 2 }, { t = now, key = "fishing", old = 2, new = 3 } }
    NS.SetByPath("journal.range", "all")
    J.Show()
    J.SelectTab("log")
    local dates, times = {}, {}
    for _, row in ipairs(J.Frame().logPanel.pool.active) do
        dates[#dates + 1], times[#times + 1] = row.cols[1]:GetText(), row.cols[2]:GetText()
    end
    J.Hide()
    NS.db.char.log = {}
    NS.SetByPath("journal.range", "session")
    local old = os.date(NS.L["%m/%d/%y"], now - 3 * 86400)
    assertTrue(dates[1] == old or dates[2] == old, "the older row carries its date: " .. table.concat(dates, ", "))
    assertTrue(times[1] == os.date("%H:%M", now) or times[2] == os.date("%H:%M", now), "every row its time")
end)

test("F-015: switching to a profile with a lower cap does not trim the stored log; lowering the setting does", function()
    -- red under: SessionLog:Add trimming the log to journal.keep whatever the log held before
    local SL = NS.SessionLog
    local log = {}
    for i = 1, 120 do log[i] = { t = i, key = "fishing", old = i, new = i + 1 } end
    NS.db.char.log = log
    SL:ResetFloor()
    local realGet = NS.GetSetting
    NS.GetSetting = function(path) if path == "journal.keep" then return 50 end return realGet(path) end
    local ok, err = pcall(function() SL:Add("fishing", 121, 122, 121) end)
    NS.GetSetting = realGet
    if not ok then error(err, 0) end
    assertEqual(#NS.db.char.log, 120, "the history held before is kept (oldest dropped for the new one)")
    NS.SetByPath("journal.keep", 50)
    assertEqual(#NS.db.char.log, 50, "the player's own lower setting trims")
    NS.SetByPath("journal.keep", NS.defaults.profile.journal.keep)
    NS.db.char.log = {}
    SL:ResetFloor()
end)

test("F-010: on a library-absent load the stand-down still takes every bus target's events down", function()
    -- red under: the degraded Bus stub's StandDown returning 0 without touching its targets
    local NS2, M2 = loadDegraded()
    NS2.addon:OnInitialize()
    NS2.db.profile.skin.pickerSeen = true
    NS2.addon:OnEnable()
    local before = 0
    for _, r in ipairs(M2.__registrations()) do if r.target ~= NS2.addon then before = before + 1 end end
    assertTrue(before > 0, "the data modules' targets registered something")
    NS2.SetByPath("enabled", false)
    local left = {}
    for _, r in ipairs(M2.__registrations()) do left[#left + 1] = tostring(r.event) end
    NS2.SetByPath("enabled", true)   -- the degraded loads share one store: leave it enabled
    assertEqual(table.concat(left, ", "), "", "survivors of the degraded stand-down")
end)

test("F-016: the Master controls' Enable row names the brand", function()
    -- red under: settings/General.lua passing the literal "Skill Master" as addonName
    local found
    for _, row in ipairs(NS.Schema) do if row.path == "enabled" then found = row end end
    assertTrue(found ~= nil, "the Enable row")
    assertEqual(found.label, "Enable " .. NS.Constants.BRAND)
end)
