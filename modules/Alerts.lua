local addonName, NS = ...
-- modules/Alerts.lua — the rank-cap and weapon-gap alerts (design §5.2, plan Task 4.2) on
-- LibKa0s-Toast-1.0: a profession at its rank's cap with a next rank to train toasts once per cap
-- and says the trainer in chat; a weapon skill `alerts.weaponGap` or more below its cap toasts once
-- per skill per session, on SKILL_UP or a level-up. Each alert has its switch; `alerts.sound` plays
-- the toast's sound. A left-click on a cap toast sets a waypoint to the trainer (NS.Waypoints, T3.3)
-- or, without it, prints the directions.
--
-- Reads the model through NS.SkillData:Get / the SKILLS_UPDATED payload and the next rank through
-- NS.Trainers:NextRank, both at call time. The toast frames are plain (never protected), so they
-- show in combat; the mockup is Detached.dc.html's two toasts.

NS.Alerts = {}
local A = NS.Alerts
local L = NS.L

local Toast = LibStub and LibStub("LibKa0s-Toast-1.0", true)

A.WIDTH = 420
A.PAD_X, A.PAD_Y = 14, 12
A.ICON, A.ICON_SMALL = 36, 28
A.GAP = 12
A.CLOSE_CLEAR = 26   -- the toast's close mark: 18 px, 4 px in, plus a margin
A.STACK = 2          -- the mockup shows the cap and the weapon toast together
A.DEFAULT_GAP = 25

local shownCap, shownGap, lastMax = {}, {}, {}

--- Forget what this session alerted (the suites; a session otherwise never resets).
function A.Reset()
    shownCap, shownGap, lastMax = {}, {}, {}
end

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

--- What this session has alerted, as a copy (the simulator takes it at start).
function A.State() return { cap = copy(shownCap), gap = copy(shownGap), max = copy(lastMax) } end

