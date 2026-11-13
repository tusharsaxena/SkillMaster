-- tests/test_round5_followups.lua — the owner's tasks added to round 5 (2026-11-13), the second
-- workflow. R5-10: the Weapon Skills block's filter mark (All, Learned, Equipped, Below cap) on its
-- header in the main window, in its detached frame and on its merged-window sub-header; the filter
-- persisted per profile through the seam; an emptied block's muted line; Equipped on an equipment change.
-- R5-14: the trainer popup's "Also teaches" line wraps, its card and the window grow by the measured
-- height (a secret or zero measure is one line), a cap clips each to one, the card's tooltip.
-- R5-15: the trainer distances: the pure math (Trainers.Distance, ByDistance), the Compat world
-- positions over the mocked C_Map (secret and missing guarded), the cards' yards, nearest first, the
-- 1 s re-measure while shown and its stop on hide.
-- R5-11..R5-13: the Rows page (settings/Rows.lua): the Stats page gone, every Hide row there, the
-- groups in the window's block order, the column captions, the headings' show-all eyes, two eyes a
-- row, its Defaults (both hidden sets) and its redraw after a write made while it was hidden.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local W, B, D, G = NS.MainWindow, NS.Blocks, NS.Detached, NS.Groups

-- ── R5-10: the weapon filter ────────────────────────────────────────────────────────────────

-- Guns learned below cap, Staves learned at cap, Bows not learned; Staves in the main hand.
local function weaponSkills()
    local function e(key, name, rank, max, learned)
        return { key = key, name = name, category = "weapon", rank = rank, max = max, modifier = 0,
                 tempPoints = 0, learned = learned }
    end
    return { byKey = {
        guns   = e("guns", "Guns", 105, 110, true),
        staves = e("staves", "Staves", 110, 110, true),
        bows   = e("bows", "Bows", 0, 0, false),
    }, order = { primary = {}, secondary = {}, weapon = { "guns", "staves", "bows" }, other = {} } }
end

local STAVES, GUNS = 10, 3   -- Enum.ItemWeaponSubclass

-- The main hand holds a weapon of `subclass` (nil: empty, so "unarmed").
local function wield(subclass)
    M.GetInventoryItemLink = function(_, slot)
        if slot == 16 and subclass then return "|Hitem:2508|h[Test]|h" end
    end
    M.GetItemInfoInstant = function() return 2508, "Weapon", "Test", "INVTYPE_WEAPON", 0, 2, subclass end
end

local function withWeapons(fn)
    local s = NS.db.profile.layout.blocks.weapon
    local saved = { NS.Blocks.source, M.GetInventoryItemLink, M.GetItemInfoInstant, NS.Widgets.ContextMenu }
    local skills = weaponSkills()
    NS.Blocks.source = function() return skills, { base = {}, spell = {}, defense = {}, utility = {} } end
    wield(STAVES)
    W.Show()
    W.Refresh(true)
    local ok, err = pcall(fn, skills)
    s.filter, s.docked, s.collapsed = "all", true, false
    NS.db.profile.layout.groups = {}
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].docked = true end
    NS.Blocks.source, M.GetInventoryItemLink, M.GetItemInfoInstant, NS.Widgets.ContextMenu =
        saved[1], saved[2], saved[3], saved[4]
    D.Refresh()
    W.Hide()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
end

