local _, NS = ...
-- settings/BrokerPins.lua — the Broker page's Pins tab (GitHub issue #11; item SMW-06 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md): each broker's pins, in the family order, as
-- one boxed list (settings/BoxList.lua). A feed's heading, then its pins in their order, each with a move
-- up, a move down and an unpin mark; a feed with none says so. A row's menu in its window pins an element
-- (modules/Interact.lua); this tab only orders and removes.
--
-- The pins are this character's (char.pins, modules/Pins.lua, its one writer): no schema row and no
-- Defaults, as a window's position is not one. Every write redraws the tab while it is open (NS.Pins.onChange).
--
-- NS.OptionsBrokerPins.Model() -> { { family, title, pins = { { key, label, index, first, last } } } }
-- NS.OptionsBrokerPins.Render(ctx) / .tab (the page's tab entry, settings/Broker.lua)

local L = NS.L
local H = NS.Helpers

local Page = {}
NS.OptionsBrokerPins = Page

Page.KEY = L["Pins"]

--- What the tab draws: every family's broker, in the family order, with this character's pins on it.
function Page.Model()
    local out = {}
    for fid, fam in NS.EachFamily() do
        local pins, stored = {}, NS.Pins.Stored(fid)
        for i, key in ipairs(stored) do
            pins[i] = { key = key, label = NS.Pins.Label(fid, key), index = i, first = i == 1, last = i == #stored }
        end
        out[#out + 1] = { family = fid, title = fam.feed.label, pins = pins }
    end
    return out
end

local function redraw()
    local ctx = Page.ctx
    if ctx and H.RefreshPanel then H.RefreshPanel(ctx, true) end
end
NS.Pins.onChange = redraw

local function mark(icon, title, tooltip, enabled, fn)
    return { image = NS.Icon and NS.Icon(icon), title = title, tooltip = tooltip, dimmed = not enabled,
             onClick = enabled and fn or nil }
end

local function pinRow(scroll, list, fid, p)
    NS.OptionsList.Row(scroll, list, {
        text = ("%d. %s"):format(p.index, p.label),
        actions = {
            mark("chevron-up", L["Move up"], L["Show this pin earlier in the feed's text and tooltip."],
                not p.first, function() NS.Pins.Move(fid, p.index, p.index - 1) end),
            mark("chevron-down", L["Move down"], L["Show this pin later in the feed's text and tooltip."],
                not p.last, function() NS.Pins.Move(fid, p.index, p.index + 1) end),
            mark("clear", L["Unpin"], L["Take this pin off the broker."], true,
                function() NS.Pins.Remove(fid, p.key) end),
        },
    })
end

--- Draw the tab: the hint, then each broker's heading and its pins.
function Page.Render(ctx)
    Page.ctx = ctx
    local scroll = H.EnsureScroll(ctx)
    if not scroll then return end
    H.TextRow(ctx, L["Each broker shows its own pins, up to %d, in this order: {pinned} joins them, {pinned1} to {pinned5} show one each, and the tooltip lists them first. Pin a row from its menu in its window (right-click). Pins are kept per character."]:format(NS.Pins.MAX))
    if H.AddSpacer then H.AddSpacer(scroll, 4) end
    local list = NS.OptionsList.Begin(ctx, {})
    for _, feed in ipairs(Page.Model()) do
        NS.OptionsList.Header(scroll, list, { text = feed.title, heading = true })
        if #feed.pins == 0 then
            NS.OptionsList.Row(scroll, list, { text = L["Nothing pinned."], dimmed = true })
        end
        for _, p in ipairs(feed.pins) do pinRow(scroll, list, feed.family, p) end
    end
    NS.OptionsList.Finish(list, scroll)
end

Page.tab = { key = Page.KEY, label = Page.KEY, tooltip = L["Each broker's pins: their order, and unpin."],
             render = function(ctx) Page.Render(ctx) end }
