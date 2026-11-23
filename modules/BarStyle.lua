local addonName, NS = ...
-- modules/BarStyle.lua — Skill Master's settings for its data bars, resolved into a style for
-- LibKa0s-Widgets-1.0's Bar (LibKa0s#80, AD-80-SM). The bar itself is the library's: the skill and
-- stat rows, the detached blocks, the row tooltip, the Journal and the broker tooltip draw
-- `NS.Widgets.Bar(parent, NS.BarStyle.Opts(styleKey))` (or `AcquireBar` / `ReleaseBars` from a pool).
-- What stays here is what the library leaves to its host: the profile reads (Bars page), the class
-- color, the threshold switches and the tooltip line heights.
--
-- Interface:
--   NS.BarStyle.Resolve(styleKey) -> style      a W.BarStyle table; styleKey "row" | "compact" |
--                                                "tooltip" | "mini"
--   NS.BarStyle.Opts(styleKey) -> opts           { owner = this addon, style = Resolve(styleKey) }
--   NS.BarStyle.Color(v) -> color                a style slot (a token name or a color) as a color
--   NS.BarStyle.PlayerColor(key, token) / .Swatch(key, token, classKey) -> color
--   NS.BarStyle.ShowMarkers(styleKey) / .TooltipRowHeight(styleKey)
--
-- The colors that follow the skin are handed over as token NAMES (`sm.barFill`, `sm.bonusTemp`, ...),
-- so the widget resolves them against this addon's skin owner at paint time and a skin switch
-- repaints every bar with no call from here. The player's own picks (a swatch off its skin
-- companion, a class color) are handed over as colors. The bonus slots are remapped onto this
-- addon's owner tokens: `bonusTemp = "sm.bonusTemp"`, `bonusPerm = "sm.bonusPerm"`.

NS.BarStyle = {}
local BS = NS.BarStyle

local function profileBars()
    return (NS.db and NS.db.profile.bars) or NS.defaults.profile.bars
end

--- A style slot as a color: a table as given, a token name through the skin (NS.SkinColor).
function BS.Color(v)
    if type(v) == "table" then return v end
    if type(v) == "string" then return NS.SkinColor(v) end
    return nil
end

--- A player color (bars.colors[key]) unless the colors follow the skin, then `token`'s color.
function BS.PlayerColor(key, token)
    local colors = profileBars().colors
    if colors.fromSkin or type(colors[key]) ~= "table" then return NS.SkinColor(token) end
    return colors[key]
end

--- A composed swatch (options-ui-§16/§17): the class color while `classKey` is on, else the skin's
--- `token` while `<key>FromSkin` is on, else the stored `key` (FB-SM-02: class first).
function BS.Swatch(key, token, classKey)
    local p = profileBars()
    local class = NS.ClassFirst(p[key], p[classKey])
    if class then return class end
    if p[key .. "FromSkin"] ~= false or type(p[key]) ~= "table" then return NS.SkinColor(token) end
    return NS.WithClassColor(p[key], p[classKey])
end

-- The same two, for the widget's style: the token NAME while the slot follows the skin.
local function playerSlot(key, token)
    local colors = profileBars().colors
    if colors.fromSkin or type(colors[key]) ~= "table" then return token end
    return colors[key]
end

local function swatchSlot(key, token, classKey)
    local p = profileBars()
    local class = NS.ClassFirst(p[key], p[classKey])
    if class then return class end
    if p[key .. "FromSkin"] ~= false or type(p[key]) ~= "table" then return token end
    return NS.WithClassColor(p[key], p[classKey])
end

--- What the border draws: show, style, size, through the skin's bar border while its companion is
--- on (S.BarBorder), else the stored three. skinning-§6: a skin that states a real bar border style
--- wins over Show border while the companion is on, and the host never gates the stored toggle
--- ahead of the call (nor after it). Under a skin's None (Ka0s Default, WoW Forever) Show border
--- off is off; under a real style the companion off hands it back (feedback round 2, FB-10). The
--- style companion defaults OFF here (a documented options-ui-§16 deviation), so Show border off
--- is off under every skin until the player opts into the skin's border.
local function border(p)
    local show, style, size = p.border == true, p.borderStyle or "Solid", tonumber(p.borderSize) or 1
    local S = NS.Skin
    if S.IsEnabled() and S.BarBorder then
        local st, sh, sz = S.BarBorder(style, show, size, p.borderStyleFromSkin == true)
        if st ~= nil then style, show, size = st, sh, sz end
    end
    if style == "None" or (tonumber(size) or 0) <= 0 then show = false end
    return { show = show and true or false, style = style, size = tonumber(size) or 1,
             color = swatchSlot("borderColor", "sm.barBorder", "useClassColorBorder") }
