-- tests/test_no_foreverdb.lua — Character Ledger reads no ForeverDB (item ISF-SM-01 of Ka0sAddonsCommonTasks
-- docs/2026-11-25-ITEM_SEARCH_FEEDBACK/, spec §8: only Drop Watcher reads ForeverDB). SF-SM-02 had
-- added an optional ForeverDB reader (modules/ForeverDBSources.lua, Trainers > Use ForeverDB); it is
-- gone, so a book rank's sources and a trainer's position come from Character Ledger's own data alone.
--
-- The characterization cases SF-SM-02 wrote before its feature pin exactly that display, and they
-- stay: a book rank's row tooltip says who sells the book and nothing more, and a trainer record with
-- no position is shown without coordinates and sends its waypoint to chat. Then the removal itself:
-- no ForeverDB read in the addon's own Lua (libs/ and tests/_kit/, the vendored LibKa0s payloads,
-- are not the addon's), none in the TOC or .pkgmeta, no setting, and schemaVersion 13 drops the
-- stored key.
--
-- red under: put ForeverDB back in ## OptionalDeps or .pkgmeta; read LibKa0s-ForeverDB-1.0 or the
-- ForeverDB global from any addon file; restore the trainers.foreverDB default; drop step 13.
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
-- Characterization: the display from Character Ledger's own data (pinned by SF-SM-02, kept)
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

-- ---------------------------------------------------------------------------------------------
-- The removal (ISF-SM-01)
-- ---------------------------------------------------------------------------------------------

local function readFile(rel)
    local f = io.open(rel, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
end

-- `text` with its Lua comments blanked (long ones first), so a comment that tells this history is no
-- read. Rough on purpose: no addon string literal holds "--".
local function code(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

-- Every .lua file of the addon's own: the TOC's, then whatever else the tree holds (the suites
-- included), less libs/, tests/_kit/ and this file, which has to name what it looks for.
local SELF = "tests/test_no_foreverdb.lua"
local function ownLuaFiles()
    local seen, out = {}, {}
    local function add(rel)
        rel = rel:gsub("^%./", "")
        if seen[rel] or rel == SELF or rel:match("^libs/") or rel:match("^tests/_kit/") then return end
        seen[rel] = true
        out[#out + 1] = rel
    end
    for _, rel in ipairs(T.Loader.tocFiles("CharacterLedger.toc")) do add(rel) end
    local ok, p = pcall(io.popen, "find . -name '*.lua' -not -path './libs/*' -not -path './tests/_kit/*' -not -path './.git/*' 2>/dev/null")
    if ok and p then
        for line in p:lines() do add(line) end
        p:close()
    end
    return out
end

test("no ForeverDB: no addon Lua file outside libs/ and tests/_kit/ reads ForeverDB", function()
    local files = ownLuaFiles()
    assertTrue(#files > 50, "the scan reached the addon's files (" .. #files .. ")")
    local hits = {}
    for _, rel in ipairs(files) do
        local text = readFile(rel)
        assertTrue(text ~= nil, rel .. " is readable")
        local body = code(text)
        for _, needle in ipairs({ "ForeverDB", "forever%-db", "trainers%.foreverDB" }) do
            if body:find(needle) then hits[#hits + 1] = rel .. ": " .. needle:gsub("%%", "") end
        end
    end
    assertEqual(#hits, 0, "ForeverDB read in:\n" .. table.concat(hits, "\n"))
end)

test("no ForeverDB: the TOC and .pkgmeta name no ForeverDB dependency, and the module is gone", function()
    local toc = readFile("CharacterLedger.toc")
    for line in (toc .. "\n"):gmatch("([^\n]*)\n") do
        if line:match("^##") then assertTrue(line:find("ForeverDB") == nil, "TOC: " .. line) end
        assertTrue(line:find("ForeverDBSources") == nil, "TOC lists the module: " .. line)
    end
    local pkg = readFile(".pkgmeta")
    assertTrue(pkg ~= nil, ".pkgmeta is readable")
    assertTrue(pkg:find("forever%-db") == nil and pkg:find("ForeverDB") == nil, ".pkgmeta names no ForeverDB")
    assertTrue(readFile("modules/ForeverDBSources.lua") == nil, "modules/ForeverDBSources.lua is deleted")
    assertTrue(NS.ForeverDBSources == nil, "no NS.ForeverDBSources")
end)

test("no ForeverDB: no Use ForeverDB setting, default or string", function()
    assertTrue(NS.defaults.profile.trainers.foreverDB == nil, "no trainers.foreverDB default")
    assertTrue(NS.db.profile.trainers.foreverDB == nil, "the live profile answers nothing for it")
    assertTrue(rawget(NS.L, "Use ForeverDB") == nil, "no Use ForeverDB string")
end)

test("no ForeverDB: schemaVersion 13 drops a stored trainers.foreverDB from every profile", function()
    local sv = rawget(_G, "CharacterLedgerDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["ISF-Off"] = { trainers = { foreverDB = false, showAll = true } }
    sv.profiles["ISF-On"] = { trainers = { foreverDB = true } }
    sv.profiles["ISF-None"] = { bars = { height = 15 } }
    sv.profiles["ISF-Odd"] = { trainers = "not a table" }
    NS.db.global.schemaVersion = 12
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertTrue(NS.SCHEMA_VERSION >= 13, "step 13 is in the ladder")
    assertTrue(sv.profiles["ISF-Off"].trainers.foreverDB == nil, "a stored false goes")
    assertEqual(sv.profiles["ISF-Off"].trainers.showAll, true, "the rest of trainers stays")
    assertTrue(sv.profiles["ISF-On"].trainers.foreverDB == nil, "a stored true goes")
    assertTrue(sv.profiles["ISF-None"].trainers == nil, "a profile with no trainers passes through")
    assertEqual(sv.profiles["ISF-Odd"].trainers, "not a table", "a malformed trainers is left alone")
    for _, k in ipairs({ "ISF-Off", "ISF-On", "ISF-None", "ISF-Odd" }) do sv.profiles[k] = nil end
end)
