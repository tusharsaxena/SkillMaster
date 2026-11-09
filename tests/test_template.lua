-- tests/test_template.lua — the broker feed text templates (plan Task 4.1, design §6.7):
-- every token, and an unknown token rendering empty.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual

local function skill(key, name, category, rank, max, modifier, learned)
    return { key = key, name = name, category = category, rank = rank, max = max,
             modifier = modifier or 0, tempPoints = 0, learned = learned ~= false }
end

--- The mockup's Dwarf Hunter, trimmed: Leatherworking, Skinning, Fishing + a lure, Guns + racial.
local function fixtureModel()
    local byKey = {
        leatherworking = skill("leatherworking", "Leatherworking", "primary", 146, 150),
        skinning       = skill("skinning", "Skinning", "primary", 122, 150),
        fishing        = skill("fishing", "Fishing", "secondary", 107, 150, 25),
        guns           = skill("guns", "Guns", "weapon", 105, 110, 5),
        bows           = skill("bows", "Bows", "weapon", 81, 110),
        swords         = skill("swords", "Swords", "weapon", 0, 0, 0, false),
    }
    return { byKey = byKey, order = {
        primary = { "leatherworking", "skinning" }, secondary = { "fishing" },
        weapon = { "guns", "bows", "swords" }, other = {},
    } }
end

local function stats()
    return {
        meleeCrit  = { key = "meleeCrit", value = 5.2, display = "5.2%" },
        rangedCrit = { key = "rangedCrit", value = 9.1, display = "9.1%" },
        speed      = { key = "speed", value = 100, display = "100%" },
    }
end

local function ctx(extra)
    local c = { skills = fixtureModel(), stat = stats(), gains = 14, level = 22,
                last = { key = "bows", new = 81 }, mainHand = "guns" }
    for k, v in pairs(extra or {}) do c[k] = v end
    return c
end

test("test_template_tokens: every token of design §6.7 renders from the context", function()
    local R = NS.Template.Render
    local c = ctx({ pinned = "fishing" })
    assertEqual(R("{pinned} · +{gains}", c), "Fishing 107+25/150 · +14")
    assertEqual(R("{last}", c), "Bows 81")
    assertEqual(R("{lowestProf}", c), "Skinning 122/150", "the lowest primary by rank / max")
    assertEqual(R("{equippedWeapon}", c), "Guns 105+5/110")
    assertEqual(R("{skill:leatherworking}", c), "Leatherworking 146/150")
    assertEqual(R("{skill:swords}", c), "Swords", "an unlearned skill renders its name")
    assertEqual(R("{stat:rangedCrit} crit · {stat:speed}", c), "9.1% crit · 100%")
    assertEqual(R("{stat:crit}", c), "9.1%", "crit is the highest crit chance")
    assertEqual(R("Lv {level}", c), "Lv 22")
end)

test("test_template_tokens: no pin falls back to the last skill-up, then to the lowest profession", function()
    local R = NS.Template.Render
    assertEqual(R("{pinned}", ctx()), "Bows 81/110")
    assertEqual(R("{pinned}", ctx({ last = false })), "Skinning 122/150")
end)

test("test_template_unknown_token_empty: unknown tokens and missing data render empty", function()
    local R = NS.Template.Render
    local c = ctx()
    assertEqual(R("a{nope}b", c), "ab")
    assertEqual(R("a{skill:notASkill}b", c), "ab")
    assertEqual(R("a{stat:notAStat}b", c), "ab")
    assertEqual(R("a{gains:extra}b", c), "ab", "an argument on a token that takes none")
    assertEqual(R("a{foo bar}b", c), "ab")
    assertEqual(R("{last} {equippedWeapon}", {}), " ", "an empty context renders every token empty")
    assertEqual(R("plain { text }", c), "plain { text }", "braces that are not a token stay")
    assertEqual(R(nil, c), "")
end)
