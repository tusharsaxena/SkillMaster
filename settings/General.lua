local addonName, NS = ...
-- settings/General.lua — the landing page spec and the General page: Master controls, the Skin tab
-- and the Keybindings tab (options-ui-§13/§15/§20, skinning-§3).
--
-- LOAD-BEARING: registers FIRST among the pages, because page order is registration order.
local H = NS.Helpers
local L = NS.L
local C = NS.Constants
local P = NS.defaults.profile

-- The landing page (options-ui-§5): logo, tagline and the slash list, drawn by the library.
NS.LANDING = {
    logo     = C.LOGO_PATH,
    notes    = function() return NS.Meta("Notes") or "" end,
    sections = { {
        heading = L["Slash Commands"],
        rows    = function() return NS.Slash:LandingRows() end,
    } },
}

-- The global reset's confirmation (options-ui-§12).
StaticPopupDialogs.SKILLMASTER_RESET_ALL = {
    text         = L["Reset this profile to the addon's defaults? Everything you have configured in it is discarded \226\128\148 your other profiles are not affected."],
    button1      = YES,
    button2      = NO,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        NS.Helpers.RestoreAllDefaults()
        NS.Print(L["All settings reset to defaults."])
    end,
}
local function confirmResetAll() StaticPopup_Show("SKILLMASTER_RESET_ALL") end

-- ---------------------------------------------------------------------------------------------
-- Master controls: one declaration, composed by the library (options-ui-§15). No General
-- visibility row: the window is opened by the player, never shown by a combat state.
-- ---------------------------------------------------------------------------------------------
local DEBUG_CONSOLE_PATH = "state.debugConsole"
local TEST_MODE_PATH     = "state.testMode"

local masterRows, masterTail = H.MasterControls({
    prefix           = "",
    page             = "general",
    addonName        = C.BRAND,
    debugConsolePath = DEBUG_CONSOLE_PATH,
    minimapPath      = C.MINIMAP_PATH,
    testModePath     = TEST_MODE_PATH,
    -- The simulator's pair, the same the launcher descriptor carries (options-ui-§15): the
    -- composer draws a session-only Sim mode row beside Test mode.
    isSimMode        = function() return NS.IsSimMode() end,
    toggleSim        = function() NS.ToggleSim() end,
    omit             = { visibility = true },
    defaults         = { enabled = P.enabled, scale = P.scale, alpha = P.alpha, locked = P.locked },
    notes            = {
        scale  = L["Scales the Skill Master window."],
        alpha  = L["Opacity of the Skill Master window."],
        locked = L["Locks the Skill Master window in place."],
    },
    onResetPosition  = function() NS.MainWindow.ResetPosition() end,
    onResetAll       = confirmResetAll,
})

-- The reactions, also reached by a write-through on a hollow load (settings/Schema.lua announce).
NS.MasterReactions = {
    enabled = function() NS.SyncEnabledHold() end,
    scale   = function() NS.MainWindow.ApplySettings() end,
    alpha   = function() NS.MainWindow.ApplySettings() end,
    locked  = function() NS.MainWindow.ApplySettings() end,
}

local function minimapStore()
    local g = NS.db and NS.db.global
    return type(g) == "table" and g.minimap or nil
end

local consoleCheckbox = NS.DebugLog:ConsoleCheckbox()
local rowStorage = {
    -- The label says shown, LibDBIcon's key says hidden: inverted here, once (launcher-§3).
    [C.MINIMAP_PATH] = {
        get = function() local t = minimapStore() return not (t and t.hide) end,
        set = function(v)
            local t = minimapStore()
            if t then t.hide = not v end
            NS.Launcher:SetShown(v and true or false)
        end,
    },
    [DEBUG_CONSOLE_PATH] = consoleCheckbox,
    [TEST_MODE_PATH] = {
        get = function() return NS.IsTestMode() end,
        set = function(v) if (v and true or false) ~= NS.IsTestMode() then NS.ToggleTestMode() end end,
    },
}

