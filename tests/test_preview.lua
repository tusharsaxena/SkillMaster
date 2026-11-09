-- tests/test_preview.lua — test mode's data swap (preview-mode, plan Task 5.2): on, every data source
-- (the blocks, the bonuses, the broker, the row tooltip, the Journal's log and alts, the stats and the
-- summary line) draws the sample Dwarf Hunter of defaults/Preview_Forever.lua; off, the live data again.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function liveModel()
    local function skill(key, name, category, rank, max)
        return { key = key, name = name, category = category, kind = "craft", rank = rank, max = max,
                 modifier = 0, tempPoints = 0, learned = true }
    end
    return {
        byKey = { tailoring = skill("tailoring", "Tailoring", "primary", 33, 75) },
        order = { primary = { "tailoring" }, secondary = {}, weapon = {}, other = {} },
    }
end

--- A distinct live character: one profession, published as the live scan would.
local function installLive()
    local m = liveModel()
    NS.SkillData:Adopt(m)
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, m)
    return m
end

local function testModeOff()
    if NS.IsTestMode() then NS.ToggleTestMode() end
end

local function find(entries, key)
    for _, r in ipairs(entries) do if r.entry.key == key then return r.entry end end
    return nil
end

test("preview: test mode draws the sample Dwarf Hunter in every block", function()
    testModeOff()
    installLive()
    assertTrue(NS.ToggleTestMode(), "test mode on")
    local skills, stats = NS.Blocks.Data()
    local lw = skills.byKey.leatherworking
    assertEqual(lw.rank, 146) assertEqual(lw.max, 150)
    assertEqual(skills.byKey.skinning.rank, 122)
    assertEqual(skills.byKey.cooking.rank, 133)
    assertEqual(skills.byKey.firstAid.rank, 121)
    assertEqual(skills.byKey.fishing.rank, 107) assertEqual(skills.byKey.fishing.modifier, 25)
    assertEqual(skills.byKey.guns.rank, 105) assertEqual(skills.byKey.guns.modifier, 5)
    assertEqual(skills.byKey.guns.max, 110)
    assertEqual(skills.byKey.bows.rank, 81)
    assertEqual(skills.byKey.daggers.rank, 74)
    assertEqual(skills.byKey.twoHandedAxes.rank, 107)
    assertEqual(skills.byKey.defense.rank, 100) assertEqual(skills.byKey.defense.max, 110)
    for _, key in ipairs({ "fistWeapons", "polearms", "thrown", "riding" }) do
        assertFalse(skills.byKey[key].learned, key .. " is unlearned")
    end
    assertEqual(skills.byKey.tailoring, nil, "no live row leaks into the sample")
    assertTrue(find(NS.Blocks.Entries("weapon"), "guns") ~= nil, "the weapon block draws the sample")
    local agility
    for _, e in ipairs(stats.base) do if e.key == "agility" then agility = e end end
    assertEqual(agility.display, "112")
    assertEqual(agility.pct, 100, "the highest primary is the reference")
    testModeOff()
end)

test("preview: the bonuses are the sample's: the Dwarf racial on Guns, the lure's timer on Fishing", function()
    testModeOff()
    installLive()
    NS.ToggleTestMode()
    local guns = NS.Bonuses:Breakdown("guns")
    assertEqual(guns.total, 5)
    assertEqual(guns.sources[1].source, "racial")
    assertEqual(guns.sources[1].amount, 5)
    local fishing = NS.Bonuses:Breakdown("fishing")
    assertEqual(fishing.sources[1].label, "Shiny Bauble")
    assertEqual(fishing.sources[1].kind, "temp")
    assertEqual(math.floor(fishing.sources[1].expires - M.GetTime() + 0.5), 252, "4:12 left")
    testModeOff()
end)

test("preview: the broker, the summary line and the row tooltip read the sample", function()
    testModeOff()
    installLive()
    NS.ToggleTestMode()
    local ctx = NS.Broker.Context()
    assertTrue(ctx.skills.byKey.guns ~= nil, "the feeds' model is the sample")
    assertEqual(ctx.level, 22)
    assertEqual(ctx.gains, 14, "the sample session's +14")
    assertEqual(ctx.last.key, "bows")
    local who, gains = NS.MainWindow.SummaryParts(NS.Blocks.Data())
    assertEqual(who, "Lv 22 \194\183 Dwarf Hunter")
    assertTrue(gains:find("+14", 1, true) ~= nil, gains)
    assertEqual(NS.Preview.Character().level, 22)
    testModeOff()
end)

test("preview: the Journal's session log and alts are the sample's", function()
    testModeOff()
    installLive()
    NS.ToggleTestMode()
    local log = NS.Preview.Log()
    assertTrue(log ~= NS.SessionLog, "a view, not the live log")
    local entries = log:Entries()
    assertEqual(#entries, 14)
    assertEqual(entries[#entries].key, "bows", "the newest is Bows 80 -> 81")
    assertEqual(entries[#entries].zone, "Loch Modan")
    assertEqual((log:Gains()), 14)
    assertTrue(type(log:ETA("leatherworking")) == "number", "the sample has an ETA")
    local alts = NS.Preview.Alts():List()
    assertEqual(#alts, 4)
    assertEqual(alts[1].record.name, "Ember Ironsong")
    assertTrue(alts[1].isCurrent, "this character first")
    assertEqual(alts[1].record.skills.leatherworking.rank, 146)
    assertFalse(NS.Preview.Alts():Forget(alts[2].key), "the sample forgets nothing")
    NS.Journal.Show()
    NS.Journal.SelectTab("alts")
    NS.Journal.Hide()
    testModeOff()
end)

test("preview: test mode off restores the live data in every source", function()
    testModeOff()
    local live = installLive()
    local entriesBefore = #NS.SessionLog:Entries()
    NS.ToggleTestMode()
    assertTrue(NS.Preview.IsOn())
    NS.ToggleTestMode()
    assertFalse(NS.IsTestMode())
    assertFalse(NS.Preview.IsOn())
    assertEqual(NS.Blocks.source, nil) assertEqual(NS.Bonuses.source, nil) assertEqual(NS.Broker.source, nil)
    local skills = NS.Blocks.Data()
    assertTrue(skills == live, "the blocks draw the live model again")
    assertTrue(NS.Broker.Context().skills == live, "the feeds draw the live model again")
    assertEqual(NS.Bonuses:Breakdown("guns").total, 0, "no sample bonus survives")
    assertTrue(NS.Preview.Log() == NS.SessionLog, "the live log")
    assertTrue(NS.Preview.Alts() == NS.Alts, "the live alts")
    assertEqual(#NS.SessionLog:Entries(), entriesBefore, "the sample wrote nothing into the live log")
    assertEqual(NS.Preview.Character().level, M.UnitLevel("player"))
end)

test("preview: combat ends test mode and puts the live data back", function()
    testModeOff()
    local live = installLive()
    NS.ToggleTestMode()
    NS.addon:OnEnterCombat()
    assertFalse(NS.IsTestMode())
    assertTrue(NS.Blocks.Data() == live)
end)
