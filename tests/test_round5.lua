-- tests/test_round5.lua — the owner's round-5 feedback (2026-11-13): a detached row's action mark
-- drawn as the main window's, the Journal's table headers on a band of their own, the Journal's lock
-- mark and test mode's surfaces (the main window, the Journal and one toast of each kind).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local W, D, R = NS.MainWindow, NS.Detached, NS.Rows

local function withWorld(fn)
    NS.Preview.Apply(true)
    W.Show()
    M.__fireTimers()
    local ok, err = pcall(fn)
    W.Hide()
    NS.Preview.Apply(false)
    M.__fireTimers()
    if not ok then error(err, 0) end
end

local function withDetached(id, fn)
    local s = NS.db.profile.layout.blocks[id]
    s.docked = false
    D.Refresh()
    local ok, err = pcall(fn)
    s.docked = true
    D.Refresh()
    if not ok then error(err, 0) end
end

-- ── R5-5: the detached row's action mark ────────────────────────────────────────────────────

-- The owner's screenshots (round 5): the detached window's marks read soft, the bracket's right stroke
-- at half intensity, while the main window's were crisp. The 13 px art sits centered in the 18 px
-- control, 2.5 px in, so where it lands on a physical pixel depends on the frame's own position: the
-- main window's happened to land on the grid, a detached frame's (a drop point anywhere) half a pixel
-- off, and the 1-texel strokes straddled two pixels. The art snaps to the pixel grid on every frame.
local function snapped(tex)
    return tex ~= nil and rawget(tex, "__snap") == true and rawget(tex, "__texelBias") == 0
end

test("round5 detached mark: a detached row's action mark snaps to the pixel grid, as the main window's", function()
    withWorld(function()
        local main = W.Rows()[1]
        assertTrue(main ~= nil and main.act.icon ~= nil, "the main window draws a row with its mark")
        assertTrue(snapped(main.act.icon), "the main window's mark snaps to the pixel grid")
        withDetached("weapon", function()
            local rows = D.Rows("weapon")
            assertTrue(#rows > 0, "the detached weapon block draws rows")
            for _, row in ipairs(rows) do
                assertTrue(snapped(row.act.icon), row.entry.key .. ": the detached mark snaps as the main window's")
            end
        end)
    end)
end)

test("round5 detached mark: the mark sits a whole unit down its row at any row height", function()
    local bars = NS.db.profile.bars
    local was = bars.rowHeight
    bars.rowHeight = 21   -- (21 - 18) / 2 = 1.5: half a unit off before the fix
    local ok, err = pcall(withWorld, function()
        withDetached("weapon", function()
            local row = D.Rows("weapon")[1]
            local x, y
            rawset(row.act, "SetPoint", function(_, _, _, _, ox, oy) x, y = ox, oy end)
            D.Render("weapon")
            rawset(row.act, "SetPoint", nil)
            assertEqual(x, -R.EDGE, "the mark at the header's inset")
            assertEqual(y, math.floor(y), "a whole unit down the row")
        end)
    end)
    bars.rowHeight = was
    if not ok then error(err, 0) end
end)

test("round5 detached mark: every chrome mark snaps its art (the band's controls too)", function()
    local b = NS.Chrome.IconButton(M.UIParent, "lock", "L")
    assertTrue(snapped(b.icon), "a fresh control's art snaps")
    assertFalse(b.glyph ~= nil and b.glyph:IsShown(), "the art drew, not the glyph")
end)
