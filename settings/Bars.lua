local _, NS = ...
-- settings/Bars.lua — the Bars page (design §6.6, mockup "Options"): every look the bar widget
-- (modules/Bar.lua) draws. No preview bar (owner feedback round 4): the open window is the preview.
--
--   Bar      -- Size -- the six heights           -- Fill -- the composed bar block (flat mode's color)
--            -- Background -- the swatch pair     -- Border -- the composed border block
--   Colors   the color mode, then the category and bonus palette (a palette: no class companion,
--            options-ui-§17's exemption), following the skin under one companion
--   Text     -- Content -- template and anchor    -- Font -- the composed font block
--   Marks    the rank tier shades (By category only), the stat markers, the timer and the spark
--
-- Every row's onChange is NS.ApplyLook (LAYOUT_CHANGED): the window, the detached blocks and the
-- journal restyle at once. The composed blocks start on the skin (skinning-§6):
-- each `*FromSkin` companion defaults true in defaults/Profile.lua and in the composer.
local H = NS.Helpers
local L = NS.L
local P = NS.defaults.profile.bars
local PAGE = "bars"
local BAR, COLORS, TEXT, MARKS, ICONS = L["Bar"], L["Colors"], L["Text"], L["Marks"], L["Icons"]
local PI = NS.defaults.profile.icons

local function row(t)
    t.page = PAGE
    return t
end

local function px(path, group, subgroup, label, desc, lo, hi)
    return row({ path = path, group = group, subgroup = subgroup, type = "number", label = label,
                 desc = desc, default = P[path:match("[^.]+$")], min = lo, max = hi, step = 1 })
end

--- The companion of a swatch or the shadow, for a composed block's `extra` (skinning-§6).
local function fromSkin(path, label, governs)
    return { path = path, page = PAGE, type = "bool", label = label, default = true,
             desc = L["Draw this in the skin's look. %s is not read while this is on."]:format(governs) }
end

local function add(rows, block)
    for _, r in ipairs(block) do rows[#rows + 1] = r end
end

local SIZE = L["Size"]
local rows = {
    px("bars.height", BAR, SIZE, L["Bar height (px)"], L["Height of a row's bar in the main window and the detached blocks."], 6, 30),
    px("bars.rowHeight", BAR, SIZE, L["Row height (px)"], L["Height of one skill or stat row, its bar included, in the main window and the detached blocks."], 14, 40),
    -- The four tooltip sizes moved to the Tooltips page (settings/Tooltips.lua, owner feedback round 4).
    row({ path = "bars.fillDirection", group = BAR, subgroup = L["Fill"], type = "string", default = P.fillDirection,
          label = L["Fill direction"], desc = L["The edge every bar fills from."],
          values = { { value = "LEFT", text = L["Left to right"] }, { value = "RIGHT", text = L["Right to left"] } } }),
}

local classColor = { source = "player" }

add(rows, H.BarGroup({
    prefix = "bars.", page = PAGE, group = BAR, subgroup = L["Fill"], fromSkin = true,
    classColor = classColor,
    tooltips = { barColor = L["The fill color while Color mode (Colors) is Flat. Not read while Use the skin's color is on."] },
    defaults = { barTexture = P.barTexture, barAlpha = P.barAlpha, barColor = P.barColor,
                 useClassColorBar = P.useClassColorBar, barTextureFromSkin = P.barTextureFromSkin },
    extra = { fromSkin("bars.barColorFromSkin", L["Use the skin's color"], L["Bar color"]) },
}))

add(rows, H.ColorPair({
    prefix = "bars.", page = PAGE, group = BAR, subgroup = L["Background"],
    key = "bgColor", companionKey = "useClassColorBg", label = L["Background color"],
    classColor = classColor,
    tooltips = { bgColor = L["The color behind the fill. Not read while Use the skin's color is on."] },
    defaults = { bgColor = P.bgColor, useClassColorBg = P.useClassColorBg },
    extra = { fromSkin("bars.bgColorFromSkin", L["Use the skin's color"], L["Background color"]) },
}))

add(rows, H.BorderGroup({
    prefix = "bars.", page = PAGE, group = BAR, subgroup = L["Border"], show = true, fromSkin = "bar",
    classColor = classColor, keys = { borderShow = "border" },
    tooltips = { borderColor = L["The border's color. Not read while Use the skin's color is on."] },
    defaults = { borderShow = P.border, borderStyle = P.borderStyle, borderSize = P.borderSize,
                 borderColor = P.borderColor, useClassColorBorder = P.useClassColorBorder,
                 borderStyleFromSkin = P.borderStyleFromSkin },
    extra = { fromSkin("bars.borderColorFromSkin", L["Use the skin's color"], L["Border color"]) },
}))

-- Colors: the mode, then the palette. A palette identifies a category, so no class companion.
local function swatch(key, label, desc)
    return row({ path = "bars.colors." .. key, group = COLORS, subgroup = L["Palette"], type = "color",
                 label = label, desc = desc, default = P.colors[key] })
end

rows[#rows + 1] = row({
    path = "bars.colorMode", group = COLORS, subgroup = L["Color mode"], type = "string", default = P.colorMode,
    label = L["Color mode"],
    desc = L["How a bar's fill is colored: by its category, by progress to its cap, by the chance of a skill-up, or one flat color (Bar > Fill)."],
    values = {
        { value = "category", text = L["By category"] }, { value = "progress", text = L["By progress"] },
        { value = "likelihood", text = L["By skill-up chance"] }, { value = "flat", text = L["Flat"] },
    },
})
rows[#rows + 1] = row({
    path = "bars.colors.fromSkin", group = COLORS, subgroup = L["Palette"], type = "bool", solo = true,
    default = P.colors.fromSkin, label = L["Use the skin's colors"],
    desc = L["Draw the category and bonus colors in the skin's own. The swatches below are not read while this is on."],
})
add(rows, {
    swatch("primary", L["Primary professions"], L["Fill of a primary profession's bar (By category)."]),
    swatch("secondary", L["Secondary skills"], L["Fill of a secondary skill's bar (By category)."]),
    swatch("weapon", L["Weapon skills"], L["Fill of a weapon skill's bar (By category)."]),
    swatch("other", L["Other skills"], L["Fill of the Other block's bars (By category)."]),
    swatch("stats", L["Stats"], L["Fill of a stat's bar (By category)."]),
    swatch("bonusTemp", L["Temporary bonus"], L["The bonus segment of a temporary bonus: a lure, a buff."]),
    swatch("bonusPerm", L["Permanent bonus"], L["The bonus segment of a permanent bonus: a racial, an item."]),
})


-- Text: content first (options-ui-§16, U-10d), then the font block. Rows show (bars.rowDisplay,
-- feedback round 1 FB-3) is one setting for skill and stat rows alike. The bar text is a presets
-- dropdown, each preset named by what it draws for the preview's Fishing 107 +25 / 150, plus
-- "Custom" and its box (NS.TemplateRows, feedback round 1 FB-2).
local CONTENT = L["Content"]
rows[#rows + 1] = row({
    path = "bars.rowDisplay", group = TEXT, subgroup = CONTENT, type = "string", default = P.rowDisplay,
    label = L["Rows show"],
    desc = L["What every skill and stat row draws, in the window, the detached blocks and the broker tooltips: the bar and its value, the bar alone, or the value alone in the bar's place."],
    values = { { value = "both", text = L["Bar and value"] }, { value = "bar", text = L["Bar only"] },
               { value = "text", text = L["Value only"] } },
})

