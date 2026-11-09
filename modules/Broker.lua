local addonName, NS = ...
-- modules/Broker.lua — the four broker data feeds (design §6.7, plan Task 4.1): SkillMaster_All,
-- SkillMaster_Professions, SkillMaster_Weapons and SkillMaster_Stats, each a LibDataBroker-1.1
-- "data source" whose text is a template (modules/Template.lua), flashed on a skill-up, with a
-- GameTooltip of mini bars and clickable rows (design §6.5).
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

B.FEEDS = {
    { id = "all",         name = "SkillMaster_All",         label = L["Skill Master: All"] },
    { id = "professions", name = "SkillMaster_Professions", label = L["Skill Master: Professions"] },
    { id = "weapons",     name = "SkillMaster_Weapons",     label = L["Skill Master: Weapons"] },
    { id = "stats",       name = "SkillMaster_Stats",       label = L["Skill Master: Stats"] },
}

-- Which feeds flash for a skill-up in each category (the All feed flashes for every one).
local FLASH_FEEDS = {
    primary = { "all", "professions" }, secondary = { "all", "professions" },
    weapon = { "all", "weapons" }, other = { "all" },
}
FLASH_FEEDS.defense = { "all", "weapons" }

-- The settings page a feed's right-click opens (the Broker page's registration key). The library
-- opens the main panel when no page of that key is built.
B.SETTINGS_PAGE = "broker"

-- ---------------------------------------------------------------------------------------------
-- State: the last models the bus handed over, the session's gains, the flash
-- ---------------------------------------------------------------------------------------------

local model, statIndex, statsModel
local gains = { total = 0, byKey = {} }
local last
local flash, flashTimer = {}, nil
local objects, texts = {}, {}

--- Back to a fresh session (the suites call this between cases).
function B.ResetSession()
    gains = { total = 0, byKey = {} }
    last, flash = nil, {}
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
    gains, last, flash = copyGains(st.gains), st.last, {}
    if flashTimer then NS.addon:CancelTimer(flashTimer) end
    flashTimer = nil
    B.Refresh()
end

--- What the feeds draw: B.source's answer while one is set, else the live state.
local function view()
    local v = B.source and B.source()
    if type(v) == "table" then return v end
    return { model = model, statsModel = statsModel, statIndex = statIndex, gains = gains, last = last }
end

local function setting(path, fallback)
    local v = NS.GetSetting and NS.db and NS.GetSetting(path)
    if v == nil then return fallback end
    return v
end

function B.FlashSeconds() return tonumber(setting("broker.flashSeconds", 5)) or 5 end

local function template(id)
    local t = setting("broker.templates." .. id, nil)
    return type(t) == "string" and t or ""
end

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

function B.Context()
    local v = view()
    return {
        skills = v.model, stat = v.statIndex, gains = v.gains.total, last = v.last,
        pinned = pinnedKey(), mainHand = B.MainHandSkill(),
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

local function feedText(feed, ctx)
    if NS.IsStoodDown() then return L["Off"] end
    if flash[feed.id] then return flash[feed.id] end
    local text = NS.Template.Render(template(feed.id), ctx)
    if text:gsub("[%s%p]", "") == "" then return feed.label end   -- never a blank cell
    return text
end

--- Re-render every feed's text; an unchanged text is not re-assigned (each write is a display
--- callback).
function B.Refresh()
    if NS.IsStoodDown() then flash = {} end
    local ctx = B.Context()
    for _, feed in ipairs(B.FEEDS) do
        local text = feedText(feed, ctx)
        if texts[feed.id] ~= text then
            texts[feed.id] = text
            if objects[feed.id] then objects[feed.id].text = text end
        end
    end
end

function B.Text(id) return texts[id] end
function B.Object(id) return objects[id] end

local function endFlash()
    flashTimer = nil
    flash = {}
    B.Refresh()
end

--- Flash "^ <name> <new>" on the skill's feeds for profile.broker.flashSeconds.
function B.Flash(key, new)
    local e = model and model.byKey[key]   -- the live model: a flash is always a live skill-up
    local cat = NS.SkillCatalog[key]
    local group = (cat and cat.kind == "defense") and "defense" or (e and e.category) or "other"
    local text = flashText(e and e.name or key, new)
    for _, id in ipairs(FLASH_FEEDS[group] or FLASH_FEEDS.other) do flash[id] = text end
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

local function addSkillRow(tip, e, opts)
    local values, bonus = skillBar(e)
    tip:AddDoubleLine(colored(nameColor(e, opts.belowCap), e.name or e.key), skillValue(e, bonus))
    local n = tip:NumLines()
    if e.learned and (e.max or 0) > 0 then drawMiniBar(tip, n, values) end
    return { line = n, kind = "skill", key = e.key }
end

local function addTitle(tip, text)
    tip:AddLine(colored("text.accent", text:upper()))
end

