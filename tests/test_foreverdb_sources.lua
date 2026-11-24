-- tests/test_foreverdb_sources.lua — ForeverDB in Skill Master (LibKa0s#105, item SF-SM-02 of
-- Ka0sAddonsCommonTasks docs/2026-11-25-SEEDS_AND_FOREVERDB/; WowAddonStandards clients-§11).
--
-- The characterization cases come first and pin what the display does with no ForeverDB at all: a
-- book rank's row tooltip says who sells the book and nothing more, and a trainer record with no
-- position is shown without coordinates and sends its waypoint to chat. The feature must leave
-- both exactly so whenever ForeverDB cannot answer.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertNil = T.test, T.assertEqual, T.assertTrue, T.assertNil

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

-- ---------------------------------------------------------------------------------------------
-- The feature, on the kit's fake (tests/_kit/mock_foreverdb.lua: invented rows in ForeverDB's
-- shape, ids 990000 and up; no row of the real database is in this repo)
-- ---------------------------------------------------------------------------------------------

local FakeDB = dofile("tests/_kit/mock_foreverdb.lua")
local IDS = FakeDB.IDS
local F = NS.ForeverDBSources
local Lib = M.LibStub("LibKa0s-ForeverDB-1.0")

-- The fake installed with `opts` (client "forever" unless given) while `fn(fake)` runs; the
-- adapter's cached answer is forgotten on both sides.
local function withFake(opts, fn)
    opts = opts or {}
    if opts.client == nil then opts.client = "forever" end
    Lib.__reset()
    local fake = FakeDB.install(M, opts)
    local ok, err = pcall(fn, fake)
    fake.restore()
    Lib.__reset()
    if not ok then error(err, 0) end
end

local function withSetting(on, fn)
    local saved = NS.db.profile.trainers.foreverDB
    NS.SetByPath("trainers.foreverDB", on)
    local ok, err = pcall(fn)
    NS.SetByPath("trainers.foreverDB", saved)
    if not ok then error(err, 0) end
end

-- An invented book vendor whose rank is learned from the fixture's blade.
local BOOK_VENDOR = { id = "sfsm02_book", name = "Fixture Bookseller", faction = "Neutral",
                      city = "Fixture Vale", mapName = "Fixture Vale", mapID = 9905, x = 10, y = 20,
                      teaches = { "cooking" }, ranks = { 225 },
                      learn = { kind = "book", itemID = IDS.blade, item = "Fixture Blade" } }

