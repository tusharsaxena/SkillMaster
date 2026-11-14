local _, NS = ...
-- modules/Bar.lua — the skill/stat data bar (plan Task 3.1, design §6.2/§6.3): a base fill, a bonus
-- segment past it in its own color (temp or permanent), threshold markers, a spark, the fill split
-- into one color per rank tier (Rank tier colors, on a scale to the last tier),
-- the "rank +bonus / max" text and an optional expiry timer. Drawn on the skin's tokens
-- (core/SkinSetup.lua owner tokens, the bar texture through S.BarTexture) and pooled (NS.Pool).
--
-- Interface (the main window, the detached blocks, the row tooltip, and later the journal and the
-- broker tooltip all draw through it):
--   NS.Bar.Create(parent, styleKey) -> bar           styleKey: "row" | "compact" | "tooltip" | "mini"
--   bar:SetValues{ value, max, bonus, bonusKind = "temp"|"perm", tiers = { n... },
--                  markers = { { at, label } }, text, color }
--   bar:SetTimer(expires|nil)                         expires: a GetTime() second
--   bar:ApplyStyle(style)                             a NS.Bar.ResolveStyle(styleKey) table
--   NS.Bar.NewPool() / Acquire(pool, parent, styleKey) / ReleaseAll(pool)
--   NS.Bar.Compute(values) -> geom, NS.Bar.FormatTimer(seconds), NS.Bar.Color(token)
--   NS.Bar.TooltipRowHeight("tooltip" | "mini") -> px   a tooltip bar line's height
-- `bar.geom` is the last Compute: fill and bonus as fractions of the width, markers and the tier
-- segments ({ from, to, tier }) as fractions; read by the tests and the tooltip, written by SetValues.

NS.Bar = {}
local Bar = NS.Bar
local floor, max, min = math.floor, math.max, math.min

Bar.TIMER_TICK = 0.2   -- seconds between timer redraws while one runs (the only per-frame work)
Bar.TIMER_W    = 38    -- the timer's width, drawn inside the bar's far end (feedback round 2)
local EDGE = 1         -- the border's width, px
local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) and true or false end

-- ---------------------------------------------------------------------------------------------
-- Colors and the resolved style
-- ---------------------------------------------------------------------------------------------

--- A token's color as { r, g, b, a }: the skin's, else the owner token's own default (a degraded
--- load, no LibKa0s, still draws).
function Bar.Color(token)
    local c = NS.Skin.Token and NS.Skin.Token(token)
    if type(c) == "table" then return c end
    local own = NS.SKIN_OWNER_TOKENS and NS.SKIN_OWNER_TOKENS[token]
    return own and own.default or nil
end

local function profileBars()
    return (NS.db and NS.db.profile.bars) or NS.defaults.profile.bars
end

local Core = LibStub and LibStub("LibKa0s-Core-1.0", true)

--- `stored` with the player's class color in place of its RGB while `useClass` is on; the stored
--- alpha always applies, and an unresolvable class keeps the stored swatch (options-ui-§17).
function Bar.WithClass(stored, useClass)
    if not (useClass and Core and Core.ClassColor) then return stored end
    local r, g, b = Core.ClassColor("player")
    if r == nil then return stored end
    return { r, g, b, type(stored) == "table" and stored[4] or 1 }
end

--- A player color (bars.colors[key]) unless the colors follow the skin, then `token`.
function Bar.PlayerColor(key, token)
    local colors = profileBars().colors
    if colors.fromSkin or type(colors[key]) ~= "table" then return Bar.Color(token) end
    return colors[key]
end

--- A composed swatch (options-ui-§16/§17): the skin's `token` while `<key>FromSkin` is on, else the
--- stored `key` through its class-color companion `classKey`.
function Bar.Swatch(key, token, classKey)
    local p = profileBars()
    if p[key .. "FromSkin"] ~= false or type(p[key]) ~= "table" then return Bar.Color(token) end
    return Bar.WithClass(p[key], p[classKey])
end

--- The media path for an LSM key, or nil (no LibSharedMedia, an unknown key).
local function media(kind, key)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if not (LSM and type(key) == "string" and key ~= "") then return nil end
    local ok, path = pcall(LSM.Fetch, LSM, kind, key, true)
    return ok and path or nil
end
Bar.Media = media

