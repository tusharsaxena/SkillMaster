local _, NS = ...
-- settings/Broker.lua — the Broker page (design §6.7): each data feed's text template and the
-- skill-up flash. A write repaints the feeds at once (NS.Broker.Refresh).
--
-- Each template is a presets dropdown plus "Custom...", which shows a text box taking the tokens
-- (NS.TemplateRows, settings/OptionsSetup.lua). A preset whose text carries a word goes through L;
-- the shipped defaults (defaults/Profile.lua) are matched as they are stored.
local L = NS.L
local P = NS.defaults.profile.broker
local PAGE, FEEDS, FLASH = "broker", L["Feeds"], L["Skill-up flash"]

local function refresh()
    if NS.Broker and NS.Broker.Refresh then NS.Broker.Refresh() end
end

local TOKENS = table.concat(NS.Template.TOKENS, ", ")
local DOT = " \194\183 "

local function preset(value, text) return { value = value, text = ("%s: %s"):format(text, value) } end

-- Each feed's presets, its shipped default first. The tokens: modules/Template.lua.
local PRESETS = {
    all = {
        preset(P.templates.all, L["Pinned skill and session gains"]),
        preset("{pinned}", L["Pinned skill"]),
        preset("{lowestProf}" .. DOT .. "+{gains}", L["Lowest profession and session gains"]),
        preset("{last}" .. DOT .. "+{gains}", L["Last skill-up and session gains"]),
    },
    professions = {
        preset(P.templates.professions, L["Lowest profession"]),
        preset("{lowestProf}" .. DOT .. "+{gains}", L["Lowest profession and session gains"]),
        preset("{pinned}", L["Pinned skill"]),
        preset("{last}", L["Last skill-up"]),
    },
    weapons = {
        preset(P.templates.weapons, L["Equipped weapon"]),
        preset("{equippedWeapon}" .. DOT .. "{skill:defense}", L["Equipped weapon and Defense"]),
        preset("{equippedWeapon}" .. DOT .. "+{gains}", L["Equipped weapon and session gains"]),
        preset("{last}", L["Last skill-up"]),
    },
    stats = {
        preset(P.templates.stats, L["Crit and speed"]),
        preset(L["{stat:crit} crit \194\183 {stat:hit} hit"], L["Crit and hit"]),
        preset(L["{stat:attackPower} AP \194\183 {stat:crit} crit"], L["Attack power and crit"]),
        preset(L["{stat:spellDamage} SP \194\183 {stat:spellCrit} crit"], L["Spell damage and spell crit"]),
        preset(L["{stat:armor} armor \194\183 {stat:dodge} dodge"], L["Armor and dodge"]),
    },
}

local function template(id, label)
    return NS.TemplateRows({
        path = "broker.templates." .. id, presetPath = "broker.presets." .. id, page = PAGE, group = FEEDS,
        subgroup = L["Text"], default = P.templates[id], label = label, presets = PRESETS[id],
        desc = L["What this feed shows on your broker display. Custom... writes your own."],
        boxDesc = L["This feed's own text. Tokens: %s. Press Enter to apply."]:format(TOKENS),
    })
end

local rows = {}
for _, feed in ipairs({ { "all", L["Skill Master: All"] }, { "professions", L["Skill Master: Professions"] },
                        { "weapons", L["Skill Master: Weapons"] }, { "stats", L["Skill Master: Stats"] } }) do
    for _, r in ipairs(template(feed[1], feed[2])) do rows[#rows + 1] = r end
end
rows[#rows + 1] = {
    path = "broker.flashSeconds", page = PAGE, group = FEEDS, subgroup = FLASH, type = "number",
    default = P.flashSeconds, min = 0, max = 30, step = 1, label = L["Flash duration (seconds, 0 = off)"],
    desc = L["How long a feed shows the skill that just went up (^ Bows 81) in place of its text."],
}
NS.RegisterSchemaRows(NS.Live(rows, refresh))

NS.RegisterSchemaPage(PAGE, L["Broker"], {
    defaultsTooltip = L["Restore every Broker setting on this profile to its default."],
})