--- Put a State() back (the simulator's stop): a simulated alert never silences a real one.
function A.RestoreState(s)
    if type(s) ~= "table" then return end
    shownCap, shownGap, lastMax = copy(s.cap or {}), copy(s.gap or {}), copy(s.max or {})
end

local function setting(key) return NS.GetSetting and NS.GetSetting("alerts." .. key) end

-- ---------------------------------------------------------------------------------------------
-- What the alerts say
-- ---------------------------------------------------------------------------------------------

--- The rank whose cap the skill sits at ("Journeyman" at 150), or nil.
local function rankNameAt(key, max)
    local ladder = NS.RankLadderFor_Forever and NS.RankLadderFor_Forever[key]
    for _, step in ipairs(ladder and NS.Ranks_Forever and NS.Ranks_Forever[ladder] or {}) do
        if step.cap == max then return step.rankName end
    end
    return nil
end

--- "Name, City (x, y)", or "Name, Subzone, City" where the table has no coordinates.
function A.Directions(trainer)
    if not trainer then return L["no trainer known"] end
    if trainer.x and trainer.y then
        return ("%s, %s (%g, %g)"):format(trainer.name, trainer.city or "", trainer.x, trainer.y)
    end
    if trainer.subzone then return ("%s, %s, %s"):format(trainer.name, trainer.subzone, trainer.city or "") end
    return ("%s, %s"):format(trainer.name, trainer.city or "")
end

local function capPayload(e, nextRank)
    local rankName = rankNameAt(e.key, e.max)
    local title = ("%s %d / %d"):format(e.name, e.rank, e.max)
    if rankName then title = L["%s · %s cap"]:format(title, rankName) end
    local trainer = nextRank.trainers and nextRank.trainers[1]
    return {
        kind = "cap", key = e.key, name = e.name, title = title, trainer = trainer,
        detail = L["Train %s (Lv %d): %s"]:format(nextRank.rankName, nextRank.minLevel, A.Directions(trainer)),
    }
end

local function gapPayload(e, cap, gap)
    return {
        kind = "weapon", key = e.key, name = e.name, gap = gap,
        title = ("%s %d / %d"):format(e.name, e.rank, cap),
        detail = L["is %d below your cap. Glancing blows and misses are more likely."]:format(gap),
    }
end

-- ---------------------------------------------------------------------------------------------
-- The two checks
-- ---------------------------------------------------------------------------------------------

local function show(payload, key)
    NS.Debug("Alerts", "%s", key)
    A.toast:Show(payload, { key = key })
end

--- A skill at its cap with a next rank to train: toast and chat, once per skill and cap.
function A.CheckCap(e)
    if not (e and e.learned and e.max and e.max > 0 and e.rank >= e.max) then return false end
    if setting("cap") == false then return false end
    local key = ("cap:%s:%d"):format(e.key, e.max)
    if shownCap[key] then return false end
    local nextRank = NS.Trainers and NS.Trainers:NextRank(e.key, e.rank, e.max)
    if not nextRank then return false end
    shownCap[key] = true
    local p = capPayload(e, nextRank)
    show(p, key)
    NS.Print(("%s. %s"):format(p.title, p.detail))
    return true
end

--- A weapon skill `alerts.weaponGap` or more below its cap: toast, once per skill per session.
function A.CheckGap(e)
    if not (e and e.learned and e.kind == "weapon") or shownGap[e.key] then return false end
    if setting("weapon") == false then return false end
    local cap = math.max(e.max or 0, NS.SkillHelpers.WeaponCap(NS.Compat.PlayerLevel()))
    local gap = cap - (e.rank or 0)
    if gap < (tonumber(setting("weaponGap")) or A.DEFAULT_GAP) then return false end
    shownGap[e.key] = true
    show(gapPayload(e, cap, gap), "weapon:" .. e.key)
    return true
end

--- SKILL_UP(key, old, new): the model already holds the new rank.
function A.OnSkillUp(key)
    local e = NS.SkillData and NS.SkillData:Get(key)
    if not e then return end
    if e.kind == "weapon" then A.CheckGap(e) else A.CheckCap(e) end
end

--- SKILLS_UPDATED(model): a weapon whose cap rose (a level-up) is checked; the first model, at
--- login, only records the caps.
function A.OnSkillsUpdated(model)
    if not (model and model.byKey and model.order) then return end
    for _, key in ipairs(model.order.weapon or {}) do
        local e = model.byKey[key]
        if e and e.learned and e.kind == "weapon" then
            if lastMax[key] and e.max > lastMax[key] then A.CheckGap(e) end
            lastMax[key] = e.max
        end
    end
end

--- A left-click on a toast: a cap toast sets a waypoint to its trainer, or prints the directions.
function A.OnToastClick(payload)
    if not (payload and payload.kind == "cap" and payload.trainer) then return end
    local W = NS.Waypoints
    if W and type(W.Set) == "function" then
        W:Set(payload.trainer)
        return
    end
    NS.Print(L["%s: %s"]:format(payload.name, A.Directions(payload.trainer)))
end

-- ---------------------------------------------------------------------------------------------
-- The toast (Detached.dc.html): an icon square, a title, a detail and a hint for the cap; a small
-- square and one line for the weapon gap. Colors are the skin's roles and tokens.
-- ---------------------------------------------------------------------------------------------

local function abbrev(name)
    local a, b = (name or ""):match("^(%a)%a*[%s%-]+(%a)")
    if a then return (a .. b):upper() end
    return (name or "?"):sub(1, 2):upper()
end

local function colorCode(token)
    local r, g, b = NS.Skin.Color(token)
    if not r then return "", "" end
    return ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255), "|r"
end

local function text(frame, role, size)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    NS.Skin.Text(fs, role)
    if size and fs.GetFont and fs.SetFont then
        local face, _, flags = fs:GetFont()
        if face then fs:SetFont(face, size, flags) end
    end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

local function onMouseUp(frame, button)
    if button == "LeftButton" and not NS.IsTestMode() then A.OnToastClick(frame.skmPayload) end
end

local function rows(frame)
    if frame.skmTitle then return end
    local icon = CreateFrame("Frame", nil, frame)
    NS.Skin.IconBorder(icon, { fromSkin = true })
    icon.label = text(icon, "heading")
    icon.label:SetPoint("CENTER")
    icon.label:SetJustifyH("CENTER")
    frame.skmIcon = icon
    frame.skmTitle = text(frame, "heading", 13)
    frame.skmDetail = text(frame, "body")
    frame.skmHint = text(frame, "accent", 11)
    frame.skmHint:SetText(L["Click to set waypoint · right-click to dismiss"])
    -- The shell does nothing on a left-click; the builder's frame keeps it (Toast's contract). In
    -- test mode the left button drags, so the click is not read there.
    frame:HookScript("OnMouseUp", onMouseUp)