local function barPreset(value)
    return { value = value, text = NS.Bar.Text(107, 25, 150, value) }
end
add(rows, NS.TemplateRows({
    path = "bars.textTemplate", presetPath = "bars.textPreset", page = PAGE, group = TEXT, subgroup = CONTENT,
    default = P.textTemplate, label = L["Bar text"],
    desc = L["What a skill's bar says, shown here for 107 +25 / 150. Custom writes your own. A stat's bar shows its value."],
    boxDesc = L["Tokens: {rank}, {bonus} (+25), {max}, {pct} (percent of the cap) and {left} (points to the cap). Press Enter to apply."],
    presets = {
        barPreset(P.textTemplate),
        barPreset("{rank} / {max}"),
        barPreset("{rank} {bonus} / {max} ({pct}%)"),
        barPreset("{pct}%"),
        barPreset(L["{left} to go"]),
        barPreset("{rank}"),
    },
}))
rows[#rows + 1] = row({
    path = "bars.textAnchor", group = TEXT, subgroup = CONTENT, type = "string", default = P.textAnchor,
    label = L["Text position"], desc = L["Where the text sits on the bar."],
    values = { { value = "LEFT", text = L["Left"] }, { value = "CENTER", text = L["Center"] },
               { value = "RIGHT", text = L["Right"] } },
})
add(rows, H.FontGroup({
    prefix = "bars.", page = PAGE, group = TEXT, subgroup = L["Font"], fromSkin = true, flagsFromSkin = true,
    classColor = classColor,
    tooltips = { fontColor = L["The bar text's color. Not read while Use the skin's color is on."] },
    defaults = { font = P.font, fontSize = P.fontSize, fontColor = P.fontColor,
                 useClassColorFont = P.useClassColorFont, fontFlags = P.fontFlags,
                 fontShadow = P.fontShadow, fontFromSkin = P.fontFromSkin },
    extra = {
        fromSkin("bars.fontColorFromSkin", L["Use the skin's color"], L["Font color"]),
        fromSkin("bars.fontShadowFromSkin", L["Use the skin's shadow"], L["Font shadow"]),
    },
}))

