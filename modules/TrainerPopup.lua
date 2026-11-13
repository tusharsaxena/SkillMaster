local _, NS = ...
-- modules/TrainerPopup.lua — "where do I learn this" (design §2 goal 7, mockup "Tooltips" artboard,
-- plan Task 3.3): the trainers for the player's faction who teach an unlearned skill, or who train a
-- learned one's next rank, one selectable card each (name, cost, city · subzone (x, y), what else
-- they teach), the unverified-data warning, and two actions: set a waypoint (TomTom, the native
-- pin or chat, NS.Waypoints) and print the directions. A window opened on demand from the MEDIUM
-- main window, so HIGH (frame-layering-§1/§4), toplevel, clamped, Escape closes it, and it closes
-- with the window.
--
-- NS.TrainerPopup.Show(key) / .Hide() / .IsShown() / .Frame() / .Trainers() / .Select(i) / .Selected()
-- / .Relayout() / .TextHeight(fs) / .Distance(t) / .RefreshDistances() / .Ticking()
--
-- Round 5, R5-14: a card's "Also teaches" line wraps inside the card (up to ALSO_LINES lines), the
-- card grows by the wrapped height and the window by the cards; past P.MAX_HEIGHT every line falls
-- back to one (the client's ellipsis), and the card's tooltip always carries the whole list.
--
-- Round 6, R6-6: the Set waypoint button always reads "Set waypoint" (no provider in brackets) and
-- the "Waypoint order" footer is gone, the window shorter by it. When the selected trainer's
-- waypoint could only go to chat (no coordinates in the data, Waypoint method Chat only, or no
-- provider: NS.Waypoints:Blocked) the button is disabled, in the skin's disabled look, and its
-- tooltip says why; Print to chat still gives the directions.
--
-- Round 5, R5-15: each card shows the trainer's distance from the player ("123 yd"), measured from
-- world positions (NS.Compat.PlayerWorldPos / MapWorldPos, the map API, guarded) and compared only
-- inside one instance (continent); none when unknown. The cards sort nearest first, the unmeasured
-- after in the data's order, and re-measure once a second (P.TICK, an AceTimer) while shown.

NS.TrainerPopup = {}
local P = NS.TrainerPopup
local L = NS.L
local LAYERS = NS.Constants.LAYERS

P.FRAME_NAME = "SkillMasterTrainerPopup"
local WIDTH, TITLE_H, PAD, CARD_H, BUTTON_H = 380, 26, 10, 54, 26
-- The "Also teaches" line: the card's width less its 8-unit insets, the small font's line height
-- (the fallback when the client measures nothing), and the lines a card may wrap to.
local ALSO_W, LINE_H, ALSO_LINES = WIDTH - 2 * PAD - 16, 12, 4
--- The popup's tallest: past it, the cards' "Also teaches" lines drop back to one line each.
P.MAX_HEIGHT = 600

local frame, cardPool, ticker
local stopTicker, startTicker   -- defined with the distances below; the frame's OnHide / OnShow call them
-- base: the trainers in the data's order; list: the cards' order (nearest first); dist: yards each.
local state = { key = nil, base = {}, list = {}, dist = {}, selected = 1 }
--- Seconds between the distance re-measures while the popup is shown.
P.TICK = 1

function P.Frame() return frame end
function P.IsShown() return frame ~= nil and frame:IsShown() == true end
function P.Trainers() return state.list end
function P.Selected() return state.list[state.selected] end
--- Yards from the player to trainer `t` at the last measure, or nil when unknown.
function P.Distance(t) return state.dist[t] end
--- True while the distance re-measure runs (the popup is shown).
function P.Ticking() return ticker ~= nil end
--- The cards on show, in order (the suites read them).
function P.Cards() return cardPool and cardPool.active or {} end

local function skillName(key)
    local cat = NS.SkillCatalog[key]
    return cat and L[cat.name] or key
end

local function teachesText(t, key)
    local names = {}
    for _, k in ipairs(t.teaches or {}) do
        if k ~= key then names[#names + 1] = skillName(k) end
    end
    return #names > 0 and L["Also teaches: %s"]:format(table.concat(names, ", ")) or ""
end

local function distText(t)
    local d = state.dist[t]
    return d and L["%d yd"]:format(math.floor(d + 0.5)) or ""
end

local function whereText(t)
    local text = NS.Rows.Place(t)
    if t.subzone and t.subzone ~= text then text = text .. " \194\183 " .. t.subzone end
    if t.x and t.y then text = text .. (" (%d, %d)"):format(math.floor(t.x + 0.5), math.floor(t.y + 0.5)) end
    return text
end

-- ---------------------------------------------------------------------------------------------
-- Cards
-- ---------------------------------------------------------------------------------------------

local function onCardClick(self) P.Select(self.index) end

--- A FontString's wrapped height: its measured height, or one line when the client answers a
--- secret, nothing or zero (an empty or not yet laid-out string).
function P.TextHeight(fs)
    local h = fs:GetStringHeight()
    if (type(issecretvalue) == "function" and issecretvalue(h)) or type(h) ~= "number" or h <= 0 then
        return LINE_H
    end
    return h
end

-- One tooltip line in a skin token's color (the row tooltip's rule: no typed color).
local function tipLine(s, token, wrap)
    local c = NS.Bar.Color(token) or NS.Bar.Color("text.body") or { 1, 1, 1 }
    GameTooltip:AddLine(s, c[1], c[2], c[3], wrap)
end

-- The card's tooltip: the whole card, the "Also teaches" list unclipped.
local function onCardEnter(self)
    if not (GameTooltip and self.trainer) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    tipLine(self.trainer.name, "text.accent")
    tipLine(self.where:GetText() or "", "text.body")
    if self.alsoText and self.alsoText ~= "" then tipLine(self.alsoText, "text.muted", true) end
    GameTooltip:Show()
end

local function onCardLeave(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function buildCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(CARD_H)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)
    c.cost = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.cost:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -7)
    NS.Skin.Text(c.cost, "body")   -- the accent is the trainer name's alone (FB-11)
    c.dist = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.dist:SetPoint("TOPRIGHT", c.cost, "BOTTOMRIGHT", 0, -3)
    c.dist:SetJustifyH("RIGHT")
    NS.Skin.Text(c.dist, "muted")
    c.where = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.where:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    NS.Skin.Text(c.where, "body")
    c.also = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.also:SetPoint("TOPLEFT", c.where, "BOTTOMLEFT", 0, -3)
    c.also:SetWidth(ALSO_W)   -- an explicit width, so the wrapped height measures before layout
    c.also:SetJustifyH("LEFT")
    c.also:SetJustifyV("TOP")
    c.also:SetWordWrap(true)
    c.also:SetNonSpaceWrap(true)   -- one long skill name still breaks inside the card
    NS.Skin.Text(c.also, "muted")
    c:SetScript("OnClick", onCardClick)
    c:SetScript("OnEnter", onCardEnter)
    c:SetScript("OnLeave", onCardLeave)
    return c
