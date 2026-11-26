local _, NS = ...
-- modules/Detached.lua — a detached block's own frame (design §2 goal 4, mockup "Detached"): a HUD
-- display (frame-layering-§1 T1, MEDIUM) with a title band (the block's title, its collapse and dock
-- controls) and the block's rows in the compact bar style, movable unless locked, its drop point
-- stored in profile.layout.blocks[id].point (geometry only a drag sets; this module is its one
-- writer, docs/ARCHITECTURE.md).
--
-- The weapon block is the mockup's compact preset: the equipped weapons carry the marker, and with
-- profile.layout.blocks.weapon.belowCapOnly only the equipped weapons and the skills below their
-- cap are shown. An equipment change redraws it.
--
-- NS.Detached.Refresh(anchor) / .RefreshValues() / .StandDown() / .Frame(id) / .Rows(id) / .Render(id)
-- NS.Detached.Ids(): the blocks and the detached sub-categories (R5-SM-09, modules/SubBlocks.lua)
-- NS.Detached.Entries(id) -> the entries a detached frame draws, and how many the header's filter
--   took out (NS.Blocks.FilterOf, round 5, R5-10); .StorePoint(id, p) (a split's landing)
-- NS.Detached.ApplyStyle(f) / .Style() / .TopHeight(f) -> the shared Detached windows style (R5-7)
-- NS.Detached.BandMarks(f, marks) -> gap: a band's settings mark (HeaderButtons) and its marks (AD-86-SM)
-- NS.Detached.PlaceInward(anchor, marks, gap): the marks at the strip's pitch when no skin header placed them
-- NS.Detached.Width(id) / .WidestOf(ids) / .ApplyLock(): the block's width and its grip (FB-SM-04)
-- NS.Detached.SnapWidth(w): a width on the Blocks row's step grid inside its range (a merged window's grip too)

NS.Detached = {}
local D = NS.Detached
local LAYERS = NS.Constants.LAYERS
local Perf = NS.Perf

D.WIDTH, D.TITLE_H, D.PAD = 280, 22, 4   -- 280: the rows' 18 px back (feedback round 2)
-- FB-SM-04: a block's own width, layout.blocks.<id>.width, inside these bounds (its Blocks row's
-- range, which the grip's bounds share); D.WIDTH is its default.
D.MIN_WIDTH, D.MAX_WIDTH, D.WIDTH_STEP = 200, 600, 10
-- The rows' own breathing room above the first row and below the last (feedback round 2); the
-- spacing between rows is the rows' own height and is not touched.
D.ROW_PAD = 4
D.STYLE = "compact"

local frames = {}

function D.Frame(id) return frames[id] end