for _, row in ipairs(masterRows) do
    row.onChange = NS.MasterReactions[row.path]
    local storage = rowStorage[row.path]
    if storage then row.get, row.set = storage.get, storage.set end
end
NS.RegisterSchemaRows(masterRows)

-- ---------------------------------------------------------------------------------------------
-- The skin choice: stored rows the Skin tab writes through NS.WriteSkinChoice (skipRender: the
-- tab draws them).
-- ---------------------------------------------------------------------------------------------
local SKIN = "Appearance"
local SD = P.skin
NS.RegisterSchemaRows({
    { path = "skin.source", page = "general", group = SKIN, skipRender = true,
      type = "string", widget = "Dropdown", values = NS.SKIN_SOURCE_OPTIONS, default = SD.source,
      label = L["Skin source"],
      desc = L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."],
      onChange = function(v) NS.ApplySkinChoice(v, nil) end },
    { path = "skin.skin", page = "general", group = SKIN, skipRender = true,
      type = "string", widget = "Dropdown", values = NS.SKIN_OPTIONS, default = SD.skin,
      label = L["Skin"],
      desc = L["The Ka0s skin this addon wears. Changes the window, the tool windows and the settings pages right away."],
      onChange = function(v) NS.ApplySkinChoice(nil, v) end },
    { path = "skin.ignorePanel", page = "general", group = SKIN, skipRender = true,
      type = "bool", default = SD.ignorePanel, label = L["Ignore settings panel"],
      desc = L["Keep this addon's settings panel in the game's own look. Its other surfaces still wear the skin."],
      onChange = function(v) NS.ApplySkinIgnore(v, nil) end },
    { path = "skin.ignoreFonts", page = "general", group = SKIN, skipRender = true,
      type = "bool", default = SD.ignoreFonts, label = L["Ignore fonts"],
      desc = L["Keep every font in this addon as the game draws it. The skin still colors the text."],
      onChange = function(v) NS.ApplySkinIgnore(nil, v) end },
    { path = "skin.font", page = "general", group = SKIN, skipRender = true,
      type = "string", default = SD.font, label = L["Font"],
      desc = L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."],
      onChange = function(v) NS.ApplySkinOverride(v, nil) end },
    { path = "skin.texture", page = "general", group = SKIN, skipRender = true,
      type = "string", default = SD.texture, label = L["Texture"],
      desc = L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."],
      onChange = function(v) NS.ApplySkinOverride(nil, v) end },
    { path = "skin.outline", page = "general", group = SKIN, skipRender = true,
      type = "string", widget = "Dropdown", values = NS.SKIN_OUTLINE_OPTIONS, default = SD.outline,
      label = L["Font outline"],
      desc = L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."],
      onChange = function(v) NS.ApplySkinOutline(v) end },
    { path = "skin.pickerSeen", page = "general", group = SKIN, skipRender = true,
      type = "bool", default = SD.pickerSeen, label = L["Skin picker seen"],
      desc = L["Whether the first-run skin picker was closed on this profile."] },
})

local TABS = { tabs = {
    H.AppearanceTab({ owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice }),
    H.KeybindingsTab({ bindings = NS.BINDINGS }),
} }

local function build(mainCategory)
    local ctx = H.CreatePanel("SkillMasterGeneralPanel", "General", {
        pageKey         = "general",
        defaultsButton  = true,
        defaultsTooltip = H.ResetAllTooltip(H.KEYBINDS_UNCHANGED),
    })
    ctx.panel.defaultsOnClick = confirmResetAll
    H.SetRenderer(ctx, function(c)
        H.ClearScroll(c)
        H.RenderTabbedSchema(c, "general", { [H.MASTER_GROUP] = masterTail }, nil, TABS)
    end)
    return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, "General")
end

NS.RegisterOptionsPage("general", "General", build)
