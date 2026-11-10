local addonName, NS = ...
-- modules/MainWindow.lua — the Skill Master window (standalone-windows, design §6.1, mockup "Main"):
-- its chrome (title band with lock, Expand all and Collapse all, journal, settings and close), the
-- optional summary strip (the character's class icon and name, then its level line), the
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
local TITLE_H, SUMMARY_H, FOOTER_H, MIN_H, SCROLLBAR_W = 28, 22, 22, 120, 16
W.CLASS_ICON = 14   -- the summary line's class icon, px

local frame          -- built on first show
local headerPool, rowPool
local headers = {}   -- [block id] = the header drawn this pass
local lastSig        -- the row set the current layout was built for

local COLUMN_GAP = 6   -- px between two columns of blocks

local function layoutSettings() return (NS.db and NS.db.profile.layout) or NS.defaults.profile.layout end
local function columns() return tonumber(layoutSettings().columns) == 2 and 2 or 1 end
local function columnWidth() return (tonumber(layoutSettings().width) or 440) - 4 - SCROLLBAR_W end

--- The scrolled body's width: Layout > Columns columns, each Window width's body wide.
function W.ContentWidth()
    local n = columns()
    return n * columnWidth() + (n - 1) * COLUMN_GAP
end

--- The window's width: the body, its scroll bar and its edges.
local function width() return W.ContentWidth() + 4 + SCROLLBAR_W end

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
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(self, true) end   -- none trails the drag
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    savePoint()
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(self, false) end  -- laid at the drop
end

-- ---------------------------------------------------------------------------------------------
-- Chrome
-- ---------------------------------------------------------------------------------------------

local function toggleLock() NS.SetByPath("locked", not NS.GetSetting("locked")) end
local function openJournal()
    if NS.Journal and NS.Journal.Toggle then NS.Journal.Toggle() end
end
local function openSettings() NS.OpenOptionsPanel() end
local function collapseAll() NS.Blocks:SetAllCollapsed(true) end
local function expandAll() NS.Blocks:SetAllCollapsed(false) end

local function controlLevel(b)
    if b then b:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CHROME) end
end

local function buildTitleControls()
    frame.close = NS.MakeCloseButton(frame, function() W.Hide() end)
    frame.lockButton = NS.Chrome.IconButton(frame, "lock", "L", toggleLock, L["Lock or unlock the window"])
    frame.journalButton = NS.Chrome.IconButton(frame, "document", "J", openJournal, L["Open the journal"])
    frame.settingsButton = NS.Chrome.IconButton(frame, "settings", "S", openSettings, L["Open the settings panel"])
    -- Expand all (outward arrows) and Collapse all (inward arrows), FB-16: on the lock's side, so
    -- three controls stand each side of the centered title and it keeps the band's middle at the
    -- narrowest Window width.
    frame.expandAllButton = NS.Chrome.IconButton(frame, "fullscreen-enter", "+", expandAll, L["Expand all blocks"])
    frame.collapseAllButton = NS.Chrome.IconButton(frame, "fullscreen-exit", "-", collapseAll,
        L["Collapse all blocks"])
    -- Each by name: frame.close is nil without the Core library, and ipairs would stop at that hole.
    controlLevel(frame.close)
    controlLevel(frame.lockButton)
    controlLevel(frame.expandAllButton)
    controlLevel(frame.collapseAllButton)
    controlLevel(frame.journalButton)
    controlLevel(frame.settingsButton)
    local left = { frame.lockButton, frame.expandAllButton, frame.collapseAllButton }
    local right = { frame.settingsButton, frame.journalButton }
    if frame.close then table.insert(right, 1, frame.close) end
    NS.Skin.Header(frame, { title = frame.title, align = "CENTER", left = left, right = right })
    if not frame.lockButton:GetPoint(1) then   -- no skin library: the same strip, anchored by hand
        frame.title:SetPoint("TOP", frame, "TOP", 0, -7)
        local prev
        for _, b in ipairs(left) do
            if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -5) end
            prev = b
        end
        prev = nil
        for _, b in ipairs(right) do
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0) else b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -5) end
            prev = b
        end
    end
end

