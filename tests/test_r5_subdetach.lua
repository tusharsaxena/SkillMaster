-- tests/test_r5_subdetach.lua — R5-SM-09 (owner feedback round 5, addendum A1, Ka0sAddonsCommonTasks
-- docs/2026-11-26-OWNER_FEEDBACK_ROUND5/A1_SKILLMASTER_MORE.md): "Allow detaching sub categories (e.g. Alliance,
-- Other here). Or any of the nested sub categories here [Statistics]. or sub categories here [Currencies]." Every
-- tree header carries the block header's detach mark; a detached sub-category is its own window drawn as a
-- detached block (moves, joins, resizes, remembers its place and collapse, survives /reload), its rows the
-- header's subtree, and it leaves the window it came from while detached. Its key is stable: the faction
-- header's id, the Statistics categoryID, the currency header's name. Test mode's sample fills every tree.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local SB, D, G = NS.SubBlocks, NS.Detached, NS.Groups

local LABELS = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

--- `fn` with test mode on and no sub-category detached; everything put back after.
local function withSample(fn)
    local saved = { M.GetText, M.UnitSex, M.UnitFactionGroup }
    M.GetText = function(key) return LABELS[tonumber(tostring(key):match("(%d+)$"))] end
    M.UnitSex = function() return 2 end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    local layout = NS.db.profile.layout
    layout.subs, layout.groups = {}, {}
    if not NS.IsTestMode() then NS.ToggleTestMode() end
    M.__fireTimers()
    for _, fid in ipairs({ "currencies", "reputations", "statistics" }) do
        local store = NS.Tree.Store(fid)
        for k in pairs(store) do store[k] = nil end
    end
    local ok, err = pcall(fn)
    layout.subs, layout.groups = {}, {}
    NS.db.profile.layout.blocks.primary.docked = true
    NS.Windows.HideAll()
    D.Refresh()
    if NS.IsTestMode() then NS.ToggleTestMode() end
    M.GetText, M.UnitSex, M.UnitFactionGroup = saved[1], saved[2], saved[3]
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function shownWindow(fid)
    local W = NS.Windows.Get(fid)
    W.Show()
    W.Refresh(true)
    return W
end

local function names(rows)
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = row.entry and row.entry.name or "?" end
    return table.concat(out, ",")
end

local function headerRow(W, name)
    for _, row in ipairs(W.Rows()) do
        if row.treeHeader and row.entry.name == name then return row end
    end
end

test("r5 sm-09: every tree header in the Reputations, Currencies and Statistics windows has a detach mark", function()
    withSample(function()
        for _, fid in ipairs({ "reputations", "currencies", "statistics" }) do
            local W = shownWindow(fid)
            local n = 0
            for _, row in ipairs(W.Rows()) do
                if row.treeHeader then
                    n = n + 1
                    assertTrue(row.subDetach ~= nil and row.subDetach:IsShown(), fid .. ": " .. row.entry.name .. " has one")
                elseif row.subDetach then
                    assertFalse(row.subDetach:IsShown(), fid .. ": a leaf row has none")
                end
            end
            assertTrue(n > 0, fid .. ": a header drawn")
        end
    end)
end)

test("r5 sm-09: detaching Alliance makes its own window of its factions and takes it out of Reputations", function()
    withSample(function()
        local W = shownWindow("reputations")
        local before = names(W.Rows())
        assertTrue(before:find("Alliance,Ironforge", 1, true) ~= nil, "Alliance and its factions listed first")
        headerRow(W, "Alliance").subDetach:__fire("OnClick", "LeftButton")
        M.__fireTimers()
        local id = SB.Id("reputations", "469")
        assertEqual(id, "sub:reputations:469", "keyed by the header's factionID")
        local s = NS.db.profile.layout.subs[id]
        assertTrue(type(s) == "table" and s.docked == false, "stored as detached")
        local f = D.Frame(id)
        assertTrue(f ~= nil and f:IsShown(), "its own window shows")
        assertEqual(f.title:GetText(), "Alliance", "titled by the header")
        assertEqual(names(D.Rows(id)), "Ironforge,Stormwind,Gnomeregan Exiles,Darnassus", "its factions, nothing else")
        assertEqual(D.Rows(id)[1].tree.depth, 0, "drawn from depth 0")
        W.Refresh(true)
        local after = names(W.Rows())
        assertTrue(after:find("Alliance", 1, true) == nil, "Alliance left the Reputations window")
        assertTrue(after:find("Ironforge", 1, true) == nil, "and its factions with it")
        assertTrue(after:find("Steamwheedle Cartel,Booty Bay", 1, true) ~= nil, "the other headers stay")
    end)
end)

