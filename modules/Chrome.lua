local _, NS = ...
-- modules/Chrome.lua — the small chrome every Skill Master surface shares: the title-bar and header
-- icon controls (standalone-windows: catalog marks at one size and one pitch, a plain glyph as the
-- fallback rung) and the hover tooltip line they carry.
--
-- NS.Chrome.IconButton(parent, icon, glyph, onClick, tip) -> button   (button.icon or button.glyph)
-- NS.Chrome.SetIcon(button, icon, glyph)                               swap the mark (lock / unlock)

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

--- Draw `icon` (a declared catalog name) on the button, or `glyph` where the art does not resolve.
function C.SetIcon(b, icon, glyph)
    local path = icon and NS.Icon(icon)
    if path then
        if not b.icon then
            b.icon = b:CreateTexture(nil, "OVERLAY")
            b.icon:SetPoint("CENTER", b, "CENTER", 0, 0)
            b.icon:SetSize(C.ART, C.ART)
        end
        b.icon:SetTexture(path)
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
