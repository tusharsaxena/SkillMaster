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

-- ---------------------------------------------------------------------------------------------
-- The live apply (T5.1): every display row's onChange. One LAYOUT_CHANGED per write repaints the
-- window, the detached blocks, the journal and the Bars page's preview (modules/Blocks.lua); a
-- bulk reset (a page's Defaults, Reset all settings) coalesces into one, on the next frame.
-- ---------------------------------------------------------------------------------------------
local pending = false

local function sendLayout()
    pending = false
    if NS.bus and NS.MSG then NS.bus:SendMessage(NS.MSG.LAYOUT_CHANGED) end
end

function NS.ApplyLook()
    -- Stood down, nothing is on screen and nothing may stay armed (slash-commands-§7); the stand-up
    -- repaints from the stored values.
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    local S = NS.SchemaRuntime
    if not (S and S.InBulk and S.InBulk()) then return sendLayout() end
    if pending then return end
    pending = true
    if NS.addon and NS.addon.ScheduleTimer then NS.addon:ScheduleTimer(sendLayout, 0) else sendLayout() end
end

--- Stamp `onChange` (default NS.ApplyLook) on every row of `rows` that has none; answers `rows`.
function NS.Live(rows, onChange)
    for _, row in ipairs(rows) do
        if row.onChange == nil then row.onChange = onChange or NS.ApplyLook end
    end
    return rows
end

-- ---------------------------------------------------------------------------------------------
-- A text template as a presets dropdown plus "Custom" (feedback round 1, FB-2). A template row
-- used to be a bare `type = "string"` row, which the library draws as a dropdown with nothing in it
-- (LibKa0s Options' EMPTY_DROPDOWN). Two rows now stand for one stored template:
--
--   the picker  `presetPath`, session-only (nothing stored): its get answers the preset the stored
--               template matches, else "custom"; its set writes the preset's template through
--               NS.SetByPath, or, for "custom", remembers the choice for the session and writes
--               nothing.
--   the box     `path`, the stored template itself, drawn as an EditBox (`dialogControl`) and only
--               while the picker reads "custom" (`shownWhen`, the library's switched sections).
--
-- The stored value is still the template string, so no SavedVariables shape changes: a string
-- matching no preset reads as Custom, with its text in the box.
-- ---------------------------------------------------------------------------------------------
NS.CUSTOM_PRESET = "custom"
local customChosen = {}   -- [path] = true once the player picks Custom this session

local function presetOf(presets, value)
    for _, p in ipairs(presets) do
        if p.value == value then return p.value end
    end
    return nil
end

local function presetPicker(spec)
    local values = {}
    for i, p in ipairs(spec.presets) do values[i] = { value = p.value, text = p.text } end
    values[#values + 1] = { value = NS.CUSTOM_PRESET, text = NS.L["Custom"] }
    return {
        path = spec.presetPath, page = spec.page, group = spec.group, subgroup = spec.subgroup,
        type = "string", sessionOnly = true, wide = true, values = values,
        default = spec.default, label = spec.label, desc = spec.desc,
        get = function()
            if customChosen[spec.path] then return NS.CUSTOM_PRESET end
            return presetOf(spec.presets, NS.GetSetting(spec.path)) or NS.CUSTOM_PRESET
        end,
        set = function(v)
            if v == NS.CUSTOM_PRESET then
                customChosen[spec.path] = true
                return
            end
            customChosen[spec.path] = nil
            -- A reset (a page's Defaults, Reset all settings) writes the box row's own default in
            -- the same walk; the picker only lets go of a Custom choice there.
            local S = NS.SchemaRuntime
            if S and S.InBulk and S.InBulk() then return end
            NS.SetByPath(spec.path, v)
        end,
        -- The write above runs the box row's own onChange; the picker repaints nothing itself.
        onChange = function() end,
    }
end

--- The two rows of one template setting. `spec` = { path, presetPath, page, group, subgroup,
--- default, label, desc, boxDesc, presets = { { value = <template>, text = <label> }, ... } }; the
--- default must be one of the presets, so a fresh profile reads as that preset.
function NS.TemplateRows(spec)
    assert(presetOf(spec.presets, spec.default), "the default template is one of the presets: " .. spec.path)
    return {
        presetPicker(spec),
        { path = spec.path, page = spec.page, group = spec.group, subgroup = spec.subgroup, type = "string",
          dialogControl = "EditBox", wide = true, default = spec.default, label = NS.L["Custom text"],
          desc = spec.boxDesc, shownWhen = { path = spec.presetPath, equals = NS.CUSTOM_PRESET } },
    }
end

--- Forget this session's Custom choices (the suites start each case from the stored values).
function NS.ForgetCustomTemplates()
    for k in pairs(customChosen) do customChosen[k] = nil end
end

--- A schema page: a canvas subcategory drawn as a tab strip over its rows' groups (options-ui-§13),
--- its Defaults button restoring the page. `spec` = { tabs, header, beforeRender, defaultsTooltip }:
--- `tabs` the host tabs (RenderTabbedSchema's opts.tabs), `header` a PageHeader spec drawn above the
--- strip, `beforeRender(ctx)` run before the first widget of a render (a reorder list's Cancel).
function NS.RegisterSchemaPage(key, title, spec)
    spec = spec or {}
    NS.RegisterOptionsPage(key, title, function(mainCategory)
        local H = NS.Helpers
        local ctx = H.CreatePanel("SkillMaster" .. key:gsub("^%l", string.upper) .. "Panel", title, {
            pageKey         = key,
            defaultsButton  = true,
            defaultsTooltip = spec.defaultsTooltip
                or NS.L["Restore every setting on this page to its default, on this profile."],
        })
        ctx.panel.defaultsOnClick = function() H.RestoreDefaults(key, ctx) end
        H.SetRenderer(ctx, function(c)
            if spec.beforeRender then spec.beforeRender(c) end
            H.ClearScroll(c)
            if spec.header then H.PageHeader(c, spec.header) end
            H.RenderTabbedSchema(c, key, nil, nil, { tabs = spec.tabs })
        end)
        return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, title)
    end)
end

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

    -- Colors are stored positionally, { r, g, b, a } (defaults/Profile.lua, NS.Bar reads c[1]..c[4]);
    -- a keyed table is still read, so a hand-edited value draws.
    colorDecode = function(c)
        c = type(c) == "table" and c or {}
        return c[1] or c.r or 1, c[2] or c.g or 1, c[3] or c.b or 1, c[4] or c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r, g, b, a or 1 } end,

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
    local MISSING = NS.L["%s, so the settings panel is unavailable."]:format(NS.LIBKA0S_MISSING)
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
    H.AppearanceTab      = function() return { key = "Appearance", label = NS.L["Skin"], render = function() end } end
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
