local _, NS = ...
-- settings/Skills.lua — the Skills and Stats pages (design §6.6): the skill rows' switches, and one
-- Hide row per catalog skill and per stat (how either kind of row draws is the Bars page's Rows show), so a row hidden from the row menu (T3.3) can be
-- shown again here or with `/sm set skills.hidden.<key> false`.
--
-- The hide rows are generated from NS.SkillCatalog and NS.STAT_DEFS at load. `skills.hidden` and
-- `stats.hidden` are sets ({ [key] = true }), so each row reads and writes its entry through get /
-- set: false clears the entry rather than storing it.
local L = NS.L
local PS = NS.defaults.profile.skills

-- ---------------------------------------------------------------------------------------------
-- The hide rows
-- ---------------------------------------------------------------------------------------------

local function hiddenSet(kind)
    local p = NS.db and NS.db.profile[kind]
    return p and p.hidden
end

local function hideRow(page, kind, key, name, group, subgroup)
    return {
        path = kind .. ".hidden." .. key, page = page, group = group, subgroup = subgroup, type = "bool",
        default = false, label = L["Hide %s"]:format(name),
        desc = L["Leave this row out of the window, the detached blocks and the feeds. The row menu's Hide sets it too."],
        get = function()
            local set = hiddenSet(kind)
            return set ~= nil and set[key] == true
        end,
        set = function(v)
            local set = hiddenSet(kind)
            if set then set[key] = v and true or nil end
        end,
        onChange = NS.ApplyLook,
    }
end

--- The whole set's row (review F-002): not drawn, but the page's Defaults, `/sm reset` and the
--- row menu reach it, so a key with no row of its own (an "other:" skill the catalog does not
--- know) is a settings write that the page's Defaults undoes.
local function setRow(page, kind, group)
    return {
        path = kind .. ".hidden", page = page, group = group, type = "set", default = {}, skipRender = true,
        label = L["Hidden rows"], desc = L["Every row hidden from the row menu, as a set of keys."],
        onChange = NS.ApplyLook,
    }
end

-- ---------------------------------------------------------------------------------------------
-- Skills
-- ---------------------------------------------------------------------------------------------
local SK_GENERAL, PROFESSIONS, WEAPONS = L["General"], L["Professions"], L["Weapons and other"]
local skillRows = NS.Live({
    { path = "skills.showUnlearned", page = "skills", group = SK_GENERAL, type = "bool", default = PS.showUnlearned,
      label = L["Show unlearned skills"],
      desc = L["List the weapon skills and Riding your class can learn but has not, dimmed, with their trainer."] },
    { path = "skills.helperTooltip", page = "skills", group = SK_GENERAL, type = "bool", default = PS.helperTooltip,
      label = L["Gathering and fishing hints"],
      desc = L["In a gathering skill's tooltip: the highest level you can skin, the next node you can gather and the skill a zone's fish need."] },
    { path = "skills.helperHint", page = "skills", group = SK_GENERAL, type = "bool", default = PS.helperHint,
      label = L["Hint under the row"],
      desc = L["One muted line under the Skinning, Mining, Herbalism and Fishing rows: what you can gather now and the next step."] },
})

local CATEGORY_TAB = {
    primary   = { PROFESSIONS, L["Primary professions"] },
    secondary = { PROFESSIONS, L["Secondary skills"] },
    weapon    = { WEAPONS, L["Weapon skills"] },
    other     = { WEAPONS, L["Defense, lockpicking and riding"] },
}
local RANK = { primary = 1, secondary = 2, weapon = 3, other = 4 }

local keys = {}
for key in pairs(NS.SkillCatalog) do keys[#keys + 1] = key end
table.sort(keys, function(a, b)
    local ca, cb = NS.SkillCatalog[a], NS.SkillCatalog[b]
    if ca.category ~= cb.category then return (RANK[ca.category] or 9) < (RANK[cb.category] or 9) end
    if (ca.order or 0) ~= (cb.order or 0) then return (ca.order or 0) < (cb.order or 0) end
    return a < b
end)
skillRows[#skillRows + 1] = setRow("skills", "skills", SK_GENERAL)
for _, key in ipairs(keys) do
    local c = NS.SkillCatalog[key]
    local tab = CATEGORY_TAB[c.category] or CATEGORY_TAB.other
    skillRows[#skillRows + 1] = hideRow("skills", "skills", key, L[c.name], tab[1], tab[2])
end
NS.RegisterSchemaRows(skillRows)
NS.RegisterSchemaPage("skills", L["Skills"], {
    defaultsTooltip = L["Restore every Skills setting on this profile to its default. Every hidden skill is shown again."],
})

-- ---------------------------------------------------------------------------------------------
-- Stats
-- ---------------------------------------------------------------------------------------------
local ST_GENERAL = L["General"]
local GROUP_TAB = {
    base = L["Base and combat"], spell = L["Spell and regen"],
    defense = L["Defense and resists"], utility = L["Utility"],
}
-- How a stat row draws is the Bars page's Rows show (bars.rowDisplay), shared with skill rows.
local statRows = { setRow("stats", "stats", ST_GENERAL) }
for _, def in ipairs(NS.STAT_DEFS) do
    statRows[#statRows + 1] = hideRow("stats", "stats", def.key, def.label, GROUP_TAB[def.group] or GROUP_TAB.utility)
end
NS.RegisterSchemaRows(statRows)
NS.RegisterSchemaPage("stats", L["Stats"], {
    defaultsTooltip = L["Restore every Stats setting on this profile to its default. Every hidden stat is shown again."],
})
