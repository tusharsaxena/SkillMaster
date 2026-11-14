local _, NS = ...
-- settings/Skills.lua — the Skills page (design §6.6): the skill rows' switches (unlearned skills,
-- the gathering and fishing hints). How a skill row draws is the Bars page's Rows show.
--
-- Every skill's and stat's Hide (the window's and the LDB tooltip's) is on the Rows page
-- (settings/Rows.lua, round 5, R5-13), which replaced this page's Professions and Weapons tabs and the
-- Stats page. This file still sorts the catalog for the pages that walk it (NS.SortedSkillKeys).
local L = NS.L
local PS = NS.defaults.profile.skills

local SK_GENERAL = L["General"]
NS.RegisterSchemaRows(NS.Live({
    { path = "skills.showUnlearned", page = "skills", group = SK_GENERAL, type = "bool", default = PS.showUnlearned,
      label = L["Show unlearned skills"],
      desc = L["List the weapon skills and Riding your class can learn but has not, dimmed, with their trainer."] },
    { path = "skills.helperTooltip", page = "skills", group = SK_GENERAL, type = "bool", default = PS.helperTooltip,
      label = L["Gathering and fishing hints"],
      desc = L["In a gathering skill's tooltip: the highest level you can skin, the next node you can gather and the skill a zone's fish need."] },
    { path = "skills.helperHint", page = "skills", group = SK_GENERAL, type = "bool", default = PS.helperHint,
      label = L["Hint under the row"],
      desc = L["One muted line under the Skinning, Mining, Herbalism and Fishing rows: what you can gather now and the next step."] },
}))

local RANK = { primary = 1, secondary = 2, weapon = 3, other = 4 }
local keys = {}
for key in pairs(NS.SkillCatalog) do keys[#keys + 1] = key end
table.sort(keys, function(a, b)
    local ca, cb = NS.SkillCatalog[a], NS.SkillCatalog[b]
    if ca.category ~= cb.category then return (RANK[ca.category] or 9) < (RANK[cb.category] or 9) end
    if (ca.order or 0) ~= (cb.order or 0) then return (ca.order or 0) < (cb.order or 0) end
    return a < b
end)
-- The catalog in the window's order (category, then catalog order): the Rows and Alerts pages walk
-- it (settings/Rows.lua, settings/Alerts.lua, loaded after this file).
NS.SortedSkillKeys = keys

NS.RegisterSchemaPage("skills", L["Skills"], {
    defaultsTooltip = L["Restore every Skills setting on this profile to its default. Hidden rows stay hidden: the Rows page's Defaults shows them again."],
})
