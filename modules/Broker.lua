local addonName, NS = ...
-- modules/Broker.lua — the one broker data feed, "Skill Master" (design §6.7, plan Task 4.1;
-- feedback round 2, FB-12): a LibDataBroker-1.1 "data source" whose text is a template
-- (modules/Template.lua), flashed on a skill-up, with a tooltip of mini bars and clickable rows
-- (design §6.5) in five sections: Primary, Secondary, Weapon, Other and Stats. Each section has its
-- own switch and each skill and stat its own tooltip Hide (profile.broker.tooltip), apart from the
-- main window's skills.hidden / stats.hidden.
--
-- The tooltip (FB-13): with "Apply skin to the tooltip" on (broker.tooltip.skin, the default) it is
-- this file's own GameTooltip-template frame, painted with the skin's window shell and fonts; off,
-- it is the shared GameTooltip exactly as before. The shared GameTooltip is never painted.
--
-- These are NOT the launcher: core/LauncherSetup.lua's one "launcher" object stays the only click
-- and menu implementation for the addon (launcher-§1). Nothing here is secure: a feed row never
-- casts, it opens a window (design §6.5, Feed row).
--
-- Consumes SKILLS_UPDATED, SKILL_UP, STATS_UPDATED and BONUSES_UPDATED on its own bus target. The
-- one client read is the main-hand weapon class for {equippedWeapon}, feature-detected.
--
-- B.source: nil for the models the bus handed over, or fn() -> { model, statsModel, statIndex,
-- gains = { total, byKey }, last } (test mode's sample character, modules/Preview.lua, T5.2). The
-- bus keeps feeding the live state underneath, so turning test mode off shows it again at once.

NS.Broker = {}
local B = NS.Broker
local L = NS.L
local LAYERS = NS.Constants.LAYERS

local MAIN_HAND = 16
local NAME_W, VALUE_W = 128, 124   -- the bar's height is profile.bars.miniHeight, its line's
                                   -- profile.bars.brokerRowHeight; its width Tooltips > Bar width

-- The tooltip's own settings (the Tooltips page, owner feedback round 4).
local function tipSettings()
    local t = NS.db and NS.db.profile.tooltips
    return t and t.ldb or NS.defaults.profile.tooltips.ldb
end

--- The tooltip's minimum width: the name column, Tooltips > Bar width and the value column. The
--- bars stretch between the two columns, so the width is the least a bar draws.
function B.MinWidth()
    return NAME_W + (tonumber(tipSettings().barWidth) or 128) + VALUE_W
end
-- The bar stops this far short of its line's value (owner feedback round 3: the fixed VALUE_W
-- left a wide gap): the widest value drawn, the tooltip's own right inset and this gap.
B.VALUE_GAP, B.TIP_INSET = 8, 10
local HIDE_POLL = 0.1          -- seconds between the tooltip's leave checks

-- The feed's LibDataBroker name (a key display addons store placements under, so never localized;
-- the launcher object is the addon's folder name, "SkillMaster") and the label a display draws.
B.NAME = "Skill Master"
B.LABEL = L["Skill Master"]

-- The tooltip's sections, in order; each one's switch is broker.tooltip.sections.<id>.
B.SECTIONS = { "primary", "secondary", "weapon", "other", "stats" }

-- The owned tooltip frame's global name (its TextLeftN lines are found by it, as GameTooltip's are).
B.TIP_NAME = "SkillMasterBrokerTooltip"

-- The settings page the feed's right-click opens (the Broker page's registration key). The library
-- opens the main panel when no page of that key is built.
B.SETTINGS_PAGE = "broker"

-- ---------------------------------------------------------------------------------------------
-- State: the last models the bus handed over, the session's gains, the flash
-- ---------------------------------------------------------------------------------------------

local model, statIndex, statsModel
local gains = { total = 0, byKey = {} }
local last
local flash, flashTimer = nil, nil
local object, rendered

--- Back to a fresh session (the suites call this between cases).
function B.ResetSession()
    gains = { total = 0, byKey = {} }
    last, flash = nil, nil
    if flashTimer then NS.addon:CancelTimer(flashTimer) end
    flashTimer = nil
