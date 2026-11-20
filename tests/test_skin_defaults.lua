-- tests/test_skin_defaults.lua — the skin-defaults run (LibKa0s#97, Ka0sAddonsCommonTasks
-- docs/2026-11-20-SKIN_DEFAULTS_AUDIT, item SD-SK-SM): the waypoint arrow's text color and shadow
-- follow the skin (SD-SK-SM.2, SM.3), the settings list's eye marks take the skin's icon tint
-- (SD-SK-SM.1), lines written onto the stock GameTooltip read the gtip family (the owner's U-7), and
-- a trainer card takes the skin's hover wash (the owner's U-31, SkillMaster#9).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local WA, TP = NS.WaypointArrow, NS.TrainerPopup

local function skinLib() return M.LibStub("LibKa0s-Skin-1.0") end

local function rgb(r, g, b) return ("%.3f %.3f %.3f"):format(r or -1, g or -1, b or -1) end
local function tok(name)
    local c = NS.SkinColor(name)
    return c and rgb(c[1], c[2], c[3]) or "nil"
end

--- Run `fn(key)` under the first shipped skin (other than the current one) where `differs()`
--- answers true, then put the stored choice back. Raises when no skin differs.
local function underSkinWhere(differs, fn)
    local lib = skinLib()
    local source, current = lib:GetChoice("SkillMaster")
    local picked
    for _, opt in ipairs(NS.SKIN_OPTIONS) do
        if opt.value ~= current then
            lib:SetChoice("SkillMaster", source, opt.value)
            if differs() then picked = opt.value break end
        end
    end
    local ok, err = true, nil
    if picked then ok, err = pcall(fn, picked) end
    lib:SetChoice("SkillMaster", source, current)
    assertTrue(picked ~= nil, "a shipped skin draws it differently")
    if not ok then error(err, 0) end
end

local function arrowText()
    for _, r in ipairs({ WA.Frame():GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then return r end
    end
    return nil
end

-- ── SD-SK-SM.2, SM.3: the arrow's text color and shadow ──────────────────────────────────────

test("skin defaults: the arrow's text color and shadow companions default on, the schema agreeing (SD-SK-SM.2, SM.3)", function()
    -- red under: no waypoints.arrowFontColorFromSkin / arrowFontShadowFromSkin seed in the defaults
    local PW = NS.defaults.profile.waypoints
    local at = {}
    for _, row in ipairs(NS.Schema) do at[row.path] = row end
    for _, key in ipairs({ "arrowFontColorFromSkin", "arrowFontShadowFromSkin" }) do
        assertEqual(PW[key], true, key .. " is seeded true")
        local row = at["waypoints." .. key]
        assertTrue(row ~= nil, key .. " is a schema row (WaypointArrowSettings minor 3)")
        assertEqual(row.default, PW[key], key .. ": the row's default and the AceDB seed agree")
    end
end)

test("skin defaults: the arrow's text takes the skin's HUD text color and moves on a skin switch (SD-SK-SM.2)", function()
    -- red under: no Restyle from the skin listener, so the shown arrow keeps the old skin's color
    local wp = NS.db.profile.waypoints
    local savedArrow = wp.arrow
    wp.arrow = true
    WA.ShowTest()
    local ok, err = pcall(function()
        local fs = arrowText()
        assertTrue(fs ~= nil, "the sample arrow shows its distance")
        assertEqual(rgb(fs:GetTextColor()), tok("hud.text"), "the skin's hud.text while the companion is on")
        local before = tok("hud.text")
        underSkinWhere(function() return tok("hud.text") ~= before end, function()
            assertEqual(rgb(fs:GetTextColor()), tok("hud.text"), "a switch repaints the shown arrow's text")
        end)
        NS.SetByPath("waypoints.arrowFontColorFromSkin", false)
        local c = wp.arrowFontColor
        assertEqual(rgb(fs:GetTextColor()), rgb(c[1], c[2], c[3]), "off: the swatch")
        NS.SetByPath("waypoints.arrowFontColorFromSkin", true)
    end)
    WA.HideTest()
    wp.arrow = savedArrow
    WA.ApplySettings()
    if not ok then error(err, 0) end
end)

-- ── SD-SK-SM.1: the settings list's eye marks ────────────────────────────────────────────────

--- The addon's AceGUI with a painting "Icon" (tests/fixture_icon_widget.lua) while `fn(aceGUI)` runs.
local installIcon = dofile("tests/fixture_icon_widget.lua")
local function withTextureIcons(fn)
    local uninstall, AceGUI = installIcon(NS, M)
    local ok, err = pcall(fn, AceGUI)
    uninstall()
    if not ok then error(err, 0) end
end

local function eyeRow(AceGUI, dimmed)
    local scroll = AceGUI:Create("SimpleGroup")
    local _, _, marks = NS.OptionsList.Row(scroll, nil, { text = "Leatherworking", actions = {
        { image = NS.Icon("eye"), title = "Window", dimmed = dimmed },
    } })
    return marks[1]
end

test("skin defaults: a list row's eye takes the skin's icon tint with the Scope cleared, the dim as alpha only (SD-SK-SM.1)", function()
    -- red under: settings/BoxList.lua's SetVertexColor(1, 1, 1, a.dimmed and 0.35 or 1)
    local lib = skinLib()
    local panel, fonts = lib:GetIgnore("SkillMaster")
    withTextureIcons(function(AceGUI)
        lib:SetIgnore("SkillMaster", false, fonts)
        local ok, err = pcall(function()
            local eye = eyeRow(AceGUI, true)
            assertEqual(rgb(eye.image:GetVertexColor()), tok("icon.tint"), "the skin's icon.tint")
            assertTrue(math.abs(eye.image:GetAlpha() - 0.35) < 1e-6, "a dimmed eye is dimmed by alpha")
            local lit = eyeRow(AceGUI, false)
            assertEqual(lit.image:GetAlpha(), 1, "a lit eye at full alpha")
            local before = tok("icon.tint")
            underSkinWhere(function() return tok("icon.tint") ~= before end, function()
                assertEqual(rgb(eye.image:GetVertexColor()), tok("icon.tint"), "a switch retints it")
            end)
            AceGUI:Release(eye)
            assertEqual(rgb(eye.image:GetVertexColor()), rgb(1, 1, 1), "release gives the pooled image its white back")
            assertEqual(eye.image:GetAlpha(), 1, "and its full alpha")
        end)
        lib:SetIgnore("SkillMaster", panel, fonts)
        if not ok then error(err, 0) end
    end)
end)

test("skin defaults: with Ignore settings panel on, the eye keeps the client's white (SD-SK-SM.1)", function()
    local lib = skinLib()
    local panel, fonts = lib:GetIgnore("SkillMaster")
    withTextureIcons(function(AceGUI)
        lib:SetIgnore("SkillMaster", true, fonts)
        local ok, err = pcall(function()
            local eye = eyeRow(AceGUI, true)
            assertEqual(rgb(eye.image:GetVertexColor()), rgb(1, 1, 1), "the stock white")
            assertTrue(math.abs(eye.image:GetAlpha() - 0.35) < 1e-6, "still dimmed")
        end)
        lib:SetIgnore("SkillMaster", panel, fonts)
        if not ok then error(err, 0) end
    end)
end)

-- ── U-7: lines on the stock GameTooltip read gtip.* ──────────────────────────────────────────

--- A GameTooltip that records each AddLine's text and color while `fn()` runs.
local function withLineTip(fn)
    local saved = M.GameTooltip
    local lines = {}
    local tip = setmetatable({}, { __index = saved })
    tip.AddLine = function(_, s, r, g, b) lines[#lines + 1] = { s = s, c = rgb(r, g, b) } end
    tip.AddDoubleLine = function(_, s, _, r, g, b) lines[#lines + 1] = { s = s, c = rgb(r, g, b) } end
    tip.SetOwner = function() end
    tip.IsOwned = function() return true end
    M.GameTooltip = tip
    local ok, err = pcall(fn, lines)
    M.GameTooltip = saved
    if not ok then error(err, 0) end
    return lines
end

local function withPopup(fn)
    local savedFaction = M.UnitFactionGroup
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    TP.Show("fistWeapons")
    local ok, err = pcall(fn)
    TP.Hide()
    M.UnitFactionGroup = savedFaction
    if not ok then error(err, 0) end
end

-- A skin whose tooltip title and body differ from its window accent and body (Obsidian, for one).
local function gtipDiffers()
    return tok("gtip.title") ~= tok("text.accent") and tok("gtip.body") ~= tok("text.body")
end
-- A skin whose tooltip muted differs from its window muted (Ka0s Default).
local function mutedDiffers() return tok("gtip.muted") ~= tok("text.muted") end

test("skin defaults: a trainer card's tooltip lines read gtip.title and gtip.body (U-7)", function()
    -- red under: tipLine(self.trainer.name, "text.accent") and the text.body place line
    underSkinWhere(gtipDiffers, function()
        withPopup(function()
            local card = TP.Cards()[1]
            local lines = withLineTip(function() card:GetScript("OnEnter")(card) end)
            assertEqual(lines[1].s, card.trainer.name)
            assertEqual(lines[1].c, tok("gtip.title"), "the name in gtip.title")
            assertEqual(lines[2].c, tok("gtip.body"), "the place in gtip.body")
            card:GetScript("OnLeave")(card)
        end)
    end)
end)

test("skin defaults: the waypoint arrow's tooltip lines read the gtip family (U-7)", function()
    local wp = NS.db.profile.waypoints
    local savedArrow = wp.arrow
    wp.arrow = true
    WA.ShowTest()
    local ok, err = pcall(function()
        underSkinWhere(gtipDiffers, function()
            local f = WA.Frame()
            local lines = withLineTip(function() f:__fire("OnEnter") end)
            assertEqual(lines[1].c, tok("gtip.title"), "the trainer in gtip.title")
            assertEqual(lines[2].c, tok("gtip.body"), "the place in gtip.body")
            f:__fire("OnLeave")
        end)
        underSkinWhere(mutedDiffers, function()
            local f = WA.Frame()
            local lines = withLineTip(function() f:__fire("OnEnter") end)
            assertEqual(lines[#lines].c, tok("gtip.muted"), "the hint in gtip.muted")
            f:__fire("OnLeave")
        end)
    end)
    WA.HideTest()
    wp.arrow = savedArrow
    WA.ApplySettings()
    if not ok then error(err, 0) end
end)

test("skin defaults: the row tooltip's tones read the gtip family, meaning colors kept (U-7)", function()
    local RT = NS.RowTooltip
    assertEqual(RT.TONES.body, "gtip.body")
    assertEqual(RT.TONES.muted, "gtip.muted")
    assertEqual(RT.TONES.heading, "gtip.title")
    assertEqual(RT.TONES.accent, "gtip.title")
    assertEqual(RT.TONES.good, "sem.good", "a meaning color stays its semantic token")
end)

-- ── U-31: the trainer card's hover wash ──────────────────────────────────────────────────────

--- The card's ListRow state as the skin facade last painted it.
local function washOf(card)
    local rec = skinLib().painted and skinLib().painted[card]
    local call = rec and rec.calls.ListRow
    return call and call[1]
end

test("skin defaults: a trainer card takes the skin's list.hover wash on hover, back on leave (U-31, SkillMaster#9)", function()
    -- red under: onCardEnter / onCardLeave painting nothing but the GameTooltip
    withPopup(function()
        local cards = TP.Cards()
        assertTrue(#cards >= 2, "the popup lists two trainers")
        local a, b = cards[1], cards[2]
        TP.Select(1)
        withLineTip(function()
            b:GetScript("OnEnter")(b)
            assertEqual(washOf(b), "hover", "the hovered card wears list.hover")
            b:GetScript("OnLeave")(b)
            assertEqual(washOf(b), "normal", "back to normal on leave")
            a:GetScript("OnEnter")(a)
            assertEqual(washOf(a), "hover", "the selected card shows the hover too")
            a:GetScript("OnLeave")(a)
            assertEqual(washOf(a), "selected", "and is selected again on leave")
        end)
    end)
end)
