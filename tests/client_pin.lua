-- tests/client_pin.lua — pins the vendored kit's client profile to WoW Forever for every mock set a
-- Loader builds, so a bare `lua tests/run.lua`, `lua tests/perf.lua` and the vendored
-- `tests/_kit/run-automated-tests.sh` run as the one client this addon ships on (clients-§6,
-- clients-§9: a Forever addon's suite runs as Forever, never on the kit's default Retail profile).
--
-- The kit stays untouched (testing-§11): this wraps the Loader's own MockClient.apply (published as
-- `Loader.MockClient`, kit revision 52), so the profile every environment is stamped with defaults
-- to "forever" rather than to KA0S_KIT_CLIENT-else-retail. KA0S_KIT_CLIENT=forever is still
-- accepted, so every documented command keeps working; KA0S_KIT_CLIENT=retail raises, because a
-- Retail run of a Forever-only addon tests a client it does not ship on.
--
--   dofile("tests/client_pin.lua")(Loader[, getenv])   -- right after the Loader's dofile
local PIN = "forever"

return function(Loader, getenv)
    getenv = getenv or os.getenv
    local asked = getenv("KA0S_KIT_CLIENT")
    if asked ~= nil and asked ~= "" and asked ~= PIN then
        error(('client_pin: KA0S_KIT_CLIENT="%s", but Ka0s Skill Master is Forever-only (clients-§9); '
            .. 'unset it or set it to "forever"'):format(asked), 2)
    end
    local MC = Loader.MockClient
    if MC.__skmPinned then return end
    local apply = MC.apply
    MC.apply = function(mocks, name) return apply(mocks, name or PIN) end
    MC.__skmPinned = true
end
