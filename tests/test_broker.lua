-- tests/test_broker.lua — the one broker data feed (plan Task 4.1, design §6.7, §6.5; feedback round
-- 2, FB-12 and FB-13): its object, the template text, the skill-up flash, the tooltip's sections,
-- rows, bars and own Hide sets, the clicks, the tooltip's skin and the schemaVersion 3 step.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function skill(key, name, category, rank, max, modifier, learned)
    return { key = key, name = name, category = category, rank = rank, max = max,
             modifier = modifier or 0, tempPoints = 0, learned = learned ~= false }
end

local function fixtureModel(bows)
    return {
        byKey = {
            skinning = skill("skinning", "Skinning", "primary", 122, 150),
            cooking  = skill("cooking", "Cooking", "secondary", 133, 150),
            guns     = skill("guns", "Guns", "weapon", 105, 110, 5),
            bows     = skill("bows", "Bows", "weapon", bows or 80, 110),
            swords   = skill("swords", "Swords", "weapon", 0, 0, 0, false),
            defense  = skill("defense", "Defense", "other", 100, 110),
        },
        order = { primary = { "skinning" }, secondary = { "cooking" },
                  weapon = { "guns", "bows", "swords" }, other = { "defense" } },
    }
end

local function statsModel()
    return {
        base = { { key = "rangedCrit", label = "Ranged Crit", value = 9.1, display = "9.1%", pct = 30, markers = {} } },
        spell = {}, defense = {},
        utility = { { key = "speed", label = "Speed", value = 100, display = "100%", pct = 50, markers = {} } },
    }
end

local B = NS.Broker

local function publish(bows)
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, fixtureModel(bows))
    NS.bus:SendMessage(NS.MSG.STATS_UPDATED, statsModel())
end

local function reset()
    M.__fireTimers()
    B.ResetSession()
    publish()
end

