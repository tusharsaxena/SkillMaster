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
            -- The main window's width, px: 420 since the rows' marks moved into the header's column
            -- and the bar's timer inside it, which gave every bar 18 px back (feedback round 2).
            width     = 420,
            maxHeight = 560,     -- the window's height; it scrolls past this
            -- Shrink the window to its rows (up to maxHeight). Off by default: the window keeps its
            -- height when blocks collapse or expand (owner feedback round 3).
            fitHeight = false,
            blockGap  = 0,       -- px between two docked blocks
            summary   = true,    -- the strip under the title: level, session gains, next alert
            columns   = 1,       -- the window's body: 1 or 2 columns of docked blocks, each `width` wide
            -- The player's strata (frame-layering-§1: BACKGROUND, LOW, MEDIUM or HIGH): the main
            -- window's, and every detached block's. The crafting overlays take their host's.
            strata         = "MEDIUM",
            detachedStrata = "MEDIUM",
            -- Layout > Detached windows (round 5, R5-7): one style for every detached window
            -- (modules/Detached.lua D.ApplyStyle). scale multiplies each block's own; alpha is the
            -- whole window's; the background and the border follow the skin while their companions
            -- are on (skinning-§6), else the swatches through their class companions; titleBand is
            -- "always", "hover" (shown while the pointer is over the window) or "never".
            detached = {
                scale               = 1,
                alpha               = 1,
                bgColor             = { 0.05, 0.05, 0.06, 0.9 },
                useClassColorBg     = false,
                bgFromSkin          = true,
                border              = true,
                borderStyle         = "Solid",
                borderSize          = 1,
                borderColor         = { 0.24, 0.22, 0.20, 1 },
                useClassColorBorder = false,
                borderFromSkin      = true,
                titleBand           = "always",
            },
            -- Merged detached windows (round 5, R5-6; modules/Groups.lua, their one owner; named
            -- non-setting state, no row sets it): [gid] = { point = {...} | false, columns = { { id,
            -- ... }, ... } }, each column a list of detached block ids, top to bottom.
            groups = {},
            -- sort: the block's row order (modules/Blocks.lua B.SORTS; owner feedback round 3).
            -- filter: the header's filter mark (modules/Blocks.lua B.FILTER_SETS; the weapon block's,
            -- round 5, R5-10; every block's, round 7, R7-1), "all" by default.
            blocks = {
                primary       = { docked = true, order = 1, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
                secondary     = { docked = true, order = 2, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
                -- belowCapOnly: the detached compact preset shows only the equipped weapons and the
                -- skills below their cap (Detached.dc.html; Layout > Blocks > Weapon skills).
                weapon        = { docked = true, order = 3, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name",
                                  belowCapOnly = false, filter = "all" },
                other         = { docked = true, order = 4, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
                stats_base    = { docked = true, order = 5, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
                stats_spell   = { docked = true, order = 6, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
                stats_defense = { docked = true, order = 7, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
                stats_utility = { docked = true, order = 8, collapsed = false, point = false, scale = 1, locked = false, shown = true, sort = "name", filter = "all" },
            },
        },
        -- Rows a player hid from the row menu (T3.3) or the Skills and Stats pages, whether unlearned
        -- rows show, the gathering and fishing helper lines in a row's tooltip (helperTooltip) and
        -- the optional one-line hint drawn under the row (helperHint, off by default: design §12.4).
        skills = { showUnlearned = true, hidden = {}, helperTooltip = true, helperHint = false },
        -- Stat rows the player hid. How a row draws is bars.rowDisplay, for skills and stats alike
        -- (schemaVersion 2 moved a stored stats.display there: core/Database.lua).
        stats  = { hidden = {} },
        -- T3.1 the bar widget's look (modules/Bar.lua). The colors are the player's picks; while
        -- `colors.fromSkin` is on (the default, skinning-§6) the skin's owner tokens draw instead
        -- (core/SkinSetup.lua, sm.cat.* and sm.bonus*). Both carry the approved mockup's colors
        -- (docs/superpowers/specs/2026-11-10-skill-master-mockups).
        -- The rows' in-game icons (Bars > Icons, feedback round 2): shown, their size, how far the
        -- art is cropped each side (the 1.x art's baked-in border; 7 is the old fixed crop), and the
        -- composed border. Its color is the row's own (the meaning color FB-14 chose, so it takes no
        -- skin companion, options-ui-§17) while borderColorFromRow is on; off, the skin's icon border
        -- while borderColorFromSkin is on, else the swatch through its class companion.
        -- borderColorFromRow is off on a new profile (round 7, R7-2); schemaVersion 12 kept the old
        -- true on every profile stored before.
        icons = {
            show                = true,
            size                = 16,
            zoom                = 7,
            border              = true,
            borderStyle         = "Solid",
            borderSize          = 1,
            borderColor         = { 0.24, 0.22, 0.20, 1 },
            useClassColorBorder = false,
            borderStyleFromSkin = true,
            borderColorFromRow  = false,
            borderColorFromSkin = true,
        },
        bars = {
            height        = 14,          -- a row's bar, px
            tooltipHeight = 8,           -- the bar inside the main window's row tooltip
            tooltipRowHeight = 14,       -- that bar's line in the row tooltip
            -- The LDB (broker) tooltip's bars (and the journal's) and its lines: a little over the
            -- old 6 and 14, under the window's 14 and 20 (feedback round 2).
            miniHeight    = 10,
            brokerRowHeight = 18,
            rowHeight     = 20,          -- one skill or stat row (the detached blocks' too)
            fontSize      = 11,          -- the bar text, before the skin's HUD scale
            textAnchor    = "CENTER",    -- "LEFT" | "CENTER" | "RIGHT"
            fillDirection = "LEFT",      -- the edge the fill grows from: "LEFT" (left to right) | "RIGHT"
            -- What every skill and stat row draws: "both" (bar and value), "bar" (no value text)
            -- or "text" (the value alone, no bar). The Bars page's Rows show.
            rowDisplay    = "both",
            -- The bar text; tokens {rank} {bonus} {max} {pct} {left} (modules/Bar.lua Bar.Text).
            textTemplate  = "{rank} {bonus} / {max}",
            spark         = false,       -- a thin line riding the end of the fill (off: feedback round 2)
            -- Color mode By category only: a profession's fill split per rank tier (Apprentice 0-75,
            -- Journeyman 75-150, Expert 150-225, Artisan 225-300) on a scale to 300 whatever the cap,
            -- each tier a darker shade of the category's color (modules/Bar.lua Bar.TierShade). The
            -- tier ticks it replaced are gone (feedback round 2; schemaVersion 4 drops `ticks`).
            tierColors    = false,
            -- A stat's threshold markers (hit cap, resist cap), one switch per surface (owner feedback
            -- round 6, R6-4): off on the window's bars (the detached and merged windows', the LDB
            -- tooltip's and the journal's too), on in the row tooltip's bar and lines. schemaVersion 7
            -- carried a stored `markers = false` to both.
            markersWindow  = false,
            markersTooltip = true,
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
            -- Show border: off by default (feedback round 2, FB-10). No migration: AceDB strips a
            -- stored value equal to the old default (true), so no profile can carry it as a choice.
            border              = false,
            borderStyle         = "Solid",
            borderSize          = 1,
            borderColor         = { 0.24, 0.22, 0.20, 1 },
            useClassColorBorder = false,
            -- Off by default, unlike every other companion (feedback round 2, the owner's ruling):
            -- under a skin stating a real bar border (Azeroth, High Contrast, WoW Midnight) the
            -- companion on would draw that edge over Show border off. A documented deviation from
            -- options-ui-§16 (docs/ARCHITECTURE.md). No migration: AceDB stripped a stored true.
            borderStyleFromSkin = false,
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
        -- written by modules/Journal.lua alone), the log's length per character, the Log tab's
        -- range (FB-32) and the Alts sub-tab on open (a block id, NS.BLOCKS; FB-33).
        journal = { point = false, size = false, keep = 500, range = "all", filter = "primary" },   -- range: All time (round 4)
        -- The Tooltips page (owner feedback round 4): each tooltip's own bar width and font size. Its
        -- bar and row heights stay at bars.tooltipHeight / tooltipRowHeight (the main window's) and
        -- bars.miniHeight / brokerRowHeight (the LDB tooltip's), their rows moved to that page.
        tooltips = {
            row = { barWidth = 200, fontSize = 12 },   -- the tooltip of a main window or detached row
            -- The LDB (broker) tooltip. style (round 6, R6-10): "window", drawn as the main window (its
            -- own frame, the window's headers, rows, bars and fonts; width and height its own, the main
            -- window's default size to start), or "classic", the tooltip lines with mini bars (barWidth,
            -- 128 keeps its old 380 px, and fontSize, read by that style only). A new profile starts on
            -- "window"; schemaVersion 8 kept every profile that existed before on "classic".
            ldb = { style = "window", width = 420, height = 560, barWidth = 128, fontSize = 12 },
        },
        -- T5.1 the Trainers and Waypoints page (modules/Waypoints.lua, modules/TrainerPopup.lua).
        waypoints = {
            -- "auto" (the map pin, else chat) | "chat". Round 7, R7-7: no TomTom; schemaVersion 11
            -- folded a stored "tomtom" or "native" into "auto".
            method   = "auto",
            announce = true,     -- say in chat where a waypoint was set
            -- Round 6, R6-11: the native pin comes with Skill Master's own arrow
            -- (modules/WaypointArrow.lua) and is not super-tracked; off, the client's arrow again.
            arrow      = true,
            arrowScale = 1,      -- the arrow frame's scale (0.5 .. 2)
            -- Drag-only geometry, no control sets it: written by modules/WaypointArrow.lua alone
            -- (architecture-§5's named-owner rule; docs/ARCHITECTURE.md names the writer).
            arrowFrame = { point = false },
        },
        trainers = {
            unverified = true,   -- mark trainer data not yet checked on WoW Forever
            -- The trainer popup's trainer name (feedback round 2, FB-11): the skin's accent while
            -- nameColorFromSkin is on (the default, skinning-§6), else the swatch through its
            -- class-color companion (options-ui-§17). The swatch starts on WoW Forever's tan accent.
            nameColor         = { 0.788, 0.627, 0.478, 1 },
            useClassColorName = false,
            nameColorFromSkin = true,
        },
        skin = {
            source      = "ka0s",                     -- Ka0s skins, or EllesmereUI
            skin        = NS.DEFAULT_SKIN or "ka0s",  -- the library's per-client default: WoW Forever here
            ignorePanel = true,                       -- skinning-§3: the settings panel keeps the client look by default
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
            -- Which weapons the gap alert reads (owner feedback round 3): "untrained" skips a weapon
            -- still at A.UNTRAINED points or fewer (never really used), "equipped" reads only the
            -- weapons equipped now, "all" every learned weapon. weaponMuted: weapons never alerted.
            weaponMode  = "untrained",
            weaponMuted = {},
            sound     = false,  -- play the toast's sound as each alert shows
            -- The skill-up toast (owner feedback round 4): on by default, for "all" skills,
            -- "professions" (primary and secondary) or "combat" (weapon and Other); its own sound.
            skillUp      = true,
            skillUpScope = "all",
            skillUpSound = false,
            point     = false,  -- the toast stack's drop point, in UIParent's units
        },
        -- The one broker data feed, "Skill Master" (modules/Broker.lua, design §6.7; feedback round
        -- 2, FB-12). Tokens: modules/Template.lua. schemaVersion 3 carried a stored
        -- `broker.templates.all` here and dropped the other three feeds' templates (core/Database.lua).
        broker = {
            flashSeconds = 5,   -- how long "^ Bows 81" replaces the feed's text after a skill-up
            template     = "{pinned} \194\183 +{gains}",
            -- The feed's tooltip: its sections, the rows it leaves out (sets of keys, apart from the
            -- main window's skills.hidden / stats.hidden) and whether it wears the skin (FB-13).
            tooltip = {
                skin     = true,
                -- The skills feed's four sections and the stats feed's four (round 6, R6-9: the Stats
                -- section moved to its own feed; schemaVersion 9 dropped a stored `stats`).
                sections = { primary = true, secondary = true, weapon = true, other = true,
                             stats_base = true, stats_spell = true, stats_defense = true, stats_utility = true },
                hiddenSkills = {},
                hiddenStats  = {},
            },
        },
    },
    -- 0, never the current version: AceDB strips a value equal to its default at logout
    -- (savedvariables-§1). `minimap` is LibDBIcon's own table (launcher-§3), per installation.
    -- `characters` is the alt overview's store (modules/Alts.lua), keyed "<realm>-<name>".
    global = { schemaVersion = 0, minimap = { hide = false }, characters = {} },
    -- Per character: the pinned skill the broker's {pinned} token shows (design §7), set from the
    -- row menu (T3.3), and the session log's ring (modules/SessionLog.lua).
    -- pinnedStat (round 6, R6-9): the stat the Skill Master Stats feed shows, from a stat row's menu.
    char = { pinned = false, pinnedStat = false, log = {} },
}
