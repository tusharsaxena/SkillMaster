-- tests/run.lua — Ka0s Skill Master's headless runner: the load list, the lifecycle kick and the
-- suite list, on the vendored kit (tests/_kit/). Run from the repo root, under the Forever profile
-- only (clients-§6): KA0S_KIT_CLIENT=forever lua tests/run.lua

local Kit        = dofile("tests/_kit/framework.lua")
local Loader     = dofile("tests/_kit/loader.lua")
dofile("tests/client_pin.lua")(Loader)   -- Forever-only: every run is the Forever profile (clients-§9)
local buildMocks = dofile("tests/wow_mock.lua")

local mocks = buildMocks()
local NS = {}
Loader.addonName = "SkillMaster"

-- The vendored library, read out of LibKa0s.xml in XML order (the TOC reaches it through that one
-- .xml, which tocFiles cannot see); a short hand list would test stubs and stay green.
local LIB_FILES = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")
-- The addon's own files come from the TOC, so the runner cannot drift from what the client loads.
local ADDON_FILES = Loader.tocFiles("SkillMaster.toc")

Loader.loadAll(LIB_FILES, NS, mocks)
Loader.loadAll(ADDON_FILES, NS, mocks)

-- Mirror the in-game lifecycle: OnInitialize builds the store, applies the skin, registers the
-- slash commands and the settings category.
NS.addon:OnInitialize()
-- The first-run skin picker previews through test mode; the suites that want it open it themselves.
NS.db.profile.skin.pickerSeen = true
NS.HideSkinPicker()

-- The live halves the surface-parity cases compare each degradation stub against.
Kit.setSurfaceSource{
    ["LibKa0s-Options-1.0"]   = NS.Helpers,
    ["LibKa0s-DebugLog-1.0"]  = NS.DebugLog,
    ["LibKa0s-Slash-1.0"]     = NS.Slash,
    ["LibKa0s-Launcher-1.0"]  = NS.Launcher,
    ["LibKa0s-Lifecycle-1.0"] = NS.Lifecycle,
    ["LibKa0s-Bus-1.0"]       = mocks.LibStub("LibKa0s-Bus-1.0", true),
    ["LibKa0s-Schema-1.0"]    = mocks.LibStub("LibKa0s-Schema-1.0", true),
}

_G.SKM_TEST = Kit.expose{
    NS = NS, mocks = mocks, Loader = Loader,
    kit = Kit,   -- the secret-value simulator (Kit.secret, Kit.installSecretValue)
    loadedAddonFiles = ADDON_FILES,
    loadedLibFiles   = LIB_FILES,
}

-- The Professions, Skills and Character Stats windows as one (SMW-04): the cases written against the one
-- window read their rows and headers through it.
_G.SKM_TEST.windows = dofile("tests/fixture_windows.lua")(NS)

-- The diagnostics contract's facts (tests/_kit/test_diagnostics_contract.lua).
Kit.diagnostics = {
    brand       = NS.Constants.BRAND,
    dispatch    = function(line) NS.Slash:OnSlash(line) end,
    console     = function() return NS.DebugLog end,
    setDebug    = function(on) NS.State.debug = on and true or false end,
    setDisabled = function(off) NS.SetByPath("enabled", not off) end,
    -- A report runs past 300 lines (its Settings section walks every schema row), so the cases'
    -- reports together reach the console's 3000-line cap, and the compaction past it drops the
    -- begin markers the cases count. Each case starts on an empty console.
    reset       = function() NS.DebugLog:Clear() end,
}

-- The typed-value gate (skinning-§1). Kit revision 58 reads three- and four-number tables and
-- `or { r, g, b }` fallbacks, so the values below, none of which draws a look, take kit categories.
Kit.skinValues = { rows = {
    { file = "core/WidgetsSetup.lua", substring = "SHADE = { 1, 0.8, 0.64, 0.5 }",
      why = "the library-absent Bar stub's shade factors (brightness multipliers), mirroring WidgetsBar BAR.SHADE",
      category = "not a color" },
    { file = "modules/Chrome.lua", substring = "C.UPRIGHT, C.TURNED = { 0, 1, 0, 1 }, { 1, 0, 1, 0 }",
      why = "texture coordinates of the detach and attach marks (left, right, top, bottom)",
      category = "not a color" },
    { file = "modules/Rows.lua", substring = "R.ICON_TRIM = { 0.07, 0.93, 0.07, 0.93 }",
      why = "the icon trim, texture coordinates that cut the baked-in border off 1.x icon art",
      category = "not a color" },
    { file = "modules/Journal.lua", substring = 'or NS.SkinColor("gtip.body") or { 1, 1, 1 }',
      why = "the last resort behind two skin tokens: every skin answers gtip.body, so it never draws",
      category = "unreachable default" },
    { file = "modules/TrainerPopup.lua", substring = 'or NS.SkinColor("gtip.body") or { 1, 1, 1 }',
      why = "the last resort behind two skin tokens: every skin answers gtip.body, so it never draws",
      category = "unreachable default" },
    { file = "modules/WaypointArrow.lua", substring = 'or NS.SkinColor("gtip.body") or { 1, 1, 1 }',
      why = "the last resort behind two skin tokens: every skin answers gtip.body, so it never draws",
      category = "unreachable default" },
} }

