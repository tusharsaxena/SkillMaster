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
    loadedAddonFiles = ADDON_FILES,
    loadedLibFiles   = LIB_FILES,
}

-- The diagnostics contract's facts (tests/_kit/test_diagnostics_contract.lua).
Kit.diagnostics = {
    brand       = NS.Constants.BRAND,
    dispatch    = function(line) NS.Slash:OnSlash(line) end,
    console     = function() return NS.DebugLog end,
    setDebug    = function(on) NS.State.debug = on and true or false end,
    setDisabled = function(off) NS.SetByPath("enabled", not off) end,
}

-- The typed-value gate (skinning-§1): nothing this addon draws needs an allow row yet.
Kit.skinValues = {}

-- The skin-switch test (skinning-§1): every surface this addon paints.
Kit.skinSwitch = {
    owner = "SkillMaster",
    skin  = function() return mocks.LibStub("LibKa0s-Skin-1.0") end,
    surfaces = {
        { name = "the main window", build = function()
            NS.MainWindow.Show()
            return NS.MainWindow.Frame()
        end, reset = function() NS.MainWindow.Hide() end },
        { name = "a detached block", build = function()
            NS.db.profile.layout.blocks.other.docked = false
            NS.Detached.Refresh()
            return NS.Detached.Frame("other")
        end, reset = function()
            NS.db.profile.layout.blocks.other.docked = true
            NS.Detached.Refresh()
        end },
        { name = "the journal", build = function()
            NS.Journal.Show()
            return NS.Journal.Frame()
        end, reset = function() NS.Journal.Hide() end },
        { name = "the trainer popup", build = function()
            NS.TrainerPopup.Show("fistWeapons")
            return NS.TrainerPopup.Frame()
        end, reset = function() NS.TrainerPopup.Hide() end },
        { name = "the alert toast", build = function()
            NS.Alerts.toast:Preview({ kind = "cap", name = "Leatherworking",
                title = "Leatherworking 150 / 150", detail = "Train Expert (Lv 20)" })
            return NS.Alerts.toast:Frame()
        end, reset = function() NS.Alerts.toast:Clear() end },
        -- A tooltip is drawn when it shows, so its repaint is the next show (`paint`).
        { name = "the row tooltip's bar", build = function()
            NS.MainWindow.Show()
            local row = NS.MainWindow.Rows()[1]
            NS.RowTooltip.Show(row)
            return NS.RowTooltip.Bar()
        end, paint = function()
            NS.RowTooltip.Show(NS.MainWindow.Rows()[1])
        end, reset = function()
            mocks.GameTooltip:Hide()
            NS.MainWindow.Hide()
        end },
        { name = "the broker feed tooltip's mini bars", build = function()
            NS.Preview.Apply(true)   -- the sample character: learned skills to draw bars for
            NS.Broker.OnEnter("all", mocks.UIParent)
            return mocks.GameTooltip   -- its lines and the pooled mini bars parented to it
        end, paint = function()
            NS.Broker.OnEnter("all", mocks.UIParent)
        end, reset = function()
            mocks.GameTooltip:Hide()
            NS.Preview.Apply(false)
        end },
        { name = "the Bars page preview", scope = "panel", build = function()
            local f = mocks.CreateFrame("Frame", nil, mocks.UIParent)
            NS.OptionsPreview.Build(nil, f)
            return f
        end },
        { name = "the debug console", build = function()
            NS.DebugLog:Show()
            return NS.DebugLog._frameForTest
        end, reset = function() NS.DebugLog:Hide() end },
    },
}

Kit.run{
    dir = "tests/",
    suites = {
        "test_loadorder",
        "test_schema",
        "test_options",
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
        "test_skilldata",
        "test_trainers",
        "test_helpers",
        "test_bonuses",
        "test_statdata",
        "test_bar",
        "test_blocks",
        "test_interact",
        "test_sessionlog",
        "test_alts",
        "test_journal",
        "test_alerts",
        "test_template",
        "test_broker",
        "test_polish",
        "test_preview",
        "test_sim",
        "test_seams",
        "test_m5_seams",
        "test_m5_review",
        "test_m5_leftovers",
        "test_m6_fixes",
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
