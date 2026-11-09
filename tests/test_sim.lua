-- tests/test_sim.lua — the simulator (preview-mode, the in-game simulator; plan Task 5.2) against
-- LibKa0s-Sim-1.0's host contract: the seam wraps every Compat member (H2), the stubs match the live
-- surfaces (H9), the refusals (H5), nothing saved across a whole session (H4), the stop restores the
-- live state, and the three surfaces onto one handler (the verb, the launcher entry, the checkbox).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local H = NS.SimHost

local function stopAll()
    if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
    NS.Sim:HidePanel()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
end

--- Deterministic text of a table (sorted keys), for the before/after comparison of saved data.
local function dump(v, seen)
    if type(v) ~= "table" then return tostring(v) end
    seen = seen or {}
    if seen[v] then return "<cycle>" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k], seen) end
    seen[v] = nil
    return "{" .. table.concat(out, ",") .. "}"
end

local function saved()
    return dump({ char = NS.db.char, global = NS.db.global, profile = NS.db.profile })
end

local function start()
    local ok = NS.Sim:Start({ scenario = H.SCENARIO })
    M.__fireTimers()
    return ok
end

--- Play the next step and run the debounced work it asked for (the scan, the bonus refresh).
local function step()
    local s = NS.Sim:Step()
    M.__fireTimers()
    return s
end

