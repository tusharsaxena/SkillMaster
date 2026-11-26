local addonName, NS = ...
-- modules/BrokerPanel.lua — the LDB tooltip in the main window's style (owner feedback round 6,
-- R6-10; Tooltips > Tooltip style "Main window", the default for a new profile). An addon-owned
-- frame at TOOLTIP strata that draws what the main window draws: the skin's window shell and title
-- band, test mode's strip (docked by the library directly under the title band, Widgets' `dock =
-- "title"`, AD-88-SM; the body moves down by its BodyOffset), the window's block headers (NS.Blocks, the chevron showing the block's
-- collapse in the window; no sort or filter mark since round 8, R8-4, the rows following the
-- window's sort and filter all the same) and the window's rows (NS.Rows: icon, name, the
-- shared bar with its text inside it, the action mark at its right end), at the window's row
-- height, fonts and bar size, in a scrolled body (the wheel and the Journal's skin scroll bar) under
-- the tooltip's own Width and Height (tooltips.ldb.width / .height, the window's default size to
-- start). The footer keeps the feed's click hints.
--
-- ONLY THE FOLD TAKES A CLICK (the owner's ask, SMW-07). A block header's chevron folds or unfolds that
-- section in the tooltip alone (NS.Broker.ToggleTipFold, tooltips.ldb.folds; the window's collapse is
-- untouched), and the body is drawn again in place at its scroll offset; the rest of the header takes no
-- pointer. A row opens, links and menus nothing here and arms no secure overlay; it keeps the window's
-- hover, the wash and the row tooltip (with no click hint). Test mode's strip takes no click either.
--
-- Shown, hidden and kept up by NS.Broker's showing machinery (OnEnter / OnLeave / HideTooltip):
-- NS.Broker.Tip() answers this frame in this style. P.Frame() / P.Fill([keepScroll]) / P.Scroll() /
-- P.SetScroll(n) / P.Rows() / P.Headers() / P.Width() / P.ContentWidth() / P.MaxHeight().

NS.BrokerPanel = {}
local P = NS.BrokerPanel
local L = NS.L
local LAYERS = NS.Constants.LAYERS

P.FRAME_NAME = "SkillMasterBrokerPanel"

-- The main window's own measures (modules/MainWindow.lua), so one Width draws one body: the title
-- band's bottom (NS.Chrome.TitleBottom, read from the band at each fill; TITLE_H, its no-band figure,
-- sizes the frame before the first), the scroll bar the body's width is counted without, and the
-- gutter the window grows by.
local TITLE_H, SCROLLBAR_W = NS.Chrome.TITLE_BOTTOM, 16
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

-- The least gap between the title and the gains text in the title band.
local TITLE_GAP = 8

local function textWidth(fs)
    local w = fs:GetStringWidth()
    if (type(issecretvalue) == "function" and issecretvalue(w)) or type(w) ~= "number" then return nil end
    return w
end

--- Lay the title in the band: centered over the frame, as the main window's, while it clears the
--- gains text at the top right; else from the left inset to the gains text's left edge, one line,
--- truncated if even that is too narrow (round 7 review: the feeds' longer titles at Width 300).
local function layTitle()
    local title, gains = frame.title, frame.gains
    local tw, gw = textWidth(title), textWidth(gains)
    title:ClearAllPoints()
    if tw and gw and (P.Width() + tw) / 2 <= P.Width() - PAD - gw - TITLE_GAP then
        title:SetPoint("TOP", frame, "TOP", 0, -7)
        title:SetJustifyH("CENTER")
    else
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -7)
        title:SetPoint("RIGHT", gains, "LEFT", -TITLE_GAP, 0)
        title:SetJustifyH("LEFT")
    end
end

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

-- A row's hover here: the window's wash and its row tooltip, nothing armed (no overlay, no lit mark).
local function rowEnter(self)
    NS.Skin.ListRow(self, "hover")
    if NS.RowTooltip and self.entry then NS.RowTooltip.Show(self) end
