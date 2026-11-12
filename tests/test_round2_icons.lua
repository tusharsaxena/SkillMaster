-- tests/test_round2_icons.lua — the owner's third round-2 follow-up: the rank tiers as shades of
-- the category's color, the rows' marks in the header's column with the bar's timer inside it, the
-- Bars > Icons settings, the LDB tooltip in the window's look, and a pin that reaches the feed.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNear = T.assertNear

local W, R = NS.MainWindow, NS.Rows

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()
end

local function withWorld(fn)
    NS.Helpers.RestoreDefaults("bars")
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(fn)
    NS.Helpers.RestoreDefaults("bars")
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function windowRow(key)
    for _, row in ipairs(W.Rows()) do
        if row.entry and row.entry.key == key then return row end
    end
end

local function paint(t)
    local p = M.__paint(t)
    return p.texture and p.vertex or p.color
end

-- ── the rank tiers ──────────────────────────────────────────────────────────────────────────

test("round2 icons: a tier's shade is the category color darkened, the first tier the color itself", function()
    local c = { 0.4, 0.6, 0.8, 1 }
    local s1, s4 = NS.Bar.TierShade(c, 1), NS.Bar.TierShade(c, 4)
    assertNear(s1[2], 0.6, 1e-9, "Apprentice: the color itself")
    assertTrue(s4[1] < s1[1] and s4[2] < s1[2] and s4[3] < s1[3], "Artisan: darker in every channel")
    assertNear(s4[1] / s4[3], 0.4 / 0.8, 1e-9, "the same hue, only darker")
    for i = 2, 4 do assertTrue(NS.Bar.TIER_SHADE[i] < NS.Bar.TIER_SHADE[i - 1], "each tier darker than the last") end
end)

-- ── the rows' marks and timer ───────────────────────────────────────────────────────────────

test("round2 icons: a row's mark stands in the header's column, the bar one inset short of it", function()
    assertEqual(R.GO_W, NS.Chrome.SIZE, "the header mark's size")
    assertEqual(R.EDGE, 4, "its inset from the right edge (modules/Blocks.lua's detach mark)")
    assertEqual(R.BAR_RIGHT, R.EDGE + R.GO_W + R.EDGE, "the bar ends the same gap before the mark")
    withWorld(function()
        local row = windowRow("leatherworking")
        local point, x
        rawset(row.act, "SetPoint", function(_, p, _, _, ox) point, x = p, ox end)
        W.Refresh(true)
        rawset(row.act, "SetPoint", nil)
        assertEqual(point, "TOPRIGHT")
        assertEqual(x, -R.EDGE, "the action mark at the header's inset")
    end)
end)

test("round2 icons: the bar's timer sits inside its far end, and the near end when the text sits right", function()
    withWorld(function()
        local bar = windowRow("fishing").bar
        local point, rel, _, x = bar.timer:GetPoint(1)
        assertEqual(point, "RIGHT", "inside the far end")
        assertTrue(rel == bar and x < 0, "on the bar itself, inset")
        set("bars.textAnchor", "RIGHT")
        bar = windowRow("fishing").bar
        point = bar.timer:GetPoint(1)
        assertEqual(point, "LEFT", "the text took the right: the timer moves left")
    end)
end)

-- ── Bars > Icons ────────────────────────────────────────────────────────────────────────────

test("round2 icons: the Icons tab's rows, their defaults the old fixed look", function()
    local P = NS.defaults.profile.icons
    assertTrue(P.show and P.size == 16 and P.zoom == 7 and P.border and P.borderSize == 1, "16 px, 7 % crop, 1 px edge")
    assertTrue(P.borderColorFromRow, "edged in the row's own color by default")
    for _, path in ipairs({ "icons.show", "icons.size", "icons.zoom", "icons.border", "icons.borderStyle",
                            "icons.borderSize", "icons.borderColor", "icons.borderColorFromRow",
                            "icons.borderColorFromSkin", "icons.borderStyleFromSkin" }) do
        local r = NS.FindSchemaRow(path)
        assertTrue(r ~= nil, path .. " has a row")
        assertEqual(r.group, NS.L["Icons"], path .. " on the Icons tab")
    end
end)

