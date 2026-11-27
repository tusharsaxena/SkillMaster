-- tests/test_windows.lua — the six family windows (item SMW-04 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md): one window per family, each with its own
-- frame, blocks, settings and place; the schemaVersion 14 split of the old one window's settings; the
-- slash verbs, the key bindings and the "Character Stats" labels.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local Windows = NS.Windows

local function hideAll() Windows.HideAll() end

test("windows: one window per family, in the family order, each its own frame and title", function()
    local names, frames, n = {}, {}, 0
    for fid, W in Windows.Each() do
        n = n + 1
        assertEqual(W.family, fid)
        assertTrue(not names[W.FRAME_NAME], "frame names are unique: " .. W.FRAME_NAME)
        names[W.FRAME_NAME] = true
        W.Show()
        assertEqual(W.Frame().title:GetText(), NS.Families[fid].title, fid .. "'s title")
        assertTrue(not frames[W.Frame()], fid .. ": a frame of its own")
        frames[W.Frame()] = true
    end
    assertEqual(n, 6)
    assertEqual(Windows.Get("professions").FRAME_NAME, "CharacterLedgerMainWindow", "Professions keeps the old window's name")
    assertEqual(NS.MainWindow.Frame(), Windows.Get("professions").Frame(), "NS.MainWindow is the Professions window")
    local escape = {}
    for _, name in ipairs(M.UISpecialFrames) do escape[name] = true end
    for _, W in Windows.Each() do assertTrue(escape[W.FRAME_NAME], W.FRAME_NAME .. " closes on Escape") end
    hideAll()
end)

test("windows: each window draws its own family's docked blocks, and only those", function()
    NS.ToggleTestMode()   -- the sample character fills every skill and stat block
    local ok, err = pcall(function()
        for _, fid in ipairs({ "professions", "skills", "stats" }) do
            local W = Windows.Get(fid)
            W.Show()
            W.Refresh(true)
            local want = {}
            for _, id in ipairs(NS.Families[fid].blocks) do want[id] = true end
            local seen = 0
            for _, id in ipairs(NS.BLOCKS) do
                local h = W.HeaderFor(id)
                if want[id] then
                    assertTrue(h ~= nil, fid .. " draws " .. id)
                    seen = seen + 1
                else
                    assertTrue(h == nil, fid .. " never draws " .. id)
                end
            end
            assertEqual(seen, #NS.Families[fid].blocks, fid)
        end
        assertEqual(table.concat(NS.Blocks.DockedIn("skills"), ","), "weapon,other")
    end)
    NS.ToggleTestMode()
    hideAll()
    if not ok then error(err, 0) end
end)

test("windows: the Character Stats window drops the Stats prefix nowhere it matters; tree windows show their empty line", function()
    assertEqual(NS.Families.stats.title, "Character Ledger \194\183 Character Stats")
    assertEqual(NS.Families.stats.short, "Character Stats")
    local empty = { currencies = "No currencies to show yet.", reputations = "No reputations to show yet.",
                    statistics = "No statistics to show yet." }
    for _, fid in ipairs({ "currencies", "reputations", "statistics" }) do
        local W = Windows.Get(fid)
        W.Show()
        assertEqual(W.Frame().empty:GetText(), empty[fid], fid .. ": nothing of its own yet")
        assertTrue(W.Frame().empty:IsShown(), fid .. "'s empty line shows")
        assertFalse(Windows.HasLegend(fid), fid .. " draws no bonus legend")
        W.Hide()
    end
    assertTrue(Windows.HasLegend("professions") and Windows.HasLegend("stats"), "the bars with bonuses keep it")
    assertEqual(Windows.EmptyText("stats"), "No stats to show yet.")
end)

test("windows: each window's size and strata are its own rows, applied to it alone", function()
    local P, S = Windows.Get("professions"), Windows.Get("skills")
    P.Show() S.Show()
    assertTrue(NS.SetByPath("windows.skills.strata", "LOW"))
    assertEqual(S.Frame():GetFrameStrata(), "LOW", "the Skills window takes its own strata")
    assertEqual(P.Frame():GetFrameStrata(), "MEDIUM", "the Professions window keeps its own")
    local before = P.ContentWidth()
    assertTrue(NS.SetByPath("windows.skills.width", 600))
    assertTrue(S.ContentWidth() > before, "the Skills window grows")
    assertEqual(P.ContentWidth(), before, "the Professions window does not")
    NS.SetByPath("windows.skills.strata", "MEDIUM")
    NS.SetByPath("windows.skills.width", NS.defaults.profile.windows.skills.width)
    NS.SetByPath("windows.skills.strata", "HIGH")
    assertEqual(NS.TrainerPopup.Strata(), "DIALOG", "the trainer popup opens over the highest window")
    NS.SetByPath("windows.skills.strata", "MEDIUM")
    hideAll()
end)

test("windows: a window never dragged opens next to the Professions window, stacked down and right", function()
    local w = NS.db.profile.windows
    local saved = w.professions.point
    w.professions.point = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 100, y = -80 }
    local p = Windows.Point("stats")
    assertEqual(p.point, "TOPLEFT")
    assertEqual(p.x, 160, "two steps right: Character Stats is third")
    assertEqual(p.y, -140, "and two down")
    w.stats.point = { point = "CENTER", relPoint = "CENTER", x = 5, y = 6 }
    assertEqual(Windows.Point("stats").x, 5, "its own drop point wins once dragged")
    w.stats.point = false
    w.professions.point = saved
    assertEqual(Windows.Point("professions").point, "CENTER", "with no drop point, Professions opens centered")
end)

