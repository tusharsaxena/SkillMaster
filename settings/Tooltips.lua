local _, NS = ...
-- settings/Tooltips.lua — the Tooltips page (owner feedback round 4): each tooltip's own look, apart
-- from the window's bars on the Bars page.
--
--   Main window tooltip   the tooltip of a main window or detached row (modules/RowTooltip.lua):
--                         bar width, bar height, row height, font size
--   LDB tooltip           the broker feed's tooltip (modules/Broker.lua): Apply skin to the
--                         tooltip, bar width, bar height, row height, font size
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

local ldbRows = NS.Live({
    { path = "broker.tooltip.skin", page = PAGE, group = LDB, type = "bool",
      default = PBR.tooltip.skin, label = L["Apply skin to the tooltip"],
      desc = L["Draw the feed's tooltip in the skin's backdrop, border and fonts. Off, it is the game's plain tooltip."] },
    px("tooltips.ldb.barWidth", LDB, L["Bar width (px)"],
        L["Width of the bars in the LDB (broker) tooltip. The tooltip widens to fit them; a wide value column can stretch them further."],
        PT.ldb.barWidth, 60, 400),
    px("bars.miniHeight", LDB, L["Bar height (px)"],
        L["Height of the bars in the LDB (broker) tooltip, and in the Journal's Alts tab."], PB.miniHeight, 3, 16),
    px("bars.brokerRowHeight", LDB, L["Row height (px)"],
        L["Height of one skill or stat line in the LDB (broker) tooltip. Never shorter than its bar."],
        PB.brokerRowHeight, 10, 40),
    px("tooltips.ldb.fontSize", LDB, L["Font size"],
        L["Size of the text in the LDB (broker) tooltip."], PT.ldb.fontSize, 8, 20),
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