local function addSkillGroup(tip, rows, title, keys, opts)
    local any, m = false, view().model
    for _, key in ipairs(keys) do
        local e = m.byKey[key]
        if e and (opts.filter == nil or opts.filter(e)) then
            if not any then addTitle(tip, title) any = true end
            rows[#rows + 1] = addSkillRow(tip, e, opts)
        end
    end
end

local SKILL_SECTIONS = {
    all = { "primary", "secondary", "weapon", "other" },
    professions = { "primary", "secondary" },
    weapons = { "weapon", "defense" },
}

local function isDefense(e)
    local cat = NS.SkillCatalog[e.key]
    return cat ~= nil and cat.kind == "defense"
end

local function fillSkills(tip, id, rows)
    local m = view().model
    if not m then
        tip:AddLine(colored("gtip.muted", L["No skills to show yet."]))
        return
    end
    local opts = { belowCap = id == "weapons" }
    for _, section in ipairs(SKILL_SECTIONS[id]) do
        if section == "defense" then
            addSkillGroup(tip, rows, L["Other"], m.order.other, { belowCap = true, filter = isDefense })
        else
            addSkillGroup(tip, rows, GROUP_TITLES[section], m.order[section] or {}, opts)
        end
    end
end

local function fillStats(tip, rows)
    local sm = view().statsModel
    if not sm then
        tip:AddLine(colored("gtip.muted", L["No stats to show yet."]))
        return
    end
    for _, group in ipairs(NS.StatData.GROUPS) do
        local list = sm[group] or {}
        if #list > 0 then addTitle(tip, GROUP_TITLES[group]) end
        for _, e in ipairs(list) do
            tip:AddDoubleLine(colored("gtip.body", e.label or e.key), colored("gtip.value", e.display or ""))
            local n = tip:NumLines()
            local values = NS.Rows.StatValues(e)
            values.color = NS.Rows.FillColor(e, true)
            drawMiniBar(tip, n, values)
            rows[#rows + 1] = { line = n, kind = "stat", key = e.key }
        end
    end
end

local TITLES = {
    all = L["Skill Master: All skills"], professions = L["Skill Master: Professions"],
    weapons = L["Skill Master: Weapon Skills"], stats = L["Skill Master: Stats"],
}

--- Fill `tip` (GameTooltip, or a stand-in) for feed `id`. Answers the clickable rows,
--- each { line, kind = "skill" | "stat", key }.
function B.FillTooltip(id, tip)
    releaseAll()
    barsDrawn = 0
    local rows = {}
    if tip.SetMinimumWidth then tip:SetMinimumWidth(MIN_W) end
    tip:AddDoubleLine(colored("gtip.title", TITLES[id] or NS.Constants.BRAND),
        colored("gtip.muted", L["+%d this session"]:format(view().gains.total)))
    if NS.IsStoodDown() then
        tip:AddLine(colored("gtip.muted", L["Ka0s Skill Master is disabled."]))
        return rows
    end
    if id == "stats" then fillStats(tip, rows) else fillSkills(tip, id, rows) end
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
-- Showing and hiding GameTooltip: it stays while the pointer is on the cell or the tooltip
-- ---------------------------------------------------------------------------------------------

local hooked, owner, poll = false, nil, nil

local function stopPoll()
    if poll then NS.addon:CancelTimer(poll) end
    poll = nil
end

local function hookTooltip(tip)
    if hooked then return end
    hooked = true
    tip:HookScript("OnHide", function() releaseAll() owner = nil stopPoll() end)
    if tip.HasScript and tip:HasScript("OnTooltipCleared") then tip:HookScript("OnTooltipCleared", releaseAll) end
end

local function anchor(tip, frame)
    tip:SetOwner(frame, "ANCHOR_NONE")
    tip:ClearAllPoints()
    local _, y = frame:GetCenter()
    local top = y and UIParent:GetHeight() and y > UIParent:GetHeight() / 2
    if top then tip:SetPoint("TOP", frame, "BOTTOM", 0, -2) else tip:SetPoint("BOTTOM", frame, "TOP", 0, 2) end
end

function B.OnEnter(id, frame)
    local tip = GameTooltip
    stopPoll()
    hookTooltip(tip)
    anchor(tip, frame)
    owner = frame
    local rows = B.FillTooltip(id, tip)
    tip:Show()
    for _, row in ipairs(rows) do addHit(tip, row) end
end

local function stillHovered(tip)
    if tip:IsMouseOver() then return true end
    return owner ~= nil and owner.IsMouseOver ~= nil and owner:IsMouseOver()
end

--- Whether GameTooltip is still the feed's: another frame may have taken it since (SetOwner).
local function ownsTip(tip)
    if owner == nil then return false end
    if type(tip.GetOwner) ~= "function" then return true end
    return tip:GetOwner() == owner
end

function B.OnLeave()
    local tip = GameTooltip
    stopPoll()
    poll = NS.addon:ScheduleRepeatingTimer(function()
        local mine = ownsTip(tip)
        if mine and tip:IsShown() and stillHovered(tip) then return end
        stopPoll()
        if mine then tip:Hide() end
        owner = nil
    end, HIDE_POLL)
end

-- ---------------------------------------------------------------------------------------------
-- The data objects, built at load (LibDataBroker-1.1 loads in the TOC's # Libraries block)
-- ---------------------------------------------------------------------------------------------

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if LDB then
    for _, feed in ipairs(B.FEEDS) do
        local id = feed.id
        objects[id] = LDB:NewDataObject(feed.name, {
            type  = "data source",
            label = feed.label,
            text  = feed.label,
            icon  = NS.Constants.LOGO_ICON_PATH,
            OnClick = B.OnClick,
            OnEnter = function(frame) B.OnEnter(id, frame) end,
            OnLeave = function() B.OnLeave() end,
        })
    end
else
    NS.Debug("Broker", "%s: LibDataBroker-1.1 absent, no data feeds", addonName)
end
