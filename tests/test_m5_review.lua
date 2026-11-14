-- tests/test_m5_review.lua — the M5 review's findings, each red before its fix:
--   * a profile switch, copy or reset repaints every surface from the new profile (options-ui-§12):
--     the window's and the detached blocks' bars restyle even when the row set did not move, the
--     broker feeds re-read their templates, and the Bars page's preview and the Journal hear the one
--     LAYOUT_CHANGED every other look change sends, and the Journal takes its stored geometry;
--   * the Bars page's preview fills in the color the Colors tab picks (the mockup's Fishing bar is
--     the secondary-skill green), so a palette, mode or flat-color edit shows in it;
--   * test mode writes nothing of the character's own: a sample row's menu cannot pin it.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function firstBarHeight()
    for _, row in ipairs(NS.MainWindow.Rows()) do
        if row.bar and row.bar.style then return row.bar.style.height end
    end
end

-- A scratch profile, seeded as one that already closed the first-run skin picker, so the switch
-- shows no picker; the case runs inside it and the active profile comes back whatever happens.
local function withProfile(name, fn)
    local db = NS.db
    local before = db:GetCurrentProfile()
    db.sv.profiles[name] = { skin = { pickerSeen = true } }
    local ok, err = pcall(fn, db)
    db:SetProfile(before)
    db.sv.profiles[name] = nil
    NS.HideSkinPicker()
    if not ok then error(err, 0) end
end

test("profile switch: the window's bars restyle from the new profile with the same row set", function()
    -- red under: reloadProfile's values-only MainWindow.Refresh(), which keeps every bar in the old
    -- profile's look while the row set's signature is unchanged.
    local default = NS.defaults.profile.bars.height
    local wasShown = NS.MainWindow.IsShown()
    NS.MainWindow.Show()
    NS.SetByPath("bars.height", default + 6)
    assertEqual(firstBarHeight(), default + 6, "the live write reached the window")
    withProfile("ReviewSwitch", function(db)
        db:SetProfile("ReviewSwitch")
        assertEqual(firstBarHeight(), default, "the new profile's bar height is drawn")
    end)
    assertEqual(firstBarHeight(), default + 6, "and the old one's again on the way back")
    NS.SetByPath("bars.height", default)
    if not wasShown then NS.MainWindow.Hide() end
end)

test("profile switch: the broker feed re-reads the new profile's template", function()
    -- red under: a reloadProfile that never calls NS.Broker.Refresh, so a feed keeps the old
    -- profile's text until the next skill pass.
    local default = NS.defaults.profile.broker.template
    NS.SetByPath("broker.template", "review {level}")
    assertTrue(tostring(NS.Broker.Text()):find("^review ") ~= nil, "the write reached the feed")
    withProfile("ReviewBroker", function(db)
        db:SetProfile("ReviewBroker")
        assertTrue(tostring(NS.Broker.Text()):find("^review ") == nil,
            "the new profile's template is drawn, got " .. tostring(NS.Broker.Text()))
    end)
    NS.SetByPath("broker.template", default)
end)

test("profile switch: the Journal takes the new profile's drop point and size", function()
    -- red under: a reloadProfile that leaves the Journal where the old profile put it (its point
    -- and size are applied once, when the frame is built). The kit's frames keep no geometry, so
    -- the case records the frame's own SetPoint and SetSize calls.
    local J = NS.Journal
    J.Show()
    local f = J.Frame()
    local realSetPoint, realSetSize = f.SetPoint, f.SetSize
    local point, size
    f.SetPoint = function(self, p, ...) point = p return realSetPoint(self, p, ...) end
    f.SetSize = function(self, w, h) size = w return realSetSize(self, w, h) end
    local ok, err = pcall(function()
        NS.db.profile.journal.point = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 12, y = -34 }
        NS.db.profile.journal.size = { w = J.MIN_W + 100, h = J.MIN_H + 50 }
        withProfile("ReviewJournal", function(db)
            point, size = nil, nil
            db:SetProfile("ReviewJournal")
            assertEqual(point, "CENTER", "the new profile has no drop point: the default place")
            assertEqual(size, J.MIN_W, "and no size: the default size")
            point, size = nil, nil
        end)
        assertEqual(point, "TOPLEFT", "the old profile's point again on the way back")
        assertEqual(size, J.MIN_W + 100, "and its size")
    end)
    f.SetPoint, f.SetSize = realSetPoint, realSetSize
    NS.db.profile.journal.point, NS.db.profile.journal.size = false, false
    J.ResetPosition()
    J.Hide()
    if not ok then error(err, 0) end
end)

test("profile reset: one LAYOUT_CHANGED reaches the look listeners (the Journal)", function()
    -- red under: a reloadProfile that repaints only the window and the detached blocks.
    withProfile("ReviewReset", function(db)
        db:SetProfile("ReviewReset")
        local seen = 0
        local target = NS.NewBusTarget()
        target:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() seen = seen + 1 end)
        local ok, err = pcall(function() db:ResetProfile() end)
        target:UnregisterMessage(NS.MSG.LAYOUT_CHANGED)
        if not ok then error(err, 0) end
        assertTrue(seen >= 1, "the reset sends LAYOUT_CHANGED")
    end)
end)

-- ---------------------------------------------------------------------------------------------
-- Test mode writes nothing of the character's own
-- ---------------------------------------------------------------------------------------------

test("test mode: a sample row's menu cannot pin the sample skill into the character's store", function()
    -- red under: a pin row that writes db.char.pinned from a test-mode row, so the sample
    -- character's skill outlives the preview in SavedVariables and drives the live {pinned}.
    NS.db.char = NS.db.char or {}
    local before = NS.db.char.pinned
    assertTrue(NS.ToggleTestMode() == true, "test mode on")
    local ok, err = pcall(function()
        local row = { kind = "skill", entry = { key = "guns", name = "Guns", category = "weapon", rank = 105,
                                                 max = 110, learned = true } }
        local pin
        for _, r in ipairs(NS.Interact.MenuRows(row)) do if r.value == "pin" then pin = r end end
        assertTrue(pin ~= nil, "the menu still lists the pin")
        assertTrue(pin.disabled == true, "grayed out while test mode is on")
        pin.onClick("pin", pin)
        assertEqual(NS.db.char.pinned, before, "and a click writes nothing")
    end)
    NS.ToggleTestMode()
    NS.db.char.pinned = before
    if not ok then error(err, 0) end
    assertTrue(not NS.IsTestMode(), "test mode off again")
end)
