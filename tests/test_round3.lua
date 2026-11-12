-- tests/test_round3.lua — the owner's round-3 feedback (2026-11-11): each block's sort order (its
-- header mark, its setting, the LDB tooltip following it), the weapon alert's modes and mute list,
-- the window keeping its height, the broker's unpinned title and its row menu, Skinning's window
-- and the Skills tab opening on the clicked skill.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local W, Blocks, I, A, B = NS.MainWindow, NS.Blocks, NS.Interact, NS.Alerts, NS.Broker

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()
end

local function withWorld(fn)
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(fn)
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].sort = "name" end
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function keysOf(entries)
    local out = {}
    for i, r in ipairs(entries) do out[i] = r.entry.key end
    return table.concat(out, ",")
end

-- ── sorting ─────────────────────────────────────────────────────────────────────────────────

test("round3 sort: Value orders a block high first, not-learned rows last; Default is the catalog's", function()
    withWorld(function()
        local name = keysOf(Blocks.Entries("weapon"))
        set("layout.blocks.weapon.sort", "value")
        local entries, seenUnlearned, last = Blocks.Entries("weapon"), false, math.huge
        for _, r in ipairs(entries) do
            local e = r.entry
            if e.learned == false then
                seenUnlearned = true
            else
                assertFalse(seenUnlearned, e.key .. ": a learned row after a not-learned one")
                assertTrue(e.rank <= last, e.key .. ": highest first")
                last = e.rank
            end
        end
        set("layout.blocks.weapon.sort", "valueAsc")
        last = -1
        for _, r in ipairs(Blocks.Entries("weapon")) do
            if r.entry.learned ~= false then
                assertTrue(r.entry.rank >= last, r.entry.key .. ": lowest first")
                last = r.entry.rank
            end
        end
        set("layout.blocks.weapon.sort", "name")
        assertEqual(keysOf(Blocks.Entries("weapon")), name, "Default gives the catalog's order back")
    end)
end)

