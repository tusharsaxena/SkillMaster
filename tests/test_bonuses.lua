-- tests/test_bonuses.lua — Bonuses: a skill's modifier broken down into racial, item, enchant and
-- buff sources, the remainder as "Other" (design §5.2, plan Task 2.2).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- NS.SkillData (T2.1) is stubbed: the skill model entry shape is
-- { key, name, category, kind, rank, max, tempPoints, modifier, learned } (T2.1); Enable is a no-op
-- so NS.RegisterRuntime can run against the stub.
local function entry(key, name, rank, max, modifier)
    return { key = key, name = name, category = "weapon", rank = rank, max = max, tempPoints = 0,
             modifier = modifier, learned = true }
end

local function tooltipData(lines)
    if not lines then return nil end
    local out = { lines = {} }
    for i, text in ipairs(lines) do out.lines[i] = { leftText = text } end
    return out
end

local SWAPPED = { "UnitRace", "C_Item", "C_TooltipInfo", "C_UnitAuras", "GetWeaponEnchantInfo" }

--- Install a world (race, skills, enchant, equipped tooltips, buffs, clock), run fn, put it all back.
local function withWorld(w, fn)
    local saved, savedSkill, savedNow = {}, NS.SkillData, M.__now
    for _, k in ipairs(SWAPPED) do saved[k] = M[k] end
    NS.SkillData = { Get = function(_, key) return w.skills[key] end, Enable = function() end }
    M.__now = w.now or 1000
    M.UnitRace = function() return w.race and w.race[1], w.race and w.race[2] end
    M.C_Item = { GetWeaponEnchantInfo = function() return unpack(w.enchant or { false }) end }
    M.GetWeaponEnchantInfo = nil
    M.C_TooltipInfo = {
        GetInventoryItem = function(_, slot) return tooltipData(w.items and w.items[slot]) end,
        GetUnitBuffByAuraInstanceID = function(_, id) return tooltipData(w.buffLines and w.buffLines[id]) end,
    }
    M.C_UnitAuras = { GetBuffDataByIndex = function(_, i) return w.buffs and w.buffs[i] end }
    NS.Bonuses.Invalidate()
    local ok, err = pcall(fn)
    for _, k in ipairs(SWAPPED) do M[k] = saved[k] end
    NS.SkillData, M.__now = savedSkill, savedNow
    NS.Bonuses.Invalidate()
    if not ok then error(err, 0) end
end

local function sum(b)
    local n = 0
    for _, s in ipairs(b.sources) do n = n + s.amount end
    return n
end

