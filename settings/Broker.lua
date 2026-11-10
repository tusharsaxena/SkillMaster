local _, NS = ...
-- settings/Broker.lua — the Broker page (design §6.7; feedback round 2, FB-12 and FB-13): the one
-- feed's text template and skill-up flash, and its tooltip: the skin, the five sections and one
-- Hide row per catalog skill and per stat. A write repaints the feed at once (NS.Broker.Refresh).
--
--   Feed            -- Text -- the template (presets + Custom)   -- Skill-up flash
--   Tooltip         -- Look -- Apply skin to the tooltip          -- Sections -- one switch each
--   Tooltip skills  one Hide row per catalog skill, by category
--   Tooltip stats   one Hide row per stat, by group
--
-- The template is a presets dropdown plus "Custom", which shows a text box taking the tokens
-- (NS.TemplateRows, settings/OptionsSetup.lua). A preset whose text carries a word goes through L;
-- the shipped default (defaults/Profile.lua) is matched as it is stored.
--
-- The tooltip's Hide sets (`broker.tooltip.hiddenSkills`, `broker.tooltip.hiddenStats`) are apart
-- from the main window's (`skills.hidden`, `stats.hidden`, settings/Skills.lua), whose pattern
-- these rows follow: each reads and writes its entry through get / set, false clearing it, and an
-- undrawn whole-set row per kind lets the page's Defaults clear a key with no row of its own.
local L = NS.L
local P = NS.defaults.profile.broker
local PAGE = "broker"
local FEED, TOOLTIP = L["Feed"], L["Tooltip"]
local TIP_SKILLS, TIP_STATS = L["Tooltip skills"], L["Tooltip stats"]

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
rows[#rows + 1] = {
    path = "broker.tooltip.skin", page = PAGE, group = TOOLTIP, subgroup = L["Look"], type = "bool",
    default = P.tooltip.skin, label = L["Apply skin to the tooltip"],
    desc = L["Draw the feed's tooltip in the skin's backdrop, border and fonts. Off, it is the game's plain tooltip."],
    onChange = function()
        if NS.Broker and NS.Broker.HideTooltip then NS.Broker.HideTooltip() end
    end,
}

local SECTION_LABEL = {
    primary = L["Primary professions"], secondary = L["Secondary skills"], weapon = L["Weapon skills"],
    other = L["Defense, lockpicking and riding"], stats = L["Stats"],
}
for _, id in ipairs(NS.Broker.SECTIONS) do
    rows[#rows + 1] = {
        path = "broker.tooltip.sections." .. id, page = PAGE, group = TOOLTIP, subgroup = L["Sections"],
        type = "bool", default = P.tooltip.sections[id], label = SECTION_LABEL[id],
        desc = L["Draw this section in the feed's tooltip."],
    }
end

-- ---------------------------------------------------------------------------------------------
-- Tooltip skills and stats: the Hide rows
-- ---------------------------------------------------------------------------------------------

local function tipSet(setKey)
    local b = NS.db and NS.db.profile.broker
    return b and b.tooltip and b.tooltip[setKey]
end

local function hideRow(setKey, key, name, group, subgroup)
    return {
        path = "broker.tooltip." .. setKey .. "." .. key, page = PAGE, group = group, subgroup = subgroup,
        type = "bool", default = false, label = L["Hide %s"]:format(name),
        desc = L["Leave this row out of the feed's tooltip. The main window has its own Hide, on the Skills and Stats pages."],
        get = function()
            local set = tipSet(setKey)
            return set ~= nil and set[key] == true
        end,
        set = function(v)
            local set = tipSet(setKey)
            if set then set[key] = v and true or nil end
        end,
    }
end

local function setRow(setKey, group)
    return {
        path = "broker.tooltip." .. setKey, page = PAGE, group = group, type = "set", default = {},
        skipRender = true, label = L["Hidden rows"],
        desc = L["Every row the feed's tooltip leaves out, as a set of keys."],
    }
end

local CATEGORY_SUBGROUP = {
    primary = L["Primary professions"], secondary = L["Secondary skills"], weapon = L["Weapon skills"],
    other = L["Defense, lockpicking and riding"],
}
rows[#rows + 1] = setRow("hiddenSkills", TIP_SKILLS)
for _, key in ipairs(NS.SortedSkillKeys) do
    local c = NS.SkillCatalog[key]
    local sub = CATEGORY_SUBGROUP[c.category] or CATEGORY_SUBGROUP.other
    rows[#rows + 1] = hideRow("hiddenSkills", key, L[c.name], TIP_SKILLS, sub)
end

local GROUP_SUBGROUP = {
    base = L["Base and combat"], spell = L["Spell and regen"],
    defense = L["Defense and resists"], utility = L["Utility"],
}
rows[#rows + 1] = setRow("hiddenStats", TIP_STATS)
for _, def in ipairs(NS.STAT_DEFS) do
    rows[#rows + 1] = hideRow("hiddenStats", def.key, def.label, TIP_STATS,
        GROUP_SUBGROUP[def.group] or GROUP_SUBGROUP.utility)
end

NS.RegisterSchemaRows(NS.Live(rows, refresh))

NS.RegisterSchemaPage(PAGE, L["Broker"], {
    defaultsTooltip = L["Restore every Broker setting on this profile to its default. Every hidden tooltip row is shown again."],
})