test("round2 icons: size, zoom, border and its color reach the drawn icon; off hides it", function()
    withWorld(function()
        local row = windowRow("leatherworking")
        local st = R.IconStyle(R.FillColor(row.entry), 20)
        assertEqual(st.size, 16)
        assertNear(st.crop, 0.07, 1e-9)
        assertTrue(st.border ~= nil and math.abs(st.border[1] - R.FillColor(row.entry)[1]) < 1e-9, "the row's color")
        set("icons.size", 24)
        set("icons.zoom", 20)
        row = windowRow("leatherworking")
        local w, h
        rawset(row.iconFrame, "SetSize", function(_, a, b) w, h = a, b end)
        row:SetSkill(row.entry)
        rawset(row.iconFrame, "SetSize", nil)
        assertEqual(w, 20, "never taller than the 20 px row")
        assertEqual(h, 20)
        local l, _, _, _, r = row.icon:GetTexCoord()
        assertNear(l, 0.2, 1e-9, "zoom 20 crops a fifth each side")
        assertNear(r, 0.8, 1e-9)
        set("icons.borderColorFromRow", false)
        set("icons.borderColorFromSkin", false)
        set("icons.borderColor", { 0.9, 0.1, 0.1, 1 })
        row = windowRow("leatherworking")
        assertNear(paint(row.iconEdges[1])[1], 0.9, 1e-6, "the swatch, once both companions are off")
        set("icons.border", false)
        row = windowRow("leatherworking")
        assertFalse(row.iconEdges[1]:IsShown(), "Show border off: no edge")
        set("icons.show", false)
        row = windowRow("leatherworking")
        assertFalse(row.iconFrame:IsShown(), "Show icons off: no icon")
        local point, rel = row.name:GetPoint(1)
        assertTrue(point == "LEFT" and rel == row, "the name takes the icon's place")
    end)
    for _, k in ipairs({ "show", "size", "zoom", "border", "borderColor", "borderColorFromRow", "borderColorFromSkin" }) do
        NS.SetByPath("icons." .. k, NS.defaults.profile.icons[k])
    end
    M.__fireTimers()
end)

-- ── the LDB tooltip ─────────────────────────────────────────────────────────────────────────

