-- tests/test_detached_width.lua — FB-SM-04 (the owner's feedback batch, 2026-11-24, S1: "Add options
-- and top of detached window controls to resize the detached window"). Each detached block keeps a
-- width (layout.blocks.<id>.width, 200 to 600, step 10, default 280) on Layout > Blocks beside Block
-- scale, and its window carries a corner resize grip that writes it, the drop point kept. Locked
-- (the global lock or the block's own) hides the grip and refuses a grab. The height still follows
-- the rows. A merged window's columns take its widest member's width.
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local D, G = NS.Detached, NS.Groups
local ID = "weapon"

local function set(path, value)
    local ok, err = NS.SetByPath(path, value)
    assertTrue(ok, "write " .. path .. ": " .. tostring(err))
    M.__fireTimers()
end

-- The base mock records no size a setter gave (fidelity rule 2), so the frame's SetWidth and
-- SetHeight are recorded on it: `f.__w`, `f.__h`.
local function spySize(f)
    rawset(f, "SetWidth", function(self, v) rawset(self, "__w", v) end)
    rawset(f, "SetHeight", function(self, v) rawset(self, "__h", v) end)
    return f
end

-- Detach the weapon block, run `fn(frame)`, then dock it again with its width and lock as they were.
local function withDetached(fn)
    local s = NS.db.profile.layout.blocks[ID]
    local savedW, savedLock, savedPoint = s.width, s.locked, s.point
    s.docked = false
    D.Refresh()
    local f = spySize(D.Frame(ID))
    D.Render(ID)
    local ok, err = pcall(fn, f)
    rawset(f, "SetWidth", nil)
    rawset(f, "SetHeight", nil)
    s.width, s.locked, s.point, s.docked = savedW, savedLock, savedPoint, true
    NS.SetByPath("locked", false)
    D.Refresh()
    M.__fireTimers()
    if not ok then error(err, 0) end
end

test("FB-SM-04 the width row: Layout > Blocks, beside Block scale, 200 to 600 in steps of 10, 280 by default", function()
    local row = NS.FindSchemaRow("layout.blocks." .. ID .. ".width")
    assertTrue(row ~= nil, "a width row per block")
    assertEqual(row.page, "layout", "on the Layout page")
    assertEqual(row.group, NS.FindSchemaRow("layout.blocks." .. ID .. ".scale").group, "on the Blocks tab")
    assertEqual(row.subgroup, NS.FindSchemaRow("layout.blocks." .. ID .. ".scale").subgroup, "in the block's subgroup")
    assertEqual(row.min, 200, "min")
    assertEqual(row.max, 600, "max")
    assertEqual(row.step, 10, "step")
    assertEqual(row.default, 280, "the old fixed width")
    assertEqual(NS.defaults.profile.layout.blocks[ID].width, 280, "the profile default")
end)

test("FB-SM-04 a detached window takes its block's width", function()
    withDetached(function(f)
        assertEqual(f.__w, 280, "the default width")
        set("layout.blocks." .. ID .. ".width", 420)
        assertEqual(f.__w, 420, "the stored width")
        assertEqual(D.Width(ID), 420, "D.Width reads it")
        NS.db.profile.layout.blocks[ID].width = 9000
        assertEqual(D.Width(ID), 600, "a stored width out of range is clamped")
    end)
end)

test("FB-SM-04 the grip: shown, its bounds the row's range at the content's height", function()
    withDetached(function(f)
        local grip = f.resizeGrip
        assertTrue(grip ~= nil and grip:IsShown(), "a detached window has a shown resize grip")
        local minW, minH, maxW, maxH = f:GetResizeBounds()
        assertEqual(minW, 200, "the row's minimum")
        assertEqual(maxW, 600, "the row's maximum")
        assertTrue(f.__h ~= nil and f.__h > 0, "the content's height")
        assertEqual(minH, f.__h, "the height is the content's")
        assertEqual(maxH, f.__h, "and the grip never changes it")
    end)
end)

test("FB-SM-04 the grip: a drag writes the width on its step grid and keeps the drop point", function()
    withDetached(function(f)
        local grip = f.resizeGrip
        rawset(f, "GetLeft", function() return 300 end)
        rawset(f, "GetTop", function() return 700 end)
        local pins = {}
        rawset(f, "SetPoint", function(_, ...) pins[#pins + 1] = { ... } end)
        rawset(f, "GetPoint", function() return "TOPLEFT", M.UIParent, "BOTTOMLEFT", 300, 700 end)
        grip:__fire("OnMouseDown", "LeftButton")
        local pin = pins[#pins]
        assertTrue(pin and pin[1] == "TOPLEFT" and pin[4] == 300 and pin[5] == 700, "pinned by its top-left")
        f:__setGeom(347, f.__h)
        f:__fire("OnSizeChanged", 347, f.__h)
        f.resizeDriver:__fire("OnUpdate", 0.016)
        assertEqual(NS.db.profile.layout.blocks[ID].width, 280, "nothing is written while dragging")
        grip:__fire("OnMouseUp", "LeftButton")
        M.__fireTimers()
        for _, k in ipairs({ "GetLeft", "GetTop", "SetPoint", "GetPoint" }) do rawset(f, k, nil) end
        f.__geomLive = nil
        assertEqual(NS.db.profile.layout.blocks[ID].width, 350, "the release writes the width, snapped to 10")
        local p = NS.db.profile.layout.blocks[ID].point
        assertTrue(p and p.point == "TOPLEFT" and p.x == 300 and p.y == 700, "and the pinned point")
    end)
end)

test("FB-SM-04 Locked hides the grip and refuses a grab, the global lock and the block's own", function()
    withDetached(function(f)
        local grip = f.resizeGrip
        set("locked", true)
        assertFalse(grip:IsShown(), "the global lock hides it")
        local before = f.__sizingCount or 0
        grip:__fire("OnMouseDown", "LeftButton")
        assertEqual(f.__sizingCount or 0, before, "and a grab does not size the window")
        grip:__fire("OnMouseUp", "LeftButton")
        set("locked", false)
        assertTrue(grip:IsShown(), "unlocked: shown again")
        set("layout.blocks." .. ID .. ".locked", true)
        assertFalse(D.Frame(ID).resizeGrip:IsShown(), "the block's own lock hides it too")
    end)
end)

test("FB-SM-04 a merged window's columns take its widest member's width", function()
    local b = NS.db.profile.layout.blocks
    local saved = { primary = b.primary.width, other = b.other.width }
    b.primary.docked, b.other.docked = false, false
    b.primary.width, b.other.width = 300, 460
    D.Refresh()
    local gid = G.Merge("primary", "other", "bottom")
    M.__fireTimers()
    local ok, err = pcall(function()
        assertEqual(G.Width(gid), 460, "the widest member")
        local f = spySize(G.Frame(gid))
        G.Render(gid)
        rawset(f, "SetWidth", nil)
        rawset(f, "SetHeight", nil)
        assertEqual(f.__w, 460, "one column, the widest member's width")
    end)
    for _, id in ipairs(NS.BLOCKS) do b[id].docked = true end
    b.primary.width, b.other.width = saved.primary, saved.other
    NS.db.profile.layout.groups = {}
    D.Refresh()
    M.__fireTimers()
    if not ok then error(err, 0) end
end)
