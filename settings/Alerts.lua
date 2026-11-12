local _, NS = ...
-- settings/Alerts.lua — the Alerts page (modules/Alerts.lua, T4.2): the rank-cap and weapon-gap
-- alerts, the gap that counts as behind, and the toast's sound. `alerts.point` is the toast stack's
-- drag-only drop point and has no row.
local L = NS.L
local P = NS.defaults.profile.alerts
local PAGE, ALERTS = "alerts", L["Alerts"]

NS.RegisterSchemaRows({
    { path = "alerts.cap", page = PAGE, group = ALERTS, type = "bool", default = P.cap,
      label = L["Rank cap alert"],
      desc = L["A toast and a chat line when a profession reaches its rank's cap and a higher rank can be trained."] },
    { path = "alerts.weapon", page = PAGE, group = ALERTS, type = "bool", default = P.weapon,
      label = L["Weapon skill alert"],
      desc = L["A toast when a weapon skill falls behind its cap (5 per level) by the gap below."] },
    { path = "alerts.weaponGap", page = PAGE, group = ALERTS, type = "number", default = P.weaponGap,
      min = 5, max = 100, step = 5, label = L["Weapon skill gap (points)"],
      desc = L["How far below its cap a weapon skill must be before it alerts. Needs Weapon skill alert."] },
    { path = "alerts.weaponMode", page = PAGE, group = ALERTS, type = "string", default = P.weaponMode,
      values = { { value = "untrained", text = L["Skip untrained weapons"] },
                 { value = "equipped", text = L["Equipped weapons only"] },
                 { value = "all", text = L["Every learned weapon"] } },
      label = L["Weapons that alert"],
      desc = L["Skip untrained weapons leaves out a weapon still at 5 points or fewer. Equipped weapons only reads the main hand, off hand and ranged weapons you wear now."] },
    { path = "alerts.sound", page = PAGE, group = ALERTS, type = "bool", default = P.sound,
      label = L["Play a sound"], desc = L["Play the toast's sound as each rank cap or weapon skill alert shows."] },
    -- The skill-up toast (owner feedback round 4), in its own subgroup.
    { path = "alerts.skillUp", page = PAGE, group = ALERTS, subgroup = L["Skill ups"], type = "bool",
      default = P.skillUp, label = L["Skill-up alert"],
      desc = L["A short green toast on every skill point. Skill-ups a few seconds apart share one toast."] },
    { path = "alerts.skillUpScope", page = PAGE, group = ALERTS, subgroup = L["Skill ups"], type = "string",
      default = P.skillUpScope,
      values = { { value = "all", text = L["All skills"] },
                 { value = "professions", text = L["Professions only"] },
                 { value = "combat", text = L["Weapons and Other only"] } },
      label = L["Skill-up alerts for"],
      desc = L["Which skills the skill-up alert reads: every skill, the primary and secondary professions, or the weapon and Other skills. Needs Skill-up alert."] },
    { path = "alerts.skillUpSound", page = PAGE, group = ALERTS, subgroup = L["Skill ups"], type = "bool",
      default = P.skillUpSound, label = L["Play a sound on skill up"],
      desc = L["Play the toast's sound as each skill-up toast shows."] },
    { path = "alerts.weaponMuted", page = PAGE, group = ALERTS, type = "set", default = {}, skipRender = true,
      label = L["Muted weapons"], desc = L["The weapons the weapon skill alert never reads, as a set of keys."] },
})

-- One Mute row per weapon line (owner feedback round 3), in the catalog's order.
local MUTED = L["Muted weapons"]
local function muted() return NS.db and NS.db.profile.alerts.weaponMuted end
local muteRows = {}
for _, key in ipairs(NS.SortedSkillKeys) do
    local c = NS.SkillCatalog[key]
    if c.category == "weapon" then
        muteRows[#muteRows + 1] = {
            path = "alerts.weaponMuted." .. key, page = PAGE, group = MUTED, type = "bool", default = false,
            label = L["Mute %s"]:format(L[c.name]),
            desc = L["Never alert for this weapon, whatever its gap."],
            get = function() local m = muted() return m ~= nil and m[key] == true end,
            set = function(v) local m = muted() if m then m[key] = v and true or nil end end,
        }
    end
end
NS.RegisterSchemaRows(muteRows)

NS.RegisterSchemaPage(PAGE, L["Alerts"], {
    defaultsTooltip = L["Restore every Alerts setting on this profile to its default."],
})
