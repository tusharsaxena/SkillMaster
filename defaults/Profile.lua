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
