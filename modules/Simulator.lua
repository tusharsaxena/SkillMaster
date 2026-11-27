local addonName, NS = ...
-- modules/Simulator.lua — the in-game simulator (preview-mode, plan Task 5.2) on LibKa0s-Sim-1.0: one
-- scripted session that plays test mode's sample character (defaults/Preview_Forever.lua) through
-- the addon's real engine. Every 3 s a step changes the simulated world and fires the events the
-- client would: skill-ups (CHAT_MSG_SKILL, so SkillData scans and sends SKILL_UP: the broker flashes,
-- the session log records it, the alerts check it), a fishing lure on and off (the bonus segment and
-- its timer) and a mount's speed change (the Speed stats). The tree families too (SMW-11): the sample's
-- reputations, currencies and Statistics tab are the world's, read through the seam as the live client is read,
-- and a step raises a reputation (UPDATE_FACTION) and a currency (CURRENCY_DISPLAY_UPDATE).
--
-- The world answers through the seam (core/SimSetup.lua): the skill list, the player's level, class
-- and race, the weapon enchant, the main hand's tooltip and the speed, each an NS.Compat member.
-- Nothing a simulation does is saved (H4): the session log writes into the session's own list
-- (NS.SessionLog:Override), alt snapshots stand aside while a session runs, and the stop puts the
-- skills model, the alerts' and the broker's session state back as they were.
--
-- Three surfaces, one handler (preview-mode, options-ui-§15, launcher-§2): `/cl sim …`, the
-- launcher's Sim mode entry and the Master-controls Sim mode checkbox, the last two through
-- NS.IsSimMode / NS.ToggleSim. NS.Sim is the library instance (or the reference stub); this file's
-- own fields are on NS.SimHost (C.4).

NS.SimHost = {}
local H = NS.SimHost
local L = NS.L

local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)

H.SCENARIO   = "fishingTrip"
H.STEP_DELAY = 3       -- seconds between steps (a host constant, never a setting: C.11)
H.LURE_SECONDS = 600   -- the lure the "lure on" step applies
H.MOUNT_YARDS = 11.2   -- 160% of the 7 yards/s run speed
H.RUN_YARDS, H.SWIM_YARDS = 7, 4.69
H.MAIN_HAND = 16
H.REP_STEP = { faction = 72, amount = 250 }        -- Stormwind, the sample's pinned faction
H.CURRENCY_STEP = { currency = 1901, amount = 150 } -- Honor Points, the sample's pinned currency

-- ── the simulated world ───────────────────────────────────────────────────────────────────────

local function session() return NS.Sim and NS.Sim:Session() or nil end
local function world() local s = session() return s and s.world or nil end

--- The world a session starts from: the sample character, lure off, on foot.
function H.NewWorld()
    local c = NS.Preview.SampleCharacter()
    local w = { lines = NS.Preview.SkillLines(), level = c.level, classFile = c.classFile, name = c.name,
                className = L[c.class], raceFile = c.raceFile, raceName = L[c.race],
                lure = nil, run = H.RUN_YARDS, swim = H.SWIM_YARDS,
                factions = NS.Preview.FactionRows(), currencies = NS.Preview.CurrencyRows(),
                statistics = NS.Preview.StatisticsList() }
    H.SetModifier(w, "fishing", 0)   -- the fixture's lure is the step's to put on
    return w
end

local function lineOf(w, key)
    local cat = NS.SkillCatalog[key]
    local name = cat and L[cat.name]
    for _, r in ipairs(w.lines) do
        if not r.isHeader and r.name == name then return r end
    end
    return nil
end

function H.SetModifier(w, key, amount)
    local r = lineOf(w, key)
    if r then r.modifier = amount end
end

local function copy(r)
    local out = {}
    for k, v in pairs(r) do out[k] = v end
    return out
end

local function byField(list, field, value)
    for _, r in ipairs(list or {}) do
        if r[field] == value then return r end
    end
    return nil
end

local function category(w, id) return byField(w.statistics, "id", id) end