-- The skin-switch test (skinning-§1): every surface this addon paints. Kit revision 58 compares
-- each setter family on its own; `expect = "texture"` asks every surface below that draws a data
-- fill on a Texture (the LibKa0s Bar) or the skin's window art to move its texture too. No surface
-- holds a family: the category and meaning hues are drawn beside skin-following parts that move.
local installIcon = dofile("tests/fixture_icon_widget.lua")
local boxList = {}
Kit.skinSwitch = {
    owner = "SkillMaster",
    skin  = function() return mocks.LibStub("LibKa0s-Skin-1.0") end,
    surfaces = {
        -- On the sample character, so its rows' bars draw fills (Bars of data, expect "texture").
        { name = "the main window", expect = "texture", build = function()
            NS.Preview.Apply(true)
            NS.MainWindow.Show()
            NS.MainWindow.Refresh(true)
            return NS.MainWindow.Frame()
        end, reset = function()
            NS.MainWindow.Hide()
            NS.Preview.Apply(false)
        end },
        { name = "a detached block", expect = "texture", build = function()
            NS.db.profile.layout.blocks.other.docked = false
            NS.Detached.Refresh()
            return NS.Detached.Frame("other")
        end, reset = function()
            NS.db.profile.layout.blocks.other.docked = true
            NS.Detached.Refresh()
        end },
        -- A merged window (round 5, R5-6): two detached blocks as one.
        { name = "a merged window", expect = "texture", build = function()
            local b = NS.db.profile.layout.blocks
            b.other.docked, b.secondary.docked = false, false
            NS.Detached.Refresh()
            return NS.Groups.Frame(NS.Groups.Merge("secondary", "other", "bottom"))
        end, reset = function()
            local b = NS.db.profile.layout.blocks
            b.other.docked, b.secondary.docked = true, true
            NS.db.profile.layout.groups = {}
            NS.Detached.Refresh()
        end },
        { name = "the journal", expect = "texture", build = function()
            NS.Journal.Show()
            return NS.Journal.Frame()
        end, reset = function() NS.Journal.Hide() end },
        { name = "the trainer popup", expect = "texture", build = function()
            NS.TrainerPopup.Show("fistWeapons")
            return NS.TrainerPopup.Frame()
        end, reset = function() NS.TrainerPopup.Hide() end },
        { name = "the alert toast", expect = "texture", build = function()
            NS.Alerts.toast:Preview({ kind = "cap", name = "Leatherworking",
                title = "Leatherworking 150 / 150", detail = "Train Expert (Lv 20)" })
            return NS.Alerts.toast:Frame()
        end, reset = function() NS.Alerts.toast:Clear() end },
        -- A tooltip is drawn when it shows, so its repaint is the next show (`paint`).
        -- No `expect = "texture"`: headless, the tooltip's line has no width, so the bar lays its fill
        -- hidden (WidgetsBar Layout) and draws no fill texture to compare. The same Bar and the same
        -- NS.BarStyle seam are checked for their fill texture on the main window, on the sample.
        { name = "the row tooltip's bar", build = function()
            NS.Preview.Apply(true)
            NS.MainWindow.Show()
            local row = NS.MainWindow.Rows()[1]
            NS.RowTooltip.Show(row)
            return NS.RowTooltip.Bar()
        end, paint = function()
            NS.RowTooltip.Show(NS.MainWindow.Rows()[1])
        end, reset = function()
            mocks.GameTooltip:Hide()
            NS.MainWindow.Hide()
            NS.Preview.Apply(false)
        end },
        -- The feed's own tooltip frame (broker.tooltip.skin, on by default): its shell, its lines
        -- and the pooled mini bars parented to it. The shared GameTooltip is never painted.
        { name = "the broker feed tooltip", expect = "texture", build = function()
            NS.Preview.Apply(true)   -- the sample character: learned skills to draw bars for
            NS.Broker.OnEnter(mocks.UIParent)
            return NS.Broker.Tip()
        end, paint = function()
            NS.Broker.OnEnter(mocks.UIParent)
        end, reset = function()
            NS.Broker.HideTooltip()
            NS.Preview.Apply(false)
        end },
        -- The feed's Classic style (SD-SK-SM.4): the tooltip lines and mini bars on the same own
        -- frame, its stripes and hover wash.
        { name = "the broker feed tooltip in the Classic style", expect = "texture", build = function()
            NS.db.profile.tooltips.ldb.style = "classic"
            NS.Preview.Apply(true)
            NS.Broker.OnEnter(mocks.UIParent)
            return NS.Broker.Tip()
        end, paint = function()
            NS.Broker.OnEnter(mocks.UIParent)
        end, reset = function()
            NS.Broker.HideTooltip()
            NS.Preview.Apply(false)
            NS.db.profile.tooltips.ldb.style = NS.defaults.profile.tooltips.ldb.style
        end },
        -- The waypoint arrow on test mode's sample trainer (SD-SK-SM.4): its art's far and near
        -- colors, and its distance text's face, color and shadow (SD-SK-SM.2, SM.3), re-applied by
        -- the skin listener (NS.WaypointArrow.Restyle).
        { name = "the waypoint arrow", build = function()
            NS.db.profile.waypoints.arrow = true
            NS.WaypointArrow.ShowTest()
            return NS.WaypointArrow.Frame()
        end, reset = function() NS.WaypointArrow.HideTest() end },
        -- A settings list row's action marks, the eye lit and dimmed (SD-SK-SM.1), on the settings
        -- panel: tested with Ignore settings panel cleared (scope "panel"); the pooled Icon carries
        -- a painting image here (tests/fixture_icon_widget.lua).
        { name = "a settings list row's eye marks", scope = "panel", build = function()
            local uninstall, AceGUI = installIcon(NS, mocks)
            boxList.uninstall, boxList.AceGUI = uninstall, AceGUI
            boxList.scroll = AceGUI:Create("SimpleGroup")
            local _, _, marks = NS.OptionsList.Row(boxList.scroll, nil, { text = "Leatherworking", actions = {
                { image = NS.Icon("eye"), title = "Window" },
                { image = NS.Icon("eye"), title = "LDB tooltip", dimmed = true },
            } })
            boxList.marks = marks
            return marks[1].frame, marks[2].frame
        end, reset = function()
            for _, m in ipairs(boxList.marks or {}) do boxList.AceGUI:Release(m) end
            if boxList.uninstall then boxList.uninstall() end
            boxList.marks, boxList.uninstall = nil, nil
        end },
        { name = "the debug console", expect = "texture", build = function()
            NS.DebugLog:Show()
            return NS.DebugLog._frameForTest
        end, reset = function() NS.DebugLog:Hide() end },
    },
}

