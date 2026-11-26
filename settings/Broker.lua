local _, NS = ...
-- settings/Broker.lua — the Broker page (design §6.7; feedback round 2, FB-12 and FB-13; SMW-05): each
-- family feed's text template (one subsection per feed, in the family order), the skill-up flash, and
-- each feed's tooltip sections, its family's blocks. A write repaints the feeds at once (NS.Broker.Refresh).
--
--   Feed            -- one subsection per feed: the template (presets + Custom)   -- Skill-up flash
--   Tooltip         -- one subsection per feed: a switch per section (the skin row is on the Tooltips page)
--   Pins            -- each feed's pins, reordered and removed (settings/BrokerPins.lua, SMW-06)
--
-- The template is a presets dropdown plus "Custom", which shows a text box taking the tokens
-- (NS.TemplateRows, settings/OptionsSetup.lua). A preset whose text carries a word goes through L;
-- the shipped default (defaults/Profile.lua) is matched as it is stored.
--
-- The tooltip's Hide sets (`broker.tooltip.hiddenSkills`, `broker.tooltip.hiddenStats`) are drawn
-- on the Rows page (settings/Rows.lua, round 5, R5-13), beside the main window's.
local L = NS.L
local P = NS.defaults.profile.broker
local PAGE = "broker"
local FEED, TOOLTIP = L["Feed"], L["Tooltip"]

local function refresh()
    if NS.Broker and NS.Broker.Refresh then NS.Broker.Refresh() end
end

local TOKENS = table.concat(NS.Template.TOKENS, ", ")
local DOT = " \194\183 "

local function preset(value, text) return { value = value, text = ("%s: %s"):format(text, value) } end

-- Each feed's presets, its shipped default first (defaults/Profile.lua broker.feeds.<family>.template).
-- The Professions feed keeps the one feed's presets, the four old feeds' best, over skills and stats
-- alike; the others start from {pinned}. The tokens: modules/Template.lua.
local function presetsFor(fid)
    local d = P.feeds[fid].template
    if fid == "professions" then
        return {
            preset(d, L["Pinned skill and session gains"]),
            preset("{pinned}", L["Pinned skill"]),
            preset("{lowestProf}" .. DOT .. "+{gains}", L["Lowest profession and session gains"]),
            preset("{last}" .. DOT .. "+{gains}", L["Last skill-up and session gains"]),
            preset("{equippedWeapon}" .. DOT .. "{skill:defense}", L["Equipped weapon and Defense"]),
            preset(L["{pinned} \194\183 {stat:crit} crit"], L["Pinned skill and crit"]),
            preset(L["{stat:crit} crit \194\183 {stat:speed}"], L["Crit and speed"]),
        }
    elseif fid == "skills" then
        return {
            preset(d, L["Pinned skill"]),
            preset("{equippedWeapon}" .. DOT .. "{skill:defense}", L["Equipped weapon and Defense"]),
            preset("{last}" .. DOT .. "+{gains}", L["Last skill-up and session gains"]),
        }
    elseif fid == "stats" then
        return { preset(d, L["Pinned stat"]), preset(L["{stat:crit} crit \194\183 {stat:speed}"], L["Crit and speed"]) }
    end
    return { preset(d, L["Pinned element"]) }
end

-- One Text subsection per feed, in the family order (SMW-05), then the skill-up flash.
local rows = {}
for _, fid in ipairs(NS.FAMILY_ORDER) do
    local base = "broker.feeds." .. fid .. "."
    for _, r in ipairs(NS.TemplateRows({
        path = base .. "template", presetPath = base .. "preset", page = PAGE, group = FEED,
        subgroup = NS.Families[fid].short, default = P.feeds[fid].template, label = L["Feed text"],
        presets = presetsFor(fid),
        desc = L["What the feed shows on your broker display. Custom writes your own."],
        boxDesc = L["The feed's own text. Tokens: %s. Press Enter to apply."]:format(TOKENS),
    })) do rows[#rows + 1] = r end
end
rows[#rows + 1] = {
    path = "broker.flashSeconds", page = PAGE, group = FEED, subgroup = L["Skill-up flash"], type = "number",
    default = P.flashSeconds, min = 0, max = 30, step = 1, label = L["Flash duration (seconds, 0 = off)"],
    desc = L["How long the feed shows the skill that just went up (^ Bows 81) in place of its text."],
}

-- ---------------------------------------------------------------------------------------------
-- Tooltip: the skin and the sections
-- ---------------------------------------------------------------------------------------------
-- "Apply skin to the tooltip" (broker.tooltip.skin) moved to the Tooltips page (owner feedback round 4).

-- Each feed's sections, its family's blocks (SMW-05), one subsection per feed in the family order. A
-- family whose blocks are not built yet has none.
local SECTION_LABEL = {
    primary = L["Primary professions"], secondary = L["Secondary skills"], weapon = L["Weapon skills"],
    other = L["Other skills"],
}
for _, fid in ipairs(NS.FAMILY_ORDER) do
    for _, id in ipairs(NS.Broker.FEEDS[fid].sections) do
        if NS.BlockDefs[id] then
            rows[#rows + 1] = {
                path = "broker.tooltip.sections." .. id, page = PAGE, group = TOOLTIP,
                subgroup = NS.Families[fid].short, type = "bool", default = P.tooltip.sections[id],
                label = SECTION_LABEL[id] or NS.BlockDefs[id].short,
                desc = L["Draw this section in the feed's tooltip."],
            }
        end
    end
end

NS.RegisterSchemaRows(NS.Live(rows, refresh))

NS.RegisterSchemaPage(PAGE, L["Broker"], {
    -- Each broker's pins (SMW-06): their order and unpin, per character (settings/BrokerPins.lua).
    tabs = { NS.OptionsBrokerPins.tab },
    beforeRender = NS.OptionsList.Cancel,
    defaultsTooltip = L["Restore every Broker setting on this profile to its default. Hidden tooltip rows stay hidden: the Rows page's Defaults shows them again."],
})
