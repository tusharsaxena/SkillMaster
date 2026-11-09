-- tests/test_perf.lua — every declared perf bucket is reached by a real bracket (performance).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertTrue = T.test, T.assertTrue

test("perf: windowRender is noted while a capture is on, and nothing is noted while off", function()
    local P = NS.Perf
    local realNote, seen = P.Note, {}
    P.Note = function(key) seen[key] = (seen[key] or 0) + 1 end
    P.on = false
    NS.MainWindow.Show()
    NS.MainWindow.Render()
    assertTrue(seen.windowRender == nil, "a bracket noted with capture off")
    P.on = true
    NS.MainWindow.Render()
    P.on = false
    P.Note = realNote
    NS.MainWindow.Hide()
    assertTrue((seen.windowRender or 0) >= 1, "windowRender was never reached")
end)