test("r5 sm-09: docking a sub-category puts it back where it was and forgets its row", function()
    withSample(function()
        local W = shownWindow("reputations")
        local id = SB.Detach("reputations", "169", "Steamwheedle Cartel")
        M.__fireTimers()
        assertTrue(D.Frame(id):IsShown(), "detached")
        D.Frame(id).dock:__fire("OnClick", "LeftButton")
        M.__fireTimers()
        assertEqual(NS.db.profile.layout.subs[id], nil, "its row goes")
        assertFalse(D.Frame(id):IsShown(), "its window hides")
        W.Refresh(true)
        assertTrue(names(W.Rows()):find("Steamwheedle Cartel,Booty Bay", 1, true) ~= nil, "back in its place")
    end)
end)

test("r5 sm-09: a nested Statistics category detaches, read whatever the window's folds say", function()
    withSample(function()
        local W = shownWindow("statistics")
        assertTrue(NS.Tree.IsFolded("statistics", "130"), "Character starts folded")
        local id = SB.Detach("statistics", "140", "Wealth")
        M.__fireTimers()
        assertEqual(id, "sub:statistics:140", "keyed by the categoryID")
        assertEqual(names(D.Rows(id)), "Total gold acquired,Auctions posted", "Wealth's own rows")
        NS.Tree.SetFolded("statistics", "130", false)
        M.__fireTimers()
        W.Refresh(true)
        local rows = names(W.Rows())
        assertTrue(rows:find("Times camped", 1, true) ~= nil, "Character open in the window")
        assertTrue(rows:find("Wealth", 1, true) == nil, "without Wealth")
        assertTrue(rows:find("Consumables", 1, true) ~= nil, "its sibling stays")
        -- A top category detaches too, and its own window leaves out the nested one already detached.
        local top = SB.Detach("statistics", "130", "Character")
        M.__fireTimers()
        local inTop = names(D.Rows(top))
        assertTrue(inTop:find("Times camped", 1, true) ~= nil, "Character's window has its rows")
        assertTrue(inTop:find("Consumables", 1, true) ~= nil, "and Consumables")
        assertTrue(inTop:find("Wealth", 1, true) == nil, "but not Wealth, detached on its own")
    end)
end)

test("r5 sm-09: a currency header detaches, keyed by its name", function()
    withSample(function()
        local W = shownWindow("currencies")
        headerRow(W, "Player vs. Player").subDetach:__fire("OnClick", "LeftButton")
        M.__fireTimers()
        local id = SB.Id("currencies", "Player vs. Player#0")
        assertTrue(NS.db.profile.layout.subs[id] ~= nil, "stored under the header's name")
        assertEqual(names(D.Rows(id)), "Honor Points", "its currency")
        W.Refresh(true)
        assertTrue(names(W.Rows()):find("Honor Points", 1, true) == nil, "gone from the Currencies window")
    end)
end)

