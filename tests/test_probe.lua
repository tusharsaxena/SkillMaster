-- tests/test_probe.lua — `/sm probe`: the Forever API report the owner runs once in game
-- (design §5.4, plan Task 1.2).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local APIS = {
    "GetUnitSpeed", "GetSpellBonusDamage", "GetSpellCritChance", "GetHitModifier",
    "GetSpellHitModifier", "GetCombatRating", "GetWeaponEnchantInfo", "GetCritChance",
    "GetRangedCritChance", "GetDodgeChance", "GetParryChance", "GetBlockChance", "UnitResistance",
    "C_Map.SetUserWaypoint", "C_Map.GetBestMapForUnit", "CastSpellByName", 'IsAddOnLoaded("TomTom")',
}

-- A 1.12-shaped skill list: a header, two lines under it, a collapsed header hiding one line.
local LINES = {
    { "Professions", true, true },
    { "Leatherworking", nil, nil, 146, 0, 0, 150 },
    { "Skinning", nil, nil, 122, 0, 5, 150 },
    { "Weapon Skills", true, false },
}
local HIDDEN = { "Bows", nil, nil, 80, 0, 0, 110 }

local function installSkills()
    local expanded = false
    M.GetNumSkillLines = function() return expanded and 5 or 4 end
    M.GetSkillLineInfo = function(i)
        if i == 4 then return "Weapon Skills", true, expanded end
        if i == 5 and expanded then return unpack(HIDDEN, 1, 7) end
        local l = LINES[i]
        if l then return unpack(l, 1, 7) end
    end
    M.ExpandSkillHeader = function(i) if i == 4 then expanded = true end end
    M.CollapseSkillHeader = function(i) if i == 4 then expanded = false end end
    M.GetWeaponEnchantInfo = function() return true, 252000, 0, 0, false end
    return function() return expanded end
end

test("probe: Run() answers the report's six keys", function()
    installSkills()
    local r = NS.Probe.Run()
    for _, key in ipairs({ "client", "build", "skillLines", "headers", "apis", "enchant" }) do
        assertTrue(r[key] ~= nil, "missing key " .. key)
    end
end)

