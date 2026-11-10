local _, NS = ...
-- defaults/Profile.lua — the AceDB defaults tree, the only place a default is written
-- (savedvariables-§2). Every schema row's `default` reads it.

NS.defaults = {
    profile = {
        enabled = true,     -- the Enable Ka0s Skill Master row (slash `enable` / `disable`)
        scale   = 1,        -- the main window's scale (0.5 .. 2)
        alpha   = 1,        -- the main window's opacity (0 .. 1)
        locked  = false,    -- the main window cannot be dragged while true
        -- Drag-only geometry, no control sets it: written by modules/MainWindow.lua alone
        -- (architecture-§5's named-owner rule; docs/ARCHITECTURE.md names the writer).
        window = { point = false },
        -- T3.2 the main window's body and the blocks (modules/Blocks.lua). `blocks[id].point` is
        -- named non-setting state (the detached frames' drag writes it); every other key has a row
        -- on the Layout page (T5.1), and `docked`, `order` and `collapsed` write through NS.Blocks.
        layout = {
            width     = 440,     -- the main window's width, px
            maxHeight = 560,     -- the window scrolls past this
            blockGap  = 0,       -- px between two docked blocks
            summary   = true,    -- the strip under the title: level, session gains, next alert
            columns   = 1,       -- the window's body: 1 or 2 columns of docked blocks, each `width` wide
            -- The player's strata (frame-layering-§1: BACKGROUND, LOW, MEDIUM or HIGH): the main
            -- window's, and every detached block's. The crafting overlays take their host's.
            strata         = "MEDIUM",
            detachedStrata = "MEDIUM",
            blocks = {
                primary       = { docked = true, order = 1, collapsed = false, point = false, scale = 1, locked = false, shown = true },
                secondary     = { docked = true, order = 2, collapsed = false, point = false, scale = 1, locked = false, shown = true },
                -- belowCapOnly: the detached compact preset shows only the equipped weapons and the
                -- skills below their cap (Detached.dc.html; Layout > Blocks > Weapon skills).
                weapon        = { docked = true, order = 3, collapsed = false, point = false, scale = 1, locked = false, shown = true,
                                  belowCapOnly = false },
                other         = { docked = true, order = 4, collapsed = false, point = false, scale = 1, locked = false, shown = true },
                stats_base    = { docked = true, order = 5, collapsed = false, point = false, scale = 1, locked = false, shown = true },
                stats_spell   = { docked = true, order = 6, collapsed = true,  point = false, scale = 1, locked = false, shown = true },
                stats_defense = { docked = true, order = 7, collapsed = true,  point = false, scale = 1, locked = false, shown = true },
                stats_utility = { docked = true, order = 8, collapsed = false, point = false, scale = 1, locked = false, shown = true },
            },
        },
        -- Rows a player hid from the row menu (T3.3) or the Skills and Stats pages, whether unlearned
        -- rows show, the gathering and fishing helper lines in a row's tooltip (helperTooltip) and
        -- the optional one-line hint drawn under the row (helperHint, off by default: design §12.4).
        skills = { showUnlearned = true, hidden = {}, helperTooltip = true, helperHint = false },
        -- How a stat row draws: "both" (bar and value), "bar" (no value text) or "text" (no bar).
        stats  = { hidden = {}, display = "both" },
        -- T3.1 the bar widget's look (modules/Bar.lua). The colors are the player's picks; while
        -- `colors.fromSkin` is on (the default, skinning-§6) the skin's owner tokens draw instead
        -- (core/SkinSetup.lua, sm.cat.* and sm.bonus*). Both carry the approved mockup's colors
        -- (docs/superpowers/specs/2026-11-10-skill-master-mockups).
        bars = {
            height        = 14,          -- a row's bar, px
            compactHeight = 11,          -- a detached block's compact bar
            tooltipHeight = 8,           -- the bar inside a row tooltip
            miniHeight    = 6,           -- the journal's and the broker tooltip's mini bars
            rowHeight     = 20,          -- one skill or stat row
            fontSize      = 11,          -- the bar text, before the skin's HUD scale
            textAnchor    = "CENTER",    -- "LEFT" | "CENTER" | "RIGHT"
            fillDirection = "LEFT",      -- the edge the fill grows from: "LEFT" (left to right) | "RIGHT"
            -- The bar text; tokens {rank} {bonus} {max} {pct} {left} (modules/Bar.lua Bar.Text).
            textTemplate  = "{rank} {bonus} / {max}",
            spark         = true,        -- a thin line riding the end of the fill
            ticks         = true,        -- profession tier ticks (75 / 150 / 225)
            markers       = true,        -- a stat's threshold markers (hit cap, resist cap)
            timer         = true,        -- the temporary bonus's time left beside the bar
            colorMode     = "category",  -- "category" | "progress" | "likelihood" | "flat"
            -- T5.1 the composed blocks (options-ui-§16): the fill (the flat color mode's color),
            -- the background, the border and the text. Every `*FromSkin` companion starts on the
            -- skin (skinning-§6): the stored pick waits for the player to turn it off.
            barTexture          = "Ka0s Default",
            barAlpha            = 1,
            barColor            = { 0.27, 0.59, 0.90, 1 },
            useClassColorBar    = false,
            barTextureFromSkin  = true,
            barColorFromSkin    = true,
            bgColor             = { 0.04, 0.03, 0.02, 0.9 },
            useClassColorBg     = false,
            bgColorFromSkin     = true,
            border              = true,        -- Show border
            borderStyle         = "Solid",
            borderSize          = 1,
            borderColor         = { 0.24, 0.22, 0.20, 1 },
            useClassColorBorder = false,
            borderStyleFromSkin = true,
            borderColorFromSkin = true,
            font                = "Ka0s Prototype",
            fontColor           = { 1, 1, 1, 1 },
            useClassColorFont   = false,
            fontFlags           = "@skin",
            fontShadow          = false,
            fontFromSkin        = true,
            fontColorFromSkin   = true,
            fontShadowFromSkin  = true,
            colors = {
                fromSkin  = true,
                primary   = { 0.357, 0.608, 0.878, 1 },
                secondary = { 0.373, 0.702, 0.427, 1 },
                weapon    = { 0.851, 0.569, 0.247, 1 },
                other     = { 0.627, 0.549, 0.878, 1 },
                stats     = { 0.788, 0.627, 0.478, 1 },
                bonusTemp = { 0.498, 0.847, 0.769, 1 },
                bonusPerm = { 0.553, 0.722, 1, 1 },
            },
        },
        -- The Journal window: its drop point and size ({ w, h }, from its resize grip; the same rule:
        -- written by modules/Journal.lua alone), the session log's length per character and the Alts
        -- tab's filter on open.
        journal = { point = false, size = false, keep = 500, filter = "professions" },
        -- T5.1 the Trainers and Waypoints page (modules/Waypoints.lua, modules/TrainerPopup.lua).
        waypoints = {
            method   = "auto",   -- "auto" (TomTom, else the map pin, else chat) | "tomtom" | "native" | "chat"
            announce = true,     -- say in chat where a waypoint was set
        },
        trainers = { unverified = true },   -- mark trainer data not yet checked on WoW Forever
        skin = {
            source      = "ka0s",                     -- Ka0s skins, or EllesmereUI
            skin        = NS.DEFAULT_SKIN or "ka0s",  -- the library's per-client default: WoW Forever here
            ignorePanel = false,
            ignoreFonts = false,
            font        = "",                         -- a LibSharedMedia key; "" keeps the skin's
            texture     = "",                         -- a LibSharedMedia key; "" keeps the skin's
            outline     = "hud",
            pickerSeen  = false,                      -- the first-run skin picker was closed here
        },
        -- T4.2: the alerts (modules/Alerts.lua). `point` is drag-only toast geometry, written by
        -- modules/Alerts.lua alone (architecture-§5's named-owner rule), like window.point.
        alerts = {
            cap       = true,   -- a profession at its rank's cap, with a next rank: toast + chat
            weapon    = true,   -- a weapon skill weaponGap or more below its cap: toast
            weaponGap = 25,     -- skill points below the cap (5 x level) that count as behind
            sound     = false,  -- play the toast's sound as each alert shows
            point     = false,  -- the toast stack's drop point, in UIParent's units
        },
        -- The broker data feeds (modules/Broker.lua, design §6.7). Tokens: modules/Template.lua.
        broker = {
            flashSeconds = 5,   -- how long "^ Bows 81" replaces a feed's text after a skill-up
            templates = {
                all         = "{pinned} \194\183 +{gains}",
                professions = "{lowestProf}",
                weapons     = "{equippedWeapon}",
                stats       = "{stat:crit} crit \194\183 {stat:speed}",
            },
        },
    },
    -- 0, never the current version: AceDB strips a value equal to its default at logout
    -- (savedvariables-§1). `minimap` is LibDBIcon's own table (launcher-§3), per installation.
    -- `characters` is the alt overview's store (modules/Alts.lua), keyed "<realm>-<name>".
    global = { schemaVersion = 0, minimap = { hide = false }, characters = {} },
    -- Per character: the pinned skill the broker's {pinned} token shows (design §7), set from the
    -- row menu (T3.3), and the session log's ring (modules/SessionLog.lua).
    char = { pinned = false, log = {} },
}
