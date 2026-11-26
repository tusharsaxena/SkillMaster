-- tests/test_feeds.lua — the six broker feeds (item SMW-05 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md): one LibDataBroker data source per family,
-- built from the registry, each with its own template, sections, pin, flash and clicks; the
-- schemaVersion 15 step; the split of modules/Broker.lua.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B = NS.Broker

local function skill(key, name, category, rank, max)
    return { key = key, name = name, category = category, rank = rank, max = max, modifier = 0,
             tempPoints = 0, learned = true }
end

local function publish()
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, {
        byKey = { skinning = skill("skinning", "Skinning", "primary", 122, 150),
                  cooking = skill("cooking", "Cooking", "secondary", 133, 150),
                  bows = skill("bows", "Bows", "weapon", 80, 110),
                  defense = skill("defense", "Defense", "other", 100, 110) },
        order = { primary = { "skinning" }, secondary = { "cooking" }, weapon = { "bows" }, other = { "defense" } },
    })
    local crit = { key = "rangedCrit", label = "Ranged Crit", value = 9.1, display = "9.1%", pct = 30, markers = {} }
    NS.bus:SendMessage(NS.MSG.STATS_UPDATED, { base = { crit }, spell = {}, defense = {}, utility = {} })
end

--- Run `fn` on a fresh session and the fixture models, the pins and the templates put back after.
local function withFeeds(fn)
    M.__fireTimers()
    B.ResetSession()
    publish()
    local char, pins = NS.db.char, NS.db.char.pins
    char.pins = {}
    B.Refresh()
    local ok, err = pcall(fn)
    char.pins = pins
    for fid in pairs(B.FEEDS) do
        NS.SetByPath("broker.feeds." .. fid .. ".template", NS.defaults.profile.broker.feeds[fid].template)
    end
    B.ResetSession()
    B.Refresh()
    if not ok then error(err, 0) end
end

