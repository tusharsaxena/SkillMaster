-- tests/test_diagnostics.lua — this addon's sections of the diagnostics report (debug-logging-§14).
-- The dispatcher contract is the kit's test_diagnostics_contract.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual

-- Each report line is { tag, text }.
local function flat(report)
    local out = {}
    for i, line in ipairs(report.lines) do out[i] = tostring(line[1]) .. " " .. tostring(line[2]) end
    return table.concat(out, "\n")
end

test("diagnostics: the report carries this addon's nine sections and raises in none", function()
    local text = flat(NS.DebugLog:BuildDiagnostics())
    for _, needle in ipairs({ "schema stored=", "profile=", "enabled=", "window shown=", "skin engine=",
                                     "model skills=", "probe skill api=", "bonus cache", "layout window" }) do
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

-- A model of three rows, two learned (one with a +5 racial modifier and a +3 temp) and one not.
local function fixtureModel()
    local SD = NS.SkillData
    local real = SD.Model
    local m = { byKey = {
        bows = { key = "bows", category = "weapon", rank = 80, max = 110, modifier = 5, tempPoints = 3, learned = true },
        skinning = { key = "skinning", category = "primary", rank = 122, max = 150, modifier = 0, tempPoints = 0, learned = true },
        mining = { key = "mining", category = "primary", rank = 0, max = 0, modifier = 0, tempPoints = 0, learned = false },
    }, order = { primary = { "skinning", "mining" }, secondary = {}, weapon = { "bows" }, other = {} } }
    SD.Model = function() return m end
    return function() SD.Model = real end
end

local function sectionLines(name)
    for _, s in ipairs(NS.Diagnostics.Sections()) do
        if s[1] == name then
            local lines = {}
            local out = {}
            function out.add(_, _, fmt, ...)
                local args = { ... }
                for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
                lines[#lines + 1] = fmt:gsub("%%s", function() return table.remove(args, 1) end)
            end
            function out.joined(self, tag, lead, parts) return self:add(tag, "%s %s", lead, table.concat(parts, ", ")) end
            out.list = out.joined
            s[2](out)
            return table.concat(lines, "\n")
        end
    end
    error("no section " .. name)
end

test("diagnostics: the section list is identity, settings, state, skin, the four domain sections, sim, rejected", function()
    local names = {}
    for i, s in ipairs(NS.Diagnostics.Sections()) do names[i] = s[1] end
    assertEqual(table.concat(names, ","), "identity,settings,state,skin,model,probe,bonuses,layout,sim,rejected")
end)

test("diagnostics: model counts the skills by category and learned state, the stats and the stores", function()
    local restore = fixtureModel()
    local text = sectionLines("model")
    restore()
    assertTrue(text:find("model skills=3 learned=2 unlearned=1", 1, true) ~= nil, text)
    assertTrue(text:find("primary=2 secondary=0 weapon=1 other=0", 1, true) ~= nil, text)
    assertTrue(text:find("stats=", 1, true) ~= nil, text)
    assertTrue(text:find("session log entries=", 1, true) ~= nil, text)
    assertTrue(text:find("alts=", 1, true) ~= nil, text)
    assertTrue(text:find("preview source=", 1, true) ~= nil, text)
end)

test("diagnostics: probe summarizes the skill API and the probed globals without expanding a header", function()
    local expanded, realNs = 0, M.C_SkillInfo
    M.C_SkillInfo = nil
    M.GetNumSkillLines = function() return 4 end
    M.GetSkillLineInfo = function() return "Professions", true, false end
    M.ExpandSkillHeader = function() expanded = expanded + 1 end
    local text = sectionLines("probe")
    M.C_SkillInfo = realNs
    assertTrue(text:find("probe skill api=global lines=4", 1, true) ~= nil, text)
    assertTrue(text:find("probe apis present=", 1, true) ~= nil, text)
    assertTrue(text:find("TomTom=", 1, true) ~= nil, text)
    assertEqual(expanded, 0, "the diagnostics expanded a Skills-tab header (it reads, never acts)")
end)

test("diagnostics: bonuses lists each skill's modifier and the cached sources, collecting none", function()
    local restore = fixtureModel()
    local B = NS.Bonuses
    local saved = { B.__cache, B.__items, B.__buffs }
    B.__items, B.__buffs = nil, nil
    B.__cache = { { name = "bows", amount = 3, kind = "temp", source = "buff", label = "Buff" } }
    local text = sectionLines("bonuses")
    local collected = B.__items ~= nil or B.__buffs ~= nil
    B.__cache, B.__items, B.__buffs = saved[1], saved[2], saved[3]
    restore()
    assertTrue(text:find("bonus skills bows=+5 (temp 3)", 1, true) ~= nil, text)
    assertTrue(text:find("bonus cache sources=1", 1, true) ~= nil, text)
    assertTrue(text:find("bows +3 temp buff", 1, true) ~= nil, text)
    assertTrue(not collected, "the diagnostics collected the bonus sources (a tooltip scan)")
end)

test("diagnostics: bonuses says so when nothing is cached yet", function()
    local B = NS.Bonuses
    local saved = B.__cache
    B.__cache = nil
    local text = sectionLines("bonuses")
    B.__cache = saved
    assertTrue(text:find("bonus cache empty", 1, true) ~= nil, text)
end)

test("diagnostics: layout prints the window and every block's stored state, detached ones flagged", function()
    NS.db.profile.layout.blocks.weapon.docked = false
    local text = sectionLines("layout")
    NS.db.profile.layout.blocks.weapon.docked = true
    assertTrue(text:find("layout window scale=", 1, true) ~= nil, text)
    for _, id in ipairs(NS.BLOCKS) do
        assertTrue(text:find("block " .. id .. " ", 1, true) ~= nil, "missing block " .. id .. ":\n" .. text)
    end
    assertTrue(text:find("block weapon docked=false", 1, true) ~= nil, text)
    assertTrue(text:find("docked order: primary, secondary, other", 1, true) ~= nil, text)
end)
