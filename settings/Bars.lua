local _, NS = ...
-- settings/Bars.lua — the Bars page (design §6.6, mockup "Options"): every look the bar widget
-- (modules/Bar.lua) draws, with the live preview bar pinned above the strip.
--
--   Bar      -- Size -- the five heights          -- Fill -- the composed bar block (flat mode's color)
--            -- Background -- the swatch pair     -- Border -- the composed border block
--   Colors   the color mode, then the category and bonus palette (a palette: no class companion,
--            options-ui-§17's exemption), following the skin under one companion
--   Text     -- Content -- template and anchor    -- Font -- the composed font block
--   Marks    the tier ticks, the stat markers, the timer and the spark
--
-- Every row's onChange is NS.ApplyLook (LAYOUT_CHANGED): the window, the detached blocks, the
-- journal and the preview restyle at once. The composed blocks start on the skin (skinning-§6):
-- each `*FromSkin` companion defaults true in defaults/Profile.lua and in the composer.
local H = NS.Helpers
local L = NS.L
local P = NS.defaults.profile.bars
local PAGE = "bars"
local BAR, COLORS, TEXT, MARKS = L["Bar"], L["Colors"], L["Text"], L["Marks"]

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
    px("bars.height", BAR, SIZE, L["Bar height (px)"], L["Height of a row's bar in the main window."], 6, 30),
    px("bars.rowHeight", BAR, SIZE, L["Row height (px)"], L["Height of one skill or stat row, its bar included."], 14, 40),
    px("bars.compactHeight", BAR, SIZE, L["Detached bar height (px)"],
        L["Height of a bar in a detached block."], 4, 24),
    px("bars.tooltipHeight", BAR, SIZE, L["Tooltip bar height (px)"],
        L["Height of the bar inside a row's tooltip."], 4, 20),
    px("bars.miniHeight", BAR, SIZE, L["Mini bar height (px)"],
        L["Height of the small bars in the Journal's Alts tab and the broker tooltips."], 3, 16),
    row({ path = "bars.fillDirection", group = BAR, subgroup = L["Fill"], type = "string", default = P.fillDirection,
          label = L["Fill direction"], desc = L["The edge every bar fills from."],
          values = { { value = "LEFT", text = L["Left to right"] }, { value = "RIGHT", text = L["Right to left"] } } }),
}

local classColor = { source = "player" }

add(rows, H.BarGroup({
    prefix = "bars.", page = PAGE, group = BAR, subgroup = L["Fill"], fromSkin = true,
    classColor = classColor,
    tooltips = { barColor = L["The fill color while Color mode (Colors) is Flat."] },
    defaults = { barTexture = P.barTexture, barAlpha = P.barAlpha, barColor = P.barColor,
                 useClassColorBar = P.useClassColorBar, barTextureFromSkin = P.barTextureFromSkin },
    extra = { fromSkin("bars.barColorFromSkin", L["Use the skin's color"], L["Bar color"]) },
}))

add(rows, H.ColorPair({
    prefix = "bars.", page = PAGE, group = BAR, subgroup = L["Background"],
    key = "bgColor", companionKey = "useClassColorBg", label = L["Background color"],
    classColor = classColor,
    defaults = { bgColor = P.bgColor, useClassColorBg = P.useClassColorBg },
    extra = { fromSkin("bars.bgColorFromSkin", L["Use the skin's color"], L["Background color"]) },
}))

add(rows, H.BorderGroup({
    prefix = "bars.", page = PAGE, group = BAR, subgroup = L["Border"], show = true, fromSkin = "bar",
    classColor = classColor, keys = { borderShow = "border" },
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
    swatch("other", L["Defense, lockpicking and riding"], L["Fill of the Other block's bars (By category)."]),
    swatch("stats", L["Stats"], L["Fill of a stat's bar (By category)."]),
    swatch("bonusTemp", L["Temporary bonus"], L["The bonus segment of a temporary bonus: a lure, a buff."]),
    swatch("bonusPerm", L["Permanent bonus"], L["The bonus segment of a permanent bonus: a racial, an item."]),
})

-- Text: content first (options-ui-§16, U-10d), then the font block. Rows show (bars.rowDisplay,
-- feedback round 1 FB-3) is one setting for skill and stat rows alike. The bar text is a presets
-- dropdown, each preset named by what it draws for the preview's Fishing 107 +25 / 150, plus
-- "Custom..." and its box (NS.TemplateRows, feedback round 1 FB-2).
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
    desc = L["What a skill's bar says, shown here for 107 +25 / 150. Custom... writes your own. A stat's bar shows its value."],
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
    mark("ticks", L["Rank tier ticks"], L["A tick on a profession's bar at each rank's cap (75, 150, 225)."]),
    mark("markers", L["Threshold markers"], L["A stat's marks: the hit cap, the resist cap, crit immunity."]),
    mark("timer", L["Expiry timer"], L["The time a temporary bonus has left, beside its bar."]),
    mark("spark", L["Spark"], L["A thin line riding the end of the fill."]),
})

