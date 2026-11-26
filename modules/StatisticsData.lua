local _, NS = ...
-- modules/StatisticsData.lua — the Statistics model (item SMW-10 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md, the spec's "Statistics (new)"): the character
-- panel's Statistics tab (counters such as Times camped, nested as Character > Wealth), never "stats" (those
-- are Character Stats, modules/StatData.lua). It reads the client through NS.Compat (Forever's
-- GetStatistic(categoryID, index) -> quantity, skip, statID) and announces STATISTICS_UPDATED.
--
-- model = { order = { entries, the tab's order }, byKey = { [key] = entry }, complete, built }
-- entry = a category { key "c:<categoryID>", categoryID, name, family, depth, header = true, nodeKey (its
--   categoryID as a string), hasBar = false } or a row { key "<categoryID>:<statID>", categoryID, statID, index,
--   name, category (its category's name), family, depth, header = false, quantity (the client's, raw), text (as
--   Blizzard shows it: the number, or "--"; a string quantity verbatim) }. A category's rows come first, then its sub-categories, as the tab
--   lays them.
--
-- LAZY, FOLD-DRIVEN READS. The category tree is built once, on first use (one GetCategoryInfo per category):
-- the Statistics window or a block of it drawn, its broker tooltip shown, or a statistic pinned. A category's
-- rows are read only when it is unfolded where it is drawn (the window's folds, or the tooltip's own): the
-- block provider asks SD:Open(store) as it lays the rows. Every category starts folded (modules/Tree.lua), so a
-- first look reads nothing but the tree. Names are cached for the session (they never change).
--
-- CRITERIA_UPDATE (noisy, no payload) is registered ONLY while the Statistics window or a block of it shows,
-- while its broker tooltip shows, or while a statistic is pinned (SD:Watch), and it is debounced: the first
-- event starts a one-shot SD.DEBOUNCE timer (an event-started debounce, not a poll) whose read takes the
-- categories unfolded on a surface that shows again and the pinned rows (each by its index, re-resolved by
-- statID when it moved). Any other category read earlier is marked stale and read again when it next unfolds on
-- a shown surface; so is every one while nothing watched (a closed window shows fresh values as it opens again,
-- SMW-REV). Statistics share no state with the panel: nothing here expands or collapses anything of the client's.
--
-- Test mode draws a sample built by SD.Build from defaults/Preview_Forever.lua (modules/Preview.lua) and reads
-- nothing live; a simulation reads through the seam (core/SimSetup.lua) from its own world, on state of its own
-- (SD:Adopt), and the stop puts the live state back.
--
-- NS.StatisticsData:Model() / :Get(key) / :Use([silent]) / :Open([store]) / :Refresh() / :Watch() /
--   :IsWatching() / :Reset() / :Adopt(state) / .BuildTree(list) (pure) / .Build(list) (pure) / .Display(quantity)
--   / .ValueText(e) / .Live(m)

NS.StatisticsData = {}
local SD = NS.StatisticsData
local L = NS.L
local Perf = NS.Perf

SD.FAMILY, SD.KIND, SD.BLOCK = "statistics", "statistic", "statistics"
SD.DEBOUNCE = 1   -- seconds: one re-read per burst of CRITERIA_UPDATE (the spec)
SD.EVENT = "CRITERIA_UPDATE"

local function emptyModel() return { order = {}, byKey = {}, complete = true, built = false } end

local model = emptyModel()
local cats, catById = {}, {}       -- the category tree, in the tab's order (depth-first), and by id
local rows, readAt, stale = {}, {}, {}   -- categoryID -> its row entries / read / read but folded since
local names = {}                   -- statID -> name, for the session
local watching, timer, tipUp = false, nil, false

--- The model, or nil before the first use and while the client lists no category.
function SD:Model() return (model.built and #model.order > 0) and model or nil end
function SD:Get(key) return model.byKey[tostring(key)] end

--- Whether `m` is the live model, or no model at all outside test mode: a block provider then reads through
--- SD:Open (a simulation's reads go through the seam to its world). A sample (test mode's) is drawn as it is.
function SD.Live(m)
    if m ~= nil then return m == model end
    return not NS.IsTestMode()
end

function SD:IsWatching() return watching end

--- Back to the before-the-first-use state (the suites). Stops watching.
function SD:Reset()
    if timer and NS.addon then NS.addon:CancelTimer(timer) end
    if watching and SD.watch then SD.watch:UnregisterEvent(SD.EVENT) end
    model, cats, catById = emptyModel(), {}, {}
    rows, readAt, stale, names = {}, {}, {}, {}
    watching, timer, tipUp = false, nil, false
end

-- ---------------------------------------------------------------------------------------------
-- The category tree (pure)
-- ---------------------------------------------------------------------------------------------

--- The categories `list` ({ { id, name, parent } } in the client's order) as a depth-first tree: each node
--- { id, name, parent, depth, kids }. A parent of -1, nil, itself or one the list lacks makes a root; a cycle's
--- nodes become roots in their list order.
function SD.BuildTree(list)
    local byId, order = {}, {}
    for _, c in ipairs(list or {}) do
        if c.id ~= nil and not byId[c.id] then
            local node = { id = c.id, name = c.name or tostring(c.id), parent = c.parent, kids = {} }
            byId[c.id] = node
            order[#order + 1] = node
        end
    end
    local roots = {}
    for _, n in ipairs(order) do
        local p = n.parent and byId[n.parent]
        if p and p ~= n then p.kids[#p.kids + 1] = n else roots[#roots + 1] = n end
    end
    local out, seen = {}, {}
    local function walk(n, depth)
        if seen[n] then return end
        seen[n] = true
        n.depth = depth
        out[#out + 1] = n
        for _, k in ipairs(n.kids) do walk(k, depth + 1) end
    end
    for _, r in ipairs(roots) do walk(r, 0) end
    for _, n in ipairs(order) do if not seen[n] then walk(n, 0) end end   -- a cycle: no root reached it
    return out, byId
end

-- ---------------------------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------------------------

--- A quantity as Blizzard's Statistics tab shows it: a number above 0 as the number ("1,234"), else "--"; a
--- string that is not a number verbatim (a value the client formats itself).
function SD.Display(q)
    local n = tonumber(q)
    if n then
        if n <= 0 then return "--" end
        if type(q) == "string" then return q end
        return NS.Tree.Number(n)
    end
    if type(q) == "string" and q ~= "" then return q end
    return "--"
end

local function nameOf(statID)
    local n = names[statID]
    if n == nil then
        n = NS.Compat.StatisticName(statID) or false
        names[statID] = n
    end
    return n or tostring(statID)
end

local function rowEntry(c, index, quantity, statID, name)
    return { key = c.id .. ":" .. tostring(statID), categoryID = c.id, statID = statID, index = index,
             name = name or nameOf(statID), category = c.name, family = SD.FAMILY, depth = c.depth + 1,
             header = false, quantity = quantity, text = SD.Display(quantity) }
end

-- Category `c`'s rows, read now: a row with `skip` or no statID is left out, as the tab leaves it out.
local function readCategory(c)
    local out = {}
    for i = 1, NS.Compat.NumStatistics(c.id) do
        local quantity, skip, statID = NS.Compat.Statistic(c.id, i)
        if statID ~= nil and not skip then out[#out + 1] = rowEntry(c, i, quantity, statID) end
    end
    rows[c.id], readAt[c.id], stale[c.id] = out, true, nil
    return out
end

local function headerEntry(c)
    return { key = "c:" .. tostring(c.id), categoryID = c.id, name = c.name, family = SD.FAMILY, depth = c.depth,
             header = true, nodeKey = tostring(c.id), hasBar = false }
end

-- The model's order again from the tree and the rows read, in place (a block holding the model sees it).
local function rebuild()
    local order, byKey = {}, {}
    for _, c in ipairs(cats) do
        local h = c.entry
        order[#order + 1], byKey[h.key] = h, h
        for _, e in ipairs(rows[c.id] or {}) do order[#order + 1], byKey[e.key] = e, e end
    end
    model.order, model.byKey = order, byKey
end

--- A whole model from `list` ({ { id, name, parent, rows = { { statID, name, quantity, skip } } } }, the tab's
--- order), every row in (pure: test mode's sample is built so, through the same entries as the live read).
function SD.Build(list)
    local tree = SD.BuildTree(list)
    local byId = {}
    for _, c in ipairs(list or {}) do if c.id ~= nil then byId[c.id] = c end end
    local m = emptyModel()
    for _, c in ipairs(tree) do
        local h = headerEntry(c)
        m.order[#m.order + 1], m.byKey[h.key] = h, h
        for i, r in ipairs(byId[c.id] and byId[c.id].rows or {}) do
            if r.statID ~= nil and not r.skip then
                local e = rowEntry(c, i, r.quantity, r.statID, r.name)
                m.order[#m.order + 1], m.byKey[e.key] = e, e
            end
        end
    end
    m.built = true
    return m
end

--- Swap this module's whole state (the model, the tree, the rows read, the names) for `state` (a fresh one when
--- nil) and answer the one it held: the simulator's start and stop. Sends nothing; watching is unchanged.
function SD:Adopt(state)
    local old = { model = model, cats = cats, catById = catById, rows = rows, readAt = readAt, stale = stale,
                  names = names }
    if timer and NS.addon then NS.addon:CancelTimer(timer) end
    timer = nil
    state = state or {}
    model, cats, catById = state.model or emptyModel(), state.cats or {}, state.catById or {}
    rows, readAt, stale, names = state.rows or {}, state.readAt or {}, state.stale or {}, state.names or {}
    return old
end

local function publish()
    NS.bus:SendMessage(NS.MSG.STATISTICS_UPDATED, model)
end

-- ---------------------------------------------------------------------------------------------
-- Pins: "<categoryID>:<statID>"
-- ---------------------------------------------------------------------------------------------

local function parsePin(key)
    local cat, stat = tostring(key):match("^(%-?%d+):(%-?%d+)$")
    return tonumber(cat), tonumber(stat)
end

local function pins()
    return NS.Pins and NS.Pins.Stored(SD.FAMILY) or {}
end

-- A pinned row again, by its index (one call); a row that moved is found by its statID (its category again).
local function readPinned(key)
    local catID, statID = parsePin(key)
    local c = catID and catById[catID]
    if not c then return end
    local e = model.byKey[key]
    if not (e and readAt[catID]) then
        readCategory(c)
        return
    end
    local quantity, skip, sid = NS.Compat.Statistic(catID, e.index)
    if sid == statID and not skip then
        e.quantity, e.text = quantity, SD.Display(quantity)
        return
    end
    readCategory(c)
end

-- ---------------------------------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------------------------------

local function buildTree()
    local list = {}
    for _, id in ipairs(NS.Compat.StatisticsCategories()) do
        local name, parent = NS.Compat.StatisticsCategoryInfo(id)
        list[#list + 1] = { id = id, name = name, parent = parent }
    end
    cats, catById = SD.BuildTree(list)
    for _, c in ipairs(cats) do c.entry = headerEntry(c) end
end

--- The first use: the category tree (once), and the pinned rows' categories. `silent` sends no
--- STATISTICS_UPDATED (a block laying its rows asks; its own pass draws them). Answers the model.
function SD:Use(silent)
    if model.built then return model end
    local t0 = Perf.on and debugprofilestop()
    buildTree()
    for _, key in ipairs(pins()) do
        local catID = parsePin(key)
        local c = catID and catById[catID]
        if c and not readAt[catID] then readCategory(c) end
    end
    rebuild()
    model.built = true
    if t0 then Perf.Note("statisticsRead", debugprofilestop() - t0) end
    NS.Debug("Statistics", "category tree: %d categories", #cats)
    if not silent then publish() end
    return model
end

-- The categories whose rows show under `store`'s folds (the window's when nil): unfolded, every parent
-- unfolded too. Answers { [categoryID] = node }.
local function openUnder(store, into)
    into = into or {}
    local skipBelow
    for _, c in ipairs(cats) do
        if not (skipBelow and c.depth > skipBelow) then
            skipBelow = nil
            if NS.Tree.IsFolded(SD.FAMILY, c.entry.nodeKey, store) then skipBelow = c.depth else into[c.id] = c end
        end
    end
    return into
end

-- Every category read so far is stale: nothing kept it current (CRITERIA_UPDATE was not registered), so the next
-- surface to unfold it reads it again rather than drawing the values it had when it was last on screen.
local function markAllStale()
    for id in pairs(readAt) do stale[id] = true end
end

--- The model with every category unfolded under `store` (the window's folds when nil, the tooltip's own when
--- given) read: a category never read, or read and folded since, or read while nothing watched since, reads
--- now. No message: the caller is laying the rows. Also starts watching CRITERIA_UPDATE when a surface now
--- shows the Statistics (SD:Watch).
function SD:Open(store)
    SD:Use(true)
    if not watching then markAllStale() end   -- a surface laid before its toggle message, or no watch at all
    local t0 = Perf.on and debugprofilestop()
    local n = 0
    for id, c in pairs(openUnder(store)) do
        if not readAt[id] or stale[id] then
            readCategory(c)
            n = n + 1
        end
    end
    if n > 0 then rebuild() end
    if t0 then Perf.Note("statisticsRead", debugprofilestop() - t0) end
    SD:Watch()
    return model
end

local function tipStore()
    local B = NS.Broker
    return B and B.TipNodeStore and B.TipNodeStore(SD.FAMILY) or nil
end

--- The debounced re-read: every category unfolded on a surface that shows now (the window's folds while the
--- Statistics block is on screen, the tooltip's own while it is up) again, every pinned row by its index; any
--- other category read earlier is stale (read again when it next unfolds on a shown surface). Sends
--- STATISTICS_UPDATED. Nothing while test mode or a simulation runs (their samples are drawn instead).
function SD:Refresh()
    if not model.built or not SD.Live(nil) then return nil end
    local t0 = Perf.on and debugprofilestop()
    local open = {}
    if SD.OnScreen() then openUnder(nil, open) end
    if tipUp then openUnder(tipStore(), open) end
    for id in pairs(readAt) do
        if open[id] then readCategory(catById[id]) else stale[id] = true end
    end
    for _, key in ipairs(pins()) do
        local catID = parsePin(key)
        if not (catID and open[catID]) then readPinned(key) end
    end
    rebuild()
    if t0 then Perf.Note("statisticsRead", debugprofilestop() - t0) end
    publish()
    return model
end

-- ---------------------------------------------------------------------------------------------
-- Watching CRITERIA_UPDATE: only while a surface shows the Statistics, or a statistic is pinned
-- ---------------------------------------------------------------------------------------------

-- Whether the Statistics block shows on screen: in its window, detached, or in a merged window.
local function onScreen()
    local W = NS.Windows and NS.Windows.Get(SD.FAMILY)
    if W and W.IsShown() then return true end
    local D = NS.Detached
    local f = D and D.Frame(SD.BLOCK)
    if f and f:IsShown() then return true end
    local G = NS.Groups
    local gid = G and G.Of and G.Of(SD.BLOCK)
    local g = gid and G.Frame(gid)
    return g ~= nil and g:IsShown() == true
end
SD.OnScreen = onScreen   -- SD:Refresh reads through it (tests/perf.lua stands a shown window in)

--- Whether CRITERIA_UPDATE is wanted now: a surface shows the Statistics, its tooltip is up, or a
--- statistic is pinned.
function SD.Wanted()
    return onScreen() or tipUp or #pins() > 0
end

local function flush()
    timer = nil
    SD:Watch()
    if watching then SD:Refresh() end
end

local function onCriteria()
    if NS.IsStoodDown() or timer then return end
    timer = NS.addon:ScheduleTimer(flush, SD.DEBOUNCE)
end
SD.OnCriteria = onCriteria   -- the suites

--- Register or unregister CRITERIA_UPDATE as SD.Wanted says. Answers whether it is registered.
function SD:Watch()
    local want = SD.watch ~= nil and not NS.IsStoodDown() and SD.Wanted()
    if want and not watching then
        markAllStale()   -- nothing kept the categories current while unwatched: the surface now showing reads afresh
        watching = NS.SafeRegisterEvent(SD.watch, SD.EVENT, onCriteria, NS.rejectedEvents) and true or false
    elseif not want and watching then
        SD.watch:UnregisterEvent(SD.EVENT)
        watching = false
        if timer then NS.addon:CancelTimer(timer) timer = nil end
    end
    return watching
end

SD.watch = NS.NewBusTarget()   -- CRITERIA_UPDATE alone, registered and unregistered by SD:Watch
SD.events = NS.NewBusTarget()
if SD.events then
    SD.events:RegisterMessage(NS.MSG.WINDOW_TOGGLED, function(_, fid)
        if fid == SD.FAMILY then SD:Watch() end
    end)
    SD.events:RegisterMessage(NS.MSG.FEED_TOOLTIP_TOGGLED, function(_, fid, shown)
        if fid ~= SD.FAMILY then return end
        tipUp = shown == true
        if tipUp and SD.Live(nil) then SD:Use(true) end   -- before the fill: the tooltip draws the tree
        SD:Watch()
    end)
    -- A pin, a dock, a detach: who shows the Statistics may have changed.
    SD.events:RegisterMessage(NS.MSG.LAYOUT_CHANGED, function() SD:Watch() end)
    -- A pinned statistic's feed text reads it from the login on.
    NS.SafeRegisterEvent(SD.events, "PLAYER_ENTERING_WORLD", function()
        if #pins() > 0 and not model.built and SD.Live(nil) then SD:Use() end
        SD:Watch()
    end, NS.rejectedEvents)
end

-- ---------------------------------------------------------------------------------------------
-- The row kind: what a statistic row draws and says (modules/Tree.lua's kind spec)
-- ---------------------------------------------------------------------------------------------

--- A row's value as the tab shows it; "" for a category.
function SD.ValueText(e)
    if e.header then return "" end
    return e.text or SD.Display(e.quantity)
end

local function lines(e)
    local out = { { left = e.name, tone = "heading" } }
    if e.header then return out end
    out[#out + 1] = { left = L["Value"], right = SD.ValueText(e), tone = "muted", rightTone = "body" }
    if e.category then out[#out + 1] = { left = L["Category"], right = e.category, tone = "muted", rightTone = "body" } end
    return out
end

NS.Tree.RegisterKind(SD.KIND, {
    family = SD.FAMILY,
    values = function() return nil end,   -- a statistic is a count: a value row, never a bar
    valueText = SD.ValueText,
    lines = lines,
    pinText = function(e) return ("%s %s"):format(e.name, SD.ValueText(e)) end,
    linkText = function(e) return ("[%s: %s]"):format(e.name, SD.ValueText(e)) end,
    icon = function() return nil end,
    pinnable = function(e) return not e.header end,
})
