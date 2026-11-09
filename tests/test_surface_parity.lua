-- tests/test_surface_parity.lua — every degradation stub carries the live surface the addon reaches
-- (testing-§8), checked against a REAL library-absent load, never a hand-stub.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertTrue = T.test, T.assertTrue
local loadDegraded = dofile("tests/degraded_env.lua")

test("parity: the Core stub publishes every NS member core/CoreSetup.lua publishes live", function()
    local f = assert(io.open("core/CoreSetup.lua", "rb"))
    local src = f:read("*a")
    f:close()
    local live, n = {}, 0
    for name in src:gmatch("\nNS%.([A-Za-z_]+)%s*=") do
        if NS[name] ~= nil and live[name] == nil then live[name] = NS[name]; n = n + 1 end
    end
    assertTrue(n >= 8, "the derivation found only " .. n .. " publications")
    T.assertSurfaceParity(live, loadDegraded(), "Core stub")
end)

test("parity: the DebugLog stub carries the whole live surface", function()
    T.assertSurfaceParity(loadDegraded().DebugLog, "LibKa0s-DebugLog-1.0",
        { "FormatPlain", "FormatColored", "CopyText", "Text", "_frameForTest", "_toggleClickForTest" })
end)

test("parity: the Options stub carries every helper the degraded build can reach", function()
    T.assertSurfaceParity(loadDegraded().Helpers, "LibKa0s-Options-1.0", {
        -- Layout constants and members only the live renderer reaches, never a page file.
        "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X", "CHROME_GAP", "TAB_H",
        "BANNER_H", "CreateOptionsPanel", "OpenOptionsPanel", "RegisterOptionsPage",
        "BuildLandingPage", "TextRow", "AceGUI", "RefreshPanel", "Drawer", "CLASS_COLOR_NOTE",
        "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_SORT", "VISIBILITY_VALUES", "PageBanner",
        "SubTabStrip", "MASTER_GROUP",
    })
end)

test("parity: the Slash stub carries every dispatcher member the addon calls", function()
    T.assertSurfaceParity(loadDegraded().Slash, "LibKa0s-Slash-1.0")
end)

test("parity: the Launcher stub carries the whole live surface", function()
    T.assertSurfaceParity(loadDegraded().Launcher, "LibKa0s-Launcher-1.0")
end)

test("parity: the Lifecycle stub carries the whole live surface", function()
    T.assertSurfaceParity(loadDegraded().Lifecycle, "LibKa0s-Lifecycle-1.0")
end)

test("parity: the Bus stub carries the library's whole surface", function()
    T.assertSurfaceParity(loadDegraded().__busLib, "LibKa0s-Bus-1.0")
end)

test("parity: the Schema stub carries the library's lib-level surface, and its instance a live one's", function()
    local NS2 = loadDegraded()
    T.assertSurfaceParity(NS2.__schemaLib, "LibKa0s-Schema-1.0", { "STRINGS" })
    T.assertSurfaceParity(NS.SchemaRuntime, NS2.SchemaRuntime, "schema instance vs host stub")
end)

test("parity: the Perf, Pool and Widgets stubs carry every member the addon reaches", function()
    local NS2 = loadDegraded()
    local reached = {
        Perf    = { "on", "suspended", "Note", "OnCommand" },
        Pool    = { "New", "Acquire", "ReleaseAll", "Counts", "NewKeyed", "AcquireKeyed",
                    "ReleaseAllKeyed", "CountsKeyed" },
        Widgets = { "TestStrip" },
    }
    local problems = {}
    for seam, keys in pairs(reached) do
        for _, k in ipairs(keys) do
            if NS[seam][k] == nil then problems[#problems + 1] = seam .. "." .. k .. " missing live" end
            if NS2[seam][k] == nil then problems[#problems + 1] = seam .. "." .. k .. " missing degraded" end
        end
    end
    assertTrue(#problems == 0, table.concat(problems, "; "))
end)

test("parity: the degraded load completes: options, slash and launcher answer without raising", function()
    local NS2 = loadDegraded()
    NS2.addon:OnInitialize()
    NS2.addon:OnEnable()
    NS2.Slash:OnSlash("help")
    NS2.Slash:OnSlash("diagnostics")
    NS2.MainWindow.Toggle()
    assertTrue(NS2.MainWindow.IsShown(), "the window still opens without LibKa0s")
end)
