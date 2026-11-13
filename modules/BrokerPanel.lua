local addonName, NS = ...
-- modules/BrokerPanel.lua — the LDB tooltip in the main window's style (owner feedback round 6,
-- R6-10; Tooltips > Tooltip style "Main window", the default for a new profile). An addon-owned
-- frame at TOOLTIP strata that draws what the main window draws: the skin's window shell and title
-- band, test mode's strip, the window's block headers (NS.Blocks, the chevron showing the block's
-- collapse in the window, its sort and filter marks) and the window's rows (NS.Rows: icon, name, the
-- shared bar with its text inside it, the action mark at its right end), at the window's row
-- height, fonts and bar size, in a scrolled body (the wheel and the Journal's skin scroll bar) under
-- the tooltip's own Width and Height (tooltips.ldb.width / .height, the window's default size to
-- start). The footer keeps the feed's click hints.
--
-- It keeps the feed tooltip's interaction (owner decision): nothing on a header takes the pointer
-- (no collapse, sort, filter, detach or restore from here: they come from the window's blocks), and
-- a row's left click opens what it opens and its right click the row menu, NS.Broker.OpenRow, as a
-- classic tooltip row does. A row's mark is a glyph here, never a control, and no secure overlay is
-- ever laid over these rows (modules/SecureOverlay.lua syncs the window's and the detached rows only).
--
-- Shown, hidden and kept up by NS.Broker's showing machinery (OnEnter / OnLeave / HideTooltip):
-- NS.Broker.Tip() answers this frame in this style. P.Frame() / P.Fill() / P.Scroll() / P.SetScroll(n)
-- / P.Rows() / P.Headers() / P.Width() / P.ContentWidth() / P.MaxHeight().

NS.BrokerPanel = {}
local P = NS.BrokerPanel
local L = NS.L
local LAYERS = NS.Constants.LAYERS

P.FRAME_NAME = "SkillMasterBrokerPanel"

-- The main window's own measures (modules/MainWindow.lua), so one Width draws one body: the title
-- band, the scroll bar the body's width is counted without, and the gutter the window grows by.
local TITLE_H, SCROLLBAR_W = 28, 16
local SCROLL_GUTTER = 6 + SCROLLBAR_W + 4
-- The footer's inset, the Journal's skin scroll bar's width, its gap and the wheel's step.
local PAD, BAR_W, WHEEL_STEP = 10, 8, 40
local LINE_H = 12   -- a line's height when the client answers none

local frame, headerPool, rowPool
local state = { offset = 0, maxOffset = 0 }

local function settings()
    local t = NS.db and NS.db.profile.tooltips
    return t and t.ldb or NS.defaults.profile.tooltips.ldb
end

--- The body's width: the tooltip's Width as Layout > Window width counts it (the window's column).
function P.ContentWidth() return (tonumber(settings().width) or 420) - 4 - SCROLLBAR_W end
--- The frame's width: the body, the scroll bar's gutter and the edges, as the window's.
function P.Width() return P.ContentWidth() + 4 + SCROLL_GUTTER end
--- The tallest the tooltip grows; past it, the body scrolls.
function P.MaxHeight() return tonumber(settings().height) or 560 end

local function textHeight(fs)
    local h = fs:GetStringHeight()
    if (type(issecretvalue) == "function" and issecretvalue(h)) or type(h) ~= "number" or h <= 0 then
        return LINE_H
    end
    return h
end

-- ---------------------------------------------------------------------------------------------
-- The rows and headers: the window's own, made still
-- ---------------------------------------------------------------------------------------------

local function rowEnter(self) NS.Skin.ListRow(self, "hover") end
local function rowLeave(self) NS.Skin.ListRow(self, self.stripe and "stripe" or "normal") end

local function rowClick(self, button)
    local e = self.entry
    if e and NS.Broker then NS.Broker.OpenRow({ kind = self.kind, key = e.key }, button, self) end
end

--- A pooled window row taken over once: the feed's clicks and the window's hover wash, no row
--- tooltip and no overlay arming; its mark a glyph the click goes through.
local function dressRow(row)
    if row.skmPanel then return end
    row.skmPanel = true
    row:SetScript("OnEnter", rowEnter)
    row:SetScript("OnLeave", rowLeave)
    row:SetScript("OnClick", rowClick)
    if row.act then row.act:EnableMouse(false) end
end

-- A header's marks that act in the window; here nothing on a header takes the pointer.
local MARKS = { "chevron", "sort", "filter", "detach", "restore" }

--- A header as a state line: the chevron says the window's collapse, the sort and filter marks the
--- window's order and filter; detach and restore (actions only) are not drawn.
local function stillHeader(h)
    h:EnableMouse(false)
    for _, k in ipairs(MARKS) do
        if h[k] then h[k]:EnableMouse(false) end
    end
    h.detach:Hide()
    h.restore:Hide()
    h.sort:ClearAllPoints()
    h.sort:SetPoint("RIGHT", h, "RIGHT", -4, 0)
    h.meta:ClearAllPoints()
    h.meta:SetPoint("RIGHT", h.filter:IsShown() and h.filter or h.sort, "LEFT", -6, 0)
end

-- ---------------------------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------------------------

--- Scroll the body to `offset` units, clamped to what it overflows by.
function P.SetScroll(offset)
    local most = state.maxOffset or 0
    offset = math.floor(math.max(0, math.min(tonumber(offset) or 0, most)) + 0.5)
    state.offset = offset
    if frame then
        frame.list:SetVerticalScroll(offset)
        if frame.scrollBar then frame.scrollBar:Sync(most, offset) end
    end
end

--- The body's scroll offset (units) and its most (0 when everything fits).
function P.Scroll() return state.offset, state.maxOffset or 0 end

local function release()
    if headerPool then NS.Blocks.ReleaseHeaders(headerPool) end
    if rowPool then NS.Rows.ReleaseAll(rowPool) end
end

local function buildBody()
    frame.list = CreateFrame("ScrollFrame", nil, frame)
    frame.list:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    frame.content = CreateFrame("Frame", nil, frame.list)
    frame.content:SetSize(P.ContentWidth(), 1)
    frame.list:SetScrollChild(frame.content)
    frame.list:EnableMouseWheel(true)
    frame.list:SetScript("OnMouseWheel", function(_, delta)
        P.SetScroll(state.offset - (tonumber(delta) or 0) * WHEEL_STEP)
    end)
    local J = NS.Journal
    if J and J.MakeScrollBar then
        frame.scrollBar = J.MakeScrollBar(frame, function(offset) P.SetScroll(offset) end)
        frame.scrollBar:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    end
    frame.empty = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.empty:SetPoint("TOPLEFT", frame.content, "TOPLEFT", PAD, -6)
    frame.empty:SetJustifyH("LEFT")
    NS.Skin.Text(frame.empty, "muted")
    headerPool, rowPool = NS.Blocks.NewHeaderPool(), NS.Rows.NewPool()
end

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", P.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetFrameStrata(LAYERS.STRATA.TOOLTIP)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetSize(P.Width(), TITLE_H * 3)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -7)
    frame.gains = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.gains:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -9)
    frame.strip = NS.Widgets.TestStrip(frame, {
        text  = L["Test mode: the skills shown are sample data."],
        owner = addonName,
        onEnd = function() NS.ToggleTestMode() end,
    })
    if frame.strip then
        frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -TITLE_H)
        frame.strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -TITLE_H)
        frame.strip:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    end
    buildBody()
    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footer:SetJustifyH("LEFT")
    frame.footer:SetWordWrap(true)
    frame:SetScript("OnHide", release)
    frame:Hide()
    return frame
