-- tests/test_database.lua — the AceDB store and the migration runner (savedvariables-§1).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("database: the defaults stamp 0 and the runner raises it to the code's target", function()
    assertEqual(NS.defaults.global.schemaVersion, 0, "the default is 0, never the current version")
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: the runner is idempotent", function()
    NS:RunMigrations()
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: a fresh profile wears the library's per-client default skin (skinning-§2)", function()
    assertEqual(NS.defaults.profile.skin.skin, NS.DEFAULT_SKIN)
    assertTrue(NS.DEFAULT_SKIN ~= "ka0s", "on the Forever profile the library answers WoW Forever, got "
        .. tostring(NS.DEFAULT_SKIN))
end)
