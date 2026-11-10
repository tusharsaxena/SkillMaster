-- tests/test_m5_leftovers.lua — the M5 leftovers, each red before its fix:
--   * every HUD color companion defaults on (skinning-§6), and the category and bonus colors keep
--     apart while they follow the skin: owner tokens sm.cat.* / sm.bonus* carry the mockup's colors;
--   * the settings rows the player expects: fill direction, the main window's and the detached
--     blocks' frame strata (the crafting overlays follow), and one or two columns of blocks;
--   * a running simulation pins nothing into the character's store;
--   * test mode's broker {pinned} and {equippedWeapon} read the sample character;
--   * no display string carries a glyph a shipped skin face cannot draw.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function near(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for i = 1, 3 do if math.abs((a[i] or 0) - (b[i] or 0)) > 0.002 then return false end end
    return true
end

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

-- ---------------------------------------------------------------------------------------------
-- 1. HUD colors follow the skin by default, and the categories keep their own colors
-- ---------------------------------------------------------------------------------------------

test("skin colors: every HUD color companion defaults on, in the defaults and on its row", function()
    -- red under: bars.colors.fromSkin defaulting false (skinning-§6, anti-patterns #110).
    local bars = NS.defaults.profile.bars
    assertEqual(bars.colors.fromSkin, true, "bars.colors.fromSkin")
    for k, v in pairs(bars) do
        if type(k) == "string" and k:find("FromSkin$") then assertEqual(v, true, "bars." .. k) end
    end
    local row = NS.SchemaRuntime and NS.SchemaRuntime.Row and NS.SchemaRuntime.Row("bars.colors.fromSkin")
    if row then assertEqual(row.default, true, "the row's default") end
end)

test("skin colors: the category and bonus owner tokens carry the mockup's colors", function()
    -- red under: no sm.cat.* tokens, and bonus tokens following sem.warn / sem.good.
    local want = {
        ["sm.cat.primary"] = "5b9be0", ["sm.cat.secondary"] = "5fb36d", ["sm.cat.weapon"] = "d9913f",
        ["sm.cat.other"] = "a08ce0", ["sm.bonusTemp"] = "7fd8c4", ["sm.bonusPerm"] = "8db8ff",
    }
    for token, h in pairs(want) do
        local def = NS.SKIN_OWNER_TOKENS[token]
        assertTrue(def ~= nil, token .. " is an owner token")
        assertTrue(near(def.default, hex(h)), token .. " defaults to #" .. h)
        assertTrue(near(NS.Bar.Color(token), hex(h)), token .. " draws #" .. h .. " under the default skin")
    end
end)

test("skin colors: following the skin, each category fills in its own token, not one shared fill", function()
    -- red under: FillColor answering sm.barFill for every category while colors.fromSkin is on.
    local bars = NS.db.profile.bars
    local mode, follow = bars.colorMode, bars.colors.fromSkin
    bars.colorMode, bars.colors.fromSkin = "category", true
    local seen = {}
    for _, cat in ipairs({ "primary", "secondary", "weapon", "other" }) do
        local c = NS.Rows.FillColor({ key = "x", rank = 1, max = 10, category = cat })
        assertTrue(near(c, NS.Bar.Color("sm.cat." .. cat)), cat .. " fills in sm.cat." .. cat)
        local sig = ("%.3f %.3f %.3f"):format(c[1], c[2], c[3])
        assertTrue(not seen[sig], cat .. " is told apart from the others")
        seen[sig] = true
    end
    assertTrue(near(NS.Rows.FillColor({ key = "crit", pct = 10 }, true), NS.Bar.Color("sm.cat.stats")), "stats")
    bars.colors.fromSkin = false
    bars.colors.weapon = { 1, 0, 0, 1 }
    assertTrue(near(NS.Rows.FillColor({ key = "x", rank = 1, max = 10, category = "weapon" }), { 1, 0, 0 }),
        "off, the player's pick draws")
    bars.colors.weapon = NS.defaults.profile.bars.colors.weapon
    bars.colorMode, bars.colors.fromSkin = mode, follow
end)
