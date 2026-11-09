local _, NS = ...
-- modules/Rows.lua — one skill or stat row (design §6.2/§6.3, plan Task 3.2): an initials icon in the
-- row's color, the name, the bar (NS.Bar) and its timer column, and the unlearned variant (dimmed,
-- "Not learned · <trainer>, <city> · <cost>" and a Go button). Pooled (NS.Pool, ordered).
--
-- NS.Rows.NewPool() / Acquire(pool, parent, styleKey) / ReleaseAll(pool)
-- row:SetSkill(entry), row:SetStat(entry), row:SetStripe(index), row.entry, row.kind ("skill"|"stat")
-- Pure helpers the tooltip, the broker and the journal reuse: SkillValues(entry), FillColor(entry),
-- StatValues(entry), UnlearnedText(entry), TrainerFor(entry), Place(trainer), Money(copper),
-- Initials(name).
-- Clicks and hover go to NS.Interact and NS.RowTooltip (T3.3) when they are loaded.

NS.Rows = {}
local R = NS.Rows
local L = NS.L
local floor = math.floor

R.PAD, R.ICON, R.NAME_W, R.GO_W = 6, 16, 118, 38
R.DIM = 0.8   -- an unlearned row's alpha (the mockup's)

-- ---------------------------------------------------------------------------------------------
-- Pure helpers
-- ---------------------------------------------------------------------------------------------

--- Two letters for the icon well: the capitals of a multi-word name, else its first two letters.
function R.Initials(name)
    name = tostring(name or "")
    local caps = name:gsub("[^%u]", "")
    if #caps >= 2 then return caps:sub(1, 2) end
    return name:sub(1, 2):upper()
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

local PROGRESS = { { 0.95, "sem.gold" }, { 0.6, "sem.good" }, { 0.3, "sem.warn" }, { 0, "sem.bad" } }
local LIKELIHOOD = { { 0.95, "sem.neutral" }, { 0.8, "sem.good" }, { 0.5, "sem.statusWarn" }, { 0, "sem.warn" } }

local function ladder(steps, p)
    for _, step in ipairs(steps) do
        if p >= step[1] then return NS.Bar.Color(step[2]) or NS.Bar.Color("sm.barFill") end
    end
    return NS.Bar.Color("sm.barFill")
end

--- The fill color for a row in the profile's color mode: by category (the player's colors, or the
--- skin's with `colors.fromSkin`), by progress, by skill-up likelihood (gray / green / yellow /
--- orange against the cap) or flat (the Bar color, through its skin and class-color companions).
function R.FillColor(e, isStat)
    local mode = bars().colorMode
    if mode == "flat" then return NS.Bar.Swatch("barColor", "sm.barFill", "useClassColorBar") end
    local p = isStat and (tonumber(e.pct) or 0) / 100 or ((e.max or 0) > 0 and e.rank / e.max or 0)
    if mode == "progress" then return ladder(PROGRESS, p) end
    if mode == "likelihood" and not isStat then return ladder(LIKELIHOOD, p) end
    return NS.Bar.PlayerColor(isStat and "stats" or (e.category or "other"), "sm.barFill")
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
             ticks = cat and cat.tiers }, expires
end

--- The bar's values for a stat entry: its percentage of its reference, its markers, its text.
function R.StatValues(e)
    return { value = tonumber(e.pct) or 0, max = 100, markers = e.markers, text = e.display }
end

-- ---------------------------------------------------------------------------------------------
-- The row
-- ---------------------------------------------------------------------------------------------

local Row = {}

local function paintIcon(row, color)
    local c = color or NS.Bar.Color("sm.barFill")
    NS.Bar.PaintEdges(row.iconEdges, c)
    if c then row.initials:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
end

local function setLearnedLook(row, learned)
    row.bar:SetShown(learned)
    row.where:SetShown(not learned)
    row.go:SetShown(not learned)
    row:SetAlpha(learned and 1 or R.DIM)
end

