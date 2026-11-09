-- tests/test_seams.lua — the seams between the M3 display and the M4 surfaces, wired at integration:
-- the broker's crafting and unlearned rows, the alert toast's waypoint, the shared mini bar in the
-- broker tooltip and the Journal, and the main window's Journal button.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local W, Blk, Br = NS.MainWindow, NS.Blocks, NS.Broker

local function skill(key, name, category, rank, max, modifier, learned)
    return { key = key, name = name, category = category, kind = NS.SkillCatalog[key] and NS.SkillCatalog[key].kind,
             rank = rank, max = max, tempPoints = 0, modifier = modifier or 0, learned = learned ~= false }
end

-- One row per category; the crafting suite moves the primary block (Leatherworking) last and shuts it.
local function fixture()
    local byKey = {
        leatherworking = skill("leatherworking", "Leatherworking", "primary", 146, 150),
        cooking        = skill("cooking", "Cooking", "secondary", 133, 150),
        guns           = skill("guns", "Guns", "weapon", 105, 110, 5),
        swords         = skill("swords", "Swords", "weapon", 0, 0, 0, false),
        defense        = skill("defense", "Defense", "other", 100, 110),
    }
    return { byKey = byKey, order = { primary = { "leatherworking" }, secondary = { "cooking" },
                                      weapon = { "guns", "swords" }, other = { "defense" } } },
           { base = {}, spell = {}, defense = {}, utility = {} }
end

local function withWorld(fn)
    local skills, stats = fixture()
    local savedSource = Blk.source
    local blocks = NS.db.profile.layout.blocks
    local savedPrimary = { order = blocks.primary.order, collapsed = blocks.primary.collapsed }
    Blk.source = function() return skills, stats end
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, skills)   -- the broker keeps the model it is sent
    local ok, err = pcall(fn, skills, blocks)
    Blk.source = savedSource
    blocks.primary.order, blocks.primary.collapsed = savedPrimary.order, savedPrimary.collapsed
    W.Hide()
    NS.TrainerPopup.Hide()
    if NS.Journal.IsShown() then NS.Journal.Hide() end
    M.__fireTimers()
    if not ok then error(err, 0) end
end

test("test_seam_broker_crafting_row_scrolls_window: a broker crafting row expands, shows and scrolls to it", function()
    -- red under: the broker calling W:ShowAndScrollTo (the key lands as the window table), or a
    -- collapsed block left shut, or the window shown unscrolled.
    withWorld(function(_, blocks)
        blocks.primary.order, blocks.primary.collapsed = 99, true   -- last in the window, and shut
        Blk.Changed()
        W.Hide()
        local scrolled
        local realShow = W.Show
        W.Show = function()
            local r = realShow()
            local scroll = W.Frame().scroll
            local realSet = scroll.SetVerticalScroll
            scroll.SetVerticalScroll = function(self, v) scrolled = v return realSet(self, v) end
            W.Show = realShow
            return r
        end
        Br.OpenRow({ kind = "skill", key = "leatherworking" })
        W.Show = realShow
        assertTrue(W.IsShown(), "the main window opened")
        assertEqual(blocks.primary.collapsed, false, "the collapsed block holding the row is expanded")
        local row
        for _, r in ipairs(W.Rows()) do if r.entry.key == "leatherworking" then row = r end end
        assertTrue(row ~= nil, "the crafting row is laid out")
        assertTrue(row.layY > Blk.HEADER_H, "the row sits under the other blocks: " .. tostring(row.layY))
        assertEqual(scrolled, row.layY - Blk.HEADER_H, "scrolled to the row, its header kept in view")
        assertTrue(W.ShowAndScrollTo("leatherworking"), "already shown: it answers true")
        assertEqual(W.ShowAndScrollTo("nope"), false, "an unknown key still shows the window, scrolls nowhere")
        assertTrue(W.IsShown())
    end)
end)

test("test_seam_broker_unlearned_row_opens_trainer_popup: the popup gets the skill key, not a table", function()
    withWorld(function()
        Br.OpenRow({ kind = "skill", key = "swords" })
        assertTrue(NS.TrainerPopup.IsShown(), "the trainer popup opened")
        local title = NS.TrainerPopup.Frame().title:GetText()
        assertTrue(title:find("Swords", 1, true) ~= nil, title)
        assertTrue(#NS.TrainerPopup.Trainers() > 0, "the faction's sword trainers are listed")
    end)
end)

test("test_seam_alert_click_sets_waypoint: a cap toast's click goes through the real NS.Waypoints", function()
    local savedTomTom = M.TomTom
    local added = {}
    M.TomTom = { AddWaypoint = function(_, ...) added[#added + 1] = { ... } return {} end }
    local trainer = NS.Trainers:For("fistWeapons", "Alliance", "Dwarf")[1]
    M.__resetPrinted()
    NS.Alerts.OnToastClick({ kind = "cap", key = "fistWeapons", name = "Fist Weapons", trainer = trainer })
    M.TomTom = savedTomTom
    assertEqual(#added, 1, "TomTom got the trainer's waypoint")
    assertEqual(added[1][1], trainer.mapID)
    assertTrue(M.__printed()[1]:find(trainer.name, 1, true) ~= nil, "and the confirmation names the trainer")
    -- A profession trainer has no coordinates: the same click prints the directions, never a pin.
    local nr = NS.Trainers:NextRank("leatherworking", 150, 150, 30, "Alliance", "Dwarf")
    M.__resetPrinted()
    NS.Alerts.OnToastClick({ kind = "cap", key = "leatherworking", name = "Leatherworking", trainer = nr.trainers[1] })
    assertEqual(#M.__printed(), 1, "one directions line")
end)

test("test_seam_mini_bars_are_the_bar_widget: the broker tooltip draws NS.Bar's mini style (the Journal's: test_journal)", function()
    withWorld(function()
        local tip = M.CreateFrame("GameTooltip", "SkillMasterSeamTip", M.UIParent)
        tip.lines = {}
        function tip:GetName() return "SkillMasterSeamTip" end
        function tip:NumLines() return #self.lines end
        function tip:ClearLines() self.lines = {} end
        local function add(...)
            tip.lines[#tip.lines + 1] = { ... }
            local name = "SkillMasterSeamTipTextLeft" .. #tip.lines
            _G[name] = _G[name] or M.CreateFrame("Frame", name, tip)
        end
        tip.AddLine, tip.AddDoubleLine = function(_, ...) add(...) end, function(_, ...) add(...) end
        Br.FillTooltip("weapons", tip)
        local bars = Br.Bars()
        assertTrue(#bars >= 2, "a bar per learned weapon row and Defense, drew " .. #bars)
        local guns
        for _, b in ipairs(bars) do
            assertEqual(b.style.key, "mini", "the mini style")
            if b.values and b.values.value == 105 then guns = b end
        end
        assertTrue(guns ~= nil, "the Guns bar carries its values")
        assertEqual(guns.values.bonus, 5, "with its +5 bonus segment")
        assertTrue(guns.geom.bonus > 0 and guns.geom.fill + guns.geom.bonus <= 1, "clamped to the end")
    end)
end)

test("test_seam_title_bar_journal_button: the main window's journal mark toggles the Journal", function()
    withWorld(function()
        W.Show()
        local button = W.Frame().journalButton
        assertTrue(button ~= nil, "the title bar carries the journal mark")
        button:GetScript("OnClick")(button, "LeftButton")
        assertTrue(NS.Journal.IsShown(), "one click opens the Journal")
        button:GetScript("OnClick")(button, "LeftButton")
        assertTrue(not NS.Journal.IsShown(), "a second closes it")
    end)
end)
