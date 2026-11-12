-- tests/test_round5_followups.lua — the owner's tasks added to round 5 (2026-11-13), the second
-- workflow. R5-10: the Weapon Skills block's filter mark (All, Learned, Equipped, Below cap) on its
-- header in the main window, in its detached frame and on its merged-window sub-header; the filter
-- persisted per profile through the seam; an emptied block's muted line; Equipped on an equipment change.
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
