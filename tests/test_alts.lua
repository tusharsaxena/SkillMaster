-- tests/test_alts.lua — Alts: each character's skills snapshotted into db.global.characters, keyed by
-- the character's whole two-word Forever name (forever-quirks-§4), on SKILLS_UPDATED and at logout.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local A = NS.Alts

local function model()
    return {
        byKey = {
            leatherworking = { key = "leatherworking", name = "Leatherworking", category = "primary",
                               rank = 146, max = 150, learned = true },
            bows = { key = "bows", name = "Bows", category = "weapon", rank = 80, max = 110, learned = true },
            swords = { key = "swords", name = "Swords", category = "weapon", rank = 0, max = 0, learned = false },
        },
        order = { primary = { "leatherworking" }, secondary = {}, weapon = { "bows", "swords" }, other = {} },
    }
end

--- Run `fn` as the character `char` on the realm key `realm` (AceDB 40's db.keys), with `m` as the
--- skills model; restores the keys, the model reader and the store's prior characters.
local function as(char, realm, m, fn)
    local keys, saved = NS.db.keys, {}
    saved.char, saved.realm = keys.char, keys.realm
    keys.char, keys.realm = char, realm
    local realModel = NS.SkillData.Model
    NS.SkillData.Model = function() return m end
    local ok, err = pcall(fn)
    NS.SkillData.Model = realModel
    keys.char, keys.realm = saved.char, saved.realm
    if not ok then error(err, 0) end
end

local function forgetAll()
    for key in pairs(NS.db.global.characters) do NS.db.global.characters[key] = nil end
end

test("test_alts_snapshot_two_word_name: the key is realm-key, then the whole two-word name", function()
    forgetAll()
    local realName = M.UnitName
    -- Forever's UnitName answers the first name and the SURNAME, never a realm.
    M.UnitName = function() return "Traxex", "Silentshot" end
    as("Traxex Silentshot", "PvP", model(), function() A:Snapshot(5000) end)
    as("Traxex Ironhide", "PvP", model(), function() A:Snapshot(5001) end)
    M.UnitName = realName
    local chars = NS.db.global.characters
    assertTrue(chars["PvP-Traxex Silentshot"] ~= nil, "keyed by the whole name")
    assertTrue(chars["PvP-Traxex Ironhide"] ~= nil, "a second Traxex is a second character")
    assertTrue(chars["Silentshot-Traxex"] == nil and chars["PvP-Traxex"] == nil,
        "never the surname as a realm, never the first word alone")
    local rec = chars["PvP-Traxex Silentshot"]
    assertEqual(rec.name, "Traxex Silentshot")
    assertEqual(rec.updated, 5000)
    assertEqual(rec.skills.leatherworking.rank, 146)
    assertEqual(rec.skills.leatherworking.max, 150)
    assertEqual(rec.skills.bows.category, "weapon")
    assertTrue(rec.skills.swords == nil, "an unlearned row is not a skill the character has")
    assertEqual(#A:List(), 2)
    forgetAll()
end)

test("alts: a half-loaded (empty) model keeps the skills the last snapshot had", function()
    forgetAll()
    local empty = { byKey = {}, order = { primary = {}, secondary = {}, weapon = {}, other = {} } }
    as("Ember Ironsong", "PvE", model(), function() A:Snapshot(1) end)
    as("Ember Ironsong", "PvE", empty, function() A:Snapshot(2) end)
    local rec = NS.db.global.characters["PvE-Ember Ironsong"]
    assertEqual(rec.updated, 2, "the record is touched")
    assertEqual(rec.skills.bows.rank, 80, "and its skills survive")
    forgetAll()
end)

test("alts: List puts this character first, then by name; Forget drops one", function()
    forgetAll()
    as("Zed Alpha", "PvE", model(), function() A:Snapshot(1) end)
    as("Abe Beta", "PvE", model(), function() A:Snapshot(1) end)
    as("Mia Gamma", "PvE", model(), function()
        A:Snapshot(1)
        local list = A:List()
        assertEqual(list[1].key, "PvE-Mia Gamma")
        assertTrue(list[1].isCurrent, "the current character is marked")
        assertEqual(list[2].key, "PvE-Abe Beta")
        assertEqual(list[3].key, "PvE-Zed Alpha")
    end)
    assertTrue(A:Forget("PvE-Zed Alpha"))
    assertFalse(A:Forget("PvE-Zed Alpha"), "already gone")
    assertEqual(#A:List(), 2)
    forgetAll()
end)

test("alts: a burst of SKILLS_UPDATED is one debounced snapshot; PLAYER_LOGOUT snapshots at once", function()
    forgetAll()
    M.__fireTimers()
    as("Quill Ashbrook", "PvE", model(), function()
        NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, model())
        NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, model())
        assertTrue(NS.db.global.characters["PvE-Quill Ashbrook"] == nil, "nothing before the debounce")
        local queued = 0
        for _, t in ipairs(M.__timers) do
            if math.abs((t.delay or 0) - A.DEBOUNCE) < 1e-9 then queued = queued + 1 end
        end
        assertEqual(queued, 1, "one timer for the burst")
        M.__fireTimers()
        assertTrue(NS.db.global.characters["PvE-Quill Ashbrook"] ~= nil, "snapshotted after it")
    end)
    forgetAll()
    as("Quill Ashbrook", "PvE", model(), function() M.__fireEvent("PLAYER_LOGOUT") end)
    assertTrue(NS.db.global.characters["PvE-Quill Ashbrook"] ~= nil, "logout snapshots without waiting")
    forgetAll()
end)

-- ── FB-33: the snapshot carries the stats the main window's four stat blocks show ────────────

local function statModel()
    return NS.StatData.Build({ strength = 88, armor = { 30, 1500 }, meleeCrit = 5.2 }, 22)
end

test("alts: the snapshot carries the character's stats by key, with each one's block and display", function()
    -- red under: a record with skills alone (the Alts stat sub-tabs would be all dashes)
    forgetAll()
    local realModel = NS.StatData.Model
    NS.StatData.Model = function() return statModel() end
    local ok, err = pcall(as, "Ember Ironsong", "PvE", model(), function() A:Snapshot(10) end)
    NS.StatData.Model = realModel
    if not ok then error(err, 0) end
    local st = NS.db.global.characters["PvE-Ember Ironsong"].stats
    assertTrue(st ~= nil, "stats stored")
    assertEqual(st.strength.group, "base")
    assertEqual(st.strength.value, 88)
    assertEqual(st.strength.display, "88")
    assertTrue(type(st.strength.pct) == "number", "the bar's scale too")
    assertEqual(st.armor.group, "defense")
    forgetAll()
end)

test("alts: no stat model keeps the stats the last snapshot had; an old snapshot has none", function()
    forgetAll()
    local realModel, realScan = NS.StatData.Model, NS.StatData.Scan
    NS.StatData.Model = function() return statModel() end
    as("Ember Ironsong", "PvE", model(), function() A:Snapshot(1) end)
    NS.StatData.Model, NS.StatData.Scan = function() return nil end, function() return nil end
    local ok, err = pcall(as, "Ember Ironsong", "PvE", model(), function() A:Snapshot(2) end)
    NS.StatData.Model, NS.StatData.Scan = realModel, realScan
    if not ok then error(err, 0) end
    assertEqual(NS.db.global.characters["PvE-Ember Ironsong"].stats.strength.value, 88, "kept")
    assertEqual(A.StatsOf(nil), nil, "no model, no stats: the Journal draws a dash")
    forgetAll()
end)
