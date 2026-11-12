local _, NS = ...
-- modules/Rows.lua — one skill or stat row (design §6.2/§6.3, plan Task 3.2): an in-game icon in a
-- thin border of the row's color (FB-14), the name, the bar (NS.Bar) and its timer column, and the
-- unlearned variant (dimmed, its icon gray, "Not learned · <trainer>, <city> · <cost>"). Every row,
-- skill or stat, carries one action mark at its right end (owner feedback rounds 3 and 4): the mark is
-- the row's action, the row's own plain click opens nothing. Pooled (NS.Pool, ordered).
--
-- NS.Rows.NewPool() / Acquire(pool, parent, styleKey) / ReleaseAll(pool)
-- row:SetSkill(entry), row:SetStat(entry), row:SetStripe(index), row.entry, row.kind ("skill"|"stat")
-- Pure helpers the tooltip, the broker and the journal reuse: SkillValues(entry), FillColor(entry),
-- StatValues(entry), UnlearnedText(entry), TrainerFor(entry), Place(trainer), Money(copper),
-- HelperHint(entry), Display() (Rows show: "both" | "bar" | "text", bars.rowDisplay),
-- Icon(kind, key) (the row's in-game icon texture; the alert toast draws it too).
-- row.marked (set before SetSkill, cleared on release): the equipped weapon's "> " marker.
-- The optional gathering hint (profile.skills.helperHint, design §12 item 4) is one muted line
-- under a Skinning, Mining, Herbalism or Fishing row, read from NS.SkillHelpers; the row grows by
-- R.HINT_H while it shows.
-- Clicks and hover go to NS.Interact and NS.RowTooltip (T3.3) when they are loaded.

NS.Rows = {}
local R = NS.Rows
local L = NS.L
local floor = math.floor

-- GO_W: the square action mark at a row's right end, one look on every row (ph:sign-in, owner
-- feedback rounds 3 and 4): it opens the row's window or panel. EDGE: its inset from the row's right edge,
-- the block header's detach mark's own (modules/Blocks.lua), so every mark down the window stands in
-- one column, and the gap between the bar and the mark (feedback round 2).
R.PAD, R.ICON, R.NAME_W = 6, 16, 118
R.GO_W, R.EDGE = NS.Chrome.SIZE, 4
R.BAR_RIGHT = R.EDGE + R.GO_W + R.EDGE   -- the bar's end, in from the row's right edge
R.DIM = 0.8   -- an unlearned row's alpha (the mockup's)
R.HINT_H = 12 -- the gathering hint's line under a row
R.MARK = "> "   -- the equipped weapon's marker (Detached.dc.html), ASCII so every skin face draws it

-- ---------------------------------------------------------------------------------------------
-- Pure helpers
-- ---------------------------------------------------------------------------------------------

-- The standard icon trim: the 1.x icon art's baked-in border cut off (left, right, top, bottom).
R.ICON_TRIM = { 0.07, 0.93, 0.07, 0.93 }

local statIcons, statIconsFor   -- key -> icon, built once per NS.STAT_DEFS table

local function statIcon(key)
    local defs = NS.STAT_DEFS
    if statIconsFor ~= defs then
        statIcons, statIconsFor = {}, defs
        for _, def in ipairs(defs or {}) do statIcons[def.key] = def.icon end
    end
    return statIcons[key]
end

--- The row's in-game icon (FB-14): a texture (a file ID or an Interface\Icons\ path), never a
--- LibKa0s glyph. A skill line draws its spell's runtime texture first (a profession's, through
--- NS.Compat.SpellTexture), else the catalog's static path; a stat its STAT_DEFS path; anything
--- unknown (an "other:" line) the question mark.
--- @param kind string "skill" | "stat"
--- @param key string the entry's key
function R.Icon(kind, key)
    if kind == "stat" then return statIcon(key) or NS.SKILL_ICON_UNKNOWN end
    local def = NS.SkillCatalog[key]
    if not def then return NS.SKILL_ICON_UNKNOWN end
    local tex = def.iconSpellID and NS.Compat.SpellTexture(def.iconSpellID)
    return tex or def.icon or NS.SKILL_ICON_UNKNOWN
