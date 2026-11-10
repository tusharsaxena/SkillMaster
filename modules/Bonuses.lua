local _, NS = ...
-- modules/Bonuses.lua — a skill's modifier broken down into its sources (design §5.2, plan Task
-- 2.2): racials (defaults/Racials_Forever.lua), equipped items and the main-hand temp enchant (a
-- lure) read off their tooltips, and skill buffs. Whatever is left is one "Other" entry, never a
-- guessed source, so the sources always add up to the modifier.
--
-- Reads the skill model through NS.SkillData:Get(key) (T2.1) at call time, and every client read the
-- simulator answers through NS.Compat at call time (T5.2). B.source: nil for the live reads, or
-- fn(key) -> breakdown (test mode's sample character, modules/Preview.lua). Publishes
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
    local hasMain, ms = NS.Compat.WeaponEnchantInfo()
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
    for i = 1, tonumber(tip:NumLines()) or 0 do
        local fs = _G[name .. "TextLeft" .. i]
        local text = fs and fs:GetText()
        if type(text) == "string" and not isSecret(text) then out[#out + 1] = text end
    end
    return out
end

--- The tooltip lines of an equipped slot, C_TooltipInfo first.
function B.ItemLines(slot)
    local data, has = NS.Compat.InventoryTooltipData(slot)
    if has then return linesOfData(data) end
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

--- The equipped slots and the main-hand enchant: read again only on an inventory change.
local function collectItems()
    local list, pats = {}, patterns()
    local enchantExpires = mainEnchantExpiry()
    for slot = 1, B.SLOTS do parseSlot(list, slot, enchantExpires, pats) end
    return list
end

--- The player's buffs: read again on an aura change, which never touches the 19 item tooltips.
local function collectBuffs()
    local list = {}
    parseBuffs(list, patterns())
    return list
end

--- Every source, read once per part; Breakdown reads this until the next Invalidate.
local function candidates()
    if not B.__cache then
        B.__items = B.__items or collectItems()
        B.__buffs = B.__buffs or collectBuffs()
        local all = {}
        for _, c in ipairs(B.__items) do all[#all + 1] = c end
        for _, c in ipairs(B.__buffs) do all[#all + 1] = c end
        B.__cache = all
    end
    return B.__cache
end

--- Drop the cached sources: `part` "items" or "buffs" drops that part only, nil drops both.
function B.Invalidate(part)
    if part ~= "buffs" then B.__items = nil end
    if part ~= "items" then B.__buffs = nil end
    B.__cache = nil
end

--- The catalog's skill names, normalized like a candidate's name (built on first use).
local function skillNames()
    if not B.__skillNames then
        local set = {}
        for name in pairs(NS.SkillNameToKey or {}) do
            if type(name) == "string" then set[norm(name)] = true end
        end
        B.__skillNames = set
    end
    return B.__skillNames
end

--- True while a cached temp candidate that names a skill has not run out. A temp line naming no
--- skill ("+15 Stamina" on a buff) is no skill bonus and keeps no ticker alive.
function B.HasLiveTemp()
    local t, names = now(), skillNames()
    for _, c in ipairs(candidates()) do
        if c.kind == "temp" and names[c.name] and (c.expires == nil or c.expires > t) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- The breakdown.
-- ---------------------------------------------------------------------------------------------

local function racial(key, race, raceFile)
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

--- The breakdown of one model entry against `cands` (the parsed candidates) for a character of
--- `race` / `raceFile`. Pure: Breakdown feeds it the live reads, test mode its sample character.
function B.Compute(e, cands, race, raceFile)
    local modifier = e and e.learned ~= false and tonumber(e.modifier) or 0
    local out = { total = modifier, sources = {} }
    if modifier == 0 or type(e.name) ~= "string" then return out end
    local key = e.key
    local sources, attributed = out.sources, 0
    local r = racial(key, race, raceFile)
    if r then sources[1], attributed = r, r.amount end
    local name = norm(e.name)
    for _, c in ipairs(cands) do
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

--- The skill's modifier and where it comes from: B.source's answer while one is set (test mode's
--- sample character, modules/Preview.lua), else the live reads.
--- @return table { total = n, sources = { { label, amount, kind = "temp"|"perm",
---   expires = <GetTime seconds>|nil, source = "racial"|"item"|"enchant"|"buff"|"other" } } }
function B:Breakdown(key)
    if B.source then return B.source(key) end
    local race, raceFile = NS.Compat.PlayerRace()
    return B.Compute(skillEntry(key), candidates(), race, raceFile)
end

--- A model entry's name, normalized as a candidate's is (test mode builds its candidates with it).
function B.Norm(name) return norm(name) end

-- ---------------------------------------------------------------------------------------------
-- Refresh: the events, the debounce and the temp-bonus ticker. Every timer is the addon's own
-- (AceTimer), so NS.StandDown's CancelAllTimers takes them down; RegisterRuntime starts afresh.
-- ---------------------------------------------------------------------------------------------

local function stopTicker()
    if B.__ticker then NS.addon:CancelTimer(B.__ticker) end
    B.__ticker = nil
end

--- Re-read what the debounced events touched (everything when called directly), publish, and keep
--- the ticker running exactly while a temp bonus lives.
function B.Refresh()
    local part = B.__dirty
    B.__pending, B.__dirty = nil, nil
    B.Invalidate(part ~= "all" and part or nil)
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

--- Debounce a refresh of `part` ("items" | "buffs" | nil for both); parts asked for inside one
--- window merge.
function B.Schedule(part)
    part = part or "all"
    if B.__dirty and B.__dirty ~= part then part = "all" end
    B.__dirty = part
    if B.__pending then return end
    B.__pending = NS.addon:ScheduleTimer(B.Refresh, B.DEBOUNCE)
end

--- Reset and schedule the first read (NS.RegisterRuntime calls this from current state). The two
--- UNIT_* events are the player's alone, on NS.UnitEvents' frame, which the same call stands up.
function B.RegisterRuntime()
    B.__pending, B.__ticker, B.__dirty = nil, nil, nil
    B.Schedule()
end

function NS.addon:OnBonusesUnitChanged(event, unit)
    if unit ~= "player" or NS.IsStoodDown() then return end
    B.Schedule(event == "UNIT_AURA" and "buffs" or "items")
end

local function onUnit(event, unit) NS.addon:OnBonusesUnitChanged(event, unit) end
NS.UnitEvents.Register("UNIT_INVENTORY_CHANGED", onUnit)
NS.UnitEvents.Register("UNIT_AURA", onUnit)
