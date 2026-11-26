local _, NS = ...
-- modules/Pins.lua — the pins per broker (GitHub issue #11; item SMW-06 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md, the spec's "Brokers and pins"). Each family's
-- broker feed shows its own pins: an ordered list of up to Pins.MAX keys, per character, in
-- char.pins[family] (named non-setting state; this file is its one writer). A row's menu toggles its own
-- pin (modules/Interact.lua), and pinning never removes another pin; the Broker settings page's Pins tab
-- (settings/BrokerPins.lua) reorders and removes them.
--
-- THE OLD ONE-PIN FIELDS. Before this item a character stored one pinned skill (char.pinned, the Skill
-- Master feed's) and one pinned stat (char.pinnedStat, the Skill Master Stats feed's). The schemaVersion
-- runner has no per-character steps (core/Database.lua), so they are normalized when read: a stored skill
-- key becomes a one-item list in its own family (its block's: Professions or Skills), a stored stat key one
-- in Character Stats, and both old fields go.
--
-- While test mode or a simulation runs, the feeds draw the sample character's pins (NS.Broker.View's
-- `pins`); a sample row's menu offers no pin (preview-mode: nothing of the live state is written for a
-- sample), but the settings page still edits this character's own list.
--
-- NS.Pins.List(family) / .Stored(family) / .Has(family, key) / .Full(family) / .Toggle(family, key) /
--   .Remove(family, key) / .Move(family, from, to) / .FamilyOfSkill(key[, model]) / .FamilyOfRow(row) /
--   .Normalize(char) / .Label(family, key)

NS.Pins = {}
local Pins = NS.Pins
local L = NS.L

Pins.MAX = 5   -- per broker (the owner's ruling)

--- The family a skill belongs to: its block's (a skill's category is its block id), from its model entry
--- or the catalog; an "other:" key the catalog does not know is the Other block's. nil when neither knows it.
function Pins.FamilyOfSkill(key, model)
    if type(key) ~= "string" then return nil end
    local e = type(model) == "table" and type(model.byKey) == "table" and model.byKey[key] or nil
    local cat = (e and e.category) or (NS.SkillCatalog[key] and NS.SkillCatalog[key].category)
    if not cat and key:find("^other:") then cat = "other" end
    local fam = cat and NS.FamilyOf(cat)
    return fam and fam.id or nil
end

--- The family whose broker a window row pins to: its own (`row.family`), a skill's block's, else the one
--- family whose rows are of its kind (Character Stats for a stat).
function Pins.FamilyOfRow(row)
    if type(row) ~= "table" then return nil end
    if row.family and NS.Families[row.family] then return row.family end
    local e = row.entry
    if row.kind == "skill" and type(e) == "table" then
        local fam = e.category and NS.FamilyOf(e.category)
        return fam and fam.id or Pins.FamilyOfSkill(e.key)
    end
    for fid, fam in NS.EachFamily() do
        if fam.rowKind == row.kind then return fid end
    end
    return nil
end

local function indexOf(list, key)
    for i, k in ipairs(list) do if k == key then return i end end
    return nil
end

local function add(pins, fid, key)
    if type(pins[fid]) ~= "table" then pins[fid] = {} end
    local list = pins[fid]
    if indexOf(list, key) or #list >= Pins.MAX then return false end
    list[#list + 1] = key
    return true
end

--- This character's store made current: char.pins as a table, the old one-pin fields folded into it and
--- gone. Answers char.pins, or nil without a character store.
function Pins.Normalize(char)
    if type(char) ~= "table" then return nil end
    if type(char.pins) ~= "table" then char.pins = {} end
    local pins = char.pins
    local skill, stat = rawget(char, "pinned"), rawget(char, "pinnedStat")
    if type(skill) == "string" then add(pins, Pins.FamilyOfSkill(skill) or "professions", skill) end
    if type(stat) == "string" then add(pins, "stats", stat) end
    if skill ~= nil then char.pinned = nil end
    if stat ~= nil then char.pinnedStat = nil end
    return pins
end

local function charStore()
    local char = NS.db and NS.db.char
    return Pins.Normalize(char)
end

local function copy(list)
    local out = {}
    for _, k in ipairs(type(list) == "table" and list or {}) do
        if type(k) == "string" then out[#out + 1] = k end
    end
    return out
end

--- This character's own pins on `family`'s broker, in order (a copy).
function Pins.Stored(family)
    local pins = charStore()
    return copy(pins and pins[family])
end

--- The pins `family`'s broker draws now (a copy): the sample character's while a source is set (test
--- mode), else this character's.
function Pins.List(family)
    local B = NS.Broker
    if B and B.View then
        local v, sourced = B.View()
        if sourced then return copy(type(v.pins) == "table" and v.pins[family]) end
    end
    return Pins.Stored(family)
end

--- Whether `key` is pinned to `family`'s broker (this character's own list).
function Pins.Has(family, key)
    return indexOf(Pins.Stored(family), key) ~= nil
end

--- Whether `family`'s broker holds Pins.MAX pins already.
function Pins.Full(family)
    return #Pins.Stored(family) >= Pins.MAX
end

-- Whoever draws the pins redraws: the feeds' text (their {pinned}), the windows (a row menu's tick), and the
-- settings page's list while it is open (Pins.onChange, settings/BrokerPins.lua).
local function changed()
    if NS.Broker and NS.Broker.Refresh then NS.Broker.Refresh() end
    if NS.Blocks and NS.Blocks.Changed then NS.Blocks.Changed() end
    if Pins.onChange then Pins.onChange() end
end

local function list(family)
    local pins = charStore()
    if not (pins and NS.Families[family]) then return nil end
    if type(pins[family]) ~= "table" then pins[family] = {} end
    return pins[family]
end

--- Pin `key` to `family`'s broker, or unpin it when it is pinned there. Answers true pinned, false
--- unpinned, nil refused (an unknown family, no store, or Pins.MAX pinned already). Never touches another pin.
function Pins.Toggle(family, key)
    local l = type(key) == "string" and list(family)
    if not l then return nil end
    local i = indexOf(l, key)
    if i then
        table.remove(l, i)
        NS.Debug("Click", "unpinned %s from the %s broker", key, family)
        changed()
        return false
    end
    if #l >= Pins.MAX then return nil end
    l[#l + 1] = key
    NS.Debug("Click", "pinned %s to the %s broker", key, family)
    changed()
    return true
end

--- Unpin `key` from `family`'s broker. Answers whether it was pinned there.
function Pins.Remove(family, key)
    local l = list(family)
    local i = l and indexOf(l, key)
    if not i then return false end
    table.remove(l, i)
    changed()
    return true
end

--- Move the pin at position `from` of `family`'s broker to position `to`. Answers whether anything moved.
function Pins.Move(family, from, to)
    local l = list(family)
    if not l or from == to or not (l[from] and l[to]) then return false end
    local key = table.remove(l, from)
    table.insert(l, to, key)
    changed()
    return true
end

--- A pin's name as the settings page lists it: its row's, from the models drawn now, else the catalog's,
--- else the key itself.
function Pins.Label(family, key)
    local B = NS.Broker
    local e = B and B.PinEntry and B.PinEntry(family, key)
    if e then return e.entry.name or e.entry.label or key end
    local cat = NS.SkillCatalog[key]
    if cat and cat.name then return L[cat.name] end
    return key
end
