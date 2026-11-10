local _, NS = ...
-- modules/Journal.lua — the Journal window (design §6.4, mockup Journal.dc.html), a standalone window
-- with two tabs. Session Log: the skill-ups newest first (time, skill, change, zone), this session's
-- gains and rate, the ETA to cap, New session and Clear log. Alts: characters x skills with mini
-- bars, filtered by Professions / Weapons / Other; right-click a character to forget it.
--
-- standalone-windows: a plain frame, toplevel in the window tier, Escape closes it, the close
-- control through NS.MakeCloseButton, the drop point saved by its one writer (savePoint, below).
-- Resizable from a bottom-right grip (NS.Chrome.MakeResizable), never smaller than its default:
-- while sizing only the visible row counts change (J.Relayout, at most once a frame); the rows are
-- re-bound once, on release, and the size is saved then (saveSize, its one writer). The lists
-- stretch with the width through their anchors; the alts grid keeps its column pitch.
-- A display: it reads NS.SessionLog and NS.Alts through NS.Preview.Log() / .Alts() (test mode's
-- sample while it is on, T5.2) and repaints on SKILLS_UPDATED and LAYOUT_CHANGED.

NS.Journal = {}
local J = NS.Journal
local L = NS.L
local LAYERS = NS.Constants.LAYERS
local Pool = NS.Pool
local floor, min, max = math.floor, math.min, math.max

J.FRAME_NAME = "SkillMasterJournal"
J.MAX_COLS = 5
J.FILTER_ORDER = { "professions", "weapons", "other" }
J.FILTERS = {
    professions = { primary = true, secondary = true },
    weapons     = { weapon = true },
    other       = { other = true },
}
local FILTER_LABEL = { professions = L["Professions"], weapons = L["Weapons"], other = L["Other"] }

local WIDTH, HEIGHT, TITLE_H, TAB_H, PAD = 640, 420, 26, 24, 12
local SIDE_W, ROW_H, ALT_ROW_H, CHAR_W, ETA_LINES = 190, 18, 32, 150, 5
local BODY_TOP = TITLE_H + TAB_H + 8
local LOG_CHROME_H = BODY_TOP + PAD + 20             -- above and below the log's rows
local ALT_CHROME_H = BODY_TOP + PAD + 26 + 22 + 20   -- the chips, the header and the footnote
J.MIN_W, J.MIN_H = WIDTH, HEIGHT
J.LOG_ROWS = floor((HEIGHT - LOG_CHROME_H) / ROW_H)
J.ALT_ROWS = floor((HEIGHT - ALT_CHROME_H) / ALT_ROW_H)
local COL_W = floor((WIDTH - PAD * 2 - CHAR_W) / J.MAX_COLS)
local ARROW = " -> "   -- ASCII: every shipped skin face draws it (the old U+2192 was a box in some)
local DASH = "\226\128\148"
local CAT_RANK = { primary = 1, secondary = 2, weapon = 3, other = 4 }

local frame   -- built on first show
local state = { tab = "log", filter = "professions", logOffset = 0, altOffset = 0, colOffset = 0,
                logRows = J.LOG_ROWS, altRows = J.ALT_ROWS }

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

local function drawMiniBar(cell, s)
    local e = { category = s.category or "other", rank = s.rank or 0, max = s.max or 0 }
    cell.bar:ApplyStyle(NS.Bar.ResolveStyle("mini"))   -- a skin or profile change since the last draw
    cell.bar:SetValues({ value = e.rank, max = e.max, color = NS.Rows.FillColor(e) })
    cell.bar:Show()
end

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

-- ── Session Log ──────────────────────────────────────────────────────────────────────────────

