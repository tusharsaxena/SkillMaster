local addonName, NS = ...
-- modules/Chrome.lua — the small chrome every Skill Master surface shares: the title-bar and header
-- icon controls (standalone-windows: catalog marks at one size and one pitch, a plain glyph as the
-- fallback rung) and the hover tooltip line they carry.
--
-- NS.Chrome.IconButton(parent, icon, glyph, onClick, tip) -> button   (button.icon or button.glyph)
-- NS.Chrome.SetIcon(button, icon, glyph, turned)                       swap the mark (lock / unlock);
--                                                                      `turned` draws it rotated 180
--                                                                      degrees (the attach mark)
-- NS.Chrome.MakeResizable(frame, spec) -> grip                         the one resize helper

NS.Chrome = {}
local C = NS.Chrome

C.SIZE, C.ART = 18, 13   -- one size and one pitch for every control strip

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

local function onLeave(self)
    if self.icon then NS.Skin.Mark(self.icon) end
    if self.glyph then NS.Skin.Text(self.glyph, "muted") end
    hideTip(self)
end

-- The texture coordinates (left, right, top, bottom): upright, and turned 180 degrees (both axes
-- flipped). The attach mark is the detach mark turned: its arrow points to the bottom left, out of
-- the box's cutout there (owner feedback round 2, FB-15).
C.UPRIGHT, C.TURNED = { 0, 1, 0, 1 }, { 1, 0, 1, 0 }

--- Draw `icon` (a declared catalog name) on the button, or `glyph` where the art does not resolve.
--- `turned` draws the mark rotated 180 degrees; a pooled button set upright again is reset.
function C.SetIcon(b, icon, glyph, turned)
    local path = icon and NS.Icon(icon)
    if path then
        if not b.icon then
            b.icon = b:CreateTexture(nil, "OVERLAY")
            b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.icon:SetSize(C.ART, C.ART)
        end
        b.icon:SetTexture(path)
        b.icon:SetTexCoord(unpack(turned and C.TURNED or C.UPRIGHT))
        NS.Skin.Mark(b.icon)
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
