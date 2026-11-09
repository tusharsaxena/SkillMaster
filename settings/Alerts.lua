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
    { path = "alerts.sound", page = PAGE, group = ALERTS, type = "bool", default = P.sound,
      label = L["Play a sound"], desc = L["Play the toast's sound as each alert shows."] },
})

NS.RegisterSchemaPage(PAGE, L["Alerts"], {
    defaultsTooltip = L["Restore every Alerts setting on this profile to its default."],
})
