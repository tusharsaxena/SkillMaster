local addonName, NS = ...
-- modules/Journal.lua — the Journal window (design §6.4, mockup Journal.dc.html), a standalone window
-- with two tabs. Log: the skill-ups newest first (date, time, skill, change, zone) over the range the
-- picker names (journal.range: this session, the last 1 / 3 / 7 / 30 days or all time), that
-- range's gains and rate, the ETA to cap, New session and Clear log (FB-32). Alts: one column per
-- character and one row per skill or stat, a sub-tab per main-window block (NS.BLOCKS, FB-33);
-- hover a character's name for its details, right-click it to forget it.
--
-- standalone-windows: a plain frame, toplevel in the window tier, Escape closes it, the close
-- control through NS.MakeCloseButton, the drop point saved by its one writer (savePoint, below).
-- Resizable from a bottom-right grip (NS.Chrome.MakeResizable), never smaller than its default and
-- never larger than the screen: while sizing only the visible row and column counts change
-- (J.Relayout, at most once a frame); the rows are re-bound once, on release, and the size is saved
-- then (saveSize, its one writer). A grab first pins the frame by its top-left corner (pinTopLeft),
-- so the grip's corner follows the cursor rather than the frame growing about its center (FB-33).
-- A display: it reads NS.SessionLog and NS.Alts through NS.Preview.Log() / .Alts() (test mode's
-- sample while it is on, T5.2) and repaints on SKILLS_UPDATED and LAYOUT_CHANGED.

NS.Journal = {}
local J = NS.Journal
local L = NS.L
local LAYERS = NS.Constants.LAYERS
local Pool = NS.Pool
local floor, min, max = math.floor, math.min, math.max

J.FRAME_NAME = "SkillMasterJournal"

-- ── the Alts sub-tabs: one per main-window block, in the main window's default order ──────────

J.FILTER_ORDER = {}
J.FILTERS = {}
for i, id in ipairs(NS.BLOCKS) do
    local d = NS.BlockDefs[id]
    J.FILTER_ORDER[i] = id
    J.FILTERS[id] = { source = d.source, filter = d.filter }
end
local FILTER_LABEL = {
    primary = L["Primary"], secondary = L["Secondary"], weapon = L["Weapons"], other = L["Other"],
    stats_base = L["Base & Combat"], stats_spell = L["Spell & Regen"],
    stats_defense = L["Defense & Resists"], stats_utility = L["Utility"],
}

--- The sub-tab's short label.
function J.FilterLabel(id) return FILTER_LABEL[id] or id end

-- ── the Log's ranges (FB-32) ──────────────────────────────────────────────────────────────────

J.RANGE_ORDER = { "session", "1d", "3d", "7d", "30d", "all" }
J.RANGE_DAYS = { ["1d"] = 1, ["3d"] = 3, ["7d"] = 7, ["30d"] = 30 }
local RANGE_LABEL = {
    session = L["Current session"], ["1d"] = L["Last 1 day"], ["3d"] = L["Last 3 days"],
    ["7d"] = L["Last 7 days"], ["30d"] = L["Last 30 days"], all = L["All time"],
}
--- The range's label.
function J.RangeLabel(range) return RANGE_LABEL[range] or range end

-- 720 wide (owner feedback round 4): the Zone column took 150 px and the Skill column kept room.
local WIDTH, HEIGHT, TITLE_H, TAB_H, PAD = 720, 420, 26, 24, 12
local SIDE_W, ROW_H, ALT_ROW_H, LABEL_W, ETA_LINES = 190, 18, 32, 150, 5
local ALT_HEAD_H, CHIP_H, CHIP_GAP = 32, 20, 4
local SCROLL_W, SCROLL_GAP = 8, 4   -- the tables' scroll bars (owner feedback round 4)
local BODY_TOP = TITLE_H + TAB_H + 8
local LOG_CHROME_H = BODY_TOP + PAD + 20                     -- above and below the log's rows
local ALT_CHROME_H = BODY_TOP + PAD + 26 + ALT_HEAD_H + 20   -- the chips, the names and the footnote
J.MIN_W, J.MIN_H = WIDTH, HEIGHT
J.LOG_ROWS = floor((HEIGHT - LOG_CHROME_H) / ROW_H)
J.ALT_ROWS = floor((HEIGHT - ALT_CHROME_H) / ALT_ROW_H)
-- The character column's pitch: five across the default width, kept as the window widens (more
-- characters show instead). J.MAX_COLS is how many a row builds.
J.COL_W = floor((WIDTH - PAD * 2 - LABEL_W - SCROLL_W - SCROLL_GAP) / 5)
J.MAX_COLS = 12
local COL_W = J.COL_W
local ARROW = " -> "   -- ASCII: every shipped skin face draws it (the old U+2192 was a box in some)
local DASH = "\226\128\148"
local DAY = 86400

local frame   -- built on first show
local state = { tab = "log", filter = "primary", logOffset = 0, altOffset = 0, colOffset = 0,
                logRows = J.LOG_ROWS, altRows = J.ALT_ROWS, altCols = 5 }

local function clamp(v, lo, hi) return max(lo, min(v, hi)) end

