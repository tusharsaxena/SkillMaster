local addonName, NS = ...
-- settings/OptionsSetup.lua — the settings panel descriptor (LibKa0s-Options-1.0, options-ui-§1).
-- NS.Helpers IS the library instance, decorated in place.
--
-- LOAD-BEARING: publishes NS.Helpers and NS.RegisterOptionsPage, which every settings/<Page>.lua
-- calls at file load, so it loads after settings/Slash.lua and before every page file.

-- Named ONCE: the Profiles page, the minimap row and every profile-backed row are vetoed from the
-- walk; the global reset IS a profile reset (options-ui-§12), so the walk keeps only session rows.
local function vetoedFromResetAll(row)
    if row.path == NS.Constants.MINIMAP_PATH then return true end
    if row.page == "profiles" then return true end
    return not row.sessionOnly
end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

local descriptor = {
    parentTitle   = NS.Constants.BRAND,
    mainPanelName = "SkillMasterMainPanel",
    addonName     = addonName,   -- the FOLDER (library-stack-§8), never a display label

    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) return NS.SetByPath(path, value) end,
    applyDefault = function(row) return NS.ApplyDefault(row) end,
    allRows      = function() return NS.Schema end,
    rowsForPage  = function(pageKey) return NS.SchemaForPage(pageKey) end,

    skipRestoreAll = vetoedFromResetAll,
    resetProfile   = function()
        local db = NS.db
        if db and db.ResetProfile then NS.ResetProfileCounted(db) end
    end,
    profilesPage = true,
    bulkBegin    = NS.SchemaRuntime.BulkBegin,
    bulkEnd      = NS.SchemaRuntime.BulkEnd,

    colorDecode = function(c)
        c = type(c) == "table" and c or {}
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,

    -- The landing body is the library's (options-ui-§5); NS.LANDING is declared in General.lua.
    buildMain     = function(ctx) NS.Helpers.BuildLandingPage(ctx, NS.LANDING) end,
    getLSM        = function() return LibStub("LibSharedMedia-3.0", true) end,
    scheduleTimer = function(fn, delay) return NS.addon:ScheduleTimer(fn, delay) end,
    validate      = function() NS.ValidateSchema() end,
    onAceGUI      = function(AceGUI) NS.AceGUI = AceGUI end,
    print         = function(line) NS.Print(line) end,
    debug         = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
}

if not lib then
    -- The LOAD-COMPLETING stub (options-ui-§1): every member a page file touches at load, the
    -- composers hollow ({}), the global reset real, everything else a no-op or one honest line.
    local MISSING = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."
    local H = {}
    NS.Helpers = H
    H.LSMValues = function() return function() return {} end end
    for _, name in ipairs({ "ColorPair", "FontGroup", "BorderGroup", "BarGroup" }) do
        H[name] = function() return {} end
    end
    H.MasterControls = function() return {}, function() end end
    H.RestoreAllDefaults = function()
        NS.SchemaRuntime.BulkRun("reset", "all", function(info)
            for _, row in ipairs(NS.Schema) do
                if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end
            end
            if NS.db and NS.db.ResetProfile then
                NS.ResetProfileCounted(NS.db)
                info.profileReset = true
            end
        end)
    end
    for _, name in ipairs({
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section", "AddSpacer",
        "AttachTooltip", "InlineButtonPair", "RenderField", "RenderGrid", "RenderRows", "RenderSchema",
        "SessionCheckbox", "RefreshAllPanels", "RestoreDefaults", "PatchAlwaysShowScrollbar",
        "SetRenderer", "SetChromeHeight", "TabStrip", "PageHeader", "RenderTabbedSchema",
        "ChoiceGrid", "IdInput", "IdList", "SelectTab", "NavRail", "LabelFont", "HideSkinPicker",
        "RefreshScalars",
    }) do
        H[name] = function() end
    end
    H.ResolveId          = function() return nil end
    H.UnnamedCandidates  = function() return nil end
    H.ID_NAME_HINT       = {}
    H.KeybindingsTab     = function() return nil end
    H.KeybindRows        = function() return nil end
    H.KEYBINDS_UNCHANGED = ""
    H.StrataTooltip      = function() return "" end
    H.ResetAllTooltip    = function(tail) return type(tail) == "string" and tail or "" end
    H.AppearanceTab      = function() return { key = "Appearance", label = "Skin", render = function() end } end
    H.AppearanceRows     = function() return nil end
    H.SkinPicker         = function() return nil end
    H.SkinVerb           = function() return nil, "absent" end
    H.SkinNotice         = function() return nil, "unavailable" end
    H.PositionBlock      = function() return {}, function() end end
    H.__panels           = function() return {} end
    H.__panelFor         = function() return nil end
    NS.RegisterOptionsPage = function() end
    NS.CreateOptionsPanel  = function() NS.Print(MISSING) end
    NS.OpenOptionsPanel    = function() NS.Print(MISSING) end
    return
end

NS.Helpers = lib:New(descriptor)
local H = NS.Helpers
NS.RegisterOptionsPage = function(key, name, builder) H.RegisterOptionsPage(key, name, builder) end
NS.CreateOptionsPanel  = function() H.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() H.OpenOptionsPanel() end   -- the `config` verb and left-click
