local addonName, NS = ...
-- modules/MainWindow.lua — the Skill Master window (standalone-windows, design §6.1, mockup "Main"):
-- its chrome (title band with lock, journal, settings and close), the optional summary strip, the
-- docked blocks in a scrolled body (NS.Blocks headers and NS.Rows rows), the bonus legend, the
-- test-mode strip, the drag-only position, the one toggle handler and the Show window key binding.
--
-- A render is a full layout only when the set of rows changed (blocks, collapse, keys); otherwise it
-- redraws values in place. The crafting rows' secure overlays (T3.3, modules/SecureOverlay.lua)
-- follow every layout through SecureOverlay:Sync, which defers itself in combat.

NS.MainWindow = {}
local W = NS.MainWindow
local L = NS.L
local Perf = NS.Perf
local LAYERS = NS.Constants.LAYERS

W.FRAME_NAME = "SkillMasterMainWindow"
W.SCROLL_NAME = "SkillMasterMainScroll"
local WIDTH, TITLE_H, SUMMARY_H, FOOTER_H, MIN_H, SCROLLBAR_W = 440, 28, 22, 22, 120, 16

local frame          -- built on first show
local headerPool, rowPool
local headers = {}   -- [block id] = the header drawn this pass
local lastSig        -- the row set the current layout was built for

local function layoutSettings() return NS.db.profile.layout end

local function savePoint()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then return end
    -- The window's drag-only geometry: this module is its one writer (docs/ARCHITECTURE.md).
    NS.db.profile.window.point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function applyPoint()
    local p = NS.db and NS.db.profile.window.point
    frame:ClearAllPoints()
    if type(p) == "table" then
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function onDragStart(self)
    if NS.GetSetting("locked") then return end
    self:StartMoving()
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    savePoint()
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end
end

-- ---------------------------------------------------------------------------------------------
-- Chrome
-- ---------------------------------------------------------------------------------------------

local function toggleLock() NS.SetByPath("locked", not NS.GetSetting("locked")) end
local function openJournal()
    if NS.Journal and NS.Journal.Toggle then NS.Journal.Toggle() end
end
local function openSettings() NS.OpenOptionsPanel() end

local function controlLevel(b)
    if b then b:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CHROME) end
end

local function buildTitleControls()
    frame.close = NS.MakeCloseButton(frame, function() W.Hide() end)
    frame.lockButton = NS.Chrome.IconButton(frame, "lock", "L", toggleLock, L["Lock or unlock the window"])
    frame.journalButton = NS.Chrome.IconButton(frame, "document", "J", openJournal, L["Open the journal"])
    frame.settingsButton = NS.Chrome.IconButton(frame, "settings", "S", openSettings, L["Open the settings panel"])
    for _, b in ipairs({ frame.close, frame.lockButton, frame.journalButton, frame.settingsButton }) do controlLevel(b) end
    local right = { frame.settingsButton, frame.journalButton }
    if frame.close then table.insert(right, 1, frame.close) end
    NS.Skin.Header(frame, { title = frame.title, align = "CENTER", left = { frame.lockButton }, right = right })
    if not frame.lockButton:GetPoint(1) then   -- no skin library: the same strip, anchored by hand
        frame.title:SetPoint("TOP", frame, "TOP", 0, -7)
        frame.lockButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5)
        local prev
        for _, b in ipairs(right) do
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5) end
            prev = b
        end
    end
end

local function buildSummary()
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summaryGains = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summaryAlert = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summaryAlert:SetJustifyH("RIGHT")
    frame.summaryAlert:SetWordWrap(false)
    NS.Skin.Text(frame.summary, "body")
    NS.Skin.Text(frame.summaryGains, "muted")
    NS.Skin.Text(frame.summaryAlert, "accent")
    frame.summaryRule = frame:CreateTexture(nil, "BORDER")
    frame.summaryRule:SetHeight(1)
    NS.Skin.Divider(frame.summaryRule)
end

local function swatch(parent, colorKey, label, anchor)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(10, 8)
    if anchor then t:SetPoint("LEFT", anchor, "RIGHT", 10, 0) else t:SetPoint("LEFT", parent, "LEFT", 10, 0) end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", t, "RIGHT", 4, 0)
    fs:SetText(label)
    NS.Skin.Text(fs, "muted")
    return t, fs, colorKey
