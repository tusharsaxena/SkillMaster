local _, NS = ...
-- modules/RowTooltip.lua — the row tooltip (design §6.2/§6.3, mockup "Tooltips", plan Task 3.3): the
-- numbers with the effective rank, the bar, every bonus source (a temp one with its time left), the
-- session's gains and the ETA (T4.3's session log, when loaded), the next rank and its trainer, a
-- weapon's distance to its cap, the gathering and fishing helpers (design §12 item 4), a stat's
-- markers and scale, and the click hints. Drawn on GameTooltip with one tooltip-style NS.Bar laid
-- under its numbers line; GameTooltip is never re-skinned (Skin's Tooltip is for library tooltips).
--
-- NS.RowTooltip.Lines(entry, kind) -> { { left, right, tone, rightTone } | { bar = true } |
--   { divider = true } }, pure; tones: body, muted, heading, accent, temp, perm, good, warn, bad.
-- NS.RowTooltip.Show(row), .Hide(row), .Bar()

NS.RowTooltip = {}
local RT = NS.RowTooltip
local L = NS.L
local Bar = NS.Bar
local DOT = " \194\183 "

local CATEGORY = { primary = L["Primary"], secondary = L["Secondary"], weapon = L["Weapon"], other = L["Other"] }

local function line(out, left, right, tone, rightTone)
    out[#out + 1] = { left = left, right = right, tone = tone or "body", rightTone = rightTone or tone or "body" }
end

-- ---------------------------------------------------------------------------------------------
-- Skill lines
-- ---------------------------------------------------------------------------------------------

local function numbers(out, e)
    local mod = tonumber(e.modifier) or 0
    local text = Bar.Text(e.rank, mod, e.max)
    if mod ~= 0 then text = text .. DOT .. L["effective %d"]:format(e.rank + mod) end
    line(out, text, nil, "body")
    out[#out + 1] = { bar = true }
end

local function bonusLines(out, e)
    line(out, L["Bonuses"], nil, "heading")
    local b = NS.Bonuses and NS.Bonuses:Breakdown(e.key)
    local sources = b and b.sources or {}
    if #sources == 0 then
        line(out, L["Racial / items / buffs"], L["none"], "muted")
        return
    end
    for _, s in ipairs(sources) do
        local amount = ("%+d"):format(s.amount or 0)
        if s.kind == "temp" and s.expires then
            amount = amount .. DOT .. Bar.FormatTimer(s.expires - GetTime())
        end
        line(out, s.label, amount, "body", s.kind == "temp" and "temp" or "perm")
        out[#out].tone = s.kind == "temp" and "temp" or "perm"
    end
end

--- An ETA as the mockup reads it: "~30 m", "~14 h".
function RT.FormatETA(sec)
    if sec < 3600 then return L["~%d m"]:format(math.max(1, math.floor(sec / 60 + 0.5))) end
    return L["~%d h"]:format(math.floor(sec / 3600 + 0.5))
end

local function sessionLines(out, e)
    local log = NS.Preview.Log()
    if not log then return end
    -- This skill's points and its rate over the whole session (the mockup's "+6 (3 / h)").
    local gains = log:GainsFor(e.key)
    if gains > 0 then
        local rate = math.floor(log:Rate(math.huge, nil, e.key) + 0.5)
        line(out, L["This session"], L["+%d (%d / h)"]:format(gains, rate), "muted", "body")
    end
    local eta = log:ETA(e.key)
    if type(eta) == "number" then
        line(out, L["ETA to %d"]:format(e.max), L["%s at this rate"]:format(RT.FormatETA(eta)), "muted", "body")
    end
end

local function trainerText(t)
    local text = ("%s, %s"):format(t.name, NS.Rows.Place(t))
    return text .. NS.Waypoints.UnverifiedMark(t)
end

local function rankLines(out, e)
    local nr = NS.Trainers and NS.Trainers:NextRank(e.key, e.rank, e.max)
    if not nr then return end
    line(out, L["Next rank"], L["%s at %d \194\183 Lv %d"]:format(nr.rankName, e.max, nr.minLevel), "muted", "body")
    if nr.trainers[1] then line(out, L["Trainer"], trainerText(nr.trainers[1]), "muted", "body") end
end

local function weaponLines(out, e)
    local level = NS.Preview.Character().level or 0
    local cap = NS.SkillHelpers.WeaponCap(level)
    line(out, L["Cap at your level"], L["%d (5 \195\151 %d)"]:format(cap, level), "muted", "body")
    local gap = cap - e.rank   -- the base rank's distance, as the weapon-gap alert measures it
    local tone, word = "good", L["fine"]
    if gap >= 25 then tone, word = "bad", L["far below"] elseif gap > 10 then tone, word = "warn", L["low"] end
    line(out, L["Below cap by"], ("%d" .. DOT .. "%s"):format(math.max(gap, 0), word), "muted", tone)
end

--- The rank that next raises the skinnable level: every 5 from 100, every 10 below.
local function skinBreakpoint(rank)
    if rank >= 100 then return rank - rank % 5 + 5 end
    return rank - rank % 10 + 10
end

local HELPERS = {}

-- The Skills page's Gathering and fishing hints row (skills.helperTooltip).
local function helpersOn()
    return not (NS.GetSetting and NS.db and NS.GetSetting("skills.helperTooltip") == false)
end

function HELPERS.skinning(out, e)
    local H = NS.SkillHelpers
    line(out, L["Skinning %d: mobs up to Lv %d"]:format(e.rank, H.SkinnableLevel(e.rank)), nil, "body")
    local nxt = skinBreakpoint(e.rank)
    line(out, L["Next breakpoint: %d (mobs up to Lv %d)"]:format(nxt, H.SkinnableLevel(nxt)), nil, "muted")
end

local function nodeLines(out, e)
    local n = NS.SkillHelpers.Nodes(e.key, e.rank)
    if not n then return end
    local best = n.gatherable[#n.gatherable]
    if best then line(out, L["Can gather"], best.name, "muted", "body") end
    if n.next then line(out, L["Next"], L["%s at %d"]:format(n.next.name, n.next.need), "muted", "body") end
end
HELPERS.mining, HELPERS.herbalism = nodeLines, nodeLines

function HELPERS.fishing(out, e)
    local need = NS.SkillHelpers.FishingNeedHere()
    if not need then return end
    local zone = type(GetZoneText) == "function" and GetZoneText() or ""
    local mod = tonumber(e.modifier) or 0
    local ok = e.rank + mod >= need
    line(out, L["Fishing in %s needs ~%d (you: %d +%d)"]:format(zone, need, e.rank, mod),
        ok and L["no fish escape"] or L["fish will escape"], "body", ok and "good" or "warn")
end

local HINTS = {
    secure = L["Arrow: open the profession \194\183 Shift-click: link \194\183 Right-click: menu"],
    tradeskill = L["Arrow: open the profession \194\183 Shift-click: link \194\183 Right-click: menu"],
    skills = L["Arrow: Skills tab \194\183 Shift-click: link \194\183 Right-click: menu"],
    trainer = L["Arrow: trainers and waypoint \194\183 Right-click: menu"],
    paperdoll = L["Arrow: character panel \194\183 Shift-click: link \194\183 Right-click: menu"],
}

local function hint(out, kind, e)
    out[#out + 1] = { divider = true }
    line(out, HINTS[NS.Interact.Target({ kind = kind, entry = e })], nil, "muted")
end

local function skillLines(e)
    local out = {}
    line(out, e.name, CATEGORY[e.category] or L["Other"], "heading", "muted")
    if e.learned == false then
        line(out, NS.Rows.UnlearnedText(e), nil, "muted")
        hint(out, "skill", e)
        return out
    end
    numbers(out, e)
    bonusLines(out, e)
    out[#out + 1] = { divider = true }
    sessionLines(out, e)
    rankLines(out, e)
    if e.category == "weapon" or e.key == "defense" then weaponLines(out, e) end
    if HELPERS[e.key] and helpersOn() then HELPERS[e.key](out, e) end
    hint(out, "skill", e)
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Stat lines
-- ---------------------------------------------------------------------------------------------

local function statLines(e)
    local out = {}
    line(out, e.label, e.display, "heading", "body")
    out[#out + 1] = { bar = true }
    local pct = tostring(e.display or ""):find("%%") and "%" or ""
    -- The threshold lines follow Bars > Marks > Thresholds in the row tooltip, as its bar does (R6-4).
    for _, m in ipairs(Bar.ShowMarkers("tooltip") and e.markers or {}) do
        line(out, ("\194\183 %s%s %s"):format(tostring(m.value or ""), pct, m.label or ""), nil, "muted")
    end
    if e.ref then line(out, L["Scale: vs %s"]:format(tostring(e.ref) .. pct), nil, "muted") end
    hint(out, "stat", e)
    return out
end

--- The tooltip's lines for a skill or stat entry.
function RT.Lines(e, kind)
    if kind == "stat" then return statLines(e) end
    return skillLines(e)
end

-- ---------------------------------------------------------------------------------------------
-- Drawing on GameTooltip
-- ---------------------------------------------------------------------------------------------

local TONES = {
    body = "text.body", muted = "text.muted", heading = "text.heading", accent = "text.accent",
    good = "sem.good", warn = "sem.warn", bad = "sem.bad",
}

local function toneColor(tone)
    if tone == "temp" then return Bar.PlayerColor("bonusTemp", "sm.bonusTemp") end
    if tone == "perm" then return Bar.PlayerColor("bonusPerm", "sm.bonusPerm") end
    return Bar.Color(TONES[tone] or "text.body") or Bar.Color("sm.barText")
end

local tipBar

function RT.Bar() return tipBar end

-- The bar's line, sized to Bars > Main window tooltip row height; back to auto height (0) with
-- the bar, since GameTooltip keeps a font string's height for whoever fills the line next.
local sizedLine

-- The tooltip's own settings (the Tooltips page, owner feedback round 4).
local function tipSettings()
    local t = NS.db and NS.db.profile.tooltips
    return t and t.row or NS.defaults.profile.tooltips.row
end

local widened = false

local function hideBar()
    if tipBar then tipBar:Hide() end
    if sizedLine then sizedLine:SetHeight(0) sizedLine = nil end
    -- GameTooltip is shared: its lines' fonts and its minimum width go back for the next owner.
    if GameTooltip then NS.Chrome.RestoreTooltipFonts(GameTooltip) end
    if widened and GameTooltip and GameTooltip.SetMinimumWidth then GameTooltip:SetMinimumWidth(0) end
    widened = false
end

--- The one tooltip bar, on GameTooltip. It goes with the tooltip's CONTENT, not only with the
--- tooltip: SetOwner on a shown GameTooltip clears it (OnTooltipCleared) without hiding it, and a
--- bar hidden by OnHide alone stayed on screen over whatever the tooltip showed next, the broker
--- feed's rows among them (feedback round 2, FB-9).
local hooked = false
local function ensureHooks()
    if hooked then return end
    hooked = true
    GameTooltip:HookScript("OnHide", hideBar)
    if GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipCleared") then
        GameTooltip:HookScript("OnTooltipCleared", hideBar)
    end
end

local function ensureBar()
    ensureHooks()
    if tipBar then return tipBar end
    tipBar = Bar.Create(GameTooltip, "tooltip")
    return tipBar
end

local function addLine(l)
    local c, r = toneColor(l.tone), toneColor(l.rightTone)
    if l.right then
        GameTooltip:AddDoubleLine(l.left, l.right, c[1], c[2], c[3], r[1], r[2], r[3])
    else
        GameTooltip:AddLine(l.left, c[1], c[2], c[3], true)
    end
end

local function sizeBarLine(n)
    local fs = _G["GameTooltipTextLeft" .. n]
    if not (fs and fs.SetHeight) then return end
    fs:SetHeight(Bar.TooltipRowHeight("tooltip"))
    sizedLine = fs
end

local function placeBar(row, n)
    local b = ensureBar()
    b:ApplyStyle(Bar.ResolveStyle("tooltip"))   -- each show, so a skin switch since the last one lands
    local anchor = _G["GameTooltipTextLeft" .. n]
    b:ClearAllPoints()
    if anchor then
        local w = tonumber(tipSettings().barWidth) or 200   -- Tooltips > Bar width
        b:SetPoint("LEFT", anchor, "LEFT", 0, 0)
        b:SetWidth(w)
        b.knownWidth = w   -- the width Layout uses when the tooltip answers its own as secret
    end
    local stat = row.kind == "stat"
    local v = stat and NS.Rows.StatValues(row.entry) or (NS.Rows.SkillValues(row.entry))
    v.color = NS.Rows.FillColor(row.entry, stat)   -- the row's own fill: Color mode, the palette, Bar > Fill
    b:SetValues(v)
    b:Show()
end

--- Show `row`'s tooltip.
function RT.Show(row)
    if not (GameTooltip and row.entry) then return end
    hideBar()   -- shown again below only when this row's lines ask for it
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local n = 0
    local barAt
    for _, l in ipairs(RT.Lines(row.entry, row.kind)) do
        if l.bar then
            GameTooltip:AddLine(" ")
            n = n + 1
            barAt = n
        elseif l.divider then
            GameTooltip:AddLine(" ")
            n = n + 1
        else
            addLine(l)
            n = n + 1
        end
    end
    if barAt then sizeBarLine(barAt) end
    -- Tooltips > Font size on this tooltip's lines, and room for Tooltips > Bar width (both undone
    -- by hideBar when the tooltip clears or hides).
    ensureHooks()
    local t = tipSettings()
    NS.Chrome.TooltipFontSize(GameTooltip, t.fontSize, 1)
    if barAt and GameTooltip.SetMinimumWidth then
        GameTooltip:SetMinimumWidth((tonumber(t.barWidth) or 200) + 20)
        widened = true
    end
    GameTooltip:Show()
    if barAt then placeBar(row, barAt) end
end

function RT.Hide(row)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end