local function mark(key, label, desc)
    return row({ path = "bars." .. key, group = MARKS, type = "bool", default = P[key], label = label, desc = desc })
end
add(rows, {
    mark("tierColors", L["Rank tier colors"],
        L["Draw a profession's bar to 300 whatever its cap, its fill split by rank tier: Apprentice to 75 in its category's color, then Journeyman, Expert and Artisan each a shade darker. Works only while Color mode (Colors) is By category."]),
    -- Two switches (owner feedback round 6, R6-4): thresholds off in the window, on in the row tooltip.
    mark("markersWindow", L["Thresholds in the window"],
        L["A stat's marks (the hit cap, the resist cap, crit immunity) on its bar in the main window, the detached and merged windows, the LDB tooltip and the journal."]),
    mark("markersTooltip", L["Thresholds in the row tooltip"],
        L["A stat's marks (the hit cap, the resist cap, crit immunity) on the bar and as lines in the tooltip shown when you hover a row."]),
    mark("timer", L["Expiry timer"], L["The time a temporary bonus has left, beside its bar."]),
    mark("spark", L["Spark"], L["A thin line riding the end of the fill."]),
})

-- Icons (feedback round 2): the rows' in-game icons in the window and the detached blocks. The
-- border is the composed block (options-ui-§16) on the icon family (fromSkin = "icon": its style and
-- thickness follow the skin's icon border while the companion is on); its color is the row's own
-- by default (Use the row's color), else the skin's, else the swatch.
local ICON = L["Icon"]
add(rows, {
    row({ path = "icons.show", group = ICONS, subgroup = ICON, type = "bool", default = PI.show,
          label = L["Show icons"], desc = L["Draw each row's in-game icon at its left end."] }),
    row({ path = "icons.size", group = ICONS, subgroup = ICON, type = "number", default = PI.size,
          min = 10, max = 28, step = 1, label = L["Icon size (px)"],
          desc = L["The icon's width and height, its border included. Never taller than the row."],
          disabledIf = function() return NS.GetSetting("icons.show") == false end }),
    row({ path = "icons.zoom", group = ICONS, subgroup = ICON, type = "number", default = PI.zoom,
          min = 0, max = 30, step = 1, label = L["Icon zoom (%)"],
          desc = L["How much of the art's edge is cropped away on each side. 7 trims the old icons' baked-in border."],
          disabledIf = function() return NS.GetSetting("icons.show") == false end }),
})
add(rows, H.BorderGroup({
    prefix = "icons.", page = PAGE, group = ICONS, subgroup = L["Border"], show = true, fromSkin = "icon",
    classColor = classColor, keys = { borderShow = "border" },
    tooltips = { borderColor = L["The icon border's color. Not read while Use the row's color or Use the skin's color is on."] },
    defaults = { borderShow = PI.border, borderStyle = PI.borderStyle, borderSize = PI.borderSize,
                 borderColor = PI.borderColor, useClassColorBorder = PI.useClassColorBorder,
                 borderStyleFromSkin = PI.borderStyleFromSkin },
    extra = {
        { path = "icons.borderColorFromRow", page = PAGE, type = "bool", label = L["Use the row's color"],
          default = PI.borderColorFromRow,
          desc = L["Edge each icon in its row's own color (its category, progress or skill-up chance, as Color mode says). Use the skin's color and Border color are not read while this is on."] },
        fromSkin("icons.borderColorFromSkin", L["Use the skin's color"], L["Border color"]),
    },
}))

-- Every slider on the page commits while it moves (throttled by the library), not only on release:
-- the open window restyles as it moves, and AceGUI's mouse wheel fires no release at all, so a
-- wheel-turned height was never written. (The page's pinned preview bar came off: owner feedback
-- round 4.)
for _, r in ipairs(rows) do
    if r.type == "number" and r.commitOn == nil then r.commitOn = "change" end
end

NS.RegisterSchemaRows(NS.Live(rows))

NS.RegisterSchemaPage(PAGE, L["Bars"], {
    defaultsTooltip = L["Restore every Bars setting on this profile to its default."],
})