end

local function layout(frame, p)
    local cap = p.kind == "cap"
    local size = cap and A.ICON or A.ICON_SMALL
    local padY = cap and A.PAD_Y or A.PAD_Y - 2
    local icon, title, detail = frame.skmIcon, frame.skmTitle, frame.skmDetail
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", A.PAD_X, -padY)
    local textW = A.WIDTH - A.PAD_X - size - A.GAP - A.CLOSE_CLEAR
    for _, fs in ipairs({ title, detail, frame.skmHint }) do
        fs:ClearAllPoints()
        fs:SetWidth(textW)
    end
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", A.GAP, 0)
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    frame.skmHint:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -4)
    return size, padY
end

--- Toast's builder: draws `p` and answers the frame's size.
function A.Build(frame, p)
    if type(p) ~= "table" then return false end
    rows(frame)
    frame.skmPayload = p
    frame.skmIcon.label:SetText(abbrev(p.name))
    local size, padY = layout(frame, p)
    local cap = p.kind == "cap"
    if cap then
        frame.skmTitle:SetText(p.title)
        frame.skmDetail:SetText(p.detail)
        frame.skmDetail:Show()
        frame.skmHint:Show()
    else
        local open, close = colorCode("sem.warn")
        frame.skmTitle:SetText(("%s%s%s %s"):format(open, p.title, close, p.detail))
        frame.skmDetail:Hide()
        frame.skmHint:Hide()
    end
    local h = frame.skmTitle:GetStringHeight() or 0
    if cap then
        h = h + 2 + (frame.skmDetail:GetStringHeight() or 0) + 4 + (frame.skmHint:GetStringHeight() or 0)
    end
    return A.WIDTH, math.max(size, h) + 2 * padY
end

-- The degradation stub (anti-pattern #47): the instance's surface, each member a no-op.
A.ToastStub = {
    Show = function() return false end, Dismiss = function() end, Remove = function() return 0 end,
    Clear = function() end, Hold = function() end, Release = function() end,
    Preview = function() end, Pause = function() end, Resume = function() end,
    Attach = function() end, Refresh = function() end, ResetPosition = function() end,
    SetStack = function() return 1, "DOWN" end, Visible = function() return {} end,
    FrameFor = function() return nil end,
    Current = function() return nil end, Frame = function() return nil end,
    Stats = function() return { built = false, shown = false, waiting = 0, held = false,
        paused = false, sticky = false, keys = {}, visible = 0, visibleKeys = {},
        stack = 1, grow = "DOWN" } end,
}

local function alertsTable() return NS.db and NS.db.profile.alerts end

--- A new toast instance on this addon's descriptor (the stub without the library).
function A.NewToast()
    if not Toast then return A.ToastStub end
    return Toast:New({
        owner = addonName, name = "SkillMasterAlertToast", build = A.Build,
        width = A.WIDTH, stack = A.STACK,
        sound = function() return setting("sound") == true end,
        draggable = function() return NS.IsTestMode() end,
        -- Drag-only geometry (architecture-§5's named owner): only this file writes alerts.point.
        getPosition = function() local t = alertsTable() return t and t.point or nil end,
        setPosition = function(point) local t = alertsTable() if t then t.point = point or false end end,
        debug = function(_, fmt, ...) NS.Debug("Alerts", fmt, ...) end,
    })
end

A.toast = A.NewToast()

--- NS.StandDown: nothing stays on screen or waits.
function A.StandDown() A.toast:Clear() end

--- A profile switch: the position and the scale are re-read.
function A.Refresh() A.toast:Refresh() end

-- A tracked bus target: the stand-down takes these down and the stand-up replays them.
A.events = NS.NewBusTarget()
if A.events then
    A.events:RegisterMessage(NS.MSG.SKILL_UP, function(_, key) A.OnSkillUp(key) end)
    A.events:RegisterMessage(NS.MSG.SKILLS_UPDATED, function(_, model) A.OnSkillsUpdated(model) end)
end
