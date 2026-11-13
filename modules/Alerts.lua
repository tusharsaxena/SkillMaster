local addonName, NS = ...
-- modules/Alerts.lua — the rank-cap, weapon-gap and skill-up alerts (design §5.2, plan Task 4.2) on
-- LibKa0s-Toast-1.0: a profession at its rank's cap with a next rank to train toasts once per cap
-- and says the trainer in chat; a weapon skill `alerts.weaponGap` or more below its cap toasts once
-- per skill per session, on SKILL_UP or a level-up. Each alert has its switch; `alerts.sound` plays
-- the toast's sound. A left-click on a cap toast sets a waypoint to the trainer (NS.Waypoints, T3.3)
-- or, without it, prints the directions.
--
-- Owner feedback round 4 (the mockup "Skill Master alert toasts"): a skill-up toast on every point
-- (alerts.skillUp, alerts.skillUpScope), green, short-lived (A.SKILLUP_SECONDS), its own sound
-- switch; skill-ups within A.FOLD_SECONDS of the last share one toast.
--
-- Owner feedback round 6 (R6-1): every kind wears the cap toast's look, the skin's toast shell, its
-- body text and the cap toast's icon size, with no tint or edge of its own. The weapon-gap and
-- skill-up toasts keep a small uppercase label and their numbers in the kind's semantic color
-- (A.KIND_TOKEN), the delta in brackets: "Daggers 74 / 110 (-36)", "Bows 81 / 110 (+1)".
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
A.ICON = 36   -- every kind's icon (round 6: the cap toast's size)
A.GAP = 12
A.CLOSE_CLEAR = 26   -- the toast's close mark: 18 px, 4 px in, plus a margin
A.STACK = 3          -- test mode shows a cap, a weapon-gap and a skill-up toast together (round 5)
A.DEFAULT_GAP = 25
A.UNTRAINED = 5   -- a weapon at this many points or fewer was never really used (alerts.weaponMode)

A.SKILLUP_SECONDS = 4   -- a skill-up toast's life (the others keep the library's 8)
A.FOLD_SECONDS = 5      -- skill-ups this close together share one toast
-- The semantic color each kind's label and numbers take (the skin's tokens): skill up green,
-- weapon gap red. The toast itself is the skin's shell, as the cap toast's (round 6).
A.KIND_TOKEN = { skillup = "sem.good", weapon = "sem.bad" }

local shownCap, shownGap, lastMax = {}, {}, {}
local recentUps, lastUpAt = {}, nil   -- the skill-ups the open skill-up toast folds

--- Forget what this session alerted (the suites; a session otherwise never resets).
function A.Reset()
    shownCap, shownGap, lastMax = {}, {}, {}
    recentUps, lastUpAt = {}, nil
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
        label = L["Weapon skill gap"],
        title = ("%s %d / %d"):format(e.name, e.rank, cap), delta = ("-%d"):format(gap),
        detail = L["Glancing blows and misses are more likely."],
    }
end

local function log() return NS.Preview and NS.Preview.Log() or NS.SessionLog end