end

--- The panel frame, built on first ask (NS.Broker.Tip answers it in the Main window style).
function P.Frame() return build() end

--- The rows and headers drawn now (the suites read them).
function P.Rows() return rowPool and rowPool.active or {} end
function P.Headers() return headerPool and headerPool.active or {} end

-- ---------------------------------------------------------------------------------------------
-- One fill: the shown blocks, then the frame fitted to them
-- ---------------------------------------------------------------------------------------------

local function layoutGap()
    local l = NS.db and NS.db.profile.layout or NS.defaults.profile.layout
    return tonumber(l.blockGap) or 0
end

--- Block `id` from `y` down in the body: its header (the window's collapse), then, expanded, its
--- rows and an emptied filter's muted line. Answers the y under it, or `y` for a block with nothing.
local function layBlock(id, skills, stats, y)
    local entries, removed = NS.Broker.TooltipEntries(id, skills, stats)
    local note = NS.Blocks.FilterNote(entries, removed)
    if #entries == 0 and not note then return y end
    local host = frame.content
    local h = NS.Blocks.AcquireHeader(headerPool, host)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    h:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -y)
    local collapsed = NS.Blocks.Settings(id).collapsed and true or false
    h:SetBlock(id, NS.Blocks.Meta(id, entries), collapsed, true)
    stillHeader(h)
    y = y + NS.Blocks.HEADER_H
    if not collapsed then
        y = NS.Blocks.LayRows(entries, host, rowPool, y, "row", 0)
        if note then
            h:SetNote(note)
            y = y + NS.Blocks.NOTE_H
        end
    end
    return y + layoutGap()
