local _, NS = ...
-- settings/Trainers.lua — the Trainers and Waypoints page (modules/Waypoints.lua): which waypoint a
-- trainer's Go button sets, whether chat says so, the unverified-data mark, Skill Master's own arrow
-- (round 6, R6-11) and its look, colors and scale (round 8, R8-5: LibKa0s-WaypointArrow-1.0's
-- settings block), and the trainer popup's name color (a swatch on the skin's accent by default,
-- with its class-color companion).
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
    { path = "trainers.unverified", page = PAGE, group = GROUP, type = "bool", default = PT.unverified,
      label = L["Mark unverified trainers"],
      desc = L["Flag trainer data not yet checked on WoW Forever, in tooltips, the trainer popup and chat."] },
}))

-- The Waypoint arrow subgroup. Round 6, R6-11: Skill Master's own arrow (modules/WaypointArrow.lua),
-- hand-written. Round 8, R8-5: then the library's settings block at NS.WaypointArrow.PATHS, in its
-- order: Arrow style (Raised by default), Use the skin's colors (on), Far color and Near color
-- (grayed while the skin's are drawn) and Arrow scale. Composed rows: a library-absent load has no
-- arrow and none of the five (tests/test_options.lua counts them in the gap).
local ARROW = L["Waypoint arrow"]
NS.RegisterSchemaRows(NS.Live({
    { path = "waypoints.arrow", page = PAGE, group = GROUP, subgroup = ARROW, type = "bool", default = PW.arrow,
      label = L["Show Skill Master's arrow"],
      desc = L["A map pin comes with Skill Master's own arrow, pointing the way with the distance under it, and the game's own arrow stays off. Off: the game's arrow points to the map pin."],
      onChange = function() if NS.WaypointArrow then NS.WaypointArrow.ApplySettings() end end },
}))
-- The library's words, keyed as its SETTINGS_STRINGS, through NS.L.
local ARROW_WORDS = {
    STYLE = L["Arrow style"],
    STYLE_TIP = L["How the arrow is drawn. Raised floats over the world on a soft shadow; On the ground lies flat, tilted toward you."],
    STYLE_FLAT = L["Flat"], STYLE_RIDGE = L["Ridge"], STYLE_RAISED = L["Raised"], STYLE_FACETED = L["Faceted"],
    STYLE_GROUND = L["On the ground"],
    USE_SKIN = L["Use the skin's colors"],
    USE_SKIN_TIP = L["The arrow fades from the skin's accent color, far away, to its good color as you arrive. Off: your own two colors."],
    FAR = L["Far color"], FAR_TIP = L["The arrow's color 300 yards away or more. Not read while Use the skin's colors is on."],
    NEAR = L["Near color"], NEAR_TIP = L["The arrow's color 30 yards away or closer. Not read while Use the skin's colors is on."],
    SCALE = L["Arrow scale"], SCALE_TIP = L["The size of the arrow and its distance, 0.5 to 2."],
}
if NS.WaypointArrow then
    NS.RegisterSchemaRows(NS.WaypointArrow.SettingsRows({ page = PAGE, group = GROUP, subgroup = ARROW, L = ARROW_WORDS }))
end

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
