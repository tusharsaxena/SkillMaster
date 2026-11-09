-- tests/test_journal.lua — the Journal window (design §6.4): its standalone-window chrome, the two
-- tabs, the session log list and side cards, the alts grid with its mini bars, and `/skm journal`.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local J, SL = NS.Journal, NS.SessionLog

local function forgetAll()
    for key in pairs(NS.db.global.characters) do NS.db.global.characters[key] = nil end
end

local function activeRows(p)
    local out = {}
    for _, row in ipairs(p.pool.active) do out[#out + 1] = row end
    return out
end

test("journal: /skm journal toggles it, through the one toggle handler", function()
    J.Hide()
    NS.Slash:OnSlash("journal")
    assertTrue(J.IsShown(), "shown")
    NS.Slash:OnSlash("journal")
    assertFalse(J.IsShown(), "hidden again")
end)

test("journal: the chrome is the shared one: the title, the wrapped close control, the window tier", function()
    J.Show()
    local f = J.Frame()
    assertEqual(f.title:GetText(), "Skill Master \194\183 Journal")
    assertTrue(f.close ~= nil, "the close control was built through NS.MakeCloseButton")
    assertEqual(f:GetFrameStrata(), NS.Constants.LAYERS.STRATA.WINDOW)
    local found = false
    for _, name in ipairs(M.UISpecialFrames) do if name == J.FRAME_NAME then found = true end end
    assertTrue(found, "Escape closes the Journal (UISpecialFrames)")
    J.Hide()
end)

test("journal: the tabs switch panels: Session Log first, then Alts", function()
    J.Show()
    J.SelectTab("log")
    local f = J.Frame()
    assertTrue(f.logPanel:IsShown() and not f.altsPanel:IsShown(), "the log tab shows its panel")
    assertTrue(J.SelectTab("alts"))
    assertTrue(f.altsPanel:IsShown() and not f.logPanel:IsShown(), "the alts tab shows its panel")
    assertFalse(J.SelectTab("nope"), "an unknown tab is refused")
    assertEqual(J.SelectedTab(), "alts")
    J.SelectTab("log")
    J.Hide()
end)

test("journal: the log lists skill-ups newest first, with the session's gains, and Clear empties it", function()
    SL:Clear()
    SL:NewSession(M.time() - 600)
    SL:Add("bows", 80, 81, M.time() - 300, "Loch Modan")
    SL:Add("fishing", 106, 107, M.time() - 200, "Loch Modan")
    J.Show()
    J.SelectTab("log")
    local p = J.Frame().logPanel
    local rows = activeRows(p)
    assertEqual(#rows, 2)
    assertEqual(rows[1].entry.key, "fishing", "newest first")
    assertEqual(rows[1].cols[3]:GetText(), "106 \226\134\146 107")
    assertEqual(rows[1].cols[4]:GetText(), "Loch Modan")
    assertEqual(p.session.value:GetText(), "+2")
    assertFalse(p.empty:IsShown(), "no empty state with entries")
    p.clear:GetScript("OnClick")(p.clear)
    assertEqual(#SL:Entries(), 0, "Clear log cleared the store")
    assertEqual(#activeRows(p), 0, "and the list")
    assertTrue(p.empty:IsShown(), "the empty state shows")
    J.Hide()
end)

test("journal: a SKILLS_UPDATED repaints an open log", function()
    SL:Clear()
    J.Show()
    J.SelectTab("log")
    SL:Add("bows", 81, 82)
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, NS.SkillData:Model())
    assertEqual(#activeRows(J.Frame().logPanel), 1)
    SL:Clear()
    J.Hide()
end)

test("journal: the alts grid shows a character per row and a mini bar per skill it has", function()
    forgetAll()
    NS.db.global.characters["PvE-Ember Ironsong"] = {
        name = "Ember Ironsong", class = "HUNTER", className = "Hunter", race = "Dwarf", level = 22,
        skills = { leatherworking = { name = "Leatherworking", category = "primary", rank = 146, max = 150 },
                   bows = { name = "Bows", category = "weapon", rank = 80, max = 110 } },
    }
    NS.db.global.characters["PvE-Quill Ashbrook"] = {
        name = "Quill Ashbrook", class = "WARRIOR", className = "Warrior", race = "Human", level = 41,
        skills = { mining = { name = "Mining", category = "primary", rank = 212, max = 225 } },
    }
    J.Show()
    J.SelectTab("alts")
    J.SelectFilter("professions")
    local p = J.Frame().altsPanel
    local rows = activeRows(p)
    assertEqual(#rows, 2, "one row per character")
    assertEqual(#p.cols, 2, "Professions shows Leatherworking and Mining, not Bows")
    local ember = rows[1].altKey == "PvE-Ember Ironsong" and rows[1] or rows[2]
    assertEqual(ember.name:GetText(), "Ember Ironsong", "the whole two-word name")
    local lw, mining
    for c, key in ipairs(p.cols) do
        if key == "leatherworking" then lw = ember.cells[c] else mining = ember.cells[c] end
    end
    assertEqual(lw.value:GetText(), "146/150")
    assertTrue(lw.fill:IsShown() and lw.bg:IsShown(), "a mini bar for a skill it has")
    assertTrue(mining.dash:IsShown() and not mining.value:IsShown(), "a dash for one it has not")
    J.SelectFilter("weapons")
    assertEqual(#p.cols, 1, "Weapons shows Bows")
    assertFalse(J.SelectFilter("nope"))
    J.SelectFilter("professions")
    J.SelectTab("log")
    J.Hide()
    forgetAll()
end)

test("journal: right-click on a character asks before forgetting it", function()
    forgetAll()
    NS.db.global.characters["PvE-Tamsin Reedwhistle"] = { name = "Tamsin Reedwhistle", level = 17, skills = {} }
    J.Show()
    J.SelectTab("alts")
    local row = activeRows(J.Frame().altsPanel)[1]
    M.__popups = {}
    row:GetScript("OnMouseUp")(row, "RightButton")
    assertEqual(M.__popups[1], "SKILLMASTER_FORGET_ALT")
    M.StaticPopupDialogs.SKILLMASTER_FORGET_ALT.OnAccept(nil, "PvE-Tamsin Reedwhistle")
    assertTrue(NS.db.global.characters["PvE-Tamsin Reedwhistle"] == nil, "forgotten on accept")
    J.SelectTab("log")
    J.Hide()
end)

test("journal: an unlocked drag saves the drop point; Reset position forgets it", function()
    J.Show()
    local f = J.Frame()
    local realGetPoint = f.GetPoint
    f.GetPoint = function() return "TOPLEFT", M.UIParent, "TOPLEFT", 12, -34 end
    f:GetScript("OnDragStop")(f)
    f.GetPoint = realGetPoint
    local p = NS.db.profile.journal.point
    assertEqual(p and p.x, 12)
    J.ResetPosition()
    assertFalse(NS.db.profile.journal.point, "forgotten")
    J.Hide()
end)

test("journal: the stand-down hides it", function()
    J.Show()
    NS.SetByPath("enabled", false)
    assertFalse(J.IsShown(), "hidden by the stand-down")
    assertFalse(J.Show(), "and Show refuses while stood down")
    NS.SetByPath("enabled", true)
end)

test("journal: durations and ETAs read as the mockup writes them", function()
    assertEqual(J.FormatDuration(6720), "1 h 52 m")
    assertEqual(J.FormatDuration(300), "5 m")
    assertEqual(J.FormatETA(1800), "~30 m")
    assertEqual(J.FormatETA(5 * 3600), "~5 h")
    assertEqual(J.FormatETA(nil), nil)
end)
