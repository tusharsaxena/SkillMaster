-- tests/test_families.lua — the family registry and the block engine's provider dispatch (item SMW-02 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md). No visible change: the eight blocks keep their
-- rows, their titles and their order.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("families: six families in the character panel's order, each with a title, blocks and a feed", function()
    assertEqual(table.concat(NS.FAMILY_ORDER, ","), "professions,skills,stats,currencies,reputations,statistics")
    local names = {}
    for fid, f in NS.EachFamily() do
        assertEqual(f.id, fid)
        assertTrue(type(f.title) == "string" and f.title ~= "", fid .. " title")
        assertTrue(#f.blocks >= 1, fid .. " blocks")
        assertTrue(type(f.source) == "string", fid .. " source")
        assertTrue(type(f.rowKind) == "string", fid .. " rowKind")
        assertTrue(type(f.message) == "string", fid .. " message")
        assertTrue(type(f.feed.name) == "string" and type(f.feed.label) == "string", fid .. " feed")
        assertTrue(not names[f.feed.name], "feed names are unique: " .. f.feed.name)
        names[f.feed.name] = true
    end
end)

test("families: the split and the kept broker names (the spec's calls)", function()
    local F = NS.Families
    assertEqual(table.concat(F.professions.blocks, ","), "primary,secondary")
    assertEqual(table.concat(F.skills.blocks, ","), "weapon,other")
    assertEqual(table.concat(F.stats.blocks, ","), "stats_base,stats_spell,stats_defense,stats_utility")
    assertEqual(F.professions.feed.name, "Skill Master", "a display stores the Professions feed by this name")
    assertEqual(F.stats.feed.name, "Skill Master Stats", "and Character Stats by this one")
    assertEqual(F.stats.title, "Skill Master \194\183 Character Stats")
    assertEqual(F.statistics.title, "Skill Master \194\183 Statistics", "Statistics is never called stats")
    for _, fid in ipairs({ "currencies", "reputations", "statistics" }) do
        assertTrue(F[fid].tree, fid .. " is drawn by the tree model")
    end
end)

test("families: every block belongs to exactly one family, and its def says which", function()
    local seen = {}
    for fid, f in NS.EachFamily() do
        for _, bid in ipairs(f.blocks) do
            assertTrue(not seen[bid], bid .. " in two families")
            seen[bid] = fid
            assertEqual(NS.FamilyOf(bid).id, fid)
        end
    end
    for _, bid in ipairs(NS.BLOCKS) do
        assertTrue(seen[bid] ~= nil, bid .. " has no family")
        assertEqual(NS.BlockDefs[bid].family, seen[bid], bid)
        assertEqual(NS.BlockDefs[bid].source, NS.Families[seen[bid]].source, bid .. "'s provider is its family's")
    end
    assertEqual(NS.FamilyOf("nope"), nil)
end)

test("blocks: NS.BLOCKS keeps the eight skill and stat blocks first, then the tree blocks (SMW-08..10)", function()
    assertEqual(table.concat(NS.BLOCKS, ","),
        "primary,secondary,weapon,other,stats_base,stats_spell,stats_defense,stats_utility,currencies,reputations")
    assertEqual(NS.BlockDefs.stats_base.title, "Stats \194\183 Base & Combat")
end)

test("blocks: the engine dispatches on B.PROVIDERS by the def's source", function()
    local B = NS.Blocks
    assertTrue(B.PROVIDERS.skills and B.PROVIDERS.stats, "the two providers")
    local calls = {}
    B.PROVIDERS.fake = {
        hiddenSet = "skills",
        model = function() return { "m" } end,
        entries = function(model, filter, isHidden)
            calls[#calls + 1] = { model = model, filter = filter, isHidden = isHidden }
            return { { kind = "fake", entry = { key = "a", name = "A" } } }
        end,
        groupOf = function() return "f" end,
    }
    NS.BlockDefs.fakeblock = { id = "fakeblock", title = "Fake", short = "Fake", source = "fake", filter = "f" }
    local ok, err = pcall(function()
        local entries = B.EntriesFrom("fakeblock", { fake = { "given" } })
        assertEqual(#entries, 1)
        assertEqual(entries[1].kind, "fake")
        assertEqual(calls[1].model[1], "given", "the models table's own entry for the source")
        assertEqual(calls[1].filter, "f")
        assertEqual(type(calls[1].isHidden), "function", "the window's hidden test when none is passed")
        B.EntriesFrom("fakeblock")
        assertEqual(calls[2].model[1], "m", "no models: the provider's live model")
    end)
    B.PROVIDERS.fake, NS.BlockDefs.fakeblock = nil, nil
    assertTrue(ok, tostring(err))
end)

test("blocks: Models() keys every provider's model by source, and Data() still answers skills, stats", function()
    local B = NS.Blocks
    local saved = B.source
    local skills, stats = { tag = "s" }, { tag = "t" }
    B.source = function() return skills, stats, { extra = { tag = "x" } } end
    local m = B.Models()
    local s1, s2, all = B.Data()
    B.source = saved
    assertEqual(m.skills.tag, "s"); assertEqual(m.stats.tag, "t"); assertEqual(m.extra.tag, "x")
    assertEqual(s1.tag, "s"); assertEqual(s2.tag, "t"); assertEqual(all.extra.tag, "x")
    assertEqual(type(B.Models()), "table", "the live models, keyed by source")
end)

test("blocks: Entries(id, skills, stats) and EntriesFrom(id, models) answer the same rows", function()
    local B = NS.Blocks
    local skills, stats = B.Data()
    for _, id in ipairs(NS.BLOCKS) do
        local a = B.Entries(id, skills, stats)
        local b = B.EntriesFrom(id, { skills = skills, stats = stats })
        assertEqual(#a, #b, id)
        for i = 1, #a do assertEqual(a[i].entry.key, b[i].entry.key, id .. " row " .. i) end
    end
    assertEqual(#B.Entries("nope"), 0, "an unknown block has no rows")
end)
