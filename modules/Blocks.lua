local _, NS = ...
-- modules/Blocks.lua — the block engine (design §5.2 Display, §6.1, plan Task 3.2): the eight
-- blocks, their persisted layout (docked, order, collapsed, point, scale, locked), the entries
-- each one shows, the collapsible block header, and the one row layout pass the main window and
-- the detached frames both draw with. Detach, Dock and a collapse send LAYOUT_CHANGED.
--
-- NS.BLOCKS = { ids in default order }; NS.BlockDefs[id] = { id, title, source, filter }
-- profile.layout.blocks[id] = { docked, order, collapsed, point, scale, locked }
-- NS.Blocks:Detach(id) / :Dock(id) / :SetCollapsed(id, v) / :ToggleCollapsed(id) / :SetAllCollapsed(v) /
--   :Move(from, to) / :SetOrder(id, n) / .Ordered() (every block, shown or not, in its order)
-- NS.Blocks.Docked() / .Undocked() / .Entries(id) / .Meta(id, entries) / .Settings(id)
-- NS.Blocks.SortOf(id) / :CycleSort(id) / .SortEntries(id, items, entryOf): each block's row order
--   (owner feedback round 3): "name" (the catalog's: skills by name, stats as defined), "value"
--   (high first), "valueAsc" (low first) or "progress" (nearest its max first); the LDB tooltip
--   sorts its sections the same way.
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
    other         = def("other", L["Other skills"], "skills", "other"),
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
        if s and s.shown ~= false and (s.docked ~= false) == docked then out[#out + 1] = id end
    end
    return byOrder(out)
end

--- Every block, shown or hidden, docked or not, in its order (the Layout page's drag list).
function B.Ordered()
    local out = {}
    for i, id in ipairs(NS.BLOCKS) do out[i] = id end
    return byOrder(out)
end

--- The docked blocks, in their order.
function B.Docked() return pick(true) end
--- The detached blocks.
function B.Undocked() return pick(false) end

-- While B:SetAllCollapsed writes, the collapses stay quiet: one click, one LAYOUT_CHANGED.
local bulk = false

function B.Changed()
    if bulk then return end
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

--- The rows' own writes (settings/Layout.lua's `set`): every actor reaches them through NS.SetByPath
--- (architecture-§5), so the seam logs each one (debug-logging-§10). A dock or a collapse waits out
--- combat, as it moves rows the crafting overlays are synced over.
-- What the last stored dock or collapse did: true ran now, false waits for the end of combat.
local lastRan = true

function B.StoreDocked(id, docked)
    local s = B.Settings(id)
    if not s then return false end
    lastRan = whenSafe("dock:" .. id, function()
        s.docked = docked and true or false
        B.Changed()
    end)
    return lastRan
end

function B.StoreCollapsed(id, collapsed)
    local s = B.Settings(id)
    if not s then return false end
    lastRan = whenSafe("collapse:" .. id, function()
        s.collapsed = collapsed and true or false
        B.Changed()
    end)
    return lastRan
end

local function path(id, key) return ("layout.blocks.%s.%s"):format(id, key) end

--- Write through the seam; answers false on a refusal or a write that waits for the end of combat.
local function seam(p, v)
    local set = NS.SetByPath
    if not set then return false end
    lastRan = true
    return set(p, v) == true and lastRan ~= false
end

--- The next sort mode for block `id` (its header's sort mark): Default, Value high, Value low,
--- Progress, round again. Through the seam, so Layout > Blocks shows it.
function B:CycleSort(id)
    local cur, nextMode = B.SortOf(id), B.SORTS[1]
    for i, m in ipairs(B.SORTS) do
        if m == cur then nextMode = B.SORTS[i % #B.SORTS + 1] end
    end
    return seam(path(id, "sort"), nextMode)
end

--- Pop block `id` out of the window into its own frame. Persisted; sends LAYOUT_CHANGED.
function B:Detach(id)
    local s = B.Settings(id)
    if not s or s.docked == false then return false end
    return seam(path(id, "docked"), false)
end

--- Put block `id` back into the window at its old place in the order.
function B:Dock(id)
    local s = B.Settings(id)
    if not s or s.docked ~= false then return false end
    return seam(path(id, "docked"), true)
end

function B:SetCollapsed(id, collapsed)
    if not B.Settings(id) then return false end
    return seam(path(id, "collapsed"), collapsed and true or false)
end

-- While B:Move renumbers, the order rows' onChange stays quiet: one drag, one LAYOUT_CHANGED.
local moving = false

--- The order rows' onChange (settings/Layout.lua).
function B.OrderChanged()
    if not moving then B.Changed() end
end

--- Move the block at position `from` of B.Ordered() to position `to`, renumbering every block
--- 1..n (the Layout page's drag list), each changed `order` through the seam in one bracket. Sends
--- one LAYOUT_CHANGED.
function B:Move(from, to)
    local ids = B.Ordered()
    local moved = table.remove(ids, from)
    if not moved or from == to then return false end
    table.insert(ids, math.max(1, math.min(to, #ids + 1)), moved)
    local entries = {}
    for i, id in ipairs(ids) do
        if B.Settings(id).order ~= i then entries[#entries + 1] = { path = path(id, "order"), value = i } end
    end
    local S = NS.SchemaRuntime
    moving = true
    local function write() for _, e in ipairs(entries) do seam(e.path, e.value) end end
    -- One bracket, so the seam logs the drag as one bulk line (debug-logging-§10).
    local ok, err = pcall(function()
        if S and S.BulkRun then S.BulkRun("reorder", "layout.blocks", write) else write() end
    end)
    moving = false
    if not ok then error(err, 0) end
    B.Changed()
    return true
end

--- Give block `id` the order `n` (through the seam: the CLI's write of layout.blocks.<id>.order).
--- Another block may share the number for a moment; ties sort by id.
function B:SetOrder(id, n)
    n = tonumber(n)
    if not (B.Settings(id) and n) then return false end
    return seam(path(id, "order"), math.floor(n))
end

--- Collapse (true) or expand (false) every docked block, each through the seam as its chevron's
--- write is (the main window's Collapse all and Expand all, FB-16). A detached block keeps its own
--- state: its frame has its own chevron. One bracket, one LAYOUT_CHANGED; in combat each write
--- waits for the end of combat, as a chevron's does. Answers how many blocks it changed.
function B:SetAllCollapsed(collapsed)
    collapsed = collapsed and true or false
    local ids = {}
    for _, id in ipairs(B.Docked()) do
        if (B.Settings(id).collapsed and true or false) ~= collapsed then ids[#ids + 1] = id end
    end
    if #ids == 0 then return 0 end
    local S = NS.SchemaRuntime
    local function write() for _, id in ipairs(ids) do B:SetCollapsed(id, collapsed) end end
    bulk = true
    local ok, err = pcall(function()
        if S and S.BulkRun then S.BulkRun(collapsed and "collapse" or "expand", "layout.blocks", write)
        else write() end
    end)
    bulk = false
    if not ok then error(err, 0) end
    B.Changed()
    return #ids
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

--- The keys hidden from block `id` (skills.hidden / stats.hidden, set true): a skill whose
--- catalog category, else model category, is the block's; a stat whose group is the block's.
--- @return table keys, string "skills"|"stats"
function B.HiddenKeys(id)
    local d = NS.BlockDefs[id]
    if not d then return {}, "skills" end
    local kind = d.source == "skills" and "skills" or "stats"
    local p = NS.db and NS.db.profile
    local set = p and p[kind] and p[kind].hidden or {}
    local groupOf = {}
    if kind == "stats" then
        for _, sd in ipairs(NS.STAT_DEFS or {}) do groupOf[sd.key] = sd.group end
    end
    local model = kind == "skills" and NS.SkillData and type(NS.SkillData.Model) == "function" and NS.SkillData:Model()
    local out = {}
    for key, on in pairs(set) do
        if on == true then
            local group
            if kind == "stats" then
                group = groupOf[key]
            else
                local cat = NS.SkillCatalog[key]
                local e = model and model.byKey and model.byKey[key]
                group = (cat and cat.category) or (e and e.category)
            end
            if group == d.filter then out[#out + 1] = key end
        end
    end
    table.sort(out)
    return out, kind
end

--- Show every row hidden from block `id` again, through the seam (owner feedback round 4: from
--- the window, without the settings). A key with its own schema row is cleared there; any other
--- (an "other:" line) through the whole set's row, as the row menu's Hide writes it.
--- @return number how many rows came back
function B.RestoreHidden(id)
    local keys, kind = B.HiddenKeys(id)
    if #keys == 0 then return 0 end
    local rest = {}
    for k, v in pairs(NS.db.profile[kind].hidden or {}) do rest[k] = v end
    local whole = false
    for _, key in ipairs(keys) do
        local p = kind .. ".hidden." .. key
        if NS.FindSchemaRow(p) then NS.SetByPath(p, false) else rest[key], whole = nil, true end
    end
    if whole then
        for k in pairs(rest) do if NS.db.profile[kind].hidden[k] ~= true then rest[k] = nil end end
        NS.SetByPath(kind .. ".hidden", rest)
    end
    NS.Debug("Click", "restored %d hidden row(s) in %s", #keys, id)
    return #keys
end

local function statEntries(stats, group)
    local out = {}
    for _, e in ipairs(stats and stats[group] or {}) do
        if not hidden("stats", e.key) then out[#out + 1] = { kind = "stat", entry = e } end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Sorting (owner feedback round 3): a block's rows in its stored order, cycled from its header
-- ---------------------------------------------------------------------------------------------

B.SORTS = { "name", "value", "valueAsc", "progress" }
B.SORT_ICON = { name = "list", value = "sort-desc", valueAsc = "sort-asc", progress = "ph:sort-descending" }
B.SORT_LABEL = {
    name = L["Default order"], value = L["Value, highest first"], valueAsc = L["Value, lowest first"],
    progress = L["Progress to max, nearest first"],
}

--- Block `id`'s sort mode, "name" when unset or unknown.
function B.SortOf(id)
    local s = B.Settings(id)
    local mode = s and s.sort
    return B.SORT_LABEL[mode] and mode or "name"
end

local function numeric(e)
    if e.rank ~= nil then return tonumber(e.rank) or 0 end
    return tonumber(e.value) or tonumber(e.pct) or 0
end

local function progress(e)
    if e.rank ~= nil then
        local max = tonumber(e.max) or 0
        return max > 0 and (tonumber(e.rank) or 0) / max or 0
    end
    return tonumber(e.pct) or 0
end

local KEY = { value = numeric, valueAsc = numeric, progress = progress }

--- `items` in block `id`'s order, in place: `entryOf(item)` is the item's model entry (default
--- item.entry). A not-learned row stays below the learned ones; a tie keeps the catalog's order.
function B.SortEntries(id, items, entryOf)
    local mode = B.SortOf(id)
    local key = KEY[mode]
    if not key then return items end
    entryOf = entryOf or function(item) return item.entry end
    local rank = {}
    for i, item in ipairs(items) do
        local e = entryOf(item)
        rank[item] = { learned = e.learned ~= false, v = key(e), i = i }
    end
    table.sort(items, function(a, b)
        local x, y = rank[a], rank[b]
        if x.learned ~= y.learned then return x.learned end
        if x.v ~= y.v then
            if mode == "valueAsc" then return x.v < y.v end
            return x.v > y.v
        end
        return x.i < y.i
    end)
    return items
end

--- The rows block `id` shows, each { kind = "skill"|"stat", entry }, in its sort order.
function B.Entries(id, skills, stats)
    local d = NS.BlockDefs[id]
    if not d then return {} end
    if skills == nil and stats == nil then skills, stats = B.Data() end
    if d.source == "skills" then return B.SortEntries(id, skillEntries(skills, d.filter)) end
    return B.SortEntries(id, statEntries(stats, d.filter))
end

-- No counts beside a title (owner feedback round 4): only Base & Combat says what its bars scale to.
local META = {
    stats_base = function() return L["vs highest primary"] end,
}

--- The muted line beside a block's title: Base & Combat's scale note, else nothing.
function B.Meta(id, entries)
    local fn = META[id]
    if fn then return fn(entries) end
    return ""
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
        collapsed and ">" or "v")
    -- Detach is the external-link mark; dock (attach) is the same mark turned 180 degrees.
    NS.Chrome.SetIcon(self.detach, "external-link", docked and "+" or "-", not docked)
    self.detach.tip = docked and L["Detach this block into its own frame"] or L["Dock this block in the main window"]
    local mode = B.SortOf(id)
    NS.Chrome.SetIcon(self.sort, B.SORT_ICON[mode], "=")
    self.sort.tip = L["Sorted: %s. Click for the next order."]:format(B.SORT_LABEL[mode])
    self.docked = docked
    B.PaintRestore(self.restore, id)
    self.meta:ClearAllPoints()
    self.meta:SetPoint("RIGHT", self.restore:IsShown() and self.restore or self.sort, "LEFT", -6, 0)
end

--- The restore mark (owner feedback round 4): shown while block `id` has hidden rows, its tip
--- saying how many. Shared by the window's header and the detached frame's band.
function B.PaintRestore(mark, id)
    local n = #(B.HiddenKeys(id))
    mark:SetShown(n > 0)
    mark.tip = n == 1 and L["1 hidden row. Click to show it again."]
        or L["%d hidden rows. Click to show them again."]:format(n)
end

local function onHeaderClick(self) B:ToggleCollapsed(self.id) end

local function onDetachClick(self)
    local h = self:GetParent()
    if h.docked then B:Detach(h.id) else B:Dock(h.id) end
end

local function onRestoreClick(self)
    local h = self:GetParent()
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end   -- its tip names a count about to go
    B.RestoreHidden(h.id)
end

local function onSortClick(self)
    local h = self:GetParent()
    B:CycleSort(h.id)
    if self:IsMouseOver() == true and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
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
    h.chevron = NS.Chrome.IconButton(h, "chevron-down", "v", function() onHeaderClick(h) end)
    h.chevron:SetPoint("LEFT", h, "LEFT", 4, 0)
    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.title:SetPoint("LEFT", h.chevron, "RIGHT", 2, 0)
    NS.Skin.Text(h.title, "heading")
    h.detach = NS.Chrome.IconButton(h, "external-link", "+", onDetachClick)
    NS.Chrome.SetRestToken(h.detach, "text.heading")   -- the title's color at rest (round 2)
    h.detach:SetPoint("RIGHT", h, "RIGHT", -4, 0)
    -- The sort mark (owner feedback round 3), left of detach in the same rest color.
    h.sort = NS.Chrome.IconButton(h, "list", "=", onSortClick)
    NS.Chrome.SetRestToken(h.sort, "text.heading")
    h.sort:SetPoint("RIGHT", h.detach, "LEFT", -4, 0)
    -- The restore mark (owner feedback round 4), left of sort, only while the block hides rows.
    h.restore = NS.Chrome.IconButton(h, "eye", "o", onRestoreClick)
    NS.Chrome.SetRestToken(h.restore, "text.heading")
    h.restore:SetPoint("RIGHT", h.sort, "LEFT", -4, 0)
    h.restore:Hide()
    h.meta = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    h.meta:SetPoint("RIGHT", h.sort, "LEFT", -6, 0)
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
    local log = NS.Preview and NS.Preview.Log() or NS.SessionLog
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
    if NS.Detached then NS.Detached.Refresh(false) end   -- data only: no frame is re-anchored
end

-- A layout change (a dock, a collapse, a hidden row) or a skin switch: a full layout even when the
-- row set did not move, because a values-only pass would leave every bar, header and icon well in
-- the old skin's colors.
local function relayout()
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    if NS.MainWindow then NS.MainWindow.Refresh(true) end
    if NS.Detached then NS.Detached.Refresh() end
    -- The in-game check that a look write reached the bars (/sm debug): the bar height drawn now.
    if NS.State.debug then
        NS.Debug("Set", "relayout: %d window rows restyled, bar height %s",
            NS.MainWindow and #NS.MainWindow.Rows() or 0, tostring(NS.Bar.ResolveStyle("row").height))
    end
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