-- The tree families' reads (SMW-11): the world's faction and currency lists (every header open, so the full
-- read toggles nothing; the toggles are guarded anyway) and its Statistics tab, in Forever's shapes.
local TREE_PROVIDERS = {
    NumFactions = function(w) return #w.factions end,
    FactionDataByIndex = function(w, i) local r = w.factions[i] return r and copy(r) or nil end,
    FactionDataByID = function(w, id) local r = byField(w.factions, "factionID", tonumber(id)) return r and copy(r) or nil end,
    NumCurrencies = function(w) return #w.currencies end,
    CurrencyListInfo = function(w, i) local r = w.currencies[i] return r and copy(r) or nil end,
    CurrencyInfo = function(w, id) local r = byField(w.currencies, "currencyID", tonumber(id)) return r and copy(r) or nil end,
    StatisticsCategories = function(w)
        local out = {}
        for i, c in ipairs(w.statistics) do out[i] = c.id end
        return out
    end,
    StatisticsCategoryInfo = function(w, id)
        local c = category(w, id)
        if c then return c.name, c.parent end
        return nil
    end,
    NumStatistics = function(w, id) local c = category(w, id) return c and #c.rows or 0 end,
    Statistic = function(w, id, i)
        local c = category(w, id)
        local r = c and c.rows[i]
        if r then return r.quantity, false, r.statID end
        return nil
    end,
    StatisticName = function(w, statID)
        for _, c in ipairs(w.statistics) do
            local r = byField(c.rows, "statID", statID)
            if r then return r.name end
        end
        return nil
    end,
}

-- The providers: each answers from the world while a session has one, else the live fallback.
local PROVIDERS = {
    NumSkillLines = function(fallback)
        local w = world()
        if not w then return fallback() end
        return #w.lines
    end,
    SkillLineInfo = function(fallback, i)
        local w = world()
        if not w then return fallback(i) end
        local r = w.lines[i]
        return r and copy(r) or nil
    end,
    PlayerLevel = function(fallback)
        local w = world()
        if not w then return fallback() end
        return w.level
    end,
    PlayerName = function(fallback)
        local w = world()
        if not w then return fallback() end
        return w.name
    end,
    PlayerClass = function(fallback)
        local w = world()
        if not w then return fallback() end
        return w.className, w.classFile
    end,
    PlayerRace = function(fallback)
        local w = world()
        if not w then return fallback() end
        return w.raceName, w.raceFile
    end,
    WeaponEnchantInfo = function(fallback)
        local w = world()
        if not w then return fallback() end
        if not w.lure then return false end
        return true, math.max(0, (w.lure - GetTime()) * 1000), 0
    end,
    InventoryTooltipData = function(fallback, slot)
        local w = world()
        if not w then return fallback(slot) end
        if slot ~= H.MAIN_HAND then return { lines = {} }, true end
        local lines = { { leftText = L["Strong Fishing Pole"] } }
        if w.lure then lines[2] = { leftText = L["Shiny Bauble (+25 Fishing Skill)"] } end
        return { lines = lines }, true
    end,
    UnitSpeed = function(fallback, unit)
        local w = world()
        if not w then return fallback(unit) end
        return 0, w.run, w.run, w.swim
    end,
}

for key, fn in pairs(TREE_PROVIDERS) do
    PROVIDERS[key] = function(fallback, ...)
        local w = world()
        if not w then return fallback(...) end
        return fn(w, ...)
    end
end

-- ── delivery: the handlers the client's registrations would call (H3) ─────────────────────────

local function skillEvent(event, ...) return NS.SkillData.OnEvent(event, ...) end
local function bonusEvent(event, unit) NS.addon:OnBonusesUnitChanged(event, unit) return 1 end

H.HANDLERS = {
    CHAT_MSG_SKILL         = { skillEvent },
    SKILL_LINES_CHANGED    = { skillEvent },
    UNIT_INVENTORY_CHANGED = { bonusEvent },
    UNIT_AURA              = { bonusEvent },
    -- The speed ticker's read (modules/StatData.lua, WatchSpeed): the client fires no event for it.
    ["hook:speedTick"]     = { function() NS.StatData:Request() return 1 end },
    UPDATE_FACTION         = { function(event, ...) return NS.RepData.OnEvent(event, ...) end },
    CURRENCY_DISPLAY_UPDATE = { function(event, ...) return NS.CurrencyData.OnEvent(event, ...) end },
}

local function rejected(event)
    for k, v in pairs(NS.rejectedEvents or {}) do
        if k == event or v == event then return true end
    end
    return false