end

local function copyGains(g)
    local byKey = {}
    for k, v in pairs(g.byKey) do byKey[k] = v end
    return { total = g.total, byKey = byKey }
end

--- This session's gains and last skill-up, as a copy (the simulator takes it at start).
function B.SessionState() return { gains = copyGains(gains), last = last } end

--- Put a SessionState() back and end any flash (the simulator's stop).
function B.RestoreSessionState(st)
    if type(st) ~= "table" or type(st.gains) ~= "table" then return end
    gains, last, flash = copyGains(st.gains), st.last, nil
    if flashTimer then NS.addon:CancelTimer(flashTimer) end
    flashTimer = nil
    B.Refresh()
end

--- What the feed draws: B.source's answer while one is set (and true), else the live state.
local function view()
    local v = B.source and B.source()
    if type(v) == "table" then return v, true end
    return { model = model, statsModel = statsModel, statIndex = statIndex, gains = gains, last = last }
end

local function setting(path, fallback)
    local v = NS.GetSetting and NS.db and NS.GetSetting(path)
    if v == nil then return fallback end
    return v
end

function B.FlashSeconds() return tonumber(setting("broker.flashSeconds", 5)) or 5 end

local function template()
    local t = setting("broker.template", nil)
    return type(t) == "string" and t or ""
end

-- ---------------------------------------------------------------------------------------------
-- What the tooltip shows: the sections' switches and its own Hide sets (never the window's)
-- ---------------------------------------------------------------------------------------------

local function tooltipStore()
    local p = NS.db and NS.db.profile
    local b = type(p) == "table" and p.broker
    return type(b) == "table" and type(b.tooltip) == "table" and b.tooltip or nil
end

--- Whether section `id` (B.SECTIONS) is drawn in the tooltip.
function B.SectionShown(id)
    local v = setting("broker.tooltip.sections." .. id, nil)
    if v == nil then return NS.defaults.profile.broker.tooltip.sections[id] == true end
    return v == true
end

--- Whether the tooltip leaves out the skill (`kind` "skill") or stat ("stat") `key`.
function B.HiddenInTooltip(kind, key)
    local store = tooltipStore()
    local set = store and store[kind == "stat" and "hiddenStats" or "hiddenSkills"]
    return type(set) == "table" and set[key] == true
end

--- Whether the tooltip wears the skin (broker.tooltip.skin).
function B.Skinned() return setting("broker.tooltip.skin", true) ~= false end

-- ---------------------------------------------------------------------------------------------
-- The template context
-- ---------------------------------------------------------------------------------------------

--- The skill key of the main-hand weapon: "unarmed" with none, nil for a non-skill item.
function B.MainHandSkill()
    return NS.SkillHelpers.WeaponSkillInSlot(MAIN_HAND)
end

local function pinnedKey()
    local char = NS.db and NS.db.char
    local key = type(char) == "table" and char.pinned or nil
    return type(key) == "string" and key or nil
end

--- The template context. While a source is set (test mode) the pin and the main hand are its own,
--- so a sample feed never reads this character's store or gear.
function B.Context()
    local v, sourced = view()
    return {
        skills = v.model, stat = v.statIndex, gains = v.gains.total, last = v.last,
        pinned = sourced and v.pinned or pinnedKey(),
        mainHand = sourced and v.mainHand or B.MainHandSkill(),
        level = NS.Preview.Character().level,
    }
end

-- ---------------------------------------------------------------------------------------------
-- Feed text: the template, or the flash while one runs
-- ---------------------------------------------------------------------------------------------

