local _, NS = ...
-- modules/Bonuses.lua — a skill's modifier broken down into its sources (design §5.2, plan Task
-- 2.2): racials (defaults/Racials_Forever.lua), equipped items and the main-hand temp enchant (a
-- lure) read off their tooltips, and skill buffs. Whatever is left is one "Other" entry, never a
-- guessed source, so the sources always add up to the modifier.
--
-- Reads the skill model through NS.SkillData:Get(key) (T2.1) at call time. Publishes
-- BONUSES_UPDATED, debounced, on UNIT_INVENTORY_CHANGED and UNIT_AURA for the player, and once a
-- second from a ticker that runs only while a temp bonus is live.

NS.Bonuses = {}
local B = NS.Bonuses
local L = NS.L

B.MAIN_HAND = 16          -- INVSLOT_MAINHAND, which the Forever set does not list
B.SLOTS     = 19          -- equipped slots 1 (head) .. 19 (tabard)
B.MAX_BUFFS = 40
B.DEBOUNCE  = 0.2
B.TICK      = 1

-- The tooltip patterns are locale strings (the key is the enUS text). Each says which capture is
-- the amount. ENCHANT is read first on the main hand while a temp enchant is on it.
local function patterns()
    return {
        enchant = { { L["%+(%d+) (.-) Skill"], amount = 1 } },
        line    = { { L["%+(%d+) (.+)"], amount = 1 }, { L["Increased (.+) %+(%d+)"], amount = 2 } },
    }
end

-- ---------------------------------------------------------------------------------------------
-- Client adapters: the kit's Forever set lists the C_ namespaces; the 1.12 globals are the fallback.
-- ---------------------------------------------------------------------------------------------

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) end

local function now() return GetTime() end

--- Seconds since GetTime() when the main-hand temp enchant runs out, or nil when there is none.
--- Assumed shape (1.12): hasMain, mainExpirationMs, ... (docs/midnight-quirks.md).
local function mainEnchantExpiry()
    local fn = (C_Item and C_Item.GetWeaponEnchantInfo) or GetWeaponEnchantInfo
    if type(fn) ~= "function" then return nil end
    local hasMain, ms = fn()
    if not hasMain then return nil end
    return now() + (tonumber(ms) or 0) / 1000
end

--- The text lines of a C_TooltipInfo data table, a secret or non-string line left out.
local function linesOfData(data)
    local out = {}
    if type(data) ~= "table" or type(data.lines) ~= "table" then return out end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not isSecret(text) then out[#out + 1] = text end
    end
    return out
end

--- The hidden scanning tooltip (the fallback when C_TooltipInfo is absent), made on first use.
local function scanTip()
    if B.__scanTip == nil then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "SkillMasterScanTip", nil, "GameTooltipTemplate")
        B.__scanTip = ok and tip or false
    end
    return B.__scanTip or nil
end