-- Each column from the list's left (x) or its right edge (r), a fixed width or (Skill) stretching
-- between the two, so the list follows the window's width with no per-tick work.
local LOG_COLS = {
    { x = 6, w = 50, j = "LEFT" },
    { x = 60, r = -(80 + 110 + 14), j = "LEFT" },
    { r = -(110 + 10), w = 80, j = "RIGHT" },
    { r = -6, w = 110, j = "RIGHT" },
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
    NS.Skin.Text(row.cols[4], "muted")
    return row
end

local function bindLogRow(p, row, e, i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", p.header, "BOTTOMRIGHT", 0, -(i - 1) * ROW_H)
    -- Today's rows show the time; a row from another day its date too (the log spans days).
    local sameDay = date("%x", e.t) == date("%x")
    row.cols[1]:SetText(date(sameDay and "%H:%M" or L["%m/%d %H:%M"], e.t))
    row.cols[2]:SetText(skillName(e.key))
    row.cols[3]:SetText(tostring(e.old) .. ARROW .. tostring(e.new))
    row.cols[4]:SetText(e.zone or "")
    row.entry = e
    NS.Skin.ListRow(row, (i % 2 == 0) and "stripe" or "normal")
    row:Show()
end

local function renderLogRows(p)
    Pool.ReleaseAll(p.pool)
    local log = NS.Preview.Log():Entries()
    local n = #log
    state.logOffset = clamp(state.logOffset, 0, max(n - state.logRows, 0))
    local shown, first = 0, n - state.logOffset
    for i = first, max(1, first - state.logRows + 1), -1 do
        shown = shown + 1
        bindLogRow(p, Pool.Acquire(p.pool, function() return newLogRow(p) end), log[i], shown)
    end
    p.empty:SetShown(n == 0)
    p.shown = shown
end

--- This session's skills with an ETA, soonest first.
function J.EtaRows()
    local log = NS.Preview.Log()
    local _, byKey = log:Gains()
    local out = {}
    for key in pairs(byKey) do
        local sec = log:ETA(key)
        if sec and sec > 0 then out[#out + 1] = { key = key, sec = sec } end
    end
    table.sort(out, function(a, b)
        if a.sec ~= b.sec then return a.sec < b.sec end
        return a.key < b.key
    end)
    return out
end

local function renderSide(p)
    local SL, now = NS.Preview.Log(), time()
    local span = now - SL:SessionStart()
    local total = SL:Gains()
    p.session.title:SetText(L["This session \194\183 %s"]:format(J.FormatDuration(span)))
    p.session.value:SetText("+" .. total)
    p.session.rate:SetText(L["%.1f skill-ups / hour"]:format(SL:Rate(span, now)))
    local rows = J.EtaRows()
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
    NS.Skin.Card(card, { title = card.title })
    return card
end

local function buildSessionCard(p)
    local card = buildCard(p, 76)
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
    card.none = text(card, "muted")
    card.none:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
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
    p.header:SetPoint("TOPRIGHT", p, "TOPRIGHT", -(SIDE_W + PAD), 0)
    p.headers = placeColumns(p.header, { L["Time"], L["Skill"], L["Change"], L["Zone"] }, "heading")
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

-- ── Alts ─────────────────────────────────────────────────────────────────────────────────────

--- The skill columns `filter` shows across `list`: catalog category, then catalog order, then name.
--- @return table keys, table names by key
function J.AltColumns(list, filter)
    local cats, info, cols = J.FILTERS[filter] or {}, {}, {}
    for _, item in ipairs(list) do
        for key, s in pairs(item.record.skills or {}) do
            if cats[s.category] and not info[key] then
                local cat = NS.SkillCatalog and NS.SkillCatalog[key]
                info[key] = { rank = CAT_RANK[s.category] or 9, order = cat and cat.order or 999,
                              name = s.name or skillName(key) }
                cols[#cols + 1] = key
            end
        end
    end
    table.sort(cols, function(a, b)
        local x, y = info[a], info[b]
        if x.rank ~= y.rank then return x.rank < y.rank end
        if x.order ~= y.order then return x.order < y.order end
        return x.name < y.name
    end)
    local names = {}
    for key, v in pairs(info) do names[key] = v.name end
    return cols, names
end

local function newCell(row, c)
    local x = CHAR_W + (c - 1) * COL_W + 8
    local cell = { barW = COL_W - 16 }
    cell.value = text(row, "body")
    cell.value:SetPoint("TOPLEFT", row, "TOPLEFT", x, -5)
    cell.bar = NS.Bar.Create(row, "mini")
    cell.bar:SetPoint("TOPLEFT", row, "TOPLEFT", x, -20)
    cell.bar:SetWidth(cell.barW)
    cell.bar:Hide()
    cell.dash = text(row, "disabled")
    cell.dash:SetPoint("TOPLEFT", row, "TOPLEFT", x, -10)
    cell.dash:SetText(DASH)
    return cell
end

local function onAltEnter(row)
    if not (GameTooltip and row.altKey) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.altName or row.altKey)
    GameTooltip:AddLine(row.altKey, nil, nil, nil, true)
    GameTooltip:Show()
end

local function newAltRow(p)
    local row = CreateFrame("Frame", nil, p)
    row:SetHeight(ALT_ROW_H)
    row:EnableMouse(true)
    row.name = text(row, "body", "GameFontNormalSmall")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.name:SetWidth(CHAR_W - 12)
    row.name:SetJustifyH("LEFT")
    row.sub = text(row, "muted")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.sub:SetWidth(CHAR_W - 12)
    row.sub:SetJustifyH("LEFT")
    row.cells = {}
    for c = 1, J.MAX_COLS do row.cells[c] = newCell(row, c) end
    row:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then J.ConfirmForget(self.altKey, self.altName) end
    end)
    row:SetScript("OnEnter", onAltEnter)
    row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return row
end

local function bindCell(cell, key, skills)
    local s = key and skills[key]
    cell.value:SetShown(s ~= nil)
    cell.dash:SetShown(key ~= nil and s == nil)
    if not s then
        cell.bar:Hide()
        return
    end
    cell.value:SetText(("%d/%d"):format(s.rank or 0, s.max or 0))
    drawMiniBar(cell, s)
end

local function altSubtitle(item)
    local r = item.record
    local sub = L["Lv %d %s %s"]:format(r.level or 0, r.race or "", r.className or r.class or "")
    if item.isCurrent then sub = sub .. " \194\183 " .. L["this character"] end
    return sub
end

local function bindAltRow(p, row, item, cols, i)
    local r = item.record
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -(i - 1) * ALT_ROW_H)
    row:SetPoint("TOPRIGHT", p.header, "BOTTOMRIGHT", 0, -(i - 1) * ALT_ROW_H)
    row.altKey, row.altName = item.key, r.name or item.key
    row.name:SetText(row.altName)
    NS.Skin.Text(row.name, "body")
    local color = RAID_CLASS_COLORS and r.class and RAID_CLASS_COLORS[r.class]
    if color then row.name:SetTextColor(color.r, color.g, color.b) end
    row.sub:SetText(altSubtitle(item))
    for c = 1, J.MAX_COLS do bindCell(row.cells[c], cols[c + state.colOffset], r.skills or {}) end
    NS.Skin.ListRow(row, (i % 2 == 0) and "stripe" or "normal")
    row:Show()
end

local function renderAlts(p)
    local list = NS.Preview.Alts():List()
    local cols, names = J.AltColumns(list, state.filter)
    state.colOffset = clamp(state.colOffset, 0, max(#cols - J.MAX_COLS, 0))
    state.altOffset = clamp(state.altOffset, 0, max(#list - state.altRows, 0))
    for c = 1, J.MAX_COLS do
        local key = cols[c + state.colOffset]
        p.colLabels[c]:SetText(key and names[key] or "")
    end
    for f, chip in pairs(p.chips) do NS.Skin.SetTabSelection(chip, f == state.filter) end
    Pool.ReleaseAll(p.pool)
    local shown = 0
    for i = 1 + state.altOffset, min(#list, state.altOffset + state.altRows) do
        shown = shown + 1
        bindAltRow(p, Pool.Acquire(p.pool, function() return newAltRow(p) end), list[i], cols, shown)
    end
    p.empty:SetShown(#list == 0)
    p.shown, p.cols = shown, cols
end

local function buildAltHeader(p)
    p.header = CreateFrame("Frame", nil, p)
    p.header:SetHeight(18)
    p.header:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -28)
    p.header:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -28)
    local who = text(p.header, "heading")
    who:SetPoint("LEFT", p.header, "LEFT", 8, 0)
    who:SetText(L["Character"])
    p.colLabels = {}
    for c = 1, J.MAX_COLS do
        local fs = text(p.header, "heading")
        fs:SetPoint("LEFT", p.header, "LEFT", CHAR_W + (c - 1) * COL_W + 8, 0)
        fs:SetWidth(COL_W - 12)
        fs:SetJustifyH("LEFT")
        p.colLabels[c] = fs
    end
end

local function onAltsWheel(_, delta)
    if IsShiftKeyDown and IsShiftKeyDown() then
        state.colOffset = state.colOffset - delta
    else
        state.altOffset = state.altOffset - delta
    end
    J.Render()
end

local function buildAlts()
    local p = panel()
    p.chips = {}
    for i, f in ipairs(J.FILTER_ORDER) do
        local chip = makeTab(p, FILTER_LABEL[f], 96, 20, function() J.SelectFilter(f) end)
        chip:SetPoint("TOPLEFT", p, "TOPLEFT", (i - 1) * 102, 0)
        NS.Skin.Tab(chip, { selected = f == state.filter, text = chip.text })
        p.chips[f] = chip
    end
    buildAltHeader(p)
    p.empty = text(p, "muted")
    p.empty:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 8, -8)
    p.empty:SetText(L["No characters recorded yet."])
    p.foot = text(p, "muted")
    p.foot:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    p.foot:SetText(L["Snapshots update on login, logout and every skill change. Right-click a character to forget it."])
    p:SetScript("OnMouseWheel", onAltsWheel)
    return p
end

-- ── the window ───────────────────────────────────────────────────────────────────────────────

local function buildTabs()
    frame.tabs = {}
    local labels = { log = L["Session Log"], alts = L["Alts"] }
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

local function hideBeyond(p, count)
    for i, row in ipairs(p.pool.active) do
        if i > count then row:Hide() end
    end
end

--- The cheap layout a size change runs (at most once a frame while the grip is dragged): the
--- visible row counts from the new height, and the rows past them hidden. Nothing is re-bound and
--- nothing is read from the log or the snapshots; the release re-binds once (J.Render).
function J.Relayout(_, h)
    if not frame then return end
    state.logRows = rowsFor(h or frame:GetHeight(), LOG_CHROME_H, ROW_H)
    state.altRows = rowsFor(h or frame:GetHeight(), ALT_CHROME_H, ALT_ROW_H)
    hideBeyond(frame.logPanel, state.logRows)
    hideBeyond(frame.altsPanel, state.altRows)
end

--- How many log rows the current size shows.
function J.VisibleLogRows() return state.logRows end

--- Re-apply the saved size, never below the default.
function J.ApplySize()
    if not frame then return end
    local s = NS.db and NS.db.profile.journal and NS.db.profile.journal.size
    if type(s) ~= "table" then return end
    local w, h = max(tonumber(s.w) or WIDTH, WIDTH), max(tonumber(s.h) or HEIGHT, HEIGHT)
    frame:SetSize(w, h)
    J.Relayout(w, h)
end

local function makeResizable()
    NS.Chrome.MakeResizable(frame, {
        minWidth = WIDTH, minHeight = HEIGHT,
        layout = function(w, h) J.Relayout(w, h) end,
        redraw = function() J.Render() end,
        save = saveSize,
        canResize = function() return not NS.GetSetting("locked") end,
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
        renderLogRows(frame.logPanel)
        renderSide(frame.logPanel)
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
    state.filter, state.colOffset = filter, 0
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

--- Ask before forgetting a character (the Alts grid's right-click).
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
        -- The Journal page's Alts filter on open (journal.filter); a chip click holds for the visit.
        local pick = NS.GetSetting and NS.GetSetting("journal.filter")
        if J.FILTERS[pick] then state.filter, state.colOffset = pick, 0 end
    end
    f:Show()
    J.Render()
    return true
end

function J.Hide() if frame then frame:Hide() end end

--- The one toggle handler: `/skm journal` (and, at integration, the title-bar and launcher entries).
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
