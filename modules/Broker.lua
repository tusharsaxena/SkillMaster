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
local NAME_W, VALUE_W, MIN_W = 128, 124, 380   -- the bar's height is profile.bars.miniHeight
local HIDE_POLL = 0.1          -- seconds between the tooltip's leave checks
local DOT = " \194\183 "

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

local function feedText(ctx)
    if NS.IsStoodDown() then return L["Off"] end
    if flash then return flash end
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
    bar:SetValues(values)
    barsDrawn = barsDrawn + 1
    return true
end

function B.BarsDrawn() return barsDrawn end

--- The mini bars on the open tooltip (NS.Bar widgets; the suites read them).
function B.Bars() return barPool.active or {} end

-- ---------------------------------------------------------------------------------------------
-- Row hit areas: plain buttons over the tooltip's lines, so a row can be clicked (never secure)
-- ---------------------------------------------------------------------------------------------

local hitPool = NS.Pool.New()

local function newHit()
    local hit = CreateFrame("Button", nil, UIParent)
    hit:RegisterForClicks("LeftButtonUp")
    hit:SetScript("OnClick", function(self, button) B.OpenRow(self.row, button) end)
    return hit
end

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

local function releaseAll()
    NS.Bar.ReleaseAll(barPool)
    NS.Pool.ReleaseAll(hitPool)
end

-- ---------------------------------------------------------------------------------------------
-- Tooltip content
-- ---------------------------------------------------------------------------------------------

local GROUP_TITLES = {
    primary = L["Primary"], secondary = L["Secondary"], weapon = L["Weapon"], other = L["Other"],
    base = L["Base"], spell = L["Spell"], defense = L["Defense"], utility = L["Utility"],
}

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

local function nameColor(e, highlightBelowCap)
    if not e.learned then return "gtip.muted" end
    if highlightBelowCap and (e.rank or 0) < (e.max or 0) then return "sem.warn" end
    return "gtip.body"
end

-- A line honors Rows show (bars.rowDisplay) as the window's rows do: Bar only leaves the value
-- column empty, Value only draws no mini bar. An unlearned skill's "Not learned" is no value.
local function showsBar() return NS.Rows.Display() ~= "text" end
local function showsValue() return NS.Rows.Display() ~= "bar" end

local function isDefense(e)
    local cat = NS.SkillCatalog[e.key]
    return cat ~= nil and cat.kind == "defense"
end

-- A weapon skill, and Defense, below its cap draws its name in the warning color (the old Weapons
-- feed's highlight).
local function belowCapHighlight(section, e)
    return section == "weapon" or isDefense(e)
end

local function addSkillRow(tip, e, section)
    local values, bonus = skillBar(e)
    local value = (showsValue() or not e.learned) and skillValue(e, bonus) or ""
    tip:AddDoubleLine(colored(nameColor(e, belowCapHighlight(section, e)), e.name or e.key), value)
    local n = tip:NumLines()
    if e.learned and (e.max or 0) > 0 and showsBar() then drawMiniBar(tip, n, values) end
    return { line = n, kind = "skill", key = e.key }
end

local function addTitle(tip, title)
    tip:AddLine(colored("text.accent", title:upper()))
end

local function addSkillSection(tip, rows, section, m)
    local any = false
    for _, key in ipairs(m.order[section] or {}) do
        local e = m.byKey[key]
        if e and not B.HiddenInTooltip("skill", key) then
            if not any then addTitle(tip, GROUP_TITLES[section]) any = true end
            rows[#rows + 1] = addSkillRow(tip, e, section)
        end
    end
end

local function addStatRow(tip, e)
    local value = showsValue() and colored("gtip.value", e.display or "") or ""
    tip:AddDoubleLine(colored("gtip.body", e.label or e.key), value)
    local n = tip:NumLines()
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
        local any = false
        for _, e in ipairs(sm[group] or {}) do
            if not B.HiddenInTooltip("stat", e.key) then
                if not any then addTitle(tip, L["Stats"] .. DOT .. GROUP_TITLES[group]) any = true end
                rows[#rows + 1] = addStatRow(tip, e)
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

--- Fill `tip` (the feed's tooltip, or a stand-in) with the shown sections. Answers the clickable
--- rows, each { line, kind = "skill" | "stat", key }.
function B.FillTooltip(tip)
    releaseAll()
    barsDrawn = 0
    local rows = {}
    if tip.SetMinimumWidth then tip:SetMinimumWidth(MIN_W) end
    tip:AddDoubleLine(colored("gtip.title", B.LABEL),
        colored("gtip.muted", L["+%d this session"]:format(view().gains.total)))
    if NS.IsStoodDown() then
        tip:AddLine(colored("gtip.muted", L["Ka0s Skill Master is disabled."]))
        return rows
    end
    fillSections(tip, rows)
    tip:AddLine(colored("gtip.footer", L["Click label: toggle window \194\183 Click row: open its window \194\183 Right-click: feed options"]))
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
    return openCharacter("SkillFrame")
end

--- One tooltip row's click.
function B.OpenRow(row)
    if type(row) ~= "table" then return end
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

local ownTip   -- made on the first skinned show

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
    if tip == ownTip then
        paintTip(tip)
        tip:Show()   -- a shown tooltip lays itself out again for the skin's fonts
    end
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