local function buildSummary()
    -- The character (FB-17): its class icon, its name in its class color, then the level line.
    frame.summaryIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.summaryIcon:SetSize(W.CLASS_ICON, W.CLASS_ICON)
    frame.summaryName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summaryName:SetWordWrap(false)
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

--- A legend mark: a thin line drawn as the bar draws it (a tick 1 px, a marker 2 px) in the bar's
--- own color, then its label, laid right to left from `anchor`. Drawn, never typed: no face has to
--- carry a glyph for it (skinning-§4).
local function legendMark(parent, colorKey, w, label, anchor)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if anchor then fs:SetPoint("RIGHT", anchor, "LEFT", -10, 0) else fs:SetPoint("RIGHT", parent, "RIGHT", -10, 0) end
    fs:SetText(label)
    NS.Skin.Text(fs, "muted")
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(w, 10)
    t:SetPoint("RIGHT", fs, "LEFT", -4, 0)
    return { tex = t, key = colorKey }, fs, t
end

local function buildLegend()
    local f = CreateFrame("Frame", nil, frame)
    f:SetHeight(FOOTER_H)
    f:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    local t1, fs1 = swatch(f, "bonusTemp", L["temp bonus"])
    local t2, fs2 = swatch(f, "bonusPerm", L["permanent bonus"], fs1)
    local marker, fs3, tex3 = legendMark(f, "marker", 2, L["threshold"])
    local tick, fs4 = legendMark(f, "tick", 1, L["rank tier"], tex3)
    f.swatches = { { tex = t1, key = "bonusTemp" }, { tex = t2, key = "bonusPerm" }, marker, tick }
    f.marks = { fs4, fs3 }
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
    content:SetWidth(W.ContentWidth())
    content:SetHeight(1)
    scroll:SetScrollChild(content)
    -- One host per column; every header and row of a block is parented to its column's. A column
    -- draws nothing and takes no mouse, so the two need no level band (frame-layering-§3, siblings).
    frame.columns = {}
    for i = 1, 2 do
        local col = CreateFrame("Frame", nil, content)
        col:SetHeight(1)
        frame.columns[i] = col
    end
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
    -- The simulation's flavor of the same strip (kind "sim"), in the same place: the two modes
    -- are exclusive, so one marker shows at a time (preview-mode).
    frame.simStrip = NS.Widgets.TestStrip(frame, {
        text  = L["Simulation: a sample character plays scripted events."],
        owner = addonName,
        kind  = "sim",
        sim   = NS.Sim,
    })
    for _, s in ipairs({ frame.strip, frame.simStrip }) do
        s:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -TITLE_H)
        s:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -TITLE_H)
        s:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
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
    frame:SetSize(width(), MIN_H)
    frame:SetFrameStrata(LAYERS.STRATA.WINDOW)   -- ApplySettings then takes the player's (layout.strata)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", onDragStart)
    frame:SetScript("OnDragStop", onDragStop)
    -- A click raises the toplevel window: its overlays are re-leveled above its rows.
    if NS.SecureOverlay then NS.SecureOverlay:Follow(frame) end

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
    -- The gathering hint changes a row's height: turning it on or off is a new layout.
    sig[#sig + 1] = (NS.db and NS.db.profile.skills.helperHint) and "hint" or "-"
    return out, table.concat(sig, ","), total
end

local function bodyTop()
    local top = TITLE_H
    local shown = (frame.strip and frame.strip:IsShown()) or (frame.simStrip and frame.simStrip:IsShown())
    if shown then top = top + (NS.Widgets.TEST_STRIP and NS.Widgets.TEST_STRIP.HEIGHT or 18) end
    return top
end

local function placeSummary(top)
    local show = layoutSettings().summary ~= false
    local parts = { frame.summaryName, frame.summary, frame.summaryGains, frame.summaryAlert, frame.summaryRule }
    for _, fs in ipairs(parts) do fs:SetShown(show) end
    if not show then
        frame.summaryIcon:Hide()
        return top
    end
    frame.summaryIcon:ClearAllPoints()
    frame.summaryIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(top + 4))
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
    local c = NS.Preview.Character()   -- the sample character in test mode; NS.Compat's reads otherwise
    local who = L["Lv %d \194\183 %s %s"]:format(c.level or 0, c.race or "", c.class or "")
    local gains = NS.Blocks.SessionGains()
    local gainText = gains > 0 and L["+%d this session"]:format(gains) or ""
    return who, gainText, NS.Blocks.NextAlert(skills) or ""
