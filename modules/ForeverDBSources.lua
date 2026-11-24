local _, NS = ...
-- modules/ForeverDBSources.lua — what Skill Master reads from ForeverDB, WoW Forever's optional data
-- addon (LibKa0s#105, item SF-SM-02 of Ka0sAddonsCommonTasks docs/2026-11-25-SEEDS_AND_FOREVERDB/;
-- WowAddonStandards clients-§11). Two things the client cannot tell and the shipped data does not
-- carry:
--
--   * Where a rank's book comes from. A rank learned from a book (defaults/Trainers_Forever.lua's
--     `learn = { kind = "book", itemID, item }`) gains its sources in the row tooltip and on the
--     trainer popup's card: who sells it, the creatures it drops from (the top three, with chances)
--     and a world drop's minimum level.
--   * A trainer's map spot, only where the shipped record has none. A record with x and y is never
--     overridden (SF-SM-01 reconciled them against ForeverDB already); a record without them is
--     shown through a view that carries ForeverDB's first spot for its npcID, on the record's own
--     map, or on any map when the record names none.
--
-- ForeverDB is read only through LibKa0s-ForeverDB-1.0, never through the ForeverDB global. Nothing
-- here loads it at file load or at login: the first lookup (a row tooltip on a book rank, a trainer
-- popup that holds a record with no spot) is what loads its 12 MB, once a session. Without
-- ForeverDB, with Use ForeverDB off (trainers.foreverDB, the Trainers tab), or without the library
-- every member answers as if ForeverDB knew nothing, and the display is what it was before.
--
-- NS.ForeverDBSources.Enabled() / .Ready() / .ItemSources(itemID) /
-- .FormatChance(chance) / .SourceLines(itemID, itemName) / .TextLines(lines) / .BookLines(t) /
-- .Placed(t) / .PlaceAll(list)

NS.ForeverDBSources = {}
local F = NS.ForeverDBSources
local L = NS.L

local Lib = LibStub and LibStub("LibKa0s-ForeverDB-1.0", true)

--- How many sellers and how many drop sources a tooltip names before "+N more".
F.TOP = 3

local function profile()
    return (NS.db and NS.db.profile.trainers) or NS.defaults.profile.trainers
end

--- Whether the feature may read ForeverDB: the library is present and Use ForeverDB is on. Reads
--- nothing from ForeverDB and loads nothing.
function F.Enabled()
    return Lib ~= nil and profile().foreverDB ~= false
end

--- Whether ForeverDB answers now (LibKa0s-ForeverDB-1.0's Available(): WoW Forever, installed,
--- loaded or loadable, a table). The first call in a session is what loads it.
function F.Ready()
    if not F.Enabled() then return false end
    return (Lib.Available()) == true
end

-- ---------------------------------------------------------------------------------------------
-- Item sources (a rank's book)
-- ---------------------------------------------------------------------------------------------

local function playerFaction()
    if type(UnitFactionGroup) ~= "function" then return nil end
    return (UnitFactionGroup("player"))
end

-- ForeverDB's faction letters for the player's faction.
local LETTER = { Alliance = "A", Horde = "H" }

-- Whether NPC answer `n` serves the player: no faction recorded, both, or the player's own.
local function serves(n, faction)
    local f = n and n.faction
    local mine = LETTER[faction]
    return f == nil or mine == nil or f == "AH" or f == mine
end

local function npcName(n, id)
    return (n and type(n.name) == "string" and n.name ~= "") and n.name or L["NPC %d"]:format(id)
end

-- The sellers of the item that serve the player, the first F.TOP by name, and how many more.
local function sellers(ids)
    local faction, names, more = playerFaction(), {}, 0
    for _, id in ipairs(ids or {}) do
        local n = Lib.NPC(id)
        if serves(n, faction) then
            if #names < F.TOP then names[#names + 1] = npcName(n, id) else more = more + 1 end
        end
    end
    return names, more
end

-- The creatures it drops from, most likely first (the library's order), the first F.TOP.
local function droppers(list)
    local out, more = {}, 0
    for _, c in ipairs(list or {}) do
        if #out < F.TOP then
            out[#out + 1] = { name = npcName(Lib.NPC(c.id), c.id), chance = c.chance }
        else
            more = more + 1
        end
    end
    return out, more
end

--- Item `itemID`'s sources for the player: { vendors = { names }, moreVendors, drops = { { name,
--- chance (0..1 or nil: rate unknown) } }, moreDrops, worldMinLevel }, or nil when ForeverDB is not
--- ready or names no seller, no creature and no world drop. Vendors of the other faction are left out.
function F.ItemSources(itemID)
    if type(itemID) ~= "number" or not F.Ready() then return nil end
    local s = Lib.ItemSources(itemID)
    if type(s) ~= "table" then return nil end
    local vendors, moreVendors = sellers(s.vendors)
    local drops, moreDrops = droppers(s.creatures)
    local world = tonumber(s.worldMinLevel)
    if #vendors == 0 and #drops == 0 and not world then return nil end
    return { vendors = vendors, moreVendors = moreVendors, drops = drops, moreDrops = moreDrops,
             worldMinLevel = world }