test("sim: the seam wraps every Compat member, and nothing escapes it (H2)", function()
    assertEqual(#NS.SimSeam:Unwrapped(), 0, "every Compat member is wrapped or pure")
    local keys = {}
    for _, k in ipairs(NS.SimSeam:Keys()) do keys[k] = true end
    for name, v in pairs(NS.Compat) do
        if type(v) == "function" then assertTrue(keys[name], name .. " is wrapped") end
    end
end)

test("sim: the Sim and seam stubs carry the live surfaces (H9)", function()
    local restore = T.setSurfaceSource({ ["LibKa0s-Sim-1.0"] = NS.Sim })
    T.assertSurfaceParity(H.NewStub(print), "LibKa0s-Sim-1.0", {})
    T.setSurfaceSource(restore)
    T.assertSurfaceParity(H.NewStub(print), NS.Sim, "stub over the live instance", {})
    T.assertSurfaceParity(NS.NewSimSeamStub(), NS.SimSeam, "seam stub over the live seam", {})
end)

test("sim: a library-absent load takes the stubs, and the verb names the missing major", function()
    local NS2, M2 = dofile("tests/degraded_env.lua")()
    assertFalse(NS2.Sim:IsActive())
    NS2.Sim:RunVerb("")
    local said = table.concat(M2.__quiet, "\n")
    assertTrue(said:find("LibKa0s-Sim-1.0", 1, true) ~= nil, said)
    assertFalse(NS2.IsSimMode())
end)

test("sim: the refusals, each leaving Sim mode unticked (H5)", function()
    stopAll()
    NS.ToggleTestMode()
    assertFalse(NS.Sim:Start({ scenario = H.SCENARIO }), "test mode on")
    assertFalse(NS.IsSimMode())
    NS.ToggleTestMode()
    local realCombat = M.InCombatLockdown
    M.InCombatLockdown = function() return true end
    assertFalse(NS.Sim:Start({ scenario = H.SCENARIO }), "in combat")
    M.InCombatLockdown = realCombat
    M.__context.inInstance = true
    assertFalse(NS.Sim:Start({ scenario = H.SCENARIO }), "in an instance")
    M.__context.inInstance = nil
    M.__context.inGroup = true
    assertFalse(NS.Sim:Start({ scenario = H.SCENARIO }), "in a group")
    M.__context.inGroup = nil
    assertFalse(NS.Sim:IsActive())
end)

test("sim: test mode refuses while a simulation runs (the two are exclusive)", function()
    stopAll()
    assertTrue(start(), "started")
    assertFalse(NS.ToggleTestMode(), "refused")
    assertFalse(NS.IsTestMode())
    stopAll()
end)

test("test_sim_skill_up_drives_flash: a sim skill-up makes the broker flash and the session log record it", function()
    stopAll()
    NS.Broker.ResetSession()
    local liveLog = #NS.db.char.log
    assertTrue(start(), "started")
    assertEqual(NS.SkillData:Get("fishing").rank, 107, "the simulated character")
    local s = step()
    assertEqual(s.kind, "skillUp")
    assertEqual(NS.SkillData:Get("fishing").rank, 108)
    local all = NS.Broker.Text("all")
    assertTrue(all:find("Fishing 108", 1, true) ~= nil, "the All feed flashes: " .. tostring(all))
    local entries = NS.SessionLog:Entries()
    assertEqual(#entries, 1, "the session log recorded it")
    assertEqual(entries[1].key, "fishing")
    assertEqual(entries[1].old, 107)
    assertEqual(entries[1].new, 108)
    assertEqual(#NS.db.char.log, liveLog, "into the session's own list, not SavedVariables")
    stopAll()
end)

test("sim: the lure goes on and off, and the mount changes the speed", function()
    stopAll()
    start()
    step()                                    -- a skill-up
    step()                                    -- the lure goes on
    local b = NS.Bonuses:Breakdown("fishing")
    assertEqual(b.total, 25)
    assertEqual(b.sources[1].source, "enchant")
    assertEqual(b.sources[1].label, "Shiny Bauble")
    assertEqual(NS.Bonuses:Breakdown("guns").sources[1].source, "racial", "the simulated Dwarf")
    step() step()                             -- two skill-ups
    step()                                    -- mount up
    local run = NS.StatData:Scan()
    local speed
    for _, e in ipairs(run.utility) do if e.key == "runSpeed" then speed = e end end
    assertEqual(speed.display, "160%")
    step() step() step()                      -- two skill-ups, dismount
    step()                                    -- the lure comes off
    assertEqual(NS.Bonuses:Breakdown("fishing").total, 0)
    stopAll()
end)

test("sim: a whole session saves nothing, and the stop restores the live state (H4)", function()
    stopAll()
    local live = NS.SkillData:Model()
    local before = saved()
    local gains = NS.State.sessionGains
    local start0 = NS.SessionLog:SessionStart()
    local brokerBefore = dump(NS.Broker.SessionState())
    assertTrue(start())
    for _ = 1, #NS.Sim:Steps() do step() end
    assertEqual(NS.SkillData:Get("skinning").rank, 123, "the last step ran")
    NS.Sim:Stop("stop")
    assertEqual(saved(), before, "SavedVariables byte-identical across the session")
    assertTrue(NS.SkillData:Model() == live, "the live skills model is back")
    assertEqual(NS.State.sessionGains, gains)
    assertEqual(NS.SessionLog:SessionStart(), start0, "the live session is back")
    assertFalse(NS.SessionLog:IsOverridden())
    assertEqual(dump(NS.Broker.SessionState()), brokerBefore, "the broker's session is back")
    assertEqual(NS.Compat.PlayerLevel(), M.UnitLevel("player"), "the seam answers live again")
    stopAll()
end)

test("sim: the stand-down stops a running session first", function()
    stopAll()
    start()
    NS.SetByPath("enabled", false)
    assertFalse(NS.Sim:IsActive())
    assertFalse(NS.Sim:Start({ scenario = H.SCENARIO }), "refused while disabled")
    NS.SetByPath("enabled", true)
    stopAll()
end)

test("sim: the verb, the launcher entry and the checkbox are one handler", function()
    stopAll()
    NS.Slash:OnSlash("sim start " .. H.SCENARIO)
    assertTrue(NS.Sim:IsActive(), "the verb starts it")
    assertTrue(NS.IsSimMode(), "ticked while it runs")
    NS.ToggleSim()
    assertFalse(NS.Sim:IsActive(), "the toggle stops it")
    assertFalse(NS.IsSimMode())
    local row
    for _, r in ipairs(NS.Schema) do if r.path == "state.sim" then row = r end end
    assertTrue(row ~= nil, "the Master-controls Sim mode row")
    assertEqual(row.default, false)
    start()
    row.set(false)
    assertFalse(NS.Sim:IsActive(), "unticking stops the session")
    stopAll()
end)

test("sim: combat stops a running session", function()
    stopAll()
    start()
    NS.addon:OnEnterCombat()
    assertFalse(NS.Sim:IsActive())
    stopAll()
end)

test("sim: the window shows the simulation strip while a session runs", function()
    stopAll()
    NS.MainWindow.Show()
    start()
    local f = NS.MainWindow.Frame()
    assertTrue(f.simStrip:IsShown(), "the sim strip")
    assertFalse(f.strip:IsShown(), "one marker at a time")
    NS.Sim:Stop("stop")
    assertFalse(f.simStrip:IsShown())
    NS.MainWindow.Hide()
    stopAll()
end)
