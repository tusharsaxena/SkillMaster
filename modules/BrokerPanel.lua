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
-- Nothing on a header takes the pointer (owner decision: no collapse, sort, filter, detach or
-- restore from here: they come from the window's blocks). A row's shift-click links it and its
-- right click opens the row menu (NS.Broker.OpenRow) wherever it lands. Its left click follows
-- Tooltips > Open a row from (round 7, R7-6; NS.Broker.OpenFrom):
--   * "icon" (the default): the go icon opens it, as the main window's does. Out of combat the
--     hovered row's go icon gets the window's secure overlay (modules/SecureOverlay.lua scans these
--     rows while P.Armed(): a profession window by its cast, the character panel by the micro
--     button); a click the overlay did not take reaches the icon, NS.Interact.Open (in combat it
--     says why it cannot open, as the window's mark does). The row's own left click opens nothing,
--     and the row takes the window's hover: the wash, the row tooltip, the icon lit under the pointer.
--   * "row": the whole row opens it, NS.Broker.OpenRow, as a classic tooltip row does; the icon is a
--     glyph the click goes through, and no overlay is laid over these rows.
-- The overlay follows the rows: a scroll and the panel's hide re-sync it (out of combat; in combat
-- Sync waits, every overlay disarmed at combat start), and a released row is forgotten (NS.Rows).
--
-- Shown, hidden and kept up by NS.Broker's showing machinery (OnEnter / OnLeave / HideTooltip):
-- NS.Broker.Tip() answers this frame in this style. P.Frame() / P.Fill() / P.Scroll() / P.SetScroll(n)
-- / P.Rows() / P.Headers() / P.Width() / P.ContentWidth() / P.MaxHeight() / P.Armed().

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

local function iconMode() return NS.Broker.OpenFrom() == "icon" end

--- Whether the hovered row's go icon is armed with the secure overlay: the panel shows, in the go
--- icon mode (modules/SecureOverlay.lua scans P.Rows() while it answers true).
function P.Armed()
    return frame ~= nil and frame:IsShown() == true and iconMode() and not NS.IsStoodDown()
end

local function isShift() return type(IsShiftKeyDown) == "function" and IsShiftKeyDown() end

--- A row's click: the right button and a shift-click always (the row menu, the link); the plain left
--- click only in the whole row mode (the go icon mode opens from the icon alone).
local function rowClick(self, button)
    local e = self.entry
    if not (e and NS.Broker) then return end
    if button ~= "RightButton" and not isShift() and iconMode() then return end
    NS.Broker.OpenRow({ kind = self.kind, key = e.key }, button, self)
end

--- The go icon's own click (the overlay did not take it: in combat, a kind it has none for, or not
--- yet synced): the window's mark action (NS.Interact.Open); the right button and shift as the row.
local function actClick(row, button)
    if not row.entry then return end
    if button == "RightButton" or isShift() then return rowClick(row, button) end
    if NS.RowTooltip then NS.RowTooltip.Hide(row) end
    return NS.Interact.Open(row)
end

--- A pooled window row dressed for the panel on each fill, as Open a row from says: in the go icon
--- mode the window's hover (NS.Rows.RowEnter / RowLeave: the overlay, the row tooltip, the icon's
--- hot watch) and a live icon; in the whole row mode the wash alone and the icon a glyph.
local function dressRow(row)
    if not row.skmPanel then
        row.skmPanel = true
        row:SetScript("OnClick", rowClick)
        row.overlayClick = rowClick   -- the overlay's right and shift clicks (SecureOverlay PostClick)
        if row.act then row.act:SetScript("OnClick", function(_, button) actClick(row, button) end) end
    end
    local icon = iconMode()
    row:SetScript("OnEnter", icon and NS.Rows.RowEnter or rowEnter)
    row:SetScript("OnLeave", icon and NS.Rows.RowLeave or rowLeave)
    if row.act then row.act:EnableMouse(icon) end
end

--- Re-lay the overlay over the hovered row after the rows moved (a scroll) or went (a hide).
local function syncOverlay()
    local SO = NS.SecureOverlay
    if SO and SO.Sync then SO:Sync() end
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
        if P.Armed() then syncOverlay() end   -- the armed icon moved with its row
    end
end

--- The body's scroll offset (units) and its most (0 when everything fits).
function P.Scroll() return state.offset, state.maxOffset or 0 end

local function release()
    if headerPool then NS.Blocks.ReleaseHeaders(headerPool) end
    if rowPool then
        for _, row in ipairs(rowPool.active) do
            if NS.RowTooltip then NS.RowTooltip.Hide(row) end
        end
        NS.Rows.ReleaseAll(rowPool)   -- each released row forgotten by the overlay (NS.Rows park)
    end
end

--- The panel hid: its rows go, and so does any overlay armed over one (out of combat; in combat
--- every overlay was disarmed at its start and Sync waits).
local function onHide()
    release()
    syncOverlay()
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
        -- Always drawn, disabled while nothing scrolls (round 7, R7-4): the gutter is never empty.
        frame.scrollBar = J.MakeScrollBar(frame, function(offset) P.SetScroll(offset) end, { alwaysShown = true })
        frame.scrollBar:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    end
    frame.empty = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.empty:SetPoint("TOPLEFT", frame.content, "TOPLEFT", PAD, -6)
    frame.empty:SetJustifyH("LEFT")
    NS.Skin.Text(frame.empty, "muted")
    headerPool, rowPool = NS.Blocks.NewHeaderPool(), NS.Rows.NewPool()
end

--- The strip menu's rows: End test, as the window's strip has (the library's label).
function P.StripMenuRows()
    return { { label = L["End test"], value = "END_TEST", onClick = function() NS.ToggleTestMode() end } }
end

local stripMenu
--- The strip's menu while it was last opened (the suites read it).
function P.StripMenu() return stripMenu end

local function stripClick(self, button)
    if button ~= "RightButton" then return end
    stripMenu = NS.Widgets.ContextMenu(self, P.StripMenuRows(), { owner = addonName, cursor = true })
    if stripMenu then NS.Broker.RaiseMenu(stripMenu, frame) end
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
    -- No onEnd: the library's strip menu opens at its own FULLSCREEN_DIALOG strata, under this
    -- TOOLTIP frame. The strip's right-click opens the same End test row here, lifted above the
    -- tooltip as the row menu is (NS.Broker.RaiseMenu), so the tooltip stays up while it is open.
    frame.strip = NS.Widgets.TestStrip(frame, {
        text  = L["Test mode: the skills shown are sample data."],
        owner = addonName,
    })
    if frame.strip then
        frame.strip:EnableMouse(true)
        frame.strip:SetScript("OnMouseUp", stripClick)
        frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -TITLE_H)
        frame.strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -TITLE_H)
        frame.strip:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    end
    buildBody()
    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footer:SetJustifyH("LEFT")
    frame.footer:SetWordWrap(true)
    frame:SetScript("OnHide", onHide)
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
    h:SetBlock(id, collapsed, true)
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
