-- tests/test_sim_start_panel.lua — every start path of Character Ledger's simulator shows the step
-- panel (FB2-SM-01 of Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH, decision D2).
--
-- The owner's words, 2026-11-24: "sim mode whether started from a command like /xx sim start
-- <scenario> or from just plain /xx sim should always show the sim stepper window". The rule is the
-- library's (LibKa0s-Sim-1.0 minor 5: a successful Start shows the panel), and this addon starts
-- every session through it. One case per path the player has: the bare verb, the typed start, the
-- panel's Start row and picker, a Restart, the Master controls Sim box and the launcher's Sim mode
-- entry. Each case closes the panel first, so a panel left open by an earlier case proves nothing.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse
local H = NS.SimHost

local function reset()
    if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
    NS.Sim:HidePanel()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    assertFalse(NS.Sim:IsPanelShown(), "the panel starts closed")
end

test("sim start panel: the panel's Start row is the typed start, and it shows the panel", function()
    -- The panel's Start row and its picker's Start run the library's act, which is
    -- RunVerb(<the row's start line>) (SimPanel.lua act). The mock keeps no frame by name, so the
    -- case reads the composed Start row and runs the very command it carries.
    reset()
    assertTrue(NS.Sim:ShowPanel(), "ShowPanel")
    local row = NS.Sim:PanelRows()[1]
    assertTrue(row ~= nil and row.key == "start", "the first row is Start")
    assertTrue(row.actionable, "Start is clickable before a session")
    local line = tostring(row.command):match("^/cl (.+)$")
    assertTrue(line ~= nil and line:find("sim start " .. H.SCENARIO, 1, true) == 1, tostring(row.command))
    NS.Sim:HidePanel()
    NS.Slash:OnSlash(line)
    assertTrue(NS.Sim:IsActive(), "the Start row's command started a session")
    assertTrue(NS.Sim:IsPanelShown(), "with the panel shown")
    reset()
end)

test("sim start panel: the bare /cl sim shows the panel", function()
    reset()
    NS.Slash:OnSlash("sim")
    assertFalse(NS.Sim:IsActive(), "the bare verb starts no session")
    assertTrue(NS.Sim:IsPanelShown(), "the bare verb opened the step panel")
    reset()
end)

test("sim start panel: a Restart with the panel closed shows it again", function()
    -- red under Sim minor 4: Restart's Start never showed the panel, so a player who closed it
    -- mid-session restarted into a hidden stepper.
    reset()
    NS.Slash:OnSlash("sim start " .. H.SCENARIO)
    assertTrue(NS.Sim:IsActive(), "a session runs")
    NS.Sim:HidePanel()
    assertFalse(NS.Sim:IsPanelShown(), "the player closed the panel")
    NS.Slash:OnSlash("sim restart")
    assertTrue(NS.Sim:IsActive(), "the restart started a fresh session")
    assertTrue(NS.Sim:IsPanelShown(), "and the panel is shown")
    reset()
end)

test("sim start panel: the Master controls Sim box shows the panel", function()
    reset()
    local row
    for _, r in ipairs(NS.Schema) do if r.path == "state.sim" then row = r end end
    assertTrue(row ~= nil, "the Master-controls Sim mode row")
    row.set(true)
    assertTrue(NS.Sim:IsPanelShown(), "ticking the box opened the step panel")
    assertTrue(NS.IsSimMode(), "and the box reads ticked")
    reset()
end)

test("sim start panel: the launcher menu's Sim mode entry shows the panel", function()
    reset()
    local rows = {}
    local root = {}
    local function row(kind, label, a, b)
        local e = { kind = kind, label = label }
        if kind == "checkbox" then e.isSelected, e.onSelect = a, b else e.onSelect = a end
        function e.SetEnabled() end
        rows[#rows + 1] = e
        return e
    end
    function root.CreateTitle(_, label) return row("title", label) end
    function root.CreateCheckbox(_, label, isSelected, onSelect) return row("checkbox", label, isSelected, onSelect) end
    function root.CreateButton(_, label, onClick) return row("button", label, onClick) end
    function root.CreateDivider() end
    local realMU = M.MenuUtil
    M.MenuUtil = { CreateContextMenu = function(owner, gen) gen(owner, root) end }
    NS.Launcher:Object().OnClick(nil, "RightButton")
    M.MenuUtil = realMU
    local entry
    for _, r in ipairs(rows) do if r.label == "Sim mode" then entry = r end end
    assertTrue(entry ~= nil, "the launcher's Sim mode entry")
    entry.onSelect()
    assertTrue(NS.Sim:IsPanelShown(), "the launcher entry opened the step panel")
    reset()
end)
