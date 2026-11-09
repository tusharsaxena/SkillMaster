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

local function sessionLines(out, e)
    local log = NS.SessionLog
    if not log then return end
    local gains = log.GainsFor and log:GainsFor(e.key)
    local rate = log.Rate and log:Rate()
    if type(gains) == "number" then
        line(out, L["This session"], type(rate) == "number" and L["+%d (%d / h)"]:format(gains, rate)
            or ("+%d"):format(gains), "muted", "body")
    end
    local eta = log.ETA and log:ETA(e.key)
    if type(eta) == "number" then
        line(out, L["ETA to %d"]:format(e.max), L["~%s at this rate"]:format(Bar.FormatTimer(eta)), "muted", "body")
    end
end

local function trainerText(t)
    local text = ("%s, %s"):format(t.name, NS.Rows.Place(t))
    if t.verified == false then text = text .. " " .. L["(unverified)"] end
    return text
end

local function rankLines(out, e)
    local nr = NS.Trainers and NS.Trainers:NextRank(e.key, e.rank, e.max)
    if not nr then return end
    line(out, L["Next rank"], L["%s at %d \194\183 Lv %d"]:format(nr.rankName, e.max, nr.minLevel), "muted", "body")
    if nr.trainers[1] then line(out, L["Trainer"], trainerText(nr.trainers[1]), "muted", "body") end
end

local function weaponLines(out, e)
    local level = type(UnitLevel) == "function" and UnitLevel("player") or 0
    local cap = NS.SkillHelpers.WeaponCap(level)
    line(out, L["Cap at your level"], L["%d (5 \195\151 %d)"]:format(cap, level), "muted", "body")
    local gap = cap - (e.rank + (tonumber(e.modifier) or 0))
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

function HELPERS.skinning(out, e)
    local H = NS.SkillHelpers
    line(out, L["Skinning %d \226\134\146 mobs up to Lv %d"]:format(e.rank, H.SkinnableLevel(e.rank)), nil, "body")
    local nxt = skinBreakpoint(e.rank)
    line(out, L["Next breakpoint: %d \226\134\146 Lv %d"]:format(nxt, H.SkinnableLevel(nxt)), nil, "muted")
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
    secure = L["Click: open the profession \194\183 Shift-click: link \194\183 Right-click: menu"],
    skills = L["Click: Skills tab \194\183 Shift-click: link \194\183 Right-click: menu"],
    trainer = L["Click: trainers and waypoint \194\183 Right-click: menu"],
    paperdoll = L["Click: character panel \194\183 Shift-click: link \194\183 Right-click: menu"],
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
    if HELPERS[e.key] then HELPERS[e.key](out, e) end
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
    for _, m in ipairs(e.markers or {}) do
        line(out, ("\226\150\143 %s%s %s"):format(tostring(m.value or ""), pct, m.label or ""), nil, "muted")
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

local function ensureBar()
    if tipBar then return tipBar end
    tipBar = Bar.Create(GameTooltip, "tooltip")
    GameTooltip:HookScript("OnHide", function() tipBar:Hide() end)
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

local function placeBar(row, n)
    local b = ensureBar()
    local anchor = _G["GameTooltipTextLeft" .. n]
    b:ClearAllPoints()
    if anchor then
        b:SetPoint("LEFT", anchor, "LEFT", 0, 0)
        b:SetWidth(200)
    end
    if row.kind == "stat" then b:SetValues(NS.Rows.StatValues(row.entry)) else b:SetValues((NS.Rows.SkillValues(row.entry))) end
    b:Show()
end

--- Show `row`'s tooltip.
function RT.Show(row)
    if not (GameTooltip and row.entry) then return end
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
    GameTooltip:Show()
    if barAt then placeBar(row, barAt) end
end

function RT.Hide(row)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end
