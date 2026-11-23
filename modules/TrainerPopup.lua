local _, NS = ...
-- modules/TrainerPopup.lua — "where do I learn this" (design §2 goal 7, mockup "Tooltips" artboard,
-- plan Task 3.3): the trainers for the player's faction who teach an unlearned skill, or who train a
-- learned one's next rank, one selectable card each (name, cost, city · subzone (x, y), what else
-- they teach), the unverified-data warning, and two actions: set a waypoint (the native pin or
-- chat, NS.Waypoints) and print the directions. A window opened on demand from the MEDIUM
-- main window, so HIGH (frame-layering-§1/§4), toplevel, clamped, Escape closes it, and it closes
-- with the window.
--
-- NS.TrainerPopup.Show(key) / .Hide() / .IsShown() / .Frame() / .Trainers() / .Groups() / .Select(i)
-- / .Selected() / .Relayout() / .TextHeight(fs) / .Distance(t) / .RefreshDistances() / .Ticking()
-- / .Scroll() / .SetScroll(offset) / .Headings() / .Notes() / .Key()
--
-- Round 2 (the owner's feedback, 2026-11-23): a rank no trainer trains (Artisan Cooking, First Aid,
-- Fishing; Expert from a book) says so under its heading, naming the quest or book and who gives
-- it, the giver's card selectable for its waypoint, and the skill's trainers listed below.
--
-- Round 5, R5-14: a card's "Also teaches" line wraps inside the card (up to ALSO_LINES lines), the
-- card grows by the wrapped height and the window by the cards, and the card's tooltip always
-- carries the whole list.
--
-- Round 6, R6-7: a learned skill's popup lists the trainers of its next rank and of every higher
-- rank (an Artisan trainer trains Expert too; NS.Trainers:NextRank's groups), each rank under its
-- heading ("Expert (225)"), the next rank first, nearest first inside a rank, a trainer once under
-- the lowest rank it trains. Past P.MAX_HEIGHT the cards scroll inside the window (the wheel and a
-- skin scroll bar, the Journal's NS.Journal.MakeScrollBar) instead of clipping (GitHub issue #4).
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
-- The small font's line height (the fallback when the client measures nothing), the lines a card's
-- "Also teaches" line may wrap to (inside the card's 8-unit insets), a rank heading's line, the
-- scroll bar's width and gap, and the wheel's step.
local LINE_H, ALSO_LINES, HEAD_H = 12, 4, 18
local SCROLL_W, SCROLL_GAP, WHEEL_STEP = 8, 4, 40
--- The popup's tallest: past it, the cards scroll inside the window (R6-7).
P.MAX_HEIGHT = 600

local frame, cardPool, ticker
local stopTicker, startTicker   -- defined with the distances below; the frame's OnHide / OnShow call them
-- groups: { rankName, cap, base (the data's order), list (nearest first) } per rank heading, or one
-- unnamed group for a skill to learn; base: every trainer in the data's order; list: the cards'
-- order (group by group); dist: yards each; offset: the cards' scroll, in units.
local state = { key = nil, groups = {}, base = {}, list = {}, dist = {}, selected = 1, offset = 0 }
--- Seconds between the distance re-measures while the popup is shown.
P.TICK = 1

function P.Frame() return frame end
function P.IsShown() return frame ~= nil and frame:IsShown() == true end
function P.Trainers() return state.list end
--- The skill key the popup was opened on (round 9: the waypoint arrow's Show trainers), or nil.
function P.Key() return state.key end
--- The rank groups on show: { rankName, cap, list } each (rankName nil for a skill to learn).
function P.Groups() return state.groups end
--- The cards' scroll offset (units) and its most (0 when everything fits).
function P.Scroll() return state.offset, state.maxOffset or 0 end
function P.Selected() return state.list[state.selected] end
--- Yards from the player to trainer `t` at the last measure, or nil when unknown.
function P.Distance(t) return state.dist[t] end
--- True while the distance re-measure runs (the popup is shown).
function P.Ticking() return ticker ~= nil end
--- The cards on show, in order (the suites read them).
function P.Cards() return cardPool and cardPool.active or {} end

-- Skill `key`'s rank ladder (defaults/Ranks_Forever.lua), or nil for a skill with no ranks.
local function ladderOf(key)
    local name = NS.RankLadderFor_Forever and NS.RankLadderFor_Forever[key]
    return name and NS.Ranks_Forever and NS.Ranks_Forever[name]
end

--- Whether card trainer `t` wears the "Your next rank" mark: Show all trainers is on and `t` trains
--- the rank the player trains next (round 2).
function P.Marked(t)
    return state.showAll == true and state.nextCap ~= nil and NS.Trainers.TrainsCap(t, state.nextCap)
end

--- The marked card's tooltip line: "Your next rank: Expert (225)".
function P.MarkTip()
    for _, step in ipairs(state.key and ladderOf(state.key) or {}) do
        if step.cap == state.nextCap then return L["Your next rank: %s (%d)"]:format(step.rankName, step.cap) end
    end
    return L["Your next rank"]
end

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

-- One tooltip line in a skin token's color (the row tooltip's rule: no typed color), from the gtip
-- family, drawn for the stock GameTooltip's dark backing (the owner's U-7, skinning-§7).
local function tipLine(s, token, wrap)
    local c = NS.SkinColor(token) or NS.SkinColor("gtip.body") or { 1, 1, 1 }
    GameTooltip:AddLine(s, c[1], c[2], c[3], wrap)
end

-- The card's own wash: selected, else normal.
local function restWash(c)
    return c.index == state.selected and "selected" or "normal"
end

-- A card is clicked, so it takes the skin's list.hover wash while the pointer is on it (the owner's
-- U-31, SkillMaster#9); ListRow is recorded, so a skin switch repaints it. The journal's rows are
-- not clicked and take none.
-- Its tooltip: the whole card, the "Also teaches" list unclipped. A card is a BODY element
-- (LibKa0s#92, AD-92-SM): beside the popup, its window group, level with the card
-- (NS.Chrome.PlaceBeside); it was owned at ANCHOR_RIGHT, the corner offset the rule retires.
local function onCardEnter(self)
    NS.Skin.ListRow(self, "hover")
    if not (GameTooltip and self.trainer) then return end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    tipLine(self.trainer.name, "gtip.title")
    tipLine(self.where:GetText() or "", "gtip.body")
    if P.Marked(self.trainer) then tipLine(P.MarkTip(), "sem.good") end
    if self.alsoText and self.alsoText ~= "" then tipLine(self.alsoText, "gtip.muted", true) end
    GameTooltip:Show()
    NS.Chrome.PlaceBeside(GameTooltip, self, frame)
end

local function onCardLeave(self)
    NS.Skin.ListRow(self, restWash(self))
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
    -- Round 2: the mark of a trainer of the player's next rank, in Show all trainers mode.
    c.mark = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.mark:SetPoint("LEFT", c.name, "RIGHT", 6, 0)
    c.mark:SetText(L["Your next rank"])
    NS.Skin.Text(c.mark, "sem.good")
    c.mark:Hide()
    c.where = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.where:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    NS.Skin.Text(c.where, "body")
    c.also = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.also:SetPoint("TOPLEFT", c.where, "BOTTOMLEFT", 0, -3)
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
            local c = NS.SkinColor("text.accent")
            if c then fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end
        end
        return
    end
    local c = NS.WithClassColor(p.nameColor, p.useClassColorName)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function fillCard(c, t, key, i, maxLines, width)
    c.index, c.trainer = i, t
    c:SetWidth(width)
    c.also:SetWidth(width - 16)   -- an explicit width, so the wrapped height measures before layout
    c.name:SetText(t.name)
    paintName(c.name)
    c.mark:SetShown(P.Marked(t))
    local cost = t.costByKey and t.costByKey[key] or t.cost
    c.cost:SetText(cost and NS.Rows.Money(cost) or "")
    c.where:SetText(whereText(t))
    c.dist:SetText(distText(t))
    c.alsoText = NS.Trainers.WithLearn(t, teachesText(t, key))
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

-- Round 2: the Show all trainers check box, the client's UICheckButtonTemplate painted by the skin
-- (LibKa0s-Widgets has no check box; NS.Skin.Checkbox is what the options panel's are painted with),
-- with its label and a tooltip. Shown for a skill with ranks only (Show).
local function buildShowAll()
    local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    NS.Skin.Checkbox(cb, { hover = true })
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(L["Show all trainers"])
    NS.Skin.Text(cb.label, "body")
    -- Toggled from the setting, not GetChecked: the write seam holds the state (the panel's row too).
    cb:SetScript("OnClick", function() P.SetShowAll(not P.ShowAll()) end)
    cb:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        tipLine(L["Show all trainers"], "gtip.title")
        tipLine(L["In the trainer popup for a profession, list every trainer of every rank, Artisan first, and mark the ones who train your next rank."], "gtip.body", true)
        GameTooltip:Show()
        NS.Chrome.PlaceAttached(GameTooltip, self)
    end)
    cb:SetScript("OnLeave", function(self) if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    frame.showAll = cb
end

local function buildActions()
    frame.warning = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.warning:SetText(L["Not confirmed on WoW Forever yet (marked until checked)"])
    NS.Skin.Text(frame.warning, "sem.warn")
    frame.waypoint = button(frame, L["Set waypoint"], setWaypoint, true)
    -- Hooked, not set: NS.Skin.Button hooked its hover look on these scripts, and SetScript drops it.
    -- The action buttons are the popup's CHROME (a modal dialog's controls, LibKa0s#92, AD-92-SM):
    -- the reason attaches centered above the button (NS.Chrome.PlaceAttached), below it only
    -- without room above.
    frame.waypoint:HookScript("OnEnter", function(self)
        if not (GameTooltip and self.blockedText) then return end
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        tipLine(self.blockedText, "gtip.body", true)
        GameTooltip:Show()
        NS.Chrome.PlaceAttached(GameTooltip, self)
    end)
    frame.waypoint:HookScript("OnLeave", onCardLeave)
    frame.print = button(frame, L["Print to chat"], printDirections, false)
end

local setScroll   -- the cards' scroll, defined with the layout below

-- The cards' viewport: a scroll frame whose child holds the rank headings and the cards, the wheel
-- and a skin scroll bar (the Journal's) driving its offset (R6-7).
local function buildList()
    frame.list = CreateFrame("ScrollFrame", nil, frame)
    frame.content = CreateFrame("Frame", nil, frame.list)
    frame.content:SetSize(WIDTH - 2 * PAD, 1)
    frame.list:SetScrollChild(frame.content)
    frame.list:EnableMouseWheel(true)
    frame.list:SetScript("OnMouseWheel", function(_, delta)
        setScroll(state.offset - (tonumber(delta) or 0) * WHEEL_STEP)
    end)
    local J = NS.Journal
    if J and J.MakeScrollBar then
        frame.scrollBar = J.MakeScrollBar(frame, function(offset) setScroll(offset) end)
        frame.scrollBar:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    end
    frame.headings = {}
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
    -- The title-bar marks on LibKa0s Widgets' HeaderButtons (AD-86-SM, LibKa0s#86): settings, then
    -- the close. The popup stands a strata over its openers, HIGH or DIALOG, over the settings panel
    -- (HIGH), so the settings mark hides it first (hideOnSettings).
    local hb = NS.Chrome.TitleMarks(frame, {
        close = function() P.Hide() end,
        settingsTip = L["Open the settings panel"],
        hideOnSettings = frame,
        level = LAYERS.LEVEL.CHROME,
    })
    frame.close, frame.settingsButton = hb.close, hb.settings
    NS.Skin.Header(frame, { title = frame.title, align = "LEFT", right = hb.right, gap = select(2, NS.Chrome.HeaderPitch()) })
    if not frame.title:GetPoint(1) then frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -7) end
    frame.intro = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.intro:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_H + 8))
    frame.intro:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
    frame.intro:SetJustifyH("LEFT")
    NS.Skin.Text(frame.intro, "muted")
    buildShowAll()
    cardPool = NS.Pool.New()
    buildList()
    buildActions()
    UISpecialFrames[#UISpecialFrames + 1] = P.FRAME_NAME
    frame:SetScript("OnHide", stopTicker)   -- Escape and the window's close hide it without P.Hide
    -- A UIParent hide (Alt+Z, a cinematic) runs OnHide too, and the popup comes back with it: the
    -- re-measure restarts on that show (review, R5-followups).
    frame:SetScript("OnShow", function() startTicker() end)
    frame:Hide()
    return frame
end

--- The rank headings on show, in order (the suites read them).
function P.Headings()
    local out = {}
    for _, h in ipairs(frame and frame.headings or {}) do if h:IsShown() then out[#out + 1] = h end end
    return out
end

local function heading(n)
    local h = frame.headings[n]
    if not h then
        h = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetJustifyH("LEFT")
        NS.Skin.Text(h, "heading")
        frame.headings[n] = h
    end
    return h
end

--- The "No trainer teaches" notes on show, in order (round 2; the suites read them).
function P.Notes()
    local out = {}
    for _, n in ipairs(frame and frame.notes or {}) do if n:IsShown() then out[#out + 1] = n end end
    return out
end

-- The `n`th note line, wrapped to the list's width (round 2, NS.Trainers.NoTrainerNote).
local function note(n)
    frame.notes = frame.notes or {}
    local fs = frame.notes[n]
    if not fs then
        fs = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        NS.Skin.Text(fs, "sem.warn")
        frame.notes[n] = fs
    end
    return fs
end

-- A group's heading (a rank's "Expert (225)", or a titled group's text) and its note, at `y`; the
-- height they take.
local function placeHead(g, y, width, counts)
    local h0 = y
    local text = g.title or (g.rankName and L["%s (%d)"]:format(g.rankName, g.cap))
    if text then
        counts.h = counts.h + 1
        local h = heading(counts.h)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 2, -(y + 2))
        h:SetText(text)
        h:Show()
        y = y + HEAD_H
    end
    if g.note then
        counts.n = counts.n + 1
        local fs = note(counts.n)
        fs:ClearAllPoints()
        fs:SetWidth(width - 4)
        fs:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 2, -y)
        fs:SetText(g.note)
        fs:Show()
        y = y + math.ceil(P.TextHeight(fs)) + 4
    end
    return y - h0
end

-- The headings, notes and cards, top down inside the scroll child, `width` wide, each "Also
-- teaches" line wrapping to ALSO_LINES; the height they take.
local function placeList(width)
    NS.Pool.ReleaseAll(cardPool)
    for _, h in ipairs(frame.headings) do h:Hide() end
    for _, fs in ipairs(frame.notes or {}) do fs:Hide() end
    local y, i, unverified = 0, 0, false
    local counts = { h = 0, n = 0 }
    for _, g in ipairs(state.groups) do
        y = y + placeHead(g, y, width, counts)
        for _, t in ipairs(g.list) do
            i = i + 1
            local c = NS.Pool.Acquire(cardPool, function() return buildCard(frame.content) end)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
            local h = fillCard(c, t, state.key, i, ALSO_LINES, width)
            c:Show()
            y = y + h + 6
            unverified = unverified or NS.Waypoints.UnverifiedMark(t) ~= ""
        end
    end
    return y, unverified
end

--- Scroll the cards to `offset` units, clamped to what the list overflows by.
function setScroll(offset)
    local most = state.maxOffset or 0
    offset = math.floor(math.max(0, math.min(tonumber(offset) or 0, most)) + 0.5)
    state.offset = offset
    if frame and frame.list then frame.list:SetVerticalScroll(offset) end
    if frame and frame.scrollBar then frame.scrollBar:Sync(most, offset) end
end
P.SetScroll = function(offset) setScroll(offset) end

local function layout()
    local top = TITLE_H + 8 + math.ceil(P.TextHeight(frame.intro)) + 8
    if frame.showAll:IsShown() then
        frame.showAll:ClearAllPoints()
        frame.showAll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD - 2, -(top - 4))
        top = top + 20
    end
    local full = WIDTH - 2 * PAD
    local listH, unverified = placeList(full)
    local room = P.MAX_HEIGHT - top - (unverified and 18 or 0) - BUTTON_H - PAD
    local scrolls = listH > room and frame.scrollBar ~= nil
    if scrolls then listH, unverified = placeList(full - SCROLL_W - SCROLL_GAP) end
    local viewH = math.max(1, scrolls and room or listH)
    frame.content:SetSize(scrolls and full - SCROLL_W - SCROLL_GAP or full, math.max(1, listH))
    frame.list:ClearAllPoints()
    frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
    frame.list:SetSize(full, viewH)
    if frame.scrollBar then
        frame.scrollBar:ClearAllPoints()
        frame.scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -top)
        frame.scrollBar:SetHeight(viewH)
    end
    state.maxOffset = scrolls and math.ceil(listH - viewH) or 0
    setScroll(state.offset)
    local y = top + viewH
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

-- Round 2 (the owner's feedback, as ItemTree shows it): a rank no trainer trains says so under its
-- heading (NS.Trainers.NoTrainerNote), and when the next rank is one, the skill's trainers follow
-- under "Trainers who teach X" (those not listed above, book vendors and quest givers left out).
local function annotate(groups, key, name)
    for _, g in ipairs(groups) do g.note = NS.Trainers.NoTrainerNote(name, g.rankName, g.base) end
    if not (groups[1] and groups[1].note) then return groups end
    local listed, rest = {}, {}
    for _, g in ipairs(groups) do for _, t in ipairs(g.base) do listed[t] = true end end
    for _, t in ipairs(NS.Trainers:For(key)) do
        if not listed[t] and not t.learn then rest[#rest + 1] = t end
    end
    if #rest > 0 then groups[#groups + 1] = { title = L["Trainers who teach %s"]:format(name), base = rest } end
    return groups
end

--- The groups and the lines for skill `key`: its teachers when unlearned (one unnamed group), else
--- its next rank's and every higher rank's, one group per rank (R6-7).
local function skillEntry(key)
    local e = NS.SkillData and NS.SkillData.Get and NS.SkillData:Get(key)
    local B = NS.Blocks
    if B.source then
        local skills = B.Data()
        e = skills and skills.byKey[key] or e
    end
    return e
end

--- Whether the popup lists every rank's trainers (round 2, trainers.showAll).
function P.ShowAll()
    local p = (NS.db and NS.db.profile.trainers) or NS.defaults.profile.trainers
    return p.showAll == true
end

--- Turn Show all trainers on or off (the row's single write seam) and re-open the popup on its skill.
function P.SetShowAll(on)
    NS.SetByPath("trainers.showAll", on and true or false)
    if P.IsShown() and state.key then P.Show(state.key) end
end

-- Round 2, Show all trainers: every rank's teachers, Artisan first (NS.Trainers:AllRanks), a rank no
-- trainer trains with its note.
local function allGroups(key, name)
    local groups = {}
    for i, g in ipairs(NS.Trainers:AllRanks(key) or {}) do
        groups[i] = { rankName = g.rankName, cap = g.cap, base = g.trainers,
                      note = NS.Trainers.NoTrainerNote(name, g.rankName, g.trainers) }
    end
    return groups
end

-- The next rank's groups (R6-7), annotated (round 2).
local function rankGroupsOf(nr, key, name)
    local groups = {}
    for i, g in ipairs(nr.groups or { { rankName = nr.rankName, cap = nr.cap, trainers = nr.trainers } }) do
        groups[i] = { rankName = g.rankName, cap = g.cap, base = g.trainers }
    end
    return annotate(groups, key, name)
end

--- What skill `key` opens on: its groups, title and intro, and the cap of the rank the player trains
--- next (round 2's mark; the ladder's first for an unlearned skill, nil at the top). Unlearned: its
--- teachers (one unnamed group); learned: its next rank's and every higher rank's (R6-7); with Show
--- all trainers on and a ladder: every rank's, Artisan first.
local function resolve(key)
    local e = skillEntry(key)
    local name, faction = skillName(key), type(UnitFactionGroup) == "function" and UnitFactionGroup("player") or ""
    local learned = e ~= nil and e.learned ~= false
    local nr = learned and NS.Trainers:NextRank(key, e.rank, e.max) or nil
    local ladder = ladderOf(key)
    local nextCap = nr and nr.cap or (not learned and ladder and ladder[1].cap) or nil
    local title = nr and L["Train: %s (%s)"]:format(name, nr.rankName) or L["Learn: %s"]:format(name)
    if ladder and P.ShowAll() then
        return allGroups(key, name), title,
            L["Every trainer for your faction (%s) who teaches %s, the highest rank first:"]:format(faction, name), nextCap
    end
    if nr then
        local intro = nr.higher
            and L["Trainers for your faction (%s) who train %s to %s (%d) or higher:"]
            or L["Trainers for your faction (%s) who train %s to %s (%d):"]
        return rankGroupsOf(nr, key, name), title, intro:format(faction, name, nr.rankName, nr.cap), nextCap
    end
    return { { base = NS.Trainers:For(key) } }, title,
        L["Trainers for your faction (%s) who teach %s:"]:format(faction, name), nextCap
end

-- Every group's cards nearest first by state.dist, and the cards' order group by group.
local function orderGroups()
    local list = {}
    for _, g in ipairs(state.groups) do
        g.list = NS.Trainers.ByDistance(g.base, state.dist)
        for _, t in ipairs(g.list) do list[#list + 1] = t end
    end
    return list
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
    local list = orderGroups()
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
    local groups, title, intro, nextCap = resolve(key)
    local all = {}
    for _, g in ipairs(groups) do for _, t in ipairs(g.base) do all[#all + 1] = t end end
    state.key, state.groups, state.base, state.selected, state.offset = key, groups, all, 1, 0
    state.showAll = ladderOf(key) ~= nil and P.ShowAll()
    state.nextCap = nextCap
    frame.showAll:SetShown(ladderOf(key) ~= nil)
    frame.showAll:SetChecked(state.showAll)
    state.dist = measure(all)
    state.list = orderGroups()
    frame.title:SetText(title)
    frame.intro:SetText(#all > 0 and intro or L["No trainer for your faction is recorded for this skill."])
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
