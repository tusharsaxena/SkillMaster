local _, NS = ...
-- modules/BrokerTooltip.lua — the broker feeds' tooltip content (split out of modules/Broker.lua, item
-- SMW-05 of docs/superpowers/plans/2026-11-26-skillmaster-windows.md, which keeps the feeds, their text,
-- their clicks and the showing machinery): the Classic style's lines (tooltips.ldb.style = "classic") with
-- Widgets Bar mini bars, the rows' heights, the header bands and stripes, the rows' hover areas, the chevrons
-- and hover wash, and the content both styles share: each feed's sections (its family's blocks, read
-- through NS.Blocks.Entries with the tooltip's own Hide sets), its heading, its footer and test mode's line.
--
-- ONLY THE FOLD TAKES A CLICK (the owner's ask, SMW-07). A section's header carries a chevron; a click
-- anywhere on the header's line (R5-SM-02, the owner's round 5: the whole line is the hit area, at every
-- depth) folds or unfolds that section in the tooltip alone (B.ToggleTipFold, modules/BrokerFolds.lua) and
-- the lines are drawn again in place. A row's line takes the pointer for its hover wash only: no open, link or
-- menu.
--
-- B.FillTooltip(tip, which) / B.ReleaseLines() / B.AddHit(tip, row) / B.TooltipEntries(id, skills, stats) /
-- B.ShownBlocks() / B.Heading() / B.FooterText() / B.AddTestModeLine(tip) / B.Models() / B.Bars() /
-- B.Bands(tip) / B.Hits() / B.Chevrons() / B.HoverWash(tip) / B.ValueInset(tip) / B.BarsDrawn()

local B = NS.Broker
local L = NS.L
local LAYERS = NS.Constants.LAYERS

-- ---------------------------------------------------------------------------------------------
-- The mini bar: the shared bar widget (LibKa0s-Widgets-1.0 Bar, "mini" style) on a tooltip line
-- ---------------------------------------------------------------------------------------------

local barPool = NS.Pool.New()
local barsDrawn = 0

local function lineRegion(tip, n)
    local name = tip.GetName and tip:GetName()
    return name and _G[name .. "TextLeft" .. n] or nil
end

