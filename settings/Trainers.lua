local _, NS = ...
-- settings/Trainers.lua — the Trainers and Waypoints page (modules/Waypoints.lua): which waypoint a
-- trainer's Go button sets, whether chat says so, the unverified-data mark, Skill Master's own arrow
-- (round 6, R6-11) and its look, colors and scale (round 8, R8-5: LibKa0s-WaypointArrow-1.0's
-- settings block), its text and position (round 9, R9-1), and the trainer popup's name color (a swatch on the skin's accent by default,
-- with its class-color companion). FB-SM-06 (the owner, 2026-11-24: "Split Trainers and Waypoint
-- into 2 separate tabs"): two groups, so two tabs, Trainers (the trainer data and the popup) first,
-- then Waypoints (the method, the chat line, the arrow); the page key and title are unchanged.
local H = NS.Helpers
local L = NS.L
local PW, PT = NS.defaults.profile.waypoints, NS.defaults.profile.trainers
local PAGE = "trainers"
local TRAINERS, WAYPOINTS = L["Trainers"], L["Waypoints"]

-- The Trainers tab: the trainer data, then the trainer popup.
NS.RegisterSchemaRows(NS.Live({
    -- Round 2 (the owner's feedback): the trainer popup's own check box writes this row too.
    { path = "trainers.showAll", page = PAGE, group = TRAINERS, type = "bool", default = PT.showAll,
      label = L["Show all trainers"],
      desc = L["In the trainer popup for a profession, list every trainer of every rank, Artisan first, and mark the ones who train your next rank."] },
    -- SF-SM-02 (LibKa0s#105, clients-§11): ForeverDB is optional, so the row says it is needed.
    { path = "trainers.foreverDB", page = PAGE, group = TRAINERS, type = "bool", default = PT.foreverDB,
      label = L["Use ForeverDB"],
      desc = L["Needs the ForeverDB addon (optional, WoW Forever). When it is installed, a rank learned from a book shows where the book is sold and what drops it, in the row tooltip and on the trainer popup's card, and a trainer with no map position in Skill Master's data takes ForeverDB's. ForeverDB loads the first time one of these is shown (about 12 MB). Without it, nothing changes."] },
}))

-- The trainer popup's name line (feedback round 2, FB-11): one swatch, its class-color companion
-- (options-ui-§17, the player's class: the trainer is no unit with one) and "Use the skin's color",
-- on by default, which draws the skin's accent (skinning-§6). The popup repaints on LAYOUT_CHANGED.
local nameRows = H.ColorPair({
    prefix = "trainers.", page = PAGE, group = TRAINERS, subgroup = L["Trainer popup"],
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

-- The Waypoints tab: where a waypoint goes and whether chat says so, then the arrow.
NS.RegisterSchemaRows(NS.Live({
    { path = "waypoints.method", page = PAGE, group = WAYPOINTS, type = "string", default = PW.method,
      label = L["Waypoint method"],
      desc = L["Where a trainer's waypoint goes: Map pin places one on the map (a TomTom waypoint, with TomTom's arrow, when TomTom is loaded), Chat only writes the directions. A trainer with no coordinates, or a client with neither TomTom nor a map pin, is always written to chat."],
      -- Round 7, R7-7: no TomTom choice, so "auto" is the map pin, else chat (schemaVersion 11 folded
      -- a stored "tomtom" or "native" into it). AF-SM-TOMTOM: "auto" is TomTom's waypoint when the
      -- real TomTom is loaded (modules/Waypoints.lua); still no separate choice.
      values = { { value = "auto", text = L["Map pin"] }, { value = "chat", text = L["Chat only"] } } },
    { path = "waypoints.announce", page = PAGE, group = WAYPOINTS, type = "bool", default = PW.announce,
      label = L["Say where in chat"], desc = L["Print a chat line naming the trainer when a waypoint is set."] },
}))

-- The Waypoint arrow subgroup. Round 6, R6-11: Skill Master's own arrow (modules/WaypointArrow.lua),
-- hand-written. Round 8, R8-5: then the library's settings block at NS.WaypointArrow.PATHS, in its
-- order: Arrow style (Raised by default), Use the skin's colors (on), Far color and Near color
-- (grayed while the skin's are drawn) and Arrow scale. Round 9, R9-1: then the library's Text block
-- under Arrow text (the canonical Font block with its Use the skin's font companion, Text
-- position, Show the trainer's name, Distance units) and its Position block under Arrow position
-- (X offset, Y offset, Lock the arrow, and the Reset position button, an afterSubgroup hook).
-- Composed rows: a library-absent load has no arrow and none of the eighteen (tests/test_options.lua
-- counts them in the gap).
local ARROW = L["Waypoint arrow"]
NS.RegisterSchemaRows(NS.Live({
    { path = "waypoints.arrow", page = PAGE, group = WAYPOINTS, subgroup = ARROW, type = "bool", default = PW.arrow,
      label = L["Show Skill Master's arrow"],
      desc = L["A map pin comes with Skill Master's own arrow, pointing the way with the distance under it, and the game's own arrow stays off. Off: the game's arrow points to the map pin. With TomTom loaded, TomTom's arrow points instead."],
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
    -- Round 9, R9-1: the Text block.
    FONT = L["Font"], FONT_TIP = L["The face the arrow's distance is drawn in."],
    FONT_SIZE = L["Font size"], FONT_SIZE_TIP = L["Height of the arrow's distance, in points."],
    FONT_COLOR = L["Font color"], FONT_COLOR_TIP = L["The color the arrow's distance is drawn in."],
    CLASS_COLOR = L["Use class color"],
    CLASS_COLOR_TIP = L["Draw the arrow's distance in your class color instead of the swatch beside it."],
    CLASS_COLOR_NOTE = L["Not read while Use class color is on, except for its opacity, which always applies."],
    FONT_FLAGS = L["Font flags"],
    FONT_FLAGS_TIP = L["Outline and monochrome rendering. From skin follows the Font outline setting on Skill Master's Skin tab; any other choice is drawn as picked."],
    FLAGS_SKIN = L["From skin"], FLAGS_NONE = L["None"], FLAGS_OUTLINE = L["Outline"],
    FLAGS_THICK = L["Thick outline"], FLAGS_MONO = L["Monochrome"], FLAGS_MONO_OUTLINE = L["Monochrome outline"],
    FONT_SHADOW = L["Font shadow"],
    FONT_SHADOW_TIP = L["Draw a soft shadow behind the arrow's distance, for legibility over bright art."],
    FONT_SKIN = L["Use the skin's font"],
    FONT_SKIN_TIP = L["Draw the arrow's distance in the skin's font. The font picker is not read while this is on."],
    TEXT_POSITION = L["Text position"],
    TEXT_POSITION_TIP = L["Where the distance sits beside the arrow, or Hidden for the arrow alone."],
    POS_BELOW = L["Below"], POS_ABOVE = L["Above"], POS_LEFT = L["Left"], POS_RIGHT = L["Right"],
    POS_HIDDEN = L["Hidden"],
    SHOW_LABEL = L["Show the trainer's name"],
    SHOW_LABEL_TIP = L["A second line under the distance with the name of the trainer the arrow points to."],
    UNITS = L["Distance units"],
    UNITS_TIP = L["Yards, or compact: thousands of yards shortened, as 4.2k yd."],
    UNITS_YARDS = L["Yards"], UNITS_COMPACT = L["Compact (4.2k yd)"],
    -- Round 9, R9-1: the Position block and the arrow's own lock.
    POSITION = L["Arrow position"],
    X_OFFSET = L["X offset"],
    X_TIP = L["How far right of the screen's center the arrow sits; the Arrow scale does not move it. Dragging the arrow sets it."],
    Y_OFFSET = L["Y offset"],
    Y_TIP = L["How far above the screen's center the arrow sits; the Arrow scale does not move it. Dragging the arrow sets it."],
    LOCK = L["Lock the arrow"],
    LOCK_TIP = L["While on, the arrow cannot be dragged. Its right-click menu still opens. /sm lock does not hold the arrow."],
    RESET_POSITION = L["Reset position"], RESET_POSITION_TIP = L["Put the arrow back at its default position."],
}
-- The Position block's Reset position button, keyed by its subgroup, for the page's render.
local arrowHooks = {}
if NS.WaypointArrow then
    local rows, hooks = NS.WaypointArrow.SettingsRows({ page = PAGE, group = WAYPOINTS, subgroup = ARROW,
        textSubgroup = L["Arrow text"], positionSubgroup = ARROW_WORDS.POSITION, L = ARROW_WORDS })
    NS.RegisterSchemaRows(rows)
    arrowHooks = hooks or {}
end

NS.RegisterSchemaPage(PAGE, L["Trainers and Waypoints"], {
    defaultsTooltip = L["Restore every Trainers and Waypoints setting on this profile to its default."],
    afterSubgroup = arrowHooks,
})