local function text(parent, role, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    NS.Skin.Text(fs, role or "body")
    fs:SetWordWrap(false)
    return fs
end

-- ── formatting ───────────────────────────────────────────────────────────────────────────────

--- "1 h 52 m", or "12 m" under an hour.
function J.FormatDuration(sec)
    sec = max(floor(tonumber(sec) or 0), 0)
    local h, m = floor(sec / 3600), floor(sec % 3600 / 60)
    if h > 0 then return L["%d h %d m"]:format(h, m) end
    return L["%d m"]:format(m)
end

--- "~30 m", "~5 h"; nil for no ETA.
function J.FormatETA(sec)
    if sec == nil then return nil end
    return NS.RowTooltip.FormatETA(sec)
end

local function skillName(key)
    local e = NS.Preview.Skill(key)
    if e and e.name then return e.name end
    local cat = NS.SkillCatalog and NS.SkillCatalog[key]
    if cat then return L[cat.name] end
    return (tostring(key):gsub("^other:", ""))
end

-- ── the mini bar: the shared bar widget (NS.Bar, "mini" style), colored as the main window's ──

local function drawMiniBar(cell, value, maxValue, color)
    cell.bar:ApplyStyle(NS.Bar.ResolveStyle("mini"))   -- a skin or profile change since the last draw
    cell.bar:SetValues({ value = value, max = maxValue, color = color })
    cell.bar:Show()
end

-- ── the tables' scroll bar ────────────────────────────────────────────────────────────────────

--- A vertical scroll bar for an offset-driven table (owner feedback round 4): `onScroll(offset)`
--- when dragged. bar:Sync(maxOffset, offset) follows the table; it is shown only while the table
--- has more rows than fit. Skinned through the facade (S.ScrollBar with the caller's track/thumb).
local function makeScrollBar(parent, onScroll)
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(SCROLL_W)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()   -- both filled by the skin's scroll.track / scroll.thumb (S.ScrollBar)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(SCROLL_W, 36)
    bar:SetThumbTexture(thumb)
    bar.track, bar.thumb = track, thumb
    bar:SetScript("OnValueChanged", function(self, value)
        if self.syncing then return end
        onScroll(floor((tonumber(value) or 0) + 0.5))
    end)
    function bar:Sync(maxOffset, offset)
        self.syncing = true
        self:SetMinMaxValues(0, maxOffset)
        self:SetValue(offset)
        self.syncing = false
        self:SetShown(maxOffset > 0)
        self.maxOffset, self.offset = maxOffset, offset
    end
    if NS.Skin.ScrollBar then NS.Skin.ScrollBar(bar, { track = track, thumb = thumb }) end
    bar:Hide()
    return bar
end
J.MakeScrollBar = makeScrollBar   -- the suites read it

-- ── geometry ─────────────────────────────────────────────────────────────────────────────────

local function savePoint()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then return end
    -- The Journal's drag-only geometry: this module is its one writer (docs/ARCHITECTURE.md).
    NS.db.profile.journal.point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

-- The Journal's size: geometry only the grip sets, written on release by this one writer.
local function saveSize(w, h)
    if not (NS.db and tonumber(w) and tonumber(h)) then return end
    NS.db.profile.journal.size = { w = floor(w + 0.5), h = floor(h + 0.5) }
end

local function applyPoint()
    local p = NS.db and NS.db.profile.journal and NS.db.profile.journal.point
    frame:ClearAllPoints()
    if type(p) == "table" then
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

--- Pin the frame by its top-left corner where it stands (FB-33). The client sizes a frame about its
--- anchor: by its CENTER (the default place) the window grew two pixels a pixel and leapt. Pinned,
--- the grip's corner follows the cursor. GetLeft / GetTop answer in the units SetPoint takes.
local function pinTopLeft()
    local left, top = tonumber(frame:GetLeft()), tonumber(frame:GetTop())
    if not (left and top) then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

-- ── shared pieces ────────────────────────────────────────────────────────────────────────────

local function makeTab(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    return b
end

local function makeButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(floor((SIDE_W - 8) / 2), 22)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    NS.Skin.Button(b)
    return b
end

local function panel()
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -BODY_TOP)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)
    p:EnableMouseWheel(true)
    p.pool = Pool.New()
    return p
end

-- ── the Log's range ──────────────────────────────────────────────────────────────────────────

--- The stored range (journal.range), or all time for a value that names none (the default since
--- owner feedback round 4).
function J.SelectedRange()
    local r = NS.GetSetting and NS.GetSetting("journal.range")
    if RANGE_LABEL[r] then return r end
    return "all"
end

--- Pick the Log's range: stored through the seam (journal.range), whose row's onChange repaints
--- the Journal (settings/Journal.lua).
function J.SelectRange(range)
    if not RANGE_LABEL[range] then return false end
    state.logOffset = 0
    if NS.SetByPath then NS.SetByPath("journal.range", range) else J.Refresh() end
    return true
end

--- The epoch second `range` starts at over `log` (nil: the read log): this session's start, `now`
--- less the range's days, or 0 for all time.
function J.RangeStart(range, log, now)
    log, now = log or NS.Preview.Log(), tonumber(now) or time()
    if range == "all" then return 0 end
    local days = J.RANGE_DAYS[range]
    if days then return now - days * DAY end
    return log:SessionStart()
end

-- ── Log ──────────────────────────────────────────────────────────────────────────────────────

-- Each column from the list's left (x) or its right edge (r), a fixed width or (Skill) stretching
-- between the two, so the list follows the window's width with no per-tick work. Every cell keeps
-- to its width and truncates (no wrap): nothing runs into the next column at the default width.
local LOG_COLS = {
    { x = 6, w = 50, j = "LEFT" },                    -- Date
    { x = 58, w = 36, j = "LEFT" },                   -- Time
    { x = 98, r = -(70 + 150 + 14), j = "LEFT" },     -- Skill
    { r = -(150 + 10), w = 70, j = "RIGHT" },         -- Change
    { r = -6, w = 150, j = "RIGHT" },                 -- Zone: 150 (owner feedback round 4)
}

local function placeColumns(parent, cols, role)
    local out = {}
    for i, c in ipairs(LOG_COLS) do
        local fs = text(parent, role)
        if c.x then fs:SetPoint("LEFT", parent, "LEFT", c.x, 0) end
        if c.r then fs:SetPoint("RIGHT", parent, "RIGHT", c.r, 0) end
        if c.w then fs:SetWidth(c.w) end
        fs:SetJustifyH(c.j)
        if cols then fs:SetText(cols[i]) end
        out[i] = fs
    end
    return out
end

local function newLogRow(p)
    local row = CreateFrame("Frame", nil, p)
    row:SetHeight(ROW_H)
    row.cols = placeColumns(row, nil, "body")
    NS.Skin.Text(row.cols[1], "muted")
    NS.Skin.Text(row.cols[2], "muted")
    NS.Skin.Text(row.cols[5], "muted")
    return row
end

local function bindLogRow(p, row, e, i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", p.header, "BOTTOMRIGHT", 0, -(i - 1) * ROW_H)
    row.cols[1]:SetText(date(L["%m/%d/%y"], e.t))
    row.cols[2]:SetText(date("%H:%M", e.t))
    row.cols[3]:SetText(skillName(e.key))
    row.cols[4]:SetText(tostring(e.old) .. ARROW .. tostring(e.new))
    row.cols[5]:SetText(e.zone or "")
    row.entry = e
    NS.Skin.ListRow(row, (i % 2 == 0) and "stripe" or "normal")
    row:Show()
end

local function renderLogRows(p, log, from)
    Pool.ReleaseAll(p.pool)
    local list = log:Since(from)
    local n = #list
    state.logOffset = clamp(state.logOffset, 0, max(n - state.logRows, 0))
    local shown, first = 0, n - state.logOffset
    for i = first, max(1, first - state.logRows + 1), -1 do
        shown = shown + 1
        bindLogRow(p, Pool.Acquire(p.pool, function() return newLogRow(p) end), list[i], shown)
    end
    p.empty:SetShown(n == 0)
    p.empty:SetText(#log:Entries() == 0 and L["No skill-ups logged yet."] or L["No skill-ups in this range."])
    p.shown = shown
    p.scroll:Sync(max(n - state.logRows, 0), state.logOffset)
end

--- The range's skills with an ETA, soonest first (`from`: the range's start; nil, this session).
function J.EtaRows(from)
    local log = NS.Preview.Log()
    local _, byKey = log:Gains(from)
    local out = {}
    for key in pairs(byKey) do
        local sec = log:ETA(key, from)
        if sec and sec > 0 then out[#out + 1] = { key = key, sec = sec } end
    end
    table.sort(out, function(a, b)
        if a.sec ~= b.sec then return a.sec < b.sec end
        return a.key < b.key
    end)
    return out
end

--- The summary card's title and rate line for `range` (owner feedback round 4: the card says what it
--- counts). The title names the count, "Skill-ups this session (1 h 20 m)" or "Skill-ups ·
--- Last 7 days"; the rate line is the average and the span it is over: "6.0 an hour" for the session,
--- "38.4 a day over 2 days" otherwise (all time: since the oldest entry, a day at least).
local function summaryLines(SL, range, from, total, now)
    if range == "session" then
        local span = now - SL:SessionStart()
        return L["Skill-ups this session (%s)"]:format(J.FormatDuration(span)),
               L["Average: %.1f an hour"]:format(SL:Rate(span, now))
    end
    local days = J.RANGE_DAYS[range]
    if not days then
        local oldest = SL:Since(from)[1]
        days = max((now - (oldest and oldest.t or now)) / DAY, 1)
    end
    local whole = max(floor(days + 0.5), 1)
    local over = whole == 1 and L["1 day"] or L["%d days"]:format(whole)
    return L["Skill-ups \194\183 %s"]:format(J.RangeLabel(range)),
           L["Average: %.1f a day over %s"]:format(total / days, over)
end

local function renderSide(p, SL, range, from, now)
    local total = SL:Gains(from)
    local title, rate = summaryLines(SL, range, from, total, now)
    p.session.title:SetText(title)
    p.session.value:SetText("+" .. total)
    p.session.rate:SetText(rate)
    local rows = J.EtaRows(from)
    for i, line in ipairs(p.eta.lines) do
        local r = rows[i]
        line.name:SetText(r and skillName(r.key) or "")
        line.value:SetText(r and J.FormatETA(r.sec) or "")
    end
    p.eta.none:SetShown(#rows == 0)
end

local function buildCard(p, h, anchor, y)
    local card = CreateFrame("Frame", nil, p, "BackdropTemplate")
    card:SetSize(SIDE_W, h)
    card:SetPoint("TOPRIGHT", anchor or p, anchor and "BOTTOMRIGHT" or "TOPRIGHT", 0, y or 0)
    card.title = text(card, "heading")
    card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
    card.title:SetWidth(SIDE_W - 20)
    card.title:SetJustifyH("LEFT")
    NS.Skin.Card(card, { title = card.title })
    return card
end

local function buildRangePicker(p)
    local W = NS.Widgets
    local dd = W and W.Dropdown and W.Dropdown(p, SIDE_W, {
        owner = addonName, chevron = NS.Icon and NS.Icon("chevron-down") or nil,
    })
    if not dd then return nil end
    dd:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    local opts = {}
    for i, r in ipairs(J.RANGE_ORDER) do opts[i] = { value = r, label = J.RangeLabel(r) } end
    dd:SetOptions(opts)
    dd.onSelect = function(v) J.SelectRange(v) end
    p.range = dd
    return dd
end

local function buildSessionCard(p)
    local dd = buildRangePicker(p)
    local card = buildCard(p, 76, dd, dd and -8 or 0)
    card.value = text(card, "accent", "GameFontNormalHuge")
    card.value:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.rate = text(card, "muted")
    card.rate:SetPoint("TOPLEFT", card.value, "BOTTOMLEFT", 0, -2)
    p.session = card
end

local function buildEtaCard(p)
    local card = buildCard(p, 30 + ETA_LINES * 16, p.session, -10)
    card.title:SetText(L["ETA to cap"])
    card.lines = {}
    for i = 1, ETA_LINES do
        local name, value = text(card, "body"), text(card, "text.subtle")
        name:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -10 - i * 16)
        name:SetWidth(SIDE_W - 80)
        name:SetJustifyH("LEFT")
        value:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -10 - i * 16)
        value:SetJustifyH("RIGHT")
        card.lines[i] = { name = name, value = value }
    end
    -- The explanation wraps inside the card (FB-32): it ran out past the card's right edge.
    card.none = text(card, "muted")
    card.none:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
    card.none:SetWidth(SIDE_W - 20)
    card.none:SetJustifyH("LEFT")
    card.none:SetWordWrap(true)
    card.none:SetText(L["Two skill-ups of a skill give it an ETA."])
    p.eta = card
end

local function buildLogButtons(p)
    p.newSession = makeButton(p, L["New session"], function() J.NewSession() end)
    p.newSession:SetPoint("TOPLEFT", p.eta, "BOTTOMLEFT", 0, -10)
    p.clear = makeButton(p, L["Clear log"], function() J.ConfirmClear() end)
    p.clear:SetPoint("TOPRIGHT", p.eta, "BOTTOMRIGHT", 0, -10)
end

local function buildLog()
    local p = panel()
    p.header = CreateFrame("Frame", nil, p)
    p.header:SetHeight(16)
    p.header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    p.header:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(SIDE_W + PAD + SCROLL_W + SCROLL_GAP), 0)
    p.headers = placeColumns(p.header, { L["Date"], L["Time"], L["Skill"], L["Change"], L["Zone"] }, "heading")
    p.scroll = makeScrollBar(p, function(offset)
        state.logOffset = offset
        J.Render()
    end)
    p.scroll:SetPoint("TOPLEFT", p.header, "BOTTOMRIGHT", SCROLL_GAP, 0)
    p.scroll:SetPoint("BOTTOMLEFT", p, "BOTTOMRIGHT", -(SIDE_W + PAD + SCROLL_W), 0)
    p.empty = text(p, "muted")
    p.empty:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 6, -8)
    p.empty:SetText(L["No skill-ups logged yet."])
    buildSessionCard(p)
    buildEtaCard(p)
    buildLogButtons(p)
    p:SetScript("OnMouseWheel", function(_, delta)
        state.logOffset = state.logOffset - delta * 3
        J.Render()
    end)
    return p