end

--- A drop chance as the tooltip reads it: "25%", "0.4%", "<0.1%", or "rate unknown" for nil.
function F.FormatChance(chance)
    if type(chance) ~= "number" then return L["rate unknown"] end
    local pct = chance * 100
    if pct >= 1 then return ("%d%%"):format(math.floor(pct + 0.5)) end
    if pct >= 0.1 then return ("%.1f%%"):format(pct) end
    return "<0.1%"
end

local function withMore(text, more)
    if more > 0 then return text .. " " .. L["+%d more"]:format(more) end
    return text
end

--- The tooltip lines for item `itemID` (named `itemName`, the shipped enUS name): a heading, then
--- "Sold by", "Drops from" (one line per creature) and "World drop", as { left, right, tone,
--- rightTone } (the row tooltip's tones); nil when ItemSources answers nil.
function F.SourceLines(itemID, itemName)
    local s = F.ItemSources(itemID)
    if not s then return nil end
    local out = {}
    out[1] = { left = itemName or L["Book"], right = L["ForeverDB"], tone = "heading", rightTone = "muted" }
    if #s.vendors > 0 then
        out[#out + 1] = { left = L["Sold by"], right = withMore(table.concat(s.vendors, ", "), s.moreVendors),
                          tone = "muted", rightTone = "body" }
    end
    for i, d in ipairs(s.drops) do
        local left = i == 1 and L["Drops from"] or " "
        out[#out + 1] = { left = left, right = d.name .. " \194\183 " .. F.FormatChance(d.chance),
                          tone = "muted", rightTone = "body" }
    end
    if s.moreDrops > 0 then
        out[#out + 1] = { left = " ", right = L["+%d more"]:format(s.moreDrops), tone = "muted", rightTone = "muted" }
    end
    if s.worldMinLevel then
        out[#out + 1] = { left = L["World drop"], right = L["from Lv %d"]:format(s.worldMinLevel),
                          tone = "muted", rightTone = "body" }
    end
    return out
end

--- Lines from SourceLines as single strings for a one-column tooltip: { text, heading } each, the
--- heading "Expert Cookbook (ForeverDB)", the rest "Sold by: ...", a continuation indented; nil in,
--- nil out.
function F.TextLines(lines)
    if not lines then return nil end
    local out = {}
    for i, l in ipairs(lines) do
        local text
        if l.tone == "heading" then
            text = ("%s (%s)"):format(l.left, l.right)
        elseif l.left == " " then
            text = "    " .. l.right
        else
            text = l.left .. ": " .. l.right
        end
        out[i] = { text = text, heading = l.tone == "heading" }
    end
    return out
end

--- The source lines for trainer record `t` when its rank is learned from a book, else nil.
function F.BookLines(t)
    local learn = type(t) == "table" and t.learn
    if not (learn and learn.kind == "book") then return nil end
    return F.SourceLines(learn.itemID, learn.item)
end

-- ---------------------------------------------------------------------------------------------
-- Map spots (a trainer record with no position)
-- ---------------------------------------------------------------------------------------------

local function hasSpot(t)
    return type(t.x) == "number" and type(t.y) == "number"
end

-- The first spot on `mapID` when the record names its map, else on the lowest map id ForeverDB has
-- one on: mapID, point, or nil.
local function pick(spots, mapID)
    if type(spots) ~= "table" then return nil end
    if mapID ~= nil then
        local list = spots[mapID]
        return (list and list[1]) and mapID or nil, list and list[1]
    end
    local best
    for id, list in pairs(spots) do
        if list[1] and (best == nil or id < best) then best = id end
    end
    return best, best and spots[best][1]
end

local function round1(v) return math.floor(v * 10 + 0.5) / 10 end

-- A record's view, kept while the record lives (weak keys: the records are the data's).
local views = setmetatable({}, { __mode = "k" })

--- Trainer record `t` with a map position: `t` itself when it has one (a shipped position is never
--- overridden) or when ForeverDB has none, else a view on `t` (its fields read through) that adds
--- mapID, x and y on the data's 0..100 scale, rounded to 0.1, and spotSource = "ForeverDB".
function F.Placed(t)
    if type(t) ~= "table" or hasSpot(t) or type(t.npcID) ~= "number" or not F.Enabled() then return t end
    if views[t] then return views[t] end
    if not F.Ready() then return t end
    local mapID, pt = pick(Lib.Spots("npc", t.npcID), t.mapID)
    if not (mapID and pt) then return t end
    local view = setmetatable({ mapID = mapID, x = round1(pt.x * 100), y = round1(pt.y * 100),
                                spotSource = "ForeverDB" }, { __index = t })
    views[t] = view
    return view
end

--- A new list of `list`'s records through Placed, in order. ForeverDB is asked only when a record
--- has no position, so a list that is all placed loads nothing.
function F.PlaceAll(list)
    local out = {}
    for i, t in ipairs(list or {}) do out[i] = F.Placed(t) end
    return out
end