local function hex(token, fallback)
    local r, g, b = NS.Skin.Color(token)
    if not r then return fallback or "ffffffff" end
    return ("ff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

local function colored(token, text)
    return ("|c%s%s|r"):format(hex(token), text)
end

local function flashText(name, new)
    local icon = NS.Icon("chevron-up")
    local mark = icon and ("|T%s:0|t"):format(icon) or "+"
    return colored("sem.good", ("%s %s %d"):format(mark, name, new))
end

--- A template that shows the pinned skill, with nothing pinned, reads "Professions and Skills"
--- (owner feedback round 3: no pin is the default, and the feed then never guesses a skill).
local function unpinned(ctx)
    return ctx.pinned == nil and template():find("{pinned}", 1, true) ~= nil
end

local function feedText(ctx)
    if NS.IsStoodDown() then return L["Off"] end
    if flash then return flash end
    if unpinned(ctx) then return L["Professions and Skills"] end
    local out = NS.Template.Render(template(), ctx)
    if out:gsub("[%s%p]", "") == "" then return B.LABEL end   -- never a blank cell
    return out
end

--- Re-render the feed's text; an unchanged text is not re-assigned (each write is a display
--- callback).
function B.Refresh()
    if NS.IsStoodDown() then flash = nil end
    local new = feedText(B.Context())
    if rendered ~= new then
        rendered = new
        if object then object.text = new end
    end
end

--- The feed's text now, and its LibDataBroker object (nil without the library).
function B.Text() return rendered end
function B.Object() return object end

local function endFlash()
    flashTimer = nil
    flash = nil
    B.Refresh()
end

--- Flash "^ <name> <new>" on the feed for profile.broker.flashSeconds.
function B.Flash(key, new)
    local e = model and model.byKey[key]   -- the live model: a flash is always a live skill-up
    flash = flashText(e and e.name or key, new)
    if flashTimer then NS.addon:CancelTimer(flashTimer) end
    flashTimer = NS.addon:ScheduleTimer(endFlash, B.FlashSeconds())
    B.Refresh()
end

-- ---------------------------------------------------------------------------------------------
-- The bus
-- ---------------------------------------------------------------------------------------------

local function indexStats(m)
    local index = {}
    for _, group in ipairs(NS.StatData.GROUPS) do
        for _, e in ipairs(type(m) == "table" and m[group] or {}) do index[e.key] = e end
    end
    return index
end

local function onSkillsUpdated(_, m)
    if type(m) == "table" then model = m end
    B.Refresh()
end

local function onSkillUp(_, key, old, new)
    local up = (tonumber(new) or 0) - (tonumber(old) or 0)
    if up <= 0 then return end
    gains.total = gains.total + up
    gains.byKey[key] = (gains.byKey[key] or 0) + up
    last = { key = key, new = new }
    B.Flash(key, new)
end

local function onStatsUpdated(_, m)
    if type(m) ~= "table" then return end
    statsModel, statIndex = m, indexStats(m)
    B.Refresh()
end

B.target = NS.NewBusTarget()
if B.target then
    B.target:RegisterMessage(NS.MSG.SKILLS_UPDATED, onSkillsUpdated)
    B.target:RegisterMessage(NS.MSG.SKILL_UP, onSkillUp)
    B.target:RegisterMessage(NS.MSG.STATS_UPDATED, onStatsUpdated)
    B.target:RegisterMessage(NS.MSG.BONUSES_UPDATED, function() B.Refresh() end)
end

-- ---------------------------------------------------------------------------------------------
-- The mini bar: the shared bar widget (NS.Bar, "mini" style) on a tooltip line
-- ---------------------------------------------------------------------------------------------

local barPool = NS.Bar.NewPool()
local barsDrawn = 0

local function lineRegion(tip, n)
    local name = tip.GetName and tip:GetName()
    return name and _G[name .. "TextLeft" .. n] or nil
end