end

--- The character the summary line names (FB-17): { name, classFile, icon }, the icon NS.Compat's
--- ClassIcon source ({ atlas } or { file, coords }) or nil. The sample character in test mode.
function W.Identity()
    local c = NS.Preview.Character()
    return { name = c.name or "", classFile = c.classFile, icon = NS.Compat.ClassIcon(c.classFile) }
end

local function paintClassIcon(tex, spec)
    if spec and spec.atlas then
        tex:SetAtlas(spec.atlas)
        tex:SetTexCoord(0, 1, 0, 1)
    elseif spec then
        tex:SetTexture(spec.file)
        tex:SetTexCoord(unpack(spec.coords))
    end
end

--- The class icon, the name in its class color, then `who` after a separator; each anchored
--- after the one before, the icon's place closed up when the client offers no icon.
local function drawIdentity(who)
    local id = W.Identity()
    local icon, name = frame.summaryIcon, frame.summaryName
    paintClassIcon(icon, id.icon)
    icon:SetShown(layoutSettings().summary ~= false and id.icon ~= nil)
    name:SetText(id.name)
    NS.Skin.Text(name, "body")
    local cc = type(RAID_CLASS_COLORS) == "table" and id.classFile and RAID_CLASS_COLORS[id.classFile]
    if cc then name:SetTextColor(cc.r, cc.g, cc.b) end
    name:ClearAllPoints()
    if id.icon then name:SetPoint("LEFT", icon, "RIGHT", 4, 0) else name:SetPoint("LEFT", icon, "LEFT", 0, 0) end
    frame.summary:ClearAllPoints()
    if id.name ~= "" then
        frame.summary:SetPoint("LEFT", name, "RIGHT", 4, 0)
        who = L["\194\183 %s"]:format(who)
    else
        frame.summary:SetPoint("LEFT", name, "LEFT", 0, 0)
    end
    frame.summary:SetText(who)
end

--- Anchor the column hosts across the body: `n` columns of `colW`, the rest hidden.
local function placeColumns(n, colW)
    for i, col in ipairs(frame.columns) do
        col:ClearAllPoints()
        col:SetPoint("TOPLEFT", frame.content, "TOPLEFT", (i - 1) * (colW + COLUMN_GAP), 0)
        col:SetWidth(colW)
        col:SetShown(i <= n)
    end
end

--- The column a block goes in: the shorter one so far, the first on a tie, so the order reads
--- left to right, top to bottom and the two stay near one height.
local function shortest(heights)
    local best = 1
    for i = 2, #heights do if heights[i] < heights[best] then best = i end end
    return best
end

local function layBlock(b, host, y)
    local h = NS.Blocks.AcquireHeader(headerPool, host)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -y)
    h:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -y)
    h:SetBlock(b.id, b.meta, b.collapsed, true)
    headers[b.id] = h
    y = y + NS.Blocks.HEADER_H
    if not b.collapsed then y = NS.Blocks.LayRows(b.entries, host, rowPool, y, "row", 0) end
    return y + (tonumber(layoutSettings().blockGap) or 0)
end

local function layOut(blocks)
    NS.Blocks.ReleaseHeaders(headerPool)
    NS.Rows.ReleaseAll(rowPool)
    for k in pairs(headers) do headers[k] = nil end
    local n = columns()
    placeColumns(n, columnWidth())
    local heights = {}
    for i = 1, n do heights[i] = 0 end
    for _, b in ipairs(blocks) do
        local i = shortest(heights)
        heights[i] = layBlock(b, frame.columns[i], heights[i])
    end
    local y = math.max(unpack(heights))
    for i = 1, n do frame.columns[i]:SetHeight(math.max(heights[i], 1)) end
    frame.content:SetHeight(math.max(y, 1))
    return y
end