end

--- Copper as "1g 50s 50c", dropping the empty parts ("10s", "90g").
function R.Money(copper)
    copper = floor(tonumber(copper) or 0)
    local g, s, c = floor(copper / 10000), floor(copper % 10000 / 100), copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

--- Where a trainer stands for a line of text: a race's riding instructor by its zone, else the city.
function R.Place(t)
    if t.race and t.mapName then return t.mapName end
    return t.city or t.mapName or ""
end

--- The trainer an unlearned row points at, with the cost and the level gate it states:
--- trainer, cost (copper) or nil, minLevel or nil.
function R.TrainerFor(e)
    local Tr = NS.Trainers
    if not Tr then return nil end
    if e.key == "riding" then
        local nr = Tr:NextRank("riding", 0, 0)
        local t = nr and nr.trainers[1]
        return t, nr and nr.cost, nr and nr.minLevel
    end
    local t = Tr:For(e.key)[1]
    if not t then return nil end
    local cost = t.costByKey and t.costByKey[e.key] or t.cost
    return t, cost, t.minLevelByKey and t.minLevelByKey[e.key]
end

--- "Not learned · Buliwyf Stonehand, Ironforge · 10s" (and "· Lv 40" where a level gates it).
function R.UnlearnedText(e)
    local t, cost, level = R.TrainerFor(e)
    if not t then return L["Not learned"] end
    local parts = { L["Not learned"], ("%s, %s"):format(t.name, R.Place(t)) }
    if level and level > 1 then parts[#parts + 1] = L["Lv %d"]:format(level) end
    if cost then parts[#parts + 1] = R.Money(cost) end
    return table.concat(parts, " \194\183 ")
end

local function bars() return (NS.db and NS.db.profile.bars) or NS.defaults.profile.bars end
local function icons() return (NS.db and NS.db.profile.icons) or NS.defaults.profile.icons end

--- What a row's icon draws (Bars > Icons, feedback round 2): shown, its size (never taller than
--- the row), its crop each side, and its border's show, style, thickness and color. `rowColor` is
--- the row's own fill color, the border's color while Use the row's color is on.
--- The icon border's color: the row's own, else the skin's icon border, else the swatch.
local function iconBorderColor(p, rowColor)
    if p.borderColorFromRow ~= false then return rowColor end
    local S = NS.Skin
    if p.borderColorFromSkin ~= false and S.Color("icon.border") then return { S.Color("icon.border") } end
    return NS.Bar.WithClass(p.borderColor, p.useClassColorBorder)
end

function R.IconStyle(rowColor, rowH)
    local p, S = icons(), NS.Skin
    local size = math.min(tonumber(p.size) or R.ICON, rowH or math.huge)
    local crop = math.max(0, math.min(tonumber(p.zoom) or 7, 30)) / 100
    local follow = p.borderStyleFromSkin ~= false
    local style = S.Resolve("icon.borderStyle", p.borderStyle or "Solid", follow) or p.borderStyle or "Solid"
    local edge = tonumber(S.Resolve("icon.borderSize", tonumber(p.borderSize) or 1, follow)) or 1
    local show = p.border ~= false and style ~= "None" and edge > 0
    local color = show and (iconBorderColor(p, rowColor) or NS.Bar.Color("sm.barFill")) or nil
    return { show = p.show ~= false, size = size, crop = crop, border = color, borderStyle = style, borderSize = edge }
end

local function hintsOn()
    local skills = NS.db and NS.db.profile.skills
    return skills ~= nil and skills.helperHint == true
end

local HINTS = {}

function HINTS.skinning(e)
    return L["Skinning %d: mobs up to Lv %d"]:format(e.rank, NS.SkillHelpers.SkinnableLevel(e.rank))
end

local function nodeHint(e)
    local n = NS.SkillHelpers.Nodes(e.key, e.rank)
    if not n then return nil end
    local best = n.gatherable[#n.gatherable]
    if best and n.next then return L["Gathers %s \194\183 next: %s at %d"]:format(best.name, n.next.name, n.next.need) end
    if best then return L["Gathers %s"]:format(best.name) end
    if n.next then return L["Next: %s at %d"]:format(n.next.name, n.next.need) end
    return nil
end
HINTS.mining, HINTS.herbalism = nodeHint, nodeHint

function HINTS.fishing(e)
    local need = NS.SkillHelpers.FishingNeedHere()
    if not need then return L["No fishing data for this zone"] end
    local zone = type(GetZoneText) == "function" and GetZoneText() or ""
    return L["Fishing in %s needs ~%d (you: %d +%d)"]:format(zone, need, e.rank, tonumber(e.modifier) or 0)
end

--- The one-line gathering hint under a learned Skinning, Mining, Herbalism or Fishing row, from
--- NS.SkillHelpers; nil with profile.skills.helperHint off or for any other skill.
function R.HelperHint(e)
    if not (hintsOn() and e and e.learned ~= false) then return nil end
    local fn = HINTS[e.key]
    return fn and fn(e) or nil
end

local PROGRESS = { { 0.95, "sem.gold" }, { 0.6, "sem.good" }, { 0.3, "sem.warn" }, { 0, "sem.bad" } }
local LIKELIHOOD = { { 0.95, "sem.neutral" }, { 0.8, "sem.good" }, { 0.5, "sem.statusWarn" }, { 0, "sem.warn" } }

local function ladder(steps, p)
    for _, step in ipairs(steps) do
        if p >= step[1] then return NS.Bar.Color(step[2]) or NS.Bar.Color("sm.barFill") end
    end
    return NS.Bar.Color("sm.barFill")
end

--- The fill color for a row in the profile's color mode: by category (the skin's sm.cat.<category>
--- token while `colors.fromSkin` is on, else the player's color), by progress, by skill-up likelihood (gray / green / yellow /
--- orange against the cap) or flat (the Bar color, through its skin and class-color companions).
function R.FillColor(e, isStat)
    local mode = bars().colorMode
    if mode == "flat" then return NS.Bar.Swatch("barColor", "sm.barFill", "useClassColorBar") end
    local p = isStat and (tonumber(e.pct) or 0) / 100 or ((e.max or 0) > 0 and e.rank / e.max or 0)
    if mode == "progress" then return ladder(PROGRESS, p) end
    if mode == "likelihood" and not isStat then return ladder(LIKELIHOOD, p) end
    local cat = isStat and "stats" or (e.category or "other")
    return NS.Bar.PlayerColor(cat, "sm.cat." .. cat)
end

--- The bar's values for a skill entry, and the earliest temp expiry (or nil). The bonus is the
--- entry's own modifier; the breakdown decides temp or permanent and the timer.
function R.SkillValues(e)
    local b = NS.Bonuses and NS.Bonuses:Breakdown(e.key)
    local kind, expires = "perm", nil
    for _, s in ipairs(b and b.sources or {}) do
        if s.kind == "temp" then
            kind = "temp"
            if s.expires and (not expires or s.expires < expires) then expires = s.expires end
        end
    end
    local cat = NS.SkillCatalog[e.key]
    return { value = e.rank, max = e.max, bonus = tonumber(e.modifier) or 0, bonusKind = kind,
             tiers = cat and cat.tiers }, expires
end

--- The bar's values for a stat entry: its percentage of its reference, its markers, its text.
function R.StatValues(e)
    return { value = tonumber(e.pct) or 0, max = 100, markers = e.markers, text = e.display }
end

-- ---------------------------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------------------------

local Row = {}

--- The name's left anchor: past the icon, or the row's own pad while icons are off.
local function placeName(row, shown)
    row.name:ClearAllPoints()
    if shown then
        row.name:SetPoint("LEFT", row.iconFrame, "RIGHT", R.PAD, 0)
    else
        row.name:SetPoint("LEFT", row, "LEFT", R.PAD, 0)
    end
end

--- The icon well: the entry's icon, gray while unlearned, sized, cropped and edged as Bars > Icons
--- says (by default 16 px, the 0.07 crop and a 1 px border in the row's color, FB-14).
local function paintIcon(row, color, kind, key, learned)
    local h = row.baseH or bars().rowHeight or 20
    local st = R.IconStyle(color or NS.Bar.Color("sm.barFill"), h)
    local f = row.iconFrame
    f:SetShown(st.show)
    placeName(row, st.show)
    if not st.show then return end
    f:SetSize(st.size, st.size)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", row, "TOPLEFT", R.PAD, -(h - st.size) / 2)
    NS.Bar.PaintBorder(f, st)
    local inset = st.border and st.borderSize or 0
    row.icon:ClearAllPoints()
    row.icon:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    row.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    row.icon:SetTexture(R.Icon(kind, key))
    row.icon:SetTexCoord(st.crop, 1 - st.crop, st.crop, 1 - st.crop)
    row.icon:SetDesaturated(learned == false)
end

--- Whether a skill entry's window opens by a cast (catalog openSpell). The cast is the crafting
--- overlay's (modules/SecureOverlay.lua), laid over the row's action mark.
function R.Opens(e)
    local cat = e and e.learned ~= false and NS.SkillCatalog[e.key]
    return cat and cat.openSpell ~= nil or false
end

local function setLearnedLook(row, learned)
    row.bar:SetShown(learned)
    row.where:SetShown(not learned)
    row:SetAlpha(learned and 1 or R.DIM)
end

--- The action mark (the row tooltip's click hint says what it does): on every row, a stat row's
--- opening the character panel (owner feedback round 4).
local function setAct(row, show)
    row.act:SetShown(show)
end

local function setName(row, text, marked)
    row.name:SetText(marked and (R.MARK .. text) or text)
    NS.Skin.Text(row.name, marked and "accent" or "body")
end

local function setHint(row, text)
    row.hint:SetText(text or "")
    row.hint:SetShown(text ~= nil)
    row:SetHeight((row.baseH or bars().rowHeight or 20) + (text and R.HINT_H or 0))
end

--- What every skill and stat row draws (bars.rowDisplay, the Bars page's Rows show): "both" (the
--- bar and its value), "bar" (the bar, no text) or "text" (the value alone, in the bar's place).
function R.Display()
    local mode = bars().rowDisplay
    if mode == nil then return "both" end
    return mode
end

--- The value alone, in the bar's place (Rows show: Value only): the bar hidden with its timer.
local function showValueOnly(row, text)
    row.bar:SetTimer(nil)
    row.bar:Hide()
    row.where:SetText(text or "")
    row.where:Show()
end

--- Draw a skill entry (SkillData's model entry) as Rows show says.
function Row:SetSkill(e)
    self.kind, self.entry = "skill", e
    setName(self, e.name, self.marked)
    setHint(self, R.HelperHint(e))
    local color = R.FillColor(e)
    paintIcon(self, color, "skill", e.key, e.learned)
    if e.learned == false then
        setLearnedLook(self, false)
        setAct(self, true)
        self.bar:SetTimer(nil)
        self.where:SetText(R.UnlearnedText(e))
        return
    end
    setLearnedLook(self, true)
    local v, expires = R.SkillValues(e)
    local mode = R.Display()
    setAct(self, true)
    if mode == "text" then
        return showValueOnly(self, NS.Bar.Text(v.value or 0, v.bonus, v.max or 0, bars().textTemplate))
    end
    v.color = color
    if mode == "bar" then v.text = "" end
    self.bar:SetValues(v)
    self.bar:SetTimer(expires)
end

--- Draw a stat entry (StatData's model entry) as Rows show says: the bar and its value, the bar
--- alone, or the value alone in the bar's place.
function Row:SetStat(e)
    self.kind, self.entry = "stat", e
    setName(self, e.label, false)
    setHint(self, nil)
    local color = R.FillColor(e, true)
    paintIcon(self, color, "stat", e.key, true)
    setLearnedLook(self, true)
    setAct(self, true)
    local mode = R.Display()
    self.bar:SetTimer(nil)
    if mode == "text" then return showValueOnly(self, e.display) end
    local v = R.StatValues(e)
    v.color = color
    if mode == "bar" then v.text = "" end
    self.bar:SetValues(v)
end

--- The alternate-row stripe (list.stripe), or the plain row.
function Row:SetStripe(i)
    self.stripe = i % 2 == 0
    NS.Skin.ListRow(self, self.stripe and "stripe" or "normal")
end

-- Only the hovered row's mark overlay is armed (modules/SecureOverlay.lua, its header): the
-- pointer entering the row arms it, before any press, and leaving both the row and the overlay
-- disarms it. The overlay appearing under the pointer takes it off the row: that is not a leave.
local function hoverOverlay(self)
    local SO = NS.SecureOverlay
    if SO and SO.Hover and SO.KindFor(self) then SO:Hover(self) end
end

local function unhoverOverlay(self)
    local SO = NS.SecureOverlay
    if SO and SO.Unhover and not SO.UnderPointer(self) then SO:Unhover(self) end
end

-- The action mark's secure overlay (when armed) lies over it and takes the pointer, so the mark
-- cannot light up on its own enter: while the row is hovered, each frame marks it hot when the
-- pointer is on it, as the detach mark is under the pointer.
local function watchAct(self)
    local act = self.act
    local hot = act:IsShown() and act:IsMouseOver() == true
    if hot ~= self.actHot then
        self.actHot = hot
        NS.Chrome.SetHot(act, hot)
    end
end

local function stopAct(self)
    self:SetScript("OnUpdate", nil)
    if self.actHot then NS.Chrome.SetHot(self.act, false) end
    self.actHot = nil
end

local function onEnter(self)
    hoverOverlay(self)
    NS.Skin.ListRow(self, "hover")
    if NS.RowTooltip and self.entry then NS.RowTooltip.Show(self) end
    if self.act and self.act:IsShown() then self:SetScript("OnUpdate", watchAct) end
end

local function onLeave(self)
    -- The pointer moved onto the row's own mark (a child that takes the mouse): still on the row.
    if self:IsMouseOver() == true then return end
    NS.Skin.ListRow(self, self.stripe and "stripe" or "normal")
    if NS.RowTooltip then NS.RowTooltip.Hide(self) end
    stopAct(self)
    unhoverOverlay(self)
end

local function onClick(self, button)
    if NS.Interact and self.entry then NS.Interact.OnRowClick(self, button) end
end

-- A click raises a toplevel window: the crafting overlays follow its new level (SecureOverlay).
local function onMouseDown()
    if NS.SecureOverlay and NS.SecureOverlay.OnRaise then NS.SecureOverlay:OnRaise() end
end

local function buildIcon(row)
    local f = CreateFrame("Frame", nil, row)
    f:SetSize(R.ICON, R.ICON)
    f:SetPoint("LEFT", row, "LEFT", R.PAD, 0)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    row.iconFrame, row.iconBg = f, bg
    row.iconEdges = NS.Bar.MakeEdges(f, "BORDER")
    f.edges = row.iconEdges   -- NS.Bar.PaintBorder's field: the icon's border is a bar border's kind
    -- Inside the 1 px edges, so the row's color stays a thin border round the art.
    row.icon = f:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    row.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
end

local function buildText(row)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.iconFrame, "RIGHT", R.PAD, 0)
    row.name:SetWidth(R.NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    NS.Skin.Text(row.name, "body")
    row.where = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.where:SetPoint("LEFT", row.name, "RIGHT", R.PAD, 0)
    row.where:SetPoint("RIGHT", row, "RIGHT", -(R.BAR_RIGHT + R.EDGE), 0)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(false)
    NS.Skin.Text(row.where, "muted")
    row.hint = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.hint:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.hint:SetPoint("RIGHT", row, "RIGHT", -R.PAD, 0)
    row.hint:SetJustifyH("LEFT")
    row.hint:SetWordWrap(false)
    row.hint:Hide()
    NS.Skin.Text(row.hint, "muted")
end

--- The action mark (ph:sign-in, owner feedback rounds 3 and 4): one look on every row, crafting,
--- gathering, weapon, Other, not learned and stat alike, and the row's one action
--- (NS.Interact.OnMarkClick). A crafting or character-panel row's mark gets a secure overlay laid
--- over it while hovered (modules/SecureOverlay.lua), which takes the click first; the mark's own
--- click is the rest (the trainer popup, a profession window by line ID, the fall-throughs). Its
--- enter and leave are the row's, so the tooltip and the row's hover stay up over it.
local function buildAct(row)
    local act = NS.Chrome.IconButton(row, "ph:sign-in", L["Go"], function(_, button)
        if NS.Interact and row.entry then NS.Interact.OnMarkClick(row, button) end
    end, nil)
    act:RegisterForClicks("AnyUp")
    act:SetPoint("RIGHT", row, "RIGHT", -R.EDGE, 0)
    act:SetScript("OnEnter", function() local fn = row:GetScript("OnEnter") if fn then fn(row) end end)
    act:SetScript("OnLeave", function() local fn = row:GetScript("OnLeave") if fn then fn(row) end end)
    act:Hide()
    row.act = act
end

local function build(parent, styleKey)
    local row = CreateFrame("Button", nil, parent)
    for k, fn in pairs(Row) do row[k] = fn end
    row:RegisterForClicks("AnyUp")
    buildIcon(row)
    buildText(row)
    row.bar = NS.Bar.Create(row, styleKey)
    row.bar:SetPoint("LEFT", row.name, "RIGHT", R.PAD, 0)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -R.BAR_RIGHT, 0)
    buildAct(row)
    row:SetScript("OnEnter", onEnter)
    row:SetScript("OnLeave", onLeave)
    row:SetScript("OnClick", onClick)
    row:HookScript("OnMouseDown", onMouseDown)
    return row
end

function R.NewPool() return NS.Pool.New() end

--- A row from `pool`, parented to `parent`, its bar restyled to `styleKey` and its height the
--- profile's row height (a detached block's compact row too: one Row height for both).
function R.Acquire(pool, parent, styleKey)
    local row = NS.Pool.Acquire(pool, function() return build(parent, styleKey) end)
    row:SetParent(parent)
    row.bar:ApplyStyle(NS.Bar.ResolveStyle(styleKey))
    local c = NS.Bar.Color("sm.iconBg")   -- every acquire, so a skin switch reaches a pooled row
    if c then row.iconBg:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    local h = bars().rowHeight or 20
    -- The icon and the action mark sit in the row's first line, so a hint line can grow it below.
    row.baseH = h
    row.iconFrame:ClearAllPoints()
    row.iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", R.PAD, -(h - R.ICON) / 2)
    row.act:ClearAllPoints()
    -- A whole unit down (round 5, R5-5): an odd row height left the mark half a unit off the grid.
    row.act:SetPoint("TOPRIGHT", row, "TOPRIGHT", -R.EDGE, -floor((h - R.GO_W) / 2))
    row:SetHeight(h)
    row:Show()
    return row
end

local function park(row)
    stopAct(row)
    if NS.SecureOverlay and NS.SecureOverlay.Forget then NS.SecureOverlay.Forget(row) end
    row.bar:SetTimer(nil)
    row.entry, row.kind, row.marked = nil, nil, nil
    row:ClearAllPoints()
end

function R.ReleaseAll(pool) NS.Pool.ReleaseAll(pool, park) end

--- Redraw every active row of `pool` from its entry's CURRENT values (no anchor moves): a bonus
--- tick, a skill-up in combat. `lookup(row)` answers the fresh entry, or nil to keep the old one.
function R.RefreshValues(pool, lookup)
    for _, row in ipairs(pool.active) do
        local e = row.entry and (lookup(row) or row.entry)
        if e and row.kind == "skill" then row:SetSkill(e) elseif e then row:SetStat(e) end
    end
end
