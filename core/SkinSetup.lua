local addonName, NS = ...
-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam (skinning): registers this addon as a skin owner
-- at file load, publishes NS.Skin, and holds the stored choice, the first-run skin picker and the
-- `skin` verb's act.
--
-- LOAD-BEARING: RegisterOwner runs at FILE LOAD, before EllesmereUI dispatches; NS.DEFAULT_SKIN is
-- read by defaults/Profile.lua and the option lists by settings/General.lua, both at file load.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local OUTLINE_PATH = "skin.outline"
local PICKER_PATH = "skin.pickerSeen"
local DEFAULT = "ka0s"

-- The library answers the per-client default (skinning-§2): WoW Forever on this client. The addon
-- never asks which client it is on.
NS.DEFAULT_SKIN = (Skin and type(Skin.DefaultSkin) == "function") and Skin:DefaultSkin() or DEFAULT

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}
NS.SKIN_OUTLINE_OPTIONS = {
    { value = "all", text = "All text" },
    { value = "hud", text = "HUD text only" },
    { value = "off", text = "Off" },
}
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

-- This addon's own tokens. The skill bars (T3.1) read them; each follows a library token so every
-- skin dresses them without knowing this addon.
NS.SKIN_OWNER_TOKENS = {
    ["sm.barFill"]   = { default = { 0.27, 0.59, 0.90, 1 }, follow = "bar.fill" },
    ["sm.barBg"]     = { default = { 0.19, 0.20, 0.25, 0.9 }, follow = "bar.bg" },
    ["sm.bonusTemp"] = { default = { 0.95, 0.75, 0.20, 1 }, follow = "sem.warn" },
    ["sm.bonusPerm"] = { default = { 0.35, 0.75, 0.43, 1 }, follow = "sem.good" },
    -- T3.1 the bar's edges, tier ticks, threshold markers, spark and text; the row's timer, icon
    -- well and the unlearned row's muted line. The category and bonus colors a player picks live
    -- in the profile (defaults/Profile.lua, bars.colors); these are what every skin draws.
    ["sm.barBorder"] = { default = { 0.24, 0.22, 0.20, 1 }, follow = "bar.border" },
    ["sm.tick"]      = { default = { 1, 1, 1, 0.45 }, follow = "chart.marker" },
    ["sm.marker"]    = { default = { 0.95, 0.70, 0.24, 1 }, follow = "hud.label" },
    ["sm.spark"]     = { default = { 1, 1, 1, 0.6 }, follow = "hud.text" },
    ["sm.barText"]   = { default = { 1, 1, 1, 1 }, follow = "hud.text" },
    ["sm.timer"]     = { default = { 0.50, 0.85, 0.77, 1 }, follow = "sem.info" },
    ["sm.iconBg"]    = { default = { 0.04, 0.035, 0.03, 1 }, follow = "card.bg" },
    ["sm.muted"]     = { default = { 0.64, 0.62, 0.59, 1 }, follow = "text.muted" },
}

local function stored(path)
    if not (NS.db and NS.GetSetting) then return nil end
    return NS.GetSetting(path)
end

local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The stored skin choice: source, skin.
function NS.SkinChoice()
    return stored(SOURCE_PATH) or DEFAULT, stored(SKIN_PATH) or NS.DEFAULT_SKIN
end