local function recordingTip()
    local name = "SkillMasterIconsTip"
    local tip = M.CreateFrame("GameTooltip", name, M.UIParent)
    tip.lines = {}
    function tip:GetName() return name end
    function tip:NumLines() return #self.lines end
    local function region(n)
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local k = name .. side .. n
            _G[k] = _G[k] or M.CreateFrame("Frame", k, tip)
        end
    end
    function tip:AddLine(text) self.lines[#self.lines + 1] = { text } region(#self.lines) end
    function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end
    return tip
end

test("round2 icons: the LDB tooltip draws the window's block titles on header bands and stripes every other row", function()
    withWorld(function()
        local tip = recordingTip()
        local rows = NS.Broker.FillTooltip(tip)
        local titles = {}
        for _, l in ipairs(tip.lines) do
            if not l[2] then titles[#titles + 1] = (l[1] or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
        end
        local joined = table.concat(titles, "|")
        assertTrue(joined:find(NS.BlockDefs.primary.title, 1, true) ~= nil, "Primary Professions, as the window says it")
        assertTrue(joined:find(NS.BlockDefs.weapon.title, 1, true) ~= nil, "Weapon Skills")
        local bands = NS.Broker.Bands(tip)
        -- One band per header, one per even row of each section.
        assertTrue(#bands > 0 and #bands < #rows + #titles, "headers and every other row, not every row")
        local header = NS.Bar.Color("sm.headerBg")
        assertNear(paint(bands[1])[1], header[1], 1e-6, "the first band is a header's, in the block header's color")
        NS.Broker.HideTooltip()
        assertEqual(#NS.Broker.Bands(tip), 0, "every band goes with the tooltip")
    end)
end)

test("round2 icons: a skill's name in the LDB tooltip is white, a weapon below its cap included", function()
    withWorld(function()
        local tip = recordingTip()
        NS.Broker.FillTooltip(tip)
        local r, g, b = NS.Skin.Color("gtip.value")
        local white = r and ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255) or nil
        local axes
        for _, l in ipairs(tip.lines) do
            if l[2] and l[1]:find(NS.L["Axes"], 1, true) then axes = l[1] end
        end
        assertTrue(axes ~= nil, "Axes is in the tooltip")
        if white then assertTrue(axes:lower():find(white, 1, true) ~= nil, "in the value color, not the warning color") end
        NS.Broker.HideTooltip()
    end)
end)

test("round2 icons: Pin to the broker feed redraws the feed at once", function()
    local prevTpl = NS.GetSetting("broker.template")
    NS.SetByPath("broker.template", "{pinned}")
    local row = { kind = "skill", entry = { key = "cooking", name = "Cooking", learned = true, rank = 140, max = 150 } }
    local pin
    for _, r in ipairs(NS.Interact.MenuRows(row)) do if r.value == "pin" then pin = r end end
    assertTrue(pin ~= nil and not pin.disabled, "the live character can pin")
    local refreshed = false
    local prev = NS.Broker.Refresh
    NS.Broker.Refresh = function(...) refreshed = true return prev(...) end
    local ok, err = pcall(pin.onClick)
    NS.Broker.Refresh = prev
    assertTrue(ok, tostring(err))
    assertTrue(refreshed, "the feed redraws on the pin, not at the next skill-up")
    assertEqual(NS.db.char.pinned, "cooking")
    NS.db.char.pinned = nil
    NS.SetByPath("broker.template", prevTpl)
end)

-- ── round 2, the header and the hammer ───────────────────────────────────────────────────────

local function tint(t)
    local p = M.__paint(t)
    return p.vertex
end

local function sameColor(got, want, what)
    assertTrue(got ~= nil and want ~= nil, what .. ": a color")
    for i = 1, 3 do assertNear(got[i], want[i], 1e-6, what) end
end

test("round2 header: Weapon Skills carries no cap line beside its title", function()
    assertEqual(NS.Blocks.Meta("weapon", { { entry = { learned = true, max = 120 } } }), "",
        "no \"cap 120 (5 x level)\"")
end)

test("round2 header: the detach mark wears the title's color at rest and the hot color under the pointer", function()
    withWorld(function()
        local h = W.Headers()[1]
        assertTrue(h ~= nil, "a block header")
        local heading = { NS.Skin.Color("text.heading") }
        sameColor(tint(h.detach.icon), heading, "at rest: the title's color")
        h.detach:__fire("OnEnter")
        sameColor(tint(h.detach.icon), { NS.Skin.Color("icon.hot") }, "hovered: hot")
        h.detach:__fire("OnLeave")
        sameColor(tint(h.detach.icon), heading, "back to the title's color")
    end)
end)

test("round2 hammer: the action mark lights up while the pointer is on it, as the detach mark does", function()
    withWorld(function()
        local row
        for _, r in ipairs(W.Rows()) do if r.act and r.act:IsShown() then row = r break end end
        assertTrue(row ~= nil, "a row with its action mark")
        local rest = tint(row.act.icon)
        local over = false
        rawset(row.act, "IsMouseOver", function() return over end)
        row:__fire("OnEnter")
        row:__fire("OnUpdate", 0.05)
        sameColor(tint(row.act.icon), rest, "on the row, off the mark: at rest")
        over = true
        row:__fire("OnUpdate", 0.05)
        sameColor(tint(row.act.icon), { NS.Skin.Color("icon.hot") }, "on the mark: hot")
        row:__fire("OnLeave")
        sameColor(tint(row.act.icon), rest, "the pointer gone: at rest")
    end)
end)