end

local function rowLeave(self)
    if self:IsMouseOver() == true then return end
    NS.Skin.ListRow(self, self.stripe and "stripe" or "normal")
    if NS.RowTooltip then NS.RowTooltip.Hide(self) end
end

--- A pooled window row dressed for the panel on each fill: no click of any button on the row or its
--- go icon, the panel's own hover, and `openFrom` "none" (the row tooltip then gives no click hint).
local function dressRow(row)
    row:SetScript("OnClick", nil)
    row:SetScript("OnMouseDown", nil)
    row:SetScript("OnEnter", rowEnter)
    row:SetScript("OnLeave", rowLeave)
    row.overlayClick = nil
    row.openFrom = "none"
    -- A tree header's chevron (SMW-08..10) folds it in the tooltip's own folds, never the window's.
    row.onFold = row.tree and function(r) return NS.Broker.ToggleTipNode(r.family, r.entry.nodeKey) end or nil
    if row.act then
        row.act:SetScript("OnClick", nil)
        row.act:EnableMouse(false)
    end
end

-- A header's marks that act in the window; here only the chevron takes the pointer.
local MARKS = { "sort", "filter", "detach", "restore" }

local function foldClick(h) NS.Broker.ToggleTipFold(h.id) end

--- A header as the tooltip's: the chevron says and flips the tooltip's own fold; the header's body and
--- every other mark take no pointer, and are not drawn (detach and restore are window actions, and the
--- sort and filter marks went in round 8, R8-4, the rows following the window's order and filter).
local function stillHeader(h)
    h:EnableMouse(false)
    for _, k in ipairs(MARKS) do
        if h[k] then h[k]:EnableMouse(false) end
    end
    h.detach:Hide()
    h.restore:Hide()
    h.sort:Hide()
    h.filter:Hide()
    h.onFold = foldClick
    h.chevron:EnableMouse(true)
    h.chevron.tip = nil   -- the chevron says it (R5-SM-01: no hint tooltip on a fold)
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
    if rowPool then
        for _, row in ipairs(rowPool.active) do
            if NS.RowTooltip then NS.RowTooltip.Hide(row) end
        end
        NS.Rows.ReleaseAll(rowPool)   -- each released row forgotten by the overlay (NS.Rows park)
    end
end

--- The panel hid: its rows go.
local function onHide() release() end

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

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", P.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetFrameStrata(LAYERS.STRATA.TOOLTIP)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetSize(P.Width(), TITLE_H * 3)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetWordWrap(false)   -- one line; P.Fill bounds it clear of the gains text
    frame.gains = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.gains:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -9)
    -- No onEnd and no click (SMW-07: only a fold chevron acts in the tooltip; test mode ends from the
    -- window's own strip or /sm test). Docked under the title band by the library, full width (AD-88-SM,
    -- LibKa0s#88).
    frame.titleBar = NS.Chrome.TitleBar(frame)
    frame.strip = NS.Widgets.TestStrip(frame, {
        text  = L["Test mode: the skills shown are sample data."],
        owner = addonName,
        dock = "title", titleBar = frame.titleBar, window = frame,
    })
    if frame.strip then
        frame.strip:EnableMouse(false)
        frame.strip:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    end
    buildBody()
    -- The hint lines (NS.Broker.FooterText) stay a FontString of their own, wrapped and as tall as
    -- they measure: this is a tooltip's footer, not a window's, with no resize grip and no status
    -- line, so standalone-windows' *The footer* (Widgets' Footer) does not cover it (AD-89-SM review).
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