--- The owner's writer: every part goes through the single write seam (architecture-§5).
function NS.WriteSkinChoice(source, skin, ignore, media)
    local set = NS.SetByPath
    if not (NS.db and set) then return end
    if source ~= nil then set(SOURCE_PATH, source) end
    if skin ~= nil then set(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        set(PANEL_PATH, ignore.panel == true)
        set(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        set(FONT_PATH, storedKey(media.font))
        set(TEXTURE_PATH, storedKey(media.texture))
        if media.outline ~= nil then set(OUTLINE_PATH, media.outline) end
    end
end

-- ---------------------------------------------------------------------------------------------
-- The skin picker: first run on a fresh profile, and the `skin` verb (skinning-§3, §10).
-- Its preview is the test mode, the first of test / unlock / window / console this addon has.
-- ---------------------------------------------------------------------------------------------

local quietClose = false

local function pickerSpec()
    return {
        owner   = addonName,
        get     = NS.SkinChoice,
        set     = NS.WriteSkinChoice,
        page    = "general",
        tab     = "Appearance",
        preview = {
            mode     = "test",
            isActive = function() return NS.IsTestMode() end,
            isShown  = function() return NS.IsTestMode() end,
            enter    = function() if not NS.IsTestMode() then NS.ToggleTestMode() end end,
            exit     = function() if NS.IsTestMode() then NS.ToggleTestMode() end end,
        },
        onClose = function()
            if quietClose or not (NS.db and NS.SetByPath) then return end
            NS.SetByPath(PICKER_PATH, true)
        end,
    }
end
NS.SkinPickerSpec = pickerSpec

--- Take the picker down without marking it seen (a stand-down, a profile switch).
function NS.HideSkinPicker()
    local O = NS.Helpers
    if not (O and type(O.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(O.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- Show the first-run picker when this profile has not closed it yet. Never in combat, never
--- while stood down. Answers the window or nil.
function NS.MaybeShowSkinPicker()
    local O = NS.Helpers
    if not (O and type(O.SkinPicker) == "function" and NS.db) then return nil end
    if NS.IsStoodDown() or NS.GetSetting(PICKER_PATH) == true then
        NS.HideSkinPicker()
        return nil
    end
    if InCombatLockdown() then return nil end
    return O.SkinPicker(pickerSpec())
end

--- The `skin` verb's act (slash-commands-§2): the library's SkinVerb, or one honest line.
function NS.RunSkinVerb()
    local O = NS.Helpers
    local win, why
    if O and type(O.SkinVerb) == "function" then
        win, why = O.SkinVerb(pickerSpec())
    else
        why = "absent"
    end
    if win == nil and why == "absent" then
        NS.Print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format("/skm skin"))
    end
    return win, why
end

if not Skin then
    -- Degrade, never error: an owner facade answering every member this addon calls, inert.
    local noop = function() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture", "Mark", "HudTextColor", "HudLabelColor", "BarFillColor", "HudShadow", "BarGloss",
        "HoverArt", "Band", "Header",
    }) do S[name] = noop end
    S.Token = function() return nil end
    S.Color = function() return nil end
    S.Resolve = function(_, value)
        if value == S.FROM_SKIN then return nil end
        return value
    end
    S.FontFlags = function(value)
        if type(value) == "string" and value ~= S.FROM_SKIN then return value end
        return "OUTLINE"
    end
    S.HudFontSize = function(size)
        local n = tonumber(size)
        return (n and n > 0) and n or 12
    end
    S.MarkText = function(path, size)
        size = size or 14
        return ("|T%s:%d:%d|t"):format(path, size, size)
    end
    S.HudFont = noop
    S.BarBorder = function(style, show, size) return style, show, size end
    S.OnLooksChanged = function(fn) return fn end
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end
    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    function NS.ApplySkinOutline() return false end
    function NS.SkinPaintAceTree() return 0 end
    return
end

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = NS.Constants.BRAND,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_OWNER_TOKENS,
})

-- A skin switch is a layout change for the blocks and bars (T3.x repaint on it).
NS.Skin.OnLooksChanged(function()
    if NS.bus and NS.MSG then NS.bus:SendMessage(NS.MSG.LAYOUT_CHANGED) end
end)

function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

local RELOAD_LINE = "Reload your interface (/reload) to finish changing the skin."
local KNOWN = {}
for _, opt in ipairs(NS.SKIN_OPTIONS) do KNOWN[opt.value] = true end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = stored(PANEL_PATH) == true, stored(FONTS_PATH) == true end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload then NS.Print(RELOAD_LINE) end
    return changed, reload
end

function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then
        font, texture = storedKey(stored(FONT_PATH)), storedKey(stored(TEXTURE_PATH))
    end
    if font == "" then font = false end
    if texture == "" then texture = false end
    return Skin:SetOverride(addonName, font, texture)
end

function NS.ApplySkinOutline(mode)
    if type(Skin.SetOutline) ~= "function" then return false end
    if mode == nil then mode = stored(OUTLINE_PATH) end
    return Skin:SetOutline(addonName, mode)
end

--- Apply the stored choice (no arguments: the whole choice, Scope and media included).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    if skin ~= nil and not KNOWN[skin] then skin = NS.DEFAULT_SKIN end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
        NS.ApplySkinOutline()
    end
    return changed, reload
end
