local _, NS = ...
-- settings/Broker.lua — the Broker page (design §6.7; feedback round 2, FB-12 and FB-13): the Skill
-- Master feed's text template and skill-up flash, its tooltip's four sections, and the Skill Master
-- Stats feed's four (round 6, R6-9; its text is the pinned stat, no template). A write repaints the
-- feed at once (NS.Broker.Refresh).
--
--   Feed            -- Text -- the template (presets + Custom)   -- Skill-up flash
--   Tooltip         -- Sections -- one switch each (the skin row is on the Tooltips page)
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

-- The feed's presets, its shipped default first: the four old feeds' best, over skills and stats
-- alike. The tokens: modules/Template.lua.
local PRESETS = {
    preset(P.template, L["Pinned skill and session gains"]),
    preset("{pinned}", L["Pinned skill"]),
    preset("{lowestProf}" .. DOT .. "+{gains}", L["Lowest profession and session gains"]),
    preset("{last}" .. DOT .. "+{gains}", L["Last skill-up and session gains"]),
    preset("{equippedWeapon}" .. DOT .. "{skill:defense}", L["Equipped weapon and Defense"]),
    preset(L["{pinned} \194\183 {stat:crit} crit"], L["Pinned skill and crit"]),
    preset(L["{stat:crit} crit \194\183 {stat:speed}"], L["Crit and speed"]),
}

local rows = NS.TemplateRows({
    path = "broker.template", presetPath = "broker.preset", page = PAGE, group = FEED,
    subgroup = L["Text"], default = P.template, label = L["Feed text"], presets = PRESETS,
    desc = L["What the feed shows on your broker display. Custom writes your own."],
    boxDesc = L["The feed's own text. Tokens: %s. Press Enter to apply."]:format(TOKENS),
})
rows[#rows + 1] = {
    path = "broker.flashSeconds", page = PAGE, group = FEED, subgroup = L["Skill-up flash"], type = "number",
    default = P.flashSeconds, min = 0, max = 30, step = 1, label = L["Flash duration (seconds, 0 = off)"],
    desc = L["How long the feed shows the skill that just went up (^ Bows 81) in place of its text."],
}

-- ---------------------------------------------------------------------------------------------
-- Tooltip: the skin and the sections
-- ---------------------------------------------------------------------------------------------
-- "Apply skin to the tooltip" (broker.tooltip.skin) moved to the Tooltips page (owner feedback round 4).

-- The Skill Master feed's four sections, then the Skill Master Stats feed's four (round 6, R6-9).
local SECTION_LABEL = {
    primary = L["Primary professions"], secondary = L["Secondary skills"], weapon = L["Weapon skills"],
    other = L["Other skills"],
}
local function sectionRows(ids, subgroup, desc)
    for _, id in ipairs(ids) do
        rows[#rows + 1] = {
            path = "broker.tooltip.sections." .. id, page = PAGE, group = TOOLTIP, subgroup = subgroup,
            type = "bool", default = P.tooltip.sections[id], label = SECTION_LABEL[id] or NS.BlockDefs[id].short,
            desc = desc,
        }
    end
end
sectionRows(NS.Broker.SECTIONS, L["Sections"], L["Draw this section in the feed's tooltip."])
sectionRows(NS.Broker.STAT_SECTIONS, L["Stats feed sections"],
    L["Draw this stat block in the Skill Master Stats feed's tooltip."])

NS.RegisterSchemaRows(NS.Live(rows, refresh))

NS.RegisterSchemaPage(PAGE, L["Broker"], {
    defaultsTooltip = L["Restore every Broker setting on this profile to its default. Hidden tooltip rows stay hidden: the Rows page's Defaults shows them again."],
})