--- Draw one mini bar on tooltip line `n` from NS.Bar values ({ value, max, bonus, bonusKind,
--- color, ... }: NS.Rows.SkillValues / StatValues). The bar clamps the bonus to its end.
local function drawMiniBar(tip, n, values)
    local line = lineRegion(tip, n)
    if not line then return false end
    local bar = NS.Bar.Acquire(barPool, tip, "mini")
    bar:SetFrameLevel(tip:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    bar:ClearAllPoints()
    bar:SetPoint("LEFT", line, "LEFT", NAME_W, 0)
    bar:SetPoint("RIGHT", tip, "RIGHT", -VALUE_W, 0)
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
    if widest <= 0 then return VALUE_W end
    return math.min(VALUE_W, math.ceil(widest) + B.TIP_INSET + B.VALUE_GAP)
end

--- Pull every bar's right end in to the value column's real width.
local function fitBars(tip)
    local inset = B.ValueInset(tip)
    for _, bar in ipairs(barPool.active or {}) do
        local line = bar.skmLine and lineRegion(tip, bar.skmLine)
        if line then
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", line, "LEFT", NAME_W, 0)
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
    h = h or NS.Bar.TooltipRowHeight("mini")
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

--- The mini bars on the open tooltip (NS.Bar widgets; the suites read them).
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
    band(tip, n, NS.Bar.TooltipRowHeight("mini"), NS.Skin.Color("list.stripe"))
end

-- ---------------------------------------------------------------------------------------------
-- Row hit areas: plain buttons over the tooltip's lines, so a row can be clicked (never secure)
-- ---------------------------------------------------------------------------------------------

local hitPool = NS.Pool.New()

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

local function newHit()
    local hit = CreateFrame("Button", nil, UIParent)
    hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    hit:SetScript("OnClick", function(self, button) B.OpenRow(self.row, button, self) end)
    hit:SetScript("OnEnter", showHover)
    hit:SetScript("OnLeave", hideHovers)
    return hit
end

--- The tooltip's clickable rows now (the suites read them).
function B.Hits() return hitPool.active or {} end

local function addHit(tip, row)
    local line = lineRegion(tip, row.line)
    if not line then return end
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

local ownTip   -- this file's own tooltip frame, made on the first skinned show (skinnedTip, below)

local function releaseAll()
    unsizeRows()
    -- Tooltips > Font size undone on whichever tooltip carried it (a no-op on one never sized).
    if ownTip then NS.Chrome.RestoreTooltipFonts(ownTip) end
    if GameTooltip then NS.Chrome.RestoreTooltipFonts(GameTooltip) end
    releaseBands()
    hideHovers()
    NS.Bar.ReleaseAll(barPool)
    NS.Pool.ReleaseAll(hitPool)
end

-- ---------------------------------------------------------------------------------------------
-- Tooltip content
-- ---------------------------------------------------------------------------------------------

--- A section's title: the window's block title (Primary Professions, Stats · Base & Combat, ...).
local function sectionTitle(id)
    local d = NS.BlockDefs[id]
    return d and d.title or id
end

--- A skill's bar values, and the token its bonus number is colored in (temp or permanent).
local function skillBar(e)
    local values = NS.Rows.SkillValues(e)
    values.color = NS.Rows.FillColor(e)
    return values, values.bonusKind == "temp" and "sm.bonusTemp" or "sm.bonusPerm"
end

local function skillValue(e, bonus)
    if not e.learned then return colored("gtip.muted", L["Not learned"]) end
    local text = ("%d/%d"):format(e.rank or 0, e.max or 0)
    local mod = tonumber(e.modifier) or 0
    if mod ~= 0 then text = text .. " " .. colored(bonus, (mod > 0 and "+" or "") .. mod) end
    local g = view().gains.byKey[e.key]
    if g and g > 0 then text = text .. "  " .. colored("sem.good", "+" .. g) end
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
    tip:AddDoubleLine(colored(nameColor(e), e.name or e.key), value)
    local n = tip:NumLines()
    sizeRow(tip, n)
    stripe(tip, n, i)
    if e.learned and (e.max or 0) > 0 and showsBar() then drawMiniBar(tip, n, values) end
    return { line = n, kind = "skill", key = e.key }
end

--- A section's header: the window's block title in the header text color on the header band, a
--- little taller than a row. No chevron: the tooltip's sections do not collapse.
local function addTitle(tip, title)
    tip:AddLine(colored("list.header.text", title))
    local n = tip:NumLines()
    local h = NS.Bar.TooltipRowHeight("mini") + B.HEADER_PAD
    sizeRow(tip, n, h)
    local c = NS.Bar.Color("sm.headerBg")
    if c then band(tip, n, h, c[1], c[2], c[3], c[4]) end
end

--- Section `id`'s entries in its block's sort order (NS.Blocks.SortEntries, owner feedback round 3).
local function sorted(id, list)
    return NS.Blocks.SortEntries(id, list, function(e) return e end)
end

local function addSkillSection(tip, rows, section, m)
    local i, list = 0, {}
    for _, key in ipairs(m.order[section] or {}) do
        if m.byKey[key] then list[#list + 1] = m.byKey[key] end
    end
    for _, e in ipairs(sorted(section, list)) do
        local key = e.key
        if not B.HiddenInTooltip("skill", key) then
            if i == 0 then addTitle(tip, sectionTitle(section)) end
            i = i + 1
            rows[#rows + 1] = addSkillRow(tip, e, i)
        end
    end
end

local function addStatRow(tip, e, i)
    local value = showsValue() and colored("gtip.value", e.display or "") or ""
    tip:AddDoubleLine(colored("gtip.value", e.label or e.key), value)
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

local function addStatsSection(tip, rows)
    local sm = view().statsModel
    if not sm then
        tip:AddLine(colored("gtip.muted", L["No stats to show yet."]))
        return
    end
    for _, group in ipairs(NS.StatData.GROUPS) do
        local i, list = 0, {}
        for n, e in ipairs(sm[group] or {}) do list[n] = e end
        for _, e in ipairs(sorted("stats_" .. group, list)) do
            if not B.HiddenInTooltip("stat", e.key) then
                if i == 0 then addTitle(tip, sectionTitle("stats_" .. group)) end
                i = i + 1
                rows[#rows + 1] = addStatRow(tip, e, i)
            end
        end
    end
end

-- One shown section. Answers whether the no-model line has been written (once for the four skill
-- sections, before the first test-mode or live model lands).
local function fillSection(tip, rows, section, m, told)
    if section == "stats" then
        addStatsSection(tip, rows)
        return told
    end
    if m then
        addSkillSection(tip, rows, section, m)
        return told
    end
    if not told then tip:AddLine(colored("gtip.muted", L["No skills to show yet."])) end
    return true
end

local function fillSections(tip, rows)
    local m, told = view().model, false
    for _, section in ipairs(B.SECTIONS) do
        if B.SectionShown(section) then told = fillSection(tip, rows, section, m, told) end
    end
end

--- Test mode's line (owner feedback round 6, R6-2): the main window's strip text in the skin's
--- warning color, added to `tip` while test mode is on. Answers whether it added the line. Any
--- tooltip this addon fills calls it right under its title.
function B.AddTestModeLine(tip)
    if not NS.IsTestMode() then return false end
    tip:AddLine(colored("sem.warn", L["Test mode: the skills shown are sample data."]))
    return true
end

--- Fill `tip` (the feed's tooltip, or a stand-in) with the shown sections. Answers the clickable
--- rows, each { line, kind = "skill" | "stat", key }.
function B.FillTooltip(tip)
    releaseAll()
    barsDrawn = 0
    local rows = {}
    if tip.SetMinimumWidth then tip:SetMinimumWidth(B.MinWidth()) end
    tip:AddDoubleLine(colored("gtip.title", B.LABEL),
        colored("gtip.muted", L["+%d this session"]:format(view().gains.total)))
    B.AddTestModeLine(tip)
    if NS.IsStoodDown() then
        tip:AddLine(colored("gtip.muted", L["Ka0s Skill Master is disabled."]))
        return rows
    end
    fillSections(tip, rows)
    fitBars(tip)
    tip:AddLine(colored("gtip.footer", L["Click label: toggle window \194\183 Right-click label: options \194\183 Rows: click to open, right-click for the menu"]))
    return rows
end

-- ---------------------------------------------------------------------------------------------
-- Clicks (design §6.5, Feed row): never secure
-- ---------------------------------------------------------------------------------------------

local function mainWindow()
    local W = NS.MainWindow
    return type(W) == "table" and W or nil
end

local function toggleWindow()
    local W = mainWindow()
    if W and type(W.Toggle) == "function" then W.Toggle() end
end

--- A crafting row opens the main window scrolled to it (or just shown, before the blocks land).
local function showInWindow(key)
    local W = mainWindow()
    if not W then return end
    if type(W.ShowAndScrollTo) == "function" then return W.ShowAndScrollTo(key) end
    if type(W.Show) == "function" then return W.Show() end
end

local function openCharacter(tab)
    if type(ToggleCharacter) == "function" then ToggleCharacter(tab) end
end

local function openSkillRow(key)
    local m = view().model
    local e = m and m.byKey[key]
    if e and not e.learned then
        local popup = NS.TrainerPopup
        if type(popup) == "table" and type(popup.Show) == "function" then return popup.Show(key) end
        return showInWindow(key)
    end
    local cat = NS.SkillCatalog[key]
    if cat and cat.openSpell then return showInWindow(key) end
    local I = NS.Interact
    if cat and cat.tradeSkill and I then return I.OpenTradeSkill(key) end
    if I then return I.OpenSkills(key) end
    return openCharacter("SkillsFrame")   -- Forever's Skills tab (round 4)
end

--- The row menu for a tooltip row (owner feedback round 3): the window's own (NS.Interact.Menu,
--- pin, waypoint, trainers, hide) on the tooltip row's entry. Answers the menu, or nil.
function B.RowMenu(row, anchor)
    local I, v = NS.Interact, view()
    local e
    if row.kind == "skill" then e = v.model and v.model.byKey[row.key]
    elseif row.kind == "stat" then e = v.statIndex and v.statIndex[row.key] end
    if not (I and e) then return nil end
    return I.Menu({ kind = row.kind, entry = e, frame = anchor, surface = "broker" })
end

--- One tooltip row's click: left opens what the row opens, right the row menu.
function B.OpenRow(row, button, anchor)
    if type(row) ~= "table" then return end
    if button == "RightButton" then return B.RowMenu(row, anchor) end
    if row.kind == "stat" then return openCharacter("PaperDollFrame") end
    if row.kind == "skill" then return openSkillRow(row.key) end
end

--- The feed options: the Broker settings page through the options library's page opener, else
--- the main settings panel (the library absent: its stub prints why), else nothing.
function B.OpenSettings()
    local H = NS.Helpers
    if type(H) == "table" and type(H.OpenOptionsPanel) == "function" then
        return H.OpenOptionsPanel(B.SETTINGS_PAGE)
    end
    if type(NS.OpenOptionsPanel) == "function" then return NS.OpenOptionsPanel() end
    return nil
end

--- The feed's own cell: left toggles the main window, right opens the feed options.
function B.OnClick(_, button)
    if button == "RightButton" then return B.OpenSettings() end
    toggleWindow()
end

-- ---------------------------------------------------------------------------------------------
-- The tooltip frame (FB-13): the shared GameTooltip as it is, or this file's own, skinned
-- ---------------------------------------------------------------------------------------------

-- ownTip: declared above releaseAll, made on the first skinned show

local function skinnedTip()
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", B.TIP_NAME, UIParent, "GameTooltipTemplate")
    end
    return ownTip
end

--- The frame the tooltip draws on now: the feed's own skinned frame while broker.tooltip.skin is
--- on, else the shared GameTooltip.
function B.Tip()
    if B.Skinned() then return skinnedTip() end
    return GameTooltip
end

--- The feed's own tooltip frame, or nil before the first skinned show (the suites read it).
function B.OwnTip() return ownTip end

-- The tooltip's line font strings, found by the frame's global name as the client names them.
local function eachLine(tip, fn)
    local name = tip.GetName and tip:GetName()
    local count = tonumber(tip.NumLines and tip:NumLines()) or 0
    if not name then return end
    for n = 1, count do
        fn(n, _G[name .. "TextLeft" .. n], _G[name .. "TextRight" .. n])
    end
end

--- Paint the owned frame from the active skin: the window shell (backdrop and border, no title
--- band) and every line's font, the title line in the title face. Run after Show, since a
--- tooltip's OnShow lays the template's own backdrop again.
local function paintTip(tip)
    local S = NS.Skin
    S.Shell(tip, { noTopBar = true })
    eachLine(tip, function(n, left, right)
        if left then S.Text(left, n == 1 and "title" or "body") end
        if right then S.Text(right, "body") end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- Showing and hiding the tooltip: it stays while the pointer is on the cell or the tooltip
-- ---------------------------------------------------------------------------------------------

local hooked, owner, poll, current = {}, nil, nil, nil

local function stopPoll()
    if poll then NS.addon:CancelTimer(poll) end
    poll = nil
end

-- The shared GameTooltip hides and clears for every frame that uses it: only the feed's own show
-- lets its bars and hit areas go.
local function hookTooltip(tip)
    if hooked[tip] then return end
    hooked[tip] = true
    tip:HookScript("OnHide", function()
        if current ~= tip then return end
        releaseAll() owner = nil current = nil stopPoll()
    end)
    if tip.HasScript and tip:HasScript("OnTooltipCleared") then
        tip:HookScript("OnTooltipCleared", function() if current == tip then releaseAll() end end)
    end
end

local function anchor(tip, frame)
    tip:SetOwner(frame, "ANCHOR_NONE")
    tip:ClearAllPoints()
    local _, y = frame:GetCenter()
    local top = y and UIParent:GetHeight() and y > UIParent:GetHeight() / 2
    if top then tip:SetPoint("TOP", frame, "BOTTOM", 0, -2) else tip:SetPoint("BOTTOM", frame, "TOP", 0, 2) end
end

--- Take the feed's tooltip down, whichever frame it is on (the skin switch's write).
function B.HideTooltip()
    stopPoll()
    local tip = current
    if tip and tip:IsShown() then tip:Hide() end
    releaseAll()
    owner, current = nil, nil
end

function B.OnEnter(frame)
    local tip = B.Tip()
    stopPoll()
    if current and current ~= tip then B.HideTooltip() end
    hookTooltip(tip)
    anchor(tip, frame)
    owner, current = frame, tip
    local rows = B.FillTooltip(tip)
    tip:Show()
    if tip == ownTip then paintTip(tip) end
    -- Tooltips > Font size, after the skin's fonts, then one more layout pass for both.
    NS.Chrome.TooltipFontSize(tip, tipSettings().fontSize, 1)
    tip:Show()   -- a shown tooltip lays itself out again for the new fonts
    for _, row in ipairs(rows) do addHit(tip, row) end
end

local function stillHovered(tip)
    if tip:IsMouseOver() then return true end
    return owner ~= nil and owner.IsMouseOver ~= nil and owner:IsMouseOver()
end

--- Whether the tooltip is still the feed's: another frame may have taken the shared GameTooltip
--- since (SetOwner).
local function ownsTip(tip)
    if owner == nil or current ~= tip then return false end
    if type(tip.GetOwner) ~= "function" then return true end
    return tip:GetOwner() == owner
end

function B.OnLeave()
    local tip = current
    stopPoll()
    if not tip then return end
    poll = NS.addon:ScheduleRepeatingTimer(function()
        local mine = ownsTip(tip)
        if mine and tip:IsShown() and stillHovered(tip) then return end
        stopPoll()
        if mine then tip:Hide() end
        owner = nil
    end, HIDE_POLL)
end

-- ---------------------------------------------------------------------------------------------
-- The data object, built at load (LibDataBroker-1.1 loads in the TOC's # Libraries block)
-- ---------------------------------------------------------------------------------------------

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if LDB then
    object = LDB:NewDataObject(B.NAME, {
        type  = "data source",
        label = B.LABEL,
        text  = B.LABEL,
        icon  = NS.Constants.LOGO_ICON_PATH,
        OnClick = B.OnClick,
        OnEnter = function(frame) B.OnEnter(frame) end,
        OnLeave = function() B.OnLeave() end,
    })
else
    NS.Debug("Broker", "%s: LibDataBroker-1.1 absent, no data feed", addonName)
end
