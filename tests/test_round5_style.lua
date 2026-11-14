-- tests/test_round5_style.lua — the owner's round-5 feedback (2026-11-13), R5-7: Layout > Detached
-- windows, one style for every detached window. Each row reaches an open detached frame through the
-- seam (NS.SetByPath, its onChange NS.ApplyLook, LAYOUT_CHANGED, NS.Detached.Refresh).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D = NS.Detached
local ID = "weapon"

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- Detach the weapon block, run `fn(frame)`, then put every style key and the block back.
local function withStyled(fn)
    local s = NS.db.profile.layout.blocks[ID]
    local style = NS.db.profile.layout.detached
    local saved, savedScale = {}, s.scale
    for k, v in pairs(style) do saved[k] = v end
    s.docked = false
    D.Refresh()
    local ok, err = pcall(fn, D.Frame(ID))
    for k in pairs(style) do style[k] = nil end
    for k, v in pairs(saved) do style[k] = v end
    s.scale, s.docked = savedScale, true
    D.Refresh()
    if not ok then error(err, 0) end
end

-- The frames' scale and the body's offset, recorded (the base mock keeps neither).
local function recordScale(f)
    rawset(f, "SetScale", function(self, v) rawset(self, "__scaleSet", v) end)
    rawset(f, "GetScale", function(self) return rawget(self, "__scaleSet") end)
end
local function bodyTop(f)
    local y
    rawset(f.body, "SetPoint", function(_, _, _, _, _, oy) y = y or oy end)
    D.Render(ID)
    rawset(f.body, "SetPoint", nil)
    return y
end

local function set(path, v)
    assertTrue(NS.SetByPath(path, v) ~= false, "the seam takes " .. path)
end

test("round5 detached style: every row is on the Layout page's Detached windows tab, the strata row moved there", function()
    local want = {
        "layout.detached.scale", "layout.detached.alpha", "layout.detached.titleBand", "layout.detachedStrata",
        "layout.detached.bgColor", "layout.detached.useClassColorBg", "layout.detached.bgFromSkin",
        "layout.detached.border", "layout.detached.borderStyle", "layout.detached.borderSize",
        "layout.detached.borderColor", "layout.detached.useClassColorBorder", "layout.detached.borderFromSkin",
    }
    local byPath = {}
    for _, row in ipairs(NS.Schema) do byPath[row.path] = row end
    for _, path in ipairs(want) do
        local row = byPath[path]
        assertTrue(row ~= nil, path .. " has a row")
        assertEqual(row.page, "layout", path .. " is on the Layout page")
        assertEqual(row.group, NS.L["Detached windows"], path .. " is on the Detached windows tab")
        assertTrue(row.onChange ~= nil, path .. " restyles on a write")
    end
    assertEqual(byPath["layout.strata"].group, NS.L["Window"], "the window's own strata stays on the Window tab")
end)

test("round5 detached style: the companions start on the skin, in the composer and in the defaults", function()
    local P = NS.defaults.profile.layout.detached
    assertTrue(P.bgFromSkin == true and P.borderFromSkin == true, "both companions default on (skinning-§6)")
    assertEqual(P.titleBand, "always", "the title band shows by default")
    assertEqual(P.scale, 1, "no scale by default")
    assertEqual(P.alpha, 1, "opaque by default")
end)

test("round5 detached style: Window scale multiplies the block's own scale", function()
    withStyled(function(f)
        recordScale(f)
        NS.db.profile.layout.blocks[ID].scale = 1.5
        set("layout.detached.scale", 0.8)
        assertTrue(near(f:GetScale(), 1.2), "1.5 x 0.8, got " .. tostring(f:GetScale()))
        set("layout.detached.scale", 1)
        assertTrue(near(f:GetScale(), 1.5), "the block's own scale alone at 1")
        rawset(f, "SetScale", nil)
        rawset(f, "GetScale", nil)
    end)
end)

test("round5 detached style: Window opacity reaches the open window", function()
    withStyled(function(f)
        assertTrue(near(f:GetAlpha(), 1), "opaque by default")
        set("layout.detached.alpha", 0.4)
        assertTrue(near(f:GetAlpha(), 0.4), "the window takes the opacity")
    end)
end)

