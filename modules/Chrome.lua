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
-- NS.Chrome.PinTopLeft(frame)                                         re-anchor by the top-left corner
-- NS.Chrome.TitleBar(frame) -> frame / .StripOffset(strip) -> px       the bar a mode strip docks
--                                                                      under, and the body's shift
-- NS.Chrome.TitleBottom(frame) -> px                                   the band's bottom, read from it
-- NS.Chrome.Footer(frame, opts) -> frame / .FooterHeight() -> px       a window's footer (Widgets')
-- NS.Chrome.TitleMarks(frame, spec) -> hb                              a window's title-bar marks
--                                                                      (Widgets' HeaderButtons)
-- NS.Chrome.HeaderPitch() -> pad, gap / .SetTip(button, words)         the strip's pitch; a mark's words
-- NS.Chrome.TooltipFontSize(tip, size, first) / .RestoreTooltipFonts(tip)   a tooltip's lines at a
--                                                                      size (Tooltips page), and back
-- NS.Chrome.PlaceBeside(tip, el, group) / .PlaceAttached(tip, el)    where a shown tooltip opens:
--   / .PlaceLauncher(tip, cell)                                        beside the window group (a body
--                                                                      element), above the control (a
--                                                                      chrome one), toward the screen's
--                                                                      center (the broker feed's cell)
-- NS.Chrome.MakeEdges(frame, layer) -> edges / .PaintEdges(edges, c)   a frame's four 1 px edges
-- NS.Chrome.PaintBorder(frame, s)                                      a frame's border from { border,
--                                                                      borderStyle, borderSize }: the
--                                                                      edges for Solid, an LSM border
--                                                                      on a backdrop child otherwise
--                                                                      (re-homed from modules/Bar.lua,
--                                                                      AD-80-SM: the icon well, the
--                                                                      detached frame, the snap ghost)

NS.Chrome = {}
local C = NS.Chrome

-- ---------------------------------------------------------------------------------------------
-- A frame's edges and border (the bars draw theirs through LibKa0s-Widgets-1.0's Bar)
-- ---------------------------------------------------------------------------------------------

local EDGE = 1   -- an edge's default width, UI units
local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

--- Four 1 px edge textures on `frame`, answered as a list (TOP, BOTTOM, LEFT, RIGHT).
function C.MakeEdges(frame, layer)
    local edges = {}
    for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = frame:CreateTexture(nil, layer or "BORDER")
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT", frame, side .. "LEFT", 0, 0)
            t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", 0, 0)
            t:SetHeight(EDGE)
        else
            t:SetPoint("TOP" .. side, frame, "TOP" .. side, 0, 0)
            t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, 0, 0)
            t:SetWidth(EDGE)
        end
        edges[i] = t
    end
    return edges
end

--- Color the edges, or hide them for a nil color.
function C.PaintEdges(edges, c)
    for _, t in ipairs(edges) do
        if c then
            t:SetColorTexture(rgba(c))
            t:Show()
        else
            t:Hide()
        end
    end
end

--- The media path for an LSM key, or nil (no LibSharedMedia, an unknown key).
function C.Media(kind, key)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not (LSM and type(key) == "string" and key ~= "") then return nil end
    local ok, path = pcall(LSM.Fetch, LSM, kind, key, true)
    return ok and path or nil
end

--- `frame`'s border (`frame.edges`, from C.MakeEdges): the four edges at `borderSize` px for a
--- Solid style, else the LSM border drawn by a backdrop child (made on first use), else nothing.
function C.PaintBorder(frame, s)
    local path = s.border and s.borderStyle ~= "Solid" and C.Media("border", s.borderStyle) or nil
    local size = s.borderSize or EDGE
    for i, t in ipairs(frame.edges) do
        if i <= 2 then t:SetHeight(size) else t:SetWidth(size) end
    end
    C.PaintEdges(frame.edges, (s.border and not path) and s.border or nil)
    if not (path or frame.edgeFrame) then return end
    local f = frame.edgeFrame
    if not f then
        f = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        f:SetAllPoints(frame)
        frame.edgeFrame = f
    end
    f:SetShown(path ~= nil)
    if path and f.SetBackdrop then
        f:SetBackdrop({ edgeFile = path, edgeSize = size })
        f:SetBackdropBorderColor(rgba(s.border))
    end
end

C.SIZE, C.ART = 18, 13   -- one size and one pitch for every control strip