test("windows: a drag saves that window's drop point alone; Reset position forgets every one", function()
    local S = Windows.Get("currencies")
    S.Show()
    local f = S.Frame()
    rawset(f, "GetPoint", function() return "TOPLEFT", M.UIParent, "TOPLEFT", 12, -34 end)
    f:GetScript("OnDragStop")(f)
    rawset(f, "GetPoint", nil)
    local p = NS.db.profile.windows.currencies.point
    assertTrue(type(p) == "table" and p.x == 12 and p.y == -34, "stored under windows.currencies.point")
    assertFalse(NS.db.profile.windows.professions.point, "the Professions window's stays unset")
    NS.MainWindow.ResetPosition()
    assertFalse(NS.db.profile.windows.currencies.point, "Reset position reaches every window")
    hideAll()
end)

test("windows: schemaVersion 14 moves the old window's stored settings to the Professions window", function()
    local sv = rawget(_G, "CharacterLedgerDB")
    sv.profiles = sv.profiles or {}
    local p = sv.profiles
    p["Win-Old"] = { window = { point = { point = "TOP", relPoint = "TOP", x = 1, y = -2 } },
                     layout = { width = 500, columns = 2, strata = "HIGH", summary = false, blockGap = 4,
                                blocks = { weapon = { collapsed = true } } } }
    p["Win-Kept"] = { layout = { width = 600 }, windows = { professions = { width = 700 } } }
    p["Win-Default"] = { window = { point = false } }
    p["Win-Fresh"] = {}
    NS.db.global.schemaVersion = 13
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    local w = p["Win-Old"].windows.professions
    assertEqual(w.point.point, "TOP", "the drop point moves")
    assertEqual(w.width, 500) assertEqual(w.columns, 2) assertEqual(w.strata, "HIGH")
    assertEqual(w.summary, false, "a stored false is a choice and moves")
    assertTrue(p["Win-Old"].window == nil, "the old window table goes")
    assertTrue(p["Win-Old"].layout.width == nil and p["Win-Old"].layout.strata == nil, "the old keys go")
    assertEqual(p["Win-Old"].layout.blockGap, 4, "the shared layout keys stay")
    assertEqual(p["Win-Old"].layout.blocks.weapon.collapsed, true, "and so do the blocks")
    assertTrue(p["Win-Old"].windows.skills == nil, "the other windows keep their defaults")
    assertEqual(p["Win-Kept"].windows.professions.width, 700, "a value already stored there wins")
    assertTrue(p["Win-Kept"].layout.width == nil, "the old key still goes")
    assertTrue(p["Win-Default"].windows == nil and p["Win-Default"].window == nil, "an unset point moves nothing")
    assertTrue(p["Win-Fresh"].windows == nil, "a fresh profile passes through")
    -- Once: the stamp is past the step.
    p["Win-Fresh"].layout = { width = 333 }
    NS:RunMigrations()
    assertEqual(p["Win-Fresh"].layout.width, 333, "the step ran once")
    for _, k in ipairs({ "Win-Old", "Win-Kept", "Win-Default", "Win-Fresh" }) do p[k] = nil end
end)

test("windows: one slash verb per window toggles it; /cl hide hides them all", function()
    hideAll()
    for _, fid in ipairs(NS.FAMILY_ORDER) do
        NS.Slash:OnSlash(fid)
        assertTrue(Windows.Get(fid).IsShown(), "/cl " .. fid .. " shows its window")
    end
    NS.Slash:OnSlash("statistics")
    assertFalse(Windows.Get("statistics").IsShown(), "a second /cl statistics hides it")
    NS.Slash:OnSlash("hide")
    assertFalse(Windows.AnyShown(), "/cl hide hides every window")
    -- Re-pinned by R5-SM-05 (the owner's round 5): /cl toggle is every window, /cl professions the Professions one.
    NS.Slash:OnSlash("toggle")
    assertTrue(Windows.Get("professions").IsShown() and Windows.Get("skills").IsShown(),
        "/cl toggle shows every window")
    hideAll()
end)

test("windows: each family's key binding button toggles its window", function()
    hideAll()
    for fid, button in pairs(NS.MainWindow.__familyButtons) do
        assertEqual(button.__template, nil, fid .. ": a plain button")
        button:GetScript("OnClick")(button, "LeftButton")
        assertTrue(Windows.Get(fid).IsShown(), fid .. ": one press shows it")
        assertFalse(Windows.Get("professions").IsShown(), fid .. ": and no other")
        button:GetScript("OnClick")(button, "LeftButton")
        assertFalse(Windows.Get(fid).IsShown(), fid .. ": a second press hides it")
    end
end)

test("windows: a broker crafting row routes to the window that docks it", function()
    NS.ToggleTestMode()
    local ok, err = pcall(function()
        hideAll()
        Windows.ShowAndScrollTo("bows")
        assertTrue(Windows.Get("skills").IsShown(), "a weapon skill opens the Skills window")
        assertFalse(Windows.Get("professions").IsShown(), "not the Professions one")
        hideAll()
        Windows.ShowAndScrollTo("nope")
        assertTrue(Windows.Get("professions").IsShown(), "an unknown key falls back to Professions")
    end)
    NS.ToggleTestMode()
    hideAll()
    if not ok then error(err, 0) end
end)

test("windows: a stood-down addon refuses every window", function()
    hideAll()
    NS.SetByPath("enabled", false)
    for _, W in Windows.Each() do W.Show() end
    local any = Windows.AnyShown()
    NS.SetByPath("enabled", true)
    assertFalse(any, "no window shows while disabled")
end)
