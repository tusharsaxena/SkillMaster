local _, NS = ...
-- settings/Tooltips.lua — the Tooltips page (owner feedback round 4): each tooltip's own look, apart
-- from the window's bars on the Bars page.
--
--   Main window tooltip   the tooltip of a main window or detached row (modules/RowTooltip.lua):
--                         bar width, bar height, row height, font size
--   LDB tooltip           the broker feed's tooltip (modules/Broker.lua, modules/BrokerPanel.lua):
--                         Tooltip style, Open a row from (Main window style, round 7, R7-6), width
--                         and height (Main window style), Apply skin to the
--                         tooltip, bar width, bar height, row height, font size (Classic style)
--
-- The heights keep their paths (bars.tooltipHeight / tooltipRowHeight, bars.miniHeight /
-- brokerRowHeight) and the skin row its own (broker.tooltip.skin): only their rows moved here, so no
-- stored value needed a migration. The widths and font sizes are new (tooltips.row.*, tooltips.ldb.*).
-- The fill, background, border and colors still follow the Bars page.
--
-- The main window tooltip is the game's shared GameTooltip: its font size reaches Skill Master's own
-- lines only, and each goes back to its own size when the tooltip clears (NS.Chrome.TooltipFontSize).
local L = NS.L
local PB, PT, PBR = NS.defaults.profile.bars, NS.defaults.profile.tooltips, NS.defaults.profile.broker
local PAGE = "tooltips"
local ROW, LDB = L["Main window tooltip"], L["LDB tooltip"]

local function px(path, group, label, desc, default, lo, hi)
    return { path = path, page = PAGE, group = group, type = "number", label = label, desc = desc,
             default = default, min = lo, max = hi, step = 1, commitOn = "change" }
end

local function closeLdb()
    if NS.Broker and NS.Broker.HideTooltip then NS.Broker.HideTooltip() end
end

NS.RegisterSchemaRows(NS.Live({
    px("tooltips.row.barWidth", ROW, L["Bar width (px)"],
        L["Width of the bar in the tooltip of a main window or detached row."], PT.row.barWidth, 80, 400),
    px("bars.tooltipHeight", ROW, L["Bar height (px)"],
        L["Height of the bar in the tooltip of a main window or detached row."], PB.tooltipHeight, 4, 20),
    px("bars.tooltipRowHeight", ROW, L["Row height (px)"],
        L["Height of the bar's line in the tooltip of a main window or detached row. Never shorter than its bar."],
        PB.tooltipRowHeight, 10, 40),
    px("tooltips.row.fontSize", ROW, L["Font size"],
        L["Size of Skill Master's lines in the tooltip of a main window or detached row. The game's other tooltips keep theirs."],
        PT.row.fontSize, 8, 20),
}))

-- The LDB tooltip's style (round 6, R6-10): Main window draws it as the main window, at its own Width
-- and Height; Classic is the tooltip lines with mini bars, and only it reads the skin switch, the bar
-- width, the row height and the font size below (each dimmed in the other style).
local function classic() return NS.GetSetting("tooltips.ldb.style") == "classic" end
local function windowStyle() return not classic() end

local function onlyIn(row, off)
    row.disabledIf = off
    return row
end

local ldbRows = NS.Live({
    { path = "tooltips.ldb.style", page = PAGE, group = LDB, type = "string", default = PT.ldb.style,
      label = L["Tooltip style"],
      desc = L["Main window draws the LDB tooltip as the main window: its block headers, rows, bars and fonts, the window's collapse, sort and filter, at the Width and Height below. Classic is the tooltip lines with mini bars."],
      values = { { value = "window", text = L["Main window"] }, { value = "classic", text = L["Classic"] } } },
    -- Round 7, R7-6: the Main window style's rows open from the go icon (the default) or the whole row.
    onlyIn({ path = "tooltips.ldb.openFrom", page = PAGE, group = LDB, type = "string", default = PT.ldb.openFrom,
      label = L["Open a row from"],
      desc = L["Main window style: what a left click on an LDB tooltip row opens from. The go icon opens it as the main window's go icon does (a profession window, the character panel, the trainers), and the rest of the row only links (shift-click) and opens the row menu (right-click). The whole row opens it from anywhere on the row. Classic style rows always open from the whole row."],
      values = { { value = "icon", text = L["The go icon"] }, { value = "row", text = L["The whole row"] } } },
      classic),
    onlyIn(px("tooltips.ldb.width", LDB, L["Width (px)"],
        L["Width of the LDB tooltip in the Main window style, counted as Layout > Window width is."],
        PT.ldb.width, 300, 800), classic),
    onlyIn(px("tooltips.ldb.height", LDB, L["Height (px)"],
        L["The tallest the LDB tooltip grows in the Main window style; past it, it scrolls (the mouse wheel or its scroll bar)."],
        PT.ldb.height, 200, 1000), classic),
    onlyIn({ path = "broker.tooltip.skin", page = PAGE, group = LDB, type = "bool",
      default = PBR.tooltip.skin, label = L["Apply skin to the tooltip"],
      desc = L["Draw the feed's tooltip in the skin's backdrop, border and fonts. Off, it is the game's plain tooltip. Classic style only: the Main window style always wears the skin."] },
      windowStyle),
    onlyIn(px("tooltips.ldb.barWidth", LDB, L["Bar width (px)"],
        L["Width of the bars in the LDB (broker) tooltip, Classic style. The tooltip widens to fit them; a wide value column can stretch them further."],
        PT.ldb.barWidth, 60, 400), windowStyle),
    px("bars.miniHeight", LDB, L["Bar height (px)"],
        L["Height of the bars in the LDB (broker) tooltip's Classic style, and in the Journal's Alts tab."], PB.miniHeight, 3, 16),
    onlyIn(px("bars.brokerRowHeight", LDB, L["Row height (px)"],
        L["Height of one skill or stat line in the LDB (broker) tooltip, Classic style. Never shorter than its bar."],
        PB.brokerRowHeight, 10, 40), windowStyle),
    onlyIn(px("tooltips.ldb.fontSize", LDB, L["Font size"],
        L["Size of the text in the LDB (broker) tooltip, Classic style. The Main window style takes the window's fonts."],
        PT.ldb.fontSize, 8, 20), windowStyle),
})
-- Any LDB look change closes the open tooltip, so the next hover draws it new.
for _, r in ipairs(ldbRows) do
    local live = r.onChange
    r.onChange = function(...)
        if live then live(...) end
        closeLdb()
    end
end
NS.RegisterSchemaRows(ldbRows)

NS.RegisterSchemaPage(PAGE, L["Tooltips"], {
    defaultsTooltip = L["Restore every Tooltips setting on this profile to its default."],
})