end

local function trainersProfile()
    return (NS.db and NS.db.profile.trainers) or NS.defaults.profile.trainers
end

--- The trainer's name in its own color (feedback round 2, FB-11): the skin's accent, recorded so a
--- skin switch repaints it, while "Use the skin's color" is on; else the swatch through its
--- class-color companion, its alpha always applying (options-ui-§17). The skin's Text keeps the
--- name's font either way; a skin switch's LAYOUT_CHANGED repaints the swatch over it.
local function paintName(fs)
    NS.Skin.Text(fs, "accent")
    local p = trainersProfile()
    if p.nameColorFromSkin ~= false or type(p.nameColor) ~= "table" then
        if not NS.Skin.IsEnabled() then
            local c = NS.Bar.Color("text.accent")
            if c then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
        end
        return
    end
    local c = NS.Bar.WithClass(p.nameColor, p.useClassColorName)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function fillCard(c, t, key, i, maxLines)
    c.index, c.trainer = i, t
    c.name:SetText(t.name)
    paintName(c.name)
    local cost = t.costByKey and t.costByKey[key] or t.cost
    c.cost:SetText(cost and NS.Rows.Money(cost) or "")
    c.where:SetText(whereText(t))
    c.dist:SetText(distText(t))
    c.alsoText = teachesText(t, key)
    c.also:SetMaxLines(maxLines)
    c.also:SetText(c.alsoText)
    -- The card's rest height carries one "Also teaches" line; a wrapped one adds the rest.
    local h = math.ceil(CARD_H - LINE_H + math.max(LINE_H, P.TextHeight(c.also)))
    c:SetHeight(h)
    NS.Skin.ListRow(c, i == state.selected and "selected" or "normal")
    return h
end

-- ---------------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------------

local function setWaypoint()
    local t = P.Selected()
    if t then NS.Waypoints:Set(t) end
end

local function printDirections()
    local t = P.Selected()
    if t then NS.Waypoints:Print(t) end
end

local function button(parent, label, onClick, primary)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(BUTTON_H)
    -- A disabled button still shows its tooltip (the Set waypoint button says why it is disabled).
    if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    NS.Skin.Button(b, { primary = primary })
    return b
end