--- The skill-up line under the title: this session's points, the points to cap and the ETA, each
--- when known ("3 this session · 49 to cap · ~2 h at this pace").
local function upDetail(e)
    local parts, SL = {}, log()
    local n = SL and SL.GainsFor and SL:GainsFor(e.key)
    if type(n) == "number" and n > 0 then parts[#parts + 1] = L["%d this session"]:format(n) end
    local left = (e.max or 0) - (e.rank or 0)
    if left > 0 then parts[#parts + 1] = L["%d to cap"]:format(left) end
    local eta = left > 0 and SL and SL.ETA and SL:ETA(e.key)
    if eta and eta > 0 and NS.RowTooltip then
        parts[#parts + 1] = L["%s at this pace"]:format(NS.RowTooltip.FormatETA(eta))
    end
    return table.concat(parts, " \194\183 ")
end

--- The skill-up toast over `ups` (oldest first, the newest titles it): one skill, or "Skill up · 3
--- skills" with the others named under it.
function A.SkillUpPayload(ups)
    local e = ups[#ups]
    local p = { kind = "skillup", key = e.key, name = e.name,
                title = ("%s %d / %d"):format(e.name, e.rank or 0, e.max or 0), delta = "+1" }
    if #ups == 1 then
        p.label, p.detail = L["Skill up"], upDetail(e)
        return p
    end
    local others = {}
    for i = #ups - 1, 1, -1 do others[#others + 1] = ("%s %d"):format(ups[i].name, ups[i].rank or 0) end
    p.label = L["Skill up \194\183 %d skills"]:format(#ups)
    p.detail = L["Also %s"]:format(table.concat(others, ", "))
    return p
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

--- Whether weapon `e` is one the gap alert reads: not muted, and as alerts.weaponMode says
--- (owner feedback round 3: Unarmed at 4 / 120 toasted on every level-up).
function A.WeaponWatched(e)
    local muted = setting("weaponMuted")
    if type(muted) == "table" and muted[e.key] then return false end
    local mode = setting("weaponMode") or "untrained"
    if mode == "equipped" then return NS.SkillHelpers.EquippedWeaponSkills()[e.key] == true end
    if mode == "untrained" then return (e.rank or 0) > A.UNTRAINED end
    return true
end

--- A weapon skill `alerts.weaponGap` or more below its cap: toast, once per skill per session.
function A.CheckGap(e)
    if not (e and e.learned and e.kind == "weapon") or shownGap[e.key] then return false end
    if setting("weapon") == false or not A.WeaponWatched(e) then return false end
    local cap = math.max(e.max or 0, NS.SkillHelpers.WeaponCap(NS.Compat.PlayerLevel()))
    local gap = cap - (e.rank or 0)
    if gap < (tonumber(setting("weaponGap")) or A.DEFAULT_GAP) then return false end
    shownGap[e.key] = true
    show(gapPayload(e, cap, gap), "weapon:" .. e.key)
    return true
end

--- Whether the skill-up alert reads entry `e` (alerts.skillUp, alerts.skillUpScope).
function A.SkillUpWatched(e)
    if setting("skillUp") == false then return false end
    local scope = setting("skillUpScope") or "all"
    local prof = e.category == "primary" or e.category == "secondary"
    if scope == "professions" then return prof end
    if scope == "combat" then return not prof end
    return true
end

local function now() return type(GetTime) == "function" and GetTime() or 0 end

--- A skill point on `e`: the skill-up toast, folded into the open one when the last skill-up was
--- under A.FOLD_SECONDS ago (the same skill's again replaces its own entry).
function A.CheckSkillUp(e)
    if not (e and e.learned ~= false and A.SkillUpWatched(e)) then return false end
    local t = now()
    if not (lastUpAt and t - lastUpAt <= A.FOLD_SECONDS) then recentUps = {} end
    for i = #recentUps, 1, -1 do if recentUps[i].key == e.key then table.remove(recentUps, i) end end
    recentUps[#recentUps + 1] = { key = e.key, name = e.name, rank = e.rank, max = e.max,
                                  category = e.category }
    lastUpAt = t
    if A.toast.Remove then A.toast:Remove("skillup") end
    show(A.SkillUpPayload(recentUps), "skillup")
    return true
end

--- SKILL_UP(key, old, new): the model already holds the new rank.
function A.OnSkillUp(key)
    local e = NS.SkillData and NS.SkillData:Get(key)
    if not e then return end
    if e.kind == "weapon" then A.CheckGap(e) else A.CheckCap(e) end
    A.CheckSkillUp(e)
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

-- ---------------------------------------------------------------------------------------------
-- Test mode's toasts (owner feedback round 5, R5-1): one of each kind from the sample character,
-- sticky while test mode is on (and draggable, so the player can place them), taken down when it ends.
-- Built from the preview's model (NS.Preview.Skill), never the live one; nothing is recorded in the
-- session's alerted sets, so a real alert after test mode still shows.
-- ---------------------------------------------------------------------------------------------

A.TEST_CAP, A.TEST_WEAPON, A.TEST_SKILLUP = "leatherworking", "daggers", "bows"
A.TEST_KEYS = { "test:cap", "test:weapon", "test:skillup" }

local function testCap(P)
    local e = P.Skill(A.TEST_CAP)
    if not (e and e.max) then return nil end
    e = { key = e.key, name = e.name, rank = e.max, max = e.max }   -- the sample's craft, at its cap
    local nextRank = NS.Trainers and NS.Trainers:NextRank(e.key, e.rank, e.max)
    return nextRank and capPayload(e, nextRank) or nil
end

local function testGap(P)
    local e = P.Skill(A.TEST_WEAPON)
    if not e then return nil end
    local cap = math.max(e.max or 0, NS.SkillHelpers.WeaponCap(P.Character().level))
    return gapPayload(e, cap, cap - (e.rank or 0))
end

local function testUp(P)
    local e = P.Skill(A.TEST_SKILLUP)
    if not e then return nil end
    return A.SkillUpPayload({ { key = e.key, name = e.name, rank = e.rank, max = e.max, category = e.category } })
end

--- Test mode's toasts: { { key, payload } ... }, cap, weapon gap, skill up, those the sample draws.
function A.TestToasts()
    local P, out = NS.Preview, {}
    if not (P and P.IsOn()) then return out end
    local payloads = { testCap(P), testGap(P), testUp(P) }
    for i, key in ipairs(A.TEST_KEYS) do
        if payloads[i] then out[#out + 1] = { key = key, payload = payloads[i] } end
    end
    return out
end

--- Show test mode's toasts, sticky (any of them already up is replaced).
function A.ShowTestToasts()
    A.HideTestToasts()
    for _, t in ipairs(A.TestToasts()) do A.toast:Show(t.payload, { key = t.key, sticky = true }) end
end

--- Take test mode's toasts down (and drop any still waiting).
function A.HideTestToasts()
    for _, key in ipairs(A.TEST_KEYS) do A.toast:Remove(key) end
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
-- The toast (Detached.dc.html): an icon square, a title, a detail and a hint for the cap; the same
-- square, a small label, the title and one line for the others. Colors are the skin's roles and tokens.
-- ---------------------------------------------------------------------------------------------

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
    if button == "LeftButton" and not NS.IsTestMode() and frame.skmPayload and frame.skmPayload.kind == "cap" then
        A.OnToastClick(frame.skmPayload)
    end
end

--- "Daggers 74 / 110 (-36)": the name in the title's role, the numbers and the bracketed delta in
--- `token`'s color (the kind's semantic one).
function A.KindTitle(p, token)
    local open, close = colorCode(token)
    local delta = (p.delta and p.delta ~= "") and (" (%s)"):format(p.delta) or ""
    local name, nums = (p.title or ""):match("^(.-) (%d+ / %d+)$")
    if name then return ("%s %s%s%s%s"):format(name, open, nums, delta, close) end
    return ("%s%s%s%s"):format(p.title or "", open, delta, close)
end

local function rows(frame)
    if frame.skmTitle then return end
    local icon = CreateFrame("Frame", nil, frame)
    NS.Skin.IconBorder(icon, { fromSkin = true })
    -- The skill's in-game icon (FB-14, the row's), inside the skin's icon border.
    icon.art = icon:CreateTexture(nil, "ARTWORK")
    icon.art:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
    icon.art:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    icon.art:SetTexCoord(unpack(NS.Rows.ICON_TRIM))
    frame.skmIcon = icon
    frame.skmLabel = text(frame, "body", 10)
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
    local size, padY = A.ICON, A.PAD_Y
    local icon, title, detail = frame.skmIcon, frame.skmTitle, frame.skmDetail
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", A.PAD_X, -padY)
    local textW = A.WIDTH - A.PAD_X - size - A.GAP - A.CLOSE_CLEAR
    for _, fs in ipairs({ title, detail, frame.skmHint }) do
        fs:ClearAllPoints()
        fs:SetWidth(textW)
    end
    local label = frame.skmLabel
    label:ClearAllPoints()
    label:SetWidth(textW)
    if cap then
        label:Hide()
        title:SetPoint("TOPLEFT", icon, "TOPRIGHT", A.GAP, 0)
    else
        label:Show()
        label:SetPoint("TOPLEFT", icon, "TOPRIGHT", A.GAP, 0)
        title:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
    end
    detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    frame.skmHint:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -4)
    return size, padY
end

--- Toast's builder: draws `p` and answers the frame's size.
function A.Build(frame, p)
    if type(p) ~= "table" then return false end
    rows(frame)
    frame.skmPayload = p
    frame.skmIcon.art:SetTexture(NS.Rows.Icon("skill", p.key))
    local size, padY = layout(frame, p)
    local cap = p.kind == "cap"
    A.lastKind = p.kind   -- the duration and sound getters run right after the build
    frame.skmDetail:SetText(p.detail or "")
    frame.skmDetail:Show()
    frame.skmHint:SetShown(cap)
    if cap then
        frame.skmTitle:SetText(p.title)
    else
        -- The label and the numbers in the kind's color: "Bows 81 / 130 (+1)", "Crossbows 97 / 130 (-33)".
        local token = A.KIND_TOKEN[p.kind]
        local open, close = colorCode(token)
        frame.skmTitle:SetText(A.KindTitle(p, token))
        frame.skmLabel:SetText(open .. (p.label or ""):upper() .. close)
    end
    local h = frame.skmTitle:GetStringHeight() or 0
    h = h + 2 + (frame.skmDetail:GetStringHeight() or 0)
    if cap then h = h + 4 + (frame.skmHint:GetStringHeight() or 0)
    else h = h + 2 + (frame.skmLabel:GetStringHeight() or 0) end
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
        -- Read right after each build (Toast's present): the kind just built picks its own sound
        -- switch and its life (a skill-up toast is short).
        sound = function()
            if A.lastKind == "skillup" then return setting("skillUpSound") == true end
            return setting("sound") == true
        end,
        duration = function() return A.lastKind == "skillup" and A.SKILLUP_SECONDS or nil end,
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
