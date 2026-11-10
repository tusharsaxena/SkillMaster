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

NS.TrainerPopup = {}
local P = NS.TrainerPopup
local L = NS.L
local LAYERS = NS.Constants.LAYERS

P.FRAME_NAME = "SkillMasterTrainerPopup"
local WIDTH, TITLE_H, PAD, CARD_H, BUTTON_H = 380, 26, 10, 54, 26

local frame, cardPool
local state = { key = nil, list = {}, selected = 1 }

function P.Frame() return frame end
function P.IsShown() return frame ~= nil and frame:IsShown() == true end
function P.Trainers() return state.list end
function P.Selected() return state.list[state.selected] end

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

local function buildCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(CARD_H)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)
    NS.Skin.Text(c.name, "body")
    c.cost = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.cost:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -7)
    NS.Skin.Text(c.cost, "accent")
    c.where = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.where:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -3)
    NS.Skin.Text(c.where, "body")
    c.also = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.also:SetPoint("TOPLEFT", c.where, "BOTTOMLEFT", 0, -3)
    c.also:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    c.also:SetJustifyH("LEFT")
    c.also:SetWordWrap(false)
    NS.Skin.Text(c.also, "muted")
    c:SetScript("OnClick", onCardClick)
    return c
end

local function fillCard(c, t, key, i)
    c.index = i
    c.name:SetText(t.name)
    local cost = t.costByKey and t.costByKey[key] or t.cost
    c.cost:SetText(cost and NS.Rows.Money(cost) or "")
    c.where:SetText(whereText(t))
    c.also:SetText(teachesText(t, key))
    NS.Skin.ListRow(c, i == state.selected and "selected" or "normal")
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
    frame.print = button(frame, L["Print to chat"], printDirections, false)
    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footer:SetText(L["Waypoint order: TomTom, then a native map pin, then chat directions"])
    NS.Skin.Text(frame.footer, "muted")
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
    frame:Hide()
    return frame
end

local function layout()
    NS.Pool.ReleaseAll(cardPool)
    local y = TITLE_H + 30
    local unverified = false
    for i, t in ipairs(state.list) do
        local c = NS.Pool.Acquire(cardPool, function() return buildCard(frame) end)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        c:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -y)
        fillCard(c, t, state.key, i)
        c:Show()
        y = y + CARD_H + 6
        unverified = unverified or NS.Waypoints.UnverifiedMark(t) ~= ""
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
    frame.footer:ClearAllPoints()
    frame.footer:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(y + BUTTON_H + 8))
    frame:SetHeight(y + BUTTON_H + 32)
end

local METHOD_LABEL = { tomtom = L["TomTom"], native = L["map pin"], chat = L["chat"] }

local function refreshActions()
    local t = P.Selected()
    local method = t and NS.Waypoints:Method(t) or "chat"
    frame.waypoint.text:SetText(L["Set waypoint (%s)"]:format(METHOD_LABEL[method]))
    frame.waypoint:SetEnabled(t ~= nil)
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
    state.key, state.list, state.selected = key, list, 1
    frame.title:SetText(title)
    frame.intro:SetText(#list > 0 and intro or L["No trainer for your faction is recorded for this skill."])
    layout()
    refreshActions()
    frame:Show()
end

--- Select the `i`th card (the waypoint and print actions use it).
function P.Select(i)
    if not state.list[i] then return end
    state.selected = i
    for _, c in ipairs(cardPool.active) do NS.Skin.ListRow(c, c.index == i and "selected" or "normal") end
    refreshActions()
end

function P.Hide()
    if frame then frame:Hide() end
end