--- Every id a detached window can draw: the blocks, then the detached sub-categories (R5-SM-09).
function D.Ids()
    local out = {}
    for i, id in ipairs(NS.BLOCKS) do out[i] = id end
    for _, id in ipairs(NS.SubBlocks and NS.SubBlocks.Ids() or {}) do out[#out + 1] = id end
    return out
end

--- The rows a detached frame is showing (the suites read them).
function D.Rows(id)
    local f = frames[id]
    return f and f.rowPool.active or {}
end

local function settings(id) return NS.Blocks.Settings(id) end

--- A detached block's strata: the player's pick, one of STRATA_CHOICES, else the HUD tier's.
function D.Strata()
    local layout = (NS.db and NS.db.profile.layout) or NS.defaults.profile.layout
    for _, v in ipairs(LAYERS.STRATA_CHOICES) do if v == layout.detachedStrata then return v end end
    return LAYERS.STRATA.HUD
end

local function isLocked(id)
    local s = settings(id)   -- nil for a sub-category docked back since its frame was built (R5-SM-09)
    return NS.GetSetting("locked") or (s ~= nil and s.locked == true)
end

--- Block `id`'s detached width (FB-SM-04): its stored width inside MIN_WIDTH..MAX_WIDTH, else WIDTH.
function D.Width(id)
    local s = NS.Blocks.Settings(id)
    local w = s and tonumber(s.width)
    if not w then return D.WIDTH end
    return math.max(D.MIN_WIDTH, math.min(D.MAX_WIDTH, w))
end

--- The widest of `ids`' widths: a merged window's column width. WIDTH for none.
function D.WidestOf(ids)
    local w = 0
    for _, id in ipairs(ids or {}) do w = math.max(w, D.Width(id)) end
    return w > 0 and w or D.WIDTH
end

local function savePoint(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    if type(point) ~= "string" then return end
    settings(f.id).point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

--- Give block `id` the drop point `p` ({ point, relPoint, x, y } against UIParent): where a section
--- split from a merged window, or a window unmerged, lands (round 5, R5-6; modules/Groups.lua). The
--- point's other writer beside a drag's savePoint; this module stays its one owner.
function D.StorePoint(id, p)
    local s = settings(id)
    if not (s and type(p) == "table" and type(p.point) == "string") then return false end
    s.point = { point = p.point, relPoint = p.relPoint or p.point, x = tonumber(p.x) or 0, y = tonumber(p.y) or 0 }
    return true
end

local function applyPoint(f)
    local p = settings(f.id).point
    f:ClearAllPoints()
    if type(p) == "table" then
        f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        -- A first detach lands right of center, stepped per block so two do not stack exactly.
        local step = 0
        for i, id in ipairs(D.Ids()) do if id == f.id then step = i end end
        f:SetPoint("TOPLEFT", UIParent, "CENTER", 240, 200 - 24 * step)
    end
    -- The scale is the style's (D.ApplyStyle): the block's own times the Detached windows tab's.
    -- The player's strata for every detached block (Layout > Detached block strata); the crafting
    -- overlays take it on the sync Refresh ends with.
    f:SetFrameStrata(D.Strata())
end

local function onDragStart(self)
    if isLocked(self.id) then return end
    self:StartMoving()
    self.dragging = true
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(self, true) end
    -- The drag that merges: this window dropped on another's side (round 5, modules/GroupsSnap.lua).
    if NS.GroupsSnap then NS.GroupsSnap.BeginWindow(self, self.id) end
end

local function onDragStop(self)
    if not self.dragging then return end
    self.dragging = nil
    self:StopMovingOrSizing()
    savePoint(self)
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(self, false) end
    if NS.GroupsSnap then NS.GroupsSnap.Drop() end
end

local function belowCapOnly(id)
    return id == "weapon" and settings(id).belowCapOnly == true
end

--- The entries detached block `id` draws: the block's, the equipped weapons marked, and for the
--- weapon block's compact filter only the equipped ones and the learned skills below their cap.
function D.Entries(id)
    local entries, removed = NS.Blocks.Entries(id)
    if id ~= "weapon" then return entries, removed end
    local equipped = NS.SkillHelpers.EquippedWeaponSkills()
    local filter = belowCapOnly(id)
    local out = {}
    for _, r in ipairs(entries) do
        local e = r.entry
        local on = equipped[e.key] == true
        if not filter or on or (e.learned ~= false and (e.rank or 0) < (e.max or 0)) then
            out[#out + 1] = { kind = r.kind, entry = e, marked = on }
        end
    end
    return out, removed
end

--- Lay block `id`'s detached rows into `host` from `y`, or the muted line its emptied filter shows
--- (`note`, a font string of the caller's). Answers the y under them. A merged section draws so too.
function D.LayEntries(id, host, rowPool, y, note)
    local entries, removed = D.Entries(id)
    local text = NS.Blocks.FilterNote(entries, removed)
    if note then
        note:SetText(text or "")
        note:SetShown(text ~= nil)
    end
    if text and note then
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -(y + D.ROW_PAD))
        note:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -(y + D.ROW_PAD))
        return y + D.ROW_PAD + NS.Blocks.NOTE_H
    end
    return NS.Blocks.LayRows(entries, host, rowPool, y + D.ROW_PAD, D.STYLE, D.PAD) + D.ROW_PAD
end

--- A muted line on `parent` for an emptied filter, hidden until D.LayEntries shows it.
function D.NewNote(parent)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetJustifyH("LEFT")
    NS.Skin.Text(note, "muted")
    note:Hide()
    return note
end

--- A band's marks on the strip (AD-86-SM, LibKa0s#86; standalone-windows, *Title-bar controls*):
--- LibKa0s Widgets' HeaderButtons builds the settings mark in the corner (no close: a detached or a
--- merged window never had one, and docking is its way back), and the band's own block-header marks
--- (`marks`, outermost first) stand inward of it at the strip's pitch, placed with it by the skin's
--- Header, `f.title` clear of them. Those marks stay this addon's (NS.Chrome.HeaderMark): their art
--- fitted to its ink box, the filter's filled badge and the restore mark's own showing are state the
--- library's mark does not carry (docs/ARCHITECTURE.md, Documented deviations). Answers the gap.
function D.BandMarks(f, marks)
    local pad, gap = NS.Chrome.HeaderPitch()
    local hb = NS.Chrome.TitleMarks(f, {
        close = false, settingsTip = NS.L["Open the settings panel"],
        level = LAYERS.LEVEL.CHROME, y = -2,
    })
    f.settingsButton = hb.settings
    local right = {}
    for _, e in ipairs(hb.right) do right[#right + 1] = e end
    for _, b in ipairs(marks) do right[#right + 1] = b end
    NS.Skin.Header(f, { title = f.title, align = "LEFT", right = right, pad = pad, gap = gap })
    return gap
end

--- The no-skin rung of D.BandMarks (S.Header placed nothing): each of `marks`, outermost first, `gap`
--- left of the one before, the first `gap` left of `anchor` (the settings mark), so the strip keeps
--- one pitch with or without a skin. Shared by the detached band and the merged window's band.
function D.PlaceInward(anchor, marks, gap)
    local prev = anchor
    for _, b in ipairs(marks) do
        b:SetPoint("RIGHT", prev, "LEFT", -gap, 0)
        prev = b
    end
end

local function buildBand(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetText(NS.BlockDefs[f.id].title)
    NS.Skin.Text(f.title, "heading")
    -- The attach mark: the header's detach mark (external-link) turned 180 degrees (FB-15).
    f.dock = NS.Chrome.HeaderMark(f, "external-link", "-", function() NS.Blocks:Dock(f.id) end,
        NS.L["Dock this block in the main window"])
    NS.Chrome.SetIcon(f.dock, "external-link", "-", true)
    f.collapse = NS.Chrome.HeaderMark(f, "chevron-down", "v", function() NS.Blocks:ToggleCollapsed(f.id) end)
    -- The block's sort mark, as on its header in the window (owner feedback round 3).
    f.sort = NS.Chrome.HeaderMark(f, "list", "=", function(b) NS.Blocks.SortMenu(f.id, b) end)
    -- The block's filter mark, on a block that has a filter (every block since round 7, R7-1).
    if NS.Blocks.FILTERABLE[f.id] then
        f.filter = NS.Chrome.HeaderMark(f, NS.Blocks.FILTER_ICON, "Y", function(b) NS.Blocks.FilterMenu(f.id, b) end)
        f.filter:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    end
    -- The restore mark (owner feedback round 4), leftmost so its hiding leaves no gap.
    f.restore = NS.Chrome.HeaderMark(f, "eye", "o", function() NS.Blocks.RestoreHidden(f.id) end)
    f.restore:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    f.restore:Hide()
    -- Every mark at rest in the main window header's color (owner feedback round 8, R8-3), which is
    -- now every mark's `icon.tint` (smoke round 1's ruling 4); under the pointer `text.link`, as
    -- there. The filter's own rest color is its badge's.
    for _, b in ipairs({ f.dock, f.collapse, f.sort, f.filter, f.restore }) do
        NS.Chrome.SetRestToken(b, NS.Chrome.REST)
    end
    if f.filter then f.filter.baseToken = NS.Chrome.REST end
    f.dock:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    f.collapse:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    f.sort:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    local marks = { f.dock, f.collapse, f.sort }
    if f.filter then marks[#marks + 1] = f.filter end
    marks[#marks + 1] = f.restore
    local gap = D.BandMarks(f, marks)
    if not f.dock:GetPoint(1) then
        D.PlaceInward(f.settingsButton, marks, gap)
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -5)
    end
end

--- The title band's height: the skin's band (S.Band, its `title.height` plus the border inset), never
--- under TITLE_H. The body starts below it, so the title the header centers on the band reads
--- centered rather than half covered by the first row (feedback round 2).
function D.TitleHeight(f)
    local band = NS.Skin.Band and NS.Skin.Band(f)
    if not (band and band.GetHeight and band.GetPoint) then return D.TITLE_H end
    local h = tonumber(band:GetHeight()) or 0
    local y = select(5, band:GetPoint(1))   -- the band's inset below the frame's top edge
    return math.max(D.TITLE_H, h + math.abs(tonumber(y) or 0))
end

-- ---------------------------------------------------------------------------------------------
-- The shared style (round 5, R5-7): Layout > Detached windows, one look for every detached window,
-- profile.layout.detached. D.ApplyStyle(f) takes any window frame shaped as a block's is: `f.ownScale`
-- (its own scale, multiplied by the tab's), `f.bandParts` (the title and the marks the title band
-- shows and hides) and an optional `f.onBand(f, shown)` for a mark whose showing is its own (the
-- restore mark). A merged group's frame calls it too.
--
--   background  the skin's window fill while bgFromSkin is on (S.Shell), else the swatch through its
--               class companion on a fill of the frame's own, over the skin's and under the band
--   border      off: none; borderFromSkin on: the skin's window edge (S.Shell); off: the style,
--               thickness and swatch on edges of the frame's own, over its rows
--   title band  always; hover: the band, its fill and its marks hidden until the pointer is over the
--               window (polled, so a pointer on a row or a mark still counts), the body kept below the
--               band so nothing jumps; never: no band, and a GRIP_H strip at the top stays the drag area
-- ---------------------------------------------------------------------------------------------
D.GRIP_H = 6           -- the drag strip a window keeps with Title band Never
D.HOVER_POLL = 0.1     -- s between two hover checks while Title band is On hover
D.TITLE_BANDS = { always = true, hover = true, never = true }

--- The style a detached window draws with: profile.layout.detached (AceDB answers a missing key
--- from its default), the defaults before the database. Each reader below falls back on its own.
function D.Style()
    local s = NS.db and NS.db.profile.layout and NS.db.profile.layout.detached
    return type(s) == "table" and s or NS.defaults.profile.layout.detached
end

-- The background's own color: the class color while its companion is on (FB-SM-02: class first),
-- else the swatch while the skin's is not followed, else nil (the skin's fill).
local function bgColor(st)
    local class = NS.ClassFirst(st.bgColor, st.useClassColorBg)
    if class then return class end
    if st.bgFromSkin ~= false or type(st.bgColor) ~= "table" then return nil end
    return NS.WithClassColor(st.bgColor, st.useClassColorBg)
end

-- The window's own border while it is shown and either its class companion is on (FB-SM-02: class
-- first) or the skin's is not followed, else nil (the skin's edge).
local function ownBorder(st)
    if st.border == false then return nil end
    local c = type(st.borderColor) == "table" and st.borderColor or NS.defaults.profile.layout.detached.borderColor
    if st.borderFromSkin ~= false and not NS.ClassFirst(c, st.useClassColorBorder) then return nil end
    return { border = NS.WithClassColor(c, st.useClassColorBorder), borderStyle = st.borderStyle or "Solid",
             borderSize = tonumber(st.borderSize) or 1 }
end

local function titleBand(st)
    return D.TITLE_BANDS[st.titleBand] and st.titleBand or "always"
end

--- The opts the window's S.Shell was last painted with (the suites read them).
function D.ShellOpts(f) return f and f.__shellOpts end

-- S.Shell only when its opts change: the skin's own repaint replays the recorded ones.
local function paintShell(f, noBorder, noTopBar)
    local key = (noBorder and "b" or "-") .. (noTopBar and "t" or "-")
    if f.__shellKey == key then return end
    f.__shellKey = key
    f.__shellOpts = { noBorder = noBorder or nil, noTopBar = noTopBar or nil }
    NS.Skin.Shell(f, f.__shellOpts)
end

local function ensureLayers(f)
    if f.styleBg then return end
    -- BACKGROUND 2: over the backdrop's fill (0) and the skin's gradient and art (-7, -6), under the
    -- band's fill (S.Shell's P.BAND_SUB, 3).
    f.styleBg = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.styleBg:SetAllPoints(f)
    f.styleBg:Hide()
    f.styleEdge = CreateFrame("Frame", nil, f)
    f.styleEdge:SetAllPoints(f)
    f.styleEdge:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    f.styleEdge.edges = NS.Chrome.MakeEdges(f.styleEdge, "OVERLAY")