--- Block `id` from `y` down in the body: its header (the tooltip's own fold, SMW-07), then, open, its
--- rows and an emptied filter's muted line. Answers the y under it, or `y` for a block with nothing.
local function blockEntries(id, skills, stats, models)
    if NS.IsTreeBlock(id) then return NS.Broker.TreeEntries(id, models), 0 end
    return NS.Broker.TooltipEntries(id, skills, stats)
end

local function layBlock(id, skills, stats, y, models)
    local entries, removed = blockEntries(id, skills, stats, models)
    local note = NS.Blocks.FilterNote(entries, removed)
    if #entries == 0 and not note then return y end
    local host = frame.content
    local h = NS.Blocks.AcquireHeader(headerPool, host)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    h:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -y)
    local collapsed = NS.Broker.TipFolded(id)
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

--- The feed's pins first (GitHub issue #11, SMW-06): a Pinned header, then each pin as its block's row.
--- Answers the y under them, or `y` when the feed has none.
local PIN_KINDS = { skill = true, stat = true }
local function layPins(y)
    local pins = {}
    for _, r in ipairs(NS.Broker.PinnedEntries(NS.Broker.Feed())) do
        -- A tree pin (SMW-08..10) as a leaf at the section's edge.
        if NS.Tree.Kind(r.kind) then
            pins[#pins + 1] = { kind = r.kind, entry = r.entry, depth = 0, indent = 0 }
        elseif PIN_KINDS[r.kind] then
            pins[#pins + 1] = r
        end
    end
    if #pins == 0 then return y end
    local host = frame.content
    local h = NS.Blocks.AcquireHeader(headerPool, host)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    h:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -y)
    h:SetLabel(L["Pinned"])
    h:EnableMouse(false)
    y = NS.Blocks.LayRows(pins, host, rowPool, y + NS.Blocks.HEADER_H, "row", 0)
    return y + layoutGap()
end

--- The body's content: the feed's pins and its shown blocks, or the one muted line that says why there
--- are none.
local function layBody()
    local B = NS.Broker
    frame.empty:SetText("")
    if NS.IsStoodDown() then
        frame.empty:SetText(L["Ka0s Skill Master is disabled."])
        return LINE_H + 12
    end
    local skills, stats, more = B.Models()
    local models = { skills = skills, stats = stats }   -- by provider source (modules/BlockProviders.lua)
    for k, m in pairs(more or {}) do models[k] = m end
    local y = layPins(0)
    for _, id in ipairs(B.ShownBlocks()) do
        if models[NS.BlockDefs[id].source] then y = layBlock(id, skills, stats, y, models) end
    end
    for _, row in ipairs(rowPool.active) do dressRow(row) end
    if y > 0 then return y end
    -- The feed's family has a model and nothing showed, or has none yet (SMW-05: each feed's own line).
    local fid = B.Feed()
    local f = B.FEEDS[fid]
    frame.empty:SetText(models[f and f.source] and L["Nothing to show in this tooltip."] or NS.Windows.EmptyText(fid))
    return LINE_H + 12
end

--- Size the frame to its body, up to Height; past it, the body scrolls.
local function fit(y, keepScroll)
    local top = NS.Chrome.TitleBottom(frame) + NS.Chrome.StripOffset(frame.strip)
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
    P.SetScroll(keepScroll and state.offset or 0)   -- clamped to the new overflow
end

--- Draw the tooltip anew: the skin's shell and fonts, the title and gains, test mode's strip, the
--- shown blocks, the footer. NS.Broker.OnEnter shows it after; a fold's redraw (`keepScroll`,
--- NS.Broker.RedrawTooltip) keeps the body where it was scrolled.
function P.Fill(keepScroll)
    build()
    release()
    local S = NS.Skin
    S.Shell(frame)
    local title, gains = NS.Broker.Heading()
    frame.title:SetText(title)
    S.Text(frame.title, "title")
    frame.gains:SetText(gains)
    S.Text(frame.gains, "muted")
    layTitle()
    S.Text(frame.empty, "muted")
    if frame.strip then frame.strip:SetShown(NS.IsTestMode()) end
    frame.footer:SetText(NS.Broker.FooterText())
    S.Text(frame.footer, "muted")
    fit(layBody(), keepScroll)
end
