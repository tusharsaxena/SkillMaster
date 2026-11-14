local addonName, NS = ...
-- modules/Chrome.lua — the small chrome every Skill Master surface shares: the title-bar and header
-- icon controls (standalone-windows: catalog marks at one size and one pitch, a plain glyph as the
-- fallback rung) and the hover tooltip line they carry.
--
-- NS.Chrome.IconButton(parent, icon, glyph, onClick, tip) -> button   (button.icon or button.glyph)
-- NS.Chrome.HeaderMark(parent, icon, glyph, onClick, tip) -> button    the same, its art fitted to
--                                                                      one ink box (C.INK_SIZE)
-- NS.Chrome.SetIcon(button, icon, glyph, turned)                       swap the mark (lock / unlock);
--                                                                      `turned` draws it rotated 180
--                                                                      degrees (the attach mark)
-- NS.Chrome.SetBadge(button, token)                                    the filled badge: a solid square
--                                                                      in `token` behind the mark, the
--                                                                      mark in the header's background
--                                                                      (nil takes it off; round 8, R8-2)
-- NS.Chrome.Snap(texture)                                              snap art to the pixel grid
-- NS.Chrome.MakeResizable(frame, spec) -> grip                         the one resize helper
-- NS.Chrome.TooltipFontSize(tip, size, first) / .RestoreTooltipFonts(tip)   a tooltip's lines at a
--                                                                      size (Tooltips page), and back

NS.Chrome = {}
local C = NS.Chrome

C.SIZE, C.ART = 18, 13   -- one size and one pitch for every control strip

-- A block header's marks (owner feedback round 6, R6-3): each catalog mark leaves its own margin in
-- its 64 px square (the funnel 52 x 48 at the square's lower middle, the list mark 64 x 56 at its
-- top, external-link the whole square), so drawn at one texture size they read at different sizes
-- and heights. A header mark (C.HeaderMark) is cropped to its ink box, measured here from the
-- shipped art (tests/test_round6.lua checks every box against the file), and drawn with its longer
-- side C.INK_SIZE px, centered on its control: every mark one size and one vertical center.
C.INK_SIZE = 12
C.INK = {   -- [mark] = { left, top, right, bottom } in the art's 64 px square
    ["chevron-down"] = { 0, 8, 64, 52 },  ["chevron-right"] = { 8, 0, 52, 64 },
    ["external-link"] = { 0, 0, 64, 64 }, ["fullscreen-enter"] = { 0, 0, 64, 64 },
    eye = { 0, 8, 64, 56 },               list = { 0, 0, 64, 56 },
    ["sort-desc"] = { 0, 0, 64, 64 },     ["sort-asc"] = { 0, 0, 64, 64 },
    ["ph:sort-descending"] = { 8, 8, 56, 56 }, ["ph:funnel"] = { 6, 10, 58, 58 },
}
local INK_SQUARE = 64

