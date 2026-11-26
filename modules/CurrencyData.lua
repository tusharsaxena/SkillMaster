local _, NS = ...
-- modules/CurrencyData.lua — the currencies model (GitHub issue #7; item SMW-09 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md, the spec's "Currencies (#7)"), a sibling of
-- modules/RepData.lua. It reads the client's currency list (NS.Compat, C_CurrencyInfo on WoW Forever) into the
-- Currency tab's own headers (by currencyListDepth) and announces CURRENCIES_UPDATED; an amount that moved is
-- CURRENCY_CHANGED (the Journal's session gains, the optional cap alert).
--
-- NO GOLD (the owner's ruling): the window shows only the client's currencies. Gold is not in the client's
-- currency list, and this module never reads it; an empty list is the window's empty line.
--
-- model = { order = { entries, the panel's order }, byKey = { [key] = entry }, complete, built }
-- entry = { key (a currency's id as a string; a header's "h:<name>#<depth>"), currencyID, name, family, depth,
--   header, nodeKey (a header's fold key, "<name>#<depth>"), hasBar (a currency with a total cap), quantity,
--   maxQuantity, weekly (canEarnPerWeek with a weekly cap), earnedThisWeek, maxWeekly, description, icon }
--
-- THE COLLAPSE TRAP, as for reputations (docs/forever-quirks.md): the first build is a full read through
-- modules/SharedList.lua (out of combat, never while TokenFrame shows, a re-entry latch); every later read goes by
-- id (GetCurrencyInfo, the listed rows first), which touches no state. CURRENCY_DISPLAY_UPDATE's currencyType
-- says which: nil is the client's bulk refresh (every known currency again), an id that one currency (an id the
-- model does not know asks for the full read). This module never folds: the window's folds are its own.
--
-- Events (a tracked bus target): CURRENCY_DISPLAY_UPDATE (coalesced, CD.DEBOUNCE), PLAYER_ENTERING_WORLD and
-- ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED (a full read), PLAYER_REGEN_ENABLED (a partial read's retry).
--
-- NS.CurrencyData:Model() / :Get(key) / .Build(rows, complete) (pure) / :Read() / :Refresh([ids]) /
-- :Request(full[, id]) / :Reset() / .BarValues(e) / .ValueText(e)

NS.CurrencyData = {}
local CD = NS.CurrencyData
local L = NS.L

CD.FAMILY, CD.KIND = "currencies", "currency"
CD.DEBOUNCE = 0.2
CD.EVENTS = { "CURRENCY_DISPLAY_UPDATE", "PLAYER_ENTERING_WORLD", "ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED",
              "PLAYER_REGEN_ENABLED" }

local function emptyModel() return { order = {}, byKey = {}, complete = false, built = false } end

local model = emptyModel()
local timer, wantFull, wantAll, panelHooked
local wantIds = {}   -- the ids CURRENCY_DISPLAY_UPDATE named since the last read, with their quantityChange

--- The model, or nil before the first read and while the list is empty (the surfaces show their empty line).
function CD:Model() return (model.built and #model.order > 0) and model or nil end
function CD:Get(key) return model.byKey[tostring(key)] end

--- Back to the before-the-first-read state (the suites).
function CD:Reset()
    model = emptyModel()
    timer, wantFull, wantAll, wantIds = nil, nil, nil, {}
end

--- Swap the model for `m` (an empty one when nil) and answer the one held: the simulator's start and stop
--- (SMW-11), as RepData's. Sends nothing.
function CD:Adopt(m)
    local old = model
    if timer and NS.addon then NS.addon:CancelTimer(timer) end
    model, timer, wantFull, wantAll, wantIds = m or emptyModel(), nil, nil, nil, {}
    return old
end

-- ---------------------------------------------------------------------------------------------
-- Building: the client's CurrencyInfo rows, in the panel's order, to entries
-- ---------------------------------------------------------------------------------------------

local function num(v) return tonumber(v) or 0 end

-- A header's fold key and entry key: its name and depth ("Miscellaneous#0"), as modules/Tree.lua keys it.
local function headerKeys(e, d, depth, was)
    e.nodeKey = was.nodeKey or NS.Tree.NodeKey(CD.FAMILY, { name = e.name, currencyListDepth = d.currencyListDepth or depth })
    e.key = "h:" .. tostring(e.nodeKey)
end

--- One entry from CurrencyInfo `d` at `depth`; `was`, the entry it refreshes, keeps what a by-id read lacks.
function CD.Entry(d, depth, was)
    was = was or {}
    local header = d.isHeader == true or was.header == true
    local max = num(d.maxQuantity)
    local e = {
        name = d.name or was.name or "", family = CD.FAMILY, depth = depth or 0, header = header,
        quantity = num(d.quantity), maxQuantity = max, hasBar = not header and max > 0,
        weekly = d.canEarnPerWeek == true and num(d.maxWeeklyQuantity) > 0,
        earnedThisWeek = num(d.quantityEarnedThisWeek), maxWeekly = num(d.maxWeeklyQuantity),
        description = d.description or was.description, icon = d.iconFileID or was.icon,
    }
    if header then
        headerKeys(e, d, depth, was)
        return e
    end
    e.currencyID = tonumber(d.currencyID) or was.currencyID
    e.key = tostring(e.currencyID or e.name)
    return e
end

-- The panel's indentation: a header at its own currencyListDepth; a currency one deeper than the header it
-- follows (whatever depth the client gives it, it sits under that header).
local function depthOf(d, ctx)
    local own = tonumber(d.currencyListDepth) or 0
    if d.isHeader then
        ctx.header = own
        return own
    end
    if ctx.header and own <= ctx.header then return ctx.header + 1 end
    return own
end

--- A model from CurrencyInfo rows in the panel's order (pure). Gold never comes here: it is not in the list.
function CD.Build(rows, complete)
    local m, ctx = emptyModel(), {}
    for _, d in ipairs(rows or {}) do
        if type(d) == "table" and d.name then
            local e = CD.Entry(d, depthOf(d, ctx))
            if not m.byKey[e.key] then
                m.order[#m.order + 1] = e
                m.byKey[e.key] = e
            end
        end
    end
    m.complete, m.built = complete ~= false, true
    return m
end

-- ---------------------------------------------------------------------------------------------
-- Reading: the first build in full, every later one by id
-- ---------------------------------------------------------------------------------------------

local function panel() return TokenFrame end

CD.LIST = {
    name = "currencies",
    count = function() return NS.Compat.NumCurrencies() end,
    row = function(i) return NS.Compat.CurrencyListInfo(i) end,
    isClosed = function(r) return r.isHeader == true and not r.isHeaderExpanded end,
    key = function(r) return tostring(r.name) .. "#" .. tostring(r.currencyListDepth) end,
    toggle = function(i, open) return NS.Compat.SetCurrencyHeaderExpanded(i, open) end,
    canToggle = function() return NS.Compat.CanToggleCurrencyHeaders() end,
    panel = panel,
}

-- The amounts that moved since `old`, as CURRENCY_CHANGED (a first build announces none). A change the
-- event named (quantityChange) sets the old amount, so a gain read late is still the gain the client said.
local function announceChanges(old, new, changes)
    if not (old and old.built) then return end
    for _, e in ipairs(new.order) do
        local was = old.byKey[e.key]
        if was and not e.header and e.quantity ~= was.quantity then
            local delta = changes and tonumber(changes[e.key])
            local before = delta and (e.quantity - delta) or was.quantity
            NS.bus:SendMessage(NS.MSG.CURRENCY_CHANGED, e.key, before, e.quantity, e.name)
        end
    end
end

local function publish(m, changes)
    local old = model
    model = m
    announceChanges(old, m, changes)
    NS.bus:SendMessage(NS.MSG.CURRENCIES_UPDATED, m)
    return m
end

local function retryOnPanelHide()
    local f = panel()
    if panelHooked or type(f) ~= "table" or type(f.HookScript) ~= "function" then return end
    panelHooked = true
    f:HookScript("OnHide", function()
        if not model.complete then CD:Request(true) end
    end)
end

--- The full read: every header opened, read, closed again (modules/SharedList.lua). nil while one runs.
function CD:Read()
    local rows, complete, why = NS.SharedList.Read(CD.LIST)
    if not rows then return nil end
    if why == "panel shown" then retryOnPanelHide() end
    NS.Debug("Currencies", "full read: %d rows%s", #rows, complete and "" or (" (partial: " .. tostring(why) .. ")"))
    return publish(CD.Build(rows, complete))
end

local function listed()
    local byKey, unknown = {}, false
    for i = 1, NS.Compat.NumCurrencies() do
        local d = NS.Compat.CurrencyListInfo(i)
        if d and not d.isHeader and d.currencyID then
            local key = tostring(d.currencyID)
            byKey[key] = d
            if not model.byKey[key] then unknown = true end
        end
    end
    return byKey, unknown
end

-- A listed currency the model does not know wants the full read. Answers whether to read now: unless combat or the
-- panel blocks it, when a read would build from the listed rows alone and drop every currency under a collapsed
-- header; the refresh then keeps the model whole and marks it partial, so combat's end or the panel's OnHide
-- reads in full.
local function readNow()
    local why = NS.SharedList.Blocked(CD.LIST)
    if why == "panel shown" then retryOnPanelHide() end
    return why ~= "combat" and why ~= "panel shown"
end

--- The read after the first, touching no list state: every known currency again (the listed row first, then
--- GetCurrencyInfo, else its last values), or only `ids` (a set of keys) when given; `changes` (key ->
--- quantityChange) sets the gains. A currency the model does not know asks for the full read instead (or, while
--- one is blocked, for one later: see readNow).
function CD:Refresh(ids, changes)
    if not model.built then return CD:Read() end
    local byKey, unknown = listed()
    if unknown and readNow() then return CD:Read() end
    local m = emptyModel()
    for _, e in ipairs(model.order) do
        local fresh = e
        if not e.header and (ids == nil or ids[e.key]) then
            local d = byKey[e.key] or (e.currencyID and NS.Compat.CurrencyInfo(e.currencyID))
            if d then fresh = CD.Entry(d, e.depth, e) end
        end
        m.order[#m.order + 1] = fresh
        m.byKey[fresh.key] = fresh
    end
    m.complete, m.built = model.complete and not unknown, true
    return publish(m, changes)
end

local function pendingTimer() return timer ~= nil and NS.addon:TimeLeft(timer) > 0 end

local function flush()
    timer = nil
    local full = wantFull or not model.built or not model.complete
    local ids, all = wantIds, wantAll
    wantFull, wantAll, wantIds = nil, nil, {}
    if full and NS.SharedList.Blocked(CD.LIST) == nil then return CD:Read() end
    local set, changes = nil, nil
    if not all and next(ids) then
        set, changes = {}, {}
        for key, change in pairs(ids) do
            set[key] = true
            if change ~= true then changes[key] = change end
        end
    end
    return CD:Refresh(set, changes)
end

--- One read CD.DEBOUNCE from now (a burst reads once). `full` asks for the full read; `id` (a currency's id)
--- with `change` (its quantityChange) narrows a by-id read to the currencies named; neither reads them all.
function CD:Request(full, id, change)
    if full then wantFull = true end
    if id ~= nil then
        local key = tostring(id)
        local prior = tonumber(wantIds[key]) or 0
        wantIds[key] = tonumber(change) and (prior + tonumber(change)) or (wantIds[key] or true)
    elseif not full then
        wantAll = true
    end
    if pendingTimer() then return end
    timer = NS.addon:ScheduleTimer(flush, CD.DEBOUNCE)
end

local HANDLERS = {
    -- currencyType nil: the client's bulk refresh; an id: that one currency. A header toggle of the read's own
    -- makes the client send this: the latch says so (SharedList.Busy).
    CURRENCY_DISPLAY_UPDATE = function(_, currencyType, _, quantityChange)
        if NS.SharedList.Busy(CD.LIST.name) then return end
        CD:Request(false, currencyType, quantityChange)
    end,
    PLAYER_ENTERING_WORLD = function() CD:Request(true) end,
    ACCOUNT_CHARACTER_CURRENCY_DATA_RECEIVED = function() CD:Request(true) end,
    PLAYER_REGEN_ENABLED = function() if model.built and not model.complete then CD:Request(true) end end,
}

--- Deliver one game event to its handler (the suites, the simulator). Answers how many ran.
function CD.OnEvent(event, ...)
    if NS.IsStoodDown() then return 0 end
    local fn = HANDLERS[event]
    if not fn then return 0 end
    fn(event, ...)
    return 1
end

CD.events = NS.NewBusTarget()
if CD.events then
    NS.SafeRegisterEvents(CD.events, CD.EVENTS, function(event, ...) CD.OnEvent(event, ...) end, NS.rejectedEvents)
end

-- ---------------------------------------------------------------------------------------------
-- The row kind: what a currency row draws and says (modules/Tree.lua's kind spec)
-- ---------------------------------------------------------------------------------------------

--- "1,200 / 75,000" for a capped currency, "12" for one without a cap; "" for a header.
function CD.ValueText(e)
    if e.header then return "" end
    if e.hasBar then return ("%s / %s"):format(NS.Tree.Number(e.quantity), NS.Tree.Number(e.maxQuantity)) end
    return NS.Tree.Number(e.quantity)
end

--- The bar's values for a capped currency (quantity of maxQuantity), or nil for a plain value row.
function CD.BarValues(e)
    if not e.hasBar then return nil end
    return { value = math.min(e.quantity or 0, e.maxQuantity), max = e.maxQuantity, text = CD.ValueText(e),
             color = NS.BarStyle.Swatch("barColor", "sm.barFill", "useClassColorBar") }
end

-- The amount, and a capped currency's cap (in the warning tone at the cap) with its bar.
local function amountLines(out, e)
    out[#out + 1] = { left = L["Amount"], right = NS.Tree.Number(e.quantity), tone = "muted", rightTone = "body" }
    if not e.hasBar then return end
    out[#out + 1] = { left = L["Cap"], right = NS.Tree.Number(e.maxQuantity), tone = "muted",
                      rightTone = e.quantity >= e.maxQuantity and "warn" or "body" }
    out[#out + 1] = { bar = true }
end

local function lines(e)
    local out = { { left = e.name, tone = "heading" } }
    if e.header then return out end
    amountLines(out, e)
    if e.weekly then
        out[#out + 1] = { left = L["This week"], right = ("%s / %s"):format(NS.Tree.Number(e.earnedThisWeek),
            NS.Tree.Number(e.maxWeekly)), tone = "muted", rightTone = "body" }
    end
    if type(e.description) == "string" and e.description ~= "" then
        out[#out + 1] = { left = e.description, tone = "muted" }
    end
    local log = NS.SessionLog
    local g = log and log.KindGainsFor and log:KindGainsFor(CD.KIND, e.key) or 0
    if g ~= 0 then
        out[#out + 1] = { left = L["This session"], right = (g > 0 and "+" or "") .. NS.Tree.Number(g),
                          tone = "muted", rightTone = g > 0 and "good" or "bad" }
    end
    return out
end

NS.Tree.RegisterKind(CD.KIND, {
    family = CD.FAMILY,
    values = CD.BarValues,
    valueText = CD.ValueText,
    lines = lines,
    pinText = function(e) return ("%s %s"):format(e.name, CD.ValueText(e)) end,
    linkText = function(e) return ("[%s: %s]"):format(e.name, CD.ValueText(e)) end,
    icon = function(e) return (not e.header) and e.icon or nil end,
    -- Every currency pins, a capped one or not (SMW-09); a header has no amount of its own.
    pinnable = function(e) return not e.header end,
})
