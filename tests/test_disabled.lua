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
end)

test("disabled 2-3: writing `enabled` through the seam leaves NOTHING registered", function()
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
    NS.MainWindow.Show()
    assertTrue(NS.MainWindow.IsShown(), "precondition: the window is up")
    disable()
    assertFalse(NS.MainWindow.IsShown(), "the window survived the stand-down")
    M.__resetPrinted()
    NS.MainWindow.Show()
    assertFalse(NS.MainWindow.IsShown(), "Show let the window back while disabled")
    enable()
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
    disable()
    M.__resetSvWrites()
    M.__resetPrinted()
    for event in pairs(events) do M.__fire(event) end
    assertEqual(#M.__svWrites(), 0, "SavedVariables writes from a game event")
    assertEqual(#M.__printed(), 0, "lines printed: " .. joined(M.__printed()))
    assertFalse(NS.MainWindow.IsShown(), "a frame was shown")
    -- Each fire must be shown to reach a handler, or the silence above is the harness's.
    for event, targets in pairs(events) do
        local reached = 0
        for target in pairs(targets) do reached = reached + M.__fireUnconditional(target, event) end
        assertTrue(reached >= 1, event .. " reached no handler, so step 6 proved nothing")
    end
    assertEqual(#M.__printed(), 0, "lines printed by a handler fired after the stand-down")
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
            assertTrue(#out > 2, "/skm help prints the index while disabled: " .. joined(out))
        elseif LIVE[verb] then
            for _, line in ipairs(out) do
                assertFalse(line:find(refusal, 1, true) ~= nil, "/skm " .. verb .. " refused: " .. line)
            end
        else
            assertEqual(#out, 1, "/skm " .. verb .. " refuses on ONE line: " .. joined(out))
            assertTrue(out[1]:find(refusal, 1, true) ~= nil, "/skm " .. verb .. ": " .. tostring(out[1]))
        end
    end
    disable()
    opened = 0
    NS.Slash:OnSlash("")
    assertEqual(opened, 1, "a bare /skm opens the settings panel while disabled")
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

test("disabled 8: the launcher's left-click and the key binding while disabled", function()
    bringUp()
    disable()
    local realOpen, opened = NS.OpenOptionsPanel, 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    M.__resetSvWrites()
    NS.Launcher:Object().OnClick(nil, "LeftButton")
    NS.OpenOptionsPanel = realOpen
    assertEqual(opened, 1, "left-click opens the panel while disabled")
    M.__resetPrinted()
    local button = NS.MainWindow.__toggleButton
    button:GetScript("OnClick")(button, "LeftButton")
    assertFalse(NS.MainWindow.IsShown(), "the binding showed the window while disabled")
    assertEqual(#M.__printed(), 1, "the binding refuses on one line")
    assertTrue(M.__printed()[1]:find(NS.Slash:DisabledLine(), 1, true) ~= nil, M.__printed()[1])
    assertEqual(#M.__svWrites(), 0, "a SavedVariables write while disabled")
    enable()
end)

test("disabled 9: re-enabling restores the registration set from current state", function()
    local R_on = bringUp()
    disable()
    NS.SetByPath("scale", 1.25)   -- one setting changed while disabled
    local f = NS.MainWindow.Frame()
    local realScale, scale = f.SetScale, nil
    f.SetScale = function(_, s) scale = s end
    enable()
    assertEqual(joined(regSet()), joined(R_on))
    NS.MainWindow.Show()
    NS.addon:OnEnable()
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
