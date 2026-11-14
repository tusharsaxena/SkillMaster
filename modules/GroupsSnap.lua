local _, NS = ...
-- modules/GroupsSnap.lua — the drags of the merged detached windows (owner feedback round 5, R5-6b):
-- a window dragged to another's side merges there, and a section's sub-header dragged out of its
-- merged window splits it off. modules/Groups.lua owns the groups; this file only measures and calls
-- NS.Groups.Merge / NS.Groups.Split on a drop.
--
-- The idea and the numbers follow AuraMaster's container snapping (the owner's sibling addon, MIT:
-- modules/Anchors_Snap.lua, modules/Anchors_SnapRect.lua, core/Constants.lua C.SNAP_RADIUS and
-- C.DETACH_RADIUS): a PURE core over rects in UIParent units, a throttled drag driver and a
-- highlight. Rewritten here for windows rather than aura containers.
--
-- THE PURE CORE (the suites drive it headless):
--   S.Nearest(rect, targets, exclude) -> hit | nil. `rect` and each `targets[i].rect` are
--     { left, top, right, bottom } in UIParent units. A side of a target is a candidate when the
--     dragged rect's facing edge is within S.SNAP_RADIUS of it and the two overlap (strictly) along
--     the other axis: the dragged left edge to the target's right (side "right"), its right edge to
--     the target's left ("left"), its bottom to the target's top ("top"), its top to the target's
--     bottom ("bottom"). The nearest candidate wins; a tie keeps the earlier target, then the side
--     order top, bottom, left, right. `exclude` (a key, or a set of keys) is never a target. The
--     hit is { key, side, dist, col }: `col` is the target column a top or bottom merge stacks into
--     (the one under the dragged rect's horizontal center, of `targets[i].cols`).
--   S.Classify(dx, dy) -> "hold" | "out": a section dragged within S.DETACH_RADIUS of where it
--     started holds (a release changes nothing), past it is out (a release splits it off).
--
-- THE DRIVER: S.BeginWindow(f, key) on a detached window's or a merged window's drag start,
-- S.BeginSection(sh, gid, id) on a sub-header's, S.Drop() on the drag's stop (answers what the drop
-- did: "merge", "split", "hold", "move" or nil for no drag), S.Cancel() at a stand-down. While a drag
-- is on, one OnUpdate (S.Frame(), armed only then) re-measures at most every S.THROTTLE s; a
-- section's ghost follows the pointer every frame. The highlight is a strip in the skin's sem.good
-- on the target's side; the ghost is edged sem.good inside the leeway, sem.bad past it. Geometry the
-- client answers secret (or not at all) gives no candidate: the drop is then a plain move.
--
-- Locked (the profile's `locked` or a member's own) refuses every drag before it reaches here (the
-- callers' drag starts). In combat a drag still moves its plain frame, and the merge or split its
-- drop asks for waits for the end of combat (NS.Groups' AfterCombat queue).

NS.GroupsSnap = {}
local S = NS.GroupsSnap
local LAYERS = NS.Constants.LAYERS

S.SNAP_RADIUS = 24      -- UIParent units: AuraMaster's C.SNAP_RADIUS
S.DETACH_RADIUS = 128   -- UIParent units: AuraMaster's C.DETACH_RADIUS
S.THROTTLE = 0.05       -- s between two measures while a drag is on
S.GLOW = 3              -- px: the highlight strip's thickness
S.SIDE_ORDER = { "top", "bottom", "left", "right" }

-- ---------------------------------------------------------------------------------------------
-- The pure core
-- ---------------------------------------------------------------------------------------------

-- The gap between the dragged rect `r`'s facing edge and target rect `t`'s side, and whether the
-- two overlap along the other axis.
local GAP = {
    top    = function(r, t) return math.abs(r.bottom - t.top), r.right > t.left and r.left < t.right end,
    bottom = function(r, t) return math.abs(r.top - t.bottom), r.right > t.left and r.left < t.right end,
    left   = function(r, t) return math.abs(r.right - t.left), r.top > t.bottom and r.bottom < t.top end,
    right  = function(r, t) return math.abs(r.left - t.right), r.top > t.bottom and r.bottom < t.top end,
}

local function excluded(exclude, key)
    if type(exclude) == "table" then return exclude[key] == true end
    return exclude ~= nil and exclude == key
end

--- The target column under rect `r`'s horizontal center: 1 .. `cols` of target rect `t`.
function S.Column(r, t, cols)
    cols = math.max(1, math.floor(tonumber(cols) or 1))
    local w = t.right - t.left
    if cols == 1 or w <= 0 then return 1 end
    local c = math.floor(((r.left + r.right) / 2 - t.left) / (w / cols)) + 1
    return math.max(1, math.min(c, cols))
end

--- The nearest side of `targets` dragged rect `rect` would merge on, or nil (the header above).
function S.Nearest(rect, targets, exclude)
    if type(rect) ~= "table" then return nil end
    local best
    for _, tg in ipairs(targets or {}) do
        local t = tg.rect
        if type(t) == "table" and tg.key ~= nil and not excluded(exclude, tg.key) then
            for _, side in ipairs(S.SIDE_ORDER) do
                local d, overlap = GAP[side](rect, t)
                if overlap and d <= S.SNAP_RADIUS and (not best or d < best.dist) then
                    best = { key = tg.key, side = side, dist = d, rect = t }
                    if side == "top" or side == "bottom" then best.col = S.Column(rect, t, tg.cols) end
                end
            end
        end
    end
    return best
end

--- A section drag's state at offset (dx, dy) from its start: "hold" within the leeway, else "out".
function S.Classify(dx, dy)
    dx, dy = tonumber(dx) or 0, tonumber(dy) or 0
    return (dx * dx + dy * dy) <= S.DETACH_RADIUS * S.DETACH_RADIUS and "hold" or "out"
end

-- ---------------------------------------------------------------------------------------------
-- Measures on the client: rects and the pointer in UIParent units, nil when secret or unanswered
-- ---------------------------------------------------------------------------------------------

local function plain(v)
    return type(v) == "number" and not (type(issecretvalue) == "function" and issecretvalue(v))
end

--- Frame `f`'s rect as { left, top, right, bottom } in UIParent units, or nil.
function S.Rect(f)
    local l, t, r, b = NS.Groups.UIRect(f)
    if not l then return nil end
    return { left = l, top = t, right = r, bottom = b }
end

--- The pointer in UIParent units, or nil.
function S.Cursor()
    local x, y = GetCursorPosition()
    local us = UIParent:GetEffectiveScale()
    if not (plain(x) and plain(y) and plain(us)) or us <= 0 then return nil end
    return x / us, y / us
end

--- Every window on screen a drop could merge into, `exclude` (a key or a set) left out: the shown
--- detached windows (key: the block id) and merged windows (key: the group id, `cols` its columns).
function S.Targets(exclude)
    local out = {}
    for _, id in ipairs(NS.BLOCKS) do
        local f = NS.Detached.Frame(id)
        if f and f:IsShown() and not excluded(exclude, id) then
            local r = S.Rect(f)
            if r then out[#out + 1] = { key = id, rect = r, cols = 1, frame = f } end
        end
    end
    for _, gid in ipairs(NS.Groups.Shown()) do
        local f = NS.Groups.Frame(gid)
        local r = not excluded(exclude, gid) and S.Rect(f)
        if r then out[#out + 1] = { key = gid, rect = r, cols = #NS.Groups.Columns(gid), frame = f } end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The highlight and the ghost
-- ---------------------------------------------------------------------------------------------

local function above()
    return LAYERS.STRATA_ABOVE[NS.Detached.Strata()] or LAYERS.STRATA.WINDOW_READ
end

local function paint(tex, token)
    local c = NS.Bar.Color(token)
    if c then tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

local glow
local function glowFrame()
    if glow then return glow end
    glow = CreateFrame("Frame", nil, UIParent)
    glow.tex = glow:CreateTexture(nil, "OVERLAY")
    glow.tex:SetAllPoints(glow)
    glow:Hide()
    return glow
end

--- The highlight strip (the suites read its `target`, `side`, `col` and `token`).
function S.Glow() return glow end

-- The strip on hit `hit`'s side of its target's frame `tf`; hidden for no hit.
local function showGlow(hit, tf)
    local g = glowFrame()
    if not (hit and tf) then
        g:Hide()
        g.target, g.side, g.col = nil, nil, nil
        return
    end
    if g.target == hit.key and g.side == hit.side and g.col == hit.col and g:IsShown() then return end
    g.target, g.side, g.col, g.token = hit.key, hit.side, hit.col, "sem.good"
    g:SetFrameStrata(above())
    g:ClearAllPoints()
    local side = hit.side
    if side == "left" or side == "right" then
        local edge = side == "left" and "LEFT" or "RIGHT"
        g:SetPoint("TOP" .. edge, tf, "TOP" .. edge, 0, 0)
        g:SetPoint("BOTTOM" .. edge, tf, "BOTTOM" .. edge, 0, 0)
        g:SetWidth(S.GLOW)
    else
        -- Over the column a top or bottom drop stacks into.
        local edge = side == "top" and "TOP" or "BOTTOM"
        local w = NS.Detached.WIDTH * (tonumber(NS.Detached.Style().scale) or 1)
        local x = ((hit.col or 1) - 1) * w
        g:SetPoint(edge .. "LEFT", tf, edge .. "LEFT", x, 0)
        g:SetWidth(w)
        g:SetHeight(S.GLOW)
    end
    paint(g.tex, g.token)
    g:Show()
end

local ghost
local function ghostFrame()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost.bg = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.bg:SetAllPoints(ghost)
    ghost.edges = NS.Bar.MakeEdges(ghost, "OVERLAY")
    ghost.title = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ghost.title:SetPoint("LEFT", ghost, "LEFT", 8, 0)
    NS.Skin.Text(ghost.title, "heading")
    ghost:Hide()
    return ghost
end

--- The section drag's ghost (the suites read its `token`).
function S.Ghost() return ghost end

local function paintGhost(state)
    local token = state == "out" and "sem.bad" or "sem.good"
    if ghost.token == token then return end
    ghost.token = token
    NS.Bar.PaintBorder(ghost, { border = NS.Bar.Color(token), borderStyle = "Solid", borderSize = 2 })
end

-- ---------------------------------------------------------------------------------------------
-- The driver: one drag at a time
-- ---------------------------------------------------------------------------------------------

local drag            -- the drag on: { kind, frame, key | gid + id, ... }
local driver          -- the frame whose OnUpdate measures while a drag is on

--- The driver's frame (the suites fire its OnUpdate).
function S.Frame() return driver end

--- The drag on, or nil (the suites read it).
function S.Drag() return drag end

local function measureWindow()
    local hit = S.Nearest(S.Rect(drag.frame), S.Targets(drag.key))
    drag.hit = hit
    showGlow(hit, hit and hit.key and S.TargetFrame(hit.key))
end

-- The ghost under the pointer; answers its rect in UIParent units.
local function followSection()
    local cx, cy = S.Cursor()
    if not cx then return nil end
    local x, y = cx - drag.offX, cy + drag.offY
    ghost:ClearAllPoints()
    ghost:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    drag.x, drag.y = x, y
    drag.state = S.Classify(cx - drag.startX, cy - drag.startY)
    paintGhost(drag.state)
    return { left = x, top = y, right = x + drag.w, bottom = y - drag.h }
end

local function measureSection()
    local rect = followSection()
    local hit = rect and drag.state == "out" and S.Nearest(rect, S.Targets(drag.gid)) or nil
    drag.hit = hit
    showGlow(hit, hit and S.TargetFrame(hit.key))
end

--- The frame window `key` (a block id or a group id) is drawn by.
function S.TargetFrame(key)
    return NS.Groups.Frame(key) or NS.Detached.Frame(key)
end

--- Re-measure the drag on now: its candidate, the highlight and the ghost.
function S.Update()
    if not drag then return end
    if drag.kind == "section" then measureSection() else measureWindow() end
end

local function onUpdate(_, elapsed)
    if not drag then return end
    drag.t = (drag.t or 0) + (elapsed or 0)
    if drag.kind == "section" and drag.t < S.THROTTLE then followSection() return end
    if drag.t < S.THROTTLE then return end
    drag.t = 0
    S.Update()
end

local function arm()
    driver = driver or CreateFrame("Frame", nil, UIParent)
    driver:SetScript("OnUpdate", onUpdate)
end

local function disarm()
    if driver then driver:SetScript("OnUpdate", nil) end
    showGlow(nil)
    if ghost then ghost:Hide() end
    if drag and drag.header then drag.header:SetAlpha(1) end
    drag = nil
end

--- A window's drag began: detached block `key`'s window, or merged window `key` (a group id).
function S.BeginWindow(f, key)
    if not (f and key) then return end
    disarm()
    drag = { kind = "window", frame = f, key = key }
    arm()
end

--- Section `id`'s sub-header `sh` in group `gid` began a drag: a ghost of it follows the pointer.
function S.BeginSection(sh, gid, id)
    if not (sh and gid and id) then return end
    disarm()
    local cx, cy = S.Cursor()
    if not cx then return end
    local gs = tonumber(NS.Detached.Style().scale) or 1
    local w, h = NS.Detached.WIDTH * gs, NS.Groups.SUB_H * gs
    -- Where the pointer took the sub-header, so the ghost does not jump under it.
    local r = S.Rect(sh)
    local offX, offY = 24, h / 2
    if r then offX, offY = cx - r.left, r.top - cy end
    local g = ghostFrame()
    g:SetFrameStrata(above())
    g:SetWidth(w)
    g:SetHeight(h)
    paint(g.bg, "sm.headerBg")
    g.title:SetText(NS.BlockDefs[id] and NS.BlockDefs[id].title or id)
    g.token = nil
    drag = { kind = "section", frame = sh.owner, header = sh, gid = gid, id = id,
             startX = cx, startY = cy, offX = offX, offY = offY, w = w, h = h, state = "hold" }
    sh:SetAlpha(0.5)
    followSection()
    g:Show()
    arm()
end

-- A window's drop: a merge onto the candidate, else nothing more (the caller saved its point).
local function dropWindow(d)
    local hit = d.hit
    if not hit then return "move" end
    NS.Groups.Merge(d.key, hit.key, hit.side, { col = hit.col })
    return "merge"
end

-- A section's drop: within the leeway nothing; past it, a merge onto a candidate, else a split at
-- the ghost's top-left.
local function dropSection(d)
    if d.state ~= "out" or not d.x then return "hold" end
    if d.hit then
        NS.Groups.Merge(d.id, d.hit.key, d.hit.side, { col = d.hit.col })
        return "merge"
    end
    NS.Groups.Split(d.gid, d.id, NS.Groups.PointAt(d.x, d.y, NS.Groups.BlockScale(d.id)))
    return "split"
end

--- The drag on ended: measure once more and act on it. Answers "merge", "split", "hold" (a section
--- released inside its leeway), "move" (a window with no candidate) or nil (no drag).
function S.Drop()
    if not drag then return nil end
    S.Update()
    local d = drag
    disarm()
    local did
    if d.kind == "section" then did = dropSection(d) else did = dropWindow(d) end
    NS.Debug("Layout", "drop %s %s: %s", d.kind, tostring(d.key or d.id), did)
    return did
end

--- Drop the drag on without acting on it (a stand-down mid-drag).
function S.Cancel() disarm() end
