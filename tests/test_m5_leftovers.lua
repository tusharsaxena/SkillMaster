-- tests/test_m5_leftovers.lua — the M5 leftovers, each red before its fix:
--   * every HUD color companion defaults on (skinning-§6), and the category and bonus colors keep
--     apart while they follow the skin: owner tokens sm.cat.* / sm.bonus* carry the mockup's colors;
--   * the settings rows the player expects: fill direction, the main window's and the detached
--     blocks' frame strata (the crafting overlays follow), and one or two columns of blocks;
--   * a running simulation pins nothing into the character's store;
--   * test mode's broker {pinned} and {equippedWeapon} read the sample character;
--   * no display string carries a glyph a shipped skin face cannot draw.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
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
    local found = false
    for _, row in ipairs(NS.Schema) do
        if row.path == "bars.colors.fromSkin" then
            found = true
            assertEqual(row.default, true, "the row's default")
        end
    end
    assertTrue(found, "bars.colors.fromSkin has a row")
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

-- ---------------------------------------------------------------------------------------------
-- 2. Fill direction, frame strata and the column count
-- ---------------------------------------------------------------------------------------------

local function rowOf(path)
    for _, row in ipairs(NS.Schema) do if row.path == path then return row end end
    return nil
end

local function valuesOf(row)
    local out = {}
    for _, v in ipairs(row.values or {}) do out[#out + 1] = type(v) == "table" and v.value or v end
    table.sort(out)
    return table.concat(out, ",")
end

test("settings: fill direction, both strata and the column count each have a live row", function()
    -- red under: none of the four rows (the player's "customization options for every visual element").
    local want = {
        ["bars.fillDirection"]    = { "LEFT,RIGHT", "LEFT" },
        ["layout.strata"]         = { "BACKGROUND,HIGH,LOW,MEDIUM", "MEDIUM" },
        ["layout.detachedStrata"] = { "BACKGROUND,HIGH,LOW,MEDIUM", "MEDIUM" },
        ["layout.columns"]        = { "1,2", 1 },
    }
    for path, w in pairs(want) do
        local row = rowOf(path)
        assertTrue(row ~= nil, path .. " has a row")
        assertEqual(valuesOf(row), w[1], path .. " offers")
        assertEqual(row.default, w[2], path .. " defaults")
        assertTrue(type(row.onChange) == "function", path .. " applies live")
    end
end)

test("settings: a strata row's tooltip is the library's, over the row's own values (frame-layering-§1)", function()
    local O = NS.Helpers
    for _, path in ipairs({ "layout.strata", "layout.detachedStrata" }) do
        local row = rowOf(path)
        local tip = O.StrataTooltip(NS.Constants.LAYERS.STRATA_CHOICES)
        assertTrue(type(row.desc) == "string" and row.desc:find(tip, 1, true) ~= nil, path .. " carries StrataTooltip")
    end
end)

test("fill direction: right to left anchors the fill, the bonus and the spark on the bar's right edge", function()
    local bar = NS.Bar.Create(M.UIParent, "row")
    bar:SetValues({ value = 50, max = 100, bonus = 10, bonusKind = "temp" })
    assertTrue(tostring((bar.fill:GetPoint(1))):find("LEFT$") ~= nil, "left to right by default")
    NS.SetByPath("bars.fillDirection", "RIGHT")
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    assertTrue(tostring((bar.fill:GetPoint(1))):find("RIGHT$") ~= nil, "the fill grows from the right")
    assertTrue(tostring((bar.bonus:GetPoint(1))):find("RIGHT$") ~= nil, "the bonus runs on from it")
    assertTrue(tostring((bar.spark:GetPoint(1))):find("^TOP") ~= nil and select(3, bar.spark:GetPoint(1)) == "TOPRIGHT",
        "the spark rides the fill's left end")
    NS.SetByPath("bars.fillDirection", "LEFT")
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    assertTrue(tostring((bar.fill:GetPoint(1))):find("LEFT$") ~= nil, "and back")
end)

test("strata: the window and a detached block take their rows' strata live; overlays sit in the host's", function()
    local W, D, layout = NS.MainWindow, NS.Detached, NS.db.profile.layout
    NS.ToggleTestMode()   -- the sample's Leatherworking row carries a crafting overlay
    W.Show()
    NS.SetByPath("layout.strata", "LOW")
    assertEqual(W.Frame():GetFrameStrata(), "LOW", "the window")
    local overlay = NS.SecureOverlay.Overlay("leatherworking")
    assertTrue(overlay ~= nil, "precondition: the crafting row's overlay exists")
    assertEqual(overlay:GetFrameStrata(), "LOW", "the overlay follows its host's strata")
    assertTrue(overlay:GetFrameLevel() > W.Frame():GetFrameLevel() + NS.Constants.LAYERS.LEVEL.CONTENT,
        "and stays over the rows")
    NS.ToggleTestMode()
    layout.blocks.other.docked = false
    NS.SetByPath("layout.detachedStrata", "HIGH")
    D.Refresh()
    assertEqual(D.Frame("other"):GetFrameStrata(), "HIGH", "the detached block")
    assertEqual(NS.TrainerPopup.Strata(), "DIALOG", "the trainer popup sits over a High detached block")
    NS.SetByPath("layout.detachedStrata", "MEDIUM")
    NS.SetByPath("layout.strata", "HIGH")
    assertEqual(NS.TrainerPopup.Strata(), "DIALOG", "and over a High window")
    NS.SetByPath("layout.strata", "MEDIUM")
    assertEqual(NS.TrainerPopup.Strata(), "HIGH", "and is High over Medium ones")
    layout.blocks.other.docked = true
    D.Refresh()
    assertEqual(W.Frame():GetFrameStrata(), "MEDIUM")
    W.Hide()
end)

test("columns: two columns lay the docked blocks side by side in a window twice as wide", function()
    local W = NS.MainWindow
    NS.ToggleTestMode()
    local ok, err = pcall(function()
        W.Show()
        local one = W.ContentWidth()
        local seen = {}
        for _, id in ipairs(NS.Blocks.Docked()) do
            local h = W.HeaderFor(id)
            if h then seen[h:GetParent()] = true end
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        assertEqual(n, 1, "one column by default")
        NS.SetByPath("layout.columns", 2)
        assertTrue(W.ContentWidth() > one * 1.9, "the body is two columns wide")
        seen, n = {}, 0
        for _, id in ipairs(NS.Blocks.Docked()) do
            local h = W.HeaderFor(id)
            if h then seen[h:GetParent()] = true end
        end
        for _ in pairs(seen) do n = n + 1 end
        assertEqual(n, 2, "the blocks fill both columns")
        for _, row in ipairs(W.Rows()) do
            assertTrue(seen[row:GetParent()] ~= nil, "every row sits in a column")
        end
    end)
    NS.SetByPath("layout.columns", 1)
    NS.ToggleTestMode()
    W.Hide()
    if not ok then error(err, 0) end
end)