test("round5 detached style: the background follows the skin until its companion is off, then the swatch", function()
    withStyled(function(f)
        assertFalse(f.styleBg:IsShown(), "the skin's window fill, no fill of the window's own")
        set("layout.detached.bgColor", { 0.1, 0.2, 0.3, 0.4 })
        assertFalse(f.styleBg:IsShown(), "the swatch is not read while the companion is on")
        set("layout.detached.bgFromSkin", false)
        assertTrue(f.styleBg:IsShown(), "the swatch's fill shows")
        local c = rawget(f.styleBg, "__color")
        assertTrue(c ~= nil and near(c[1], 0.1) and near(c[3], 0.3) and near(c[4], 0.4), "in the swatch's color, its alpha kept")
        set("layout.detached.bgFromSkin", true)
        assertFalse(f.styleBg:IsShown(), "back on the skin")
    end)
end)

test("round5 detached style: the border is the skin's, the window's own, or none", function()
    withStyled(function(f)
        local function ownShown()
            for _, e in ipairs(f.styleEdge.edges) do if e:IsShown() then return true end end
            return false
        end
        assertFalse(D.ShellOpts(f).noBorder == true, "the skin's edge by default")
        assertFalse(ownShown(), "and none of the window's own")
        set("layout.detached.borderColor", { 0.9, 0.1, 0.1, 1 })
        set("layout.detached.borderSize", 3)
        set("layout.detached.borderFromSkin", false)
        assertTrue(D.ShellOpts(f).noBorder == true, "the skin's edge off")
        assertTrue(ownShown(), "the window's own edge on")
        local c = rawget(f.styleEdge.edges[1], "__color")
        assertTrue(c ~= nil and near(c[1], 0.9), "in the swatch's color")
        assertEqual(f.styleEdge.edges[1]:GetHeight(), 3, "at the stored thickness")
        set("layout.detached.border", false)
        assertTrue(D.ShellOpts(f).noBorder == true, "Show border off: no skin edge")
        assertFalse(ownShown(), "and no edge of its own")
    end)
end)

test("round5 detached style: Title band Never hides the band and keeps a drag strip", function()
    withStyled(function(f)
        assertTrue(f.title:IsShown() and f.dock:IsShown(), "the band's title and marks show by default")
        set("layout.detached.titleBand", "never")
        assertFalse(f.title:IsShown(), "no title")
        assertFalse(f.dock:IsShown() or f.collapse:IsShown() or f.sort:IsShown() or f.restore:IsShown(), "no marks")
        assertTrue(D.ShellOpts(f).noTopBar == true, "no band fill")
        assertEqual(bodyTop(f), -D.GRIP_H, "the body starts below the drag strip")
        assertTrue(f:GetScript("OnDragStart") ~= nil, "the window still drags")
        set("layout.detached.titleBand", "always")
        assertTrue(f.title:IsShown() and f.dock:IsShown(), "the band back")
        assertFalse(D.ShellOpts(f).noTopBar == true, "its fill back")
    end)
end)

test("round5 detached style: Title band On hover shows the band while the pointer is over the window", function()
    withStyled(function(f)
        local over = false
        rawset(f, "IsMouseOver", function() return over end)
        set("layout.detached.titleBand", "hover")
        local poll = f:GetScript("OnUpdate")
        assertTrue(poll ~= nil, "the window polls the pointer")
        assertFalse(f.title:IsShown() or f.dock:IsShown(), "hidden with the pointer away")
        assertTrue(D.ShellOpts(f).noTopBar == true, "no band fill")
        assertEqual(bodyTop(f), -D.TitleHeight(f), "the body stays below the band, so nothing jumps")
        over = true
        poll(f, 1)
        assertTrue(f.title:IsShown() and f.dock:IsShown() and f.collapse:IsShown(), "shown with the pointer over")
        assertFalse(D.ShellOpts(f).noTopBar == true, "with its fill")
        assertTrue(f:GetScript("OnDragStart") ~= nil, "and the window drags by it")
        over = false
        poll(f, 1)
        assertFalse(f.title:IsShown(), "hidden again when the pointer leaves")
        rawset(f, "IsMouseOver", nil)
        set("layout.detached.titleBand", "always")
        assertTrue(f:GetScript("OnUpdate") == nil, "Always polls nothing")
    end)
end)

test("round5 detached style: a skin switch keeps the style", function()
    withStyled(function(f)
        set("layout.detached.bgFromSkin", false)
        set("layout.detached.alpha", 0.5)
        NS.bus:SendMessage(NS.MSG.LAYOUT_CHANGED)   -- what the skin owner's look-change hook sends
        assertTrue(f.styleBg:IsShown(), "the swatch's fill survives the repaint")
        assertTrue(near(f:GetAlpha(), 0.5), "and the opacity")
    end)
end)