end

local function font(p)
    return {
        size = p.fontSize, flags = p.fontFlags, shadow = p.fontShadow,
        shadowFromSkin = p.fontShadowFromSkin ~= false,
        face = p.fontFromSkin == false and NS.Chrome.Media("font", p.font) or nil,
        fromSkin = p.fontFromSkin ~= false,
    }
end

-- A detached block's compact bar is as tall as the main window's (the owner's ruling, feedback
-- round 2: no separate Detached bar height).
local HEIGHT_KEY = { row = "height", compact = "height", tooltip = "tooltipHeight", mini = "miniHeight" }

--- The height of one tooltip line carrying a bar: the stored row height `rowKey`, never shorter
--- than the bar `barKey` it carries. "tooltip" (the row tooltip) or "mini" (the LDB tooltip).
local ROW_KEY = { tooltip = { "tooltipRowHeight", "tooltipHeight" }, mini = { "brokerRowHeight", "miniHeight" } }
function BS.TooltipRowHeight(styleKey)
    local k, p = ROW_KEY[styleKey] or ROW_KEY.mini, profileBars()
    return math.max(tonumber(p[k[1]]) or 14, tonumber(p[k[2]]) or 0)
end

--- Whether a `styleKey` bar draws a stat's threshold markers (owner feedback round 6, R6-4): the row
--- tooltip's bar follows Bars > Marks > Thresholds in the row tooltip (on by default), every other
--- bar Thresholds in the window (off by default).
function BS.ShowMarkers(styleKey)
    local p = profileBars()
    if styleKey == "tooltip" then return p.markersTooltip ~= false end
    return p.markersWindow == true
end

--- The style one kind of bar draws with: the profile's sizes, switches, media and colors, each
--- following the skin where its companion says so, as a W.BarStyle table (it carries `key`, so
--- `bar:ApplyStyle` takes it whole). The border is decided here, so `border` is false while none
--- draws (false: the widget's own default would be `bar.border`); `borderFromSkin` stays off for the widget, which would only decide it again.
function BS.Resolve(styleKey)
    local p = profileBars()
    styleKey = HEIGHT_KEY[styleKey] and styleKey or "row"
    local edge = border(p)
    return NS.Widgets.BarStyle(styleKey, {
        height = p[HEIGHT_KEY[styleKey]] or p.height,
        fill = "sm.barFill",
        bg = swatchSlot("bgColor", "sm.barBg", "useClassColorBg"),
        border = edge.show and edge.color or false, borderShow = edge.show,
        borderStyle = edge.style, borderSize = edge.size, borderFromSkin = false,
        marker = "sm.marker", spark = p.spark and "sm.spark" or false,
        -- Rank tier colors works under Color mode By category alone (feedback round 2): the
        -- widget's segments, one shade per rank tier (W.BAR.SHADE).
        segmented = p.tierColors == true and (p.colorMode or "category") == "category",
        text = swatchSlot("fontColor", "sm.barText", "useClassColorFont"), timer = "sm.timer",
        bonusTemp = playerSlot("bonusTemp", "sm.bonusTemp"),
        bonusPerm = playerSlot("bonusPerm", "sm.bonusPerm"),
        -- The LibSharedMedia key: the widget fetches it, and an unknown one draws the skin's texture.
        texture = p.barTextureFromSkin == false and p.barTexture or nil,
        alpha = tonumber(p.barAlpha) or 1,
        font = font(p), fontSize = p.fontSize, textAnchor = p.textAnchor or "CENTER",
        reverse = p.fillDirection == "RIGHT",   -- fills from the right edge (Bars > Fill direction)
        template = p.textTemplate,
        showText = styleKey ~= "mini" and styleKey ~= "tooltip",
        showMarkers = BS.ShowMarkers(styleKey), showTimer = p.timer ~= false,
    })
end

--- The widget's opts for one kind of bar: this addon's skin owner and the resolved style.
function BS.Opts(styleKey) return { owner = addonName, style = BS.Resolve(styleKey) } end