local function linesOfScan(slot)
    local tip = scanTip()
    if not (tip and type(tip.SetInventoryItem) == "function") then return {} end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    tip:SetInventoryItem("player", slot)
    local out, name = {}, tip:GetName()
    for i = 1, tip:NumLines() do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if type(text) == "string" and not isSecret(text) then out[#out + 1] = text end
    end
    return out
end

--- The tooltip lines of an equipped slot, C_TooltipInfo first.
function B.ItemLines(slot)
    local get = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
    if type(get) == "function" then return linesOfData(get("player", slot)) end
    return linesOfScan(slot)
end

--- The player's buffs as { label, expires, lines }; empty when the aura readers are absent.
local function buffs()
    local get = C_UnitAuras and C_UnitAuras.GetBuffDataByIndex
    local tip = C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID
    local out = {}
    if type(get) ~= "function" or type(tip) ~= "function" then return out end
    for i = 1, B.MAX_BUFFS do
        local aura = get("player", i)
        if not aura then break end
        local expires = tonumber(aura.expirationTime)
        out[#out + 1] = { label = aura.name, expires = (expires and expires > 0) and expires or nil,
                          lines = linesOfData(tip("player", aura.auraInstanceID)) }
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Parsing: every tooltip line that names a skill bonus becomes a candidate, keyed by the skill's
-- lower-cased name; Breakdown picks the candidates whose name is the skill's.
-- ---------------------------------------------------------------------------------------------

local function norm(s) return (s:lower():gsub("^%s+", ""):gsub("[%s%.:]+$", "")) end

--- amount, normalized name of the first pattern in `list` the line matches, or nil.
local function match(text, list)
    for _, p in ipairs(list) do
        local a, b = text:match(p[1])
        if a then
            local amount, name = a, b
            if p.amount == 2 then amount, name = b, a end
            return tonumber(amount), norm(name)
        end
    end
    return nil
end

--- The enchant's label: its tooltip line up to the bracket ("Fishing Lure (+25 ...)").
local function enchantLabel(text)
    local label = text:match("^(.-)%s*%(")
    if label and label ~= "" then return label end
    return L["Weapon enchant"]
end

local function addCandidate(list, amount, name, fields)
    if not amount or amount == 0 then return end
    fields.amount, fields.name = amount, name
    list[#list + 1] = fields
end

--- One slot's lines: the enchant line (main hand, enchant live) first, the rest as item lines.
local function parseSlot(list, slot, enchantExpires, pats)
    local lines = B.ItemLines(slot)
    local itemName = lines[1] or L["Item"]
    for i = 2, #lines do
        local text = lines[i]
        local amount, name
        if enchantExpires and slot == B.MAIN_HAND then amount, name = match(text, pats.enchant) end
        if amount then
            addCandidate(list, amount, name, { label = enchantLabel(text), kind = "temp",
                source = "enchant", expires = enchantExpires })
        else
            amount, name = match(text, pats.line)
            addCandidate(list, amount, name, { label = itemName, kind = "perm", source = "item" })
        end
    end
end

local function parseBuffs(list, pats)
    for _, aura in ipairs(buffs()) do
        for _, text in ipairs(aura.lines) do
            local amount, name = match(text, pats.line)
            addCandidate(list, amount, name, { label = aura.label or L["Buff"], kind = "temp",
                source = "buff", expires = aura.expires })
        end
    end
end

--- Read every source once; Breakdown reads this until the next Invalidate.
local function collect()
    local list, pats = {}, patterns()
    local enchantExpires = mainEnchantExpiry()
    for slot = 1, B.SLOTS do parseSlot(list, slot, enchantExpires, pats) end
    parseBuffs(list, pats)
    return list
end

local function candidates()
    if not B.__cache then B.__cache = collect() end
    return B.__cache
end

function B.Invalidate() B.__cache = nil end

--- True while a cached temp candidate has not run out.
function B.HasLiveTemp()
    local t = now()
    for _, c in ipairs(candidates()) do
        if c.kind == "temp" and (c.expires == nil or c.expires > t) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- The breakdown.
-- ---------------------------------------------------------------------------------------------

local function racial(key)
    local race, raceFile = UnitRace("player")
    local byRace = NS.Racials_Forever and NS.Racials_Forever.byRace
    local amount = byRace and raceFile and byRace[raceFile] and byRace[raceFile][key]
    if not amount then return nil end
    return { label = L["%s racial"]:format(race or raceFile), amount = amount, kind = "perm",
             source = "racial" }
end

local function sourceOf(c)
    return { label = c.label, amount = c.amount, kind = c.kind, expires = c.expires, source = c.source }
end

local function skillEntry(key)
    local SD = NS.SkillData
    if not (SD and type(SD.Get) == "function") then return nil end
    return SD:Get(key)
end

--- The skill's modifier and where it comes from.
--- @return table { total = n, sources = { { label, amount, kind = "temp"|"perm",
---   expires = <GetTime seconds>|nil, source = "racial"|"item"|"enchant"|"buff"|"other" } } }
function B:Breakdown(key)
    local e = skillEntry(key)
    local modifier = e and e.learned ~= false and tonumber(e.modifier) or 0
    local out = { total = modifier, sources = {} }
    if modifier == 0 or type(e.name) ~= "string" then return out end
    local sources, attributed = out.sources, 0
    local r = racial(key)
    if r then sources[1], attributed = r, r.amount end
    local name = norm(e.name)
    for _, c in ipairs(candidates()) do
        if c.name == name then
            sources[#sources + 1] = sourceOf(c)
            attributed = attributed + c.amount
        end
    end
    local rest = modifier - attributed
    if rest ~= 0 then
        if rest < 0 then NS.Debug("Bonus", "%s: %d attributed past a modifier of %d", key, attributed, modifier) end
        sources[#sources + 1] = { label = L["Other"], amount = rest, kind = "perm", source = "other" }
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Refresh: the events, the debounce and the temp-bonus ticker. Every timer is the addon's own
-- (AceTimer), so NS.StandDown's CancelAllTimers takes them down; RegisterRuntime starts afresh.
-- ---------------------------------------------------------------------------------------------

local function stopTicker()
    if B.__ticker then NS.addon:CancelTimer(B.__ticker) end
    B.__ticker = nil
end

--- Re-read everything, publish, and keep the ticker running exactly while a temp bonus lives.
function B.Refresh()
    B.__pending = nil
    B.Invalidate()
    local live = B.HasLiveTemp()
    if live and not B.__ticker then
        B.__ticker = NS.addon:ScheduleRepeatingTimer(B.Tick, B.TICK)
    elseif not live then
        stopTicker()
    end
    NS.bus:SendMessage(NS.MSG.BONUSES_UPDATED)
end

--- The 1 s tick: publish for the timers; re-read once the temp bonus has run out.
function B.Tick()
    if B.HasLiveTemp() then NS.bus:SendMessage(NS.MSG.BONUSES_UPDATED) return end
    B.Refresh()
end

function B.Schedule()
    if B.__pending then return end
    B.__pending = NS.addon:ScheduleTimer(B.Refresh, B.DEBOUNCE)
end

--- The game events, on the addon object (NS.RegisterRuntime calls this from current state).
function B.RegisterRuntime(addon)
    B.__pending, B.__ticker = nil, nil
    NS.SafeRegisterEvent(addon, "UNIT_INVENTORY_CHANGED", "OnBonusesUnitChanged", NS.rejectedEvents)
    NS.SafeRegisterEvent(addon, "UNIT_AURA", "OnBonusesUnitChanged", NS.rejectedEvents)
    B.Schedule()
end

function NS.addon:OnBonusesUnitChanged(_, unit)
    if unit ~= "player" or NS.IsStoodDown() then return end
    B.Schedule()
end