end

local function paintLegend()
    local style = NS.Bar.ResolveStyle("row")
    for _, sw in ipairs(frame.legend.swatches) do
        local c = style[sw.key]
        if c then sw.tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    end
end

local function buildLegend()
    local f = CreateFrame("Frame", nil, frame)
    f:SetHeight(FOOTER_H)
    f:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    local t1, fs1 = swatch(f, "bonusTemp", L["temp bonus"])
    local t2, fs2 = swatch(f, "bonusPerm", L["permanent bonus"], fs1)
    f.swatches = { { tex = t1, key = "bonusTemp" }, { tex = t2, key = "bonusPerm" } }
    f.marks = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.marks:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    f.marks:SetText(L["\226\148\130 rank tier \194\183 \226\150\143 threshold"])
    NS.Skin.Text(f.marks, "muted")
    f.rule = f:CreateTexture(nil, "BORDER")
    f.rule:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.rule:SetHeight(1)
    NS.Skin.Divider(f.rule)
    frame.legend = f
    frame.legendText = { fs1, fs2 }
    paintLegend()
end

local function buildBody()
    local scroll = CreateFrame("ScrollFrame", W.SCROLL_NAME, frame, "UIPanelScrollFrameTemplate")
    scroll:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(WIDTH - 4 - SCROLLBAR_W)
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnVerticalScroll", function()
        if NS.SecureOverlay then NS.SecureOverlay:Sync() end
    end)
    local bar = scroll.ScrollBar or _G[W.SCROLL_NAME .. "ScrollBar"]
    if bar then NS.Skin.ScrollBar(bar) end
    frame.scroll, frame.content = scroll, content
    headerPool, rowPool = NS.Blocks.NewHeaderPool(), NS.Rows.NewPool()
end

local function buildChrome()
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetText(L["Skill Master"])
    NS.Skin.Shell(frame)
    NS.Skin.Text(frame.title, "title")
    buildTitleControls()

    -- The test-mode marker (preview-mode): a localized text band, readable without hovering.
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
    buildSummary()
    buildBody()
    buildLegend()
end

local function onHide()
    -- Popups close with their opener (frame-layering-§4); the overlays follow their rows.
    if NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end
    if NS.TrainerPopup then NS.TrainerPopup.Hide() end
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end
    NS.Blocks.UpdateSpeedWatch()
