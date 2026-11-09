-- tests/test_slash.lua — NS.COMMANDS and the dispatcher (slash-commands).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local loadDegraded = dofile("tests/degraded_env.lua")

local function names()
    local out = {}
    for i, e in ipairs(NS.COMMANDS) do out[i] = e[1] end
    return out
end

local function indexOf(verb)
    for i, e in ipairs(NS.COMMANDS) do if e[1] == verb then return i end end
end

test("slash: every entry is a positional triple", function()
    for _, e in ipairs(NS.COMMANDS) do
        assertTrue(type(e[1]) == "string" and type(e[2]) == "string" and type(e[3]) == "function",
            "malformed entry " .. tostring(e[1]))
    end
end)

test("slash: the reserved verbs are all present, `skin` directly after `config`", function()
    for _, verb in ipairs({ "help", "config", "skin", "get", "set", "list", "reset", "resetall",
        "version", "debug", "perf", "diagnostics", "enable", "disable" }) do
        assertTrue(indexOf(verb) ~= nil, "missing reserved verb " .. verb .. ": " .. table.concat(names(), ","))
    end
    assertEqual(indexOf("skin"), indexOf("config") + 1, "skin follows config (skinning-§3)")
    assertTrue(indexOf("diag") == nil and indexOf("dump") == nil, "no diagnostics alias (debug-logging-§14)")
end)

test("slash: /skm lock and /skm unlock write `locked` through the seam and echo it", function()
    M.__resetPrinted()
    NS.Slash:OnSlash("lock")
    assertTrue(NS.GetSetting("locked") == true, "lock")
    local out = table.concat(M.__printed(), "\n")
    assertTrue(out:find("locked", 1, true) ~= nil, "echo: " .. out)
    NS.Slash:OnSlash("unlock")
    assertTrue(NS.GetSetting("locked") == false, "unlock")
end)

test("slash: /skm test flips test mode, and again turns it off", function()
    NS.Slash:OnSlash("test")
    assertTrue(NS.IsTestMode(), "on")
    NS.Slash:OnSlash("test")
    assertTrue(not NS.IsTestMode(), "off")
end)

test("slash: the stub's one library string is pinned to the live major", function()
    local NS2 = loadDegraded()
    T.assertLibraryConstant(NS2.Slash.__disabledLineFormat, "LibKa0s-Slash-1.0", "DISABLED_LINE_FORMAT")
end)

test("slash: on a library-absent load, /skm enable still lands through writeThrough", function()
    local NS2 = loadDegraded()
    NS2.addon:OnInitialize()
    NS2.Slash:OnSlash("disable")
    assertTrue(NS2.db.profile.enabled == false, "disable wrote through the hollow seam")
    NS2.Slash:OnSlash("enable")
    assertTrue(NS2.db.profile.enabled == true, "enable wrote through the hollow seam")
end)
