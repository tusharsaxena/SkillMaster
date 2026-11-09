local _, NS = ...
-- core/SimSetup.lua — the LibKa0s-Sim-1.0 seam (preview-mode, the in-game simulator, H2): wraps every
-- NS.Compat member in place at load, so while a simulation runs the simulator (modules/Simulator.lua)
-- answers the reads it registers a provider for, and the one member that acts on the client is
-- guarded. Absent major: the inert reference stub below, so every caller still finds the surface.
--
-- LOAD-BEARING: straight after core/Compat.lua and before any file that reads a Compat member.

local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)

-- Members that act on the client: the safe answer while a session runs. Collapsing or expanding a
-- header changes the player's Skills tab, and a simulated list has nothing to toggle.
local GUARDED = {
    SetSkillHeaderExpanded = function() return false end,
}

--- The reference seam stub (LibKa0s-Sim-1.0's "Adopting it", step 2), member by member.
local function newSeamStub()
    local seam = {}
    function seam.SetProvider() end
    function seam.Live(_, fn, ...) return fn(...) end
    function seam.Keys() return {} end
    function seam.Unwrapped() return {} end
    return seam
end
NS.NewSimSeamStub = newSeamStub   -- the surface-parity case builds one to compare

if Sim then
    NS.SimSeam = Sim:NewSeam(NS.Compat, {
        name    = "SkillMaster",
        guarded = GUARDED,
        -- NS.Debug loads later (core/DebugLogSetup.lua); the seam reaches it at call time.
        debug   = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,
    })
else
    NS.SimSeam = newSeamStub()
end
