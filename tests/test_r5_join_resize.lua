-- tests/test_r5_join_resize.lua — R5-SM-08 (owner feedback round 5, addendum A1, Ka0sAddonsCommonTasks
-- docs/2026-11-26-OWNER_FEEDBACK_ROUND5/A1_CHARACTERLEDGER_MORE.md): "Detached windows, when joined, are no longer
-- resizable." A merged window carries the same corner grip as a detached one: it sets the window's column
-- width (layout.groups[gid].width, inside a block's 200..600 on the same step), the drop point kept, hidden
-- while locked. Unmerged, each block keeps its own width.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D, G = NS.Detached, NS.Groups

local function spySize(f)
    rawset(f, "SetWidth", function(self, v) rawset(self, "__w", v) end)
    rawset(f, "SetHeight", function(self, v) rawset(self, "__h", v) end)
    return f
end

-- Primary and Reputations detached and merged side by side (the owner's screenshot 28 stacks them; a
-- left/right merge makes two columns, so the grip's per-column width is tested too). `fn(gid, frame)`.
local function withMerged(side, fn)
    local b = NS.db.profile.layout.blocks
    local saved = { primary = b.primary.width, reputations = b.reputations.width }
    b.primary.docked, b.reputations.docked = false, false
    b.primary.width, b.reputations.width = 300, 360
    D.Refresh()
    local gid = G.Merge("reputations", "primary", side)
    M.__fireTimers()
    local f = spySize(G.Frame(gid))
    G.Render(gid)
    local ok, err = pcall(fn, gid, f)
    rawset(f, "SetWidth", nil)
    rawset(f, "SetHeight", nil)
    b.primary.docked, b.reputations.docked = true, true
    b.primary.width, b.reputations.width = saved.primary, saved.reputations
    NS.db.profile.layout.groups = {}
    NS.SetByPath("locked", false)
    D.Refresh()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

test("r5 sm-08: a merged window has a shown resize grip, its bounds per column at the content's height", function()
    withMerged("bottom", function(_, f)
        local grip = f.resizeGrip
        assertTrue(grip ~= nil, "a merged window carries a resize grip")
        assertTrue(grip:IsShown(), "shown while unlocked")
        local minW, minH, maxW, maxH = f:GetResizeBounds()
        assertEqual(minW, D.MIN_WIDTH, "one column: a block's minimum")
        assertEqual(maxW, D.MAX_WIDTH, "one column: a block's maximum")
        assertTrue(f.__h ~= nil and f.__h > 0, "the content's height")
        assertEqual(minH, f.__h, "the height is the content's")
        assertEqual(maxH, f.__h, "and the grip never changes it")
    end)
    withMerged("right", function(_, f)
        local minW, _, maxW = f:GetResizeBounds()
        assertEqual(minW, 2 * D.MIN_WIDTH, "two columns: twice the minimum")
        assertEqual(maxW, 2 * D.MAX_WIDTH, "two columns: twice the maximum")
    end)
end)

test("r5 sm-08: a drag on the grip sets the column width, snapped, and keeps the drop point", function()
    withMerged("right", function(gid, f)
        assertEqual(f.__w, 2 * 360, "before: two columns of the widest member's width")
        local grip = f.resizeGrip
        rawset(f, "GetLeft", function() return 300 end)
        rawset(f, "GetTop", function() return 700 end)
        rawset(f, "GetRight", function() return 300 + 2 * 360 end)
        rawset(f, "GetBottom", function() return 400 end)
        rawset(f, "GetPoint", function() return "TOPLEFT", M.UIParent, "BOTTOMLEFT", 300, 700 end)
        grip:__fire("OnMouseDown", "LeftButton")
        f:__setGeom(903, f.__h)
        f:__fire("OnSizeChanged", 903, f.__h)
        f.resizeDriver:__fire("OnUpdate", 0.016)
        assertEqual(NS.db.profile.layout.groups[gid].width, nil, "nothing is written while dragging")
        grip:__fire("OnMouseUp", "LeftButton")
        M.__fireTimers()
        for _, k in ipairs({ "GetLeft", "GetTop", "GetRight", "GetBottom", "GetPoint" }) do rawset(f, k, nil) end
        f.__geomLive = nil
        assertEqual(NS.db.profile.layout.groups[gid].width, 450, "the release stores 903 / 2, snapped to 10")
        assertEqual(G.Width(gid), 450, "the window's column width reads it")
        local p = NS.db.profile.layout.groups[gid].point
        assertTrue(type(p) == "table" and p.point == "TOPLEFT", "the drop point is kept")
        G.Render(gid)
        assertEqual(f.__w, 900, "the window redraws at two columns of 450")
        -- The members' own widths are untouched: unmerged, each keeps its own.
        assertEqual(NS.db.profile.layout.blocks.primary.width, 300, "Primary keeps its own width")
        assertEqual(NS.db.profile.layout.blocks.reputations.width, 360, "Reputations keeps its own width")
        G.Unmerge(gid)
        M.__fireTimers()
        assertEqual(D.Width("primary"), 300, "unmerged, Primary is its own width again")
        assertEqual(D.Width("reputations"), 360, "and Reputations its own")
        assertTrue(D.Frame("primary").resizeGrip:IsShown(), "each detached window has its own grip")
    end)
end)

test("r5 sm-08: Locked hides a merged window's grip and refuses a grab", function()
    withMerged("bottom", function(gid, f)
        local grip = f.resizeGrip
        NS.SetByPath("locked", true)
        M.__fireTimers()
        assertFalse(grip:IsShown(), "the global lock hides it")
        local before = f.__sizingCount or 0
        grip:__fire("OnMouseDown", "LeftButton")
        assertEqual(f.__sizingCount or 0, before, "and a grab does not size the window")
        grip:__fire("OnMouseUp", "LeftButton")
        assertEqual(NS.db.profile.layout.groups[gid].width, nil, "nothing stored")
        NS.SetByPath("locked", false)
        M.__fireTimers()
        assertTrue(grip:IsShown(), "unlocked: shown again")
    end)
end)

test("r5 sm-08: a stored column width out of range is clamped, a malformed one dropped", function()
    local groups = { g1 = { point = false, width = 9000, columns = { { "primary", "other" } } },
                     g2 = { point = false, width = "wide", columns = { { "weapon", "secondary" } } } }
    G.Model.Normalize(groups)
    assertEqual(groups.g1.width, D.MAX_WIDTH, "clamped to a block's maximum")
    assertEqual(groups.g2.width, nil, "a non-number goes")
end)

test("r5 sm-08: migration 17 cleans a stored group's column width", function()
    local sv = rawget(_G, "CharacterLedgerDB")
    sv.profiles = sv.profiles or {}
    sv.profiles["R5-Join"] = { layout = {
        blocks = { primary = { docked = false }, other = { docked = false } },
        groups = { g1 = { point = false, width = 50, columns = { { "primary", "other" } } } },
    } }
    NS.db.global.schemaVersion = 16
    NS:RunMigrations()
    assertEqual(NS.db.global.schemaVersion, NS.SCHEMA_VERSION)
    assertEqual(sv.profiles["R5-Join"].layout.groups.g1.width, D.MIN_WIDTH, "clamped up to a block's minimum")
    sv.profiles["R5-Join"] = nil
end)
