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

test("perf: every event-path bucket (detachedRender, skillScan, statScan, bonusRefresh) is reached", function()
    -- red under: a declared bucket with no bracket (performance-§3), or a bracket noting while off
    local P = NS.Perf
    local realNote, seen = P.Note, {}
    P.Note = function(key) seen[key] = (seen[key] or 0) + 1 end
    local function drive()
        NS.Blocks:Detach("other")
        NS.Detached.Render("other")
        NS.SkillData:Scan()
        NS.StatData:Scan()
        NS.Bonuses.Refresh()
        NS.Blocks:Dock("other")
    end
    P.on = false
    local ok, err = pcall(drive)
    local off = next(seen)
    P.on = true
    if ok then ok, err = pcall(drive) end
    P.on = false
    P.Note = realNote
    if not ok then error(err, 0) end
    assertTrue(off == nil, "a bracket noted with capture off: " .. tostring(off))
    for _, key in ipairs({ "detachedRender", "skillScan", "statScan", "bonusRefresh" }) do
        assertTrue((seen[key] or 0) >= 1, key .. " was never reached")
    end
end)