end

local function bandShown(f, shown)
    for _, part in ipairs(f.bandParts or {}) do part:SetShown(shown) end
    if f.onBand then f.onBand(f, shown) end
end

-- The band as the pointer has it: shown while over the window, hidden otherwise.
local function hover(f)
    local over = f.IsMouseOver ~= nil and f:IsMouseOver() == true
    if over == f.__bandShown then return end
    f.__bandShown = over
    bandShown(f, over)
    paintShell(f, f.__noBorder, not over)
end

local function onHoverUpdate(f, elapsed)
    f.__hoverT = (f.__hoverT or 0) + (elapsed or 0)
    if f.__hoverT < D.HOVER_POLL then return end
    f.__hoverT = 0
    hover(f)
end

--- The height the window's title band takes at the top, by the style's Title band.
function D.TopHeight(f)
    if titleBand(D.Style()) == "never" then return D.GRIP_H end
    return D.TitleHeight(f)
end

--- Paint window `f` in the shared style: scale, opacity, background, border and title band.
function D.ApplyStyle(f)
    if not f then return end
    local st = D.Style()
    ensureLayers(f)
    f:SetScale((tonumber(f.ownScale) or 1) * (tonumber(st.scale) or 1))
    f:SetAlpha(tonumber(st.alpha) or 1)
    local bg = bgColor(st)
    if bg then
        f.styleBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
        f.styleBg:Show()
    else
        f.styleBg:Hide()
    end
    local own = ownBorder(st)
    NS.Chrome.PaintBorder(f.styleEdge, own or { border = nil, borderStyle = "Solid", borderSize = 1 })
    -- The skin's edge only while the border is shown and follows it; the window's own edge otherwise.
    f.__noBorder = st.border == false or own ~= nil
    local mode = titleBand(st)
    f.__titleBand = mode
    if mode == "hover" then
        f:SetScript("OnUpdate", onHoverUpdate)
        f.__bandShown = nil
        hover(f)
    else
        f:SetScript("OnUpdate", nil)
        f.__bandShown = mode == "always"
        bandShown(f, f.__bandShown)
        paintShell(f, f.__noBorder, mode ~= "always")
    end