NS.RegisterSchemaRows(NS.Live(rows))

-- ---------------------------------------------------------------------------------------------
-- The live preview (the mockup's): Fishing 107 +25 / 150 with a lure's 4:12, drawn by NS.Bar in
-- the page's pinned header frame, restyled on every LAYOUT_CHANGED while it exists.
-- ---------------------------------------------------------------------------------------------
NS.OptionsPreview = NS.OptionsPreview or {}
local Preview = NS.OptionsPreview
Preview.VALUES = { value = 107, max = 150, bonus = 25, bonusKind = "temp", ticks = { 75, 150, 225, 300 } }
-- The row the preview stands for, as NS.Rows.FillColor reads it: the fill follows Color mode, the
-- palette (Fishing is a secondary skill) and Bar > Fill exactly as the window's Fishing row does.
Preview.ENTRY = { key = "fishing", category = "secondary", rank = 107, max = 150 }
Preview.EXPIRES_IN = 252   -- 4:12
local HEADER_H, NAME_W = 44, 110

function Preview.Refresh()
    local bar = Preview.bar
    if not bar then return end
    bar:ApplyStyle(NS.Bar.ResolveStyle("row"))
    local v = {}
    for k, x in pairs(Preview.VALUES) do v[k] = x end
    v.color = NS.Rows.FillColor(Preview.ENTRY)
    bar:SetValues(v)
    -- The lure's time left, drawn still: a preview arms no OnUpdate (nothing may run while the
    -- page is closed or the addon stood down).
    bar.timer:SetText(NS.Bar.FormatTimer(Preview.EXPIRES_IN))
    bar.timer:SetShown(bar.style.showTimer ~= false)
end

local function buildPreview(_, frame)
    if not frame.skmPreview then
        local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", frame, "LEFT", 4, -4)
        name:SetWidth(NAME_W)
        name:SetJustifyH("LEFT")
        name:SetText(L["Fishing"])
        local bar = NS.Bar.Create(frame, "row")
        bar:SetPoint("LEFT", frame, "LEFT", NAME_W + 8, -4)
        bar:SetPoint("RIGHT", frame, "RIGHT", -(NS.Bar.TIMER_W + 8), -4)
        frame.skmPreview = { name = name, bar = bar }
    end
    Preview.bar = frame.skmPreview.bar
    Preview.Refresh()
end
Preview.Build = buildPreview   -- the skin-switch test builds the preview on a frame of its own

if NS.NewBusTarget then
    Preview.events = NS.NewBusTarget()
    if Preview.events then Preview.events:RegisterMessage(NS.MSG.LAYOUT_CHANGED, Preview.Refresh) end
end

NS.RegisterSchemaPage(PAGE, L["Bars"], {
    header = { height = HEADER_H, build = buildPreview },
    defaultsTooltip = L["Restore every Bars setting on this profile to its default."],
})
