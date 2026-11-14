-- tests/test_bars_round2.lua — feedback round 2, the bars branch (FB-9, FB-10, FB-11).
--
-- FB-9: at a Tooltip bar height of 12 px the owner saw a large purple blob over the broker
-- tooltip. Bars > Tooltip bar height reaches one bar only, the row tooltip's, which lives on
-- GameTooltip and was hidden by GameTooltip's OnHide alone. GameTooltip handed to another owner
-- while shown (SetOwner clears it, OnTooltipCleared, no OnHide) kept that bar on screen, anchored to
-- a line of whatever the tooltip showed next: the broker feed's tooltip, its first rows. The fill
-- of the last row shown (an Other row's purple) is the blob. The cases pin that the bar never
-- outlives its tooltip's content, and that every region it draws is painted and inside it at every
-- height the slider offers.
-- FB-10: the bar border is off by default; a skin's real bar border style still wins while its
-- companion is on (skinning-§6).
-- FB-11: the trainer popup's trainer name has its own color, the skin's accent by default.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local assertNear = T.assertNear

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()
end

local function windowRow(key)
    for _, row in ipairs(NS.MainWindow.Rows()) do
        if row.entry and row.entry.key == key then return row end
    end
end

--- Run `fn` on the sample character with the main window open, and always put both back.
local function withWindow(fn)
    NS.Helpers.RestoreDefaults("bars")
    NS.Helpers.RestoreDefaults("trainers")
    M.__fireTimers()
    NS.Preview.Apply(true)
    NS.MainWindow.Show()
    local ok, err = pcall(fn)
    M.GameTooltip:Hide()
    NS.MainWindow.Hide()
    NS.Preview.Apply(false)
    NS.Helpers.RestoreDefaults("bars")
    NS.Helpers.RestoreDefaults("trainers")
    M.__fireTimers()
    if not ok then error(err, 0) end
end

-- ---------------------------------------------------------------------------------------------
-- FB-9: the row tooltip's bar
-- ---------------------------------------------------------------------------------------------

local function painted(region)
    local p = M.__paint(region)
    return p.color ~= nil or p.texture ~= nil or p.atlas ~= nil
end

--- Every point of `region` is on `bar` itself, its vertical offset within the bar's height.
local function insideBar(region, bar, h, what)
    for i = 1, region:GetNumPoints() do
        local _, rel, _, _, y = region:GetPoint(i)
        assertTrue(rel == bar, what .. ": anchored to the bar, point " .. i)
        assertTrue(math.abs(tonumber(y) or 0) <= h, what .. ": within the bar's height, point " .. i)
    end
    local ownH = rawget(region, "__h")
    assertTrue(ownH == nil or ownH <= h, what .. ": no taller than the bar (" .. tostring(ownH) .. ")")
end

test("tooltip bar: every region it draws is painted and inside the bar at heights 4 to 20", function()
    -- red under: a region shown with no texture or color, or sized or anchored off the bar.
    withWindow(function()
        for _, key in ipairs({ "leatherworking", "fishing" }) do   -- fishing: the lure's temp bonus
            for h = 4, 20 do
                set("bars.tooltipHeight", h)
                NS.RowTooltip.Show(windowRow(key))
                local bar = NS.RowTooltip.Bar()
                assertEqual(bar.style.height, h, key .. " at " .. h .. ": the bar's height")
                for i, region in ipairs({ bar:GetRegions() }) do
                    local what = ("%s at %d px, region %d"):format(key, h, i)
                    if region:IsShown() then
                        if region:GetObjectType() == "Texture" then
                            assertTrue(painted(region), what .. ": a shown texture is painted")
                        end
                        if region ~= bar.timer then insideBar(region, bar, h, what) end
                    end
                end
                for _, child in ipairs({ bar:GetChildren() }) do
                    assertFalse(child:IsShown(), key .. " at " .. h .. ": no LSM border frame under the Solid border")
                end
                M.GameTooltip:Hide()
            end
        end
    end)
end)

test("tooltip bar: hidden once GameTooltip is cleared for another owner, never carried into the broker tooltip", function()
    -- red under: the bar hidden by GameTooltip's OnHide only. SetOwner on a shown tooltip clears it
    -- (OnTooltipCleared) without hiding it, as the client does.
    withWindow(function()
        local tip = M.GameTooltip
        rawset(tip, "SetOwner", function(self) self:__fire("OnTooltipCleared") end)
        local ok, err = pcall(function()
            -- Apply skin to the tooltip off (FB-13): the feed draws on the shared GameTooltip.
            NS.SetByPath("tooltips.ldb.style", "classic")   -- round 6: the Classic style draws on GameTooltip
            NS.SetByPath("broker.tooltip.skin", false)
            NS.RowTooltip.Show(windowRow("leatherworking"))
            local bar = NS.RowTooltip.Bar()
            tip:Show()
            assertTrue(bar:IsShown(), "the row tooltip draws its bar")
            NS.Broker.OnEnter(M.UIParent)   -- the feed's cell takes the shown tooltip
            assertFalse(bar:IsShown(), "the row tooltip's bar went with its content")
            NS.Broker.HideTooltip()
            -- On (the default): the feed draws on its own frame, never under the row tooltip's bar.
            NS.SetByPath("broker.tooltip.skin", true)
            assertTrue(NS.Broker.Tip() ~= tip, "the skinned feed has its own tooltip frame")
        end)
        NS.Broker.HideTooltip()
        NS.SetByPath("broker.tooltip.skin", true)
        NS.SetByPath("tooltips.ldb.style", NS.defaults.profile.tooltips.ldb.style)
        rawset(tip, "SetOwner", nil)
        if not ok then error(err, 0) end
    end)
end)

test("tooltip bar: a row tooltip with no bar line leaves no bar from the last one", function()
    -- red under: RT.Show placing the bar only when a line asks for it, and never hiding it.
    withWindow(function()
        NS.RowTooltip.Show(windowRow("leatherworking"))
        assertTrue(NS.RowTooltip.Bar():IsShown(), "a learned row's tooltip has the bar")
        local unlearned
        for _, row in ipairs(NS.MainWindow.Rows()) do
            if row.entry and row.entry.learned == false then unlearned = row break end
        end
        assertTrue(unlearned ~= nil, "the sample character has an unlearned row")
        NS.RowTooltip.Show(unlearned)   -- straight on, GameTooltip never hidden in between
        assertFalse(NS.RowTooltip.Bar():IsShown(), "an unlearned row's tooltip draws no bar")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- FB-10: the border is off by default; a skin's real style follows its companion
-- ---------------------------------------------------------------------------------------------

test("bar border: off by default in the profile and on its schema row", function()
    assertFalse(NS.defaults.profile.bars.border, "defaults/Profile.lua")
    local row
    for _, r in ipairs(NS.Schema) do if r.path == "bars.border" then row = r end end
    assertTrue(row ~= nil, "the Show border row")
    assertFalse(row.default, "the Show border row's default agrees")
    withWindow(function()
        assertEqual(NS.Bar.ResolveStyle("row").border, nil, "no border color resolved")
        local bar = windowRow("leatherworking").bar
        for _, e in ipairs(bar.edges) do assertFalse(e:IsShown(), "a window bar draws no edge") end
    end)
end)

test("bar border: off under the default skin's None; a real skin style wins only while its companion is on", function()
    -- skinning-§6: a skin's None defers to Show border; a real style wins while the companion is
    -- on, and the companion off hands Show border back. red under: Off ignored under None, or the
    -- companion off still drawing the skin's edge.
    withWindow(function()
        assertEqual(NS.Bar.ResolveStyle("row").border, nil, "the shipped skin (None): Show border off is off")
    end)
    local S = NS.Skin
    local prev = rawget(S, "BarBorder")
    local follows
    rawset(S, "BarBorder", function(style, show, size, fromSkin)
        follows = fromSkin
        if fromSkin then return "Blizzard Tooltip", true, 2 end
        return style, show, size
    end)
    local ok, err = pcall(withWindow, function()
        -- The companion defaults OFF (the owner's ruling, an options-ui-§16 deviation).
        assertEqual(NS.Bar.ResolveStyle("row").border, nil, "the companion off by default: Show border off is off")
        assertFalse(follows, "the companion is off by default")
        set("bars.borderStyleFromSkin", true)
        assertTrue(NS.Bar.ResolveStyle("row").border ~= nil, "opted in: a skin stating a real style wins (skinning-§6)")
        set("bars.borderStyleFromSkin", false)
        assertEqual(NS.Bar.ResolveStyle("row").border, nil, "the companion off again: Show border off is off")
    end)
    rawset(S, "BarBorder", prev)
    if not ok then error(err, 0) end
end)

-- ---------------------------------------------------------------------------------------------
-- FB-11: the trainer's name color
-- ---------------------------------------------------------------------------------------------

local function nameColor()
    local P = NS.TrainerPopup
    P.Show("fistWeapons")
    local list = P.Trainers()
    assertTrue(#list > 0, "the popup lists trainers")
    local card = P.Cards()[1]
    assertEqual(card.name:GetText(), list[1].name, "the first card names its trainer")
    return M.__paint(card.name).textColor, M.__paint(card.where).textColor
end

test("trainer popup: the trainer's name wears the skin's accent by default, apart from the other text", function()
    withWindow(function()
        local name, where = nameColor()
        local accent = NS.Bar.Color("text.accent")
        assertTrue(accent ~= nil, "the skin answers an accent")
        for i = 1, 3 do assertNear(name[i], accent[i], 1e-6, "the name's channel " .. i) end
        local same = true
        for i = 1, 3 do same = same and math.abs(name[i] - where[i]) < 1e-6 end
        assertFalse(same, "the name stands apart from the place line")
        NS.TrainerPopup.Hide()
    end)
end)

test("trainer popup: the name's swatch draws once Use the skin's color is off, the class color through its companion", function()
    withWindow(function()
        set("trainers.nameColorFromSkin", false)
        set("trainers.nameColor", { 0.1, 0.8, 0.3, 0.9 })
        local name = nameColor()
        assertNear(name[1], 0.1, 1e-6, "red")
        assertNear(name[2], 0.8, 1e-6, "green")
        assertNear(name[4], 0.9, 1e-6, "the stored alpha")
        set("trainers.useClassColorName", true)
        local r = M.LibStub("LibKa0s-Core-1.0").ClassColor("player") or 0.1
        assertNear(nameColor()[1], r, 1e-6, "the class color")
        assertNear(nameColor()[4], 0.9, 1e-6, "the stored alpha still applies")
        set("trainers.nameColorFromSkin", true)
        local accent = NS.Bar.Color("text.accent")
        assertNear(nameColor()[1], accent[1], 1e-6, "back on the skin's accent")
        NS.TrainerPopup.Hide()
    end)
end)

test("trainer popup: a changed name color reaches an open popup at once", function()
    withWindow(function()
        nameColor()
        set("trainers.nameColorFromSkin", false)
        set("trainers.nameColor", { 0.2, 0.3, 0.4, 1 })
        local c = M.__paint(NS.TrainerPopup.Cards()[1].name).textColor
        assertNear(c[3], 0.4, 1e-6, "the open popup repainted")
        NS.TrainerPopup.Hide()
    end)
end)