-- The row tooltip's lines for Cooking 150/150, its next rank taught by BOOK_VENDOR alone.
local function bookRankLines()
    local saved = NS.Trainers.NextRank
    NS.Trainers.NextRank = function()
        return { rankName = "Expert", cap = 225, minLevel = 20, minSkill = 125, trainers = { BOOK_VENDOR },
                 groups = {}, higher = true }
    end
    local e = { key = "cooking", name = "Cooking", category = "secondary", learned = true,
                rank = 150, max = 150, modifier = 0 }
    local ok, lines = pcall(NS.RowTooltip.Lines, e, "skill", "row")
    NS.Trainers.NextRank = saved
    if not ok then error(lines, 0) end
    local out = {}
    for _, l in ipairs(lines) do if l.left then out[#out + 1] = l.left .. "|" .. tostring(l.right) end end
    return out
end

-- The lines after the Trainer line, up to the click hint (the last line).
local function afterTrainer(lines)
    local at = indexOf(lines, "Trainer|")
    local out = {}
    for i = at + 1, #lines - 1 do out[#out + 1] = lines[i] end
    return table.concat(out, " ; ")
end

test("foreverdb: nothing loads ForeverDB at file load; a tooltip with no book and a placed popup ask nothing", function()
    withFake({ preset = "present" }, function(fake)
        -- The module's file, loaded again into a fresh namespace with the fake in place.
        local fresh = { L = NS.L, defaults = NS.defaults }
        T.Loader.load("modules/ForeverDBSources.lua", fresh, M)
        assertTrue(fresh.ForeverDBSources ~= nil, "the module loaded")
        assertEqual(fake.loads, 0, "loading the module loaded nothing")
        asAllianceHuman(function()
            fishingLines(50, 75)   -- Journeyman next: a trainer trains it, no book
            assertEqual(fake.loads, 0, "a tooltip without a book asks nothing")
        end)
        NS.TrainerPopup.Show("fishing")
        NS.TrainerPopup.Hide()
        assertEqual(fake.loads, 0, "a popup whose records all have a position asks nothing")
    end)
end)

test("foreverdb present: a book rank's row tooltip lists sellers, drops by chance and the world drop", function()
    withFake({ preset = "present" }, function(fake)
        asAllianceHuman(function()
            local text = afterTrainer(bookRankLines())
            assertEqual(text, "Fixture Blade|ForeverDB ; Sold by|Fixture Vendor, Fixture Trainer"
                .. " ; Drops from|Fixture Gnoll \194\183 25% ;  |Fixture Kobold \194\183 rate unknown"
                .. " ; World drop|from Lv 8")
        end)
        assertEqual(fake.loads, 1, "the tooltip's lookup loaded ForeverDB, once")
        asAllianceHuman(function() bookRankLines() end)
        assertEqual(fake.loads, 1, "a second tooltip loads nothing more")
    end)
end)

test("foreverdb present: a seller of the other faction is left out", function()
    withFake({ preset = "present" }, function()
        local f = M.UnitFactionGroup
        M.UnitFactionGroup = function() return "Horde", "Horde" end
        local ok, text = pcall(function() return afterTrainer(bookRankLines()) end)
        M.UnitFactionGroup = f
        if not ok then error(text, 0) end
        assertTrue(text:find("Sold by|Fixture Vendor ;", 1, true) ~= nil, "the Alliance trainer is not named: " .. text)
    end)
end)

test("foreverdb present: past three sellers or three drops, the rest is counted", function()
    local data = FakeDB.fixture()
    local vend, drop = {}, {}
    for i = 1, 5 do
        local id = 990500 + i
        data.npc[id] = { "Fixture Extra " .. i, nil, 1, 1, 0 }
        vend[#vend + 1] = id
        drop[#drop + 1] = id
        drop[#drop + 1] = 1000 * i
    end
    data.vend[IDS.blade] = vend
    data.drop[IDS.blade] = drop
    withFake({ preset = "present", data = data }, function()
        asAllianceHuman(function()
            local text = afterTrainer(bookRankLines())
            assertTrue(text:find("Sold by|Fixture Extra 1, Fixture Extra 2, Fixture Extra 3 +2 more", 1, true) ~= nil, text)
            assertTrue(text:find("Drops from|Fixture Extra 5 \194\183 50%", 1, true) ~= nil, "most likely first: " .. text)
            assertTrue(text:find(" |+2 more", 1, true) ~= nil, text)
        end)
    end)
end)

test("foreverdb present: an item ForeverDB names no source for adds nothing", function()
    withFake({ preset = "present" }, function()
        assertNil(F.SourceLines(IDS.pebble, "Fixture Pebble"))
        assertNil(F.SourceLines("990101", "a string id"))
    end)
end)

test("foreverdb present: a trainer with no position takes ForeverDB's spot through a view", function()
    withFake({ preset = "present" }, function(fake)
        local rec = coordless()
        withFixturePopup(rec, function()
            local cards = NS.TrainerPopup.Cards()
            assertEqual(cards[1].where:GetText(), "Fixture Vale (50, 25)", "the card shows the spot")
            local t = NS.TrainerPopup.Selected()
            assertEqual(t.mapID, IDS.mapA)
            assertEqual(t.x, 50)
            assertEqual(t.y, 25)
            assertEqual(t.spotSource, "ForeverDB")
            assertEqual(t.name, "Fixture Teacher", "the view reads the record's own fields")
            assertTrue(NS.Waypoints:Blocked(t) ~= "nocoords", "the waypoint is no longer blocked for coordinates")
            assertNil(rec.x, "the record itself is untouched")
            assertNil(rec.mapID, "the record itself is untouched")
        end)
        assertEqual(fake.loads, 1, "the popup's lookup loaded ForeverDB")
    end)
end)

test("foreverdb present: the card's tooltip says where the position came from", function()
    withFake({ preset = "present" }, function()
        withFixturePopup(coordless(), function()
            local saved, seen = M.GameTooltip, {}
            local tip = setmetatable({}, { __index = saved })
            tip.AddLine = function(_, s) seen[#seen + 1] = s end
            M.GameTooltip = tip
            local c = NS.TrainerPopup.Cards()[1]
            local ok, err = pcall(c:GetScript("OnEnter"), c)
            M.GameTooltip = saved
            if not ok then error(err, 0) end
            assertEqual(seen[#seen], "Map position from ForeverDB", table.concat(seen, " ; "))
        end)
    end)
end)

test("foreverdb present: a shipped position is never overridden, and ForeverDB is not asked", function()
    withFake({ preset = "present" }, function(fake)
        local rec = coordless({ mapID = 9905, x = 12.5, y = 34.5 })
        assertTrue(F.Placed(rec) == rec, "a placed record is answered as itself")
        withFixturePopup(rec, function()
            assertEqual(NS.Trainers_Forever[#NS.Trainers_Forever].x, 12.5)
            assertEqual(NS.TrainerPopup.Cards()[1].where:GetText(), "Fixture Vale (13, 35)")
        end)
        assertEqual(fake.loads, 0, "nothing loaded")
    end)
end)

test("foreverdb present: a record on a map ForeverDB has no spot on stays without coordinates", function()
    withFake({ preset = "present" }, function()
        withFixturePopup(coordless({ mapID = IDS.mapB }), function()
            assertEqual(NS.Waypoints:Blocked(NS.TrainerPopup.Selected()), "nocoords")
            assertEqual(NS.TrainerPopup.Cards()[1].where:GetText(), "Fixture Vale")
        end)
    end)
end)

-- Every way ForeverDB cannot answer leaves the display exactly as the characterization pinned it.
local function assertInert(label)
    asAllianceHuman(function()
        assertEqual(afterTrainer(bookRankLines()), "", label .. ": no source lines")
    end)
    withFixturePopup(coordless(), function(f)
        assertEqual(NS.TrainerPopup.Cards()[1].where:GetText(), "Fixture Vale", label .. ": no coordinates")
        assertEqual(f.waypoint.blockedText,
            "No map coordinates for this trainer yet; Print to chat gives directions.", label)
    end)
end

for _, preset in ipairs({ "missing", "loadfails", "reshaped" }) do
    test("foreverdb " .. preset .. ": the tooltip and the popup are unchanged", function()
        withFake({ preset = preset }, function()
            assertInert(preset)
            assertTrue(not F.Ready(), preset .. ": not ready")
        end)
    end)
end

test("foreverdb off Forever (the Retail case, under the Forever-only profile): inert, nothing loads", function()
    withFake({ preset = "present", client = "retail" }, function(fake)
        assertInert("retail")
        assertTrue(not F.Ready(), "not ready on Retail")
        assertEqual(fake.loads, 0, "nothing loaded on Retail")
    end)
end)

test("foreverdb: Use ForeverDB off reads nothing and loads nothing", function()
    withFake({ preset = "present" }, function(fake)
        withSetting(false, function()
            assertInert("Use ForeverDB off")
            assertTrue(not F.Enabled(), "off")
        end)
        assertEqual(fake.loads, 0, "nothing loaded")
    end)
end)

test("foreverdb: drop chances as the tooltip reads them", function()
    assertEqual(F.FormatChance(0.25), "25%")
    assertEqual(F.FormatChance(1), "100%")
    assertEqual(F.FormatChance(0.004), "0.4%")
    assertEqual(F.FormatChance(0.0001), "<0.1%")
    assertEqual(F.FormatChance(nil), "rate unknown")
end)

test("foreverdb: the Use ForeverDB row is on the Trainers tab, on by default, and says it needs ForeverDB", function()
    local row
    for _, r in ipairs(NS.SchemaForPage("trainers")) do if r.path == "trainers.foreverDB" then row = r end end
    assertTrue(row ~= nil, "the row is on the page")
    assertEqual(row.group, NS.L["Trainers"])
    assertEqual(row.type, "bool")
    assertEqual(NS.defaults.profile.trainers.foreverDB, true, "on by default")
    assertTrue(row.desc:find("Needs the ForeverDB addon", 1, true) == 1, "the row says the feature needs it")
end)

test("foreverdb: an optional dependency only (TOC OptionalDeps, .pkgmeta optional-dependencies)", function()
    local function read(p)
        local f = assert(io.open(p, "rb"))
        local s = f:read("*a")
        f:close()
        return s
    end
    local toc = read("SkillMaster.toc")
    assertTrue(toc:match("\n## OptionalDeps:[^\n]*ForeverDB") ~= nil, "OptionalDeps names ForeverDB")
    assertTrue(toc:match("\n## Dependencies:[^\n]*ForeverDB") == nil, "never Dependencies")
    assertTrue(toc:match("\n## RequiredDeps:[^\n]*ForeverDB") == nil, "never RequiredDeps")
    local pkg = read(".pkgmeta")
    assertTrue(pkg:find("\noptional%-dependencies:%s*%- forever%-db") ~= nil, ".pkgmeta lists forever-db as optional")
    assertTrue(pkg:find("\n%s*required%-dependencies:") == nil, "never required-dependencies")
end)
