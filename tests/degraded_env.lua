-- tests/degraded_env.lua — a REAL library-absent load: the addon's TOC files with every
-- libs/LibKa0s file left out, so each setup file takes its degradation stub (testing-§8).
return function()
    local Loader     = dofile("tests/_kit/loader.lua")
    dofile("tests/client_pin.lua")(Loader)   -- Forever-only (clients-§9)
    local buildMocks = dofile("tests/wow_mock.lua")
    Loader.addonName = "SkillMaster"
    local mocks2, NS2 = buildMocks(), {}
    -- The stubs' chat lines go to the recorder, not the terminal running the suite.
    mocks2.__quiet = {}
    mocks2.print = function(...) mocks2.__quiet[#mocks2.__quiet + 1] = table.concat({ ... }, " ") end
    Loader.loadAll(Loader.tocFiles("SkillMaster.toc"), NS2, mocks2)
    return NS2, mocks2
end