--- A recording stand-in for GameTooltip: its lines, and a TextLeftN region per line.
local function recordingTip()
    local tip = M.CreateFrame("GameTooltip", "SkillMasterTestTip", M.UIParent)
    tip.lines = {}
    function tip:GetName() return "SkillMasterTestTip" end
    function tip:NumLines() return #self.lines end
    function tip:ClearLines() self.lines = {} end
    local function region(n)
        local name = "SkillMasterTestTipTextLeft" .. n
        _G[name] = _G[name] or M.CreateFrame("Frame", name, tip)   -- the addon reads the real _G, as in the client
    end
    function tip:AddLine(text) self.lines[#self.lines + 1] = { text } region(#self.lines) end
    function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end
    return tip
end

--- Dress a frame the addon made (the feed's own tooltip) as a recording tooltip under its own
--- global name: its lines, and TextLeftN / TextRightN font strings the skin can paint.
local function dressed(tip, name)
    tip.lines = {}
    rawset(tip, "GetName", function() return name end)
    rawset(tip, "NumLines", function(self) return #self.lines end)
    rawset(tip, "ClearLines", function(self) self.lines = {} end)
    rawset(tip, "SetOwner", function(self, o) self.lines, self.__owner = {}, o end)
    rawset(tip, "GetOwner", function(self) return self.__owner end)
    local function region(n)
        for _, side in ipairs({ "Left", "Right" }) do
            local key = name .. "Text" .. side .. n
            _G[key] = _G[key] or tip:CreateFontString()
        end
    end
    rawset(tip, "AddLine", function(self, text) self.lines[#self.lines + 1] = { text } region(#self.lines) end)
    rawset(tip, "AddDoubleLine", function(self, l, r) self.lines[#self.lines + 1] = { l, r } region(#self.lines) end)
    return tip
end

local function skinLib() return M.LibStub("LibKa0s-Skin-1.0") end

--- Run `fn` with the tooltip's sections, Hide sets and skin as `fn` leaves them, then put the
--- shipped defaults back.
local function withTooltip(fn)
    local ok, err = pcall(fn)
    local tip, D = NS.db.profile.broker.tooltip, NS.defaults.profile.broker.tooltip
    for id, v in pairs(D.sections) do tip.sections[id] = v end
    tip.hiddenSkills, tip.hiddenStats, tip.skin = {}, {}, D.skin
    NS.db.profile.skills.hidden, NS.db.profile.stats.hidden = {}, {}
    B.HideTooltip()
    if not ok then error(err, 0) end
end

local function joined(tip)
    local out = {}
    for _, l in ipairs(tip.lines) do out[#out + 1] = table.concat(l, " | ") end
    return table.concat(out, "\n")
end


test("broker: one data source, \"Skill Master\", separate from the launcher object", function()
    reset()
    local obj = M.__ldbObjects["Skill Master"]
    assertTrue(obj ~= nil, "the feed is registered")
    assertEqual(obj.type, "data source")
    assertEqual(obj.label, "Skill Master")
    assertTrue(type(obj.OnClick) == "function" and type(obj.OnEnter) == "function"
        and type(obj.OnLeave) == "function", "its handlers")
    assertTrue(B.Object() == obj, "B.Object is it")
    local sources = 0
    for _, o in pairs(M.__ldbObjects) do if o.type == "data source" then sources = sources + 1 end end
    assertEqual(sources, 1, "exactly one data source")
    for _, gone in ipairs({ "SkillMaster_All", "SkillMaster_Professions", "SkillMaster_Weapons", "SkillMaster_Stats" }) do
        assertTrue(M.__ldbObjects[gone] == nil, gone .. " is gone")
    end
    assertEqual(NS.Launcher:Object().type, "launcher", "the launcher stays the one launcher object")
end)

test("broker: the feed renders its template", function()
    reset()
    B.Refresh()
    assertEqual(B.Text(), "Professions and Skills", "nothing pinned (the default): the feed's plain title")
    NS.db.char.pinned = "skinning"
    B.Refresh()
    assertEqual(B.Text(), "Skinning 122/150 · +0", "a pinned skill and the session's gains")
    NS.db.char.pinned = false
    B.Refresh()
    NS.SetByPath("broker.template", "{stat:crit} crit · {stat:speed}")
    assertEqual(B.Text(), "9.1% crit · 100%", "a stat token on the same feed")
    NS.SetByPath("broker.template", NS.defaults.profile.broker.template)
end)

test("broker: {equippedWeapon} follows the main hand's weapon class", function()
    reset()
    local saved = { M.GetInventoryItemLink, M.GetItemInfoInstant }
    M.GetInventoryItemLink = function(_, slot) if slot == 16 then return "|Hitem:2508|h[Old Blunderbuss]|h" end end
    M.GetItemInfoInstant = function() return 2508, "Weapon", "Guns", "INVTYPE_RANGEDRIGHT", 0, 2, 3 end
    NS.SetByPath("broker.template", "{equippedWeapon}")
    M.GetInventoryItemLink, M.GetItemInfoInstant = saved[1], saved[2]
    assertEqual(B.Text(), "Guns 105+5/110")
    NS.SetByPath("broker.template", NS.defaults.profile.broker.template)
end)

test("test_broker_flash_reverts: any skill-up flashes the feed, then the template comes back", function()
    reset()
    B.Refresh()
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "bows", 80, 81)
    publish(81)
    assertTrue(B.Text():find("Bows 81", 1, true) ~= nil, "a weapon skill-up flashes: " .. B.Text())
    assertEqual(B.FlashSeconds(), 5, "profile.broker.flashSeconds defaults to 5")
    M.__now = M.__now + 5
    M.__fireTimers()
    assertEqual(B.Text(), "Professions and Skills", "reverted: nothing pinned, the plain title")
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "cooking", 133, 134)
    assertTrue(B.Text():find("Cooking 134", 1, true) ~= nil, "and so does a profession's: " .. B.Text())
    M.__now = M.__now + 5
    M.__fireTimers()
end)

test("broker: the tooltip's skill sections are on and Stats is off by default", function()
    reset()
    for _, id in ipairs({ "primary", "secondary", "weapon", "other" }) do
        assertEqual(NS.defaults.profile.broker.tooltip.sections[id], true, id .. " on by default")
        assertTrue(B.SectionShown(id), id)
    end
    assertEqual(NS.defaults.profile.broker.tooltip.sections.stats, false, "Stats off by default")
    assertFalse(B.SectionShown("stats"))
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "bows", 80, 81)
    publish(81)
    local tip = recordingTip()
    local rows = B.FillTooltip(tip)
    local text = joined(tip)
    for _, want in ipairs({ "Skill Master", "+1 this session", "Primary Professions", "Secondary Skills",
                            "Weapon Skills", "Other skills", "Skinning", "Guns", "Defense" }) do
        assertTrue(text:find(want, 1, true) ~= nil, "tooltip has " .. want .. "\n" .. text)
    end
    assertFalse(text:find("Ranged Crit", 1, true) ~= nil, "no stats by default\n" .. text)
    assertTrue(text:find("+5", 1, true) ~= nil, "Guns shows its +5 bonus")
    assertTrue(B.BarsDrawn() >= 5, "a mini bar per learned row, drew " .. B.BarsDrawn())
    local keys = {}
    for _, r in ipairs(rows) do keys[r.key] = r end
    assertTrue(keys.bows and keys.skinning and keys.swords, "clickable rows carry their keys")
    M.__fireTimers()
end)

test("broker: each section has its own switch", function()
    withTooltip(function()
        reset()
        NS.SetByPath("broker.tooltip.sections.weapon", false)
        NS.SetByPath("broker.tooltip.sections.stats", true)
        local tip = recordingTip()
        local rows = B.FillTooltip(tip)
        local text = joined(tip)
        assertFalse(text:find("Guns", 1, true) ~= nil, "Weapon off: no weapon skills\n" .. text)
        assertTrue(text:find("Skinning", 1, true) ~= nil and text:find("Defense", 1, true) ~= nil, text)
        assertTrue(text:find("Ranged Crit", 1, true) ~= nil and text:find("Speed", 1, true) ~= nil,
            "Stats on: the stats\n" .. text)
        local stat = false
        for _, r in ipairs(rows) do stat = stat or (r.kind == "stat" and r.key == "speed") end
        assertTrue(stat, "a stat row is clickable")
        for _, id in ipairs(B.SECTIONS) do NS.SetByPath("broker.tooltip.sections." .. id, false) end
        tip = recordingTip()
        assertEqual(#B.FillTooltip(tip), 0, "every section off: no rows")
    end)
end)

test("broker: a tooltip Hide leaves the main window alone, and the window's Hide leaves the tooltip", function()
    withTooltip(function()
        reset()
        NS.SetByPath("broker.tooltip.sections.stats", true)
        assertTrue(NS.SetByPath("broker.tooltip.hiddenSkills.bows", true))
        assertTrue(NS.SetByPath("broker.tooltip.hiddenStats.speed", true))
        assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.bows == true, "stored in the tooltip's set")
        assertTrue(next(NS.db.profile.skills.hidden) == nil, "the window's skills.hidden is untouched")
        assertTrue(next(NS.db.profile.stats.hidden) == nil, "the window's stats.hidden is untouched")
        NS.db.profile.skills.hidden.guns = true   -- hidden from the window only
        local tip = recordingTip()
        B.FillTooltip(tip)
        local text = joined(tip)
        assertFalse(text:find("Bows", 1, true) ~= nil, "the tooltip leaves Bows out\n" .. text)
        assertFalse(text:find("Speed", 1, true) ~= nil, "and Speed\n" .. text)
        assertTrue(text:find("Guns", 1, true) ~= nil, "a window-hidden skill still shows in the tooltip")
        assertTrue(text:find("Ranged Crit", 1, true) ~= nil, text)
        assertTrue(NS.SetByPath("broker.tooltip.hiddenSkills.bows", false))
        assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.bows == nil, "false clears the entry")
    end)
end)

test("broker: the Broker page has a Hide row per catalog skill and per stat, apart from the window's", function()
    local paths = {}
    for _, row in ipairs(NS.SchemaForPage("broker")) do paths[row.path] = row end
    for key in pairs(NS.SkillCatalog) do
        assertTrue(paths["broker.tooltip.hiddenSkills." .. key] ~= nil, "a row for " .. key)
    end
    for _, def in ipairs(NS.STAT_DEFS) do
        assertTrue(paths["broker.tooltip.hiddenStats." .. def.key] ~= nil, "a row for " .. def.key)
    end
    for _, id in ipairs(B.SECTIONS) do
        assertTrue(paths["broker.tooltip.sections." .. id] ~= nil, "a switch for " .. id)
    end
    local tips = {}
    for _, row in ipairs(NS.SchemaForPage("tooltips")) do tips[row.path] = row end
    assertTrue(tips["broker.tooltip.skin"] ~= nil, "the skin switch, on the Tooltips page (round 4)")
    assertTrue(paths["broker.tooltip.skin"] == nil, "and no longer on the Broker page")
    assertTrue(paths["broker.template"] ~= nil and paths["broker.preset"] ~= nil, "the one template")
    for path in pairs(paths) do
        assertFalse(path:find("^broker%.templates") ~= nil, "no old feed template row: " .. path)
    end
end)

test("broker: clicks follow design §6.5 and never touch a secure frame", function()
    reset()
    local W = NS.MainWindow
    local calls = {}
    local saved = { W.Toggle, W.ShowAndScrollTo, M.ToggleCharacter }
    W.Toggle = function() calls[#calls + 1] = "toggle" end
    W.ShowAndScrollTo = function(key) calls[#calls + 1] = (type(key) == "string" and "scroll:" .. key or "BAD") end
    M.ToggleCharacter = function(tab) calls[#calls + 1] = "char:" .. tab end
    M.__ldbObjects["Skill Master"].OnClick(nil, "LeftButton")
    B.OpenRow({ kind = "skill", key = "cooking" })
    B.OpenRow({ kind = "skill", key = "bows" })
    B.OpenRow({ kind = "stat", key = "speed" })
    W.Toggle, W.ShowAndScrollTo, M.ToggleCharacter = saved[1], saved[2], saved[3]
    assertEqual(table.concat(calls, ","), "toggle,scroll:cooking,char:SkillsFrame,char:PaperDollFrame")
end)

test("broker: a crafting row without ShowAndScrollTo still opens the main window", function()
    reset()
    local W = NS.MainWindow
    local saved, shown = W.ShowAndScrollTo, 0
    local realShow = W.Show
    W.ShowAndScrollTo = nil
    W.Show = function() shown = shown + 1 end
    B.OpenRow({ kind = "skill", key = "cooking" })
    W.Show, W.ShowAndScrollTo = realShow, saved
    assertEqual(shown, 1)
end)

test("broker: a hovered tooltip row wears the window's hover wash, under its text, until the pointer leaves", function()
    withTooltip(function()
        reset()
        local tip = dressed(B.Tip(), B.TIP_NAME)
        B.OnEnter(M.UIParent)
        local hits = B.Hits()
        assertTrue(#hits > 0, "the rows are clickable")
        assertTrue(B.HoverWash(tip) == nil or not B.HoverWash(tip):IsShown(), "nothing washed before a hover")
        local hit = hits[1]
        hit:__fire("OnEnter")
        local wash = B.HoverWash(tip)
        assertTrue(wash ~= nil and wash:IsShown(), "the hovered row is washed")
        assertTrue(wash:GetParent() == tip, "on the tooltip itself, so the text stays above it")
        assertEqual(select(1, wash:GetDrawLayer()), "BORDER", "in the stripes' layer, over them")
        hit:__fire("OnLeave")
        assertFalse(wash:IsShown(), "the wash goes when the pointer leaves the row")
        hits[#hits]:__fire("OnEnter")
        assertTrue(wash:IsShown(), "another row's hover reuses it")
        B.HideTooltip()
        assertFalse(wash:IsShown(), "and it goes with the tooltip")
    end)
end)

test("broker: stood down, the feed reads Off and its tooltip says so; standing up re-renders", function()
    reset()
    B.Refresh()
    -- The latch's predicate, held down (test_disabled drives the real cycle; this reads the feed).
    local real = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    B.Refresh()
    local off = B.Text()
    local tip = recordingTip()
    local rows = B.FillTooltip(tip)
    NS.IsStoodDown = real
    B.Refresh()
    assertEqual(off, "Off")
    assertEqual(#rows, 0, "no clickable rows while disabled")
    assertTrue(joined(tip):find("disabled", 1, true) ~= nil, joined(tip))
    assertEqual(B.Text(), "Professions and Skills")
end)

-- ── FB-13: the tooltip's skin ────────────────────────────────────────────────────────────────

test("broker: the tooltip wears the skin by default, on its own frame, never on GameTooltip", function()
    withTooltip(function()
        reset()
        assertEqual(NS.defaults.profile.broker.tooltip.skin, true, "on by default")
        assertTrue(B.Skinned())
        local tip = B.Tip()
        assertTrue(tip ~= M.GameTooltip, "the feed's own frame")
        assertTrue(B.OwnTip() == tip)
        dressed(tip, B.TIP_NAME)
        B.OnEnter(M.UIParent)
        local rec = skinLib().painted[tip]
        assertTrue(rec ~= nil and rec.calls.Shell ~= nil, "the frame wears the skin's shell")
        local title = _G[B.TIP_NAME .. "TextLeft1"]
        local tr = skinLib().painted[title]
        assertTrue(tr ~= nil and tr.calls.Text ~= nil and tr.calls.Text[1] == "title", "the title line's font")
        local body = skinLib().painted[_G[B.TIP_NAME .. "TextLeft2"]]
        assertTrue(body ~= nil and body.calls.Text[1] == "body", "a body line's font")
        assertTrue(B.Bars()[1] ~= nil, "the mini bars draw on it")
        assertTrue(skinLib().painted[M.GameTooltip] == nil, "GameTooltip is never painted")
        assertFalse(M.GameTooltip:IsShown(), "and never shown for the feed")
        B.OnLeave()
        M.__now = M.__now + 1
        M.__fireTimers()
    end)
end)

test("broker: Apply skin off draws the plain GameTooltip, and takes the skinned one down", function()
    withTooltip(function()
        reset()
        local own = dressed(B.Tip(), B.TIP_NAME)
        B.OnEnter(M.UIParent)
        assertTrue(own:IsShown(), "the skinned tooltip is up")
        assertTrue(NS.SetByPath("broker.tooltip.skin", false))
        assertFalse(own:IsShown(), "the switch takes it down")
        assertFalse(B.Skinned())
        assertTrue(B.Tip() == M.GameTooltip, "off: the shared GameTooltip")
        B.OnEnter(M.UIParent)
        assertTrue(M.GameTooltip:IsShown(), "drawn on GameTooltip")
        assertFalse(own:IsShown(), "the own frame stays down")
        assertTrue(skinLib().painted[M.GameTooltip] == nil, "plain: GameTooltip is not painted")
        B.HideTooltip()
        assertFalse(M.GameTooltip:IsShown())
    end)
end)

test("broker: GameTooltip keeps its state, and its hide never takes the skinned tooltip's bars", function()
    withTooltip(function()
        reset()
        -- A plain show first: the feed hooks GameTooltip's OnHide.
        NS.SetByPath("broker.tooltip.skin", false)
        B.OnEnter(M.UIParent)
        B.HideTooltip()
        local scripts = {}
        for k, v in pairs(M.GameTooltip.__scripts) do scripts[k] = v end
        NS.SetByPath("broker.tooltip.skin", true)
        dressed(B.Tip(), B.TIP_NAME)
        B.OnEnter(M.UIParent)
        local bars = #B.Bars()
        assertTrue(bars > 0, "the skinned tooltip drew bars")
        -- Another frame's tooltip goes away (the row tooltip's hide).
        M.GameTooltip:Show()
        M.GameTooltip:Hide()
        M.GameTooltip:__fire("OnHide")
        assertEqual(#B.Bars(), bars, "the skinned tooltip keeps its bars")
        for k, v in pairs(M.GameTooltip.__scripts) do
            assertTrue(scripts[k] == v, "GameTooltip's " .. k .. " handler is as it was")
        end
        assertTrue(skinLib().painted[M.GameTooltip] == nil, "and it was never painted")
        B.HideTooltip()
        assertEqual(#B.Bars(), 0, "the feed's own hide releases them")
    end)
end)

-- ── schemaVersion 3: one feed ────────────────────────────────────────────────────────────────

test("broker: schemaVersion 3 carries the All template and drops the other feeds' keys", function()
    local sv = rawget(_G, "SkillMasterDB")
    assertTrue(type(sv) == "table", "the SavedVariables table")
    sv.profiles = sv.profiles or {}
    local D = NS.defaults.profile.broker.template
    sv.profiles["OneFeed-Custom"] = { broker = { flashSeconds = 3, templates = {
        all = "{last} Lv {level}", professions = "{lowestProf}", stats = "{stat:armor}" } } }
    sv.profiles["OneFeed-Others"] = { broker = { templates = { weapons = "{equippedWeapon} !" } } }
    sv.profiles["OneFeed-Kept"] = { broker = { template = "{pinned} kept", templates = { all = "{level}" } } }
    sv.profiles["OneFeed-Fresh"] = {}
    NS.db.global.schemaVersion = 2
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION, "the runner reaches the newest step")
    local p = sv.profiles
    assertEqual(p["OneFeed-Custom"].broker.template, "{last} Lv {level}", "the All template carries")
    assertTrue(p["OneFeed-Custom"].broker.templates == nil, "the old table goes")
    assertEqual(p["OneFeed-Custom"].broker.flashSeconds, 3, "the rest of broker is kept")
    assertTrue(p["OneFeed-Others"].broker.template == nil, "no All template: the default stands")
    assertTrue(p["OneFeed-Others"].broker.templates == nil, "a dead feed's template goes")
    assertEqual(p["OneFeed-Kept"].broker.template, "{pinned} kept", "a stored template wins")
    assertTrue(next(p["OneFeed-Fresh"]) == nil, "a fresh profile passes through")
    -- Once: the stamp is past the step.
    p["OneFeed-Others"].broker.templates = { all = "{level}" }
    NS:RunMigrations()
    assertTrue(p["OneFeed-Others"].broker.template == nil, "the step ran once")
    for _, k in ipairs({ "OneFeed-Custom", "OneFeed-Others", "OneFeed-Kept", "OneFeed-Fresh" }) do p[k] = nil end
    assertEqual(D, NS.defaults.profile.broker.template)
end)

test("broker: schemaVersion 3 moves the active profile's All template past the copied default", function()
    local b = NS.db.profile.broker
    b.templates = { all = "{level} active" }
    NS.db.global.schemaVersion = 2
    NS:RunMigrations()
    assertEqual(b.template, "{level} active", "the active profile's choice moved")
    assertTrue(b.templates == nil, "the old key goes")
    NS.SetByPath("broker.template", NS.defaults.profile.broker.template)
end)
