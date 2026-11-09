local _, NS = ...
-- settings/Trainers.lua — the Trainers and Waypoints page (modules/Waypoints.lua): which waypoint a
-- trainer's Go button sets, whether chat says so, and the unverified-data mark.
local L = NS.L
local PW, PT = NS.defaults.profile.waypoints, NS.defaults.profile.trainers
local PAGE, GROUP = "trainers", L["Trainers and waypoints"]

NS.RegisterSchemaRows(NS.Live({
    { path = "waypoints.method", page = PAGE, group = GROUP, type = "string", default = PW.method,
      label = L["Waypoint method"],
      desc = L["Where a trainer's waypoint goes: Automatic tries TomTom, then the map pin, then chat. A trainer with no coordinates is always written to chat."],
      values = { { value = "auto", text = L["Automatic"] }, { value = "tomtom", text = L["TomTom first"] },
                 { value = "native", text = L["Map pin"] }, { value = "chat", text = L["Chat only"] } } },
    { path = "waypoints.announce", page = PAGE, group = GROUP, type = "bool", default = PW.announce,
      label = L["Say where in chat"], desc = L["Print a chat line naming the trainer when a waypoint is set."] },
    { path = "trainers.unverified", page = PAGE, group = GROUP, type = "bool", default = PT.unverified,
      label = L["Mark unverified trainers"],
      desc = L["Flag trainer data not yet checked on WoW Forever, in tooltips, the trainer popup and chat."] },
}))

NS.RegisterSchemaPage(PAGE, L["Trainers and Waypoints"], {
    defaultsTooltip = L["Restore every Trainers and Waypoints setting on this profile to its default."],
})