test("r5 sm-09: a detached sub-category collapses, resizes, joins a block and survives a reload", function()
    withSample(function()
        local id = SB.Detach("reputations", "469", "Alliance")
        M.__fireTimers()
        local f = D.Frame(id)
        f.collapse:__fire("OnClick", "LeftButton")
        M.__fireTimers()
        assertTrue(NS.db.profile.layout.subs[id].collapsed, "its collapse is stored")
        assertEqual(#D.Rows(id), 0, "collapsed: no rows")
        f.collapse:__fire("OnClick", "LeftButton")
        M.__fireTimers()
        -- The grip's release writes its own width (no schema row for a sub-category).
        rawset(f, "GetPoint", function() return "TOPLEFT", M.UIParent, "BOTTOMLEFT", 50, 600 end)
        f.resizeGrip:__fire("OnMouseDown", "LeftButton")
        f:__setGeom(333, 100)
        f:__fire("OnSizeChanged", 333, 100)
        f.resizeGrip:__fire("OnMouseUp", "LeftButton")
        M.__fireTimers()
        rawset(f, "GetPoint", nil)
        f.__geomLive = nil
        assertEqual(NS.db.profile.layout.subs[id].width, 330, "its width, snapped")
        assertTrue(type(NS.db.profile.layout.subs[id].point) == "table", "and its drop point")
        -- Joined with a detached block.
        NS.db.profile.layout.blocks.primary.docked = false
        D.Refresh()
        local gid = G.Merge(id, "primary", "bottom")
        M.__fireTimers()
        assertTrue(gid ~= nil, "merged")
        assertEqual(G.Title(gid), "Primary \194\183 Alliance", "the merged window names it")
        assertFalse(D.Frame(id):IsShown(), "its own frame hides in the group")
        local inGroup = names(G.Rows(gid))
        assertTrue(inGroup:find("Ironforge", 1, true) ~= nil, "its rows draw in the merged window")
        -- A reload: every frame gone, the stored rows drawn again.
        G.Unmerge(gid)
        M.__fireTimers()
        D.StandDown()
        D.Refresh()
        assertTrue(D.Frame(id):IsShown(), "back after the reload")
        assertEqual(names(D.Rows(id)), "Ironforge,Stormwind,Gnomeregan Exiles,Darnassus", "with its rows")
    end)
end)

test("r5 sm-09: the LDB tooltip keeps the whole tree and shows no detach mark", function()
    withSample(function()
        SB.Detach("reputations", "469", "Alliance")
        M.__fireTimers()
        NS.Broker.OnEnter(M.UIParent, "reputations")
        local rows = NS.BrokerPanel.Rows()
        local seen = false
        for _, row in ipairs(rows) do
            if row.entry and row.entry.name == "Ironforge" then seen = true end
            if row.subDetach then assertFalse(row.subDetach:IsShown(), "no detach mark in the tooltip") end
        end
        assertTrue(seen, "Alliance's factions still in the feed's tooltip")
        NS.Broker.HideTooltip()
        NS.Broker.SetFeed(NS.Broker.DEFAULT_FEED)
    end)
end)

test("r5 sm-09: the model normalizes a stored row and refuses what is no tree header", function()
    local subs = { ["sub:reputations:469"] = { docked = true, name = 5, width = 9000, collapsed = "yes" },
                   ["sub:primary:1"] = { docked = false }, ["sub:statistics:140"] = "bad", other = {} }
    SB.Normalize(subs)
    local s = subs["sub:reputations:469"]
    assertTrue(s ~= nil and s.docked == false, "a kept row is detached")
    assertEqual(s.name, nil, "a non-string name goes")
    assertEqual(s.width, D.MAX_WIDTH, "a width is clamped")
    assertEqual(s.collapsed, false, "a collapse is a boolean")
    assertEqual(subs["sub:primary:1"], nil, "a block that is no tree family goes")
    assertEqual(subs["sub:statistics:140"], nil, "a row that is no table goes")
    assertEqual(subs.other, nil, "an id that is no sub-category's goes")
    assertEqual(SB.Detach("skills", "x"), nil, "a non-tree family detaches nothing")
end)

test("r5 sm-09: schemaVersion 18 normalizes a stored layout.subs and drops one that is no table", function()
    local sv = rawget(_G, "SkillMasterDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R5-Subs"] = { layout = { subs = { ["sub:reputations:469"] = { point = 3 }, junk = 1 } } }
    sv.profiles["R5-SubsBad"] = { layout = { subs = "nope" } }
    NS.db.global.schemaVersion = 17
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    local subs = sv.profiles["R5-Subs"].layout.subs
    assertTrue(subs["sub:reputations:469"] ~= nil and subs["sub:reputations:469"].point == false, "a kept row cleaned")
    assertEqual(subs.junk, nil, "junk goes")
    assertEqual(sv.profiles["R5-SubsBad"].layout.subs, nil, "a non-table goes")
    sv.profiles["R5-Subs"], sv.profiles["R5-SubsBad"] = nil, nil
end)