end

function H.Deliver(event, ...)
    local list = H.HANDLERS[event]
    if not list or rejected(event) then return 0 end
    local ran = 0
    for _, fn in ipairs(list) do ran = ran + (fn(event, ...) or 0) end
    return ran
end

-- ── the scenario ──────────────────────────────────────────────────────────────────────────────

local function skillUp(key) return { kind = "skillUp", skill = key } end

--- The steps, in order: six skill-ups around a lure on and off and a mount up and down, then a reputation gain
--- and a currency gain (SMW-11).
function H.Timeline()
    return {
        skillUp("fishing"),
        { kind = "lure", on = true },
        skillUp("fishing"),
        skillUp("leatherworking"),
        { kind = "speed", yards = H.MOUNT_YARDS },
        skillUp("guns"),
        skillUp("bows"),
        { kind = "speed", yards = H.RUN_YARDS },
        { kind = "lure", on = false },
        skillUp("skinning"),
        { kind = "rep", faction = H.REP_STEP.faction, amount = H.REP_STEP.amount },
        { kind = "currency", currency = H.CURRENCY_STEP.currency, amount = H.CURRENCY_STEP.amount },
    }
end

local function skillName(key)
    local cat = NS.SkillCatalog[key]
    return cat and L[cat.name] or key
end

local function treeName(list, field, id)
    local r = byField(NS.Preview and list(), field, id)
    return r and r.name or tostring(id)
end

local STEP_LABEL = {
    rep = function(step)
        return L["Reputation: %s +%d"]:format(treeName(NS.Preview.FactionRows, "factionID", step.faction), step.amount)
    end,
    currency = function(step)
        return L["Currency: %s +%d"]:format(treeName(NS.Preview.CurrencyRows, "currencyID", step.currency), step.amount)
    end,
}

function H.StepLabel(step)
    if STEP_LABEL[step.kind] then return STEP_LABEL[step.kind](step) end
    if step.kind == "skillUp" then return L["Skill-up: %s"]:format(skillName(step.skill)) end
    if step.kind == "lure" then return step.on and L["Fishing lure on"] or L["Fishing lure off"] end
    if step.kind == "speed" then
        return step.yards > H.RUN_YARDS and L["Mount up: speed 160%"] or L["Dismount: speed 100%"]
    end
    return step.kind
end

local PLAY = {
    skillUp = function(step, w, sim)
        local r = lineOf(w, step.skill)
        if not r then return "absent" end
        r.rank = math.min(r.rank + 1, r.max)
        sim:Fire("CHAT_MSG_SKILL", L["Your skill in %s has increased to %d."]:format(r.name, r.rank))
        return ("%s %d"):format(r.name, r.rank)
    end,
    lure = function(step, w, sim)
        w.lure = step.on and (GetTime() + H.LURE_SECONDS) or nil
        H.SetModifier(w, "fishing", step.on and 25 or 0)
        sim:Fire("UNIT_INVENTORY_CHANGED", "player")
        sim:Fire("SKILL_LINES_CHANGED")
        return step.on and "+25" or "0"
    end,
    -- A reputation gain (SMW-11): the faction's standing moves; the client says so with UPDATE_FACTION.
    rep = function(step, w, sim)
        local r = byField(w.factions, "factionID", step.faction)
        if not r then return "absent" end
        r.currentStanding = math.min((r.currentStanding or 0) + step.amount, r.nextReactionThreshold or math.huge)
        sim:Fire("UPDATE_FACTION")
        return ("%s +%d"):format(r.name, step.amount)
    end,
    -- A currency gain (SMW-11): CURRENCY_DISPLAY_UPDATE names the currency, its amount and the change.
    currency = function(step, w, sim)
        local r = byField(w.currencies, "currencyID", step.currency)
        if not r then return "absent" end
        local max = (r.maxQuantity or 0) > 0 and r.maxQuantity or math.huge
        local before = r.quantity or 0
        r.quantity = math.min(before + step.amount, max)
        sim:Fire("CURRENCY_DISPLAY_UPDATE", r.currencyID, r.quantity, r.quantity - before)
        return ("%s +%d"):format(r.name, r.quantity - before)
    end,
    speed = function(step, w, sim)
        w.run = step.yards
        sim:Fire("UNIT_AURA", "player")
        sim:Fire("hook:speedTick")
        return ("%d%%"):format(math.floor(step.yards / H.RUN_YARDS * 100 + 0.5))
    end,
}

