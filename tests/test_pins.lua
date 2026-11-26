-- tests/test_pins.lua — the pins per broker (GitHub issue #11; item SMW-06 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md): char.pins[family], up to five per broker; a
-- row's menu toggles its own pin and never removes another; {pinned} joins them and {pinned1}..{pinned5}
-- render one each; the tooltip lists them first; the Broker page's Pins tab orders and removes; the old
-- one-pin fields are folded in when read.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, Pins = NS.Broker, NS.Pins
local DOT = " \194\183 "

local function skill(key, name, category, rank, max)
    return { key = key, name = name, category = category, rank = rank, max = max, modifier = 0,
             tempPoints = 0, learned = true }
end

local SKILLS = {
    skinning = skill("skinning", "Skinning", "primary", 122, 150),
    mining = skill("mining", "Mining", "primary", 90, 150),
    cooking = skill("cooking", "Cooking", "secondary", 133, 150),
    fishing = skill("fishing", "Fishing", "secondary", 60, 75),
    firstaid = skill("firstaid", "First Aid", "secondary", 40, 75),
    bows = skill("bows", "Bows", "weapon", 80, 110),
}

local function publish()
    local byKey = {}
    for k, e in pairs(SKILLS) do byKey[k] = e end
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, {
        byKey = byKey,
        order = { primary = { "skinning", "mining" }, secondary = { "cooking", "fishing", "firstaid" },
                  weapon = { "bows" }, other = {} },
    })
    local crit = { key = "rangedCrit", label = "Ranged Crit", value = 9.1, display = "9.1%", pct = 30, markers = {} }
    local speed = { key = "speed", label = "Speed", value = 100, display = "100%", pct = 50, markers = {} }
    NS.bus:SendMessage(NS.MSG.STATS_UPDATED, { base = { crit, speed }, spell = {}, defense = {}, utility = {} })
end

--- `fn` on the fixture models and an empty pin store; the store and the templates put back after.
local function withPins(fn)
    M.__fireTimers()
    B.ResetSession()
    publish()
    local char = NS.db.char
    local pins, pinned, pinnedStat = char.pins, rawget(char, "pinned"), rawget(char, "pinnedStat")
    char.pins, char.pinned, char.pinnedStat = {}, nil, nil
    B.Refresh()
    local ok, err = pcall(fn)
    char.pins, char.pinned, char.pinnedStat = pins, pinned, pinnedStat
    for fid in pairs(B.FEEDS) do
        NS.SetByPath("broker.feeds." .. fid .. ".template", NS.defaults.profile.broker.feeds[fid].template)
    end
    B.ResetSession()
    B.Refresh()
    if not ok then error(err, 0) end
end

local function pinOf(row)
    for _, r in ipairs(NS.Interact.MenuRows(row)) do if r.value == "pin" then return r end end
    return nil
end

local function skillRow(key) return { kind = "skill", entry = SKILLS[key] } end

