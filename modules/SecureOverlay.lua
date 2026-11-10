local _, NS = ...
-- modules/SecureOverlay.lua — the crafting rows' secure buttons (design §6.5, §11, plan Task 3.3,
-- Review Focus 3) and the addon's combat queue (events-frames-taint-§2).
--
-- One SecureActionButtonTemplate per profession that opens a window by a cast (catalog
-- `openSpell`: the crafts, Cooking, First Aid, Smelting for Mining), `type1 = "spell"`, `spell =`
-- the localized spell name, made the first time its row shows OUT of combat. Each is parented to
-- UIParent and laid over its row at ABSOLUTE coordinates, never anchored to it: a row is a plain
-- pooled frame the window and the detached frames re-lay at will, and a frame a secure button is
-- anchored to (or parents) becomes restricted in combat (frame-layering-§4). So:
--   * Sync() lays every overlay over its row, out of combat only; in combat it marks itself dirty.
--   * PLAYER_REGEN_DISABLED (lockdown not yet on, events-frames-taint-§2) disarms every overlay:
--     nothing invisible stays mouse-live, and a crafting click in combat reaches the plain row,
--     which says why it cannot open (design §6.5: disabled in combat).
--   * PLAYER_REGEN_ENABLED runs the queued work (AfterCombat), then re-syncs.
-- A shift-click and a right-click pass through to the row's own handlers (PostClick); only a
-- plain left click is secure.
--
-- An overlay's level is its host's plus LEVEL.SECURE, read at each Sync. A toplevel window that a
-- click raises, a Raise() and a show move the host's level, so Follow(host) re-syncs on each
-- (OnMouseDown, Raise, OnShow; a row's mouse-down calls OnRaise too), out of combat, and once more
-- on the next frame in case the raise lands after the script. While a host is dragged its overlays
-- come down (SetMoving), so none trails the window, and they are laid again at the drop.
--
-- NS.SecureOverlay:Sync() / :AfterCombat(key, fn) -> ran / :Pending() / :StandDown() / .Overlay(key)
-- NS.SecureOverlay:Follow(host) / :OnRaise() / :SetMoving(host, moving)

NS.SecureOverlay = {}
local SO = NS.SecureOverlay
local L = NS.L
local LAYERS = NS.Constants.LAYERS

local overlays = {}   -- [skill key] = button, made once, never destroyed (frames are not)
local queue, order = {}, {}
local dirty = false
local moving = {}     -- [host frame] = true while it is being dragged
local raisePending = false

function SO.Overlay(key) return overlays[key] end

--- True while work waits for the end of combat.
function SO:Pending() return dirty or #order > 0 end

--- Run `fn` now, or queue it (one entry per `key`, the latest wins) for PLAYER_REGEN_ENABLED.
--- Answers whether it ran.
function SO:AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return true
    end
    if not queue[key] then order[#order + 1] = key end
    queue[key] = fn
    NS.Debug("Combat", "queued %s until combat ends", key)
    return false
end

--- The open spell of a row that gets an overlay: a learned profession whose window opens by a cast.
--- The name its spell ID resolves to on this client (localization-§4), else the locale key's.
local function spellFor(row)
    local e = row.kind == "skill" and row.entry
    if not (e and e.learned ~= false) then return nil end
    local cat = NS.SkillCatalog[e.key]
    if not (cat and cat.openSpell) then return nil end
    local name = cat.openSpellID and NS.Compat.SpellName(cat.openSpellID)
    return name or L[cat.openSpell]
end
SO.SpellFor = spellFor   -- the suites read it

local function postClick(self, button, down)
    if down or not self.row then return end
    if button == "RightButton" or (type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) then
        NS.Interact.OnRowClick(self.row, button)
    end
end

local function hover(script)
    return function(self)
        local row = self.row
        local fn = row and row:GetScript(script)
        if fn then fn(row) end
    end
end

--- Make the overlay for `key` (out of combat only: the caller checked).
local function make(key, spell)
    local b = CreateFrame("Button", "SkillMasterCraft_" .. key, UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata(LAYERS.STRATA.WINDOW)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("type1", "spell")
    b:SetAttribute("spell", spell)
    b:SetScript("PostClick", postClick)
    b:HookScript("OnEnter", hover("OnEnter"))
    b:HookScript("OnLeave", hover("OnLeave"))
    b:Hide()
    b.key = key
    overlays[key] = b
    return b
end

local function num(...)
    for i = 1, select("#", ...) do
        if type((select(i, ...))) ~= "number" then return false end
    end
    return true
end

--- Lay `b` over `row` at the row's absolute rect, inside `clip` (the scrolled body) when given.
--- A row scrolled out of view answers false. Headless frames answer no geometry: true, unplaced.
local function place(b, row, clip)
    local l, t, w, h, s = row:GetLeft(), row:GetTop(), row:GetWidth(), row:GetHeight(), row:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()
    if not num(l, t, w, h, s, us) then return true end
    if clip then
        local ct, cb = clip:GetTop(), clip:GetBottom()
        if num(ct, cb) and (t > ct + 0.5 or t - h < cb - 0.5) then return false end
    end
    local k = s / us
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * k, t * k)
    b:SetSize(w * k, h * k)
    return true
end

--- Every shown row that wants an overlay, with its host frame and clip: [key] = { row, host, clip }.
local function wanted()
    local out = {}
    local function scan(rows, host, clip)
        for _, row in ipairs(rows) do
            local spell = spellFor(row)
            if spell then out[row.entry.key] = { row = row, host = host, clip = clip, spell = spell } end
        end
    end
    local W = NS.MainWindow
    if W and W.IsShown() and not moving[W.Frame()] then scan(W.Rows(), W.Frame(), W.Frame().scroll) end
    local D = NS.Detached
    for _, id in ipairs(D and NS.BLOCKS or {}) do
        local f = D.Frame(id)
        if f and f:IsShown() and not moving[f] then scan(D.Rows(id), f, nil) end
    end
    return out
end

local function arm(b, want)
    b.row = want.row
    b:SetFrameStrata(want.host:GetFrameStrata())
    b:SetFrameLevel(want.host:GetFrameLevel() + LAYERS.LEVEL.SECURE)
    b:SetShown(place(b, want.row, want.clip))
end

local function disarm(b)
    b.row = nil
    b:Hide()
end

--- Lay every overlay over its row, make the missing ones, hide the rest. In combat it changes
--- nothing and runs again on PLAYER_REGEN_ENABLED. Answers whether it ran.
function SO:Sync()
    if InCombatLockdown() then
        dirty = true
        return false
    end
    dirty = false
    local want = (NS.IsStoodDown and NS.IsStoodDown()) and {} or wanted()
    for key, w in pairs(want) do arm(overlays[key] or make(key, w.spell), w) end
    for key, b in pairs(overlays) do
        if not want[key] then disarm(b) end
    end
    return true
end

--- A host is being dragged (true) or was dropped (false): its overlays come down for the drag and
--- are laid over the rows' new places at the drop. In combat Sync waits, as ever.
function SO:SetMoving(host, isMoving)
    moving[host] = isMoving and true or nil
    return SO:Sync()
end

local function afterRaise()
    raisePending = false
    SO:Sync()
end

--- A host was (or may have been) raised: re-level its overlays now and once more next frame.
function SO:OnRaise()
    SO:Sync()
    if raisePending or not (NS.addon and NS.addon.ScheduleTimer) then return end
    raisePending = true
    NS.addon:ScheduleTimer(afterRaise, 0)
end

--- Keep the overlays above `host`'s rows whenever it is raised or shown.
function SO:Follow(host)
    local function raised() SO:OnRaise() end
    host:HookScript("OnMouseDown", raised)
    host:HookScript("OnShow", raised)
    -- The host is the addon's own plain frame, so its Raise is wrapped in place (no secure hook).
    local raise = host.Raise
    if type(raise) == "function" then
        host.Raise = function(frame, ...)
            local r = raise(frame, ...)
            raised()
            return r
        end
    end
end

--- Stand-down: every overlay disarmed (out of combat; in combat they were disarmed at its start).
function SO:StandDown()
    queue, order, dirty = {}, {}, false
    moving = {}
    if InCombatLockdown() then return end
    for _, b in pairs(overlays) do disarm(b) end
end

local function onCombatStart()
    -- InCombatLockdown() is still false here: the last moment a secure frame may be hidden.
    for _, b in pairs(overlays) do disarm(b) end
    dirty = true
end

local function onCombatEnd()
    local keys, fns = order, queue
    queue, order = {}, {}
    for _, key in ipairs(keys) do fns[key]() end
    SO:Sync()
end

-- A tracked bus target: stood down with the addon and replayed on stand-up (LibKa0s-Bus-1.0).
SO.events = NS.NewBusTarget()
if SO.events then
    NS.SafeRegisterEvent(SO.events, "PLAYER_REGEN_DISABLED", onCombatStart, NS.rejectedEvents)
    NS.SafeRegisterEvent(SO.events, "PLAYER_REGEN_ENABLED", onCombatEnd, NS.rejectedEvents)
end