--- Draw one mini bar on tooltip line `n` from the bar's values ({ value, max, bonus, bonusKind,
--- color, ... }: NS.Rows.SkillValues / StatValues). The bar clamps the bonus to its end.
local function drawMiniBar(tip, n, values)
    local line = lineRegion(tip, n)
    if not line then return false end
    local bar = NS.Widgets.AcquireBar(barPool, tip, NS.BarStyle.Opts("mini"))
    bar:SetFrameLevel(tip:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    bar:ClearAllPoints()
    bar:SetPoint("LEFT", line, "LEFT", B.NAME_W, 0)
    bar:SetPoint("RIGHT", tip, "RIGHT", -B.VALUE_W, 0)
    bar.skmLine = n
    bar:SetValues(values)
    barsDrawn = barsDrawn + 1
    return true
end

function B.BarsDrawn() return barsDrawn end

--- The bars' right inset for `tip`: the widest value on a bar's line, the tooltip's inset and the
--- gap; VALUE_W when no width answers (a stand-in tooltip, a value-less line).
function B.ValueInset(tip)
    local name, widest = tip.GetName and tip:GetName(), 0
    for _, bar in ipairs(barPool.active or {}) do
        local fs = name and bar.skmLine and _G[name .. "TextRight" .. bar.skmLine]
        local w = fs and fs.GetStringWidth and tonumber(fs:GetStringWidth()) or 0
        if w > widest then widest = w end
    end
    if widest <= 0 then return B.VALUE_W end
    return math.min(B.VALUE_W, math.ceil(widest) + B.TIP_INSET + B.VALUE_GAP)
end

--- Pull every bar's right end in to the value column's real width.
local function fitBars(tip)
    local inset = B.ValueInset(tip)
    for _, bar in ipairs(barPool.active or {}) do
        local line = bar.skmLine and lineRegion(tip, bar.skmLine)
        if line then
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", line, "LEFT", B.NAME_W, 0)
            bar:SetPoint("RIGHT", tip, "RIGHT", -inset, 0)
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Row height: a skill or stat line's font strings take Bars > LDB tooltip row height. The shared
-- GameTooltip keeps a font string's height across owners, so every line sized here goes back to
-- auto height (SetHeight(0)) with the bars, before anyone else's lines land on it.
-- ---------------------------------------------------------------------------------------------

local sized = {}

local function sizeRow(tip, n, h)
    local name = tip.GetName and tip:GetName()
    if not name then return end
    h = h or NS.BarStyle.TooltipRowHeight("mini")
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
        local fs = _G[name .. side .. n]
        if fs and fs.SetHeight then
            fs:SetHeight(h)
            sized[#sized + 1] = fs
        end
    end
end

local function unsizeRows()
    for i = #sized, 1, -1 do
        sized[i]:SetHeight(0)
        sized[i] = nil
    end
end

--- The mini bars on the open tooltip (Widgets Bar instances; the suites read them).
function B.Bars() return barPool.active or {} end

-- ---------------------------------------------------------------------------------------------
-- Bands: the window's look on the tooltip (feedback round 2): a section's header band
-- (`sm.headerBg`, the block header's) and the alternate rows' stripe (`list.stripe`, the window
-- rows'). Textures on the tooltip itself, in its BORDER layer, above its backdrop and below its
-- text; a child frame would draw over the text. Each tooltip keeps its own pool, every texture
-- hidden again with the bars, so the shared GameTooltip shows nothing of the feed's for its next owner.
-- ---------------------------------------------------------------------------------------------

local bands = {}   -- [tooltip] = { textures, used = n }
B.HEADER_PAD = 6   -- a section header line is this much taller than a row

local function band(tip, n, h, r, g, b, a)
    local line = lineRegion(tip, n)
    if not (line and tip.CreateTexture and r) then return nil end
    local pool = bands[tip]
    if not pool then pool = { used = 0 } bands[tip] = pool end
    pool.used = pool.used + 1
    local t = pool[pool.used]
    if not t then
        t = tip:CreateTexture(nil, "BORDER")
        pool[pool.used] = t
    end
    t:ClearAllPoints()
    t:SetPoint("LEFT", line, "LEFT", -6, 0)
    t:SetPoint("RIGHT", tip, "RIGHT", -4, 0)
    t:SetHeight(h + 2)
    t:SetColorTexture(r, g, b, a or 1)
    t:Show()
    return t
end

local function releaseBands()
    for _, pool in pairs(bands) do
        for i = 1, pool.used do pool[i]:Hide() end
        pool.used = 0
    end
end

--- The bands drawn on `tip` now (the suites read them).
function B.Bands(tip)
    local pool, out = bands[tip], {}
    for i = 1, pool and pool.used or 0 do out[i] = pool[i] end
    return out
end

local function stripe(tip, n, i)
    if i % 2 ~= 0 then return end   -- the window's rows stripe the even ones (NS.Rows SetStripe)
    band(tip, n, NS.BarStyle.TooltipRowHeight("mini"), NS.Skin.Color("list.stripe"))
end

-- ---------------------------------------------------------------------------------------------
-- Row hover areas over the tooltip's lines (the wash, never a click), and the sections' fold chevrons
-- ---------------------------------------------------------------------------------------------

local hitPool, chevronPool = NS.Pool.New(), NS.Pool.New()

-- The hovered row's wash (the window's `list.hover`, NS.Rows onEnter): one texture per tooltip, on
-- the tooltip in the stripes' BORDER layer one sublevel up, so it covers a stripe and never the
-- text. A wash on the hit button would sit over the line, the button being a child frame.
local hovers = {}   -- [tooltip] = texture

--- The hover wash on `tip`, or nil before its first hover (the suites read it).
function B.HoverWash(tip) return hovers[tip] end

local function showHover(hit)
    local tip, row = hit:GetParent(), hit.row
    local line = tip and row and lineRegion(tip, row.line)
    local r, g, b, a = NS.Skin.Color("list.hover")
    if not (line and r and tip.CreateTexture) then return end
    local t = hovers[tip]
    if not t then
        t = tip:CreateTexture(nil, "BORDER", nil, 1)
        hovers[tip] = t
    end
    t:ClearAllPoints()
    t:SetPoint("LEFT", line, "LEFT", -6, 0)
    t:SetPoint("RIGHT", tip, "RIGHT", -4, 0)
    t:SetHeight(hit:GetHeight())
    t:SetColorTexture(r, g, b, a or 1)
    t:Show()
end

local function hideHovers()
    for _, t in pairs(hovers) do t:Hide() end
end

-- A plain frame, not a button: it takes the pointer for the hover and no click (SMW-07).
local function newHit()
    local hit = CreateFrame("Frame", nil, UIParent)
    hit:EnableMouse(true)
    hit:SetScript("OnEnter", showHover)
    hit:SetScript("OnLeave", hideHovers)
    return hit
end

-- A section header's fold: the one thing in the tooltip a click acts on, laid over the header's whole line.
local function newChevron()
    local b = CreateFrame("Button", nil, UIParent)
    b:RegisterForClicks("LeftButtonUp")
    b:SetScript("OnClick", function(self)
        local row = self.row
        if row.node ~= nil then return B.ToggleTipNode(row.family, row.node) end   -- a tree header (SMW-08..10)
        B.ToggleTipFold(row.fold)
    end)
    return b
end

--- The tooltip's row hover areas now (the suites read them).
function B.Hits() return hitPool.active or {} end
--- The tooltip's section chevrons now (the suites read them).
function B.Chevrons() return chevronPool.active or {} end

-- A tree header's line leads with its depth's indent (four spaces a level, addTreeRow) and then its chevron.
local INDENT = "    "

local function addChevron(tip, row, line)
    local b = NS.Pool.Acquire(chevronPool, newChevron)
    b.row = row
    b:SetParent(tip)
    b:SetFrameLevel(tip:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    b:ClearAllPoints()
    -- Over the header's whole line, as a row's hover area lies (R5-SM-02): a click anywhere on it folds,
    -- a nested tree header's included (its chevron past the indent, SMW-REV, is inside the line).
    b:SetPoint("LEFT", line, "LEFT", -2, 0)
    b:SetPoint("RIGHT", tip, "RIGHT", -4, 0)
    b:SetHeight((line.GetHeight and line:GetHeight() or 12) + 2)
    b:Show()
end

--- Over `tip`'s line of `row`: a section header's fold chevron (`row.fold`, its block id) or a row's hover
--- area (B.OnEnter lays one per Classic row and header).
function B.AddHit(tip, row)
    local line = lineRegion(tip, row.line)
    if not line then return end
    if row.fold or row.node ~= nil then return addChevron(tip, row, line) end
    local hit = NS.Pool.Acquire(hitPool, newHit)
    hit.row = row
    hit:SetParent(tip)
    hit:SetFrameLevel(tip:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    hit:ClearAllPoints()
    hit:SetPoint("LEFT", line, "LEFT", -2, 0)
    hit:SetPoint("RIGHT", tip, "RIGHT", -4, 0)
    hit:SetHeight((line.GetHeight and line:GetHeight() or 12) + 2)
    hit:Show()
end

--- Let go of everything the Classic lines drew: the sized rows, the fonts, the bands, the hover wash, the
--- mini bars, the hover areas and the chevrons (modules/Broker.lua's showing machinery calls it as the
--- tooltip goes, and before each redraw).
function B.ReleaseLines()
    unsizeRows()
    -- Tooltips > Font size undone on whichever tooltip carried it (a no-op on one never sized).
    local ownTip = B.OwnTip()
    if ownTip then NS.Chrome.RestoreTooltipFonts(ownTip) end
    if GameTooltip then NS.Chrome.RestoreTooltipFonts(GameTooltip) end
    releaseBands()
    hideHovers()
    NS.Widgets.ReleaseBars(barPool)
    NS.Pool.ReleaseAll(hitPool)
    NS.Pool.ReleaseAll(chevronPool)
end

-- ---------------------------------------------------------------------------------------------
-- Tooltip content
-- ---------------------------------------------------------------------------------------------

--- A section's title: the block's title in its own family's window (Primary Professions, Base & Combat, ...).
local function sectionTitle(id)
    return NS.Blocks.HomeTitle(id)
end

--- A skill's bar values, and the token its bonus number is colored in (temp or permanent).
local function skillBar(e)
    local values = NS.Rows.SkillValues(e)
    values.color = NS.Rows.FillColor(e)
    return values, values.bonusKind == "temp" and "sm.bonusTemp" or "sm.bonusPerm"
end

local function skillValue(e, bonus)
    if not e.learned then return B.Colored("gtip.muted", L["Not learned"]) end
    local text = ("%d/%d"):format(e.rank or 0, e.max or 0)
    local mod = tonumber(e.modifier) or 0
    if mod ~= 0 then text = text .. " " .. B.Colored(bonus, (mod > 0 and "+" or "") .. mod) end
    local g = B.View().gains.byKey[e.key]
    if g and g > 0 then text = text .. "  " .. B.Colored("sem.good", "+" .. g) end
    return text
end

-- A skill's name is white, the tooltip's value color, as the window's are (feedback round 2); an
-- unlearned one is muted.
local function nameColor(e)
    if not e.learned then return "gtip.muted" end
    return "gtip.value"
end

-- A line honors Rows show (bars.rowDisplay) as the window's rows do: Bar only leaves the value
-- column empty, Value only draws no mini bar. An unlearned skill's "Not learned" is no value.
local function showsBar() return NS.Rows.Display() ~= "text" end
local function showsValue() return NS.Rows.Display() ~= "bar" end

local function addSkillRow(tip, e, i)
    local values, bonus = skillBar(e)
    local value = (showsValue() or not e.learned) and skillValue(e, bonus) or ""
    tip:AddDoubleLine(B.Colored(nameColor(e), e.name or e.key), value)
    local n = tip:NumLines()
    sizeRow(tip, n)
    stripe(tip, n, i)
    if e.learned and (e.max or 0) > 0 and showsBar() then drawMiniBar(tip, n, values) end
    return { line = n, kind = "skill", key = e.key }
end

--- The chevron drawn at a folding header's left: the icon as a texture escape, else its glyph.
local function chevronMark(folded)
    local icon = NS.Icon(folded and "chevron-right" or "chevron-down")
    if icon then return ("|T%s:0|t "):format(icon) end
    return folded and "> " or "v "
end

--- A section's header: the window's block title in the header text color on the header band, a
--- little taller than a row. A block's header (`foldId`) leads with its chevron (SMW-07: the Classic
--- style's sections fold too) and answers its chevron's row ({ line, fold }); the Pinned header folds nothing.
local function addTitle(tip, title, foldId)
    local mark = foldId and chevronMark(B.TipFolded(foldId)) or ""
    tip:AddLine(mark .. B.Colored("list.header.text", title))
    local n = tip:NumLines()
    local h = NS.BarStyle.TooltipRowHeight("mini") + B.HEADER_PAD
    sizeRow(tip, n, h)
    local c = NS.SkinColor("sm.headerBg")
    if c then band(tip, n, h, c[1], c[2], c[3], c[4]) end
    return foldId and { line = n, fold = foldId } or nil
end

--- The tooltip's own Hide sets as NS.Blocks.Entries asks ("skills" | "stats", key).
local function tipHidden(kind, key)
    return B.HiddenInTooltip(kind == "stats" and "stat" or "skill", key)
end

--- The models the tooltip draws: the bus's, or test mode's sample (B.source): skills, stats, and every
--- provider's keyed by its source (NS.Blocks.Models, the tree families').
function B.Models()
    local v = B.View()
    return v.model, v.statsModel, v.models
end

--- Block `id`'s rows in the tooltip, each { kind, entry }, and how many its filter took out: the
--- window's block as NS.Blocks.Entries lays it (its sort order and its filter, owner feedback
--- round 6, R6-10, every block's filter since round 7, R7-1; unlearned rows as Skills > Show unlearned says), less the tooltip's own
--- Hide sets in place of the window's.
function B.TooltipEntries(id, skills, stats)
    if skills == nil and stats == nil then return {}, 0 end
    return NS.Blocks.Entries(id, skills, stats, tipHidden)
end

--- A section's header, then its rows; a section its filter emptied shows its header and the
--- window's muted line.
local function addSkillSection(tip, rows, section, m)
    local entries, removed = B.TooltipEntries(section, m, nil)
    local note = NS.Blocks.FilterNote(entries, removed)
    if #entries == 0 and not note then return end
    rows[#rows + 1] = addTitle(tip, sectionTitle(section), section)
    if B.TipFolded(section) then return end
    for i, r in ipairs(entries) do rows[#rows + 1] = addSkillRow(tip, r.entry, i) end
    if note then tip:AddLine(B.Colored("gtip.muted", note)) end
end

local function addStatRow(tip, e, i)
    local value = showsValue() and B.Colored("gtip.value", e.display or "") or ""
    tip:AddDoubleLine(B.Colored("gtip.value", e.label or e.key), value)
    local n = tip:NumLines()
    sizeRow(tip, n)
    stripe(tip, n, i)
    if showsBar() then
        local values = NS.Rows.StatValues(e)
        values.color = NS.Rows.FillColor(e, true)
        drawMiniBar(tip, n, values)
    end
    return { line = n, kind = "stat", key = e.key }
end

local function addStatSection(tip, rows, id, sm)
    local entries, removed = B.TooltipEntries(id, nil, sm)
    local note = NS.Blocks.FilterNote(entries, removed)
    if #entries == 0 and not note then return end
    rows[#rows + 1] = addTitle(tip, sectionTitle(id), id)
    if B.TipFolded(id) then return end
    for i, r in ipairs(entries) do rows[#rows + 1] = addStatRow(tip, r.entry, i) end
    if note then tip:AddLine(B.Colored("gtip.muted", note)) end
end

-- A tree family's rows (SMW-08..10): a header line leads with its fold chevron, indented by its depth (INDENT,
-- above), and answers its chevron's row ({ line, node, family, depth }); a leaf a value line with its kind's mini
-- bar.
local function addTreeRow(tip, r, i)
    local e, spec = r.entry, NS.Tree.Kind(r.kind) or {}
    local lead = INDENT:rep(r.depth or 0) .. (r.header and chevronMark(r.folded) or "")
    local value = showsValue() and spec.valueText and spec.valueText(e) or ""
    local token = r.header and "list.header.text" or "gtip.value"
    tip:AddDoubleLine(lead .. B.Colored(token, e.name or e.key), B.Colored("gtip.value", value))
    local n = tip:NumLines()
    sizeRow(tip, n)
    stripe(tip, n, i)
    local values = showsBar() and spec.values and spec.values(e)
    if values then
        values.text = ""
        drawMiniBar(tip, n, values)
    end
    if r.header then return { line = n, node = e.nodeKey, family = spec.family, depth = r.depth } end
    return { line = n, kind = r.kind, key = e.key }
end

--- Tree block `id`'s rows in the tooltip, under the tooltip's own folds (tooltips.ldb.folds.nodes, SMW-07).
function B.TreeEntries(id, models)
    local d = NS.BlockDefs[id]
    return NS.Blocks.EntriesFrom(id, models, nil, d and B.TipNodeStore(d.family))
end

local function addTreeSection(tip, rows, id, models)
    local entries = B.TreeEntries(id, models)
    if #entries == 0 then return end
    rows[#rows + 1] = addTitle(tip, sectionTitle(id), id)
    if B.TipFolded(id) then return end
    for i, r in ipairs(entries) do rows[#rows + 1] = addTreeRow(tip, r, i) end
end

-- One shown section of the feed. Answers whether the no-model line has been written (once per
-- tooltip, before the first test-mode or live model lands).
-- A section's lines, by its block's provider (modules/BlockProviders.lua): the skills', the stats' and a tree
-- family's (handed every model, keyed by source).
local ADD = { skills = addSkillSection, stats = addStatSection }
local function modelFor(v, source)
    if source == "skills" then return v.model end
    if source == "stats" then return v.statsModel end
    return v.models and v.models[source] or nil
end

local function fillSection(tip, rows, section, v, told)
    local d = NS.BlockDefs[section]
    local tree = d and NS.IsTreeBlock(section)
    local add = d and (ADD[d.source] or (tree and addTreeSection))
    local m = add and modelFor(v, d.source)
    if m then
        add(tip, rows, section, tree and v.models or m)
        return told
    end
    if not told then tip:AddLine(B.Colored("gtip.muted", NS.Windows.EmptyText(B.Feed()))) end
    return true
end

--- The feed's pins first (GitHub issue #11, SMW-06): a Pinned section, each pin a line as its block draws
--- it. Nothing when the feed has none.
local PIN_ROW = { skill = function(tip, r, i) return addSkillRow(tip, r.entry, i) end,
                  stat = function(tip, r, i) return addStatRow(tip, r.entry, i) end }
-- A tree pin draws as a leaf at the section's edge (no indent, no chevron).
local function pinRow(r)
    if PIN_ROW[r.kind] then return PIN_ROW[r.kind] end
    if NS.Tree.Kind(r.kind) then
        return function(tip, p, i) return addTreeRow(tip, { kind = p.kind, entry = p.entry, depth = 0 }, i) end
    end
    return nil
end
local function addPinSection(tip, rows)
    local pins = B.PinnedEntries(B.Feed())
    local drawn = {}
    for _, r in ipairs(pins) do if pinRow(r) then drawn[#drawn + 1] = r end end
    if #drawn == 0 then return end
    addTitle(tip, L["Pinned"])
    for i, r in ipairs(drawn) do rows[#rows + 1] = pinRow(r)(tip, r, i) end
end

local function fillSections(tip, rows)
    addPinSection(tip, rows)
    local v, told = B.View(), false
    for _, section in ipairs(B.FEEDS[B.Feed()].sections) do
        if B.SectionShown(section) then told = fillSection(tip, rows, section, v, told) end
    end
end

--- Test mode's line (owner feedback round 6, R6-2): the main window's strip text in the skin's
--- warning color, added to `tip` while test mode is on. Answers whether it added the line. Any
--- tooltip this addon fills calls it right under its title.
function B.AddTestModeLine(tip)
    if not NS.IsTestMode() then return false end
    tip:AddLine(B.Colored("sem.warn", L["Test mode: the skills shown are sample data."]))
    return true
end

--- The tooltip's footer: what the feed's label does on a click, and the one click the tooltip takes.
function B.FooterText()
    return L["Click label: toggle window \194\183 Right-click label: options \194\183 Click a header to fold"]
end

--- The blocks the Main window style draws for the feed showing now, in the window's block order
--- (NS.Blocks.Ordered): each of its shown sections' block.
function B.ShownBlocks()
    local want = {}
    for _, section in ipairs(B.FEEDS[B.Feed()].sections) do
        if B.SectionShown(section) then want[section] = true end
    end
    local out = {}
    for _, id in ipairs(NS.Blocks.Ordered()) do
        if want[id] then out[#out + 1] = id end
    end
    return out
end

--- The tooltip's title (the feed's, R7-5: its family window's title) and its session gains line, the
--- skill feeds' (Professions, Skills); "" for the others.
function B.Heading()
    local f = B.FEEDS[B.Feed()]
    local gained = f.source == "skills" and L["+%d this session"]:format(B.View().gains.total) or ""
    return f.title, gained
end

--- Fill `tip` (the feed's tooltip, or a stand-in) with the shown sections. Answers the lines that take
--- the pointer: each row { line, kind = "skill" | "stat", key } (its hover) and each section header's
--- chevron { line, fold = block id }. `which` picks the feed (a family id, the Professions
--- feed by default); it stays the feed showing now.
function B.FillTooltip(tip, which)
    if which then B.SetFeed(which) end
    B.ReleaseLines()
    barsDrawn = 0
    local rows = {}
    if tip.SetMinimumWidth then tip:SetMinimumWidth(B.MinWidth()) end
    local title, gained = B.Heading()
    tip:AddDoubleLine(B.Colored("gtip.title", title), B.Colored("gtip.muted", gained))
    B.AddTestModeLine(tip)
    if NS.IsStoodDown() then
        tip:AddLine(B.Colored("gtip.muted", L["Ka0s Skill Master is disabled."]))
        return rows
    end
    fillSections(tip, rows)
    fitBars(tip)
    tip:AddLine(B.Colored("gtip.footer", B.FooterText()))
    return rows
end

