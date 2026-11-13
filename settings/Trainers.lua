local _, NS = ...
-- settings/Trainers.lua — the Trainers and Waypoints page (modules/Waypoints.lua): which waypoint a
-- trainer's Go button sets, whether chat says so, Skill Master's own arrow and its scale (round 6,
-- R6-11), the unverified-data mark, and the trainer popup's name color (a swatch on the skin's accent by default, with its class-color companion).
local H = NS.Helpers
local L = NS.L
local PW, PT = NS.defaults.profile.waypoints, NS.defaults.profile.trainers
local PAGE, GROUP = "trainers", L["Trainers and waypoints"]

NS.RegisterSchemaRows(NS.Live({
    { path = "waypoints.method", page = PAGE, group = GROUP, type = "string", default = PW.method,
      label = L["Waypoint method"],
      desc = L["Where a trainer's waypoint goes: Map pin places one on the map, Chat only writes the directions. A trainer with no coordinates, or a client with no map pin, is always written to chat."],
      -- Round 7, R7-7: no TomTom, so "auto" is the map pin, else chat (schemaVersion 11 folded a
      -- stored "tomtom" or "native" into it).
      values = { { value = "auto", text = L["Map pin"] }, { value = "chat", text = L["Chat only"] } } },
    { path = "waypoints.announce", page = PAGE, group = GROUP, type = "bool", default = PW.announce,
      label = L["Say where in chat"], desc = L["Print a chat line naming the trainer when a waypoint is set."] },
    -- Round 6, R6-11: Skill Master's own arrow (modules/WaypointArrow.lua).
    { path = "waypoints.arrow", page = PAGE, group = GROUP, type = "bool", default = PW.arrow,
      label = L["Show Skill Master's arrow"],
      desc = L["A map pin comes with Skill Master's own arrow, pointing the way with the distance under it, and the game's own arrow stays off. Off: the game's arrow points to the map pin."],
      onChange = function() if NS.WaypointArrow then NS.WaypointArrow.ApplySettings() end end },
    { path = "waypoints.arrowScale", page = PAGE, group = GROUP, type = "number", default = PW.arrowScale,
      min = 0.5, max = 2, step = 0.05, commitOn = "change", label = L["Arrow scale"],
      desc = L["Size of Skill Master's waypoint arrow."],
      onChange = function() if NS.WaypointArrow then NS.WaypointArrow.ApplySettings() end end },
    { path = "trainers.unverified", page = PAGE, group = GROUP, type = "bool", default = PT.unverified,
      label = L["Mark unverified trainers"],
      desc = L["Flag trainer data not yet checked on WoW Forever, in tooltips, the trainer popup and chat."] },
}))

-- The trainer popup's name line (feedback round 2, FB-11): one swatch, its class-color companion
-- (options-ui-§17, the player's class: the trainer is no unit with one) and "Use the skin's color",
-- on by default, which draws the skin's accent (skinning-§6). The popup repaints on LAYOUT_CHANGED.
local nameRows = H.ColorPair({
    prefix = "trainers.", page = PAGE, group = GROUP, subgroup = L["Trainer popup"],
    key = "nameColor", companionKey = "useClassColorName", label = L["Trainer name color"],
    classColor = { source = "player" },
    tooltips = { nameColor = L["The trainer's name in the trainer popup. Not read while Use the skin's color is on."] },
    defaults = { nameColor = PT.nameColor, useClassColorName = PT.useClassColorName },
    extra = {
        { path = "trainers.nameColorFromSkin", page = PAGE, type = "bool", default = PT.nameColorFromSkin,
          label = L["Use the skin's color"],
          desc = L["Draw the trainer's name in the skin's accent. Trainer name color is not read while this is on."] },
    },
})
NS.RegisterSchemaRows(NS.Live(nameRows))

NS.RegisterSchemaPage(PAGE, L["Trainers and Waypoints"], {
    defaultsTooltip = L["Restore every Trainers and Waypoints setting on this profile to its default."],
})