-- Every title-bar and header-strip mark's colors (smoke round 1 of the LibKa0s v1.105.0 run,
-- ruling 4, SR-L3): `icon.tint` at rest, as the library's close X (`close.rest` follows it) and its
-- own header marks; `text.link` under the pointer. A control that is no title-bar mark (a row's
-- action mark) names its own hot token (button.hotToken). The filled badge's square is the mark's
-- rest color, so a narrowing filter still reads as a state.
C.REST, C.HOT = "icon.tint", "text.link"

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

-- The hover tooltip (ruling 3, SR-L2): LibKa0s-Tooltip-1.0's AttachTitleTip, the library's own
-- title-bar tooltip: one line, `button.tip` read on each hover, in the owner's `gtip.title`, placed
-- above the control by PlaceAttached (below only without room). Without the library, the game's
-- tooltip attached centered above the control (attachAbove).
local function tipWords(self) return self.tip end

-- ---------------------------------------------------------------------------------------------
-- Where a tooltip opens (LibKa0s#92, AD-92-SM; WowAddonStandards standalone-windows, *Tooltip
-- placement*, and launcher-§7). Every tooltip this addon places itself is owned at ANCHOR_NONE,
-- filled, shown (so its size is known) and then placed by one of these, which read
-- LibKa0s-Tooltip-1.0 at call time:
--   PlaceBeside    a BODY element (a row, a card, a column header, the HUD arrow): beside the
--                  window group, right when it fits and otherwise left, top level with the element,
--                  TIP_GAP out; `group` nil is the library's GroupOf (the outermost frame under
--                  UIParent: the window, the detached or merged HUD, the broker panel);
--   PlaceAttached  a CHROME element (a modal's action button): centered above it, below it only
--                  without room above;
--   PlaceLauncher  the broker feed's own tooltip on its display cell: toward the screen's center,
--                  TIP_GAP off the cell (the launcher shape, launcher-§7).
-- With the library absent, or the geometry unreadable (a placer answers nil, nothing placed), the
-- tooltip attaches centered above its element by a relative point, as the library's own fallback
-- does. Never the cursor, never a corner offset.
-- ---------------------------------------------------------------------------------------------

C.TIP_GAP = 2

local function tipLib()
    local Tip = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    return type(Tip) == "table" and type(Tip.PlaceBeside) == "function" and Tip or nil
end

local function attachAbove(tip, el)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOM", el, "TOP", 0, C.TIP_GAP)
end

--- Place the shown `tip` for the body element `el`, beside its window group (`group` as
--- LibKa0s-Tooltip-1.0's PlaceBeside takes it; nil is GroupOf(el)).
function C.PlaceBeside(tip, el, group)
    local Tip = tipLib()
    if Tip and Tip.PlaceBeside(tip, el, group) then return end
    attachAbove(tip, el)
end

--- Place the shown `tip` for the chrome element `el`, centered above it.
function C.PlaceAttached(tip, el)
    local Tip = tipLib()
    if Tip and type(Tip.PlaceAttached) == "function" and Tip.PlaceAttached(tip, el) then return end
    attachAbove(tip, el)
end

--- Place `tip` on the broker display's cell, toward the screen's center; answers true when the
--- library placed it (false: the caller keeps its own attached anchor).
function C.PlaceLauncher(tip, cell)
    local Tip = tipLib()
    return (Tip and type(Tip.PlaceLauncher) == "function" and Tip.PlaceLauncher(tip, cell)) and true or false
end

-- Without the library: the game's tooltip, owned at ANCHOR_NONE, attached centered above the mark.
local function showTip(self)
    if not (self.tip and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetText(self.tip)
    GameTooltip:Show()
    attachAbove(GameTooltip, self)
end

local function hideTip(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function titleTipLib()
    local Tip = LibStub and LibStub("LibKa0s-Tooltip-1.0", true)
    return Tip and type(Tip.AttachTitleTip) == "function" and Tip or nil
end

--- The mark's tint at rest: on a badge the header's background, else the button's own token
--- (C.SetRestToken), else the skin's icon tint.
local function rest(b)
    if b.badgeToken then return { token = C.BADGE_INK_TOKEN } end
    return { token = b.restToken or C.REST }
end

local function hotToken(b) return b.hotToken or C.HOT end

--- Paint `b` hot (under the pointer) or at rest. A badged mark lights its square and keeps the mark
--- dark on it, so it stays readable; any other mark lights itself.
local function paint(b, isHot)
    if b.badgeToken and b.badge then
        -- The square's fill read through the seam at each paint (a skin switch repaints every header).
        local r, g, bl, a = NS.Skin.Color(isHot and hotToken(b) or b.badgeToken)
        if r then b.badge:SetColorTexture(r, g, bl, a or 1) end
        if b.icon then NS.Skin.Mark(b.icon, rest(b)) end
    elseif b.icon then
        NS.Skin.Mark(b.icon, isHot and { token = hotToken(b) } or rest(b))
    end
    if b.glyph then NS.Skin.Text(b.glyph, isHot and hotToken(b) or (b.restToken or C.REST)) end
end

local function onEnter(self)
    paint(self, true)
    if not titleTipLib() then showTip(self) end
end

local function onLeave(self)
    paint(self, false)
    if not titleTipLib() then hideTip(self) end
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
    if b.label and not b.glyph then   -- a library mark drawn as its word: the word changes
        b.label:SetText(glyph or "?")
        return
    end
    if not b.glyph then
        b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    end
    b.glyph:SetText(glyph or "?")
    b.glyph:Show()
    NS.Skin.Text(b.glyph, b.restToken or C.REST)
end

--- Tint `b`'s mark with skin token `token` at rest (the block header's detach mark takes the
--- title's `text.heading` until smoke round 1's ruling 4); under the pointer it is C.HOT. nil goes
--- back to C.REST, `icon.tint`.
function C.SetRestToken(b, token)
    b.restToken = token
    if b.icon then NS.Skin.Mark(b.icon, rest(b)) end
end

--- The filled badge on `b` (owner feedback round 8, R8-2): with `token`, a solid C.BADGE_SIZE square
--- in that skin token under the mark, the mark refitted to C.BADGE_INK and drawn in the header's
--- background (C.BADGE_INK_TOKEN); under the pointer the square is C.HOT. nil takes it off:
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

--- Mark `b` hot (its hot token) or at rest, as the pointer over it would: for a mark that takes no
--- mouse itself (a crafting row's hammer, under the row's secure overlay).
function C.SetHot(b, isHot)
    paint(b, isHot)
end

--- One square control: the catalog mark (or the glyph), the skin's tint at rest and hot under the
--- pointer, `tip` as a one-line tooltip (read on each hover), `onClick(button, mouseButton)`.
local function newButton(parent, icon, glyph, onClick, tip, fit)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(C.SIZE, C.SIZE)
    b:RegisterForClicks("AnyUp")
    b.tip = tip
    b.fit = fit
    C.SetIcon(b, icon, glyph)
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    local Tip = titleTipLib()
    if Tip then Tip.AttachTitleTip(b, tipWords, addonName) end
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
-- A window's title-bar marks (AD-86-SM, LibKa0s#86; standalone-windows, *Title-bar controls*):
-- LibKa0s Widgets' HeaderButtons, right-aligned, left to right the window's own extras, then
-- settings, then close, one 18 px slot, PAD (6) from the corner and GAP (6) apart, painted by the
-- library's one path (`icon.tint` at rest, `text.link` under the pointer, the close's own pair).
-- The settings mark opens this addon's settings through the opener the launcher registered
-- (core/LauncherSetup.lua's `openSettings`, read by LibKa0s-Core-1.0's OpenSettings), and the close
-- is built through the one wrapper, NS.MakeCloseButton. Each mark keeps `button.tip`, the words its
-- callers and suites read, beside the library's `__tip`; C.SetTip writes both.
-- ---------------------------------------------------------------------------------------------

-- An 18 px mark centered on the 30 px band 1 px in: 1 + (30 - 18) / 2 below the window's top. The
-- skin's Header places the marks again on its band; this is where they stand without one.
C.TITLE_MARK_Y = -7

--- The strip's corner inset and gap: Widgets' HEADER, the same figures with no library.
function C.HeaderPitch()
    local H = NS.Widgets and NS.Widgets.HEADER
    return (H and tonumber(H.PAD)) or 6, (H and tonumber(H.GAP)) or 6
end

--- A mark's tooltip words, read on each hover by this module's marks (`tip`) and the library's (`__tip`).
function C.SetTip(b, words)
    if not b then return end
    b.tip, b.__tip = words, words
end

--- The settings click without the library: hide `hideOnSettings` first, then the window's own
--- opener, else the options panel.
local function plainSettings(spec)
    return function()
        local hide = spec.hideOnSettings
        if hide and hide.Hide then hide:Hide() end
        if type(spec.settings) == "function" then return spec.settings() end
        if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
    end
end

--- The strip's entries outermost first: close, settings, then the extras from the innermost out.
local function plainList(frame, spec, hb)
    local list = {}
    if spec.close ~= false then
        hb.close = NS.MakeCloseButton(frame, spec.close or function() frame:Hide() end)
        if hb.close then list[1] = { key = "close", btn = hb.close } end
    end
    if spec.settings ~= false then
        hb.settings = C.IconButton(frame, "settings", "S", plainSettings(spec), spec.settingsTip)
        list[#list + 1] = { key = "settings", btn = hb.settings }
    end
    local extras = spec.extras or {}
    for i = #extras, 1, -1 do
        local x = extras[i]
        local b = C.IconButton(frame, x.icon, x.glyph, x.onClick, x.tip)
        hb.extras[x.key] = b
        list[#list + 1] = { key = x.key, btn = b }
    end
    return list
end

--- The same strip with no Widgets library: this module's marks, placed from the same corner at the
--- same pitch, answering the library's shape.
local function plainMarks(frame, spec)
    local pad, gap = C.HeaderPitch()
    local hb = { extras = {}, order = {}, offsets = {}, right = {} }
    local list = plainList(frame, spec, hb)
    local off = pad
    for _, e in ipairs(list) do
        e.btn:SetPoint(spec.point, frame, spec.point, -off, spec.y)
        hb.offsets[e.key] = -off
        hb.right[#hb.right + 1] = { frame = e.btn, x = off }
        off = off + C.SIZE + gap
    end
    for i = #list, 1, -1 do hb.order[#hb.order + 1] = list[i].key end
    frame.headerButtons = hb
    return hb
end

--- Build `frame`'s title-bar marks. spec = {
---   close = fn | false,            the close's click (false: the window has none)
---   settings = nil | fn | false,   nil: the launcher's opener; false needs `settingsOptOut`
---   settingsOptOut, hideOnSettings, settingsTip,
---   extras = { { key, icon, glyph, tip, onClick }, ... },   left to right, inward of settings
---   level = n,                     each mark's frame level over the window's (LAYERS.LEVEL.CHROME)
---   point, y                       the corner the marks stand in before the skin's Header places
---                                  them on its band (TOPRIGHT, C.TITLE_MARK_Y)
--- }
--- Answers HeaderButtons' `hb` (also `frame.headerButtons`): `hb.right` is what NS.Skin.Header takes.
function C.TitleMarks(frame, spec)
    local full = {
        owner = addonName, frame = frame, point = spec.point or "TOPRIGHT", y = spec.y or C.TITLE_MARK_Y,
        makeClose = NS.MakeCloseButton, close = spec.close, settings = spec.settings,
        settingsOptOut = spec.settingsOptOut, hideOnSettings = spec.hideOnSettings,
        settingsTip = spec.settingsTip, extras = spec.extras,
    }
    local W = NS.Widgets
    local hb
    if W and type(W.HeaderButtons) == "function" then hb = W.HeaderButtons(frame, full) else hb = plainMarks(frame, full) end
    if spec.settingsTip then C.SetTip(hb.settings, spec.settingsTip) end
    for _, x in ipairs(spec.extras or {}) do C.SetTip(hb.extras[x.key], x.tip) end
    if spec.level then
        local level = frame:GetFrameLevel() + spec.level
        for _, e in ipairs(hb.right) do e.frame:SetFrameLevel(level) end
    end
    return hb
end

-- ---------------------------------------------------------------------------------------------
-- The title bar a mode strip docks under (AD-88-SM, LibKa0s#88; preview-mode, *Where the strip
-- sits*): LibKa0s Widgets' TestStrip with `dock = "title"` anchors itself under the frame it is
-- handed, full width, and places itself again on every show, hide and resize. Each window hands it
-- the skin's title band (S.Band), the frame the skin lays where it paints the bar in every skin, so
-- the strip sits under the bar the player sees. What sits below the bar starts C.TitleBottom(frame)
-- under the window's top edge, plus the strip's BodyOffset while one shows, plus the window's own gap.
-- ---------------------------------------------------------------------------------------------

-- The title band's bottom edge below the window's top when no band is measured (no skin library, or
-- a band not yet laid): the 1 px inset plus `title.height`, 30 px. A host copies no band height
-- (standalone-windows, *Window chrome geometry*): C.TitleBottom reads the band where the skin lays it.
C.TITLE_BOTTOM = 31

--- The window's title bar as a frame: the skin's band, or with no skin library a bare frame of the
--- same rect (1 px in, C.TITLE_BOTTOM - 1 tall) that draws nothing and takes no mouse.
function C.TitleBar(frame)
    local band = NS.Skin.Band and NS.Skin.Band(frame)
    if type(band) == "table" then return band end
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    bar:SetHeight(C.TITLE_BOTTOM - 1)
    bar:EnableMouse(false)
    return bar
end

--- The title band's bottom edge below `frame`'s top now: the band's height plus its inset, read from
--- `frame.titleBar` as the skin laid it (S.Band sits `win.borderSize` in for a flat border, 1 px for
--- the others; modules/Detached.lua's D.TitleHeight reads its band the same way). C.TITLE_BOTTOM
--- while no band is measured: no window, no title bar, or a band that answers no height yet.
function C.TitleBottom(frame)
    local band = type(frame) == "table" and frame.titleBar
    if not (type(band) == "table" and band.GetHeight and band.GetPoint) then return C.TITLE_BOTTOM end
    local h = tonumber(band:GetHeight()) or 0
    if h <= 0 then return C.TITLE_BOTTOM end
    local y = select(5, band:GetPoint(1))   -- the band's inset below the window's top edge
    return h + math.abs(tonumber(y) or 0)
end

--- The window footer's height, read where the library publishes it (Widgets' FOOTER.HEIGHT, 24 px
--- under every skin; standalone-windows, *Window chrome geometry*), the same figure with no library.
function C.FooterHeight()
    local F = NS.Widgets and NS.Widgets.FOOTER
    return (F and tonumber(F.HEIGHT)) or 24
end

--- A window's footer (standalone-windows, *The footer*; AD-89-SM, LibKa0s#89): LibKa0s Widgets'
--- Footer across `frame`'s bottom edge, no fill, the skin's `divider` hairline along its top, painted
--- for this addon's skin owner. `opts` = { left = text, grip = bool } (`grip`: its right side clears
--- the resize grip's corner). With no library, a bare frame of C.FooterHeight() and no hairline, its
--- `left` line in the muted text role and `foot:SetLeft(text)` as the library's.
function C.Footer(frame, opts)
    opts = opts or {}
    local W = NS.Widgets
    local foot = W and W.Footer and W.Footer(frame, { owner = addonName, left = opts.left, grip = opts.grip })
    if foot then return foot end
    foot = CreateFrame("Frame", nil, frame)
    foot:SetHeight(C.FooterHeight())
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    foot.left = foot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    foot.left:SetPoint("LEFT", foot, "LEFT", 8, 0)
    foot.left:SetPoint("RIGHT", foot, "RIGHT", opts.grip and -22 or -8, 0)
    foot.left:SetJustifyH("LEFT")
    foot.left:SetWordWrap(false)
    NS.Skin.Text(foot.left, "muted")
    foot.SetLeft = function(self, text) self.left:SetText(type(text) == "string" and text or "") end
    foot:SetLeft(opts.left)
    return foot
end

--- How far a docked strip moves the body down now: its BodyOffset while it shows, else 0 (an
--- undocked or absent strip, the library missing, moves nothing).
function C.StripOffset(strip)
    if not (strip and type(strip.BodyOffset) == "function") then return 0 end
    return tonumber(strip:BodyOffset()) or 0
end

-- ---------------------------------------------------------------------------------------------
-- The one resize helper (standalone-windows, Resizing): every resizable window hands it its cheap
-- layout and its full redraw. A size change only marks the layout dirty, and one pass runs on the
-- next rendered frame (a driver's one-shot OnUpdate), however many OnSizeChanged calls came in.
-- The full redraw and the save run once, on the grip's release (LibKa0s's onResizeStop).
-- ---------------------------------------------------------------------------------------------

--- Pin `frame` by its top-left corner where it stands (FB-33). The client sizes a frame about its
--- anchor: by its CENTER (a window's default place) it grew two pixels a pixel and leapt. Pinned, the
--- grip's corner follows the cursor. GetLeft / GetTop answer in the units SetPoint takes. A grab's
--- canResize calls it (the Journal, the main window).
function C.PinTopLeft(frame)
    local left, top = tonumber(frame:GetLeft()), tonumber(frame:GetTop())
    if not (left and top) then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

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