-- The filled badge (owner feedback round 8, R8-2: an active filter, the mockup's option 1): a solid
-- square in the mark's own rest color under the mark, the mark drawn on it in the window's background
-- (`win.bg`, what shows through the header's translucent fill), inset so the square reads as the
-- mark's footprint: BADGE_SIZE inside the C.SIZE control, the mark's longer side BADGE_INK.
C.BADGE_SIZE, C.BADGE_INK, C.BADGE_INK_TOKEN = 16, 10, "win.bg"

-- ---------------------------------------------------------------------------------------------
-- A tooltip's font size (the Tooltips page, owner feedback round 4). GameTooltip's line font strings
-- are the game's, shared with every addon: each one sized here keeps its own face, size and flags
-- to go back to, and RestoreTooltipFonts puts them back when the tooltip clears or hides.
-- ---------------------------------------------------------------------------------------------

local savedFonts = setmetatable({}, { __mode = "k" })   -- [tip] = { [fontString] = { face, size, flags } }

--- Lines `first`..last of `tip` (both sides) at `size`, the first line (its title) 2 px larger when
--- `first` is 1. A size that is not a number, or a font string without fonts, is left alone.
function C.TooltipFontSize(tip, size, first)
    size = tonumber(size)
    local name = tip and tip.GetName and tip:GetName()
    if not (size and name) then return end
    local saved = savedFonts[tip] or {}
    savedFonts[tip] = saved
    for n = first or 1, tonumber(tip.NumLines and tip:NumLines()) or 0 do
        for _, side in ipairs({ "TextLeft", "TextRight" }) do
            local fs = _G[name .. side .. n]
            local face, was, flags
            if fs and fs.GetFont and fs.SetFont then face, was, flags = fs:GetFont() end
            if face then
                if not saved[fs] then saved[fs] = { face, was, flags } end
                fs:SetFont(face, n == 1 and size + 2 or size, flags)
            end
        end
    end
end

--- Every line `tip` had sized back at its own font.
function C.RestoreTooltipFonts(tip)
    local saved = tip and savedFonts[tip]
    if not saved then return end
    for fs, f in pairs(saved) do fs:SetFont(f[1], f[2], f[3]) end
    savedFonts[tip] = nil
end

local function showTip(self)
    if not (self.tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.tip)
    GameTooltip:Show()
end

local function hideTip(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

--- The mark's tint at rest: on a badge the header's background, else the button's own token
--- (C.SetRestToken), else the skin's icon tint.
local function rest(b)
    if b.badgeToken then return { token = C.BADGE_INK_TOKEN } end
    return b.restToken and { token = b.restToken } or nil
end

--- Paint `b` hot (under the pointer) or at rest. A badged mark lights its square and keeps the mark
--- dark on it, so it stays readable; any other mark lights itself.
local function paint(b, hot)
    if b.badgeToken and b.badge then
        -- The square's fill read through the seam at each paint (a skin switch repaints every header).
        local r, g, bl, a = NS.Skin.Color(hot and "icon.hot" or b.badgeToken)
        if r then b.badge:SetColorTexture(r, g, bl, a or 1) end
        if b.icon then NS.Skin.Mark(b.icon, rest(b)) end
    elseif b.icon then
        NS.Skin.Mark(b.icon, hot and { token = "icon.hot" } or rest(b))
    end
    if b.glyph then NS.Skin.Text(b.glyph, hot and "accent" or "muted") end
end

local function onEnter(self)
    paint(self, true)
    showTip(self)
end

local function onLeave(self)
    paint(self, false)
    hideTip(self)
end

-- The texture coordinates (left, right, top, bottom): upright, and turned 180 degrees (both axes
-- flipped). The attach mark is the detach mark turned: its arrow points to the bottom left, out of
-- the box's cutout there (owner feedback round 2, FB-15).
C.UPRIGHT, C.TURNED = { 0, 1, 0, 1 }, { 1, 0, 1, 0 }

--- Snap `tex` to the physical pixel grid (round 5, R5-5). The 13 px art sits centered in the 18 px
--- control, 2.5 px in, so where it falls on the screen's pixels follows the frame's own position: the
--- main window's marks happened to land on the grid, a detached frame's (dropped anywhere) half a
--- pixel off, and the art's 1-texel strokes straddled two pixels at half intensity (the owner's
--- screenshots). Snapped, every mark draws crisp wherever its window stands.
function C.Snap(tex)
    if type(tex.SetSnapToPixelGrid) == "function" then tex:SetSnapToPixelGrid(true) end
    if type(tex.SetTexelSnappingBias) == "function" then tex:SetTexelSnappingBias(0) end
end

--- A header mark's art (C.HeaderMark): `icon` cropped to its ink box (C.INK, the whole square for a
--- mark it does not list), its longer side `size` (C.INK_SIZE), turned 180 degrees with `turned`.
local function fitInk(tex, icon, turned, size)
    local box = C.INK[icon] or { 0, 0, INK_SQUARE, INK_SQUARE }
    local l, t, r, btm = box[1] / INK_SQUARE, box[2] / INK_SQUARE, box[3] / INK_SQUARE, box[4] / INK_SQUARE
    local w, h = r - l, btm - t
    local scale = (size or C.INK_SIZE) / math.max(w, h)
    tex:SetSize(w * scale, h * scale)
    if turned then tex:SetTexCoord(r, l, btm, t) else tex:SetTexCoord(l, r, t, btm) end
end

--- Draw `icon` (a declared catalog name) on the button, or `glyph` where the art does not resolve.
--- `turned` draws the mark rotated 180 degrees; a pooled button set upright again is reset.
function C.SetIcon(b, icon, glyph, turned)
    local path = icon and NS.Icon(icon)
    if path then
        if not b.icon then
            b.icon = b:CreateTexture(nil, "OVERLAY")
            b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.icon:SetSize(C.ART, C.ART)
            C.Snap(b.icon)
        end
        b.icon:SetTexture(path)
        b.iconName, b.turned = icon, turned
        if b.fit then
            fitInk(b.icon, icon, turned, b.badgeToken and C.BADGE_INK or C.INK_SIZE)
        else
            b.icon:SetTexCoord(unpack(turned and C.TURNED or C.UPRIGHT))
        end
        NS.Skin.Mark(b.icon, rest(b))
        if b.glyph then b.glyph:Hide() end
        return
    end
    if not b.glyph then
        b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    b.glyph:SetText(glyph or "?")
    b.glyph:Show()
    NS.Skin.Text(b.glyph, "muted")
end

--- Tint `b`'s mark with skin token `token` at rest (the block header's detach mark takes the
--- title's `text.heading`); under the pointer it is `icon.hot` as ever. nil goes back to `icon.tint`.
function C.SetRestToken(b, token)
    b.restToken = token
    if b.icon then NS.Skin.Mark(b.icon, rest(b)) end
end

--- The filled badge on `b` (owner feedback round 8, R8-2): with `token`, a solid C.BADGE_SIZE square
--- in that skin token under the mark, the mark refitted to C.BADGE_INK and drawn in the header's
--- background (C.BADGE_INK_TOKEN); under the pointer the square is `icon.hot`. nil takes it off:
--- the mark at its own size and rest tint again. A mark drawn as a glyph (no art) wears no badge.
function C.SetBadge(b, token)
    if not b.icon then token = nil end
    b.badgeToken = token
    if token and not b.badge then
        b.badge = b:CreateTexture(nil, "ARTWORK")
        b.badge:SetPoint("CENTER", b, "CENTER", 0, 0)
        b.badge:SetSize(C.BADGE_SIZE, C.BADGE_SIZE)
        C.Snap(b.badge)
    end
    if b.badge then b.badge:SetShown(token ~= nil) end
    if b.icon and b.fit and b.iconName then
        fitInk(b.icon, b.iconName, b.turned, token and C.BADGE_INK or C.INK_SIZE)
    end
    paint(b, false)
end

--- Mark `b` hot (`icon.hot`) or at rest, as the pointer over it would: for a mark that takes no
--- mouse itself (a crafting row's hammer, under the row's secure overlay).
function C.SetHot(b, hot)
    paint(b, hot)
end

--- One square control: the catalog mark (or the glyph), the skin's tint at rest and hot under the
--- pointer, `tip` as a one-line tooltip, `onClick(button, mouseButton)`.
local function newButton(parent, icon, glyph, onClick, tip, fit)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(C.SIZE, C.SIZE)
    b:RegisterForClicks("AnyUp")
    b.tip = tip
    b.fit = fit
    C.SetIcon(b, icon, glyph)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function C.IconButton(parent, icon, glyph, onClick, tip)
    return newButton(parent, icon, glyph, onClick, tip, nil)
end

--- A block header's mark (round 6, R6-3): an IconButton whose art is fitted to its ink box, so every
--- header mark (the window's header, a detached or merged window's band, a section's sub-header)
--- draws at one size and one vertical center whatever margin its art leaves.
function C.HeaderMark(parent, icon, glyph, onClick, tip)
    return newButton(parent, icon, glyph, onClick, tip, true)
end

-- ---------------------------------------------------------------------------------------------
-- The one resize helper (standalone-windows, Resizing): every resizable window hands it its cheap
-- layout and its full redraw. A size change only marks the layout dirty, and one pass runs on the
-- next rendered frame (a driver's one-shot OnUpdate), however many OnSizeChanged calls came in.
-- The full redraw and the save run once, on the grip's release (LibKa0s's onResizeStop).
-- ---------------------------------------------------------------------------------------------

--- spec = { minWidth, minHeight, layout = fn(w, h), redraw = fn(), save = fn(w, h), canResize = fn(frame) }
--- Answers the grip (frame.resizeGrip), or nil where the library offers none. frame.resizeDriver
--- is the frame whose OnUpdate runs the coalesced pass.
function C.MakeResizable(frame, spec)
    local driver = CreateFrame("Frame", nil, frame)
    local pending = false
    local function pass(self)
        self:SetScript("OnUpdate", nil)
        pending = false
        spec.layout(frame:GetWidth(), frame:GetHeight())
    end
    local function mark()
        if pending then return end
        pending = true
        driver:SetScript("OnUpdate", pass)
    end
    local function stop(w, h)
        driver:SetScript("OnUpdate", nil)
        pending = false
        spec.layout(w, h)
        spec.redraw()
        if spec.save then spec.save(w, h) end
    end
    frame.resizeDriver = driver
    return NS.MakeResizable(frame, {
        minWidth = spec.minWidth, minHeight = spec.minHeight,
        onResize = mark, onResizeStop = stop, canResize = spec.canResize, owner = addonName,
    })
end
