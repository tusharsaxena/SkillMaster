-- tests/test_diagnostics.lua — this addon's sections of the diagnostics report (debug-logging-§14).
-- The dispatcher contract is the kit's test_diagnostics_contract.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertTrue = T.test, T.assertTrue

-- Each report line is { tag, text }.
local function flat(report)
    local out = {}
    for i, line in ipairs(report.lines) do out[i] = tostring(line[1]) .. " " .. tostring(line[2]) end
    return table.concat(out, "\n")
end

test("diagnostics: the report carries this addon's five sections and raises in none", function()
    local text = flat(NS.DebugLog:BuildDiagnostics())
    for _, needle in ipairs({ "schema stored=", "profile=", "enabled=", "window shown=", "skin engine=" }) do
        assertTrue(text:find(needle, 1, true) ~= nil, "missing '" .. needle .. "' in:\n" .. text)
    end
    assertTrue(not text:find("raised", 1, true), "a section raised:\n" .. text)
end)

test("diagnostics: stood down, the state section says so and reads nothing else", function()
    NS.SetByPath("enabled", false)
    local text = flat(NS.DebugLog:BuildDiagnostics())
    NS.SetByPath("enabled", true)
    assertTrue(text:find("stood down: runtime state released", 1, true) ~= nil, text)
end)