local function fit(top, y)
    frame.scroll:ClearAllPoints()
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -(top + 1))
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(2 + SCROLLBAR_W), FOOTER_H + 2)
    local maxH = layoutSettings().maxHeight or 560
    frame:SetWidth(width())
    frame.content:SetWidth(W.ContentWidth())
    frame:SetHeight(math.max(MIN_H, math.min(top + y + FOOTER_H + 4, maxH)))
end

local function renderTitle(test, sim)
    if frame.strip then frame.strip:SetShown(test) end
    if frame.simStrip then frame.simStrip:SetShown(sim and not test) end
    local word = (test and not frame.strip and L["Test mode"])
        or (sim and not frame.simStrip and L["Simulation"]) or nil
    frame.title:SetText(word and L["%s - %s"]:format(L["Skill Master"], word) or L["Skill Master"])
end

--- The marker state, part of the layout signature: a strip shown or hidden moves the body.
local function markerSig(test, sim) return (test and "T" or "") .. (sim and "S" or "") end

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
    local test, sim = NS.IsTestMode(), NS.IsSimRunning and NS.IsSimRunning() or false
    renderTitle(test, sim)
    local skills, stats = NS.Blocks.Data()
    local blocks, sig, total = plan(skills, stats)
    sig = sig .. "|" .. markerSig(test, sim)
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
    drawIdentity(who)
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

--- The window's strata: the player's pick (Layout > Window strata), one of STRATA_CHOICES.
function W.Strata()
    local s = layoutSettings().strata
    for _, v in ipairs(LAYERS.STRATA_CHOICES) do if v == s then return s end end
    return LAYERS.STRATA.WINDOW
end

--- Re-apply the stored strata, scale, opacity, lock and position. The crafting overlays take the
--- new strata on the sync at the end (modules/SecureOverlay.lua reads the host's at each arm).
function W.ApplySettings()
    if not (frame and NS.db) then return end
    frame:SetFrameStrata(W.Strata())
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

--- The ONE toggle handler: `/sm toggle`, the launcher's Show window entry and the key binding.
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

--- Re-read state after a mode or data change. `relayout` forces the full layout pass (a layout
--- change or a skin switch: every pooled row and header is restyled, not only revalued).
function W.Refresh(relayout)
    if relayout then lastSig = nil end
    if W.IsShown() then W.Render() end
end

--- Stand-down: the window is hidden, and stays hidden (Show refuses).
function W.StandDown() W.Hide() end

--- Reset position (the Master-controls button).
function W.ResetPosition()
    if NS.db then NS.db.profile.window.point = false end
    if frame then applyPoint() end
end

-- The key bindings (launcher-§6), in Bindings.xml order: Show window first, then the Journal. The
-- button names are permanent: the client stores the player's key against them, so a rename unbinds
-- every player's key. Each is plain (no secure template), hidden, one toggle per press, and its click
-- runs that window's one toggle handler, which refuses while stood down exactly as its verb does.
W.TOGGLE_BUTTON = "SkillMasterToggleWindow"
W.JOURNAL_BUTTON = "SkillMasterToggleJournal"

local function bindingButton(name, onClick)
    local button = CreateFrame("Button", name, UIParent)   -- plain, not a secure template
    button:RegisterForClicks("AnyDown")                     -- one press, one toggle
    button:SetScript("OnClick", onClick)                    -- the handler itself
    button:Hide()
    return button
end

do
    -- the binding suites drive them by reference
    W.__toggleButton = bindingButton(W.TOGGLE_BUTTON, function() W.Toggle() end)
    W.__journalButton = bindingButton(W.JOURNAL_BUTTON, function() NS.Journal.Toggle() end)
    BINDING_HEADER_SKILLMASTER = NS.Constants.BRAND
    local window = ("CLICK %s:LeftButton"):format(W.TOGGLE_BUTTON)
    local journal = ("CLICK %s:LeftButton"):format(W.JOURNAL_BUTTON)
    rawset(_G, "BINDING_NAME_" .. window, L["Toggle skills window"])
    rawset(_G, "BINDING_NAME_" .. journal, L["Toggle journal"])
    NS.BINDINGS = {
        { command = window,  tooltip = L["Shows or hides the Skill Master window."] },
        { command = journal, tooltip = L["Shows or hides the Journal: the session log and your alts."] },
    }
end