test("bonuses: lure on the pole is one temp enchant source with its expiry", function()
    withWorld({
        race = { "Dwarf", "Dwarf" }, now = 1000,
        skills = { fishing = entry("fishing", "Fishing", 107, 150, 25) },
        enchant = { true, 252000, 0, false, 0, 0 },
        items = { [16] = { "Strong Fishing Pole", "Fishing Lure (+25 Fishing Skill) (4 min)" } },
    }, function()
        local b = NS.Bonuses:Breakdown("fishing")
        assertEqual(b.total, 25)
        assertEqual(#b.sources, 1, "one source, no Other")
        local s = b.sources[1]
        assertEqual(s.amount, 25)
        assertEqual(s.kind, "temp")
        assertEqual(s.source, "enchant")
        assertEqual(s.expires, 1252, "GetTime() + 252 s")
        assertEqual(s.label, "Fishing Lure")
    end)
end)

test("bonuses: a Dwarf's Guns +5 is one permanent racial source", function()
    withWorld({
        race = { "Dwarf", "Dwarf" },
        skills = { guns = entry("guns", "Guns", 105, 110, 5) },
    }, function()
        local b = NS.Bonuses:Breakdown("guns")
        assertEqual(b.total, 5)
        assertEqual(#b.sources, 1)
        local s = b.sources[1]
        assertEqual(s.amount, 5)
        assertEqual(s.kind, "perm")
        assertEqual(s.source, "racial")
        assertTrue(s.expires == nil, "a racial never expires")
        assertTrue(s.label:find("Dwarf", 1, true) ~= nil, s.label)
    end)
end)

test("bonuses: modifier 12 with 7 attributed leaves one Other 5", function()
    withWorld({
        race = { "Human", "Human" },
        skills = { swords = entry("swords", "Swords", 200, 300, 12) },
        items = { [10] = { "Gauntlets of the Blade", "Equip: Increased Swords +2." } },
    }, function()
        local b = NS.Bonuses:Breakdown("swords")
        assertEqual(b.total, 12)
        assertEqual(#b.sources, 3, "racial, item, other")
        assertEqual(b.sources[1].source, "racial")
        assertEqual(b.sources[1].amount, 5)
        assertEqual(b.sources[2].source, "item")
        assertEqual(b.sources[2].amount, 2)
        assertEqual(b.sources[2].kind, "perm")
        assertEqual(b.sources[2].label, "Gauntlets of the Blade")
        local other = b.sources[3]
        assertEqual(other.source, "other")
        assertEqual(other.amount, 5)
        assertEqual(other.label, "Other")
        assertEqual(sum(b), b.total, "the sources add up to the modifier")
    end)
end)

test("bonuses: no modifier, no sources", function()
    withWorld({
        race = { "Dwarf", "Dwarf" },
        skills = { bows = entry("bows", "Bows", 80, 110, 0), guns = entry("guns", "Guns", 1, 110, 0) },
        items = { [1] = { "Hat", "+10 Stamina" } },
    }, function()
        for _, key in ipairs({ "bows", "guns" }) do
            local b = NS.Bonuses:Breakdown(key)
            assertEqual(b.total, 0, key)
            assertEqual(#b.sources, 0, key .. ": a racial the modifier does not carry is not shown")
        end
    end)
end)

test("bonuses: an unknown or unlearned skill answers an empty breakdown", function()
    local unlearned = entry("polearms", "Polearms", 0, 0, 5)
    unlearned.learned = false
    withWorld({ race = { "Orc", "Orc" }, skills = { polearms = unlearned } }, function()
        assertEqual(NS.Bonuses:Breakdown("nope").total, 0)
        assertEqual(#NS.Bonuses:Breakdown("nope").sources, 0)
        assertEqual(#NS.Bonuses:Breakdown("polearms").sources, 0)
    end)
end)

test("bonuses: the '+N <Skill>' item pattern, case-insensitive, other stats ignored", function()
    withWorld({
        race = { "Gnome", "Gnome" },
        skills = { fishing = entry("fishing", "Fishing", 120, 150, 5) },
        items = {
            [1] = { "Lucky Fishing Hat", "+5 fishing", "+10 Stamina" },
            [16] = { "Strong Fishing Pole" },
        },
    }, function()
        local b = NS.Bonuses:Breakdown("fishing")
        assertEqual(#b.sources, 1)
        assertEqual(b.sources[1].source, "item")
        assertEqual(b.sources[1].amount, 5)
        assertEqual(b.sources[1].label, "Lucky Fishing Hat")
    end)
end)

test("bonuses: a skill buff is a temp source with its aura's expiry", function()
    withWorld({
        race = { "Gnome", "Gnome" }, now = 50,
        skills = { fishing = entry("fishing", "Fishing", 120, 150, 10) },
        buffs = { { name = "Savory Deviate Delight", auraInstanceID = 7, expirationTime = 0 },
                  { name = "Fisherman's Focus", auraInstanceID = 9, expirationTime = 650 } },
        buffLines = { [7] = { "Savory Deviate Delight" }, [9] = { "Fisherman's Focus", "Increased Fishing +10." } },
    }, function()
        local b = NS.Bonuses:Breakdown("fishing")
        assertEqual(#b.sources, 1)
        local s = b.sources[1]
        assertEqual(s.source, "buff")
        assertEqual(s.kind, "temp")
        assertEqual(s.amount, 10)
        assertEqual(s.expires, 650)
        assertEqual(s.label, "Fisherman's Focus")
    end)
end)

test("bonuses: more attributed than the modifier shows a negative Other, never a silent mismatch", function()
    withWorld({
        race = { "Orc", "Orc" },
        skills = { axes = entry("axes", "Axes", 200, 300, 3) },
    }, function()
        local b = NS.Bonuses:Breakdown("axes")
        assertEqual(b.total, 3)
        assertEqual(b.sources[#b.sources].source, "other")
        assertEqual(b.sources[#b.sources].amount, -2)
        assertEqual(sum(b), 3)
    end)
end)

test("bonuses: the 1.12 globals and a scanning tooltip are the fallback readers", function()
    withWorld({
        race = { "Dwarf", "Dwarf" }, now = 10,
        skills = { fishing = entry("fishing", "Fishing", 107, 150, 25) },
    }, function()
        M.C_Item, M.C_TooltipInfo, M.C_UnitAuras = nil, nil, nil
        M.GetWeaponEnchantInfo = function() return 1, 60000, 0 end
        local lines = { "Strong Fishing Pole", "Fishing Lure (+25 Fishing Skill) (1 min)" }
        local shown = {}
        local tip = {
            GetName = function() return "SkmTestScanTip" end,
            SetOwner = function() end, ClearLines = function() for i = #shown, 1, -1 do shown[i] = nil end end,
            SetInventoryItem = function(_, _, slot)
                if slot == 16 then for i, l in ipairs(lines) do shown[i] = l end end
            end,
            NumLines = function() return #shown end,
        }
        for i = 1, 2 do
            _G["SkmTestScanTipTextLeft" .. i] = { GetText = function() return shown[i] end }
        end
        local realTip = NS.Bonuses.__scanTip
        NS.Bonuses.__scanTip = tip
        NS.Bonuses.Invalidate()
        local ok, err = pcall(function()
            local b = NS.Bonuses:Breakdown("fishing")
            assertEqual(#b.sources, 1)
            assertEqual(b.sources[1].source, "enchant")
            assertEqual(b.sources[1].expires, 70)
        end)
        NS.Bonuses.__scanTip = realTip
        for i = 1, 2 do _G["SkmTestScanTipTextLeft" .. i] = nil end
        if not ok then error(err, 0) end
    end)
end)

test("bonuses: inventory change publishes BONUSES_UPDATED; the 1 s ticker runs only while a temp bonus lives", function()
    withWorld({
        race = { "Dwarf", "Dwarf" }, now = 1000,
        skills = { fishing = entry("fishing", "Fishing", 107, 150, 25) },
        enchant = { false },
        items = { [16] = { "Strong Fishing Pole", "Fishing Lure (+25 Fishing Skill) (1 min)" } },
    }, function()
        local target = NS.NewBusTarget()
        local got = 0
        target:RegisterMessage(NS.MSG.BONUSES_UPDATED, function() got = got + 1 end)
        for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
        NS.RegisterRuntime()
        local events = {}
        for _, r in ipairs(M.__registrations()) do events[r.event] = true end
        assertTrue(events.UNIT_INVENTORY_CHANGED and events.UNIT_AURA, "both events registered")
        M.__fireTimers()   -- the start-up refresh
        assertEqual(got, 1, "the start-up refresh publishes")
        assertTrue(NS.Bonuses.__ticker == nil, "no temp bonus: no ticker")
        got = 0
        M.__fire("UNIT_INVENTORY_CHANGED", "target")
        M.__fireTimers()
        assertEqual(got, 0, "another unit's inventory is not ours")
        M.C_Item.GetWeaponEnchantInfo = function() return true, 2000 end   -- the lure goes on
        M.__fire("UNIT_INVENTORY_CHANGED", "player")
        M.__fire("UNIT_AURA", "player")
        M.__fireTimers()
        assertEqual(got, 1, "two events inside the debounce publish once")
        assertTrue(NS.Bonuses.__ticker ~= nil, "a lure is up: the ticker runs")
        M.__fireTimers()
        assertEqual(got, 2, "a tick publishes")
        -- the lure runs out: the next tick re-reads, finds no temp bonus and stops the ticker
        M.__now = 1003
        NS.Bonuses.Invalidate()
        M.C_Item.GetWeaponEnchantInfo = function() return false end
        M.__fireTimers()
        assertTrue(NS.Bonuses.__ticker == nil, "no temp bonus: the ticker stops")
        assertEqual(#NS.Bonuses:Breakdown("fishing").sources, 1, "the 25 is now Other")
        assertEqual(NS.Bonuses:Breakdown("fishing").sources[1].source, "other")
        target:UnregisterAllMessages()
        NS.addon:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        NS.addon:UnregisterEvent("UNIT_AURA")
        NS.addon:CancelAllTimers()
        NS.Bonuses.__ticker = nil
    end)
end)

test("racials: the table is Forever data, unverified, with a source, +5 per racial skill", function()
    local R = NS.Racials_Forever
    assertTrue(type(R) == "table", "NS.Racials_Forever")
    assertEqual(R.verified, false)
    assertTrue(type(R.source) == "string" and #R.source > 0, "records its source")
    assertEqual(R.byRace.Human.swords, 5)
    assertEqual(R.byRace.Human.maces, 5)
    assertEqual(R.byRace.Dwarf.guns, 5)
    assertEqual(R.byRace.Orc.axes, 5)
    assertEqual(R.byRace.Troll.bows, 5)
    assertEqual(R.byRace.Troll.thrown, 5)
end)

test("racials: every racial skill key is a catalog key", function()
    if type(NS.SkillCatalog) ~= "table" then T.skip("NS.SkillCatalog (T2.1) is not on this branch yet") end
    for race, skills in pairs(NS.Racials_Forever.byRace) do
        for key in pairs(skills) do
            assertTrue(NS.SkillCatalog[key] ~= nil, race .. "." .. key .. " is not in NS.SkillCatalog")
        end
    end
end)

test("bonuses: UNIT_AURA re-reads the buffs only, never the equipped tooltips", function()
    withWorld({
        race = { "Dwarf", "Dwarf" }, now = 1000,
        skills = { fishing = entry("fishing", "Fishing", 107, 150, 10) },
        items = { [16] = { "Strong Fishing Pole" } },
    }, function()
        local itemReads, buffReads = 0, 0
        local tip = M.C_TooltipInfo
        local getItem, getBuff = tip.GetInventoryItem, M.C_UnitAuras.GetBuffDataByIndex
        tip.GetInventoryItem = function(...) itemReads = itemReads + 1; return getItem(...) end
        M.C_UnitAuras.GetBuffDataByIndex = function(...) buffReads = buffReads + 1; return getBuff(...) end
        for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
        local ok, err = pcall(function()
            NS.RegisterRuntime()
            M.__fireTimers()
            assertEqual(itemReads, NS.Bonuses.SLOTS, "the start-up refresh reads every slot")
            itemReads, buffReads = 0, 0
            M.__fire("UNIT_AURA", "player")
            M.__fireTimers()
            assertEqual(itemReads, 0, "an aura change leaves the item tooltips cached")
            assertTrue(buffReads > 0, "an aura change re-reads the buffs")
            itemReads, buffReads = 0, 0
            M.__fire("UNIT_INVENTORY_CHANGED", "player")
            M.__fireTimers()
            assertEqual(itemReads, NS.Bonuses.SLOTS, "an inventory change re-reads every slot")
        end)
        NS.addon:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        NS.addon:UnregisterEvent("UNIT_AURA")
        NS.addon:CancelAllTimers()
        NS.Bonuses.__ticker, NS.Bonuses.__pending = nil, nil
        if not ok then error(err, 0) end
    end)
end)

test("bonuses: a temp '+N' line that names no skill starts no ticker", function()
    withWorld({
        race = { "Human", "Human" }, now = 1000,
        skills = {},
        buffs = { { name = "Some Elixir", auraInstanceID = 3, expirationTime = 0 } },
        buffLines = { [3] = { "Some Elixir", "+15 Stamina" } },
    }, function()
        for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
        NS.Bonuses.Refresh()
        local ticker = NS.Bonuses.__ticker
        NS.addon:CancelAllTimers()
        NS.Bonuses.__ticker = nil
        assertTrue(ticker == nil, "no skill bonus is live: no 1 s ticker")
    end)
end)

-- WoW Forever 1.60.1, measured in game 2026-11-10: GetBuffDataByIndex raised "Auras cannot be accessed
-- when secret while tainted by 'SkillMaster'" from the ticker.
test("bonuses: a blocked aura read never raises and keeps the last buffs read in full", function()
    local w = {
        race = { "Gnome", "Gnome" }, now = 50,
        skills = { fishing = entry("fishing", "Fishing", 120, 150, 10) },
        buffs = { { name = "Fisherman's Focus", auraInstanceID = 9, expirationTime = 650 } },
        buffLines = { [9] = { "Fisherman's Focus", "Increased Fishing +10." } },
    }
    withWorld(w, function()
        assertEqual(#NS.Bonuses:Breakdown("fishing").sources, 1, "plain read first")
        M.C_UnitAuras = { GetBuffDataByIndex = function()
            error("GetBuffDataByIndex(): Auras cannot be accessed when secret while tainted by 'SkillMaster'")
        end }
        NS.Bonuses.Invalidate("buffs")
        local ok, b = pcall(NS.Bonuses.Breakdown, NS.Bonuses, "fishing")
        assertTrue(ok, "must not raise: " .. tostring(b))
        assertEqual(b.sources[1].source, "buff", "the last full buff list stands in")
        assertTrue(NS.Bonuses.buffsBlocked, "notes the read was blocked")
        local ok2, live = pcall(NS.Bonuses.HasLiveTemp)
        assertTrue(ok2, tostring(live))
    end)
end)

test("bonuses: an aura with a secret field is treated as a blocked read", function()
    local Kit = T.kit
    local restore = Kit.installSecretValue()
    local ok, err = pcall(withWorld, {
        race = { "Gnome", "Gnome" }, now = 50,
        skills = { fishing = entry("fishing", "Fishing", 120, 150, 10) },
        buffs = { { name = "Fisherman's Focus", auraInstanceID = 9, expirationTime = Kit.secret(650) } },
        buffLines = { [9] = { "Fisherman's Focus", "Increased Fishing +10." } },
    }, function()
        local b = NS.Bonuses:Breakdown("fishing")
        assertTrue(NS.Bonuses.buffsBlocked)
        for _, s in ipairs(b.sources) do assertTrue(s.source ~= "buff" or s.expires ~= nil) end
    end)
    restore()
    assertTrue(ok, tostring(err))
end)
