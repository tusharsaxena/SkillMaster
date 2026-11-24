-- tests/test_foreverdb_sources.lua — ForeverDB in Skill Master (LibKa0s#105, item SF-SM-02 of
-- Ka0sAddonsCommonTasks docs/2026-11-25-SEEDS_AND_FOREVERDB/; WowAddonStandards clients-§11).
--
-- The characterization cases come first and pin what the display does with no ForeverDB at all: a
-- book rank's row tooltip says who sells the book and nothing more, and a trainer record with no
-- position is shown without coordinates and sends its waypoint to chat. The feature must leave
-- both exactly so whenever ForeverDB cannot answer.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- An Alliance Human at level 40 while `fn` runs.
local function asAllianceHuman(fn)
    local f, r, l = M.UnitFactionGroup, M.UnitRace, M.UnitLevel
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.UnitRace = function() return "Human", "Human" end
    M.UnitLevel = function() return 40 end
    local ok, err = pcall(fn)
    M.UnitFactionGroup, M.UnitRace, M.UnitLevel = f, r, l
    if not ok then error(err, 0) end
end

-- The row tooltip's lines for Fishing at `rank` / `max`, as "left|right" strings.
local function fishingLines(rank, max)
    local e = { key = "fishing", name = "Fishing", category = "secondary", learned = true,
                rank = rank, max = max, modifier = 0 }
    local out = {}
    for _, l in ipairs(NS.RowTooltip.Lines(e, "skill", "row")) do
        if l.left then out[#out + 1] = l.left .. "|" .. tostring(l.right) end
    end
    return out
end

local function indexOf(list, prefix)
    for i, s in ipairs(list) do if s:sub(1, #prefix) == prefix then return i end end
    return nil
end

-- The popup on an invented skill whose one teacher is `rec`, then everything back.
local FIXTURE_KEY = "sfsm02fixture"
local function withFixturePopup(rec, fn)
    local list = NS.Trainers_Forever
    list[#list + 1] = rec
    local ok, err = pcall(asAllianceHuman, function()
        NS.TrainerPopup.Show(FIXTURE_KEY)
        fn(NS.TrainerPopup.Frame())
    end)
    NS.TrainerPopup.Hide()
    for i = #list, 1, -1 do if list[i] == rec then table.remove(list, i) end end
    if not ok then error(err, 0) end
end

local function coordless(extra)
    local rec = { id = "sfsm02_fixture", name = "Fixture Teacher", faction = "Neutral",
                  city = "Fixture Vale", mapName = "Fixture Vale", teaches = { FIXTURE_KEY },
                  npcID = 990001, source = "invented (tests)" }
    for k, v in pairs(extra or {}) do rec[k] = v end
    return rec
end

-- ---------------------------------------------------------------------------------------------
-- Characterization: no ForeverDB
-- ---------------------------------------------------------------------------------------------

test("characterization: Fishing 150/150's row tooltip names the next rank and its book seller, then the hint", function()
    asAllianceHuman(function()
        local lines = fishingLines(150, 150)
        local at = indexOf(lines, "Next rank|")
        assertTrue(at ~= nil, "a Next rank line")
        assertEqual(lines[at], "Next rank|Expert at 150 \194\183 Lv 20")
        local trainer = lines[at + 1]
        assertTrue(trainer:find("^Trainer|") ~= nil, "the trainer line follows: " .. tostring(trainer))
        assertTrue(trainer:find("Sells Expert Fishing - The Bass and You", 1, true) ~= nil, trainer)
        local all = table.concat(lines, " ; ")
        assertTrue(lines[at + 2]:find("^Fishing in ") ~= nil, "the fishing helper follows: " .. all)
        assertEqual(#lines, at + 3, "then only the click hint: " .. all)
    end)
end)

test("characterization: a trainer record with no position shows no coordinates and blocks the waypoint", function()
    withFixturePopup(coordless(), function(f)
        local cards = NS.TrainerPopup.Cards()
        assertEqual(#cards, 1, "the one fixture teacher")
        assertEqual(cards[1].where:GetText(), "Fixture Vale", "no coordinates on the card")
        assertEqual(NS.Waypoints:Blocked(NS.TrainerPopup.Selected()), "nocoords")
        assertEqual(f.waypoint.blockedText,
            "No map coordinates for this trainer yet; Print to chat gives directions.")
    end)
end)

test("characterization: every shipped trainer record has a map position", function()
    for _, t in ipairs(NS.Trainers_Forever) do
        assertTrue(type(t.mapID) == "number" and type(t.x) == "number" and type(t.y) == "number",
            t.name .. " has mapID, x and y")
    end
end)
