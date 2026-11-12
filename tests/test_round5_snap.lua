-- tests/test_round5_snap.lua — the owner's round-5 feedback (2026-11-13), R5-6b: the drags of the
-- merged detached windows (modules/GroupsSnap.lua). The pure snap core on plain rects (all four
-- sides, the radius's edge, the overlap it needs, the nearest winning, a window never its own
-- target, the column a top or bottom drop stacks into), the leeway's classify, then simulated drags
-- on the mock frames: a detached window dropped on another's side merges there, a left-side drop
-- makes a second column, a drop with no candidate is a plain move, a merged window dragged whole, a
-- section dragged out past the leeway splits off at its drop and held inside it changes nothing, a
-- section dragged onto another window merges there, the locks and combat.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local G, D, S = NS.Groups, NS.Detached, NS.GroupsSnap

local function rect(l, t, w, h) return { left = l, top = t, right = l + w, bottom = t - h } end
local function target(key, l, t, w, h, cols) return { key = key, rect = rect(l, t, w, h), cols = cols } end

local function cols(gid)
    local out = {}
    for c, col in ipairs(G.Columns(gid)) do out[c] = table.concat(col, ",") end
    return table.concat(out, " | ")
end

-- ── the pure core ──────────────────────────────────────────────────────────────────────────

test("round5 snap: each of the four sides is found where the dragged window's facing edge meets it", function()
    local tg = { target("primary", 400, 600, 280, 200) }    -- left 400, right 680, top 600, bottom 400
    local hit = S.Nearest(rect(690, 580, 280, 100), tg)
    assertEqual(hit.key, "primary")
    assertEqual(hit.side, "right", "dragged left edge by the target's right")
    assertEqual(hit.dist, 10)
    assertEqual(S.Nearest(rect(110, 580, 280, 100), tg).side, "left", "dragged right edge by the target's left")
    assertEqual(S.Nearest(rect(420, 710, 280, 100), tg).side, "top", "dragged bottom by the target's top")
    assertEqual(S.Nearest(rect(420, 395, 280, 100), tg).side, "bottom", "dragged top by the target's bottom")
    -- Overlapping the edge counts as near it too (the gap is the absolute distance).
    assertEqual(S.Nearest(rect(670, 580, 280, 100), tg).side, "right", "ten units over the edge")
end)

test("round5 snap: the radius is SNAP_RADIUS, inclusive; one unit past it is no candidate", function()
    assertEqual(S.SNAP_RADIUS, 24, "AuraMaster's radius")
    local tg = { target("primary", 400, 600, 280, 200) }
    local hit = S.Nearest(rect(680 + 24, 580, 280, 100), tg)
    assertTrue(hit ~= nil and hit.side == "right" and hit.dist == 24, "at the radius")
    assertTrue(S.Nearest(rect(680 + 24.01, 580, 280, 100), tg) == nil, "past it")
    assertTrue(S.Nearest(rect(420, 600 + 24 + 100 + 0.5, 280, 100), tg) == nil, "past it above")
end)

test("round5 snap: a side needs the two windows to overlap along the other axis", function()
    local tg = { target("primary", 400, 600, 280, 200) }
    assertTrue(S.Nearest(rect(690, 300, 280, 100), tg) == nil, "beside the right edge but wholly below")
    assertTrue(S.Nearest(rect(690, 500, 280, 100), tg) ~= nil, "beside it, overlapping")
    assertTrue(S.Nearest(rect(690, 400 + 100, 280, 100), tg) ~= nil, "its bottom edge on the target's")
    assertTrue(S.Nearest(rect(690, 400, 280, 100), tg) == nil, "only touching at a corner")
    assertTrue(S.Nearest(rect(100, 700, 280, 100), tg) == nil, "above the top edge but wholly left of it")
    assertTrue(S.Nearest(rect(680, 700, 280, 100), tg) == nil, "above it, touching at a corner")
end)

test("round5 snap: the nearest candidate wins, across targets and across one target's sides", function()
    local tg = { target("primary", 400, 600, 280, 200), target("weapon", 1000, 600, 280, 200) }
    -- 690..970: 10 from primary's right, 30 from weapon's left (outside), so primary.
    assertEqual(S.Nearest(rect(690, 580, 280, 100), tg).key, "primary")
    -- 700..980: 20 from primary's right, 20 from weapon's left: a tie keeps the earlier target.
    assertEqual(S.Nearest(rect(700, 580, 280, 100), tg).key, "primary", "a tie, the earlier target")
    -- 712..992: 32 off primary, 8 off weapon.
    local hit = S.Nearest(rect(712, 580, 280, 100), tg)
    assertEqual(hit.key, "weapon")
    assertEqual(hit.side, "left")
    -- One target, a dragged window by two of its sides: the nearer side.
    local one = { target("primary", 400, 600, 280, 200) }
    hit = S.Nearest(rect(670, 405, 280, 100), one)   -- 10 over the right edge, 5 over the bottom
    assertEqual(hit.side, "bottom", "the nearer side")
end)

