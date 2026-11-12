local addonName, NS = ...
-- modules/Chrome.lua — the small chrome every Skill Master surface shares: the title-bar and header
-- icon controls (standalone-windows: catalog marks at one size and one pitch, a plain glyph as the
-- fallback rung) and the hover tooltip line they carry.
--
-- NS.Chrome.IconButton(parent, icon, glyph, onClick, tip) -> button   (button.icon or button.glyph)
-- NS.Chrome.SetIcon(button, icon, glyph, turned)                       swap the mark (lock / unlock);
--                                                                      `turned` draws it rotated 180
--                                                                      degrees (the attach mark)
-- NS.Chrome.Snap(texture)                                              snap art to the pixel grid
-- NS.Chrome.MakeResizable(frame, spec) -> grip                         the one resize helper
-- NS.Chrome.TooltipFontSize(tip, size, first) / .RestoreTooltipFonts(tip)   a tooltip's lines at a
--                                                                      size (Tooltips page), and back

NS.Chrome = {}
local C = NS.Chrome

C.SIZE, C.ART = 18, 13   -- one size and one pitch for every control strip

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

local function onEnter(self)
    if self.icon then NS.Skin.Mark(self.icon, { token = "icon.hot" }) end
    if self.glyph then NS.Skin.Text(self.glyph, "accent") end
    showTip(self)
end

--- The mark's tint at rest: the button's own token (C.SetRestToken), else the skin's icon tint.
local function rest(b)
    return b.restToken and { token = b.restToken } or nil
end

local function onLeave(self)
    if self.icon then NS.Skin.Mark(self.icon, rest(self)) end
    if self.glyph then NS.Skin.Text(self.glyph, "muted") end
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
        b.icon:SetTexCoord(unpack(turned and C.TURNED or C.UPRIGHT))
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

--- Mark `b` hot (`icon.hot`) or at rest, as the pointer over it would: for a mark that takes no
--- mouse itself (a crafting row's hammer, under the row's secure overlay).
function C.SetHot(b, hot)
    if b.icon then NS.Skin.Mark(b.icon, hot and { token = "icon.hot" } or rest(b)) end
    if b.glyph then NS.Skin.Text(b.glyph, hot and "accent" or "muted") end
end

--- One square control: the catalog mark (or the glyph), the skin's tint at rest and hot under the
--- pointer, `tip` as a one-line tooltip, `onClick(button, mouseButton)`.
function C.IconButton(parent, icon, glyph, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(C.SIZE, C.SIZE)
    b:RegisterForClicks("AnyUp")
    b.tip = tip
    C.SetIcon(b, icon, glyph)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
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
