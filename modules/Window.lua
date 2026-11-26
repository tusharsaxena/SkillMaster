local addonName, NS = ...
-- modules/Window.lua — the family window factory (item SMW-04 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md; the spec's "Families and windows"). One
-- window per family of defaults/Families.lua, each its own instance of what was the one Skill Master
-- window: its chrome (title band with lock, journal, settings, one Expand / Collapse all and close), the
-- optional summary strip (the character's class icon and name, then its level line), its family's
-- docked blocks in a scrolled body (NS.Blocks headers and NS.Rows rows), the bonus legend on the
-- window's footer for the families whose bars carry bonuses (LibKa0s Widgets' Footer, FOOTER.HEIGHT;
-- standalone-windows, *The footer*), the test and sim strips docked under the title bar (Widgets'
-- `dock = "title"`, preview-mode's *Where the strip sits*), the drag-only position, the corner resize grip
-- (AF-SM-RESIZE: NS.Chrome.MakeResizable, its size written to the window's Width and Height on the
-- release, hidden and refused while Locked) and its one toggle handler.
--
-- Each instance keeps its own frame, pools, headers and layout signature; its settings are
-- profile.windows.<family> (defaults/Profile.lua), its rows on Layout > Window. The Professions window
-- keeps the old window's frame name, so modules/MainWindow.lua (NS.MainWindow) is a thin shim over it.
--
-- NS.Windows.New(fid) -> W (once per family, at load) / .Get(fid) / .Each() / .Settings(fid) / .Point(fid)
--   / .EmptyText(fid) / .HasLegend(fid) / .ForBlock(id) (the window a docked block draws in) / .Toggle(fid)
--   / .RefreshAll(relayout) / .RefreshValuesAll() / .ApplyAll() / .HideAll() / .StandDownAll()
--   / .ResetPositions() / .AnyShown() / .AllRows() (every shown window's rows, the overlay sync's)
--   / .ShowAndScrollTo(key) / .TopStrata() (the highest window strata, the trainer popup's)
--
-- A render is a full layout only when the set of rows changed (blocks, collapse, keys); otherwise it
-- redraws values in place. The crafting rows' secure overlays (T3.3, modules/SecureOverlay.lua)
-- follow every layout through SecureOverlay:Sync, which defers itself in combat.

NS.Windows = {}
local Windows = NS.Windows
local L = NS.L
local Perf = NS.Perf
local LAYERS = NS.Constants.LAYERS

local SUMMARY_H, MIN_H, SCROLLBAR_W = 22, 120, 16
-- The footer's height, read where the library publishes it (NS.Chrome.FooterHeight: FOOTER.HEIGHT,
-- 24 px under every skin; standalone-windows, *Window chrome geometry*), the same figure with no library.
local function footerH() return NS.Chrome.FooterHeight() end
-- What the scroll bar takes past the body: UIPanelScrollFrameTemplate hangs its 16 px bar 6 px off
-- the scroll frame's right edge, and 4 px keep it off the window's border. The window grows by this
-- gutter rather than the body shrinking, so the rows stay Window width's (feedback round 2).
local SCROLL_GUTTER = 6 + SCROLLBAR_W + 4
local COLUMN_GAP = 6   -- px between two columns of blocks
local floor, max, min = math.floor, math.max, math.min

local byFamily = {}   -- [fid] = W

-- ---------------------------------------------------------------------------------------------
-- The registry's reads: each window's settings, its first-time place, its empty line
-- ---------------------------------------------------------------------------------------------

--- Family `fid`'s window settings (profile.windows.<fid>), the defaults' before the store exists.
function Windows.Settings(fid)
    local p = NS.db and NS.db.profile.windows
    return (p and p[fid]) or NS.defaults.profile.windows[fid]
end

-- Where a window with no drop point opens (the spec's call: the old window became Professions, and the
-- others start next to it the first time, stacked down and to the right, STACK px apart): the
-- Professions window's point, else the screen's center, offset by the family's place in the order.
local STACK = 30
local ORDER = {}
for i, fid in ipairs(NS.FAMILY_ORDER) do ORDER[fid] = i end

--- Window `fid`'s point: { point, relPoint, x, y }, its own drop point or its first-time place.
function Windows.Point(fid)
    local own = Windows.Settings(fid).point
    if type(own) == "table" then return own end
    local base = Windows.Settings("professions").point
    if type(base) ~= "table" then base = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 } end
    local step = ((ORDER[fid] or 1) - 1) * STACK
    return { point = base.point, relPoint = base.relPoint or base.point, x = (base.x or 0) + step, y = (base.y or 0) - step }
end

-- The empty window's line, by its family's data provider.
local EMPTY = { skills = L["No skills to show yet."], stats = L["No stats to show yet."] }
function Windows.EmptyText(fid)
    local fam = NS.Families[fid]
    return EMPTY[fam and fam.source] or L["Nothing to show yet."]
end

--- Whether family `fid`'s window draws the bonus legend (its bars carry temporary and permanent bonuses).
function Windows.HasLegend(fid)
    local fam = NS.Families[fid]
    return fam ~= nil and (fam.source == "skills" or fam.source == "stats")
end

-- ---------------------------------------------------------------------------------------------
-- One window
-- ---------------------------------------------------------------------------------------------

local function cap(s) return (s:gsub("^%l", string.upper)) end

--- Build family `fid`'s window object (its frame waits for the first show). Called once per family.
function Windows.New(fid)
    local fam = NS.Families[fid]
    assert(fam, "no family " .. tostring(fid))
    local W = { family = fid, CLASS_ICON = 14 }   -- the summary line's class icon, px
    byFamily[fid] = W
    -- The Professions window keeps the old window's names (a skin or a player's macro may know them).
    local frameName = fid == "professions" and "SkillMasterMainWindow" or ("SkillMaster" .. cap(fid) .. "Window")
    W.FRAME_NAME = frameName
    W.SCROLL_NAME = fid == "professions" and "SkillMasterMainScroll" or ("SkillMaster" .. cap(fid) .. "Scroll")
    local PATH = "windows." .. fid .. "."   -- its Layout > Window rows

    local frame          -- built on first show
    local headerPool, rowPool
    local headers = {}   -- [block id] = the header drawn this pass
    local lastSig        -- the row set the current layout was built for

    local sizing = false   -- the grip is being dragged: only the cheap pass lays the body out

    local function winSettings() return Windows.Settings(fid) end
    local function blockGap()
        local layout = (NS.db and NS.db.profile.layout) or NS.defaults.profile.layout
        return tonumber(layout.blockGap) or 0
    end
    local function columns() return tonumber(winSettings().columns) == 2 and 2 or 1 end
    local function columnWidth() return (tonumber(winSettings().width) or 420) - 4 - SCROLLBAR_W end

    --- The scrolled body's width: Layout > Columns columns, each Window width's body wide.
    function W.ContentWidth()
        local n = columns()
        return n * columnWidth() + (n - 1) * COLUMN_GAP
    end

    --- The window's width: the body, its scroll bar's whole gutter and its edges.
    local function width() return W.ContentWidth() + 4 + SCROLL_GUTTER end

    -- ---------------------------------------------------------------------------------------------
    -- The resize grip (AF-SM-RESIZE; standalone-windows, Resizing). The grip sets the two Layout
    -- settings the window's size already comes from: Window width (one column's, so a frame width maps
    -- back through the column count) and Window height. Its bounds are those rows' own range, never
    -- past the screen. While it is dragged only the cheap pass runs (W.Relayout: the columns and the
    -- body take the new width, once per rendered frame); on the release the two settings are written
    -- through the seam in one bulk bracket, whose one coalesced LAYOUT_CHANGED is the one full redraw.
    -- ---------------------------------------------------------------------------------------------


    -- A Layout row's range (settings/Layout.lua), read from the schema so the grip and the slider agree.
    local function rowRange(path, lo, hi)
        local S = NS.SchemaRuntime
        local row = S and S.FindRow and S.FindRow(path)
        return (row and tonumber(row.min)) or lo, (row and tonumber(row.max)) or hi
    end

    -- `v` snapped to the row's step grid (from its minimum), so the slider holds a value it can step
    -- from and the first nudge never jumps the window (a row with no step rounds to the pixel).
    local function snapToStep(path, v, lo)
        local S = NS.SchemaRuntime
        local row = S and S.FindRow and S.FindRow(path)
        local step = row and tonumber(row.step)
        if not (step and step > 0) then return floor(v + 0.5) end
        return lo + floor((v - lo) / step + 0.5) * step
    end

    -- The frame width a Window width of `colSetting` gives, and the Window width a frame width maps to.
    local function widthFor(colSetting)
        local n = columns()
        return n * (colSetting - 4 - SCROLLBAR_W) + (n - 1) * COLUMN_GAP + 4 + SCROLL_GUTTER
    end
    local function bodyColumnFor(w)
        local n = columns()
        return (w - 4 - SCROLL_GUTTER - (n - 1) * COLUMN_GAP) / n
    end

    local function screenSize()
        local sw = UIParent and tonumber(UIParent:GetWidth())
        local sh = UIParent and tonumber(UIParent:GetHeight())
        -- Resize bounds are in the frame's own units: Master scale above 1 shrinks the screen in them.
        local scale = frame and type(frame.GetScale) == "function" and tonumber(frame:GetScale())
        if not (scale and scale > 0) then scale = 1 end
        sw = (sw and sw > 0) and sw / scale or nil
        sh = (sh and sh > 0) and sh / scale or nil
        return sw, sh
    end

    --- Re-apply the grip's bounds: Window width's and Window height's range at the current column
    --- count, capped at the screen (in the frame's units, so at its Master scale). A full layout and
    --- W.ApplySettings run it, so a Columns or Master scale change moves them.
    local function applyBounds()
        if not (frame and frame.resizeGrip) then return end
        local wLo, wHi = rowRange(PATH .. "width", 320, 800)
        local hLo, hHi = rowRange(PATH .. "maxHeight", 200, 1200)
        local sw, sh = screenSize()
        local minW, maxW = widthFor(wLo), widthFor(wHi)
        if sw then maxW = max(min(maxW, sw), minW) end
        if sh then hHi = max(min(hHi, sh), hLo) end
        if type(frame.SetResizeBounds) == "function" then
            frame:SetResizeBounds(minW, hLo, maxW, hHi)
        else
            if type(frame.SetMinResize) == "function" then frame:SetMinResize(minW, hLo) end
            if type(frame.SetMaxResize) == "function" then frame:SetMaxResize(maxW, hHi) end
        end
    end

    local function savePoint()
        local point, _, relPoint, x, y = frame:GetPoint(1)
        if type(point) ~= "string" then return end
        -- The window's drag-only geometry: this module is its one writer (docs/ARCHITECTURE.md).
        NS.db.profile.windows[fid].point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end

    local function applyPoint()
        local p = Windows.Point(fid)
        frame:ClearAllPoints()
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
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
    --- Whether any docked block that draws rows is expanded: the one Expand / Collapse all control
    --- then collapses, else it expands (the two are one control, feedback round 2).
    function W.AnyExpanded()
        local skills, stats = NS.Blocks.Data()
        for _, id in ipairs(NS.Blocks.DockedIn(fid)) do
            if not NS.Blocks.Settings(id).collapsed and #NS.Blocks.Entries(id, skills, stats) > 0 then return true end
        end
        return false
    end

    local function toggleAll() NS.Blocks:SetCollapsedFor(NS.Blocks.DockedIn(fid), W.AnyExpanded()) end

    --- Show the control as what a click does now: Collapse all (inward arrows) while a block is open,
    --- Expand all (outward arrows) once every one is collapsed.
    local function paintToggleAll()
        local b = frame and frame.toggleAllButton
        if not b then return end
        local collapse = W.AnyExpanded()
        NS.Chrome.SetIcon(b, collapse and "fullscreen-exit" or "fullscreen-enter", collapse and "-" or "+")
        NS.Chrome.SetTip(b, collapse and L["Collapse all blocks"] or L["Expand all blocks"])
        b.collapses = collapse
    end

    local function buildTitleControls()
        -- The title-bar marks on LibKa0s Widgets' HeaderButtons (AD-86-SM, LibKa0s#86; standalone-windows,
        -- *Title-bar controls*): left to right the lock, the journal and the one Expand / Collapse all
        -- control (FB-16: it shows what a click does now, paintToggleAll, never both at once), then
        -- settings, then the close in the corner. The lock stands with the other marks at the top right
        -- (owner feedback round 3); Expand / Collapse all moves inward of settings, the rule's order.
        local hb = NS.Chrome.TitleMarks(frame, {
            close = function() W.Hide() end,
            settingsTip = L["Open the settings panel"],
            level = LAYERS.LEVEL.CHROME,
            extras = {
                { key = "lock", icon = "lock", glyph = "L", onClick = toggleLock, tip = L["Lock or unlock the window"] },
                { key = "journal", icon = "document", glyph = "J", onClick = openJournal, tip = L["Open the journal"] },
                { key = "toggleAll", icon = "fullscreen-exit", glyph = "-", onClick = toggleAll, tip = L["Collapse all blocks"] },
            },
        })
        frame.close, frame.settingsButton = hb.close, hb.settings
        frame.lockButton, frame.journalButton = hb.extras.lock, hb.extras.journal
        frame.toggleAllButton = hb.extras.toggleAll
        NS.Skin.Header(frame, { title = frame.title, align = "CENTER", right = hb.right, gap = select(2, NS.Chrome.HeaderPitch()) })
        if not frame.title:GetPoint(1) then frame.title:SetPoint("TOP", frame, "TOP", 0, -7) end
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
        if not frame.legend.markerTex then return end   -- a window with no legend (Windows.HasLegend)
        local style = NS.BarStyle.Resolve("row")
        -- The threshold entry only while the window's bars draw thresholds (owner feedback round 6, R6-4).
        local marks = style.showMarkers == true
        frame.legend.markerTex:SetShown(marks)
        frame.legend.markerLabel:SetShown(marks)
        for _, sw in ipairs(frame.legend.swatches) do
            local c = NS.BarStyle.Color(style[sw.key])   -- a token name or the player's color
            if c then sw.tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
        end
    end

    --- A legend mark: a thin line drawn as the bar draws it (a marker, 2 px) in the bar's
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

    -- The window's footer (AD-89-SM, LibKa0s#89): NS.Chrome.Footer, the library's Footer, no fill, its
    -- hairline in the skin's `divider` along its top, FOOTER.HEIGHT tall across the window's bottom edge,
    -- painted for this addon's skin owner. Its words are the legend's, laid over it; its own left and right
    -- lines stay empty. With no library, a bare frame of the same height and no hairline.
    local function buildLegend()
        local f = NS.Chrome.Footer(frame, { grip = true })   -- its right side clears the grip's corner
        frame.legend = f
        if not Windows.HasLegend(fid) then   -- the footer stays: the grip sits in its corner
            f.swatches, f.marks, frame.legendText = {}, {}, {}
            return
        end
        local t1, fs1 = swatch(f, "bonusTemp", L["temp bonus"])
        local t2, fs2 = swatch(f, "bonusPerm", L["permanent bonus"], fs1)
        local marker, fs3 = legendMark(f, "marker", 2, L["threshold"])
        f.swatches = { { tex = t1, key = "bonusTemp" }, { tex = t2, key = "bonusPerm" }, marker }
        f.marks = { fs3 }
        f.markerTex, f.markerLabel = marker.tex, fs3
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
        frame.title:SetText(fam.title)
        NS.Skin.Shell(frame)
        NS.Skin.Text(frame.title, "title")
        buildTitleControls()
        frame.titleBar = NS.Chrome.TitleBar(frame)

        -- The test-mode marker (preview-mode): a localized text band, readable without hovering, docked
        -- by the library directly under the title bar, full width (AD-88-SM, LibKa0s#88).
        frame.strip = NS.Widgets.TestStrip(frame, {
            text  = L["Test mode: the skills shown are sample data."],
            owner = addonName,
            onEnd = function() NS.ToggleTestMode() end,
            dock = "title", titleBar = frame.titleBar, window = frame,
        })
        -- The simulation's flavor of the same strip (kind "sim"), at the same dock: the two modes
        -- are exclusive, so one marker shows at a time (preview-mode).
        frame.simStrip = NS.Widgets.TestStrip(frame, {
            text  = L["Simulation: a sample character plays scripted events."],
            owner = addonName,
            kind  = "sim",
            sim   = NS.Sim,
            dock = "title", titleBar = frame.titleBar, window = frame,
        })
        for _, s in ipairs({ frame.strip, frame.simStrip }) do
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

    -- The release: Window width and Window height take the dragged size, each through the seam
    -- (architecture-§5), in one bulk bracket so the redraw they cause is one coalesced LAYOUT_CHANGED.
    local function storeSize(w, h)
        if not (NS.db and tonumber(w) and tonumber(h)) then return end
        local wLo, wHi = rowRange(PATH .. "width", 320, 800)
        local hLo, hHi = rowRange(PATH .. "maxHeight", 200, 1200)
        local colSetting = max(wLo, min(wHi, snapToStep(PATH .. "width", bodyColumnFor(w) + 4 + SCROLLBAR_W, wLo)))
        local height = max(hLo, min(hHi, snapToStep(PATH .. "maxHeight", h, hLo)))
        local function write()
            if colSetting ~= winSettings().width then NS.SetByPath(PATH .. "width", colSetting) end
            if height ~= winSettings().maxHeight then NS.SetByPath(PATH .. "maxHeight", height) end
        end
        local S = NS.SchemaRuntime
        if S and S.BulkRun then S.BulkRun("resize", "windows." .. fid, write) else write() end
    end

    local function endSizing()
        sizing = false
        if NS.SecureOverlay then NS.SecureOverlay:SetMoving(frame, false) end   -- laid at the release
    end

    local function makeResizable()
        NS.Chrome.MakeResizable(frame, {
            layout = function(w, h) W.Relayout(w, h) end,
            redraw = endSizing,
            -- The grab re-anchored the frame by its top-left, so the drop point is saved with the size.
            save = function(w, h)
                storeSize(w, h)
                savePoint()
            end,
            -- Asked at every grab, before sizing starts: Locked refuses, then the top-left pin.
            canResize = function()
                if NS.GetSetting("locked") then return false end
                NS.Chrome.PinTopLeft(frame)
                sizing = true
                if NS.SecureOverlay then NS.SecureOverlay:SetMoving(frame, true) end   -- none trails it
                return true
            end,
        })
        applyBounds()
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
        makeResizable()

        frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
        frame.empty:SetText(Windows.EmptyText(fid))
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
        -- `laid` counts the blocks laid out, not their rows: a block its filter emptied shows its
        -- header and note, so it is content and the window's empty message stays down (review, R5-followups).
        local out, sig, laid = {}, {}, 0
        for _, id in ipairs(NS.Blocks.DockedIn(fid)) do
            local entries, removed = NS.Blocks.Entries(id, skills, stats)
            -- A block its filter emptied keeps its header and a muted line (round 5, R5-10).
            local note = NS.Blocks.FilterNote(entries, removed)
            if #entries > 0 or note then
                local collapsed = NS.Blocks.Settings(id).collapsed and true or false
                out[#out + 1] = { id = id, entries = entries, collapsed = collapsed, note = note }
                sig[#sig + 1] = id .. (collapsed and "-" or "+") .. NS.Blocks.SortOf(id) .. NS.Blocks.FilterOf(id)
                    .. (note and "!" or "")
                if not collapsed then
                    for _, r in ipairs(entries) do sig[#sig + 1] = r.entry.key end
                end
                laid = laid + 1
            end
        end
        -- The gathering hint changes a row's height: turning it on or off is a new layout.
        sig[#sig + 1] = (NS.db and NS.db.profile.skills.helperHint) and "hint" or "-"
        return out, table.concat(sig, ","), laid
    end

    --- Where the body starts under the window's top: the title band's bottom, moved down by the strip in
    --- force's BodyOffset (0 with none showing).
    local function bodyTop()
        local C = NS.Chrome
        return C.TitleBottom(frame) + math.max(C.StripOffset(frame.strip), C.StripOffset(frame.simStrip))
    end

    local function placeSummary(top)
        local show = winSettings().summary ~= false
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
        icon:SetShown(winSettings().summary ~= false and id.icon ~= nil)
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
        h:SetBlock(b.id, b.collapsed, true)
        headers[b.id] = h
        y = y + NS.Blocks.HEADER_H
        if not b.collapsed then
            y = NS.Blocks.LayRows(b.entries, host, rowPool, y, "row", 0)
            if b.note then
                h:SetNote(b.note)
                y = y + NS.Blocks.NOTE_H
            end
        end
        return y + blockGap()
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
        frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(2 + SCROLL_GUTTER), footerH() + 2)
        applyBounds()
        -- A render while the grip is dragged keeps the grip's size: the body takes the frame's width.
        if sizing then return W.Relayout(frame:GetWidth(), frame:GetHeight()) end
        local maxH = winSettings().maxHeight or 560
        frame:SetWidth(width())
        frame.content:SetWidth(W.ContentWidth())
        -- The window keeps Window height unless Shrink to fit is on: a block collapsing or expanding
        -- never resizes it (owner feedback round 3).
        local h = winSettings().fitHeight and math.min(top + y + footerH() + 4, maxH) or maxH
        frame:SetHeight(math.max(MIN_H, h))
    end

    local function renderTitle(test, sim)
        if frame.strip then frame.strip:SetShown(test) end
        if frame.simStrip then frame.simStrip:SetShown(sim and not test) end
        local word = (test and not frame.strip and L["Test mode"])
            or (sim and not frame.simStrip and L["Simulation"]) or nil
        frame.title:SetText(word and L["%s - %s"]:format(fam.title, word) or fam.title)
    end

    --- The marker state, part of the layout signature: a strip shown or hidden moves the body, and so
    --- does the title band's bottom (a skin whose band sits elsewhere, NS.Chrome.TitleBottom).
    local function markerSig(test, sim)
        return (test and "T" or "") .. (sim and "S" or "") .. NS.Chrome.TitleBottom(frame)
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
        local test, sim = NS.IsTestMode(), NS.IsSimRunning and NS.IsSimRunning() or false
        renderTitle(test, sim)
        local skills, stats = NS.Blocks.Data()
        local blocks, sig, laid = plan(skills, stats)
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
        frame.empty:SetShown(laid == 0)
        paintToggleAll()
        local who, gains, alert = W.SummaryParts(skills)
        drawIdentity(who)
        frame.summaryGains:SetText(gains)
        frame.summaryAlert:SetText(alert)
        paintLegend()
        NS.Blocks.UpdateSpeedWatch()
        if t0 then Perf.Note("windowRender", debugprofilestop() - t0) end
    end

    --- The cheap layout a size change runs while the grip is dragged (at most once a rendered frame,
    --- NS.Chrome.MakeResizable): the columns and the scrolled body take the frame's new width. The rows
    --- are anchored to their column's two edges, so they follow; nothing is re-planned or re-bound, and
    --- the release's redraw lays everything out once. Outside a drag it does nothing.
    function W.Relayout(w)
        if not (frame and sizing) then return end
        local n = columns()
        local colW = max(1, bodyColumnFor(tonumber(w) or frame:GetWidth()))
        placeColumns(n, colW)
        frame.content:SetWidth(n * colW + (n - 1) * COLUMN_GAP)
    end

    --- The rows drawn this pass (the suites and the overlay sync read them).
    function W.Rows() return rowPool and rowPool.active or {} end
    function W.Headers() return headerPool and headerPool.active or {} end

    --- The header drawn for block `id` this pass, or nil.
    function W.HeaderFor(id) return headers[id] end

    --- The window's strata: the player's pick (Layout > Window strata), one of STRATA_CHOICES.
    function W.Strata()
        local s = winSettings().strata
        for _, v in ipairs(LAYERS.STRATA_CHOICES) do if v == s then return s end end
        return LAYERS.STRATA.WINDOW
    end

    --- Re-apply the stored strata, scale, opacity, lock and position. The crafting overlays take the
    --- new strata on the sync at the end (modules/SecureOverlay.lua reads the host's at each arm).
    function W.ApplySettings()
        if not (frame and NS.db) then return end
        frame:SetFrameStrata(W.Strata())
        frame:SetScale(NS.GetSetting("scale") or 1)
        applyBounds()   -- the screen cap is in the frame's units, so it moves with Master scale
        frame:SetAlpha(NS.GetSetting("alpha") or 1)
        local locked = NS.GetSetting("locked")
        frame:SetMovable(not locked)
        -- Locked holds the window: no drag, and no grip (AF-SM-RESIZE; canResize refuses it too).
        if frame.resizeGrip then frame.resizeGrip:SetShown(not locked) end
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

    --- The window's ONE toggle handler: its slash verb, its launcher entry and its key binding.
    function W.Toggle()
        if W.IsShown() then W.Hide() return false end
        return W.Show()
    end

    --- The docked skill block that shows skill `key`, or nil (detached, hidden or not a skill).
    local function dockedBlockOf(key)
        local skills = NS.Blocks.Data()
        for _, id in ipairs(NS.Blocks.DockedIn(fid)) do
            for _, r in ipairs(NS.Blocks.Entries(id, skills, nil)) do
                if r.kind == "skill" and r.entry.key == key then return id end
            end
        end
        return nil
    end

    --- Whether this window docks skill `key`'s row (Windows.ShowAndScrollTo picks the window by it).
    function W.Docks(key) return dockedBlockOf(key) ~= nil end

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
        if NS.db then NS.db.profile.windows[fid].point = false end
        if frame then applyPoint() end
    end

    return W
end

-- ---------------------------------------------------------------------------------------------
-- Every window
-- ---------------------------------------------------------------------------------------------

--- Family `fid`'s window, or nil.
function Windows.Get(fid) return byFamily[fid] end

--- The windows in the family order: for fid, W in Windows.Each().
function Windows.Each()
    local i = 0
    return function()
        i = i + 1
        local fid = NS.FAMILY_ORDER[i]
        if fid then return fid, byFamily[fid] end
    end
end

--- The window docked block `id` draws in (its family's), or nil.
function Windows.ForBlock(id)
    local d = NS.BlockDefs[id]
    return d and byFamily[d.family] or nil
end

--- Show or hide family `fid`'s window: its slash verb, its key binding and its launcher entry.
function Windows.Toggle(fid)
    local W = byFamily[fid]
    return W and W.Toggle() or false
end

function Windows.RefreshAll(relayout)
    for _, W in Windows.Each() do W.Refresh(relayout) end
end

function Windows.RefreshValuesAll()
    for _, W in Windows.Each() do W.RefreshValues() end
end

function Windows.ApplyAll()
    for _, W in Windows.Each() do W.ApplySettings() end
end

function Windows.HideAll()
    for _, W in Windows.Each() do W.Hide() end
end

function Windows.StandDownAll()
    for _, W in Windows.Each() do W.StandDown() end
end

--- Reset position (the Master-controls button): every window back to its first-time place.
function Windows.ResetPositions()
    for _, W in Windows.Each() do W.ResetPosition() end
end

--- Whether any family window is shown.
function Windows.AnyShown()
    for _, W in Windows.Each() do if W.IsShown() then return true end end
    return false
end

--- Every shown window's rows, each list with its frame: { { rows, frame }, ... } (the overlay sync's).
function Windows.Shown()
    local out = {}
    for _, W in Windows.Each() do
        if W.IsShown() then out[#out + 1] = W end
    end
    return out
end

--- Show the window that docks skill `key`, scrolled to its row (the broker's crafting rows); with no
--- window docking it, the Professions window. Answers whether the row was brought into view.
function Windows.ShowAndScrollTo(key)
    for _, W in Windows.Each() do
        if W.Docks(key) then return W.ShowAndScrollTo(key) end
    end
    return byFamily.professions.ShowAndScrollTo(key)
end

--- The highest strata a family window is drawn in (the trainer popup opens over whichever it came from).
local RANK = {}
for i, s in ipairs(LAYERS.STRATA_CHOICES) do RANK[s] = i end
function Windows.TopStrata()
    local top
    for _, W in Windows.Each() do
        local s = W.Strata()
        if not top or (RANK[s] or 0) > (RANK[top] or 0) then top = s end
    end
    return top or LAYERS.STRATA.WINDOW
end

for _, fid in ipairs(NS.FAMILY_ORDER) do Windows.New(fid) end