--- Draw a skill entry (SkillData's model entry).
function Row:SetSkill(e)
    self.kind, self.entry = "skill", e
    self.name:SetText(e.name)
    self.initials:SetText(R.Initials(e.name))
    local color = R.FillColor(e)
    paintIcon(self, color)
    if e.learned == false then
        setLearnedLook(self, false)
        self.bar:SetTimer(nil)
        self.where:SetText(R.UnlearnedText(e))
        return
    end
    setLearnedLook(self, true)
    local v, expires = R.SkillValues(e)
    v.color = color
    self.bar:SetValues(v)
    self.bar:SetTimer(expires)
end

local function statDisplay()
    local s = (NS.db and NS.db.profile.stats) or NS.defaults.profile.stats
    return s.display or "both"
end

--- Draw a stat entry (StatData's model entry) as stats.display says: the bar and its value, the
--- bar alone, or the value alone in the bar's place.
function Row:SetStat(e)
    self.kind, self.entry = "stat", e
    self.name:SetText(e.label)
    self.initials:SetText(R.Initials(e.label))
    local color = R.FillColor(e, true)
    paintIcon(self, color)
    setLearnedLook(self, true)
    local mode = statDisplay()
    self.bar:SetTimer(nil)
    if mode == "text" then
        self.bar:Hide()
        self.where:SetText(e.display or "")
        self.where:Show()
        return
    end
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

local function onEnter(self)
    NS.Skin.ListRow(self, "hover")
    if NS.RowTooltip and self.entry then NS.RowTooltip.Show(self) end
end

local function onLeave(self)
    NS.Skin.ListRow(self, self.stripe and "stripe" or "normal")
    if NS.RowTooltip then NS.RowTooltip.Hide(self) end
end

local function onClick(self, button)
    if NS.Interact and self.entry then NS.Interact.OnRowClick(self, button) end
end

local function onGo(self)
    local row = self:GetParent()
    if NS.Interact and row.entry then NS.Interact.Trainer(row) end
end

local function buildIcon(row)
    local f = CreateFrame("Frame", nil, row)
    f:SetSize(R.ICON, R.ICON)
    f:SetPoint("LEFT", row, "LEFT", R.PAD, 0)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    row.iconFrame, row.iconBg = f, bg
    row.iconEdges = NS.Bar.MakeEdges(f, "BORDER")
    row.initials = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.initials:SetPoint("CENTER", f, "CENTER", 0, 0)
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
    row.where:SetPoint("RIGHT", row, "RIGHT", -(R.GO_W + 2 * R.PAD), 0)
    row.where:SetJustifyH("LEFT")
    row.where:SetWordWrap(false)
    NS.Skin.Text(row.where, "muted")
end

local function buildGo(row)
    local go = CreateFrame("Button", nil, row)
    go:SetSize(R.GO_W, 18)
    go:SetPoint("RIGHT", row, "RIGHT", -R.PAD, 0)
    go.text = go:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    go.text:SetPoint("CENTER", go, "CENTER", 0, 0)
    go.text:SetText(L["Go"])
    go:SetScript("OnClick", onGo)
    NS.Skin.Button(go)
    row.go = go
end

local function build(parent, styleKey)
    local row = CreateFrame("Button", nil, parent)
    for k, fn in pairs(Row) do row[k] = fn end
    row:RegisterForClicks("AnyUp")
    buildIcon(row)
    buildText(row)
    row.bar = NS.Bar.Create(row, styleKey)
    row.bar:SetPoint("LEFT", row.name, "RIGHT", R.PAD, 0)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -(NS.Bar.TIMER_W + R.PAD), 0)
    buildGo(row)
    row:SetScript("OnEnter", onEnter)
    row:SetScript("OnLeave", onLeave)
    row:SetScript("OnClick", onClick)
    return row
end

function R.NewPool() return NS.Pool.New() end

--- A row from `pool`, parented to `parent`, its bar restyled to `styleKey` and its height the
--- profile's row height (a compact row is two pixels shorter).
function R.Acquire(pool, parent, styleKey)
    local row = NS.Pool.Acquire(pool, function() return build(parent, styleKey) end)
    row:SetParent(parent)
    row.bar:ApplyStyle(NS.Bar.ResolveStyle(styleKey))
    local c = NS.Bar.Color("sm.iconBg")   -- every acquire, so a skin switch reaches a pooled row
    if c then row.iconBg:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    local h = bars().rowHeight or 20
    row:SetHeight(styleKey == "compact" and h - 2 or h)
    row:Show()
    return row
end

local function park(row)
    row.bar:SetTimer(nil)
    row.entry, row.kind = nil, nil
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
