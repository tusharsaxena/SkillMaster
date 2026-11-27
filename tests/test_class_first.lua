-- tests/test_class_first.lua — FB-SM-02 (the owner's feedback batch, 2026-11-24, finding P;
-- WowAddonStandards v2.119.0, options-ui-§17, *The precedence is class, then the skin's color, then
-- the swatch*). Every color with a "Use class color" companion draws the class color while that
-- companion is on, whatever "Use the skin's color" says; with the class off the skin's color wins
-- while its companion is on, else the swatch. Every site here is player-scoped, so the class always
-- resolves (the stand-in never applies).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertTrue, assertNear = T.test, T.assertTrue, T.assertNear

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()
end

-- The suite's client answers no RAID_CLASS_COLORS, so each case plants one for the player's class
-- (a hunter's green, the owner's example) and takes it away after.
local Core = M.LibStub("LibKa0s-Core-1.0")
local GREEN = { r = 0.67, g = 0.83, b = 0.45 }
local function planted(fn)
    return function()
        local token = select(2, M.UnitClass("player"))
        local was, wasG = M.RAID_CLASS_COLORS, rawget(_G, "RAID_CLASS_COLORS")
        M.RAID_CLASS_COLORS = { [token] = GREEN }
        rawset(_G, "RAID_CLASS_COLORS", M.RAID_CLASS_COLORS)
        Core.__ResetClassColor()
        local ok, err = pcall(fn)
        M.RAID_CLASS_COLORS = was
        rawset(_G, "RAID_CLASS_COLORS", wasG)
        Core.__ResetClassColor()
        NS.ApplyLook()
        M.__fireTimers()
        if not ok then error(err, 0) end
    end
end

local function classRGB()
    local r, g, b = M.LibStub("LibKa0s-Core-1.0").ClassColor("player")
    assertTrue(r ~= nil, "the suite's player has a class color")
    return { r, g, b }
end

local function assertClass(c, what, alpha)
    local want = classRGB()
    assertTrue(type(c) == "table", what .. ": a color, not the skin's token")
    for i = 1, 3 do assertNear(c[i], want[i], 1e-6, what .. ": channel " .. i) end
    if alpha then assertNear(c[4], alpha, 1e-6, what .. ": the stored alpha") end
end

-- Write each path, run `fn`, then put every path back as it was.
local function with(paths, fn)
    local saved = {}
    for path, v in pairs(paths) do saved[path] = NS.GetSetting(path); set(path, v) end
    local ok, err = pcall(fn)
    for path, v in pairs(saved) do set(path, v) end
    if not ok then error(err, 0) end
end

local SWATCH = { 0.1, 0.2, 0.3, 0.5 }

test("FB-SM-02 bars: the flat fill, background, border and text draw the class color while the skin's is followed too", planted(function()
    with({
        ["bars.barColor"] = SWATCH, ["bars.barColorFromSkin"] = true, ["bars.useClassColorBar"] = true,
        ["bars.bgColor"] = SWATCH, ["bars.bgColorFromSkin"] = true, ["bars.useClassColorBg"] = true,
        ["bars.borderColor"] = SWATCH, ["bars.borderColorFromSkin"] = true, ["bars.useClassColorBorder"] = true,
        ["bars.fontColor"] = SWATCH, ["bars.fontColorFromSkin"] = true, ["bars.useClassColorFont"] = true,
        ["bars.border"] = true,
    }, function()
        assertClass(NS.BarStyle.Swatch("barColor", "cl.barFill", "useClassColorBar"), "the flat fill", 0.5)
        local st = NS.BarStyle.Resolve("row")
        assertClass(st.bg, "the background", 0.5)
        assertClass(st.text, "the text", 0.5)
        assertClass(st.border, "the border", 0.5)
    end)
end))

test("FB-SM-02 bars: with the class off the skin's color still wins over the swatch", function()
    with({ ["bars.bgColor"] = SWATCH, ["bars.bgColorFromSkin"] = true, ["bars.useClassColorBg"] = false },
        function()
            assertTrue(NS.BarStyle.Resolve("row").bg == "cl.barBg" or type(NS.BarStyle.Resolve("row").bg) == "table"
                and NS.BarStyle.Resolve("row").bg[1] ~= 0.1, "the skin's background, not the swatch")
        end)
end)

test("FB-SM-02 detached windows: the background and the border draw the class color while the skin's is followed too", planted(function()
    local D, id = NS.Detached, "weapon"
    local s = NS.db.profile.layout.blocks[id]
    s.docked = false
    D.Refresh()
    local ok, err = pcall(with, {
        ["layout.detached.bgColor"] = SWATCH, ["layout.detached.bgFromSkin"] = true,
        ["layout.detached.useClassColorBg"] = true,
        ["layout.detached.borderColor"] = SWATCH, ["layout.detached.borderFromSkin"] = true,
        ["layout.detached.useClassColorBorder"] = true, ["layout.detached.border"] = true,
    }, function()
        local f = D.Frame(id)
        assertTrue(f.styleBg:IsShown(), "the window's own fill shows")
        assertClass(rawget(f.styleBg, "__color"), "the background", 0.5)
        assertTrue(D.ShellOpts(f).noBorder == true, "the skin's edge gives way to the class-colored one")
        assertClass(rawget(f.styleEdge.edges[1], "__color"), "the border")
    end)
    s.docked = true
    D.Refresh()
    if not ok then error(err, 0) end
end))

test("FB-SM-02 icons: the border draws the class color while the skin's icon border is followed too", planted(function()
    with({ ["icons.borderColor"] = SWATCH, ["icons.borderColorFromSkin"] = true,
           ["icons.useClassColorBorder"] = true, ["icons.borderColorFromRow"] = false, ["icons.border"] = true },
        function() assertClass(NS.Rows.IconStyle({ 1, 0, 0, 1 }, 14).border, "the icon border", 0.5) end)
    with({ ["icons.borderColorFromRow"] = true, ["icons.useClassColorBorder"] = true },
        function()
            local c = NS.Rows.IconStyle({ 1, 0, 0, 1 }, 14).border
            assertNear(c[1], 1, 1e-6, "Use the row's color still comes first (the meaning color)")
        end)
end))

test("FB-SM-02 trainer popup: the trainer's name draws the class color while the skin's accent is followed too", planted(function()
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    local ok, err = pcall(with, { ["trainers.nameColor"] = SWATCH, ["trainers.nameColorFromSkin"] = true,
        ["trainers.useClassColorName"] = true }, function()
        NS.TrainerPopup.Show("fistWeapons")
        assertClass(M.__paint(NS.TrainerPopup.Cards()[1].name).textColor, "the name", 0.5)
    end)
    NS.TrainerPopup.Hide()
    M.UnitFactionGroup = savedFaction
    if not ok then error(err, 0) end
end))