-- The client-globals gate scans what ships: tools/ is dev-only Lua run from the shell (the trainer
-- probe, GitHub issue #3), never in the TOC, so its loadfile and dofile are not client calls.
Kit.clientGlobals = { skip = { "tools/" } }

Kit.run{
    dir = "tests/",
    suites = {
        "test_loadorder",
        "test_schema",
        "test_options",
        "test_template_rows",
        "test_row_display",
        "test_database",
        "test_bus",
        "test_slash",
        "test_mainwindow",
        "test_launcher",
        "test_keybinds",
        "test_locale",
        "test_skinsetup",
        "test_perf",
        "test_probe",
        "test_probe_sections",
        "test_skilldata",
        "test_trainers",
        "test_trainer_probe",
        "test_helpers",
        "test_bonuses",
        "test_statdata",
        "test_bar",
        "test_bars_live",
        "test_bars_round2",
        "test_class_first",
        "test_trainers_tabs",
        "test_detached_width",
        "test_bars_sizes",
        "test_round2_layout",
        "test_round2_icons",
        "test_round3",
        "test_round5",
        "test_round5_style",
        "test_round5_groups",
        "test_round5_snap",
        "test_round5_followups",
        "test_round6",
        "test_round7",
        "test_round8",
        "test_round9",
        "test_sr1",
        "test_blocks",
        "test_families",
        "test_tree",
        "test_windows",
        "test_interact",
        "test_sessionlog",
        "test_alts",
        "test_journal",
        "test_alerts",
        "test_template",
        "test_broker",
        "test_feeds",
        "test_pins",
        "test_ldb_tooltip",
        "test_reputations",
        "test_currencies",
        "test_statistics",
        "test_smw_review",
        "test_r5_feedback",
        "test_r5_join_resize",
        "test_r5_subdetach",
        "test_preview_trees",
        "test_polish",
        "test_preview",
        "test_sample_names",
        "test_sim",
        "test_sim_start_panel",
        "test_dropdown_selected",
        "test_window_chrome",
        "test_header_buttons",
        "test_tooltips",
        "test_no_foreverdb",
        "test_skin_defaults",
        "test_seams",
        "test_m5_seams",
        "test_m5_review",
        "test_m5_leftovers",
        "test_m6_fixes",
        "test_fb2_chrome",
        "test_surface_parity",
        "test_vendor_sync",
        -- slash-commands-§7: drives OnEnable and full disable/enable cycles on the shared
        -- environment, so it runs after every suite that reads a registration set.
        "test_disabled",
        "test_diagnostics",
        { name = "test_diagnostics_contract", dir = "tests/_kit/" },
        { name = "test_eol", dir = "tests/_kit/" },
        { name = "test_prose", dir = "tests/_kit/" },
        { name = "test_layout_cap", dir = "tests/_kit/" },
        { name = "test_lizard_sighted", dir = "tests/_kit/" },
        { name = "test_skin_values", dir = "tests/_kit/" },
        { name = "test_skin_switch", dir = "tests/_kit/" },
        { name = "test_client_globals", dir = "tests/_kit/" },
    },
}
