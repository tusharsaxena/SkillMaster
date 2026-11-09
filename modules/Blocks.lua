local _, NS = ...
-- modules/Blocks.lua — the block engine (design §5.2 Display, §6.1, plan Task 3.2): the eight
-- blocks, their persisted layout (docked, order, collapsed, point, scale, locked), the entries
-- each one shows, the collapsible block header, and the one row layout pass the main window and
-- the detached frames both draw with. Detach, Dock and a collapse send LAYOUT_CHANGED.
--
-- NS.BLOCKS = { ids in default order }; NS.BlockDefs[id] = { id, title, source, filter }
-- profile.layout.blocks[id] = { docked, order, collapsed, point, scale, locked }
-- NS.Blocks:Detach(id) / :Dock(id) / :SetCollapsed(id, v) / :ToggleCollapsed(id)
-- NS.Blocks.Docked() / .Undocked() / .Entries(id) / .Meta(id, entries) / .Settings(id)
-- NS.Blocks.source: nil for the live models, or fn() -> skills, stats (test mode's preview, T5.2;
--   the suites' fixtures).

local L = NS.L

NS.BLOCKS = { "primary", "secondary", "weapon", "other", "stats_base", "stats_spell", "stats_defense", "stats_utility" }

local function def(id, title, source, filter)
    return { id = id, title = title, source = source, filter = filter }
end

NS.BlockDefs = {
    primary       = def("primary", L["Primary Professions"], "skills", "primary"),
    secondary     = def("secondary", L["Secondary Skills"], "skills", "secondary"),
    weapon        = def("weapon", L["Weapon Skills"], "skills", "weapon"),
    other         = def("other", L["Defense \194\183 Lockpicking \194\183 Riding"], "skills", "other"),
    stats_base    = def("stats_base", L["Stats \194\183 Base & Combat"], "stats", "base"),
    stats_spell   = def("stats_spell", L["Stats \194\183 Spell & Regen"], "stats", "spell"),
    stats_defense = def("stats_defense", L["Stats \194\183 Defense & Resists"], "stats", "defense"),
    stats_utility = def("stats_utility", L["Stats \194\183 Utility"], "stats", "utility"),
}

NS.Blocks = {}
local B = NS.Blocks
B.HEADER_H = 24

-- ---------------------------------------------------------------------------------------------
-- Layout state: the profile's layout.blocks rows, written here and by the detached frames' drag
-- ---------------------------------------------------------------------------------------------

local function layout() return (NS.db and NS.db.profile.layout) or NS.defaults.profile.layout end

function B.Settings(id) return layout().blocks[id] end

local function byOrder(ids)
    table.sort(ids, function(a, b)
        local sa, sb = B.Settings(a), B.Settings(b)
        if sa.order ~= sb.order then return sa.order < sb.order end
        return a < b
    end)
    return ids
end

local function pick(docked)
    local out = {}
    for _, id in ipairs(NS.BLOCKS) do
        local s = B.Settings(id)
        if s and (s.docked ~= false) == docked then out[#out + 1] = id end
    end
    return byOrder(out)
end

--- The docked blocks, in their order.
function B.Docked() return pick(true) end
--- The detached blocks.
function B.Undocked() return pick(false) end

function B.Changed()
    if NS.bus and NS.MSG then NS.bus:SendMessage(NS.MSG.LAYOUT_CHANGED) end
end

--- Run `fn` now, or after combat (NS.SecureOverlay's queue, T3.3): a dock, detach or collapse moves
--- rows that crafting overlays are synced over, so in combat it waits (Review Focus 3).
local function whenSafe(key, fn)
    local SO = NS.SecureOverlay
    if SO and SO.AfterCombat then return SO:AfterCombat(key, fn) end
    fn()
    return true
end

--- Pop block `id` out of the window into its own frame. Persisted; sends LAYOUT_CHANGED.
function B:Detach(id)
    local s = B.Settings(id)
    if not s or s.docked == false then return false end
    return whenSafe("dock:" .. id, function()
        s.docked = false
        B.Changed()
    end)
end

--- Put block `id` back into the window at its old place in the order.
function B:Dock(id)
    local s = B.Settings(id)
    if not s or s.docked ~= false then return false end
    return whenSafe("dock:" .. id, function()
        s.docked = true
        B.Changed()
    end)
end

function B:SetCollapsed(id, collapsed)
    local s = B.Settings(id)
    if not s then return false end
    return whenSafe("collapse:" .. id, function()
        s.collapsed = collapsed and true or false
        B.Changed()
    end)
end

function B:ToggleCollapsed(id)
    local s = B.Settings(id)
    return s and B:SetCollapsed(id, not s.collapsed)
end

-- ---------------------------------------------------------------------------------------------
-- Data: what each block shows
-- ---------------------------------------------------------------------------------------------

--- The two models the blocks draw: B.source's when set, else the live ones.
function B.Data()
    if B.source then return B.source() end
    local SD, ST = NS.SkillData, NS.StatData
    local skills = SD and type(SD.Model) == "function" and SD:Model() or nil
    local stats = ST and type(ST.Model) == "function" and (ST:Model() or ST:Scan()) or nil
    return skills, stats
end

local function hidden(kind, key)
    local p = NS.db and NS.db.profile
    local list = p and p[kind] and p[kind].hidden
    return list and list[key] == true
end

local function skillEntries(skills, category)
    local out = {}
    local showUnlearned = not (NS.db and NS.db.profile.skills.showUnlearned == false)
    for _, key in ipairs(skills and skills.order[category] or {}) do
        local e = skills.byKey[key]
        if e and not hidden("skills", key) and (e.learned ~= false or showUnlearned) then
            out[#out + 1] = { kind = "skill", entry = e }
        end
    end
    return out
end

local function statEntries(stats, group)
    local out = {}
    for _, e in ipairs(stats and stats[group] or {}) do
        if not hidden("stats", e.key) then out[#out + 1] = { kind = "stat", entry = e } end
    end
    return out
end

--- The rows block `id` shows, each { kind = "skill"|"stat", entry }.
function B.Entries(id, skills, stats)
    local d = NS.BlockDefs[id]
    if not d then return {} end
    if skills == nil and stats == nil then skills, stats = B.Data() end
    if d.source == "skills" then return skillEntries(skills, d.filter) end
    return statEntries(stats, d.filter)
end

local function learnedCount(entries)
    local n = 0
    for _, r in ipairs(entries) do if r.entry.learned ~= false then n = n + 1 end end
    return n
end

local META = {
    primary = function(entries) return ("%d / 2"):format(learnedCount(entries)) end,
    secondary = function(entries) return tostring(learnedCount(entries)) end,
    weapon = function(entries)
        local first = entries[1] and entries[1].entry
        local cap = first and first.learned ~= false and first.max or 0
        return cap > 0 and L["cap %d (5 \195\151 level)"]:format(cap) or ""
    end,
    other = function() return "" end,
    stats_base = function() return L["vs highest primary"] end,
}

--- The muted line beside a block's title (the mockup's: "2 / 2", "cap 110 (5 × level)", a count).
function B.Meta(id, entries)
    local fn = META[id]
    if fn then return fn(entries) end
    return #entries > 0 and tostring(#entries) or ""
end

-- ---------------------------------------------------------------------------------------------
-- The block header: chevron, title, meta, detach (or dock) control
-- ---------------------------------------------------------------------------------------------

local Header = {}

local function paintHeaderBg(h)
    local c = NS.Bar.Color("sm.headerBg")
    if c then h.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
end

function Header:SetBlock(id, meta, collapsed, docked)
    self.id, self.collapsed = id, collapsed and true or false
    paintHeaderBg(self)   -- every layout, so a skin switch reaches a pooled header
    self.title:SetText(NS.BlockDefs[id].title)
    self.meta:SetText(meta or "")
    NS.Chrome.SetIcon(self.chevron, collapsed and "chevron-right" or "chevron-down",
        collapsed and "\226\150\184" or "\226\150\190")
    NS.Chrome.SetIcon(self.detach, docked and "external-link" or "fullscreen-exit", docked and "\226\134\151" or "\226\136\146")
    self.detach.tip = docked and L["Detach this block into its own frame"] or L["Dock this block in the main window"]
    self.docked = docked
end

local function onHeaderClick(self) B:ToggleCollapsed(self.id) end

local function onDetachClick(self)
    local h = self:GetParent()
    if h.docked then B:Detach(h.id) else B:Dock(h.id) end
end

local function buildHeader(parent)
    local h = CreateFrame("Button", nil, parent)
    for k, fn in pairs(Header) do h[k] = fn end
    h:SetHeight(B.HEADER_H)
    h:RegisterForClicks("AnyUp")
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints(h)
    paintHeaderBg(h)
    h.rule = h:CreateTexture(nil, "BORDER")
    h.rule:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    h.rule:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0)
    h.rule:SetHeight(1)
    NS.Skin.Divider(h.rule)
    h.chevron = NS.Chrome.IconButton(h, "chevron-down", "\226\150\190", function() onHeaderClick(h) end)
    h.chevron:SetPoint("LEFT", h, "LEFT", 4, 0)
    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", h.chevron, "RIGHT", 2, 0)
    NS.Skin.Text(h.title, "heading")
    h.detach = NS.Chrome.IconButton(h, "external-link", "\226\134\151", onDetachClick)
    h.detach:SetPoint("RIGHT", h, "RIGHT", -4, 0)
    h.meta = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.meta:SetPoint("RIGHT", h.detach, "LEFT", -6, 0)
    NS.Skin.Text(h.meta, "muted")
    h:SetScript("OnClick", onHeaderClick)
    return h
end

function B.NewHeaderPool() return NS.Pool.New() end

function B.AcquireHeader(pool, parent)
    local h = NS.Pool.Acquire(pool, function() return buildHeader(parent) end)
    h:SetParent(parent)
    h:Show()
    return h
end

function B.ReleaseHeaders(pool)
    NS.Pool.ReleaseAll(pool, function(h) h:ClearAllPoints() end)
end

-- ---------------------------------------------------------------------------------------------
-- One layout pass
-- ---------------------------------------------------------------------------------------------

--- Lay `entries` out as rows in `host` from `y` (px down from its top), each `inset` px in from
--- both sides. An entry's `marked` draws the row's equipped marker. Answers the y under the last row; each row keeps its own top as `row.layY` (the
--- main window's ShowAndScrollTo reads it).
function B.LayRows(entries, host, rowPool, y, styleKey, inset)
    inset = inset or 0
    for i, r in ipairs(entries) do
        local row = NS.Rows.Acquire(rowPool, host, styleKey)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -y)
        row:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inset, -y)
        row.layY = y
        row.marked = r.marked or nil
        if r.kind == "skill" then row:SetSkill(r.entry) else row:SetStat(r.entry) end
        row:SetStripe(i)
        y = y + row:GetHeight()
    end
    return y
end

--- The fresh entry for a row from the current models (by key), for a values-only refresh.
function B.Lookup(skills, stats)
    local index = {}
    for _, group in ipairs({ "base", "spell", "defense", "utility" }) do
        for _, e in ipairs(stats and stats[group] or {}) do index[e.key] = e end
    end
    return function(row)
        local e = row.entry
        if row.kind == "skill" then return skills and skills.byKey[e.key] end
        return index[e.key]
    end
end

--- Whether any shown surface draws the utility stats (the speed ticker runs only then).
function B.UpdateSpeedWatch()
    if not (NS.StatData and NS.StatData.WatchSpeed) then return end
    local s = B.Settings("stats_utility")
    local onScreen
    if s.docked ~= false then
        onScreen = NS.MainWindow and NS.MainWindow.IsShown() and not s.collapsed
    else
        local f = NS.Detached and NS.Detached.Frame("stats_utility")
        onScreen = f and f:IsShown() and not s.collapsed
    end
    NS.StatData:WatchSpeed(onScreen and true or false)
end

-- ---------------------------------------------------------------------------------------------
-- The summary strip's numbers
-- ---------------------------------------------------------------------------------------------

--- Skill points gained this session: the session log's count when it is loaded (T4.3), else the
--- SKILL_UP messages this module has counted since login.
function B.SessionGains()
    local log = NS.SessionLog
    local g = log and log.Gains and log:Gains()
    if type(g) == "number" then return g end
    if type(g) == "table" then return #g end
    return NS.State.sessionGains or 0
end

--- The first profession at (or within 5 of) its rank's cap with a rank left to train:
--- "Leatherworking near cap: train Expert", or nil.
function B.NextAlert(skills)
    if not (skills and NS.Trainers) then return nil end
    for _, category in ipairs({ "primary", "secondary" }) do
        for _, key in ipairs(skills.order[category] or {}) do
            local e = skills.byKey[key]
            if e and e.learned ~= false and (e.max or 0) > 0 and e.rank >= e.max - 5 then
                local nr = NS.Trainers:NextRank(key, e.rank, e.max)
                if nr then return L["%s near cap: train %s"]:format(e.name, nr.rankName) end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------------------------
-- The bus: data and layout messages repaint every surface (a tracked target: stood down with the
-- addon, replayed on stand-up)
-- ---------------------------------------------------------------------------------------------

local function repaint()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if NS.MainWindow then NS.MainWindow.Refresh() end
    if NS.Detached then NS.Detached.Refresh() end
end

-- A layout change (a dock, a collapse, a hidden row) or a skin switch: a full layout even when the
-- row set did not move, because a values-only pass would leave every bar, header and icon well in
-- the old skin's colors.
local function relayout()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if NS.MainWindow then NS.MainWindow.Refresh(true) end
    if NS.Detached then NS.Detached.Refresh() end
end

local function revalue()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if NS.MainWindow then NS.MainWindow.RefreshValues() end
    if NS.Detached then NS.Detached.RefreshValues() end
end

B.events = NS.NewBusTarget()
if B.events then
    B.events:RegisterMessage(NS.MSG.SKILLS_UPDATED, repaint)
    B.events:RegisterMessage(NS.MSG.STATS_UPDATED, repaint)
    B.events:RegisterMessage(NS.MSG.BONUSES_UPDATED, revalue)
    B.events:RegisterMessage(NS.MSG.LAYOUT_CHANGED, relayout)
    B.events:RegisterMessage(NS.MSG.SKILL_UP, function(_, _, old, new)
        NS.State.sessionGains = (NS.State.sessionGains or 0) + math.max(0, (new or 0) - (old or 0))
    end)
end