end

--- The body's content: the shown blocks, or the one muted line that says why there are none.
local function layBody()
    local B = NS.Broker
    frame.empty:SetText("")
    if NS.IsStoodDown() then
        frame.empty:SetText(L["Ka0s Skill Master is disabled."])
        return LINE_H + 12
    end
    local skills, stats = B.Models()
    local y = 0
    for _, id in ipairs(B.ShownBlocks()) do
        local stat = NS.BlockDefs[id].source == "stats"
        if (stat and stats) or (not stat and skills) then y = layBlock(id, skills, stats, y) end
    end
    for _, row in ipairs(rowPool.active) do dressRow(row) end
    if y > 0 then return y end
    local have = NS.Broker.Feed() == "stats" and stats or (NS.Broker.Feed() ~= "stats" and skills)
    local none = NS.Broker.Feed() == "stats" and L["No stats to show yet."] or L["No skills to show yet."]
    frame.empty:SetText(have and L["Nothing to show in this tooltip."] or none)
    return LINE_H + 12
end

--- Size the frame to its body, up to Height; past it, the body scrolls.
local function fit(y)
    local stripOn = frame.strip ~= nil and frame.strip:IsShown()
    local top = TITLE_H + (stripOn and (NS.Widgets.TEST_STRIP and NS.Widgets.TEST_STRIP.HEIGHT or 18) or 0)
    local w = P.Width()
    frame:SetWidth(w)
    frame.footer:SetWidth(w - 2 * PAD)
    local footerH = math.ceil(textHeight(frame.footer)) + 8
    local room = math.max(1, P.MaxHeight() - top - 1 - footerH - 4)
    local viewH = math.max(1, math.min(y, room))
    state.maxOffset = y > room and math.ceil(y - room) or 0
    frame.content:SetSize(P.ContentWidth(), math.max(y, 1))
    frame.list:ClearAllPoints()
    frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -(top + 1))
    frame.list:SetSize(P.ContentWidth(), viewH)
    if frame.scrollBar then
        frame.scrollBar:ClearAllPoints()
        frame.scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(2 + (SCROLL_GUTTER - BAR_W) / 2), -(top + 1))
        frame.scrollBar:SetHeight(viewH)
    end
    frame.footer:ClearAllPoints()
    frame.footer:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(top + 1 + viewH + 4))
    frame:SetHeight(top + 1 + viewH + footerH + 4)
    P.SetScroll(0)
end

--- Draw the tooltip anew: the skin's shell and fonts, the title and gains, test mode's strip, the
--- shown blocks, the footer. NS.Broker.OnEnter shows it after.
function P.Fill()
    build()
    release()
    local S = NS.Skin
    S.Shell(frame)
    local title, gains = NS.Broker.Heading()
    frame.title:SetText(title)
    S.Text(frame.title, "title")
    frame.gains:SetText(gains)
    S.Text(frame.gains, "muted")
    S.Text(frame.empty, "muted")
    if frame.strip then frame.strip:SetShown(NS.IsTestMode()) end
    frame.footer:SetText(NS.Broker.FooterText())
    S.Text(frame.footer, "muted")
    fit(layBody())
end