local function recordingTip()
    local lines = {}
    local tip = M.CreateFrame("GameTooltip", "SkillMasterPinsTip", M.UIParent)
    function tip:AddLine(t) lines[#lines + 1] = t end
    function tip:AddDoubleLine(l, r) lines[#lines + 1] = l .. " " .. tostring(r) end
    function tip:NumLines() return #lines end
    return tip, lines
end

local function lineIndex(lines, text)
    for i, l in ipairs(lines) do if l:find(text, 1, true) then return i end end
    return nil
end

test("pins: a row's menu ticks its own family's broker, and a second pin keeps the first", function()
    withPins(function()
        local pin = pinOf(skillRow("cooking"))
        assertEqual(pin.label, "Pin to the Professions broker")
        assertTrue(pin.radio ~= true, "a tick of its own, not a radio among the rows")
        assertFalse(pin.selected(), "not pinned yet")
        pin.onClick()
        assertTrue(pin.selected(), "ticked")
        pinOf(skillRow("skinning")).onClick()
        assertEqual(table.concat(Pins.Stored("professions"), ","), "cooking,skinning", "both, in pin order")
        assertEqual(pinOf(skillRow("bows")).label, "Pin to the Skills broker", "a weapon row pins to the Skills broker")
        assertEqual(pinOf({ kind = "stat", entry = { key = "rangedCrit", label = "Ranged Crit" } }).label,
            "Pin to the Character Stats broker")
        pinOf(skillRow("cooking")).onClick()
        assertEqual(table.concat(Pins.Stored("professions"), ","), "skinning", "unpinning one leaves the other")
    end)
end)

test("pins: {pinned} joins the feed's pins, {pinned1}..{pinned5} render one each", function()
    withPins(function()
        NS.SetByPath("broker.feeds.professions.template", "{pinned}")
        Pins.Toggle("professions", "cooking")
        Pins.Toggle("professions", "skinning")
        assertEqual(B.Text(), "Cooking 133/150" .. DOT .. "Skinning 122/150", "every pin, joined, at once")
        NS.SetByPath("broker.feeds.professions.template", "{pinned2} | {pinned1} | {pinned3}")
        assertEqual(B.Text(), "Skinning 122/150 | Cooking 133/150 | ", "one each; a missing one is empty")
        Pins.Toggle("stats", "speed")
        Pins.Toggle("stats", "rangedCrit")
        assertEqual(B.StatsText(), "Speed 100%" .. DOT .. "Ranged Crit 9.1%", "the Character Stats feed's own")
        assertEqual(B.TextFor("skills"), "Skills", "a feed with none reads its short name")
        assertEqual(NS.Template.Render("{pinned5}", { pinnedTexts = { "a", "b", "c", "d", "e" } }), "e")
        assertEqual(NS.Template.Render("{pinned6}", { pinnedTexts = { "a" } }), "", "no sixth token")
    end)
end)

test("pins: five per broker; a sixth row's pin is disabled and says why, other brokers unaffected", function()
    withPins(function()
        for _, k in ipairs({ "skinning", "mining", "cooking", "fishing", "firstaid" }) do
            assertEqual(Pins.Toggle("professions", k), true, k)
        end
        assertTrue(Pins.Full("professions"))
        assertEqual(Pins.Toggle("professions", "herbalism"), nil, "a sixth is refused")
        assertEqual(#Pins.Stored("professions"), Pins.MAX, "nothing was removed for it")
        local pin = pinOf({ kind = "skill", entry = skill("herbalism", "Herbalism", "primary", 1, 75) })
        assertTrue(pin.disabled == true, "the menu's pin is disabled")
        assertTrue(pin.tooltip ~= nil and pin.tooltip:find("5 elements", 1, true) ~= nil, tostring(pin.tooltip))
        assertFalse(pinOf(skillRow("cooking")).disabled == true, "a pinned row can still unpin")
        assertFalse(pinOf(skillRow("bows")).disabled == true, "the Skills broker has room")
    end)
end)

test("pins: the old one-pin fields fold into their families' lists when read, once", function()
    withPins(function()
        local char = NS.db.char
        char.pins, char.pinned, char.pinnedStat = {}, "bows", "rangedCrit"
        assertEqual(table.concat(Pins.Stored("skills"), ","), "bows", "a weapon skill: the Skills broker's")
        assertEqual(table.concat(Pins.Stored("stats"), ","), "rangedCrit", "the stat: Character Stats'")
        assertTrue(rawget(char, "pinned") == nil and rawget(char, "pinnedStat") == nil, "the old fields go")
        char.pinned = "cooking"
        char.pins.professions = { "cooking" }
        Pins.Normalize(char)
        assertEqual(table.concat(char.pins.professions, ","), "cooking", "never twice")
        char.pinned, char.pinnedStat = false, false
        Pins.Normalize(char)
        assertTrue(rawget(char, "pinned") == nil, "a stored false (the old default) goes too")
        char.pinned = "other:Lockpicking"
        assertEqual(Pins.FamilyOfSkill("other:Lockpicking"), "skills", "an unknown other: key is the Other block's")
        assertEqual(Pins.Stored("skills")[2], "other:Lockpicking")
        assertTrue(NS.defaults.char.pinned == nil and type(NS.defaults.char.pins) == "table", "the new default")
    end)
end)

test("pins: the Classic tooltip lists the feed's pins first, under Pinned", function()
    withPins(function()
        Pins.Toggle("professions", "fishing")
        Pins.Toggle("professions", "skinning")
        local tip, lines = recordingTip()
        local rows = B.FillTooltip(tip, "professions")
        local pinned, primary = lineIndex(lines, "Pinned"), lineIndex(lines, "Primary Professions")
        assertTrue(pinned ~= nil and primary ~= nil and pinned < primary, table.concat(lines, "\n"))
        assertTrue(lines[pinned + 1]:find("Fishing", 1, true) ~= nil, "the first pin first")
        assertTrue(lines[pinned + 2]:find("Skinning", 1, true) ~= nil, "then the second")
        assertEqual(rows[1].key, "fishing", "a pin's line is a row of its own")
        local _, none = recordingTip()
        B.FillTooltip(select(1, recordingTip()), "skills")
        assertTrue(lineIndex(none, "Pinned") == nil, "a feed with no pins has no Pinned section")
        B.SetFeed(B.DEFAULT_FEED)
    end)
end)

test("pins: the Main window style tooltip lists them first too, a Pinned header over their rows", function()
    withPins(function()
        local ldb = NS.db.profile.tooltips.ldb
        local style = ldb.style
        ldb.style = "window"
        Pins.Toggle("stats", "speed")
        B.OnEnter(M.UIParent, "stats")
        local h = NS.BrokerPanel.Headers()[1]
        local first = NS.BrokerPanel.Rows()[1]
        local title, chevron = h.title:GetText(), h.chevron:IsShown()
        B.HideTooltip()
        ldb.style = style
        B.SetFeed(B.DEFAULT_FEED)
        assertEqual(title, "Pinned", "the first header names the pins")
        assertFalse(chevron, "it folds nothing")
        assertTrue(h.id == nil, "it is no block's header")
        assertEqual(first.entry.key, "speed", "the pin's row comes first")
    end)
end)

test("pins: the Broker page's Pins tab lists each broker's pins, moves and unpins them", function()
    withPins(function()
        Pins.Toggle("professions", "cooking")
        Pins.Toggle("professions", "skinning")
        Pins.Toggle("professions", "mining")
        local redraws = 0
        local saved = NS.Pins.onChange
        NS.Pins.onChange = function() redraws = redraws + 1 end
        assertTrue(Pins.Move("professions", 3, 1), "moved")
        assertEqual(table.concat(Pins.Stored("professions"), ","), "mining,cooking,skinning")
        assertFalse(Pins.Move("professions", 1, 9), "nowhere to go")
        assertTrue(Pins.Remove("professions", "cooking"))
        NS.Pins.onChange = saved
        assertEqual(redraws, 2, "each write redraws the open page")
        local model = NS.OptionsBrokerPins.Model()
        assertEqual(#model, #NS.FAMILY_ORDER, "one list per broker")
        assertEqual(model[1].family, "professions")
        assertEqual(model[1].title, "Skill Master", "named as the display names the feed")
        local p = model[1].pins
        assertEqual(p[1].label, "Mining")
        assertTrue(p[1].first and not p[1].last and p[2].last, "the ends cannot move past themselves")
        assertEqual(#model[3].pins, 0, "Character Stats: none")
        local tab = NS.OptionsBrokerPins.tab
        assertEqual(tab.key, "Pins")
        assertEqual(type(tab.render), "function")
    end)
end)

test("pins: in test mode the feeds draw the sample's pins, and this character's store stays", function()
    withPins(function()
        Pins.Toggle("professions", "skinning")
        assertTrue(NS.ToggleTestMode() == true, "test mode on")
        local ok, err = pcall(function()
            local list = Pins.List("professions")
            assertEqual(#list, 1)
            assertEqual(list[1], "fishing", "the sample's pin (Preview_Forever: Fishing)")
            assertEqual(Pins.Stored("professions")[1], "skinning", "the live list is untouched")
            assertTrue(B.Text():find("^Fishing") ~= nil, B.Text())
        end)
        NS.ToggleTestMode()
        if not ok then error(err, 0) end
        assertEqual(Pins.List("professions")[1], "skinning", "back to the live pins")
    end)
end)