function H.Play(step, s)
    local fn = PLAY[step.kind]
    if not (fn and s and s.world) then return nil end
    local detail = fn(step, s.world, NS.Sim)
    NS.bus:SendMessage(NS.MSG.SIM_TICK, step.kind)
    return detail
end

-- ── start, refusal, stop ─────────────────────────────────────────────────────────────────────

--- The host's every refusal, read inside seam:Live (the real world).
function H.Refusal()
    local stood = NS.StoodDownRefusal()
    if stood then return stood end
    if NS.IsTestMode() then return L["A simulation cannot start while test mode is on."] end
    if InCombatLockdown() then return L["A simulation cannot start in combat."] end
    if type(IsInInstance) == "function" and IsInInstance() then
        return L["A simulation cannot start in an instance."]
    end
    if type(IsInGroup) == "function" and IsInGroup() then return L["A simulation cannot start in a group."] end
    return nil
end

local function repaint()
    if NS.IsStoodDown() then return end
    if NS.MainWindow then NS.MainWindow.Refresh(true) end
    if NS.Detached then NS.Detached.Refresh() end
    if NS.Journal then NS.Journal.Refresh() end
end

--- Build the world and point every store a simulated event reaches at session-only state.
function H.Prepare(s, _, _, ready)
    s.world = H.NewWorld()
    s.log = {}
    s.saved = {
        model  = NS.SkillData:Adopt(nil),   -- from an empty model: the first pass sends no SKILL_UP
        alerts = NS.Alerts.State(),
        broker = NS.Broker.SessionState(),
        gains  = NS.State.sessionGains,
        -- The tree families' live state (SMW-11): the world is read afresh, the stop puts these back.
        reps = NS.RepData:Adopt(nil), currencies = NS.CurrencyData:Adopt(nil),
        statistics = NS.StatisticsData:Adopt(nil),
    }
    NS.Alerts.Reset()                       -- the first simulated model only records the caps
    NS.SessionLog:Override(s.log, time())
    NS.Bonuses.Invalidate()
    NS.SkillData:Scan()
    NS.Bonuses.Refresh()
    NS.StatData:Request()
    NS.RepData:Read()
    NS.CurrencyData:Read()
    repaint()
    ready()
end

--- The stop, seam off: the live state back exactly as it was, then one live repaint.
function H.Restore(s, reason)
    local saved = s and s.saved
    NS.SessionLog:Override(nil)
    if not saved then return end
    NS.SkillData:Adopt(saved.model)
    NS.Alerts.RestoreState(saved.alerts)
    NS.Alerts.StandDown()                   -- a simulated toast does not outlive the session
    NS.State.sessionGains = saved.gains
    NS.Broker.RestoreSessionState(saved.broker)
    NS.Bonuses.Invalidate()
    NS.RepData:Adopt(saved.reps)
    NS.CurrencyData:Adopt(saved.currencies)
    NS.StatisticsData:Adopt(saved.statistics)
    if reason == "standDown" or NS.IsStoodDown() then return end
    NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, saved.model)
    NS.bus:SendMessage(NS.MSG.REPS_UPDATED, saved.reps)
    NS.bus:SendMessage(NS.MSG.CURRENCIES_UPDATED, saved.currencies)
    NS.bus:SendMessage(NS.MSG.STATISTICS_UPDATED, saved.statistics.model)
    NS.Bonuses.Refresh()
    NS.StatData:Request()
    repaint()
end

-- ── the instance, or the reference stub (H9) ──────────────────────────────────────────────────

local NEEDS_LINE = L["The simulator needs LibKa0s-Sim-1.0."]

