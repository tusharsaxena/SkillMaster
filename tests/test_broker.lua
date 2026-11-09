-- tests/test_broker.lua — the four broker data feeds (plan Task 4.1, design §6.7, §6.5): their
-- objects, the template text, the skill-up flash, the tooltip rows and bars, and the clicks.
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

local function joined(tip)
    local out = {}
    for _, l in ipairs(tip.lines) do out[#out + 1] = table.concat(l, " | ") end
    return table.concat(out, "\n")
end

test("broker: four data sources, separate from the launcher object", function()
    reset()
    for _, name in ipairs({ "SkillMaster_All", "SkillMaster_Professions", "SkillMaster_Weapons", "SkillMaster_Stats" }) do
        local obj = M.__ldbObjects[name]
        assertTrue(obj ~= nil, name .. " registered")
        assertEqual(obj.type, "data source", name)
        assertTrue(type(obj.OnClick) == "function" and type(obj.OnEnter) == "function"
            and type(obj.OnLeave) == "function", name .. " handlers")
    end
    assertEqual(NS.Launcher:Object().type, "launcher", "the launcher stays the one launcher object")
end)

test("broker: each feed renders its default template", function()
    reset()
    B.Refresh()
    assertEqual(B.Text("all"), "Skinning 122/150 · +0", "no pin and no skill-up yet: the lowest profession")
    assertEqual(B.Text("professions"), "Skinning 122/150")
    assertEqual(B.Text("stats"), "9.1% crit · 100%")
    assertTrue(B.Text("weapons") ~= "", "the weapons feed is never blank")
end)

test("broker: the weapons feed follows the main hand's weapon class", function()
    reset()
    local saved = { M.GetInventoryItemLink, M.GetItemInfoInstant }
    M.GetInventoryItemLink = function(_, slot) if slot == 16 then return "|Hitem:2508|h[Old Blunderbuss]|h" end end
    M.GetItemInfoInstant = function() return 2508, "Weapon", "Guns", "INVTYPE_RANGEDRIGHT", 0, 2, 3 end
    B.Refresh()
    M.GetInventoryItemLink, M.GetItemInfoInstant = saved[1], saved[2]
    assertEqual(B.Text("weapons"), "Guns 105+5/110")
end)

test("test_broker_flash_reverts: a skill-up flashes its feeds, then the template comes back", function()
    reset()
    B.Refresh()
    local before = B.Text("professions")
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "bows", 80, 81)
    publish(81)
    assertTrue(B.Text("all"):find("Bows 81", 1, true) ~= nil, "the All feed flashes: " .. B.Text("all"))
    assertTrue(B.Text("weapons"):find("Bows 81", 1, true) ~= nil, "the Weapons feed flashes")
    assertEqual(B.Text("professions"), before, "a weapon skill-up leaves the Professions feed alone")
    assertEqual(B.FlashSeconds(), 5, "profile.broker.flashSeconds defaults to 5")
    M.__now = M.__now + 5
    M.__fireTimers()
    assertEqual(B.Text("all"), "Bows 81/110 · +1", "reverted: the last skill-up is the pin, one gain")
end)

test("broker: the All tooltip lists every category with mini bars, bonuses and gains", function()
    reset()
    NS.bus:SendMessage(NS.MSG.SKILL_UP, "bows", 80, 81)
    publish(81)
    local tip = recordingTip()
    local rows = B.FillTooltip("all", tip)
    local text = joined(tip)
    for _, want in ipairs({ "Skill Master: All skills", "+1 this session", "PRIMARY", "SECONDARY",
                            "WEAPON", "OTHER", "Skinning", "Guns", "Defense" }) do
        assertTrue(text:find(want, 1, true) ~= nil, "tooltip has " .. want .. "\n" .. text)
    end
    assertTrue(text:find("+5", 1, true) ~= nil, "Guns shows its +5 bonus")
    assertTrue(B.BarsDrawn() >= 5, "a mini bar per learned row, drew " .. B.BarsDrawn())
    local keys = {}
    for _, r in ipairs(rows) do keys[r.key] = r end
    assertTrue(keys.bows and keys.skinning and keys.swords, "clickable rows carry their keys")
    M.__fireTimers()
end)

test("broker: the Weapons tooltip is the weapon skills plus Defense; Stats is the four groups", function()
    reset()
    local tip = recordingTip()
    B.FillTooltip("weapons", tip)
    local text = joined(tip)
    assertTrue(text:find("Defense", 1, true) ~= nil and text:find("Guns", 1, true) ~= nil, text)
    assertFalse(text:find("Skinning", 1, true) ~= nil, "no professions in the Weapons tooltip")
    tip = recordingTip()
    B.FillTooltip("stats", tip)
    text = joined(tip)
    assertTrue(text:find("Ranged Crit", 1, true) ~= nil and text:find("Speed", 1, true) ~= nil, text)
end)

test("broker: clicks follow design §6.5 and never touch a secure frame", function()
    reset()
    local W = NS.MainWindow
    local calls = {}
    local saved = { W.Toggle, W.ShowAndScrollTo, M.ToggleCharacter }
    W.Toggle = function() calls[#calls + 1] = "toggle" end
    W.ShowAndScrollTo = function(self, key) calls[#calls + 1] = (self == W and "scroll:" or "BAD:") .. key end
    M.ToggleCharacter = function(tab) calls[#calls + 1] = "char:" .. tab end
    M.__ldbObjects.SkillMaster_All.OnClick(nil, "LeftButton")
    B.OpenRow({ kind = "skill", key = "cooking" })
    B.OpenRow({ kind = "skill", key = "bows" })
    B.OpenRow({ kind = "stat", key = "speed" })
    W.Toggle, W.ShowAndScrollTo, M.ToggleCharacter = saved[1], saved[2], saved[3]
    assertEqual(table.concat(calls, ","), "toggle,scroll:cooking,char:SkillFrame,char:PaperDollFrame")
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

test("broker: stood down, every feed reads Off and its tooltip says so; standing up re-renders", function()
    reset()
    B.Refresh()
    -- The latch's predicate, held down (test_disabled drives the real cycle; this reads the feeds).
    local real = NS.IsStoodDown
    NS.IsStoodDown = function() return true end
    B.Refresh()
    local off = { B.Text("all"), B.Text("stats") }
    local tip = recordingTip()
    local rows = B.FillTooltip("all", tip)
    NS.IsStoodDown = real
    B.Refresh()
    assertEqual(table.concat(off, ","), "Off,Off")
    assertEqual(#rows, 0, "no clickable rows while disabled")
    assertTrue(joined(tip):find("disabled", 1, true) ~= nil, joined(tip))
    assertEqual(B.Text("stats"), "9.1% crit · 100%")
end)