end

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", W.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, MIN_H)
    frame:SetFrameStrata(LAYERS.STRATA.WINDOW)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", onDragStart)
    frame:SetScript("OnDragStop", onDragStop)

    buildChrome()

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.empty:SetText(L["No skills to show yet."])
    NS.Skin.Text(frame.empty, "muted")

    -- Escape closes it, as every standalone window does.
    UISpecialFrames[#UISpecialFrames + 1] = W.FRAME_NAME
    frame:Hide()
    frame:SetScript("OnHide", onHide)
    W.ApplySettings()
    return frame
end

-- ---------------------------------------------------------------------------------------------
-- The body
-- ---------------------------------------------------------------------------------------------

local function plan(skills, stats)
    local out, sig, total = {}, {}, 0
    for _, id in ipairs(NS.Blocks.Docked()) do
        local entries = NS.Blocks.Entries(id, skills, stats)
        if #entries > 0 then
            local collapsed = NS.Blocks.Settings(id).collapsed and true or false
            out[#out + 1] = { id = id, entries = entries, collapsed = collapsed, meta = NS.Blocks.Meta(id, entries) }
            sig[#sig + 1] = id .. (collapsed and "-" or "+")
            if not collapsed then
                for _, r in ipairs(entries) do sig[#sig + 1] = r.entry.key end
            end
            total = total + #entries
        end
    end
    return out, table.concat(sig, ","), total
end

local function bodyTop()
    local top = TITLE_H
    if frame.strip and frame.strip:IsShown() then top = top + (NS.Widgets.TEST_STRIP and NS.Widgets.TEST_STRIP.HEIGHT or 18) end
    return top
end

local function placeSummary(top)
    local show = layoutSettings().summary ~= false
    for _, fs in ipairs({ frame.summary, frame.summaryGains, frame.summaryAlert, frame.summaryRule }) do fs:SetShown(show) end
    if not show then return top end
    frame.summary:ClearAllPoints()
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(top + 5))
    frame.summaryGains:ClearAllPoints()
    frame.summaryGains:SetPoint("LEFT", frame.summary, "RIGHT", 10, 0)
    frame.summaryAlert:ClearAllPoints()
    frame.summaryAlert:SetPoint("LEFT", frame.summaryGains, "RIGHT", 10, 0)
    frame.summaryAlert:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    frame.summaryRule:ClearAllPoints()
    frame.summaryRule:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -(top + SUMMARY_H))
    frame.summaryRule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -(top + SUMMARY_H))
    return top + SUMMARY_H
end

--- The summary strip's three parts: "Lv 22 · Dwarf Hunter", the session gains, the next alert.
function W.SummaryParts(skills)
    local level = type(UnitLevel) == "function" and UnitLevel("player") or 0
    local race = type(UnitRace) == "function" and UnitRace("player") or ""
    local class = type(UnitClass) == "function" and UnitClass("player") or ""
    local who = L["Lv %d \194\183 %s %s"]:format(level or 0, race or "", class or "")
    local gains = NS.Blocks.SessionGains()
    local gainText = gains > 0 and L["\226\150\178 +%d this session"]:format(gains) or ""
    return who, gainText, NS.Blocks.NextAlert(skills) or ""
end

local function layOut(blocks)
    NS.Blocks.ReleaseHeaders(headerPool)
    NS.Rows.ReleaseAll(rowPool)
    for k in pairs(headers) do headers[k] = nil end
    local y = 0
    for _, b in ipairs(blocks) do
        local h = NS.Blocks.AcquireHeader(headerPool, frame.content)
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -y)
        h:SetPoint("TOPRIGHT", frame.content, "TOPRIGHT", 0, -y)
        h:SetBlock(b.id, b.meta, b.collapsed, true)
        headers[b.id] = h
        y = y + NS.Blocks.HEADER_H
        if not b.collapsed then y = NS.Blocks.LayRows(b.entries, frame.content, rowPool, y, "row", 0) end
    end
    frame.content:SetHeight(math.max(y, 1))
    return y
end

local function fit(top, y)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -(top + 1))
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(2 + SCROLLBAR_W), FOOTER_H + 2)
    local maxH = layoutSettings().maxHeight or 560
    frame:SetHeight(math.max(MIN_H, math.min(top + y + FOOTER_H + 4, maxH)))
end

local function renderTitle(test)
    if frame.strip then
        frame.strip:SetShown(test)
        frame.title:SetText(L["Skill Master"])
    else
        frame.title:SetText(test and (L["Skill Master"] .. " - " .. L["Test mode"]) or L["Skill Master"])
    end
end

--- Redraw the rows' values in place (a bonus tick, a stat or a rank change): no anchor moves.
function W.RefreshValues()
    if not (frame and frame:IsShown()) then return end
    NS.Rows.RefreshValues(rowPool, NS.Blocks.Lookup(NS.Blocks.Data()))
end

--- The window's body, one pass: a full layout when the row set changed, else values in place. The
--- rows are plain frames and no secure frame is anchored to them (the crafting overlays sit on
--- UIParent at absolute coordinates), so a layout is safe in combat; the overlays follow it on the
--- next out-of-combat sync (modules/SecureOverlay.lua).
function W.Render()
    if not frame then return end
    local t0 = Perf.on and debugprofilestop()
    renderTitle(NS.IsTestMode())
    local skills, stats = NS.Blocks.Data()
    local blocks, sig, total = plan(skills, stats)
    local SO = NS.SecureOverlay
    if sig == lastSig then
        W.RefreshValues()
    else
        local top = placeSummary(bodyTop())
        local y = layOut(blocks)
        fit(top, y)
        lastSig = sig
        if SO then SO:Sync() end
    end
    frame.empty:SetShown(total == 0)
    local who, gains, alert = W.SummaryParts(skills)
    frame.summary:SetText(who)
    frame.summaryGains:SetText(gains)
    frame.summaryAlert:SetText(alert)
    paintLegend()
    NS.Blocks.UpdateSpeedWatch()
    if t0 then Perf.Note("windowRender", debugprofilestop() - t0) end
end

--- The rows drawn this pass (the suites and the overlay sync read them).
function W.Rows() return rowPool and rowPool.active or {} end

