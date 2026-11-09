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
        -- T3.1 the bar widget's look (modules/Bar.lua). The colors are the player's picks; with
        -- `colors.fromSkin` they give way to the skin's owner tokens (core/SkinSetup.lua). The
        -- defaults are the approved mockup's (docs/superpowers/specs/2026-11-10-skill-master-mockups).
        bars = {
            height        = 14,          -- a row's bar, px
            compactHeight = 11,          -- a detached block's compact bar
            tooltipHeight = 8,           -- the bar inside a row tooltip
            miniHeight    = 6,           -- the journal's and the broker tooltip's mini bars
            rowHeight     = 20,          -- one skill or stat row
            fontSize      = 11,          -- the bar text, before the skin's HUD scale
            textAnchor    = "CENTER",    -- "LEFT" | "CENTER" | "RIGHT"
            spark         = true,        -- a thin line riding the end of the fill
            ticks         = true,        -- profession tier ticks (75 / 150 / 225)
            border        = true,        -- a 1 px edge around each bar
            colorMode     = "category",  -- "category" | "progress" | "likelihood" | "flat"
            colors = {
                fromSkin  = false,
                primary   = { 0.357, 0.608, 0.878, 1 },
                secondary = { 0.373, 0.702, 0.427, 1 },
                weapon    = { 0.851, 0.569, 0.247, 1 },
                other     = { 0.627, 0.549, 0.878, 1 },
                stats     = { 0.788, 0.627, 0.478, 1 },
                bonusTemp = { 0.498, 0.847, 0.769, 1 },
                bonusPerm = { 0.553, 0.722, 1, 1 },
            },
        },
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
    },
    -- 0, never the current version: AceDB strips a value equal to its default at logout
    -- (savedvariables-§1). `minimap` is LibDBIcon's own table (launcher-§3), per installation.
    global = { schemaVersion = 0, minimap = { hide = false } },
}
