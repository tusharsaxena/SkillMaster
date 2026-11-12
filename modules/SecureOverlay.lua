local _, NS = ...
-- modules/SecureOverlay.lua — the action marks' secure buttons (design §6.5, §11, plan Task 3.3,
-- Review Focus 3) and the addon's combat queue (events-frames-taint-§2).
--
-- Two kinds, each laid over the hovered row's ACTION MARK alone (owner feedback round 4: a row's
-- own click opens nothing, the mark is the action):
--   * "spell": one SecureActionButtonTemplate per profession that opens a window by a cast (catalog
--     `openSpell`: the crafts, Cooking, First Aid, Smelting for Mining), `type1 = "spell"`, `spell =`
--     the localized spell name.
--   * "char": the character panel, for a stat row (the paper doll) and a weapon, Defense, Riding or
--     gathering row (the Skills tab, its line selected). On WoW Forever an addon that shows
--     CharacterFrame itself taints its OnShow, whose PlayerFrame status-bar text then compares
--     secret health values and raises (owner's error, 2026-11-12). So the button clicks the micro
--     menu's CharacterMicroButton through a secure macro ("/click CharacterMicroButton"), whose own
--     OnClick shows the panel untainted; PreClick (out of combat: an overlay is never armed in
--     combat) writes the macro for the panel's state, and PostClick switches to the Skills tab on the
--     panel already shown. With no CharacterMicroButton (a replaced micro menu) there is no "char"
--     overlay and the mark's plain click opens the panel the old way.
-- Each is made the first time its row is hovered OUT of combat, and parented to
-- UIParent and laid over its row's mark at ABSOLUTE coordinates, never anchored to it: a row is a plain
-- pooled frame the window and the detached frames re-lay at will, and a frame a secure button is
-- anchored to (or parents) becomes restricted in combat (frame-layering-§4). So:
--   * Sync() lays every overlay over its row's mark, out of combat only; in combat it marks itself dirty.
--   * PLAYER_REGEN_DISABLED (lockdown not yet on, events-frames-taint-§2) disarms every overlay:
--     nothing invisible stays mouse-live, and a crafting click in combat reaches the plain row,
--     which says why it cannot open (design §6.5: disabled in combat).
--   * PLAYER_REGEN_ENABLED runs the queued work (AfterCombat), then re-syncs.
-- A shift-click and a right-click pass through to the row's own handlers (PostClick); only a
-- plain left click is secure.
--
-- An overlay sits ONE STRATA ABOVE its host (LAYERS.STRATA_ABOVE), a documented deviation from
-- frame-layering-§1 (docs/ARCHITECTURE.md, Documented deviations). The hosts are toplevel windows,
-- and the client orders a raised toplevel window with everything in it as one group: an overlay in
-- the host's own strata lost the hit test to the row under it at any frame level (feedback round 2:
-- GetMouseFoci named the row alone, the overlay shown, placed and three levels higher). A strata up,
-- an invisible mouse-live frame could cover another window that overlaps the row, so only the
-- HOVERED crafting row is armed: Hover(row) from the row's OnEnter, Unhover(row) once the pointer
-- has left both the row and its overlay. A window over the row takes the pointer first, so the row
-- under it is never hovered and nothing is armed there.
--
-- Its level is its host's plus LEVEL.SECURE, read at each Sync. A toplevel window that a click
-- raises, a Raise() and a show move the host's level, so Follow(host) re-syncs on each
-- (OnMouseDown, Raise, OnShow; a row's mouse-down calls OnRaise too), out of combat, and once more
-- on the next frame in case the raise lands after the script. While a host is dragged its overlays
-- come down (SetMoving), so none trails the window, and they are laid again at the drop.
--
-- NS.SecureOverlay:Sync() / :AfterCombat(key, fn) -> ran / :Pending() / :StandDown() / .Overlay(key)
-- NS.SecureOverlay:Follow(host) / :OnRaise() / :SetMoving(host, moving) / :Hover(row) / :Unhover(row)
-- NS.SecureOverlay.KindFor(row) -> "spell"|"char"|nil, .KeyFor(row), .CharMacro(target, key)

NS.SecureOverlay = {}
local SO = NS.SecureOverlay
local L = NS.L
local LAYERS = NS.Constants.LAYERS

local overlays = {}   -- [skill key] = button, made once, never destroyed (frames are not)
local queue, order = {}, {}
local dirty = false
local moving = {}     -- [host frame] = true while it is being dragged
local raisePending = false
local hovered         -- the crafting row under the pointer: the one row armed (see the header)

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

-- The micro menu's character button, the secure way into the panel (see the header), or nil.
local function microButton()
    local b = CharacterMicroButton
    return type(b) == "table" and b.Click and b or nil
end

--- The character-panel target of `row` ("skills" or "paperdoll"), or nil (NS.Interact.Target).
local function charTarget(row)
    local t = row and row.entry and NS.Interact and NS.Interact.Target(row)
    if t == "skills" or t == "paperdoll" then return t end
    return nil
end
SO.CharTarget = charTarget

--- The overlay kind `row`'s mark takes: "spell" (a crafting cast), "char" (the character panel, with
--- the micro button present), or nil (the mark's own click does it).
function SO.KindFor(row)
    if spellFor(row) then return "spell" end
    if charTarget(row) and microButton() then return "char" end
    return nil
end

--- The overlay's key for `row`: the skill's key, or "stat:<key>" for a stat row.
function SO.KeyFor(row)
    local e = row and row.entry
    if not e then return nil end
    return row.kind == "stat" and ("stat:" .. tostring(e.key)) or e.key
end

local function shown(f)
    return type(f) == "table" and f.IsShown and f:IsShown() == true
end

--- The macro a "char" overlay runs for `target` in the panel's current state: one click opens the
--- paper doll (the micro button's own tab), two reopen it there from another tab, one closes it when
--- it already shows the paper doll. The Skills tab opens by one click when the panel is closed (then
--- PostClick switches tabs), else by no click at all (PostClick alone).
--- @return string macrotext ("" for none), boolean switch (PostClick shows the Skills tab)
function SO.CharMacro(target)
    local CLICK = "/click CharacterMicroButton"
    local open = shown(CharacterFrame)
    if target == "paperdoll" then
        if not open or shown(PaperDollFrame) then return CLICK, false end
        return CLICK .. "\n" .. CLICK, false
    end
    if not open then return CLICK, true end
    return "", true
end

local function isShift() return type(IsShiftKeyDown) == "function" and IsShiftKeyDown() end

--- A "char" overlay's PreClick, on the press (insecure, out of combat): select the Skills tab's line
--- first (the tab keeps a selection it finds), then write the macro for the panel's state.
local function charPreClick(self, button, down)
    if not down then return end
    local row = self.row
    local target = row and charTarget(row)
    if button ~= "LeftButton" or isShift() or not target then
        self:SetAttribute("type1", nil)
        self.switch = nil
        return
    end
    if target == "skills" then NS.Interact.SelectSkillLine(row.entry.key) end
    local macro, switch = SO.CharMacro(target)
    self:SetAttribute("type1", macro ~= "" and "macro" or nil)
    self:SetAttribute("macrotext1", macro)
    self.switch = switch
    NS.Debug("Click", "panel overlay %s: %s, macro %q, Skills tab after: %s", tostring(self.key), target,
        macro, tostring(switch))
end

local function postClick(self, button, down)
    NS.Debug("Click", "overlay %s PostClick %s down=%s", tostring(self.key), tostring(button), tostring(down))
    if self.kind == "char" and down then return end
    if self.kind ~= "char" and (down or not self.row) then return end
    if self.kind == "char" then
        -- The release: the panel is open now (the macro ran on the press); the Skills tab last.
        if button == "LeftButton" and not isShift() and self.switch and self.row then
            NS.Interact.ShowSkillsTab(self.row.entry.key)
        end
        self.switch = nil
        if not self.row then return end
    end
    if button == "LeftButton" and self.kind == "spell" then NS.Debug("Click", "crafting overlay %s cast %s", tostring(self.key), tostring(self:GetAttribute("spell"))) end
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

--- Make the overlay for `key` of kind `want.kind` (out of combat only: the caller checked).
local function make(key, want)
    local name = (want.kind == "char" and "SkillMasterPanel_" or "SkillMasterCraft_") .. tostring(key):gsub("%W", "_")
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata(LAYERS.STRATA.WINDOW)
    b:RegisterForClicks("AnyUp", "AnyDown")
    b.kind = want.kind
    if want.kind == "spell" then
        b:SetAttribute("type1", "spell")
        b:SetAttribute("spell", want.spell)
    else
        -- The macro is written on each press (charPreClick); the secure action runs on the press too,
        -- so the panel opens before PostClick's tab switch on the release.
        b:SetAttribute("type1", nil)
        b:SetScript("PreClick", charPreClick)
    end
    b:SetScript("PostClick", postClick)
    b:HookScript("OnEnter", hover("OnEnter"))
    b:HookScript("OnLeave", hover("OnLeave"))
    b:HookScript("OnMouseDown", function(self, button)
        NS.Debug("Click", "overlay %s mouse-down %s", tostring(self.key), tostring(button))
    end)
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

--- Every shown row that wants an overlay, with its host frame and clip: [key] = { row, host, clip,
--- kind, spell }. Only the hovered row (see the header).
local function wanted()
    local out = {}
    local function scan(rows, host, clip)
        for _, row in ipairs(rows) do
            local kind = row == hovered and SO.KindFor(row)
            if kind then
                out[SO.KeyFor(row)] = { row = row, host = host, clip = clip, kind = kind, spell = spellFor(row) }
            end
        end
    end
    local W = NS.MainWindow
    if W and W.IsShown() and not moving[W.Frame()] then scan(W.Rows(), W.Frame(), W.Frame().scroll) end
    local D = NS.Detached
    for _, id in ipairs(D and NS.BLOCKS or {}) do
        local f = D.Frame(id)
        if f and f:IsShown() and not moving[f] then scan(D.Rows(id), f, nil) end
    end
    -- The merged windows (round 5, R5-6): their sections' rows.
    local G = NS.Groups
    for _, gid in ipairs(G and G.Shown() or {}) do
        local f = G.Frame(gid)
        if not moving[f] then scan(G.Rows(gid), f, nil) end
    end
    return out
end

--- One strata above the host's (the documented frame-layering-§1 deviation, see the header): the
--- host is a toplevel window, whose raised group outranks any level in its own strata.
local function strataOver(host)
    local s = host:GetFrameStrata()
    return LAYERS.STRATA_ABOVE[s] or s
end
SO.StrataOver = strataOver   -- the suites read it

local function arm(b, want)
    b.row = want.row
    b:SetFrameStrata(strataOver(want.host))
    b:SetFrameLevel(want.host:GetFrameLevel() + LAYERS.LEVEL.SECURE)
    -- Over the row's action mark alone (owner feedback round 4); the row itself when it has none.
    b:SetShown(place(b, want.row.act or want.row, want.clip))
end

local function disarm(b)
    b.row = nil
    b:Hide()
end

-- `f:method()` as text, or "n/a" where this client has no such method (the click debug).
local function call(f, method)
    local fn = f[method]
    if type(fn) ~= "function" then return "n/a" end
    local ok, v = pcall(fn, f)
    return ok and tostring(v) or "err"
end

local function rect(f)
    local l, t, w, h = f:GetLeft(), f:GetTop(), f:GetWidth(), f:GetHeight()
    if not num(l, t, w, h) then return "none" end
    return ("%.0f,%.0f %.0fx%.0f"):format(l, t, w, h)
end

--- One line on `key`'s overlay against `row` (the click debug, /sm debug): whether it exists, is
--- shown, sits over the row and above it. A click that reaches the plain row logs this.
function SO.Describe(key, row)
    local b = overlays[key]
    if not b then return ("overlay %s: none made (spell=%s)"):format(tostring(key), tostring(row and spellFor(row))) end
    local parts = {
        ("overlay %s: shown=%s visible=%s armedFor=%s"):format(tostring(key), tostring(b:IsShown()),
            tostring(b:IsVisible()), tostring(b.row == row)),
        ("level=%s/%s row=%s/%s"):format(tostring(b:GetFrameStrata()), tostring(b:GetFrameLevel()),
            row and tostring(row:GetFrameStrata()) or "-", row and tostring(row:GetFrameLevel()) or "-"),
        ("rect=%s rowRect=%s points=%s"):format(rect(b), row and rect(row) or "-", tostring(b:GetNumPoints())),
        ("mouseOver=%s mouse=%s spell=%s"):format(tostring(b:IsMouseOver()), tostring(b:IsMouseEnabled()),
            tostring(b:GetAttribute("spell"))),
        ("clicks=%s motion=%s propagate=%s protected=%s enabled=%s scale=%s/%s"):format(
            call(b, "IsMouseClickEnabled"), call(b, "IsMouseMotionEnabled"), call(b, "GetPropagateMouseClicks"),
            call(b, "IsProtected"), call(b, "IsEnabled"), call(b, "GetEffectiveScale"),
            row and call(row, "GetEffectiveScale") or "-"),
    }
    return table.concat(parts, " ")
end

--- The frames the client has under the pointer now, topmost first (GetMouseFoci), each as
--- name-or-type@strata/level: the frame that takes a click is the first.
function SO.MouseFoci()
    if type(GetMouseFoci) ~= "function" then return "GetMouseFoci absent" end
    local foci = GetMouseFoci()
    if type(foci) ~= "table" then return tostring(foci) end
    if foci.GetObjectType then foci = { foci } end
    local out = {}
    for i, f in ipairs(foci) do
        local name = f.GetName and f:GetName() or nil
        local tag = name or (f.GetObjectType and f:GetObjectType() or "?")
        for key, b in pairs(overlays) do if b == f then tag = "overlay:" .. key end end
        if f.entry then tag = tag .. "(row " .. tostring(f.entry.key) .. ")" end
        local parent = f.GetParent and f:GetParent()
        local pname = parent and parent.GetName and parent:GetName() or (parent and "anon" or "nil")
        out[i] = ("%s@%s/%s<%s"):format(tag, call(f, "GetFrameStrata"), call(f, "GetFrameLevel"), tostring(pname))
    end
    return #out > 0 and table.concat(out, " ") or "none"
end

--- Lay every overlay over its row's mark, make the missing ones, hide the rest. In combat it changes
--- nothing and runs again on PLAYER_REGEN_ENABLED. Answers whether it ran.
function SO:Sync()
    if InCombatLockdown() then
        dirty = true
        return false
    end
    dirty = false
    local want = (NS.IsStoodDown and NS.IsStoodDown()) and {} or wanted()
    for key, w in pairs(want) do arm(overlays[key] or make(key, w), w) end
    for key, b in pairs(overlays) do
        if not want[key] then disarm(b) end
    end
    return true
end

--- The pointer is on crafting row `row`: arm its overlay (out of combat; Sync waits in combat).
function SO:Hover(row)
    hovered = row
    return SO:Sync()
end

--- The pointer left `row` (and its overlay): disarm it, unless another row is hovered by now.
function SO:Unhover(row)
    if hovered ~= row then return false end
    hovered = nil
    return SO:Sync()
end

--- Whether `row`'s armed overlay is under the pointer: its own appearing takes the pointer off the
--- row, which must not count as leaving it.
function SO.UnderPointer(row)
    local key = SO.KeyFor(row)
    local b = key and overlays[key]
    return b ~= nil and b.row == row and b:IsShown() and b:IsMouseOver() == true
end

--- `row` is parked (released to its pool): it is hovered no more, so a pooled row re-used for
--- another crafting skill is never armed without a hover of its own. No sync: the layout that
--- released it syncs after.
function SO.Forget(row)
    if hovered == row then hovered = nil end
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
    moving, hovered = {}, nil
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