--- The header drawn for block `id` this pass, or nil.
function W.HeaderFor(id) return headers[id] end

--- Re-apply the stored scale, opacity, lock and position.
function W.ApplySettings()
    if not (frame and NS.db) then return end
    frame:SetScale(NS.GetSetting("scale") or 1)
    frame:SetAlpha(NS.GetSetting("alpha") or 1)
    local locked = NS.GetSetting("locked")
    frame:SetMovable(not locked)
    NS.Chrome.SetIcon(frame.lockButton, locked and "lock" or "unlock", locked and "L" or "U")
    applyPoint()
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end
end

--- The window frame, or nil before the first show (the suites and the skin-switch test read it).
function W.Frame() return frame end

function W.IsShown() return frame ~= nil and frame:IsShown() == true end

--- Show the window. Refused while stood down, through the one refusal helper.
function W.Show()
    local refusal = NS.StoodDownRefusal()
    if refusal then NS.Print(refusal) return false end
    build():Show()
    lastSig = nil
    W.Render()
    return true
end

function W.Hide()
    if not frame then return end
    frame:Hide()
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end   -- OnHide does too; an Escape reaches only that
end

--- The ONE toggle handler: `/skm toggle`, the launcher's Show window entry and the key binding.
function W.Toggle()
    if W.IsShown() then W.Hide() return false end
    return W.Show()
end

--- The docked skill block that shows skill `key`, or nil (detached, hidden or not a skill).
local function dockedBlockOf(key)
    local skills = NS.Blocks.Data()
    for _, id in ipairs(NS.Blocks.Docked()) do
        for _, r in ipairs(NS.Blocks.Entries(id, skills, nil)) do
            if r.kind == "skill" and r.entry.key == key then return id end
        end
    end
    return nil
end

local function rowFor(key)
    for _, row in ipairs(W.Rows()) do
        if row.kind == "skill" and row.entry and row.entry.key == key then return row end
    end
    return nil
end

--- Show the window scrolled so skill `key`'s row is in view: the broker's crafting rows (design
--- §6.5), which never cast. A collapsed block holding it is expanded first (queued in combat, as
--- every collapse is). A row in a detached block, or none, still shows the window. Answers whether
--- the row was brought into view.
function W.ShowAndScrollTo(key)
    local id = dockedBlockOf(key)
    if id and NS.Blocks.Settings(id).collapsed then NS.Blocks:SetCollapsed(id, false) end
    if not (W.IsShown() or W.Show()) then return false end
    W.Render()
    local row = rowFor(key)
    if not row then return false end
    local offset = math.max(0, (row.layY or 0) - NS.Blocks.HEADER_H)   -- its block's header stays in view
    local range = tonumber(frame.scroll:GetVerticalScrollRange())
    if range then offset = math.min(offset, math.max(range, 0)) end
    frame.scroll:SetVerticalScroll(offset)
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end   -- the overlays follow the scroll
    return true
end

--- Re-read state after a mode or data change.
function W.Refresh()
    if W.IsShown() then W.Render() end
end

--- Stand-down: the window is hidden, and stays hidden (Show refuses).
function W.StandDown() W.Hide() end

--- Reset position (the Master-controls button).
function W.ResetPosition()
    if NS.db then NS.db.profile.window.point = false end
    if frame then applyPoint() end
end

-- The Show window key binding (launcher-§6). The button name is permanent: the client stores the
-- player's key against it, so a rename unbinds every player's key.
W.TOGGLE_BUTTON = "SkillMasterToggleWindow"
do
    local button = CreateFrame("Button", W.TOGGLE_BUTTON, UIParent)   -- plain, not a secure template
    button:RegisterForClicks("AnyDown")                               -- one press, one toggle
    button:SetScript("OnClick", function() W.Toggle() end)            -- the handler itself
    button:Hide()
    W.__toggleButton = button   -- the binding suite drives it by reference
    BINDING_HEADER_SKILLMASTER = NS.Constants.BRAND
    local command = ("CLICK %s:LeftButton"):format(W.TOGGLE_BUTTON)
    rawset(_G, "BINDING_NAME_" .. command, L["Toggle the Skill Master window"])
    NS.BINDINGS = { { command = command, tooltip = L["Shows or hides the Skill Master window."] } }
end