test("round5 snap: a window is never its own target, by key or by a set", function()
    local tg = { target("primary", 400, 600, 280, 200), target("g1", 1000, 600, 560, 200, 2) }
    assertTrue(S.Nearest(rect(690, 580, 280, 100), tg, "primary") == nil, "itself excluded")
    assertTrue(S.Nearest(rect(710, 580, 280, 100), tg, { g1 = true }) == nil, "its own group excluded")
    assertEqual(S.Nearest(rect(710, 580, 280, 100), tg, "primary").key, "g1", "another still found")
end)

test("round5 snap: a top or bottom drop on a merged window stacks into the column under its center", function()
    local tg = { target("g1", 400, 600, 560, 200, 2) }
    assertEqual(S.Nearest(rect(400, 395, 280, 100), tg).col, 1, "under the first column")
    assertEqual(S.Nearest(rect(650, 395, 280, 100), tg).col, 2, "its center over the second")
    assertEqual(S.Nearest(rect(900, 395, 280, 100), tg).col, 2, "clamped to the last")
    assertTrue(S.Nearest(rect(970, 580, 280, 100), tg).col == nil, "a side drop has no column")
end)

test("round5 snap: a section inside DETACH_RADIUS holds, past it is out", function()
    assertEqual(S.DETACH_RADIUS, 128, "AuraMaster's leeway")
    assertEqual(S.Classify(0, 0), "hold")
    assertEqual(S.Classify(128, 0), "hold", "at the leeway")
    assertEqual(S.Classify(0, -128.5), "out", "past it")
    assertEqual(S.Classify(90, 90), "hold", "diagonal inside (127.3)")
    assertEqual(S.Classify(91, 91), "out", "diagonal outside (128.7)")
end)

-- ── simulated drags on the mock frames ─────────────────────────────────────────────────────

local IDS = { "primary", "secondary", "weapon", "stats_base" }