--- What the border draws: show, style, size, through the skin's bar border while its companion is
--- on (S.BarBorder), else the stored three. skinning-§6: a skin that states a real bar border style
--- wins over Show border while the companion is on, and the host never gates the stored toggle
--- ahead of the call (nor after it). Under a skin's None (Ka0s Default, WoW Forever) Show border
--- off is off; under a real style the companion off hands it back (feedback round 2, FB-10). The
--- style companion defaults OFF here (a documented options-ui-§16 deviation), so Show border off
--- is off under every skin until the player opts into the skin's border.
local function border(p)
    local show, style, size = p.border == true, p.borderStyle or "Solid", tonumber(p.borderSize) or 1
    local S = NS.Skin
    if S.IsEnabled() and S.BarBorder then
        local st, sh, sz = S.BarBorder(style, show, size, p.borderStyleFromSkin == true)
        if st ~= nil then style, show, size = st, sh, sz end
    end
    if style == "None" or (tonumber(size) or 0) <= 0 then show = false end
    return { show = show and true or false, style = style, size = tonumber(size) or 1,
             color = Bar.Swatch("borderColor", "sm.barBorder", "useClassColorBorder") }
end

local function font(p)
    return {
        size = p.fontSize, flags = p.fontFlags, shadow = p.fontShadow,
        shadowFromSkin = p.fontShadowFromSkin ~= false,
        face = p.fontFromSkin == false and media("font", p.font) or nil,
        fromSkin = p.fontFromSkin ~= false,
    }
end

-- A detached block's compact bar is as tall as the main window's (the owner's ruling, feedback
-- round 2: no separate Detached bar height).
--- Rank tier `tier`'s shade of `c`: the category's own color for the first tier (Apprentice), each
--- tier after it darker by one step, its alpha kept (feedback round 2).
Bar.TIER_SHADE = { 1, 0.8, 0.64, 0.5 }
function Bar.TierShade(c, tier)
    local k = Bar.TIER_SHADE[tier] or Bar.TIER_SHADE[#Bar.TIER_SHADE]
    return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 }
end

local HEIGHT_KEY = { row = "height", compact = "height", tooltip = "tooltipHeight", mini = "miniHeight" }

--- The height of one tooltip line carrying a bar: the stored row height `rowKey`, never shorter
--- than the bar `barKey` it carries. "tooltip" (the row tooltip) or "mini" (the LDB tooltip).
local ROW_KEY = { tooltip = { "tooltipRowHeight", "tooltipHeight" }, mini = { "brokerRowHeight", "miniHeight" } }
function Bar.TooltipRowHeight(styleKey)
    local k, p = ROW_KEY[styleKey] or ROW_KEY.mini, profileBars()
    return math.max(tonumber(p[k[1]]) or 14, tonumber(p[k[2]]) or 0)
end

--- Whether a `styleKey` bar draws a stat's threshold markers (owner feedback round 6, R6-4): the row
--- tooltip's bar follows Bars > Marks > Thresholds in the row tooltip (on by default), every other
--- bar Thresholds in the window (off by default).
function Bar.ShowMarkers(styleKey)
    local p = profileBars()
    if styleKey == "tooltip" then return p.markersTooltip ~= false end
    return p.markersWindow == true
end

--- The style one kind of bar draws with: the profile's sizes, switches, media and colors, each
--- following the skin where its companion says so.
function Bar.ResolveStyle(styleKey)
    local p = profileBars()
    styleKey = HEIGHT_KEY[styleKey] and styleKey or "row"
    local edge = border(p)
    return {
        key = styleKey,
        height = p[HEIGHT_KEY[styleKey]] or p.height,
        fill = Bar.Color("sm.barFill"),
        bg = Bar.Swatch("bgColor", "sm.barBg", "useClassColorBg"),
        border = edge.show and edge.color or nil, borderStyle = edge.style, borderSize = edge.size,
        marker = Bar.Color("sm.marker"), spark = p.spark and Bar.Color("sm.spark"),
        -- Rank tier colors works under Color mode By category alone (feedback round 2).
        tiered = p.tierColors == true and (p.colorMode or "category") == "category",
        text = Bar.Swatch("fontColor", "sm.barText", "useClassColorFont"), timer = Bar.Color("sm.timer"),
        bonusTemp = Bar.PlayerColor("bonusTemp", "sm.bonusTemp"),
        bonusPerm = Bar.PlayerColor("bonusPerm", "sm.bonusPerm"),
        texture = p.barTextureFromSkin == false and media("statusbar", p.barTexture) or nil,
        alpha = tonumber(p.barAlpha) or 1,
        font = font(p), fontSize = p.fontSize, textAnchor = p.textAnchor or "CENTER",
        reverse = p.fillDirection == "RIGHT",   -- fills from the right edge (Bars > Fill direction)
        template = p.textTemplate,
        showText = styleKey ~= "mini" and styleKey ~= "tooltip",
        showMarkers = Bar.ShowMarkers(styleKey), showTimer = p.timer ~= false,
    }
