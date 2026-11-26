-- tests/test_r6_owner.lua — owner feedback round 6 (Ka0sAddonsCommonTasks docs/2026-11-27-OWNER_FEEDBACK_ROUND6/).
-- R6-SM-01: "Rename secondary skills to secondary professions": every label Skill Master gives that group reads
-- Secondary Professions; the client's own Skills-tab header ("Secondary Skills") is game data and still files
-- Cooking, First Aid and Fishing there, and the block's id, its saved settings and its short label stay.
-- R6-SM-02: the Journal Log's Type column (below).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- ---------------------------------------------------------------------------------------------
-- R6-SM-01: Secondary Professions
-- ---------------------------------------------------------------------------------------------

local function skill(key, name, category, rank, max)
    return { key = key, name = name, category = category, rank = rank, max = max, tempPoints = 0,
             modifier = 0, learned = true }
end

local function withWorld(fn)
    local B = NS.Blocks
    local skills = { byKey = { fishing = skill("fishing", "Fishing", "secondary", 107, 150),
                               skinning = skill("skinning", "Skinning", "primary", 122, 150) },
                     order = { primary = { "skinning" }, secondary = { "fishing" }, weapon = {}, other = {} } }
    local stats = { base = {}, spell = {}, defense = {}, utility = {} }
    local savedSource = B.source
    B.source = function() return skills, stats end
    local ok, err = pcall(fn)
    B.source = savedSource
    NS.MainWindow.Hide()
    if not ok then error(err, 0) end
end

test("r6 sm-01: the group's title reads Secondary Professions; its id and short label stay", function()
    local d = NS.BlockDefs.secondary
    assertEqual(d.title, "Secondary Professions", "the window's group header")
    assertEqual(NS.Blocks.HomeTitle("secondary"), "Secondary Professions", "in its own family's window and feed")
    assertEqual(d.short, "Secondary", "the short label (Alts sub-tab, merged title) unchanged")
    assertEqual(d.id, "secondary", "the id the saved settings key on")
    assertTrue(NS.defaults.profile.layout.blocks.secondary ~= nil, "the saved block settings keep their key")
end)

test("r6 sm-01: a detached Secondary window is titled Secondary Professions", function()
    withWorld(function()
        local B, D = NS.Blocks, NS.Detached
        B:Detach("secondary")
        local ok, err = pcall(function()
            assertEqual(D.Frame("secondary").title:GetText(), "Secondary Professions")
        end)
        B:Dock("secondary")
        if not ok then error(err, 0) end
    end)
end)

test("r6 sm-01: the settings labels and the Professions window's binding tip say secondary professions", function()
    assertEqual(NS.FindSchemaRow("broker.tooltip.sections.secondary").label, "Secondary professions",
        "the Professions feed's tooltip section")
    local swatch = NS.FindSchemaRow("bars.colors.secondary")
    assertEqual(swatch.label, "Secondary professions", "the bar color swatch")
    assertTrue(swatch.desc:find("secondary profession's bar", 1, true) ~= nil, swatch.desc)
    local tip = NS.BINDINGS[1].tooltip   -- the family order's first: Professions
    assertEqual(tip, "Shows or hides the Professions window: primary and secondary professions.", "the binding's tip")
end)

test("r6 sm-01: the client's own header, Secondary Skills, still files its lines in the Secondary group", function()
    local SD = NS.SkillData
    local model = SD.Build({ { rec = { name = "Fishing", rank = 107, max = 150, tempPoints = 0, modifier = 0 },
                                             header = "Secondary Skills" } }, { classFile = "HUNTER", level = 20 })
    assertEqual(model.byKey.fishing and model.byKey.fishing.category, "secondary")
end)