-- The frame's rect, answered in UIParent units at scale 1.
local GEOM = { "GetLeft", "GetTop", "GetRight", "GetBottom", "GetEffectiveScale" }
local touched = {}
local function placed(f, l, t, w, h)
    rawset(f, "GetLeft", function() return l end)
    rawset(f, "GetTop", function() return t end)
    rawset(f, "GetRight", function() return l + w end)
    rawset(f, "GetBottom", function() return t - h end)
    rawset(f, "GetEffectiveScale", function() return 1 end)
    touched[#touched + 1] = f
end

-- The four blocks detached, UIParent at scale 1; everything put back afterwards.
local function withDetached(fn)
    local layout = NS.db.profile.layout
    NS.Preview.Apply(true)
    for _, id in ipairs(IDS) do layout.blocks[id].docked = false end
    layout.groups = {}
    D.Refresh()
    placed(M.UIParent, 0, 768, 1024, 768)
    local ok, err = pcall(fn, layout)
    S.Cancel()
    for _, f in ipairs(touched) do for _, k in ipairs(GEOM) do rawset(f, k, nil) end end
    touched = {}
    M.__cursor[1], M.__cursor[2] = 0, 0
    NS.db.profile.locked = false
    layout.groups = {}
    for _, id in ipairs(NS.BLOCKS) do
        layout.blocks[id].docked, layout.blocks[id].collapsed, layout.blocks[id].point = true, false, false
        layout.blocks[id].locked = nil
    end
    layout.blocks.stats_spell.collapsed, layout.blocks.stats_defense.collapsed = true, true
    M.InCombatLockdown = function() return false end
    D.Refresh()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function tick() S.Frame():__fire("OnUpdate", S.THROTTLE + 0.01) end

test("round5 snap: a detached window dragged under another glows its bottom and merges there on the drop", function()
    withDetached(function()
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(tf, 400, 600, D.WIDTH, 200)
        placed(df, 400, 390, D.WIDTH, 120)
        df:__fire("OnDragStart")
        assertTrue(S.Drag() ~= nil and S.Drag().key == "secondary", "the drag is on")
        assertTrue(S.Frame():GetScript("OnUpdate") ~= nil, "the driver armed while dragging")
        tick()
        local glow = S.Glow()
        assertTrue(glow:IsShown(), "the target side glows")
        assertEqual(glow.target, "primary")
        assertEqual(glow.side, "bottom")
        assertEqual(glow.token, "sem.good")
        df:__fire("OnDragStop")
        local gid = G.Of("primary")
        assertTrue(gid ~= nil and G.Of("secondary") == gid, "merged")
        assertEqual(cols(gid), "primary,secondary", "stacked under the target")
        assertFalse(glow:IsShown(), "the glow gone at the drop")
        assertTrue(S.Frame():GetScript("OnUpdate") == nil, "the driver disarmed")
        assertTrue(S.Drag() == nil)
    end)
end)

test("round5 snap: the driver measures at most every THROTTLE seconds", function()
    withDetached(function()
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(tf, 400, 600, D.WIDTH, 200)
        placed(df, 400, 390, D.WIDTH, 120)
        df:__fire("OnDragStart")
        S.Frame():__fire("OnUpdate", S.THROTTLE / 2)
        assertFalse(S.Glow() ~= nil and S.Glow():IsShown(), "not measured before the throttle")
        S.Frame():__fire("OnUpdate", S.THROTTLE / 2 + 0.001)
        assertTrue(S.Glow():IsShown(), "measured once the throttle passed")
        df:__fire("OnDragStop")
    end)
end)

test("round5 snap: a drop left of a window makes a second column, the target kept where it stood", function()
    withDetached(function(layout)
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(tf, 400, 600, D.WIDTH, 200)
        placed(df, 400 - D.WIDTH - 10, 560, D.WIDTH, 120)
        df:__fire("OnDragStart")
        tick()
        assertEqual(S.Glow().side, "left")
        df:__fire("OnDragStop")
        local gid = G.Of("primary")
        assertEqual(cols(gid), "secondary | primary", "a column before the target's")
        local p = layout.groups[gid].point
        assertEqual(p.x, 400 - D.WIDTH, "the target stays where it stood")
        assertEqual(p.y, 600)
    end)
end)

test("round5 snap: a drop with no window near is a plain move", function()
    withDetached(function()
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(tf, 400, 600, D.WIDTH, 200)
        placed(df, 0, 200, D.WIDTH, 120)
        df:__fire("OnDragStart")
        tick()
        assertFalse(S.Glow() ~= nil and S.Glow():IsShown(), "no glow")
        df:__fire("OnDragStop")
        assertTrue(G.Of("secondary") == nil and G.Of("primary") == nil, "nothing merged")
        assertTrue(df:IsShown(), "still its own window")
    end)
end)

test("round5 snap: a merged window dragged by its band merges whole onto a detached window's side", function()
    withDetached(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        local gf, wf = G.Frame(gid), D.Frame("weapon")
        placed(wf, 400, 600, D.WIDTH, 200)
        placed(gf, 690, 590, D.WIDTH, 300)
        gf.band:__fire("OnDragStart")
        assertEqual(S.Drag().key, gid, "the group's drag")
        tick()
        assertEqual(S.Glow().target, "weapon")
        assertEqual(S.Glow().side, "right")
        gf.band:__fire("OnDragStop")
        local into = G.Of("weapon")
        assertTrue(into ~= nil and G.Of("primary") == into and G.Of("secondary") == into, "one group")
        assertEqual(cols(into), "weapon | primary,secondary", "its column beside the target's")
    end)
end)

test("round5 snap: a window dragged over its own group's frame is never merged into it", function()
    withDetached(function()
        local gid = G.Merge("secondary", "primary", "bottom")
        local gf = G.Frame(gid)
        placed(gf, 400, 600, D.WIDTH, 300)
        gf:__fire("OnDragStart")
        tick()
        assertFalse(S.Glow() ~= nil and S.Glow():IsShown(), "its own frame is no target")
        assertEqual(gf:__fire("OnDragStop"), nil)
        assertEqual(cols(gid), "primary,secondary", "unchanged")
    end)
end)

-- A merged window of primary over secondary, its frame and secondary's sub-header placed.
local function mergedPlaced()
    local gid = G.Merge("secondary", "primary", "bottom")
    local gf = G.Frame(gid)
    placed(gf, 400, 600, D.WIDTH, 300)
    local sh = G.Section(gid, "secondary").header
    placed(sh, 400, 450, D.WIDTH, G.SUB_H)
    return gid, gf, sh
end

test("round5 snap: a section dragged inside the leeway holds, edged sem.good, and its release changes nothing", function()
    withDetached(function()
        local gid, _, sh = mergedPlaced()
        M.__cursor[1], M.__cursor[2] = 450, 440
        sh:__fire("OnDragStart")
        assertEqual(S.Drag().kind, "section")
        assertTrue(S.Ghost():IsShown(), "the ghost follows the pointer")
        M.__cursor[1], M.__cursor[2] = 500, 380        -- 78 units off
        tick()
        assertEqual(S.Ghost().token, "sem.good", "inside the leeway")
        assertEqual(sh:__fire("OnDragStop"), nil)
        assertEqual(cols(gid), "primary,secondary", "still merged")
        assertFalse(S.Ghost():IsShown(), "the ghost gone")
    end)
end)

test("round5 snap: a section dragged past the leeway, edged sem.bad, splits off at its drop point", function()
    withDetached(function(layout)
        local gid, _, sh = mergedPlaced()
        M.__cursor[1], M.__cursor[2] = 450, 440        -- 50 in from the sub-header's left, 10 down
        sh:__fire("OnDragStart")
        M.__cursor[1], M.__cursor[2] = 750, 200
        tick()
        assertEqual(S.Ghost().token, "sem.bad", "past the leeway")
        sh:__fire("OnDragStop")
        assertTrue(layout.groups[gid] == nil, "a group of one dissolves")
        assertTrue(G.Of("secondary") == nil, "its own window again")
        local p = layout.blocks.secondary.point
        assertEqual(p.point, "TOPLEFT")
        assertEqual(p.relPoint, "BOTTOMLEFT")
        assertEqual(p.x, 700, "the ghost's left at the drop")
        assertEqual(p.y, 210, "the ghost's top at the drop")
        assertTrue(D.Frame("secondary"):IsShown(), "drawn as its own window")
    end)
end)

test("round5 snap: a section dragged out onto another window's side merges there", function()
    withDetached(function()
        local gid, _, sh = mergedPlaced()
        local wf = D.Frame("weapon")
        placed(wf, 0, 300, D.WIDTH, 150)
        M.__cursor[1], M.__cursor[2] = 450, 440
        sh:__fire("OnDragStart")
        -- The ghost's top-left at (50, 160): 10 under weapon's bottom (150).
        M.__cursor[1], M.__cursor[2] = 100, 150
        tick()
        assertEqual(S.Glow().target, "weapon")
        assertEqual(S.Glow().side, "bottom")
        sh:__fire("OnDragStop")
        assertTrue(G.All()[gid] == nil and G.Of("primary") == nil, "its old group, left with one, dissolved")
        local into = G.Of("weapon")
        assertTrue(into ~= nil and G.Of("secondary") == into, "merged with weapon")
        assertEqual(cols(into), "weapon,secondary")
    end)
end)

test("round5 snap: locked refuses every drag: a window's, a group's and a section's", function()
    withDetached(function(layout)
        local gid, gf, sh = mergedPlaced()
        local df = D.Frame("weapon")
        NS.db.profile.locked = true
        df:__fire("OnDragStart")
        assertTrue(S.Drag() == nil, "a detached window")
        gf.band:__fire("OnDragStart")
        assertTrue(S.Drag() == nil, "a merged window")
        sh:__fire("OnDragStart")
        assertTrue(S.Drag() == nil, "a section")
        NS.db.profile.locked = false
        layout.blocks.primary.locked = true
        sh:__fire("OnDragStart")
        assertTrue(S.Drag() == nil, "a member's own lock holds its whole group")
        layout.blocks.weapon.locked = true
        df:__fire("OnDragStart")
        assertTrue(S.Drag() == nil, "a block's own lock")
        assertEqual(cols(gid), "primary,secondary")
    end)
end)

test("round5 snap: in combat a drop still moves, and the merge it asks for waits for combat's end", function()
    withDetached(function()
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(tf, 400, 600, D.WIDTH, 200)
        placed(df, 400, 390, D.WIDTH, 120)
        M.InCombatLockdown = function() return true end
        df:__fire("OnDragStart")
        assertTrue(S.Drag() ~= nil, "the drag still runs in combat")
        df:__fire("OnDragStop")
        assertTrue(G.Of("primary") == nil, "nothing merged in combat")
        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        local gid = G.Of("primary")
        assertTrue(gid ~= nil and G.Of("secondary") == gid, "merged after combat")
    end)
end)

test("round5 snap: a stand-down mid-drag drops the drag, the driver disarmed and the glow hidden", function()
    withDetached(function()
        local tf, df = D.Frame("primary"), D.Frame("secondary")
        placed(tf, 400, 600, D.WIDTH, 200)
        placed(df, 400, 390, D.WIDTH, 120)
        df:__fire("OnDragStart")
        tick()
        G.StandDown()
        assertTrue(S.Drag() == nil, "no drag")
        assertTrue(S.Frame():GetScript("OnUpdate") == nil, "no OnUpdate left armed")
        assertFalse(S.Glow():IsShown())
        D.Refresh()
    end)
end)
