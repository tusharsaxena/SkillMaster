-- tests/test_disabled.lua — slash-commands-§7's ten steps: disabled means not running.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function regKey(r)
    return ("%s|%s|%s|%s"):format(r.kind, tostring(r.event), tostring(r.unit), tostring(r.target))
end
local function regSet()
    local out = {}
    for i, r in ipairs(M.__registrations()) do out[i] = regKey(r) end
    table.sort(out)
    return out
end
local function joined(list) return table.concat(list, "\n  ") end

--- The addon's own top-level frames on screen: parented to UIParent (or to nothing) and shown.
--- A child's own shown flag outlives its hidden parent, so only the top of each tree is read.
local function shownTop()
    local out = {}
    for _, f in ipairs(M.__shownFrames()) do
        local parent = f.GetParent and f:GetParent()
        if parent == nil or parent == M.UIParent then out[f] = true end
    end
    return out
end
local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end
--- Frames in `after` that `before` did not have: the shows a step caused.
local function newShows(before, after)
    local out = {}
    for f in pairs(after) do
        if not before[f] then out[#out + 1] = tostring(f.GetName and f:GetName() or f) end
    end
    return out
end
--- Every addon surface that can be on screen while enabled: the window, a detached block, the
--- Journal, the trainer popup and the alert toast (the skin-switch list in tests/run.lua).
local function showEverything()
    NS.MainWindow.Show()
    NS.Blocks:Detach("other")
    NS.Journal.Show()
    NS.TrainerPopup.Show("fistWeapons")
    NS.Alerts.toast:Preview({ kind = "cap", name = "Leatherworking",
        title = "Leatherworking 150 / 150", detail = "Train Expert (Lv 20)" })
end
local function hideEverything()
    NS.MainWindow.Hide()
    NS.Blocks:Dock("other")
    NS.Journal.Hide()
    NS.TrainerPopup.Hide()
    NS.Alerts.toast:Clear()
end
local function disable() NS.SetByPath("enabled", false) end
local function enable() NS.SetByPath("enabled", true) end

local function bringUp()
    -- The skin library's EllesmereUI retry frame waits on PLAYER_LOGIN; the client fires it once.
    local skinLib = M.LibStub("LibKa0s-Skin-1.0", true)
    local retry = skinLib and skinLib.__euiEventFrame
    if retry then retry:__fire("OnEvent", "PLAYER_LOGIN") end
    enable()
    NS.db.profile.skin.pickerSeen = true
    NS.addon:OnEnable()
    -- Timers an earlier suite left queued (a library window's deferred paint) are not this addon's.
    for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
    return regSet()
end

test("disabled 1: the enabled addon registers something to stand down from", function()
    local R_on = bringUp()
    assertTrue(#R_on > 0, "the baseline registration set is empty")
    -- The other two baselines: the armed timers and the frames on screen.
    NS.addon:ScheduleTimer(function() end, 5)
    showEverything()
    local T_on, F_on = #M.__timers(), shownTop()
    assertTrue(T_on > 0, "the baseline armed-timer set is empty")
    assertTrue(count(F_on) >= 5, "the baseline shown-frame set misses an addon surface")
    for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
    hideEverything()
end)

test("disabled 2-3: writing `enabled` through the seam leaves NOTHING registered", function()
    -- red under: drop addon:UnregisterAllEvents() (or NS.BusStandDown()) from NS.StandDown
    -- (core/SkillMaster.lua): the addon's or a data module's events survive the disable.
    bringUp()
    disable()
    assertEqual(#regSet(), 0, "survivors:\n  " .. joined(regSet()))
    enable()
end)

test("disabled 4: no timer is left armed", function()
    bringUp()
    NS.addon:ScheduleTimer(function() end, 5)
    disable()
    assertEqual(#M.__timers(), 0, "timers left armed on a stood-down addon")
    enable()
end)

test("disabled 5: every frame that was on screen is hidden, and Show refuses", function()
    bringUp()
    local before = shownTop()
    showEverything()
    local F_on = {}
    for f in pairs(shownTop()) do if not before[f] then F_on[f] = true end end
    assertTrue(NS.MainWindow.IsShown(), "precondition: the window is up")
    assertTrue(count(F_on) >= 5, "precondition: every addon surface is up")
    disable()
    for f in pairs(F_on) do
        assertFalse(f.__shown, tostring(f.GetName and f:GetName() or f) .. " survived the stand-down")
    end
    M.__resetPrinted()
    NS.MainWindow.Show()
    assertFalse(NS.MainWindow.IsShown(), "Show let the window back while disabled")
    enable()
    hideEverything()
end)

test("disabled 6: firing every baseline event writes nothing, says nothing, shows nothing", function()
    bringUp()
    -- event -> every target registered for it: the addon object, and each data module's own
    -- tracked bus target (modules/StatData.lua and the other data modules).
    local events = {}
    for _, r in ipairs(M.__registrations()) do
        if r.kind ~= "message" then
            events[r.event] = events[r.event] or {}
            events[r.event][r.target] = true
        end
    end
    assertTrue(events.PLAYER_REGEN_DISABLED, "the combat-entry event is in the baseline by name")
    -- red under: drop addon:UnregisterAllEvents() from NS.StandDown (core/SkillMaster.lua):
    -- OnEnterCombat runs on PLAYER_REGEN_DISABLED, ends test mode and prints.
    disable()
    M.__resetSvWrites()
    M.__resetPrinted()
    local shown = shownTop()
    for event in pairs(events) do M.__fire(event) end
    assertEqual(#M.__svWrites(), 0, "SavedVariables writes from a game event")
    assertEqual(#M.__printed(), 0, "lines printed: " .. joined(M.__printed()))
    assertEqual(joined(newShows(shown, shownTop())), "", "frames shown by a game event")
    -- Each fire must be shown to reach a handler, or the silence above is the harness's.
    for event, targets in pairs(events) do
        local reached = 0
        for target in pairs(targets) do reached = reached + M.__fireUnconditional(target, event) end
        assertTrue(reached >= 1, event .. " reached no handler, so step 6 proved nothing")
    end
    assertEqual(#M.__printed(), 0, "lines printed by a handler fired after the stand-down")
    assertEqual(joined(newShows(shown, shownTop())), "", "frames shown by a handler fired after the stand-down")
    enable()
end)

test("disabled 7: every live verb answers, and each feature verb refuses on one line", function()
    local LIVE = {
        help = true, config = true, version = true, enable = true, disable = true, debug = true,
        perf = true, get = true, set = true, list = true, reset = true, resetall = true,
        diagnostics = true,
    }
    local realOpen, opened = NS.OpenOptionsPanel, 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    bringUp()
    local refusal = NS.Slash:DisabledLine()
    for _, entry in ipairs(NS.COMMANDS) do
        local verb = entry[1]
        disable()
        M.__resetPrinted()
        NS.Slash:OnSlash(verb)
        local out = M.__printed()
        if verb == "help" then
            -- help prints the whole index while disabled (the library heads it with the notice).
            assertTrue(#out > 2, "/sm help prints the index while disabled: " .. joined(out))
        elseif LIVE[verb] then
            for _, line in ipairs(out) do
                assertFalse(line:find(refusal, 1, true) ~= nil, "/sm " .. verb .. " refused: " .. line)
            end
        else
            assertEqual(#out, 1, "/sm " .. verb .. " refuses on ONE line: " .. joined(out))
            assertTrue(out[1]:find(refusal, 1, true) ~= nil, "/sm " .. verb .. ": " .. tostring(out[1]))
        end
    end
    -- The reserved verbs' other forms: `debug diagnostics` answers as `diagnostics` does.
    for _, line in ipairs({ "debug diagnostics", "diagnostics" }) do
        disable()
        M.__resetPrinted()
        NS.Slash:OnSlash(line)
        local out = M.__printed()
        assertTrue(#out >= 1, "/sm " .. line .. " printed nothing while disabled")
        for _, l in ipairs(out) do
            assertFalse(l:find(refusal, 1, true) ~= nil, "/sm " .. line .. " refused: " .. l)
        end
    end
    NS.DebugLog:Hide()
    disable()
    opened = 0
    NS.Slash:OnSlash("")
    assertEqual(opened, 1, "a bare /sm opens the settings panel while disabled")
    NS.OpenOptionsPanel = realOpen
    enable()
    -- Under the perf hold alone, a feature verb answers the capture line, never the disabled one.
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    M.__resetPrinted()
    NS.Slash:OnSlash("show")
    NS.Lifecycle:Release(NS.HOLD_PERF)
    local out = M.__printed()
    assertEqual(#out, 1, joined(out))
    assertTrue(out[1]:find("Not available during a performance capture.", 1, true) ~= nil, out[1])
    assertFalse(out[1]:find(refusal, 1, true) ~= nil, "the perf hold answered the disabled line")
    NS.MainWindow.Hide()
end)

--- A headless MenuUtil: CreateContextMenu runs the generator on a recording root and answers it.
local function menuMock()
    local root = { rows = {} }
    local function entry(kind, label)
        local e = { kind = kind, label = label, enabled = true }
        function e.SetEnabled(_, on) e.enabled = on and true or false end
        root.rows[#root.rows + 1] = e
        return e
    end
    function root.CreateTitle(_, label) return entry("title", label) end
    function root.CreateCheckbox(_, label) return entry("checkbox", label) end
    function root.CreateButton(_, label) return entry("button", label) end
    return { CreateContextMenu = function(owner, gen) gen(owner, root) end }, root
end

test("disabled 8: the launcher's clicks and the key bindings while disabled", function()
    -- red under: a launcher whose isEnabled accessor reads the stand-down instead of the stored
    -- `enabled` (Enabled grays too), or a binding handler that toggles without the stand-down check.
    bringUp()
    disable()
    local realOpen, opened = NS.OpenOptionsPanel, 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    M.__resetSvWrites()
    local shown = shownTop()
    NS.Launcher:Object().OnClick(nil, "LeftButton")
    assertEqual(opened, 1, "left-click opens the panel while disabled")
    assertEqual(joined(newShows(shown, shownTop())), "", "the left-click showed a frame")
    -- Right: the options menu, Enabled clickable and every other entry grayed.
    local realMU = M.MenuUtil
    local mu, root = menuMock()
    M.MenuUtil = mu
    opened = 0
    NS.Launcher:Object().OnClick(nil, "RightButton")
    M.MenuUtil = realMU
    NS.OpenOptionsPanel = realOpen
    assertEqual(opened, 0, "right-click opens the menu, not the panel")
    local checks = 0
    for _, e in ipairs(root.rows) do
        if e.kind == "checkbox" then
            checks = checks + 1
            if e.label == "Enabled" then
                assertTrue(e.enabled, "Enabled is clickable while disabled: " .. e.label)
            else
                assertFalse(e.enabled, "grayed while disabled: " .. e.label)
            end
        end
    end
    assertTrue(checks >= 5, "the menu lists Enabled, Locked, Test mode, Sim mode and Show window")
    assertEqual(#M.__svWrites(), 0, "opening the menu wrote SavedVariables")
    assertEqual(joined(newShows(shown, shownTop())), "", "opening the menu showed a frame")
    -- Both bindings refuse on one line, toggle nothing, write nothing.
    for _, button in ipairs({ NS.MainWindow.__toggleButton, NS.MainWindow.__journalButton }) do
        M.__resetPrinted()
        button:GetScript("OnClick")(button, "LeftButton")
        assertFalse(NS.MainWindow.IsShown(), "a binding showed the window while disabled")
        assertFalse(NS.Journal.IsShown(), "a binding showed the Journal while disabled")
        assertEqual(#M.__printed(), 1, "the binding refuses on one line")
        assertTrue(M.__printed()[1]:find(NS.Slash:DisabledLine(), 1, true) ~= nil, M.__printed()[1])
    end
    assertEqual(#M.__svWrites(), 0, "a SavedVariables write while disabled")
    assertEqual(joined(newShows(shown, shownTop())), "", "a binding showed a frame")
    -- Enabled, under the perf hold alone: no toggle, the capture line, never the disabled one.
    enable()
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    for _, button in ipairs({ NS.MainWindow.__toggleButton, NS.MainWindow.__journalButton }) do
        M.__resetPrinted()
        button:GetScript("OnClick")(button, "LeftButton")
        local out = M.__printed()
        assertFalse(NS.MainWindow.IsShown() or NS.Journal.IsShown(), "a binding toggled under the perf hold")
        assertEqual(#out, 1, "one line under the perf hold: " .. joined(out))
        assertTrue(out[1]:find("Not available during a performance capture.", 1, true) ~= nil, out[1])
        assertFalse(out[1]:find(NS.Slash:DisabledLine(), 1, true) ~= nil, "the perf hold answered the disabled line")
    end
    NS.Lifecycle:Release(NS.HOLD_PERF)
end)

test("disabled 9: re-enabling restores the registration set from current state", function()
    local R_on = bringUp()
    disable()
    NS.SetByPath("scale", 1.25)   -- one setting changed while disabled
    local f = NS.MainWindow.Frame()
    local realScale, scale = f.SetScale, nil
    f.SetScale = function(_, s) scale = s end
    -- red under: an NS.StandUp that skips NS.MainWindow.ApplySettings (the window keeps the scale
    -- it had when it stood down); nothing here calls OnEnable, so only the stand-up can apply it.
    enable()
    assertEqual(joined(regSet()), joined(R_on))
    NS.MainWindow.Show()
    f.SetScale = realScale
    assertEqual(scale, 1.25, "the rebuilt window reads the setting changed while disabled")
    NS.MainWindow.Hide()
    NS.SetByPath("scale", 1)
end)

test("disabled 10: releasing ONE hold does not resurrect an addon the other holds down", function()
    -- red under: an enable path, or a perf resume, that calls NS.StandUp() directly instead of
    -- releasing its hold - the registration set comes back non-empty under the other hold.
    bringUp()
    T.assertLatchHoldOrder{
        lifecycle = NS.Lifecycle, perfHold = NS.HOLD_PERF,
        setEnabled = function(on) NS.SetByPath("enabled", on) end,
        regSet = regSet, label = "SkillMaster",
    }
end)