end

local function placeBody(f, top)
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    f.body:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
end

-- ---------------------------------------------------------------------------------------------
-- The resize grip (FB-SM-04; standalone-windows, Resizing): the corner grip sets the block's width
-- only. Its bounds are the Blocks row's range at the content's height, so the height never moves.
-- While it is dragged the rows follow the frame's width by their anchors; on the release the width
-- is written through the settings seam on the row's step grid (one ApplyLook redraw) and the drop
-- point the grab pinned is saved first, so the redraw lands where the frame stands. Locked (the
-- global lock or the block's own) hides the grip and refuses a grab.
-- ---------------------------------------------------------------------------------------------

local function snapWidth(w)
    w = tonumber(w) or D.WIDTH
    w = D.MIN_WIDTH + math.floor((w - D.MIN_WIDTH) / D.WIDTH_STEP + 0.5) * D.WIDTH_STEP
    return math.max(D.MIN_WIDTH, math.min(D.MAX_WIDTH, w))
end
D.SnapWidth = snapWidth   -- a merged window's grip snaps its column width the same way (R5-SM-08)

local function makeResizable(f)
    NS.Chrome.MakeResizable(f, {
        layout = function() end,   -- the rows are anchored to both edges: they follow the frame
        redraw = function()
            f.sizing = nil
            if NS.SecureOverlay then NS.SecureOverlay:SetMoving(f, false) end
        end,
        save = function(w)
            savePoint(f)
            -- A detached sub-category's width is its own row's (R5-SM-09: no schema row); a block's goes
            -- through the seam.
            if NS.SubBlocks and NS.SubBlocks.IsSub(f.id) then return NS.SubBlocks.SetWidth(f.id, snapWidth(w)) end
            NS.SetByPath("layout.blocks." .. f.id .. ".width", snapWidth(w))
        end,
        canResize = function()
            if isLocked(f.id) then return false end
            NS.Chrome.PinTopLeft(f)
            f.sizing = true
            if NS.SecureOverlay then NS.SecureOverlay:SetMoving(f, true) end
            return true
        end,
    })
end

-- The grip's bounds (the row's range, the height pinned at `h`) and its showing (hidden while locked).
local function applyGrip(f, h)
    local grip = f.resizeGrip
    if not grip then return end
    if type(f.SetResizeBounds) == "function" then
        f:SetResizeBounds(D.MIN_WIDTH, h, D.MAX_WIDTH, h)
    else
        if type(f.SetMinResize) == "function" then f:SetMinResize(D.MIN_WIDTH, h) end
        if type(f.SetMaxResize) == "function" then f:SetMaxResize(D.MAX_WIDTH, h) end
    end
    grip:SetShown(not isLocked(f.id))