local function buildActions()
    frame.warning = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.warning:SetText(L["Coordinates unverified on WoW Forever (flagged until the smoke pass)"])
    NS.Skin.Text(frame.warning, "sem.warn")
    frame.waypoint = button(frame, L["Set waypoint"], setWaypoint, true)
    frame.waypoint:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.blockedText) then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        tipLine(self.blockedText, "text.body", true)
        GameTooltip:Show()
    end)
    frame.waypoint:SetScript("OnLeave", onCardLeave)
    frame.print = button(frame, L["Print to chat"], printDirections, false)
end

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", P.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetFrameStrata(LAYERS.STRATA.WINDOW_READ)   -- Show sets P.Strata() at each open
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetWidth(WIDTH)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    NS.Skin.Shell(frame)
    NS.Skin.Text(frame.title, "title")
    frame.close = NS.MakeCloseButton(frame, function() P.Hide() end)
    if frame.close then frame.close:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CHROME) end
    NS.Skin.Header(frame, { title = frame.title, align = "LEFT", right = { frame.close } })
    if not frame.title:GetPoint(1) then frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -7) end
    frame.intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.intro:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_H + 8))
    frame.intro:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame.intro:SetJustifyH("LEFT")
    NS.Skin.Text(frame.intro, "muted")
    cardPool = NS.Pool.New()
    buildActions()
    UISpecialFrames[#UISpecialFrames + 1] = P.FRAME_NAME
    frame:SetScript("OnHide", stopTicker)   -- Escape and the window's close hide it without P.Hide
    -- A UIParent hide (Alt+Z, a cinematic) runs OnHide too, and the popup comes back with it: the
    -- re-measure restarts on that show (review, R5-followups).
    frame:SetScript("OnShow", function() startTicker() end)
    frame:Hide()
    return frame
end

-- The cards, top down, each "Also teaches" line wrapping to `maxLines`; the y under the last.
local function placeCards(maxLines)
    NS.Pool.ReleaseAll(cardPool)
    local y = TITLE_H + 30
    local unverified = false
    for i, t in ipairs(state.list) do
        local c = NS.Pool.Acquire(cardPool, function() return buildCard(frame) end)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        c:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
        local h = fillCard(c, t, state.key, i, maxLines)
        c:Show()
        y = y + h + 6
        unverified = unverified or NS.Waypoints.UnverifiedMark(t) ~= ""
    end
    return y, unverified
end

local function layout()
    local y, unverified = placeCards(ALSO_LINES)
    if y + (unverified and 18 or 0) + BUTTON_H + PAD > P.MAX_HEIGHT then
        y, unverified = placeCards(1)   -- too tall: one line each, the tooltip has the rest
    end
    frame.warning:ClearAllPoints()
    frame.warning:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.warning:SetShown(unverified)
    if unverified then y = y + 18 end
    frame.waypoint:ClearAllPoints()
    frame.waypoint:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
    frame.waypoint:SetPoint("RIGHT", frame, "CENTER", 40, 0)
    frame.print:ClearAllPoints()
    frame.print:SetPoint("TOPLEFT", frame.waypoint, "TOPRIGHT", 8, 0)
    frame.print:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame:SetHeight(y + BUTTON_H + PAD)   -- no footer under the buttons (R6-6)
end

-- Why the Set waypoint button is disabled, by NS.Waypoints:Blocked's answer (R6-6).
local BLOCKED_TEXT = {
    nocoords = L["No map coordinates for this trainer yet; Print to chat gives directions."],
    chat = L["Waypoint method is Chat only (Trainers and Waypoints page); Print to chat gives directions."],
    noprovider = L["No TomTom and no map pin on this client; Print to chat gives directions."],
}

local function refreshActions()
    local t = P.Selected()
    local blocked = t and NS.Waypoints:Blocked(t)
    frame.waypoint.text:SetText(L["Set waypoint"])
    frame.waypoint.blockedText = blocked and BLOCKED_TEXT[blocked] or nil
    frame.waypoint:SetEnabled(t ~= nil and not blocked)
    frame.print:SetEnabled(t ~= nil)
end

--- The list and the lines for skill `key`: its teachers when unlearned, else its next rank's.
local function resolve(key)
    local e = NS.SkillData and NS.SkillData.Get and NS.SkillData:Get(key)
    local B = NS.Blocks
    if B.source then
        local skills = B.Data()
        e = skills and skills.byKey[key] or e
    end
    local name, faction = skillName(key), type(UnitFactionGroup) == "function" and UnitFactionGroup("player") or ""
    if e and e.learned ~= false then
        local nr = NS.Trainers:NextRank(key, e.rank, e.max)
        if nr then
            return nr.trainers, L["Train: %s (%s)"]:format(name, nr.rankName),
                L["Trainers for your faction (%s) who train %s to %s (%d):"]:format(faction, name, nr.rankName, nr.cap)
        end
    end
    return NS.Trainers:For(key), L["Learn: %s"]:format(name),
        L["Trainers for your faction (%s) who teach %s:"]:format(faction, name)
end

-- ---------------------------------------------------------------------------------------------
-- Distances (R5-15)
-- ---------------------------------------------------------------------------------------------

-- A trainer's world position, once measured (static, so kept); weak keys: the records are the data's.
local worldOf = setmetatable({}, { __mode = "k" })

local function trainerWorld(t)
    local w = worldOf[t]
    if w then return w end
    if not (t.mapID and t.x and t.y) then return nil end
    local instance, x, y = NS.Compat.MapWorldPos(t.mapID, t.x / 100, t.y / 100)
    if instance == nil then return nil end
    w = { instance, x, y }
    worldOf[t] = w
    return w
end

--- Yards from the player to each trainer of `list` (trainer -> yards; absent when unknown).
local function measure(list)
    local dist = {}
    local instance, x, y = NS.Compat.PlayerWorldPos()
    if instance == nil then return dist end
    local me = { instance, x, y }
    for _, t in ipairs(list) do dist[t] = NS.Trainers.Distance(me, trainerWorld(t)) end
    return dist
end

function stopTicker()
    if ticker and NS.addon then NS.addon:CancelTimer(ticker) end
    ticker = nil
end

function startTicker()
    stopTicker()   -- a stand-down's CancelAllTimers may have taken the old one: always a fresh one
    if NS.addon and NS.addon.ScheduleRepeatingTimer then
        ticker = NS.addon:ScheduleRepeatingTimer(P.RefreshDistances, P.TICK)
    end
end

local function sameOrder(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

--- Re-measure the distances: the cards' distance lines, and the order when it changed (the selected
--- trainer stays selected). Stops the re-measure once the popup is hidden.
function P.RefreshDistances()
    if not P.IsShown() then return stopTicker() end
    local selected = P.Selected()
    state.dist = measure(state.base)
    local list = NS.Trainers.ByDistance(state.base, state.dist)
    if sameOrder(list, state.list) then
        for _, c in ipairs(cardPool.active) do c.dist:SetText(distText(c.trainer)) end
        return
    end
    state.list, state.selected = list, 1
    for i, t in ipairs(list) do if t == selected then state.selected = i end end
    layout()
    refreshActions()
end

--- Open the popup on skill `key`.
local RANK = {}
for i, s in ipairs(LAYERS.STRATA_CHOICES) do RANK[s] = i end

--- The popup's strata: one above the higher of its two openers' (the window and a detached block,
--- each a player's pick), never under WINDOW_READ, so it opens over whichever it came from
--- (frame-layering-§1: a frame opened from another sits at least one strata above it).
function P.Strata()
    local stored = (NS.db and NS.db.profile.layout) or NS.defaults.profile.layout
    local top = stored.strata
    if (RANK[stored.detachedStrata] or 0) > (RANK[top] or 0) then top = stored.detachedStrata end
    local above = LAYERS.STRATA_ABOVE[top]
    if not above or (RANK[above] and RANK[above] < RANK[LAYERS.STRATA.WINDOW_READ]) then
        return LAYERS.STRATA.WINDOW_READ
    end
    return above
end

function P.Show(key)
    build()
    frame:SetFrameStrata(P.Strata())   -- at each open: the openers' strata are the player's
    local list, title, intro = resolve(key)
    state.dist = measure(list)
    state.key, state.base, state.selected = key, list, 1
    state.list = NS.Trainers.ByDistance(list, state.dist)
    frame.title:SetText(title)
    frame.intro:SetText(#list > 0 and intro or L["No trainer for your faction is recorded for this skill."])
    layout()
    refreshActions()
    frame:Show()
    startTicker()
end

--- Lay the open popup out again (its cards' text re-measured); a no-op while it is hidden.
function P.Relayout()
    if not P.IsShown() then return end
    layout()
end

--- Select the `i`th card (the waypoint and print actions use it).
function P.Select(i)
    if not state.list[i] then return end
    state.selected = i
    for _, c in ipairs(cardPool.active) do NS.Skin.ListRow(c, c.index == i and "selected" or "normal") end
    refreshActions()
end

function P.Hide()
    stopTicker()
    if frame then frame:Hide() end
end

-- A changed name color (a Trainers-page row) or a skin switch reaches an open popup at once.
local function repaintNames()
    if not P.IsShown() then return end
    for _, c in ipairs(P.Cards()) do paintName(c.name) end
end

if NS.NewBusTarget then
    P.events = NS.NewBusTarget()
    if P.events then P.events:RegisterMessage(NS.MSG.LAYOUT_CHANGED, repaintNames) end
end