test("round3 sort: the header's sort mark cycles Default, Value high, Value low, Progress, and the window redraws", function()
    withWorld(function()
        local header
        for _, h in ipairs(W.Headers()) do if h.id == "weapon" then header = h end end
        assertTrue(header ~= nil and header.sort ~= nil, "the weapon header carries a sort mark")
        assertEqual(header.sort.icon:GetTexture(), NS.Icon("list"), "Default at first")
        for _, want in ipairs({ "value", "valueAsc", "progress", "name" }) do
            header.sort:__fire("OnClick", "LeftButton")
            M.__fireTimers()
            assertEqual(Blocks.SortOf("weapon"), want, "the next mode")
            assertEqual(NS.db.profile.layout.blocks.weapon.sort, want, "stored through the seam")
        end
        header.sort:__fire("OnClick", "LeftButton")
        M.__fireTimers()
        for _, h in ipairs(W.Headers()) do if h.id == "weapon" then header = h end end
        assertEqual(header.sort.icon:GetTexture(), NS.Icon("sort-desc"), "the redrawn header shows Value, highest first")
        local rows = {}
        for _, row in ipairs(W.Rows()) do
            if row.entry and NS.SkillCatalog[row.entry.key] and NS.SkillCatalog[row.entry.key].category == "weapon" then
                rows[#rows + 1] = row.entry.key
            end
        end
        assertEqual(table.concat(rows, ","), keysOf(Blocks.Entries("weapon")), "the window's rows in the block's order")
    end)
end)

test("round3 sort: the LDB tooltip lists a section in its block's order", function()
    withWorld(function()
        set("layout.blocks.weapon.sort", "valueAsc")
        local rows = B.FillTooltip(M.CreateFrame("GameTooltip", "SkillMasterRound3Tip", M.UIParent, "GameTooltipTemplate"))
        local got = {}
        for _, r in ipairs(rows) do
            local c = r.kind == "skill" and NS.SkillCatalog[r.key]
            if c and c.category == "weapon" then got[#got + 1] = r.key end
        end
        local want = {}
        for _, r in ipairs(Blocks.Entries("weapon")) do
            if not B.HiddenInTooltip("skill", r.entry.key) then want[#want + 1] = r.entry.key end
        end
        assertEqual(table.concat(got, ","), table.concat(want, ","))
    end)
end)

-- ── the weapon alert ────────────────────────────────────────────────────────────────────────

test("round3 alerts: skip untrained by default; equipped only; every weapon; a muted weapon never", function()
    local unarmed = { key = "unarmed", kind = "weapon", learned = true, rank = 4, max = 120 }
    local bows = { key = "bows", kind = "weapon", learned = true, rank = 80, max = 120 }
    assertEqual(NS.GetSetting("alerts.weaponMode"), "untrained", "the default")
    assertFalse(A.WeaponWatched(unarmed), "Unarmed at 4: untrained, skipped")
    assertTrue(A.WeaponWatched(bows), "Bows at 80: watched")
    set("alerts.weaponMode", "equipped")
    local saved = NS.SkillHelpers.EquippedWeaponSkills
    NS.SkillHelpers.EquippedWeaponSkills = function() return { unarmed = true } end
    local okEq, errEq = pcall(function()
        assertTrue(A.WeaponWatched(unarmed), "equipped: watched whatever its points")
        assertFalse(A.WeaponWatched(bows), "not equipped: skipped")
    end)
    NS.SkillHelpers.EquippedWeaponSkills = saved
    if not okEq then error(errEq, 0) end
    set("alerts.weaponMode", "all")
    assertTrue(A.WeaponWatched(unarmed), "every weapon")
    set("alerts.weaponMuted.bows", true)
    assertFalse(A.WeaponWatched(bows), "a muted weapon never alerts")
    assertTrue(NS.db.profile.alerts.weaponMuted.bows, "stored in the muted set")
    set("alerts.weaponMuted.bows", false)
    set("alerts.weaponMode", "untrained")
end)

-- ── the window's height ─────────────────────────────────────────────────────────────────────

test("round3 window: collapsing every block keeps the window's height; Shrink to fit lets it shrink", function()
    withWorld(function()
        local f, h = W.Frame(), nil
        rawset(f, "SetHeight", function(_, v) h = v end)
        local ok, err = pcall(function()
            W.Refresh(true)
            local tall = h
            assertEqual(tall, NS.db.profile.layout.maxHeight, "Window height")
            Blocks:SetAllCollapsed(true)
            M.__fireTimers()
            W.Refresh(true)
            assertEqual(h, tall, "collapsed: the same height")
            set("layout.fitHeight", true)
            W.Refresh(true)
            assertTrue(h < tall, "Shrink to fit: the window shrinks to its headers")
        end)
        rawset(f, "SetHeight", nil)
        set("layout.fitHeight", false)
        Blocks:SetAllCollapsed(false)
        M.__fireTimers()
        if not ok then error(err, 0) end
    end)
end)

-- ── the broker ──────────────────────────────────────────────────────────────────────────────

test("round3 broker: a second Pin on the pinned skill unpins it, and the feed reads Professions and Skills", function()
    local before = NS.db.char.pinned
    NS.db.char.pinned = false
    -- End any earlier suite's skill-up flash: a fresh flash, then its timer runs out.
    B.Flash("cooking", 1)
    M.__now = M.__now + B.FlashSeconds() + 1
    M.__fireTimers()
    local row = { kind = "skill", entry = { key = "cooking", name = "Cooking", learned = true, rank = 1, max = 75 } }
    local pin
    for _, r in ipairs(I.MenuRows(row)) do if r.value == "pin" then pin = r end end
    pin.onClick()
    assertEqual(NS.db.char.pinned, "cooking", "pinned")
    pin.onClick()
    assertEqual(NS.db.char.pinned, false, "unpinned")
    B.Refresh()
    assertEqual(B.Text(), "Professions and Skills")
    NS.db.char.pinned = before
    B.Refresh()
end)

test("round3 broker: a right-click on a tooltip row opens the row menu, whose Hide leaves it out of the tooltip only", function()
    withWorld(function()
        local savedMenu, opened = I.Menu, nil
        I.Menu = function(row) opened = row return row end
        local ok, err = pcall(function()
            B.OpenRow({ kind = "skill", key = "cooking" }, "RightButton", M.UIParent)
            assertTrue(opened ~= nil and opened.entry.key == "cooking", "the menu for the row's entry")
            assertEqual(opened.surface, "broker")
            local hide
            for _, r in ipairs(I.MenuRows(opened)) do if r.value == "hide" then hide = r end end
            assertEqual(hide.label, "Hide in this tooltip")
            hide.onClick()
            assertTrue(B.HiddenInTooltip("skill", "cooking"), "left out of the tooltip")
            assertFalse(NS.db.profile.skills.hidden.cooking == true, "still in the window")
        end)
        I.Menu = savedMenu
        NS.db.profile.broker.tooltip.hiddenSkills.cooking = nil
        if not ok then error(err, 0) end
    end)
end)

test("round3 broker: the bars stop at the widest value, never past the old fixed column", function()
    local tip = M.CreateFrame("GameTooltip", "SkillMasterRound3Inset", M.UIParent, "GameTooltipTemplate")
    local inset = B.ValueInset(tip)
    assertTrue(inset > 0 and inset <= 124, "within the old 124 px column: " .. tostring(inset))
end)

-- ── the windows a click opens ───────────────────────────────────────────────────────────────

test("round3 click: a weapon row opens the Skills tab with its line selected", function()
    local C = NS.Compat
    local saved = { C.NumSkillLines, C.SkillLineInfo, C.SelectSkillLine, M.ToggleCharacter }
    local selected, toggled
    C.NumSkillLines = function() return 3 end
    C.SkillLineInfo = function(i)
        return ({ { name = "Weapon Skills", isHeader = true },
                  { name = "Bows", skillLineID = 45 },
                  { name = "Guns", skillLineID = 46 } })[i]
    end
    C.SelectSkillLine = function(i) selected = i return "SetSelectedSkill" end
    M.ToggleCharacter = function(tab) toggled = tab end
    local ok, err = pcall(function()
        assertEqual(I.SkillLineIndex("guns"), 3, "Guns by its line ID")
        I.OpenSkills("guns")
        assertEqual(toggled, "SkillsFrame", "the Skills tab opens (Forever's SkillsFrame, round 4)")
        assertEqual(selected, 3, "on Guns")
    end)
    C.NumSkillLines, C.SkillLineInfo, C.SelectSkillLine, M.ToggleCharacter = saved[1], saved[2], saved[3], saved[4]
    if not ok then error(err, 0) end
end)

test("round3 click: Compat.OpenTradeSkill answers false without the call, and the call's own answer with it", function()
    local C = NS.Compat
    M.C_TradeSkillUI = nil
    assertFalse(C.OpenTradeSkill(393), "no C_TradeSkillUI")
    M.C_TradeSkillUI = { OpenTradeSkill = function() return false end }
    assertFalse(C.OpenTradeSkill(393), "the client refused")
    M.C_TradeSkillUI = { OpenTradeSkill = function() error("blocked") end }
    assertFalse(C.OpenTradeSkill(393), "an error is a refusal, never thrown")
    M.C_TradeSkillUI = { OpenTradeSkill = function() return true end }
    assertTrue(C.OpenTradeSkill(393))
    M.C_TradeSkillUI = nil
end)
