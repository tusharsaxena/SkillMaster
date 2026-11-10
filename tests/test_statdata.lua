-- tests/test_statdata.lua — StatData: the four stat groups, each stat scaled against its reference with
-- its markers (design §6.3, plan Task 2.3), the missing-API rule and the throttled STATS_UPDATED.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNear = T.test, T.assertEqual, T.assertTrue, T.assertNear

-- Every stat API the module reads, so a test can install a fixture and put the mock back after.
local API_NAMES = {
    "UnitStat", "UnitAttackPower", "UnitRangedAttackPower", "GetCritChance", "GetRangedCritChance",
    "GetHitModifier", "GetRangedHitModifier", "GetSpellHitModifier", "GetSpellCritChance",
    "GetSpellBonusDamage", "GetSpellBonusHealing", "GetManaRegen", "UnitArmor", "UnitDefenseSkill",
    "GetDodgeChance", "GetParryChance", "GetBlockChance", "UnitResistance", "GetUnitSpeed",
    "GetInventoryItemDurability",
}

-- Str, Agi, Sta, Int, Spi of a level-22 Dwarf Hunter (the mockup's character).
local PRIMARIES = { 48, 112, 90, 30, 40 }
local RESISTS = { [2] = 10, [3] = 20, [4] = 30, [5] = 40, [6] = 0 }

local function fixture()
    return {
        UnitStat = function(_, i) local v = PRIMARIES[i] return v - 5, v, 5, 0 end,
        UnitAttackPower = function() return 200, 20, -5 end,
        UnitRangedAttackPower = function() return 150, 10, 0 end,
        GetCritChance = function() return 6.5 end,
        GetRangedCritChance = function() return 7.25 end,
        GetHitModifier = function() return 4 end,
        GetRangedHitModifier = function() return 3 end,
        GetSpellHitModifier = function() return 8 end,
        GetSpellCritChance = function(school) return school == 3 and 4 or 2 end,
        GetSpellBonusDamage = function(school) return 10 * school end,
        GetSpellBonusHealing = function() return 50 end,
        GetManaRegen = function() return 2, 1 end,
        UnitArmor = function() return 1000, 1104, 1104, 104, 0 end,
        UnitDefenseSkill = function() return 110, 0 end,
        GetDodgeChance = function() return 9.5 end,
        GetParryChance = function() return 5 end,
        GetBlockChance = function() return 0 end,
        UnitResistance = function(_, school) local v = RESISTS[school] or 0 return v, v, 0, 0 end,
        GetUnitSpeed = function() return 0, 7, 7, 4.72 end,
        GetInventoryItemDurability = function(slot)
            if slot == 1 then return 15, 60 end
            if slot == 5 then return 80, 100 end
        end,
    }
end

--- Install `apis` (name -> function, or false for "absent") at `level`; answers the restore.
local function install(apis, level)
    local saved, savedLevel = {}, M.__context.level
    for _, name in ipairs(API_NAMES) do
        saved[name] = M[name]
        local fn = apis[name]
        if fn == false then fn = nil end
        M[name] = fn
    end
    M.__context.level = level or 22
    return function()
        for _, name in ipairs(API_NAMES) do M[name] = saved[name] end
        M.__context.level = savedLevel
    end
end

local function scan(apis, level)
    local restore = install(apis or fixture(), level)
    local ok, model = pcall(NS.StatData.Scan, NS.StatData)
    restore()
    assertTrue(ok, tostring(model))
    return model
end

local function entry(model, group, key)
    for _, e in ipairs(model[group] or {}) do if e.key == key then return e end end
    return nil
end

local function markerAt(e, value)
    for _, m in ipairs(e.markers) do if m.value == value then return m end end
    return nil
end

test("statdata (primary_vs_highest): the primaries scale against the highest, Agi 112 -> 100%, Str 48 -> 42.9%", function()
    local model = scan()
    local agi, str = entry(model, "base", "agility"), entry(model, "base", "strength")
    assertEqual(agi.value, 112)
    assertEqual(agi.ref, 112, "the highest of the five")
    assertNear(agi.pct, 100, 0.05)
    assertEqual(str.value, 48)
    assertNear(str.pct, 42.9, 0.05)
    assertEqual(str.display, "48")
    assertEqual(str.label, NS.L["Strength"])
end)

test("statdata: attack power is base plus buffs against 400, crit against 30%", function()
    local model = scan()
    local ap = entry(model, "base", "attackPower")
    assertEqual(ap.value, 215)
    assertEqual(ap.ref, 400)
    assertEqual(entry(model, "base", "rangedAttackPower").ref, 400)
    local crit = entry(model, "base", "meleeCrit")
    assertEqual(crit.ref, 30)
    assertEqual(crit.display, "6.5%")
    assertEqual(entry(model, "base", "rangedCrit").ref, 30)
    assertEqual(entry(model, "spell", "spellCrit").ref, 30)
    assertEqual(entry(model, "spell", "spellCrit").value, 4, "the best school")
end)

test("statdata (hit_markers): hit scales to 9% with markers at 5% and 9%, spell hit to 16%", function()
    local model = scan()
    local hit = entry(model, "base", "meleeHit")
    assertEqual(hit.value, 4)
    assertEqual(hit.ref, 9)
    assertEqual(#hit.markers, 2)
    local same, boss = markerAt(hit, 5), markerAt(hit, 9)
    assertNear(same.at, 55.6, 0.05)
    assertEqual(same.label, NS.L["vs same level"])
    assertNear(boss.at, 100, 0.001)
    assertEqual(boss.label, NS.L["vs raid boss"])
    local spellHit = entry(model, "spell", "spellHit")
    assertEqual(spellHit.ref, 16)
    assertEqual(#spellHit.markers, 1)
    assertNear(spellHit.markers[1].at, 100, 0.001)
    assertNear(spellHit.pct, 50, 0.001)
end)

test("statdata (armor_mitigation): 1104 armor at level 22 -> 1104/(1104+400+1870) = 32.7%, against 75%", function()
    local model = scan()
    local armor = entry(model, "defense", "armor")
    assertNear(armor.value, 32.7, 0.05)
    assertEqual(armor.raw, 1104)
    assertEqual(armor.ref, 75)
    assertNear(armor.pct, 32.72 / 75 * 100, 0.1)
    assertEqual(armor.display, "1104 (32.7%)")
    assertNear(markerAt(armor, 75).at, 100, 0.001)
end)

test("statdata (missing_api_omitted): a stat the client cannot give is left out, never faked", function()
    local apis = fixture()
    apis.GetSpellHitModifier = false
    apis.UnitDefenseSkill = false
    apis.GetUnitSpeed = false
    local model = scan(apis)
    assertEqual(entry(model, "spell", "spellHit"), nil)
    assertEqual(entry(model, "defense", "defense"), nil)
    assertEqual(entry(model, "utility", "runSpeed"), nil)
    assertTrue(entry(model, "spell", "spellDamage") ~= nil, "the rest of the group stays")
    local empty = scan({})
    for _, group in ipairs({ "base", "spell", "defense", "utility" }) do
        assertEqual(type(empty[group]), "table", group)
        assertEqual(#empty[group], 0, group)
    end
end)

test("statdata (resist_ref_at_60): resists scale to 5 x (level + 3) = 315 at 60, with the cap marker", function()
    local model = scan(nil, 60)
    local fire = entry(model, "defense", "fireResist")
    assertEqual(fire.value, 10)
    assertEqual(fire.ref, 315)
    assertEqual(#fire.markers, 1)
    assertEqual(fire.markers[1].value, 315)
    assertNear(fire.markers[1].at, 100, 0.001)
    assertEqual(entry(scan(nil, 22), "defense", "fireResist").ref, 125, "5 x 25 at level 22")
end)

test("statdata: defense scales to 5 x level, and the 440 marker shows only at 60", function()
    local low = entry(scan(nil, 22), "defense", "defense")
    assertEqual(low.value, 110)
    assertEqual(low.ref, 110)
    assertEqual(#low.markers, 0)
    local cap = entry(scan(nil, 60), "defense", "defense")
    assertEqual(cap.ref, 300)
    assertEqual(#cap.markers, 1)
    assertEqual(cap.markers[1].value, 440)
    assertEqual(cap.markers[1].label, NS.L["crit immunity vs bosses"])
end)

test("statdata: speed is yards per second over 7, against 200% with the 100% marker", function()
    local model = scan()
    local run = entry(model, "utility", "runSpeed")
    assertNear(run.value, 100, 0.001)
    assertEqual(run.ref, 200)
    assertNear(run.pct, 50, 0.001)
    assertEqual(run.display, "100%")
    assertNear(markerAt(run, 100).at, 50, 0.001)
    assertNear(entry(model, "utility", "speed").value, 0, 0.001, "standing still")
    assertNear(entry(model, "utility", "swimSpeed").value, 67.4, 0.1)
end)

test("statdata: durability is the lowest equipped slot, with the 20% repair marker", function()
    local model = scan()
    local dur = entry(model, "utility", "durability")
    assertNear(dur.value, 25, 0.001)
    assertEqual(dur.ref, 100)
    assertEqual(markerAt(dur, 20).label, NS.L["repair"])
    local apis = fixture()
    apis.GetInventoryItemDurability = function() return nil end
    assertNear(entry(scan(apis), "utility", "durability").value, 100, 0.001, "nothing breakable worn")
end)

test("statdata: every def declares a known group, an api, a ref and a source record", function()
    local groups = { base = true, spell = true, defense = true, utility = true }
    for i, def in ipairs(NS.STAT_DEFS) do
        assertTrue(type(def.key) == "string", "def " .. i .. " has a key")
        assertTrue(groups[def.group], def.key .. " group " .. tostring(def.group))
        assertTrue(type(def.api) == "string", def.key .. " api")
        assertTrue(def.ref ~= nil, def.key .. " ref")
        assertTrue(type(def.label) == "string", def.key .. " label")
    end
    assertEqual(NS.STATS_FOREVER_META.verified, false)
    assertTrue(type(NS.STATS_FOREVER_META.source) == "string")
end)

test("statdata: Model() and Get(key) answer the last scan", function()
    scan()
    assertEqual(NS.StatData:Get("agility").value, 112)
    assertTrue(NS.StatData:Model().base ~= nil)
    assertEqual(NS.StatData:Get("noSuchStat"), nil)
end)

test("statdata: a burst of stat events sends STATS_UPDATED once, after the 0.2 s throttle", function()
    local restore = install(fixture())
    M.__fireTimers()   -- drain anything another suite left queued
    local target, got = NS.NewBusTarget(), {}
    target:RegisterMessage(NS.MSG.STATS_UPDATED, function(_, model) got[#got + 1] = model end)
    M.__fireEvent("UNIT_STATS", "player")
    M.__fireEvent("UNIT_ATTACK_POWER", "player")
    M.__fireEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
    M.__fireEvent("UNIT_STATS", "target")
    assertEqual(#got, 0, "nothing before the throttle runs")
    M.__fireTimers()
    target:UnregisterAllMessages()
    restore()
    assertEqual(#got, 1, "one send for the burst")
    assertEqual(entry(got[1], "base", "agility").value, 112, "the payload is the stats model")
end)

test("statdata: another unit's event schedules nothing", function()
    local restore = install(fixture())
    M.__fireTimers()
    local target, got = NS.NewBusTarget(), 0
    target:RegisterMessage(NS.MSG.STATS_UPDATED, function() got = got + 1 end)
    M.__fireEvent("UNIT_RESISTANCES", "party1")
    M.__fireTimers()
    target:UnregisterAllMessages()
    restore()
    assertEqual(got, 0)
end)

test("statdata: the speed ticker runs only while a speed display asks for it", function()
    local restore = install(fixture())
    M.__fireTimers()
    local target, got = NS.NewBusTarget(), 0
    target:RegisterMessage(NS.MSG.STATS_UPDATED, function() got = got + 1 end)
    NS.StatData:WatchSpeed(true)
    assertTrue(NS.StatData:IsWatchingSpeed())
    M.__fireTimers()   -- the 0.5 s tick queues a refresh
    M.__fireTimers()   -- the throttle sends it
    assertTrue(got >= 1, "a tick refreshes the stats")
    NS.StatData:WatchSpeed(false)
    assertTrue(not NS.StatData:IsWatchingSpeed())
    M.__fireTimers()
    local after = got
    M.__fireTimers()
    M.__fireTimers()
    target:UnregisterAllMessages()
    restore()
    assertEqual(got, after, "no tick after the watch ends")
end)

-- WoW Forever 1.60.1, measured in game 2026-11-10: UnitStat answered secret numbers inside an AceTimer
-- callback, and groupMax's comparison raised "attempt to compare field 'value' (a secret number value)".
test("stats: a secret read never raises and keeps the stat's last plain value, marked stale", function()
    local Kit = T.kit
    scan()   -- a plain scan first: Strength 48
    local restoreSecret = Kit.installSecretValue()
    local apis = fixture()
    apis.UnitStat = function(_, i) local v = PRIMARIES[i] return Kit.secret(v - 5), Kit.secret(v), 5, 0 end
    apis.GetCritChance = function() return Kit.secret(9) end
    local ok, model = pcall(function() return scan(apis) end)
    restoreSecret()
    assertTrue(ok, "a secret answer must not raise: " .. tostring(model))
    local str = entry(model, "base", "strength") or entry(model, "primary", "strength")
    for _, g in pairs(model) do for _, e in ipairs(g) do if e.key == "strength" then str = e end end end
    assertTrue(str ~= nil, "Strength kept from the last plain scan")
    assertEqual(str.value, 48); assertTrue(str.stale, "marked stale")
    assertTrue(NS.StatData.sawSecret, "the scan notes it met a secret")
    -- the next plain scan reads fresh values again
    local fresh = scan()
    for _, g in pairs(fresh) do for _, e in ipairs(g) do
        if e.key == "strength" then assertEqual(e.stale, nil); assertEqual(e.value, 48) end
    end end
end)

test("stats: leaving combat asks for a rescan (PLAYER_REGEN_ENABLED)", function()
    local found = false
    for _, ev in ipairs(NS.StatData.EVENTS) do if ev == "PLAYER_REGEN_ENABLED" then found = true end end
    assertTrue(found)
end)