local function newSimStub(say)
    local sim = {}
    local function no() return false end
    local function noop() end
    local function absent() return false, "absent" end
    sim.IsActive, sim.IsDelivering, sim.IsPanelShown = no, no, no
    function sim.Fire() return 0 end
    function sim.DeliverForCleanup() return 0 end
    function sim.After() return nil end
    function sim.Start() say(NEEDS_LINE); return false, NEEDS_LINE end
    sim.Stop = no
    sim.OnStop, sim.OnStopGuarded, sim.AddListener = noop, noop, noop
    function sim.Status() return { active = false } end
    function sim.Session() return nil end
    function sim.Steps() return {} end
    function sim.Step() return nil, "absent" end
    sim.Run, sim.Pause, sim.Resume, sim.Restart = absent, absent, absent, absent
    function sim.RunVerb() say(NEEDS_LINE); return false, "absent" end
    sim.ShowPanel, sim.TogglePanel = no, no
    sim.HidePanel, sim.RefreshPanel, sim.ResetPanelPosition = noop, noop, noop
    function sim.PanelRows() return {} end
    return sim
end
H.NewStub = newSimStub   -- the surface-parity case compares it with the live instance

local function mainFrame()
    local W = NS.MainWindow
    if W and W.IsShown() then return W.Frame() end
    return nil
end

--- The descriptor (LibKa0s-Sim-1.0, `Sim:New(d)`).
function H.Descriptor()
    return {
        name = addonName, seam = NS.SimSeam, slash = "/cl sim",
        deliver = H.Deliver,
        isStoodDown = function() return NS.IsStoodDown() end,
        scenarios = { names = { H.SCENARIO }, defs = { [H.SCENARIO] = {
            label = L["A fishing trip: skill-ups, a lure and a mount"],
            timeline = function() return H.Timeline() end,
        } } },
        prepare = H.Prepare,
        play = H.Play,
        refusal = H.Refusal,
        stepDelay = H.STEP_DELAY,
        stopText = {
            standDown = L["Simulation stopped: Character Ledger was disabled."],
            combat    = L["Simulation stopped: combat started."],
            profile   = L["Simulation stopped: the profile changed."],
        },
        L = { STARTED = L["Simulation started (%s): a sample character plays scripted events. Nothing is saved."] },
        print = function(line) NS.Print(line) end,
        debug = function(_, fmt, ...) NS.Debug("Sim", fmt, ...) end,
        panel = {
            title = L["Character Ledger - Simulation"],
            stepLabel = function(step) return H.StepLabel(step) end,
            anchorTo = mainFrame,
            check = NS.Icon("confirm"),
        },
    }
end

if Sim then
    for key, fn in pairs(PROVIDERS) do NS.SimSeam:SetProvider(key, fn) end
    NS.Sim = Sim:New(H.Descriptor())
    NS.Sim:OnStop(function(s, reason) H.Restore(s, reason) end)
else
    NS.Sim = newSimStub(function(line) NS.Print(line) end)
end

-- ── the one handler the launcher entry and the Master-controls checkbox share ─────────────────

local function refreshScalars()
    if NS.Helpers and NS.Helpers.RefreshScalars then NS.Helpers.RefreshScalars() end
end

-- The checkbox and the launcher entry follow every show and hide of the step panel too, which no
-- session transition reports (options-ui-§15): hook the panel's frame once it exists.
local function hookPanel()
    local f = _G[addonName .. "SimPanel"]
    if H.hooked or type(f) ~= "table" or type(f.HookScript) ~= "function" then return end
    H.hooked = true
    f:HookScript("OnShow", refreshScalars)
    f:HookScript("OnHide", refreshScalars)
end

NS.Sim:AddListener(function()
    hookPanel()
    refreshScalars()
    if NS.MainWindow and not NS.IsStoodDown() then NS.MainWindow.Refresh() end
end)

--- Ticked while the step panel is shown or a session runs (options-ui-§15, v2.100.0).
function NS.IsSimMode() return NS.Sim:IsPanelShown() or NS.Sim:IsActive() end

--- Whether a session is running (the window's simulation strip reads this).
function NS.IsSimRunning() return NS.Sim:IsActive() end

--- The one toggle: on, what the bare `/cl sim` does (the status, the usage and the step panel);
--- off, stop a running session and hide the panel.
function NS.ToggleSim()
    if NS.IsSimMode() then
        if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
        NS.Sim:HidePanel()
    else
        local refusal = NS.StoodDownRefusal()
        if refusal then NS.Print(refusal) return false end
        NS.Sim:RunVerb("")
        hookPanel()
    end
    refreshScalars()
    return NS.IsSimMode()
end