local function keysOf(list)
    local out = {}
    for _, r in ipairs(list) do out[#out + 1] = r.entry and r.entry.key end
    return table.concat(out, ",")
end

local function header(id)
    for _, h in ipairs(W.Headers()) do if h.id == id then return h end end
    return nil
end

local function windowWeaponRows()
    local out = {}
    for _, row in ipairs(W.Rows()) do
        if row.entry and row.entry.category == "weapon" then out[#out + 1] = row end
    end
    return out
end

test("round5 filter: All, Learned, Equipped and Below cap narrow the weapon block, stored per profile through the seam", function()
    withWeapons(function()
        assertEqual(B.FilterOf("weapon"), "all", "All by default")
        assertEqual(NS.db.profile.layout.blocks.weapon.filter, "all", "the profile default")
        assertEqual(keysOf(B.Entries("weapon")), "guns,staves,bows", "All: every row")
        local want = { learned = "guns,staves", equipped = "staves", belowCap = "guns", all = "guns,staves,bows" }
        for _, mode in ipairs({ "learned", "equipped", "belowCap", "all" }) do
            set("layout.blocks.weapon.filter", mode)
            assertEqual(B.FilterOf("weapon"), mode)
            local entries, removed = B.Entries("weapon")
            assertEqual(keysOf(entries), want[mode], mode)
            assertEqual(removed, 3 - #entries, mode .. ": answers how many it took out")
        end
        assertEqual(B.FilterOf("primary"), "all", "a block without a filter is always All")
        assertFalse(B:SetFilter("primary", "learned"), "and takes none")
        assertFalse(B:SetFilter("weapon", "bogus"), "an unknown filter is refused")
    end)
end)

test("round5 filter: Layout > Blocks > Weapon skills has the Show rows row, its values the filter menu's", function()
    local row = NS.FindSchemaRow("layout.blocks.weapon.filter")
    assertTrue(row ~= nil, "the weapon block's filter has a schema row")
    assertEqual(row.page, "layout")
    assertEqual(row.default, "all")
    local values = {}
    for _, v in ipairs(row.values) do values[#values + 1] = v.value end
    assertEqual(table.concat(values, ","), table.concat(B.FILTERS, ","))
    assertTrue(NS.FindSchemaRow("layout.blocks.primary.filter") == nil, "no other block has one")
end)

test("round5 filter: the weapon header's funnel opens a menu, the current filter ticked; a pick filters the window", function()
    withWeapons(function()
        local h = header("weapon")
        assertTrue(h ~= nil and h.filter ~= nil, "the weapon header carries a filter mark")
        assertTrue(h.filter:IsShown(), "shown on the weapon block")
        assertEqual(h.filter.icon:GetTexture(), NS.Icon("ph:funnel"), "the funnel")
        assertTrue(h.filter.tip:find(NS.L["All"], 1, true) ~= nil, "its tip names the current filter: " .. h.filter.tip)
        local other = header("primary") or header("other")
        if other then assertFalse(other.filter:IsShown(), "no filter mark on another block") end
        local opened
        NS.Widgets.ContextMenu = function(anchor, rows) opened = { anchor = anchor, rows = rows } return {} end
        h.filter:__fire("OnClick", "LeftButton")
        assertTrue(opened ~= nil and opened.anchor == h.filter, "the click opens the menu on the mark")
        local ticked, picks = {}, {}
        for _, r in ipairs(opened.rows) do
            if r.radio then
                picks[r.value] = r
                if r.selected() then ticked[#ticked + 1] = r.value end
            end
        end
        assertEqual(table.concat(ticked, ","), "all", "the current filter ticked, alone")
        picks.equipped.onClick("equipped")
        M.__fireTimers()
        assertEqual(NS.db.profile.layout.blocks.weapon.filter, "equipped", "the pick is stored")
        assertTrue(picks.equipped.selected(), "and ticked on the next paint")
        assertEqual(keysOf(windowWeaponRows()), "staves", "the window redraws with the equipped weapon only")
        h = header("weapon")
        assertTrue(h.filter.tip:find(NS.L["Equipped"], 1, true) ~= nil, "the tip follows: " .. h.filter.tip)
        assertEqual(h.filter.restToken, "text.accent", "a filter that narrows the rows draws the mark in the accent")
    end)
end)

test("round5 filter: a block its filter empties keeps its header and a muted line, not an empty block", function()
    withWeapons(function()
        wield(nil)   -- nothing in the main hand: Unarmed, which the block does not list
        set("layout.blocks.weapon.filter", "equipped")
        M.__fireTimers()
        local h = header("weapon")
        assertTrue(h ~= nil, "the emptied block keeps its header")
        assertEqual(#windowWeaponRows(), 0, "no weapon rows")
        assertTrue(h.note:IsShown(), "the muted line shows")
        assertEqual(h.note:GetText(), NS.L["No rows match this filter."])
        set("layout.blocks.weapon.filter", "all")
        M.__fireTimers()
        h = header("weapon")
        assertFalse(h.note:IsShown(), "gone once the filter lets rows through")
    end)
end)

test("round5 filter: the detached frame carries the filter mark and the muted line", function()
    withWeapons(function()
        B:Detach("weapon")
        M.__fireTimers()
        local f = D.Frame("weapon")
        assertTrue(f.filter ~= nil and f.filter:IsShown(), "the detached weapon frame has the filter mark")
        assertEqual(f.filter.icon:GetTexture(), NS.Icon("ph:funnel"))
        set("layout.blocks.weapon.filter", "belowCap")
        M.__fireTimers()
        assertEqual(keysOf(D.Rows("weapon")), "guns", "the detached rows follow the filter")
        wield(nil)
        set("layout.blocks.weapon.filter", "equipped")
        M.__fireTimers()
        assertEqual(#D.Rows("weapon"), 0)
        assertTrue(f.note:IsShown(), "the muted line in the detached frame")
        B:Detach("primary")
        M.__fireTimers()
        assertTrue(D.Frame("primary").filter == nil, "a block without a filter has no mark")
    end)
end)

test("round5 filter: a merged window's weapon sub-header carries the filter mark and the muted line", function()
    withWeapons(function()
        NS.db.profile.layout.blocks.weapon.docked = false
        NS.db.profile.layout.blocks.other.docked = false
        D.Refresh()
        local gid = G.Merge("weapon", "other", "bottom")
        assertTrue(gid ~= nil, "merged")
        local sh = G.Section(gid, "weapon").header
        assertTrue(sh.filter:IsShown(), "the weapon section's sub-header has the filter mark")
        assertFalse(G.Section(gid, "other").header.filter:IsShown(), "the other section's has none")
        wield(nil)
        set("layout.blocks.weapon.filter", "equipped")
        M.__fireTimers()
        sh = G.Section(gid, "weapon").header
        assertTrue(sh.note:IsShown(), "the muted line under the emptied section")
        assertEqual(sh.note:GetText(), NS.L["No rows match this filter."])
    end)
end)

test("round5 filter: Equipped follows an equipment change in the main window at once", function()
    withWeapons(function()
        set("layout.blocks.weapon.filter", "equipped")
        M.__fireTimers()
        assertEqual(keysOf(windowWeaponRows()), "staves")
        wield(GUNS)
        M.__fireEvent("PLAYER_EQUIPMENT_CHANGED", 16)   -- no timers: not the stats rescan's redraw
        assertEqual(keysOf(windowWeaponRows()), "guns", "the swap redraws the block")
    end)
end)

-- ── R5-14: the trainer popup's "Also teaches" line wraps ────────────────────────────────────

local TP = NS.TrainerPopup

-- The client measures `lines` wrapped lines (12 units each) on every card's "Also teaches" line,
-- clipped by its max-lines as the client clips it; `secret` answers the height as a secret.
local function measureAlso(lines, secret)
    for _, c in ipairs(TP.Cards()) do
        c.also.GetStringHeight = function(self)
            local max = self:GetMaxLines()
            local n = (max and max > 0) and math.min(lines, max) or lines
            return secret and T.kit.secret(n * 12) or n * 12
        end
    end
end

-- The kit records no SetHeight (testkit revision 35): a recorder on the window and its cards, so
-- GetHeight answers what the layout set.
local function recordHeight(f)
    f.SetHeight = function(self, h) self.__geomH, self.__geomLive = h, true end
end

local function armGeometry()
    recordHeight(TP.Frame())
    for _, c in ipairs(TP.Cards()) do recordHeight(c) end
    TP.Relayout()
end

local function withPopup(fn)
    local savedMax = TP.MAX_HEIGHT
    TP.Show("fistWeapons")
    armGeometry()
    local ok, err = pcall(fn)
    for _, c in ipairs(TP.Cards()) do c.also.GetStringHeight, c.SetHeight, c.__geomLive = nil, nil, nil end
    TP.Frame().SetHeight, TP.Frame().__geomLive = nil, nil
    TP.MAX_HEIGHT = savedMax
    TP.Hide()
    if not ok then error(err, 0) end
end

test("round5 trainer popup: the Also teaches line wraps inside its card, and the card and the window grow to fit", function()
    withPopup(function()
        local cards = TP.Cards()
        assertTrue(#cards > 0, "the popup lists trainers")
        local c = cards[1]
        assertTrue(c.also:GetText() ~= "", "the first weapon master teaches other weapons too")
        assertTrue(c.also:CanWordWrap(), "the line wraps")
        assertTrue(c.also:GetWidth() > 0, "its width is bound to the card, so the wrap has a measure")
        assertTrue(c.also:GetMaxLines() > 1, "it may take more than one line")
        local baseCard, baseFrame = c:GetHeight(), TP.Frame():GetHeight()
        measureAlso(3)
        TP.Relayout()
        assertEqual(c:GetHeight(), baseCard + 24, "three lines: the card grows by two")
        assertEqual(TP.Frame():GetHeight(), baseFrame + 24 * #cards, "and the window by every card")
    end)
end)

test("round5 trainer popup: a secret or zero measure keeps the one-line card, and too tall a window scrolls, still wrapped", function()
    withPopup(function()
        local c = TP.Cards()[1]
        local baseCard, baseFrame = c:GetHeight(), TP.Frame():GetHeight()
        local restore = T.kit.installSecretValue()
        measureAlso(3, true)
        local ok, err = pcall(TP.Relayout)
        restore()
        assertTrue(ok, "a secret height must not raise: " .. tostring(err))
        assertEqual(c:GetHeight(), baseCard, "a secret measure reads as one line")
        measureAlso(3)
        TP.MAX_HEIGHT = baseFrame + 10
        TP.Relayout()
        -- Round 6 (R6-7, issue #4): past the cap the cards scroll; the wrap is kept.
        assertTrue(c.also:GetMaxLines() > 1, "past the cap the line still wraps")
        assertEqual(TP.Frame():GetHeight(), TP.MAX_HEIGHT, "the window stops at the cap")
        local _, most = TP.Scroll()
        assertTrue(most > 0, "and the cards scroll")
    end)
end)

test("round5 trainer popup: a card's tooltip carries the whole Also teaches list", function()
    withPopup(function()
        local c = TP.Cards()[1]
        local lines, savedAdd = {}, M.GameTooltip.AddLine
        M.GameTooltip.AddLine = function(_, s) lines[#lines + 1] = s end
        local ok, err = pcall(function() c:GetScript("OnEnter")(c) end)
        M.GameTooltip.AddLine = savedAdd
        assertTrue(ok, tostring(err))
        assertEqual(lines[1], TP.Trainers()[1].name, "the trainer's name first")
        assertEqual(lines[#lines], c.alsoText, "the full list last")
        assertTrue(M.GameTooltip:IsShown(), "shown")
        c:GetScript("OnLeave")(c)
    end)
end)

-- ── R5-15: the trainer popup's distances ────────────────────────────────────────────────────

local TR = NS.Trainers

test("round5 distance: yards between two world positions, none across instances or without one", function()
    assertEqual(TR.Distance({ 0, 0, 0 }, { 0, 3, 4 }), 5, "a 3-4-5 triangle")
    assertEqual(TR.Distance({ 0, 0, 0 }, { 1, 3, 4 }), nil, "another continent is no distance")
    assertEqual(TR.Distance(nil, { 0, 3, 4 }), nil, "no player position")
    assertEqual(TR.Distance({ 0, 0, 0 }, nil), nil, "no trainer position")
end)

test("round5 distance: nearest first, the unmeasured last in their order, the input untouched", function()
    local a, b, c, d, e = { n = "a" }, { n = "b" }, { n = "c" }, { n = "d" }, { n = "e" }
    local input = { a, b, c, d, e }
    local out = TR.ByDistance(input, { [b] = 300, [d] = 20, [e] = 300 })
    local names = {}
    for i, t in ipairs(out) do names[i] = t.n end
    assertEqual(table.concat(names, ","), "d,b,e,a,c", "nearest first, ties and the unmeasured in input order")
    assertEqual(input[1], a, "a new list: the data's order is kept")
    assertEqual(#TR.ByDistance(input, nil), 5, "no distances: the same trainers")
end)

-- The player on Stormwind (1453, a 1000-yard square at the origin of instance 0); Ashenvale
-- (1440) on instance 1.
local function mapModel()
    M.__map = { player = { mapID = 1453, x = 0.1, y = 0.12 }, worlds = {
        [1453] = { instance = 0, ox = 0, oy = 0, w = 1000, h = 1000 },
        [1440] = { instance = 1, ox = 0, oy = 0, w = 1000, h = 1000 },
    } }
    M.C_Map = M.__newMapApi()
end

test("round5 distance: Compat reads the player's and a map point's world position, nil when the client cannot say", function()
    local C = NS.Compat
    local saved = { M.C_Map, M.__map }
    local ok, err = pcall(function()
        mapModel()
        local i, x, y = C.PlayerWorldPos()
        assertEqual(i, 0); assertEqual(x, 100); assertEqual(y, 120)
        i, x, y = C.MapWorldPos(1440, 0.5, 0.25)
        assertEqual(i, 1); assertEqual(x, 500); assertEqual(y, 250)
        assertEqual(C.MapWorldPos(9999, 0.5, 0.5), nil, "a map with no world rect")
        assertEqual(C.MapWorldPos(1453, nil, 0.5), nil, "no coordinates")
        M.__map.player = nil
        assertEqual(C.PlayerWorldPos(), nil, "no map (an instance)")
        mapModel()
        local restore = T.kit.installSecretValue()
        M.C_Map.GetPlayerMapPosition = function() return M.CreateVector2D(T.kit.secret(0.1), T.kit.secret(0.2)) end
        local okSecret, got = pcall(C.PlayerWorldPos)
        restore()
        assertTrue(okSecret, "a secret position must not raise: " .. tostring(got))
        assertEqual(got, nil, "a secret position is unknown")
        M.C_Map = { GetBestMapForUnit = function() return 1453 end }
        assertEqual(C.PlayerWorldPos(), nil, "an API the client lacks")
        M.C_Map = nil
        assertEqual(C.MapWorldPos(1453, 0.5, 0.5), nil, "no C_Map at all")
    end)
    M.C_Map, M.__map = saved[1], saved[2]
    if not ok then error(err, 0) end
end)

-- Four trainers in the data's order: far, no coordinates, near, on another continent.
local function distanceTrainers()
    local function t(name, mapID, x, y)
        return { name = name, faction = "Alliance", city = "Stormwind", mapID = mapID, x = x, y = y,
                 teaches = { "staves" }, verified = true }
    end
    return { t("Far", 1453, 50, 50), t("Nowhere", 1453, nil, nil), t("Near", 1453, 10, 10),
             t("Elsewhere", 1440, 10, 12) }
end

local function withDistancePopup(fn)
    local saved = { M.C_Map, M.__map, TR.For, TR.NextRank }
    local list = distanceTrainers()
    TR.For = function() return list end
    TR.NextRank = function() return nil end
    mapModel()
    TP.Show("staves")
    local ok, err = pcall(fn, list)
    TP.Hide()
    M.C_Map, M.__map, TR.For, TR.NextRank = saved[1], saved[2], saved[3], saved[4]
    if not ok then error(err, 0) end
end

local function cardNames()
    local out = {}
    for i, c in ipairs(TP.Cards()) do out[i] = c.name:GetText() end
    return table.concat(out, ",")
end

test("round5 distance: each card shows its distance and the popup sorts nearest first, the unknown last", function()
    withDistancePopup(function()
        assertEqual(cardNames(), "Near,Far,Nowhere,Elsewhere")
        local cards = TP.Cards()
        assertEqual(cards[1].dist:GetText(), NS.L["%d yd"]:format(20), "Near: 20 yards")
        assertEqual(cards[2].dist:GetText(), NS.L["%d yd"]:format(552), "Far: about 552 yards")
        assertEqual(cards[3].dist:GetText(), "", "no coordinates: no distance")
        assertEqual(cards[4].dist:GetText(), "", "another continent: no distance")
        assertEqual(TP.Selected().name, "Near", "the nearest is selected")
    end)
end)

test("round5 distance: the popup re-measures once a second while shown, keeps the selection, and stops on hide", function()
    withDistancePopup(function()
        assertTrue(TP.Ticking(), "the re-measure runs while shown")
        TP.Select(1)   -- Near
        M.__map.player = { mapID = 1453, x = 0.5, y = 0.52 }
        M.__fireTimers()
        assertEqual(cardNames(), "Far,Near,Nowhere,Elsewhere", "the player walked to Far")
        assertEqual(TP.Selected().name, "Near", "the selected trainer stays selected")
        assertEqual(TP.Cards()[1].dist:GetText(), NS.L["%d yd"]:format(20))
        TP.Hide()
        assertFalse(TP.Ticking(), "hidden: the re-measure stops")
        M.__map.player = { mapID = 1453, x = 0.1, y = 0.12 }
        M.__fireTimers()
        assertEqual(cardNames(), "Far,Near,Nowhere,Elsewhere", "no re-sort while hidden")
    end)
end)

test("round5 distance: a secret or missing player position shows no distance and keeps the data's order", function()
    withDistancePopup(function()
        TP.Hide()
        M.__map.player = nil
        TP.Show("staves")
        assertEqual(cardNames(), "Far,Nowhere,Near,Elsewhere", "no position: the data's order")
        for _, c in ipairs(TP.Cards()) do assertEqual(c.dist:GetText(), "") end
        TP.Hide()
        mapModel()
        local restore = T.kit.installSecretValue()
        M.C_Map.GetBestMapForUnit = function() return T.kit.secret(1453) end
        local ok, err = pcall(TP.Show, "staves")
        restore()
        assertTrue(ok, "a secret map must not raise: " .. tostring(err))
        assertEqual(cardNames(), "Far,Nowhere,Near,Elsewhere")
    end)
end)

test("round5 distance: Escape (the frame's own hide) stops the re-measure too", function()
    withDistancePopup(function()
        assertTrue(TP.Ticking())
        local onHide = TP.Frame():GetScript("OnHide")
        assertTrue(type(onHide) == "function", "the frame stops it on hide")
        onHide(TP.Frame())
        assertFalse(TP.Ticking(), "stopped")
    end)
end)

-- ── R5-11..R5-13: the Rows page ─────────────────────────────────────────────────────────────

local function aceGUI() return M.__libs["AceGUI-3.0"] end

local function createdOf(from, wtype)
    local out = {}
    local list = aceGUI().__created
    for i = from + 1, #list do
        local w = list[i]
        if w.type == wtype and not w.__released then out[#out + 1] = w end
    end
    return out
end

-- Every live widget drawn after `from` of the given types, in creation order.
local function drawn(from, types)
    local out = {}
    local list = aceGUI().__created
    for i = from + 1, #list do
        local w = list[i]
        if types[w.type] and not w.__released then out[#out + 1] = w end
    end
    return out
end

local function showRowsPage()
    local panel = M.__subcategories[NS.L["Rows"]]
    assertTrue(panel ~= nil, "the Rows page is registered")
    local from = #aceGUI().__created
    panel:Show()
    panel:__fire("OnShow")
    M.__fireTimers()
    return panel, from
end

local function hidePanel(panel)
    panel:Hide()
    panel:__fire("OnHide")
    M.__fireTimers()
end

local function clearHidden()
    NS.db.profile.skills.hidden, NS.db.profile.stats.hidden = {}, {}
    NS.db.profile.broker.tooltip.hiddenSkills, NS.db.profile.broker.tooltip.hiddenStats = {}, {}
end

test("round5 rows: the Stats page is gone (its General tab drew nothing) and the Rows page holds every hide row", function()
    -- red under: the Stats page still registered, or a hide row left on the Skills, Stats or Broker page
    assertTrue(M.__subcategories[NS.L["Stats"]] == nil, "no Stats page")
    assertTrue(M.__subcategories[NS.L["Rows"]] ~= nil, "a Rows page")
    local onRows = {}
    for _, row in ipairs(NS.Schema) do
        assertTrue(row.page ~= "stats", "no row on the old Stats page: " .. tostring(row.path))
        local hide = row.path:find("^skills%.hidden") or row.path:find("^stats%.hidden")
            or row.path:find("^broker%.tooltip%.hidden")
        if hide then
            assertEqual(row.page, "rows", row.path .. " is on the Rows page")
            onRows[row.path] = true
        end
    end
    for key in pairs(NS.SkillCatalog) do
        assertTrue(onRows["skills.hidden." .. key], "window row for " .. key)
        assertTrue(onRows["broker.tooltip.hiddenSkills." .. key], "tooltip row for " .. key)
    end
    for _, def in ipairs(NS.STAT_DEFS) do
        assertTrue(onRows["stats.hidden." .. def.key], "window row for " .. def.key)
        assertTrue(onRows["broker.tooltip.hiddenStats." .. def.key], "tooltip row for " .. def.key)
    end
    for _, setPath in ipairs({ "skills.hidden", "stats.hidden", "broker.tooltip.hiddenSkills", "broker.tooltip.hiddenStats" }) do
        assertTrue(onRows[setPath], "the whole-set row " .. setPath)
    end
    local skills = NS.SchemaForPage("skills")
    assertEqual(#skills, 3, "the Skills page keeps its three switches")
end)

test("round5 rows: the groups follow the window's block order, skills by category, stats by group", function()
    local groups = NS.OptionsRows.Groups()
    local ordered = NS.Blocks.Ordered()
    assertEqual(#groups, #ordered, "one group per block")
    for i, id in ipairs(ordered) do
        assertEqual(groups[i].id, id)
        assertEqual(groups[i].title, NS.BlockDefs[id].title)
    end
    local primary = groups[1]
    assertEqual(primary.id, "primary")
    local seen = {}
    for _, r in ipairs(primary.rows) do
        seen[r.key] = r
        assertEqual(NS.SkillCatalog[r.key].category, "primary", r.key .. " is a primary profession")
    end
    local lw = seen.leatherworking
    assertTrue(lw ~= nil, "Leatherworking under Primary Professions")
    assertEqual(lw.windowPath, "skills.hidden.leatherworking")
    assertEqual(lw.tipPath, "broker.tooltip.hiddenSkills.leatherworking")
    assertEqual(lw.icon, NS.Rows.Icon("skill", "leatherworking"))
    local base
    for _, g in ipairs(groups) do if g.id == "stats_base" then base = g end end
    assertTrue(base ~= nil and #base.rows > 0, "the Base & Combat stats")
    assertEqual(base.rows[1].windowPath, "stats.hidden." .. base.rows[1].key)
    assertEqual(base.rows[1].tipPath, "broker.tooltip.hiddenStats." .. base.rows[1].key)
    local total = 0
    for _, g in ipairs(groups) do total = total + #g.rows end
    local n = #NS.STAT_DEFS
    for _ in pairs(NS.SkillCatalog) do n = n + 1 end
    assertEqual(total, n, "every skill and stat once")
end)

test("round5 rows: the page draws a column header, a heading per group and two eyes per row", function()
    clearHidden()
    local panel, from = showRowsPage()
    local ok, err = pcall(function()
    local captions = {}
    for _, c in ipairs(createdOf(from, "SkillMasterListCaption")) do
        if c.text ~= "" then captions[#captions + 1] = c end
    end
    assertEqual(#captions, 2, "two column captions")
    assertEqual(captions[1].text, NS.L["Window"])
    assertEqual(captions[2].text, NS.L["LDB tooltip"])
    local headings = createdOf(from, "SkillMasterListHeading")
    local groups = NS.OptionsRows.Groups()
    assertEqual(#headings, #groups, "a heading per group")
    for i, g in ipairs(groups) do assertEqual(headings[i].text, g.title) end
    -- Per row: its label, then its window eye, then its tooltip eye.
    local seq = drawn(from, { SkillMasterListLabel = true, Icon = true })
    local lwAt
    for i, w in ipairs(seq) do
        if w.type == "SkillMasterListLabel" and w.text == NS.L["Leatherworking"] then lwAt = i end
    end
    assertTrue(lwAt ~= nil, "Leatherworking has a row")
    local winEye, tipEye = seq[lwAt + 1], seq[lwAt + 2]
    assertEqual(winEye.type, "Icon")
    assertEqual(tipEye.type, "Icon")
    assertEqual(winEye.image[1], NS.Icon("eye"))
    winEye.callbacks.OnClick()
    M.__fireTimers()
    assertTrue(NS.db.profile.skills.hidden.leatherworking == true, "the window eye writes skills.hidden")
    assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.leatherworking == nil, "and not the tooltip's")
    tipEye.callbacks.OnClick()
    M.__fireTimers()
    assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.leatherworking == true, "the tooltip eye writes its own set")
    end)
    clearHidden()
    hidePanel(panel)
    if not ok then error(err, 0) end
end)

test("round5 rows: a group heading's eyes show that group's hidden rows again, one column each", function()
    -- red under: no show-all eye on a heading, or one that reaches another group or the other column
    clearHidden()
    NS.SetByPath("skills.hidden.axes", true)
    NS.SetByPath("skills.hidden.bows", true)
    NS.SetByPath("broker.tooltip.hiddenSkills.guns", true)
    NS.SetByPath("skills.hidden.fishing", true)   -- another group's
    local panel, from = showRowsPage()
    local function weaponMarks(since)
        local seq = drawn(since, { SkillMasterListHeading = true, Icon = true })
        for i, w in ipairs(seq) do
            if w.type == "SkillMasterListHeading" and w.text == NS.BlockDefs.weapon.title then
                return seq[i + 1], seq[i + 2]
            end
        end
    end
    local ok, err = pcall(function()
        local showWin = weaponMarks(from)
        assertTrue(showWin ~= nil and showWin.type == "Icon", "the Weapon Skills heading's window eye")
        from = #aceGUI().__created
        showWin.callbacks.OnClick()
        M.__fireTimers()
        assertTrue(NS.db.profile.skills.hidden.axes == nil and NS.db.profile.skills.hidden.bows == nil, "both shown")
        assertTrue(NS.db.profile.skills.hidden.fishing == true, "another group's row stays hidden")
        assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.guns == true, "the tooltip column is apart")
        local _, showTip = weaponMarks(from)
        assertTrue(showTip ~= nil and showTip.type == "Icon", "the page drew again, the tooltip eye with it")
        showTip.callbacks.OnClick()
        M.__fireTimers()
        assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.guns == nil, "the tooltip's eye shows Guns again")
    end)
    clearHidden()
    hidePanel(panel)
    if not ok then error(err, 0) end
end)

test("round5 rows: a hide written while the page is hidden (the row menu) redraws it on its next show", function()
    -- red under: the page drawn once and shown again with the eyes it had
    clearHidden()
    local panel = showRowsPage()
    hidePanel(panel)
    NS.SetByPath("broker.tooltip.hiddenStats.speed", true)
    local from
    panel, from = showRowsPage()
    local labels = createdOf(from, "SkillMasterListLabel")
    hidePanel(panel)
    clearHidden()
    assertTrue(#labels > 0, "the page drew again")
end)

test("round5 rows: the Rows page's Defaults restores both hidden sets; the Skills and Broker pages' leave them", function()
    clearHidden()
    NS.SetByPath("skills.hidden.axes", true)
    NS.SetByPath("stats.hidden.agility", true)
    NS.SetByPath("broker.tooltip.hiddenSkills.bows", true)
    NS.SetByPath("broker.tooltip.hiddenStats.speed", true)
    NS.db.profile.skills.hidden["other:Jewelcrafting"] = true   -- a key with no row of its own
    NS.Helpers.RestoreDefaults("skills")
    NS.Helpers.RestoreDefaults("broker")
    M.__fireTimers()
    assertTrue(NS.db.profile.skills.hidden.axes == true, "Skills' Defaults leaves the hidden rows")
    assertTrue(NS.db.profile.broker.tooltip.hiddenSkills.bows == true, "Broker's too")
    NS.Helpers.RestoreDefaults("rows")
    M.__fireTimers()
    assertTrue(next(NS.db.profile.skills.hidden) == nil, "every window-hidden skill shown")
    assertTrue(next(NS.db.profile.stats.hidden) == nil, "every window-hidden stat")
    assertTrue(next(NS.db.profile.broker.tooltip.hiddenSkills) == nil, "every tooltip-hidden skill")
    assertTrue(next(NS.db.profile.broker.tooltip.hiddenStats) == nil, "every tooltip-hidden stat")
    clearHidden()
end)

-- ── The R5-followups review (2026-11-13) ────────────────────────────────────────────────────

test("round5 review: a UIParent hide and show (Alt+Z, a cinematic) restarts the popup's re-measure", function()
    -- red under: only P.Show starts the ticker, so OnHide's stop outlives the implicit show
    withDistancePopup(function()
        local f = TP.Frame()
        f:GetScript("OnHide")(f)   -- UIParent hid: the popup's OnHide runs, it stays IsShown()
        assertFalse(TP.Ticking(), "the implicit hide stops it")
        local onShow = f:GetScript("OnShow")
        assertTrue(type(onShow) == "function", "the frame restarts it on show")
        onShow(f)
        assertTrue(TP.Ticking(), "running again once UIParent shows")
        M.__map.player = { mapID = 1453, x = 0.5, y = 0.52 }
        M.__fireTimers()
        assertEqual(cardNames(), "Far,Near,Nowhere,Elsewhere", "the order follows the player again")
    end)
end)

test("round5 review: a block its filter emptied is content, so the window's empty message stays hidden", function()
    -- red under: plan() counting only entries, so the centered message drew over the header
    withWeapons(function()
        wield(nil)
        set("layout.blocks.weapon.filter", "equipped")
        M.__fireTimers()
        assertTrue(header("weapon") ~= nil, "the weapon header and its note are laid out")
        assertEqual(#W.Rows(), 0, "no row anywhere")
        assertFalse(W.Frame().empty:IsShown(), "no 'No skills to show yet.' over the header")
    end)
end)

local function headingsSince(from)
    local out = {}
    for _, h in ipairs(createdOf(from, "SkillMasterListHeading")) do out[#out + 1] = h.text end
    return out
end

test("round5 review: a hide written elsewhere while the Rows page is on screen redraws it; a show-all draws once", function()
    -- red under: stale() skipping the refresh while the page is shown
    clearHidden()
    local panel = showRowsPage()
    local ok, err = pcall(function()
        local from = #aceGUI().__created
        NS.SetByPath("skills.hidden.axes", true)   -- the row menu's Hide, `/sm set`
        M.__fireTimers()
        assertTrue(#headingsSince(from) > 0, "the shown page drew again")
        from = #aceGUI().__created
        NS.SetByPath("skills.hidden.bows", true)
        M.__fireTimers()
        local seq = drawn(from, { SkillMasterListHeading = true, Icon = true })
        local showWin
        for i, w in ipairs(seq) do
            if w.type == "SkillMasterListHeading" and w.text == NS.BlockDefs.weapon.title then showWin = seq[i + 1] end
        end
        assertTrue(showWin ~= nil, "the Weapon Skills heading's window eye")
        from = #aceGUI().__created
        showWin.callbacks.OnClick()
        M.__fireTimers()
        assertEqual(#headingsSince(from), #NS.OptionsRows.Groups(), "one render for the whole show-all")
    end)
    clearHidden()
    hidePanel(panel)
    if not ok then error(err, 0) end
end)

test("round5 review: a block reorder redraws the Rows page in the new order, shown or hidden", function()
    -- red under: nothing marking the page stale on a reorder
    clearHidden()
    local function indexOf(id)
        for i, b in ipairs(NS.Blocks.Ordered()) do if b == id then return i end end
    end
    local was = indexOf("weapon")
    local panel = showRowsPage()
    hidePanel(panel)
    local ok, err = pcall(function()
        NS.Blocks:Move(was, 1)
        M.__fireTimers()
        local from
        panel, from = showRowsPage()
        assertEqual(headingsSince(from)[1], NS.BlockDefs.weapon.title, "hidden: the next show draws the new order")
        from = #aceGUI().__created
        NS.Blocks:Move(1, was)
        M.__fireTimers()
        assertEqual(headingsSince(from)[1], NS.BlockDefs[NS.Blocks.Ordered()[1]].title, "shown: drawn again at once")
        assertTrue(NS.Blocks.Ordered()[1] ~= "weapon", "back in place")
    end)
    if indexOf("weapon") ~= was then NS.Blocks:Move(indexOf("weapon"), was) end
    hidePanel(panel)
    if not ok then error(err, 0) end
end)