end

-- ---------------------------------------------------------------------------------------------
-- The geometry, pure
-- ---------------------------------------------------------------------------------------------

local function clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

--- The fill split by rank tier on a scale to the last tier: one { from, to, tier } per tier the
--- value has entered, as fractions of the scale. `tiers` is the catalog's caps ({ 75, 150, 225, 300 }).
local function tierSegments(tiers, value, scale)
    local out, from = {}, 0
    for i, cap in ipairs(tiers) do
        if value <= from then break end
        out[#out + 1] = { from = from / scale, to = min(value, cap) / scale, tier = i }
        from = cap
    end
    return out
end

local function markerFractions(list, cap)
    local out = {}
    for _, m in ipairs(list or {}) do
        local at = tonumber(m.at)
        if at and at >= 0 and at <= cap then out[#out + 1] = { at = at / cap, label = m.label } end
    end
    return out
end

Bar.TEMPLATE = "{rank} {bonus} / {max}"

local function signed(bonus)
    if bonus and bonus > 0 then return "+" .. bonus end
    if bonus and bonus < 0 then return tostring(bonus) end
    return ""
end

--- The bar text from `template` (bars.textTemplate; Bar.TEMPLATE when nil): {rank}, {bonus} ("+25",
--- "-3" or nothing), {max}, {pct} (whole percent of the cap) and {left} (points to the cap). A
--- token with nothing to say leaves no double space behind. The default reads "107 +25 / 150".
function Bar.Text(value, bonus, cap, template)
    local pct = cap > 0 and floor(value / cap * 100 + 0.5) or 0
    local subs = { rank = tostring(value), bonus = signed(bonus), max = tostring(cap),
                   pct = tostring(pct), left = tostring(max(cap - value, 0)) }
    local out = tostring(template or Bar.TEMPLATE):gsub("{(%a+)}", function(k) return subs[k] end)
    return (out:gsub("%s%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- The bar's geometry from its values. The base clamps to [0, 1]; the bonus reaches at most the
--- end (Review Focus 4); the text keeps the full numbers. Markers up to and including the cap.
--- `tiered` (Rank tier colors) draws a bar carrying `tiers` on a scale to its last tier (300 for a
--- profession) whatever its cap, its fill in `segments`, one per tier entered.
function Bar.Compute(v, template, tiered)
    local cap = tonumber(v.max) or 0
    local value = tonumber(v.value) or 0
    local bonus = tonumber(v.bonus) or 0
    local g = { fill = 0, bonus = 0, markers = {} }
    local tiers = tiered and type(v.tiers) == "table" and #v.tiers > 0 and v.tiers or nil
    local scale = tiers and tonumber(tiers[#tiers]) or cap
    if scale > 0 then
        g.fill = clamp01(value / scale)
        g.bonus = max(0, clamp01((value + max(bonus, 0)) / scale) - g.fill)
        g.markers = markerFractions(v.markers, scale)
        if tiers then g.segments = tierSegments(tiers, min(value, scale), scale) end
    end
    g.text = v.text or Bar.Text(value, bonus, cap, template)
    return g
end

--- Seconds as m:ss, or h:mm:ss from an hour; never negative.
function Bar.FormatTimer(seconds)
    local s = max(0, floor((tonumber(seconds) or 0) + 0.5))
    local h, m = floor(s / 3600), floor(s % 3600 / 60)
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s % 60) end
    return ("%d:%02d"):format(m, s % 60)
end

-- ---------------------------------------------------------------------------------------------
-- Painting
-- ---------------------------------------------------------------------------------------------

local function rgba(c) return c[1], c[2], c[3], c[4] or 1 end

--- A data fill: the skin's bar texture tinted (S.BarTexture, recorded so a skin switch follows),
--- or a flat color where the skin library is absent.
local function paintFill(tex, c, s)
    if not c then return end
    local r, g, b, a = rgba(c)
    a = a * (s and s.alpha or 1)
    if s and s.texture then
        tex:SetTexture(s.texture)
        tex:SetVertexColor(r, g, b, a)
    elseif NS.Skin.IsEnabled() then
        NS.Skin.BarTexture(tex, r, g, b, a)
    else
        tex:SetColorTexture(r, g, b, a)
    end
end

--- Four 1 px edge textures on `frame`, answered as a list.
function Bar.MakeEdges(frame, layer)
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
function Bar.PaintEdges(edges, c)
    for _, t in ipairs(edges) do
        if c then
            t:SetColorTexture(rgba(c))
            t:Show()
        else
            t:Hide()
        end
    end
end

--- The bar's border: the four edges at `borderSize` px for a Solid style, else the LSM border
--- drawn by a backdrop child (made on first use), else nothing.
function Bar.PaintBorder(bar, s)
    local path = s.border and s.borderStyle ~= "Solid" and media("border", s.borderStyle) or nil
    local size = s.borderSize or EDGE
    for i, t in ipairs(bar.edges) do
        if i <= 2 then t:SetHeight(size) else t:SetWidth(size) end
    end
    Bar.PaintEdges(bar.edges, (s.border and not path) and s.border or nil)
    if not (path or bar.edgeFrame) then return end
    local f = bar.edgeFrame
    if not f then
        f = CreateFrame("Frame", nil, bar, "BackdropTemplate")
        f:SetAllPoints(bar)
        bar.edgeFrame = f
    end
    f:SetShown(path ~= nil)
    if path and f.SetBackdrop then
        f:SetBackdrop({ edgeFile = path, edgeSize = size })
        f:SetBackdropBorderColor(rgba(s.border))
    end
end

local function textureList(bar, field, n, layer, sublevel)
    local list = bar[field]
    while #list < n do list[#list + 1] = bar:CreateTexture(nil, layer, nil, sublevel) end
    return list
end

-- ---------------------------------------------------------------------------------------------
-- The widget
-- ---------------------------------------------------------------------------------------------

local Methods = {}

--- The edge the fill grows from and the sign of an x offset along it: LEFT, +1 by default; RIGHT,
--- -1 while the style fills right to left.
local function origin(bar)
    if bar.style and bar.style.reverse then return "RIGHT", -1 end
    return "LEFT", 1
end

--- Place the fill (or its tier segments), the bonus, the spark and the markers from `geom` on the
--- current width, from the style's edge. Cheap: anchors and widths only (standalone-windows, Resizing).
function Methods:Layout()
    local g, w = self.geom, self:GetWidth()
    -- WoW Forever answers a tooltip-anchored bar's width as a secret number while the addon's code
    -- is tainted (measured 2026-11-12, RowTooltip.placeBar): no arithmetic on it, so the last plain
    -- width stands in (the caller seeds `knownWidth` when it sets one).
    if isSecret(w) or type(w) ~= "number" then
        w = self.knownWidth or 0
    elseif w > 0 then
        self.knownWidth = w   -- a frame not laid out yet answers 0: never the width to fall back to
    end
    w = w - 2 * EDGE
    local side, sgn = origin(self)
    local fillW, bonusW = max(0, w * g.fill), max(0, w * g.bonus)
    self.fill:ClearAllPoints()
    self.fill:SetPoint("TOP" .. side, self, "TOP" .. side, sgn * EDGE, -EDGE)
    self.fill:SetPoint("BOTTOM" .. side, self, "BOTTOM" .. side, sgn * EDGE, EDGE)
    self.fill:SetWidth(max(fillW, 0.01))
    self.fill:SetShown(fillW >= 0.5 and not g.segments)
    self:LayoutSegments(g.segments, w)
    local x = sgn * (EDGE + fillW)
    self.bonus:ClearAllPoints()
    self.bonus:SetPoint("TOP" .. side, self, "TOP" .. side, x, -EDGE)
    self.bonus:SetPoint("BOTTOM" .. side, self, "BOTTOM" .. side, x, EDGE)
    self.bonus:SetWidth(max(bonusW, 0.01))
    self.bonus:SetShown(bonusW >= 0.5)
    self.spark:ClearAllPoints()
    self.spark:SetPoint("TOP", self, "TOP" .. side, x, 0)
    self.spark:SetPoint("BOTTOM", self, "BOTTOM" .. side, x, 0)
    self.spark:SetShown(self.style.spark and fillW >= 1 and g.fill < 1 or false)   -- false: Spark off
    self:LayoutMarks(self.markerTextures, g.markers, w, function(m) return m.at end)
end

--- The tier segments, each from its tier's start to where the value stops in it; none untiered.
function Methods:LayoutSegments(segs, w)
    local side, sgn = origin(self)
    for i, t in ipairs(self.segmentTextures) do
        local seg = segs and segs[i]
        local sw = seg and w * (seg.to - seg.from) or 0
        if seg and sw >= 0.5 then
            t:ClearAllPoints()
            t:SetPoint("TOP" .. side, self, "TOP" .. side, sgn * (EDGE + w * seg.from), -EDGE)
            t:SetPoint("BOTTOM" .. side, self, "BOTTOM" .. side, sgn * (EDGE + w * seg.from), EDGE)
            t:SetWidth(sw)
        end
        t:SetShown(seg ~= nil and sw >= 0.5)
    end
end

function Methods:LayoutMarks(list, marks, w, at)
    local side, sgn = origin(self)
    for i, t in ipairs(list) do
        local m = marks[i]
        if m then
            local x = sgn * (EDGE + min(w * at(m), max(w - 1, 0)))
            t:ClearAllPoints()
            t:SetPoint("TOP" .. side, self, "TOP" .. side, x, 0)
            t:SetPoint("BOTTOM" .. side, self, "BOTTOM" .. side, x, 0)
        end
        t:SetShown(m ~= nil)
    end
end

function Methods:PaintMarks()
    local g, s = self.geom, self.style
    -- The tier segments take the fill's place and layer (ARTWORK 1), each its tier's shade of the
    -- row's fill color (its category's, under By category).
    local segs = textureList(self, "segmentTextures", g.segments and #g.segments or 0, "ARTWORK", 1)
    local base = (self.values and self.values.color) or s.fill
    for i, t in ipairs(segs) do
        local seg = g.segments and g.segments[i]
        if seg and base then paintFill(t, Bar.TierShade(base, seg.tier), s) end
    end
    if s.showMarkers == false then for i = #g.markers, 1, -1 do g.markers[i] = nil end end
    local marks = textureList(self, "markerTextures", #g.markers, "OVERLAY")
    for i, t in ipairs(marks) do
        if g.markers[i] and s.marker then t:SetColorTexture(rgba(s.marker)) end
        t:SetWidth(2)
    end
end

--- Set the numbers. Recomputes the geometry, repaints the fill and bonus colors, redraws.
function Methods:SetValues(v)
    self.values = v
    self.geom = Bar.Compute(v, self.style and self.style.template, self.style and self.style.tiered)
    local s = self.style
    local fillColor = v.color or s.fill
    if fillColor ~= self.fillColor then
        self.fillColor = fillColor
        paintFill(self.fill, fillColor, s)
    end
    local bonusColor = v.bonusKind == "temp" and s.bonusTemp or s.bonusPerm
    if bonusColor ~= self.bonusColor then
        self.bonusColor = bonusColor
        paintFill(self.bonus, bonusColor, s)
    end
    self.text:SetText(self.geom.text)
    self.text:SetShown(s.showText)
    self:PaintMarks()
    self:Layout()
end

local function timerTick(self, elapsed)
    self.__acc = (self.__acc or 0) + (elapsed or 0)
    if self.__acc < Bar.TIMER_TICK then return end
    self.__acc = 0
    self:RedrawTimer()
end

function Methods:RedrawTimer()
    local left = self.expires and self.expires - GetTime()
    if not left or left <= 0 then
        self:SetTimer(nil)
        return
    end
    self.timer:SetText(Bar.FormatTimer(left))
end

--- Show the time left until `expires` (a GetTime() second) beside the bar, or clear it with nil.
--- The OnUpdate runs only while a timer does, and is disarmed when it is cleared or runs out.
function Methods:SetTimer(expires)
    self.expires = tonumber(expires)
    if self.style and self.style.showTimer == false then self.expires = nil end
    if not self.expires or self.expires <= GetTime() then
        self.expires = nil
        self.timer:SetText("")
        self.timer:Hide()
        self:SetScript("OnUpdate", nil)
        return
    end
    self.timer:Show()
    self.__acc = 0
    self:RedrawTimer()
    self:SetScript("OnUpdate", timerTick)
end

--- The text at its anchor; the timer inside the bar's far end, or its near end when the text sits
--- right, so the two never share a corner.
local function placeText(bar, anchor)
    bar.text:ClearAllPoints()
    local x = anchor == "LEFT" and 4 or (anchor == "RIGHT" and -4 or 0)
    bar.text:SetPoint(anchor, bar, anchor, x, 0)
    bar.text:SetJustifyH(anchor)
    local side = anchor == "RIGHT" and "LEFT" or "RIGHT"
    bar.timer:ClearAllPoints()
    bar.timer:SetPoint(side, bar, side, side == "LEFT" and 3 or -3, 0)
    bar.timer:SetJustifyH(side)
end

local function paintText(bar, s)
    local S = NS.Skin
    local f = s.font or {}
    local size = S.HudFontSize(s.fontSize or 11, f.fromSkin)
    if S.IsEnabled() then
        S.HudFont(bar.text, { size = size, face = f.face, flags = S.FontFlags(f.flags or S.FROM_SKIN),
                              shadow = f.shadow, shadowFromSkin = f.shadowFromSkin })
    end
    if s.text then bar.text:SetTextColor(rgba(s.text)) end
    if s.timer then bar.timer:SetTextColor(rgba(s.timer)) end
end

--- Apply a resolved style (Bar.ResolveStyle, or a partial table over the current one). A resolved
--- style (it carries `key`) REPLACES the current one: its absent fields mean "none" (no border, the
--- skin's texture), and a merge would keep the last style's border or texture in their place.
function Methods:ApplyStyle(style)
    local s = {}
    if not (style and style.key) then
        for k, v in pairs(self.style or {}) do s[k] = v end
    end
    for k, v in pairs(style or {}) do s[k] = v end
    self.style = s
    self:SetHeight(s.height or 14)
    if s.bg then self.bg:SetColorTexture(rgba(s.bg)) end
    Bar.PaintBorder(self, s)
    if s.spark then self.spark:SetColorTexture(rgba(s.spark)) end
    placeText(self, s.textAnchor or "CENTER")
    paintText(self, s)
    self.fillColor, self.bonusColor = nil, nil
    if self.values then self:SetValues(self.values) end
end

local function buildRegions(bar)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    bar.fill = bar:CreateTexture(nil, "ARTWORK", nil, 1)   -- anchored by Layout, from the style's edge
    bar.bonus = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetWidth(1)
    bar.edges = Bar.MakeEdges(bar, "OVERLAY")
    bar.segmentTextures, bar.markerTextures = {}, {}
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetWordWrap(false)
    bar.timer = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.timer:SetWidth(Bar.TIMER_W - 4)
    bar.timer:Hide()
end

--- One bar, parented to `parent`, in the style `styleKey` resolves to.
function Bar.Create(parent, styleKey)
    local bar = CreateFrame("Frame", nil, parent)
    for k, fn in pairs(Methods) do bar[k] = fn end
    buildRegions(bar)
    bar.geom = Bar.Compute({ value = 0, max = 0 })
    bar:ApplyStyle(Bar.ResolveStyle(styleKey))
    bar:SetScript("OnSizeChanged", function(self) self:Layout() end)
    return bar
end

-- ---------------------------------------------------------------------------------------------
-- The pool (LibKa0s-Pool-1.0, ordered: position n gets its bar back after a release)
-- ---------------------------------------------------------------------------------------------

function Bar.NewPool() return NS.Pool.New() end

--- A bar from `pool`, (re)parented to `parent` and restyled to `styleKey` (a skin or profile change
--- reaches every bar on the next render).
function Bar.Acquire(pool, parent, styleKey)
    local bar = NS.Pool.Acquire(pool, function() return Bar.Create(parent, styleKey) end)
    bar:SetParent(parent)
    bar:ApplyStyle(Bar.ResolveStyle(styleKey))
    bar:Show()
    return bar
end

local function park(bar)
    bar:SetTimer(nil)
    bar:ClearAllPoints()
end

function Bar.ReleaseAll(pool) NS.Pool.ReleaseAll(pool, park) end