--- A recording tooltip: its lines as text.
local function recordingTip()
    local lines = {}
    local tip = M.CreateFrame("GameTooltip", "SkillMasterFeedsTip", M.UIParent)
    function tip:AddLine(t) lines[#lines + 1] = t end
    function tip:AddDoubleLine(l, r) lines[#lines + 1] = l .. " " .. tostring(r) end
    function tip:NumLines() return #lines end
    return tip, lines
end

test("feeds: one data source per family, in the family order, the two shipped names kept", function()
    local want = {
        professions = { "Skill Master", "Skill Master" },
        skills = { "Skill Master Skills", "Skill Master Skills" },
        stats = { "Skill Master Stats", "Skill Master Character Stats" },
        currencies = { "Skill Master Currencies", "Skill Master Currencies" },
        reputations = { "Skill Master Reputations", "Skill Master Reputations" },
        statistics = { "Skill Master Statistics", "Skill Master Statistics" },
    }
    for fid, w in pairs(want) do
        local f = B.FEEDS[fid]
        assertEqual(f.name, w[1], fid .. "'s LibDataBroker name")
        local obj = M.__ldbObjects[f.name]
        assertTrue(obj ~= nil and obj == B.ObjectFor(fid), fid .. " is registered")
        assertEqual(obj.type, "data source")
        assertEqual(obj.label, w[2], fid .. "'s label")
        assertEqual(table.concat(f.sections, ","), table.concat(NS.Families[fid].blocks, ","), fid .. ": its family's blocks")
        assertEqual(f.title, NS.Families[fid].title, fid .. "'s tooltip title is its window's")
    end
end)

test("feeds: with nothing pinned, a {pinned} feed reads its family's short name", function()
    withFeeds(function()
        for fid in pairs(B.FEEDS) do
            assertEqual(B.TextFor(fid), NS.Families[fid].short, fid)
        end
        NS.SetByPath("broker.feeds.currencies.template", " - ")
        assertEqual(B.TextFor("currencies"), "Skill Master Currencies", "a blank render falls back to the label")
    end)
end)

test("feeds: each feed's template is its own", function()
    withFeeds(function()
        assertTrue(NS.SetByPath("broker.feeds.skills.template", "{skill:bows} \194\183 {level}"))
        assertTrue(B.TextFor("skills"):find("^Bows 80/110") ~= nil, B.TextFor("skills"))
        assertEqual(B.Text(), "Professions", "the Professions feed keeps its own")
        assertEqual(B.Template("skills"), "{skill:bows} \194\183 {level}")
        assertEqual(B.Template("professions"), NS.defaults.profile.broker.feeds.professions.template)
    end)
end)

test("feeds: a pinned skill shows on its own family's feed", function()
    withFeeds(function()
        NS.Pins.Toggle("skills", "bows")
        assertEqual(B.TextFor("skills"), "Bows 80/110", "a weapon pin on the Skills feed")
        assertEqual(B.Text(), "Professions", "not on the Professions feed")
        NS.Pins.Remove("skills", "bows")
        NS.Pins.Toggle("professions", "cooking")
        assertEqual(B.Text(), "Cooking 133/150 \194\183 +0", "a profession pin on the Professions feed")
        assertEqual(B.TextFor("skills"), "Skills")
    end)
end)

test("feeds: the Character Stats feed's {pinned} is its pinned stat, in any template", function()
    withFeeds(function()
        NS.Pins.Toggle("stats", "rangedCrit")
        assertEqual(B.StatsText(), "Ranged Crit 9.1%")
        assertTrue(NS.SetByPath("broker.feeds.stats.template", "{pinned} \194\183 Lv {level}"))
        assertEqual(B.StatsText():find("Ranged Crit 9.1% \194\183 Lv ", 1, true), 1, B.StatsText())
    end)
end)

test("feeds: a skill-up flashes its own family's feed alone", function()
    withFeeds(function()
        NS.bus:SendMessage(NS.MSG.SKILL_UP, "cooking", 133, 134)
        assertTrue(B.Text():find("Cooking 134", 1, true) ~= nil, "Professions flashes: " .. B.Text())
        assertEqual(B.TextFor("skills"), "Skills", "Skills does not")
        assertEqual(B.Flashing(), "professions")
        NS.bus:SendMessage(NS.MSG.SKILL_UP, "defense", 100, 101)
        assertTrue(B.TextFor("skills"):find("Defense 101", 1, true) ~= nil, "a later skill-up moves the flash")
        assertEqual(B.Text(), "Professions", "and the first feed's ends")
        M.__now = M.__now + B.FlashSeconds() + 1
        M.__fireTimers()
        assertEqual(B.Flashing(), nil, "the flash ends")
    end)
end)

test("feeds: a tree family's tooltip says it has nothing yet, in both styles", function()
    withFeeds(function()
        local tip, lines = recordingTip()
        local rows = B.FillTooltip(tip, "reputations")
        local text = table.concat(lines, "\n")
        assertEqual(#rows, 0, "no rows")
        assertTrue(text:find("Skill Master \194\183 Reputations", 1, true) ~= nil, text)
        assertTrue(text:find("Nothing to show yet.", 1, true) ~= nil, text)
        assertEqual(select(2, B.Heading()), "", "no session gains line on a feed that gains no skill")
        local ldb = NS.db.profile.tooltips.ldb
        local style = ldb.style
        ldb.style = "window"
        B.OnEnter(M.UIParent, "statistics")
        local f = NS.BrokerPanel.Frame()
        local said = f.empty:GetText()
        B.HideTooltip()
        ldb.style = style
        assertEqual(said, "Nothing to show yet.", "the Main window style's line")
        B.SetFeed(B.DEFAULT_FEED)
    end)
end)

test("feeds: each feed's cell toggles its own window; a right click opens the Broker page", function()
    NS.Windows.HideAll()
    for fid in pairs(B.FEEDS) do
        B.ObjectFor(fid).OnClick(nil, "LeftButton")
        assertTrue(NS.Windows.Get(fid).IsShown(), fid .. "'s window opens")
        B.ObjectFor(fid).OnClick(nil, "LeftButton")
        assertFalse(NS.Windows.Get(fid).IsShown(), fid .. "'s window closes")
    end
    local saved, opened = NS.Helpers.OpenOptionsPanel, nil
    NS.Helpers.OpenOptionsPanel = function(page) opened = page end
    B.ObjectFor("currencies").OnClick(nil, "RightButton")
    NS.Helpers.OpenOptionsPanel = saved
    assertEqual(opened, "broker")
end)

test("feeds: stood down, every feed reads Off", function()
    withFeeds(function()
        local real = NS.IsStoodDown
        NS.IsStoodDown = function() return true end
        B.Refresh()
        local texts = {}
        for fid in pairs(B.FEEDS) do texts[fid] = B.TextFor(fid) end
        NS.IsStoodDown = real
        B.Refresh()
        for fid, t in pairs(texts) do assertEqual(t, "Off", fid) end
    end)
end)

test("feeds: the Broker page has a template pair and the section switches per feed", function()
    local rows = {}
    for _, row in ipairs(NS.SchemaForPage("broker")) do rows[row.path] = row end
    for fid in pairs(B.FEEDS) do
        local t = rows["broker.feeds." .. fid .. ".template"]
        assertTrue(t ~= nil and rows["broker.feeds." .. fid .. ".preset"] ~= nil, fid .. "'s template pair")
        assertEqual(t.subgroup, NS.Families[fid].short, fid .. "'s own subsection")
        assertEqual(t.default, NS.defaults.profile.broker.feeds[fid].template)
    end
    assertEqual(rows["broker.tooltip.sections.weapon"].subgroup, "Skills", "a section sits under its feed")
    assertEqual(rows["broker.tooltip.sections.stats_base"].subgroup, "Character Stats")
    assertTrue(rows["broker.template"] == nil, "no one template")
end)

test("feeds: schemaVersion 15 moves the one template to the Professions feed's", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    local p = sv.profiles
    local D = NS.defaults.profile.broker.feeds.professions.template
    p["Feed-Old"] = { broker = { template = "{last} Lv {level}", flashSeconds = 2 } }
    p["Feed-Kept"] = { broker = { template = "{level}", feeds = { professions = { template = "{gains}" } } } }
    p["Feed-Copy"] = { broker = { template = "{lowestProf}", feeds = { professions = { template = D } } } }
    p["Feed-Fresh"] = {}
    NS.db.global.schemaVersion = 14
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(p["Feed-Old"].broker.feeds.professions.template, "{last} Lv {level}", "the stored template moves")
    assertTrue(p["Feed-Old"].broker.template == nil, "the old key goes")
    assertEqual(p["Feed-Old"].broker.flashSeconds, 2, "the rest of broker stays")
    assertEqual(p["Feed-Kept"].broker.feeds.professions.template, "{gains}", "a choice already there wins")
    assertTrue(p["Feed-Kept"].broker.template == nil, "the old key still goes")
    assertEqual(p["Feed-Copy"].broker.feeds.professions.template, "{lowestProf}", "a stored copy of the default is no choice")
    assertTrue(p["Feed-Fresh"].broker == nil, "a fresh profile passes through")
    p["Feed-Fresh"].broker = { template = "{level}" }
    NS:RunMigrations()
    assertEqual(p["Feed-Fresh"].broker.template, "{level}", "the step ran once")
    for _, k in ipairs({ "Feed-Old", "Feed-Kept", "Feed-Copy", "Feed-Fresh" }) do p[k] = nil end
end)

test("feeds: the tooltip content is its own file, and Broker.lua stays well under the cap", function()
    local function lines(path)
        local n = 0
        for _ in io.lines(path) do n = n + 1 end
        return n
    end
    assertTrue(lines("modules/Broker.lua") < 800, "Broker.lua: the feeds, the clicks, the showing")
    assertTrue(type(B.FillTooltip) == "function" and type(B.ReleaseLines) == "function", "BrokerTooltip.lua's")
end)