end

local function renderLog(p)
    local SL, now, range = NS.Preview.Log(), time(), J.SelectedRange()
    local from = J.RangeStart(range, SL, now)
    if p.range then p.range:SelectValue(range) end
    renderLogRows(p, SL, from)
    renderSide(p, SL, range, from, now)
end

-- ── Alts ─────────────────────────────────────────────────────────────────────────────────────

--- Whether the character of `record` can learn catalog skill `key` (owner feedback round 4, an
--- unlearned row): any profession, a weapon skill or Riding its class trains
--- (NS.ClassWeapons_Forever), Lockpicking a rogue's. Defense every character has.
function J.CanLearn(record, key)
    local cat = NS.SkillCatalog and NS.SkillCatalog[key]
    if not cat then return false end
    if cat.category == "primary" or cat.category == "secondary" then return true end
    if cat.kind == "defense" then return true end
    if cat.kind == "lockpicking" then return record.class == "ROGUE" end
    for _, k in ipairs((NS.ClassWeapons_Forever or {})[record.class or ""] or {}) do
        if k == key then return true end
    end
    return false
end

local function skillRows(list, category)
    local info, keys = {}, {}
    local function add(key, name)
        if info[key] then return end
        local cat = NS.SkillCatalog and NS.SkillCatalog[key]
        info[key] = { order = cat and cat.order or 999, name = name or skillName(key) }
        keys[#keys + 1] = key
    end
    for _, item in ipairs(list) do
        for key, s in pairs(item.record.skills or {}) do
            if s.category == category then add(key, s.name) end
        end
        -- Every catalog skill of the block the character can learn, learned or not (round 4).
        for key, cat in pairs(NS.SkillCatalog or {}) do
            if cat.category == category and J.CanLearn(item.record, key) then add(key, L[cat.name]) end
        end
    end
    table.sort(keys, function(a, b)
        local x, y = info[a], info[b]
        if x.order ~= y.order then return x.order < y.order end
        return x.name < y.name
    end)
    local names = {}
    for key, v in pairs(info) do names[key] = v.name end
    return keys, names
end

-- The stat rows of `group`: every catalog stat of the block (NS.STAT_DEFS, in its order), whoever
-- has it; a character whose snapshot lacks one shows a dash.
local function statRows(group)
    local keys, names = {}, {}
    for _, def in ipairs(NS.STAT_DEFS or {}) do
        if def.group == group then
            keys[#keys + 1] = def.key
            names[def.key] = def.label
        end
    end
    return keys, names
end

--- The rows sub-tab `filter` shows across `list` ({ key, record, isCurrent }): a skill block's every
--- skill some character has or can learn (J.CanLearn), in catalog order; a stat block's every stat (statRows).
--- @return table keys, table names by key, string "skill"|"stat"
function J.AltRows(list, filter)
    local f = J.FILTERS[filter]
    if not f then return {}, {}, "skill" end
    if f.source == "stats" then
        local keys, names = statRows(f.filter)
        return keys, names, "stat"
    end
    local keys, names = skillRows(list, f.filter)
    return keys, names, "skill"
end

--- A character's two header lines (FB-33): a two-word Forever name is the given name over the
--- surname; a one-word name is the name over its realm. The second answer says which.
--- @return string line1, string line2, boolean secondIsRealm
function J.NameLines(name, realm)
    name = tostring(name or "")
    local first, rest = name:match("^(%S+)%s+(.+)$")
    if first then return first, rest, false end
    return name, realm or "", true
end

--- The realm part of a store key ("<realm>-<name>", forever-quirks-§4).
function J.RealmOf(key, name)
    key = tostring(key or "")
    name = name and tostring(name)
    if name and #key > #name + 1 and key:sub(-(#name + 1)) == "-" .. name then
        return key:sub(1, #key - #name - 1)
    end
    return key:match("^(.-)%-") or ""
end

local function classColor(r)
    return RAID_CLASS_COLORS and r.class and RAID_CLASS_COLORS[r.class] or nil
end

-- One tooltip line in a skin token's color (the row tooltip's rule: no typed color).
local function tipLine(s, token, wrap)
    local c = NS.Bar.Color(token) or NS.Bar.Color("text.body") or { 1, 1, 1 }
    GameTooltip:AddLine(s, c[1], c[2], c[3], wrap)
end

--- The column header's tooltip: everything about the character the two lines leave out.
local function onHeadEnter(head)
    local item = head.item
    if not (GameTooltip and item) then return end
    local r = item.record
    GameTooltip:SetOwner(head, "ANCHOR_BOTTOM")
    local c = classColor(r)
    if c then GameTooltip:AddLine(r.name or item.key, c.r, c.g, c.b) else tipLine(r.name or item.key, "text.heading") end
    local sub = L["Lv %d %s %s"]:format(r.level or 0, r.race or "", r.className or r.class or "")
    if item.isCurrent then sub = L["%s \194\183 this character"]:format(sub) end
    tipLine(sub, "text.body")
    local realm = J.RealmOf(item.key, r.name)
    if realm ~= "" then tipLine(L["Realm: %s"]:format(realm), "text.muted") end
    if r.faction then tipLine(r.faction, "text.muted") end
    if not item.isCurrent then
        if tonumber(r.updated) then tipLine(L["Last seen: %s"]:format(date(L["%m/%d %H:%M"], r.updated)), "text.muted") end
        tipLine(L["Right-click to forget this character."], "text.muted", true)
    end
    GameTooltip:Show()
end

local function newHead(header, c)
    local head = CreateFrame("Frame", nil, header)
    head:SetSize(COL_W - 4, ALT_HEAD_H)
    head:SetPoint("TOPLEFT", header, "TOPLEFT", LABEL_W + (c - 1) * COL_W + 4, 0)
    head:EnableMouse(true)
    head.line1 = text(head, "body", "GameFontNormalSmall")
    head.line1:SetPoint("TOPLEFT", head, "TOPLEFT", 4, -2)
    head.line2 = text(head, "body", "GameFontNormalSmall")
    head.line2:SetPoint("TOPLEFT", head.line1, "BOTTOMLEFT", 0, -2)
    for _, fs in ipairs({ head.line1, head.line2 }) do
        fs:SetWidth(COL_W - 12)   -- truncated to the column: a long name never runs into the next
        fs:SetJustifyH("LEFT")
    end
    head:SetScript("OnEnter", onHeadEnter)
    head:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    head:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.item then
            J.ConfirmForget(self.item.key, self.item.record.name or self.item.key)
        end
    end)
    return head
end

local function bindHead(head, item)
    head.item = item
    if not item then head:Hide() return end
    local r = item.record
    local one, two, isRealm = J.NameLines(r.name or item.key, J.RealmOf(item.key, r.name))
    head.line1:SetText(one)
    head.line2:SetText(two)
    NS.Skin.Text(head.line1, "body")
    NS.Skin.Text(head.line2, isRealm and "muted" or "body")
    local c = classColor(r)
    if c then
        head.line1:SetTextColor(c.r, c.g, c.b)
        if not isRealm then head.line2:SetTextColor(c.r, c.g, c.b) end
    end
    head:Show()
end

local function newCell(row, c)
    local x = LABEL_W + (c - 1) * COL_W + 8
    local cell = { barW = COL_W - 16 }
    cell.value = text(row, "body")
    cell.value:SetPoint("TOPLEFT", row, "TOPLEFT", x, -5)
    cell.value:SetWidth(COL_W - 12)
    cell.value:SetJustifyH("LEFT")
    cell.bar = NS.Bar.Create(row, "mini")
    cell.bar:SetPoint("TOPLEFT", row, "TOPLEFT", x, -20)
    cell.bar:SetWidth(cell.barW)
    cell.bar:Hide()
    cell.dash = text(row, "disabled")
    cell.dash:SetPoint("TOPLEFT", row, "TOPLEFT", x, -10)
    cell.dash:SetText(DASH)
    -- A skill the character can learn and has not (owner feedback round 4).
    cell.unlearned = text(row, "muted")
    cell.unlearned:SetPoint("TOPLEFT", row, "TOPLEFT", x, -10)
    cell.unlearned:SetWidth(COL_W - 12)
    cell.unlearned:SetJustifyH("LEFT")
    cell.unlearned:SetText(L["Unlearned"])
    cell.unlearned:Hide()
    return cell
end

local function newAltRow(p)
    local row = CreateFrame("Frame", nil, p)
    row:SetHeight(ALT_ROW_H)
    row.label = text(row, "body")
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetWidth(LABEL_W - 12)
    row.label:SetJustifyH("LEFT")
    row.cells = {}
    for c = 1, J.MAX_COLS do row.cells[c] = newCell(row, c) end
    return row
end

local function bindCell(cell, item, key, kind)
    local r, v = item and item.record, nil
    if r and kind == "stat" then v = r.stats and r.stats[key] elseif r then v = r.skills and r.skills[key] end
    local unlearned = r ~= nil and not v and kind == "skill" and J.CanLearn(r, key)
    cell.unlearned:SetShown(unlearned)
    cell.dash:SetShown(r ~= nil and not v and not unlearned)   -- no character in the column: nothing at all
    cell.value:SetShown(v and true or false)
    if not v then return cell.bar:Hide() end
    if kind == "stat" then
        cell.value:SetText(v.display or tostring(v.value))
        drawMiniBar(cell, clamp(tonumber(v.pct) or 0, 0, 100), 100, NS.Rows.FillColor(v, true))
        return
    end
    cell.value:SetText(("%d/%d"):format(v.rank or 0, v.max or 0))
    local e = { category = v.category or "other", rank = v.rank or 0, max = v.max or 0 }
    drawMiniBar(cell, e.rank, e.max, NS.Rows.FillColor(e))
end

local function bindAltRow(p, row, key, name, kind, list, i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -(i - 1) * ALT_ROW_H)
    row:SetPoint("TOPRIGHT", p.header, "BOTTOMRIGHT", 0, -(i - 1) * ALT_ROW_H)
    row.key, row.kind = key, kind
    row.label:SetText(name or key)
    for c = 1, J.MAX_COLS do
        bindCell(row.cells[c], c <= state.altCols and list[c + state.colOffset] or nil, key, kind)
    end
    NS.Skin.ListRow(row, (i % 2 == 0) and "stripe" or "normal")
    row:Show()
end

local function renderAlts(p)
    local list = NS.Preview.Alts():List()
    local keys, names, kind = J.AltRows(list, state.filter)
    state.colOffset = clamp(state.colOffset, 0, max(#list - state.altCols, 0))
    state.altOffset = clamp(state.altOffset, 0, max(#keys - state.altRows, 0))
    p.corner:SetText(NS.BlockDefs[state.filter] and NS.BlockDefs[state.filter].title or "")
    for c = 1, J.MAX_COLS do
        bindHead(p.heads[c], c <= state.altCols and list[c + state.colOffset] or nil)
    end
    for f, chip in pairs(p.chips) do NS.Skin.SetTabSelection(chip, f == state.filter) end
    Pool.ReleaseAll(p.pool)
    local shown = 0
    if #list > 0 then
        for i = 1 + state.altOffset, min(#keys, state.altOffset + state.altRows) do
            shown = shown + 1
            bindAltRow(p, Pool.Acquire(p.pool, function() return newAltRow(p) end),
                keys[i], names[keys[i]], kind, list, shown)
        end
    end
    p.empty:SetShown(#list == 0 or #keys == 0)
    p.empty:SetText(#list == 0 and L["No characters recorded yet."] or L["No character has a skill in this block yet."])
    p.shown, p.rows, p.list = shown, keys, list
    p.scroll:Sync(#list > 0 and max(#keys - state.altRows, 0) or 0, state.altOffset)
end

local function buildAltHeader(p)
    p.header = CreateFrame("Frame", nil, p)
    p.header:SetHeight(ALT_HEAD_H)
    p.header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -(CHIP_H + 6))
    p.header:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(SCROLL_W + SCROLL_GAP), -(CHIP_H + 6))
    p.corner = text(p.header, "heading")
    p.corner:SetPoint("LEFT", p.header, "LEFT", 8, 0)
    p.corner:SetWidth(LABEL_W - 12)
    p.corner:SetJustifyH("LEFT")
    p.heads = {}
    for c = 1, J.MAX_COLS do p.heads[c] = newHead(p.header, c) end
end

local function onAltsWheel(_, delta)
    if IsShiftKeyDown and IsShiftKeyDown() then
        state.colOffset = state.colOffset - delta
    else
        state.altOffset = state.altOffset - delta
    end
    J.Render()
end

--- The chips' widths: each its label plus a margin, shrunk together when the eight would not fit
--- the panel's width at the default size (a wider skin face).
local function layoutChips(p)
    local avail = WIDTH - PAD * 2 - CHIP_GAP * (#J.FILTER_ORDER - 1)
    local widths, sum = {}, 0
    for i, f in ipairs(J.FILTER_ORDER) do
        widths[i] = max(floor((tonumber(p.chips[f].text:GetStringWidth()) or 0) + 16 + 0.5), 40)
        sum = sum + widths[i]
    end
    local scale = sum > avail and avail / sum or 1
    local x = 0
    for i, f in ipairs(J.FILTER_ORDER) do
        local chip, w = p.chips[f], floor(widths[i] * scale)
        chip:SetWidth(w)
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", p, "TOPLEFT", x, 0)
        x = x + w + CHIP_GAP
    end
end

local function buildAlts()
    local p = panel()
    p.chips = {}
    for _, f in ipairs(J.FILTER_ORDER) do
        local chip = makeTab(p, J.FilterLabel(f), 40, CHIP_H, function() J.SelectFilter(f) end)
        NS.Skin.Tab(chip, { selected = f == state.filter, text = chip.text })
        p.chips[f] = chip
    end
    layoutChips(p)
    buildAltHeader(p)
    p.empty = text(p, "muted")
    p.empty:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 8, -8)
    p.empty:SetText(L["No characters recorded yet."])
    p.foot = text(p, "muted")
    p.foot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    p.foot:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -16, 0)   -- clear of the resize grip
    p.foot:SetJustifyH("LEFT")
    p.foot:SetText(L["Snapshots update on login, logout and every skill change. Right-click a character to forget it."])
    p:SetScript("OnMouseWheel", onAltsWheel)
    p.scroll = makeScrollBar(p, function(offset)
        state.altOffset = offset
        J.Render()
    end)
    p.scroll:SetPoint("TOPLEFT", p.header, "BOTTOMRIGHT", SCROLL_GAP, 0)
    p.scroll:SetPoint("BOTTOMLEFT", p.foot, "TOPRIGHT", 16 + SCROLL_GAP, 4)
    return p
end

-- ── the window ───────────────────────────────────────────────────────────────────────────────

local function buildTabs()
    frame.tabs = {}
    local labels = { log = L["Log"], alts = L["Alts"] }
    for i, key in ipairs({ "log", "alts" }) do
        local tab = makeTab(frame, labels[key], 110, TAB_H, function() J.SelectTab(key) end)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * 112, -TITLE_H - 2)
        NS.Skin.Tab(tab, { selected = key == state.tab, text = tab.text })
        frame.tabs[key] = tab
    end
    frame.rule = frame:CreateTexture(nil, "ARTWORK")
    frame.rule:SetHeight(1)
    frame.rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TITLE_H - TAB_H - 2)
    frame.rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -TITLE_H - TAB_H - 2)
    NS.Skin.Divider(frame.rule)
end

local function buildChrome()
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -7)
    frame.title:SetText(L["Skill Master \194\183 Journal"])
    NS.Skin.Shell(frame)
    NS.Skin.Text(frame.title, "title")
    local close = NS.MakeCloseButton(frame, function() J.Hide() end)
    if close then
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        close:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    end
    frame.close = close
end

local function onDragStart(self)
    if NS.GetSetting("locked") then return end
    self:StartMoving()
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    savePoint()
end

-- ── sizing ───────────────────────────────────────────────────────────────────────────────────

local function rowsFor(h, chrome, rowH)
    h = max(tonumber(h) or 0, HEIGHT)
    return max(1, floor((h - chrome) / rowH))
end

local function colsFor(w)
    w = max(tonumber(w) or 0, WIDTH)
    return clamp(floor((w - PAD * 2 - LABEL_W - SCROLL_W - SCROLL_GAP) / COL_W), 1, J.MAX_COLS)
end

local function hideBeyond(p, count)
    for i, row in ipairs(p.pool.active) do
        if i > count then row:Hide() end
    end
end

--- The cheap layout a size change runs (at most once a frame while the grip is dragged): the
--- visible row and character counts from the new size, and the rows past them hidden. Nothing is
--- re-bound and nothing is read from the log or the snapshots; the release re-binds once (J.Render).
function J.Relayout(w, h)
    if not frame then return end
    h = h or frame:GetHeight()
    state.logRows = rowsFor(h, LOG_CHROME_H, ROW_H)
    state.altRows = rowsFor(h, ALT_CHROME_H, ALT_ROW_H)
    state.altCols = colsFor(w or frame:GetWidth())
    hideBeyond(frame.logPanel, state.logRows)
    hideBeyond(frame.altsPanel, state.altRows)
end

--- How many log rows, alts rows and character columns the current size shows.
function J.VisibleLogRows() return state.logRows end
function J.VisibleAltRows() return state.altRows end
function J.VisibleAltCols() return state.altCols end

-- The screen's size, the grip's own maximum (LibKa0s MakeResizable: UIParent's), or nil unknown.
local function screenMax()
    local w = UIParent and tonumber(UIParent:GetWidth())
    local h = UIParent and tonumber(UIParent:GetHeight())
    if not (w and h and w > 0 and h > 0) then return nil end
    return w, h
end

--- Re-apply the saved size, never below the default and never beyond the screen (a size saved
--- while the grip leapt, FB-33, comes back on the screen).
function J.ApplySize()
    if not frame then return end
    local s = NS.db and NS.db.profile.journal and NS.db.profile.journal.size
    if type(s) ~= "table" then return end
    local w, h = max(tonumber(s.w) or WIDTH, WIDTH), max(tonumber(s.h) or HEIGHT, HEIGHT)
    local sw, sh = screenMax()
    if sw then w, h = max(min(w, sw), WIDTH), max(min(h, sh), HEIGHT) end
    frame:SetSize(w, h)
    J.Relayout(w, h)
end

local function makeResizable()
    NS.Chrome.MakeResizable(frame, {
        minWidth = WIDTH, minHeight = HEIGHT,
        layout = function(w, h) J.Relayout(w, h) end,
        redraw = function() J.Render() end,
        -- The grab re-anchored the frame by its top-left, so the drop point is saved with the size.
        save = function(w, h)
            saveSize(w, h)
            savePoint()
        end,
        -- Asked at every grab, before the sizing starts: the gate, then the top-left pin.
        canResize = function()
            if NS.GetSetting("locked") then return false end
            pinTopLeft()
            return true
        end,
    })
end

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", J.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata(LAYERS.STRATA.WINDOW)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", onDragStart)
    frame:SetScript("OnDragStop", onDragStop)
    -- The range picker's menu is the library's one shared popup, parented to UIParent: closed with
    -- the window, whatever closed it (Escape, the close control, a slash command).
    frame:SetScript("OnHide", function() if NS.Widgets and NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end end)
    buildChrome()
    buildTabs()
    frame.logPanel = buildLog()
    frame.altsPanel = buildAlts()
    UISpecialFrames[#UISpecialFrames + 1] = J.FRAME_NAME   -- Escape closes it
    frame:Hide()
    applyPoint()
    makeResizable()
    J.ApplySize()
    return frame
end

-- ── the surface ──────────────────────────────────────────────────────────────────────────────

--- Draw the selected tab, one pass.
function J.Render()
    if not frame then return end
    frame.logPanel:SetShown(state.tab == "log")
    frame.altsPanel:SetShown(state.tab == "alts")
    for key, tab in pairs(frame.tabs) do NS.Skin.SetTabSelection(tab, key == state.tab) end
    if state.tab == "log" then
        renderLog(frame.logPanel)
    else
        renderAlts(frame.altsPanel)
    end
end

function J.SelectTab(tab)
    if tab ~= "log" and tab ~= "alts" then return false end
    state.tab = tab
    J.Render()
    return true
end

function J.SelectFilter(filter)
    if not J.FILTERS[filter] then return false end
    state.filter, state.altOffset = filter, 0
    J.Render()
    return true
end

function J.SelectedTab() return state.tab end
function J.SelectedFilter() return state.filter end

function J.NewSession()
    NS.Preview.Log():NewSession()
    J.Render()
end

function J.ClearLog()
    NS.Preview.Log():Clear()
    state.logOffset = 0
    J.Render()
end

StaticPopupDialogs.SKILLMASTER_CLEAR_LOG = {
    text         = L["Clear this character's skill-up log? Every entry is removed."],
    button1      = YES,
    button2      = NO,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function() J.ClearLog() end,
}

--- Ask before clearing the stored log (review F-005), as Forget does. A simulation's or test
--- mode's log is session-only sample data, so it clears at once.
function J.ConfirmClear()
    if NS.Sim:IsActive() or NS.Preview.IsOn() then return J.ClearLog() end
    StaticPopup_Show("SKILLMASTER_CLEAR_LOG")
end

StaticPopupDialogs.SKILLMASTER_FORGET_ALT = {
    text         = L["Forget %s? Their snapshot is removed until they log in again."],
    button1      = YES,
    button2      = NO,
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function(_, key)
        NS.Preview.Alts():Forget(key)
        J.Render()
    end,
}

--- Ask before forgetting a character (a right-click on its column's name).
function J.ConfirmForget(key, name)
    if not key then return end
    if NS.Sim:IsActive() then   -- a destructive act waits for the simulation to end (H5)
        NS.Print(L["Forgetting a character waits until the simulation stops."])
        return
    end
    StaticPopup_Show("SKILLMASTER_FORGET_ALT", name or key, nil, key)
end

function J.Frame() return frame end
function J.IsShown() return frame ~= nil and frame:IsShown() == true end

--- Show the Journal. Refused while stood down, through the one refusal helper.
function J.Show()
    local refusal = NS.StoodDownRefusal()
    if refusal then NS.Print(refusal) return false end
    local f = build()
    if not f:IsShown() then
        -- The Journal page's Alts sub-tab on open (journal.filter); a chip click holds for the visit.
        local pick = NS.GetSetting and NS.GetSetting("journal.filter")
        if J.FILTERS[pick] then state.filter, state.altOffset = pick, 0 end
    end
    f:Show()
    J.Render()
    return true
end

function J.Hide() if frame then frame:Hide() end end

--- The one toggle handler: `/sm journal` (and, at integration, the title-bar and launcher entries).
function J.Toggle()
    if J.IsShown() then J.Hide() return false end
    return J.Show()
end

function J.Refresh() if J.IsShown() then J.Render() end end
function J.StandDown() J.Hide() end

function J.ResetPosition()
    if NS.db then NS.db.profile.journal.point = false end
    if frame then applyPoint() end
end

--- Re-apply the active profile's drop point and size (a profile switch, copy or reset): the
--- default place and size where the profile stores none.
function J.ApplyGeometry()
    if not frame then return end
    applyPoint()
    local s = NS.db and NS.db.profile.journal and NS.db.profile.journal.size
    if type(s) == "table" then return J.ApplySize() end
    frame:SetSize(WIDTH, HEIGHT)
    J.Relayout(WIDTH, HEIGHT)
end

-- A skill pass (after its SKILL_UPs, so the log is current) and a look change repaint it.
J.events = NS.NewBusTarget()
if J.events then
    J.events:RegisterMessage(NS.MSG.SKILLS_UPDATED, function() J.Refresh() end)
    J.events:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() J.Refresh() end)
end