end

--- The lock changed (the global Locked's reaction, settings/General.lua): every built detached
--- window's drag and grip follow it at once, not at its next render.
function D.ApplyLock()
    for id, f in pairs(frames) do
        f:SetMovable(not isLocked(id))
        if f.resizeGrip then f.resizeGrip:SetShown(not isLocked(id)) end
    end
    if NS.Groups and NS.Groups.ApplyLock then NS.Groups.ApplyLock() end
end

local function build(id)
    -- A detached sub-category's frame has no global name: its id carries a node key (R5-SM-09).
    local sub = NS.SubBlocks and NS.SubBlocks.IsSub(id)
    local f = CreateFrame("Frame", (not sub) and ("SkillMasterBlock_" .. id) or nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata(LAYERS.STRATA.HUD)
    f.id = id
    f:SetWidth(D.Width(id))
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", onDragStart)
    f:SetScript("OnDragStop", onDragStop)
    if NS.SecureOverlay then NS.SecureOverlay:Follow(f) end
    f.body = CreateFrame("Frame", nil, f)
    placeBody(f, D.TITLE_H)
    f.body:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    f.rowPool = NS.Rows.NewPool()
    NS.Skin.Shell(f)
    buildBand(f)
    f.note = D.NewNote(f.body)
    f.bandParts = { f.title, f.settingsButton, f.dock, f.collapse, f.sort }
    if f.filter then f.bandParts[#f.bandParts + 1] = f.filter end
    f.onBand = function(self, shown)
        if shown then NS.Blocks.PaintRestore(self.restore, self.id) else self.restore:Hide() end
    end
    makeResizable(f)
    frames[id] = f
    return f
end

--- Draw block `id` into its frame: the rows (none while collapsed) and the frame's height.
function D.Render(id)
    local f = frames[id]
    if not f then return end
    local t0 = Perf.on and debugprofilestop()
    NS.Rows.ReleaseAll(f.rowPool)
    local collapsed = settings(id).collapsed
    f.title:SetText(NS.BlockDefs[id].title)   -- a sub-category's name can arrive after its window (R5-SM-09)
    NS.Chrome.SetIcon(f.collapse, collapsed and "chevron-right" or "chevron-down",
        collapsed and ">" or "v")
    f.collapse.tip = nil   -- the chevron says it (R5-SM-01: no hint tooltip on a fold)
    NS.Blocks.PaintSort(f.sort, id)
    if f.filter then NS.Blocks.PaintFilter(f.filter, id) end
    f.ownScale = settings(id).scale or 1
    D.ApplyStyle(f)
    local y = 0
    f.note:Hide()
    if not collapsed then y = D.LayEntries(id, f.body, f.rowPool, 0, f.note) end
    -- Read at each render: a skin switch can move the band (it re-renders through ApplyLook).
    local top = D.TopHeight(f)
    placeBody(f, top)
    f.rowsH = y   -- the rows' drawn extent (the block as a merged section, NS.Groups)
    f.body:SetHeight(math.max(y, 1))
    local h = top + y + D.PAD
    if not f.sizing then f:SetWidth(D.Width(id)) end
    f:SetHeight(h)
    applyGrip(f, h)
    f:SetMovable(not isLocked(id))
    if t0 then Perf.Note("detachedRender", debugprofilestop() - t0) end
end

--- Show every detached block's frame and hide every docked block's. Nothing shows while stood down.
--- `anchor == false` (a data repaint) leaves a frame already on screen where it is, so a frame the
--- player is dragging is not re-anchored; a layout change, a first show and the default re-anchor.
--- A block in a merged window (NS.Groups, round 5) draws there, its own frame hidden; the merged
--- windows refresh with the same `anchor`.
function D.Refresh(anchor)
    local down = NS.IsStoodDown and NS.IsStoodDown()
    local G = NS.Groups
    local seen = {}
    for _, id in ipairs(D.Ids()) do
        seen[id] = true
        local s = settings(id)
        local f = frames[id]
        -- A detached sub-category this character's tree lacks keeps its row but shows no window (R5-REV).
        local absent = NS.SubBlocks and NS.SubBlocks.Absent(id)
        if s and s.docked == false and not down and not (G and G.Of(id)) and not absent then
            f = f or build(id)
            if anchor ~= false or not f:IsShown() then applyPoint(f) end
            f:Show()
            D.Render(id)
        elseif f then
            NS.Rows.ReleaseAll(f.rowPool)
            f:Hide()
        end
    end
    -- A sub-category docked back (R5-SM-09) is no id any more: its frame hides.
    for id, f in pairs(frames) do
        if not seen[id] and f:IsShown() then
            NS.Rows.ReleaseAll(f.rowPool)
            f:Hide()
        end
    end
    if G then G.Refresh(anchor) end
    NS.Blocks.UpdateSpeedWatch()
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end
end

--- Redraw the shown rows' values without moving anything (a bonus tick, combat).
function D.RefreshValues()
    local lookup
    for _, f in pairs(frames) do
        if f:IsShown() then
            lookup = lookup or NS.Blocks.Lookup(NS.Blocks.Data())
            NS.Rows.RefreshValues(f.rowPool, lookup)
        end
    end
    if NS.Groups then NS.Groups.RefreshValues() end
end

--- Stand-down: every detached frame hidden, its rows parked.
function D.StandDown()
    for _, f in pairs(frames) do
        NS.Rows.ReleaseAll(f.rowPool)
        f:Hide()
    end
    if NS.Groups then NS.Groups.StandDown() end
end

-- The equipped marker and the compact filter follow the equipment: a shown weapon block redraws.
-- A tracked bus target, stood down with the addon (LibKa0s-Bus-1.0).
local function onEquipmentChanged()
    -- The header's Equipped filter (round 5, R5-10): the main window's docked block now, not after
    -- the stats rescan's throttle.
    local s = settings("weapon")
    if s.docked ~= false and NS.Blocks.FilterOf("weapon") == "equipped" and NS.MainWindow then
        NS.MainWindow.Refresh()
    end
    local f = frames.weapon
    if f and f:IsShown() then
        D.Render("weapon")
        if NS.SecureOverlay then NS.SecureOverlay:Sync() end
    end
    -- Or its merged window's section (round 5).
    local gid = NS.Groups and NS.Groups.Of("weapon")
    local g = gid and NS.Groups.Frame(gid)
    if g and g:IsShown() then
        NS.Groups.Render(gid)
        if NS.SecureOverlay then NS.SecureOverlay:Sync() end
    end
end

D.events = NS.NewBusTarget()
if D.events then
    NS.SafeRegisterEvent(D.events, "PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged, NS.rejectedEvents)
end