test("probe: skillLines holds the raw returns of every line, the collapsed ones included", function()
    local isExpanded = installSkills()
    local r = NS.Probe.Run()
    assertEqual(#r.skillLines, 5, "every line, with the collapsed header's child")
    local names = {}
    for i, line in ipairs(r.skillLines) do names[i] = line[1] end
    assertTrue(table.concat(names, ","):find("Bows", 1, true) ~= nil, table.concat(names, ","))
    local lw = r.skillLines[2]
    assertEqual(lw[1], "Leatherworking")
    assertEqual(lw[4], 146)
    assertEqual(lw[7], 150)
    assertTrue(not isExpanded(), "the player's collapsed header is collapsed again")
end)

test("probe: headers lists the localized header names", function()
    installSkills()
    local r = NS.Probe.Run()
    assertEqual(table.concat(r.headers, ","), "Professions,Weapon Skills")
end)

test("probe: apis maps every probed name to a boolean", function()
    installSkills()
    M.GetUnitSpeed = function() return 7 end
    M.GetCombatRating = nil
    local r = NS.Probe.Run()
    for _, name in ipairs(APIS) do
        assertEqual(type(r.apis[name]), "boolean", name)
    end
    assertTrue(r.apis.GetUnitSpeed, "a present API reads true")
    assertTrue(r.apis.GetCombatRating == false, "an absent API reads false")
end)

test("probe: enchant carries the weapon enchant returns (a lure's time left)", function()
    installSkills()
    local r = NS.Probe.Run()
    assertEqual(r.enchant[1], true)
    assertEqual(r.enchant[2], 252000)
end)

test("probe: /sm probe shows the report as JSON in the copy window", function()
    installSkills()
    local shown
    local realCopy = NS.Probe.__copy
    NS.Probe.__copy = { Show = function(_, text) shown = text end }
    NS.Slash:OnSlash("probe")
    NS.Probe.__copy = realCopy
    assertTrue(type(shown) == "string" and shown:sub(1, 1) == "{", "JSON object text: " .. tostring(shown))
    assertTrue(shown:find('"skillLines"', 1, true) ~= nil, shown)
end)

-- The kit's generated Forever API set (Ketho/BlizzardInterfaceResources, branch forever) carries the
-- skill list as C_SkillInfo.* and the weapon enchant as C_Item.GetWeaponEnchantInfo, with no bare
-- globals. The probe prefers those, records which it read, and keeps a table return whole.
test("probe: C_SkillInfo and C_Item are read first, a table-shaped line kept whole", function()
    installSkills()
    local realSkill, realItem = M.C_SkillInfo, M.C_Item
    local expanded = false
    M.C_SkillInfo = {
        GetNumSkillLines = function() return expanded and 2 or 1 end,
        GetSkillLineInfo = function(i)
            if i == 1 then return { skillName = "Weapon Skills", isHeader = true, isExpanded = expanded } end
            if i == 2 and expanded then return { skillName = "Bows", skillRank = 80, skillMaxRank = 110 } end
        end,
        ExpandSkillHeader = function() expanded = true end,
        CollapseSkillHeader = function() expanded = false end,
    }
    M.C_Item = { GetWeaponEnchantInfo = function() return true, 9000 end }
    local r = NS.Probe.Run()
    M.C_SkillInfo, M.C_Item = realSkill, realItem
    assertEqual(r.skillSource, "C_SkillInfo")
    assertEqual(#r.skillLines, 2, "the collapsed header's child was read")
    assertEqual(r.skillLines[2][1].skillName, "Bows", "a table return is kept whole")
    assertEqual(table.concat(r.headers, ","), "Weapon Skills")
    assertTrue(not expanded, "collapsed again")
    assertEqual(r.enchant[2], 9000, "C_Item.GetWeaponEnchantInfo is read first")
    assertTrue(r.apis["C_SkillInfo.GetSkillLineInfo"] == true, "reported present")
end)

-- WoW Forever 1.60.1, measured in game 2026-11-10: `local enchants = C_Item.GetWeaponEnchantInfo(weaponSlot)`
-- errors when called without a slot ("bad argument #1 ... Usage: ..."), and answers one table.
local function foreverEnchant(record)
    return function(slot)
        if slot == nil then
            error("bad argument #1 to '?' (Usage: local enchants = C_Item.GetWeaponEnchantInfo(weaponSlot))")
        end
        return record
    end
end

test("probe: a slot-taking C_Item.GetWeaponEnchantInfo does not error, and each try is recorded", function()
    installSkills()
    local realItem, realGlobal = M.C_Item, M.GetWeaponEnchantInfo
    M.GetWeaponEnchantInfo = nil
    M.C_Item = { GetWeaponEnchantInfo = foreverEnchant({ { enchantID = 263, expiration = 252000 } }) }
    local ok, r = pcall(NS.Probe.Run)
    M.C_Item, M.GetWeaponEnchantInfo = realItem, realGlobal
    assertTrue(ok, "Run() must not raise: " .. tostring(r))
    assertTrue(#r.enchantTries >= 1, "every slot argument tried is recorded")
    assertTrue(r.enchantTries[1].ok, "the first candidate slot is accepted")
    assertEqual(r.enchant[1][1].enchantID, 263, "the raw table return is kept whole")
end)

test("compat: WeaponEnchantInfo passes a slot and normalizes Forever's table to the 1.12 shape", function()
    local realItem, realGlobal = M.C_Item, M.GetWeaponEnchantInfo
    M.GetWeaponEnchantInfo = nil
    NS.Compat.__enchantSlot = nil
    M.C_Item = { GetWeaponEnchantInfo = foreverEnchant({ { enchantID = 263, expiration = 252000, charges = 0 } }) }
    local ok, has, ms, charges, id = pcall(NS.Compat.WeaponEnchantInfo)
    assertTrue(ok, "must not raise: " .. tostring(has))
    assertEqual(has, true); assertEqual(ms, 252000); assertEqual(charges, 0); assertEqual(id, 263)
    -- seconds rather than ms, and a keyed record rather than an array
    M.C_Item = { GetWeaponEnchantInfo = foreverEnchant({ expirationTime = 600 }) }
    has, ms = NS.Compat.WeaponEnchantInfo()
    assertEqual(has, true); assertEqual(ms, 600000, "a seconds value is read as seconds")
    -- no enchant: an empty list
    M.C_Item = { GetWeaponEnchantInfo = foreverEnchant({}) }
    assertEqual(NS.Compat.WeaponEnchantInfo(), false, "an empty answer is no enchant")
    -- every slot errors: nil, never a raise
    M.C_Item = { GetWeaponEnchantInfo = function() error("nope") end }
    NS.Compat.__enchantSlot = nil
    local ok2, v = pcall(NS.Compat.WeaponEnchantInfo)
    assertTrue(ok2, "never raises"); assertEqual(v, nil)
    M.C_Item, M.GetWeaponEnchantInfo = realItem, realGlobal
    NS.Compat.__enchantSlot = nil
end)
