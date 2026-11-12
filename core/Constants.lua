local addonName, NS = ...
-- core/Constants.lua — the brand, the logo paths, the monospace face and the one layers table.
NS.Constants = NS.Constants or {}
local C = NS.Constants

-- The brand in plain text (launcher-§1): the LDB label, the disabled line's subject, the Options
-- parent title and the diagnostics markers. Never the TOC ## Title, never the folder name.
C.BRAND = "Ka0s Skill Master"

-- A real client font as the last rung, never nil (debug-logging-§2).
C.FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
C.FONT_MONO_NAME = "JetBrains Mono"
C.FONT_MONO = NS.MediaFont and NS.MediaFont(C.FONT_MONO_NAME) or C.FALLBACK_FONT

-- The landing page's logo (300x300) and the icon-sized one (128x128, uncompressed 32-bit) that is
-- also the TOC's ## IconTexture, the minimap button and the broker icon (layout-§4, launcher-§4).
C.LOGO_PATH = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga"):format(addonName, addonName:lower())
C.LOGO_ICON_PATH = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga")
    :format(addonName, addonName:lower())

-- The minimap button's visibility as the CLI path reads it (launcher-§3). The stored key stays
-- LibDBIcon's own `global.minimap.hide`; the row's get/set invert onto it.
C.MINIMAP_PATH = "global.minimap.shown"

-- The layers table (frame-layering-§5). Every SetFrameStrata / SetFrameLevel in this addon reads it.
-- This addon's stack, bottom to top (frame-layering-§1 tiers):
--   T1 HUD     a detached block (modules/Detached.lua), MEDIUM by default, the player's pick of
--              STRATA_CHOICES (layout.detachedStrata); its band controls at + CHROME, its rows at
--              + CONTENT
--   T4 window  the main window (modules/MainWindow.lua), MEDIUM by default, the player's pick of
--              STRATA_CHOICES (layout.strata), toplevel, clamped; its title bar,
--              test strip and close control are levels over the window's own (+ OVERLAY, + CHROME);
--              its scrolled body + CONTENT; the crafting rows' secure overlays (modules/SecureOverlay.lua,
--              parented to UIParent) one strata ABOVE their host (STRATA_ABOVE), armed only over the
--              hovered row: a documented frame-layering-§1 deviation (docs/ARCHITECTURE.md), since a
--              toplevel host's raised group outranks any level in its own strata
--   T4 window  the trainer popup (modules/TrainerPopup.lua), HIGH: opened from the window or a
--              detached block, so one strata above the higher of the two (STRATA_ABOVE, never under
--              HIGH: DIALOG over a High pick), toplevel, clamped, closed with the window
-- Library- and Blizzard-owned tiers this addon relies on (frame-layering-§6): the debug console
-- and perf panel DIALOG, toplevel; the copy window FULLSCREEN; menus (the row menu,
-- LibKa0s-Widgets-1.0 ContextMenu) FULLSCREEN_DIALOG; the Settings panel HIGH; GameTooltip TOOLTIP.
C.LAYERS = {
    STRATA = { WINDOW = "MEDIUM", HUD = "MEDIUM", WINDOW_READ = "HIGH" },
    LEVEL  = { CONTENT = 2, OVERLAY = 4, SECURE = 8, CHROME = 10 },
    -- A player-chosen strata offers these four only (frame-layering-§1, player-chosen strata).
    STRATA_CHOICES = { "BACKGROUND", "LOW", "MEDIUM", "HIGH" },
    -- The strata one above each choice: where a popup opened from it sits (frame-layering-§1).
    STRATA_ABOVE = { BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG" },
}
