-- tools/trainer_probe/checks.lua — the trainer probe's checks (GitHub issue #3), pure functions over
-- the shipped records (defaults/Trainers_Forever.lua) and the sources the readers return. No file
-- access here, so tests/test_trainer_probe.lua drives every check on small hand-made inputs.
--
-- Per record: name (one NPC of that name and side, or the record's npcID), role (the trainer bit and
-- a title naming the skill and the top rank; a book's vendor or a rank quest's giver for a record
-- that says the rank is learned that way), place (the spawn's AreaID maps to the record's uiMapID,
-- and its x, y within TOLERANCE map-% of the spawn) and duplicates (two NPCs on one point). A record
-- every check passes is confirmed; any other names its reason.

local C = {}

--- Map-% a shipped point may sit from the source's spawn (issue #2's agreed tolerance).
C.TOLERANCE = 1.0
-- Spawns closer than this to each other are one standing point (a trainer with two spawn rows).
C.SAME_POINT = 1.0

C.TRAINER, C.VENDOR, C.QUEST_GIVER = 16, 4, 2

-- The title words that name each skill (QuestieDB subName, the NPC's title in game), and the rank
-- spell's line name in the CMaNGOS dump (ItemTree's method: what the trainer's rows teach).
C.SKILLS = {
    alchemy = { words = { "Alchemist", "Alchemy" }, line = "Alchemy" },
    blacksmithing = { words = { "Blacksmith", "Blacksmithing", "Armorsmith", "Weaponsmith" }, line = "Blacksmithing" },
    enchanting = { words = { "Enchanter", "Enchanting" }, line = "Enchanting" },
    engineering = { words = { "Engineer", "Engineering" }, line = "Engineering" },
    herbalism = { words = { "Herbalism", "Herbalist" }, line = "Herb Gathering" },
    leatherworking = { words = { "Leatherworker", "Leatherworking" }, line = "Leatherworking" },
    mining = { words = { "Mining", "Miner" }, line = "Mining" },
    skinning = { words = { "Skinning", "Skinner" }, line = "Skinning" },
    tailoring = { words = { "Tailor", "Tailoring" }, line = "Tailoring" },
    cooking = { words = { "Cooking", "Cook", "Chef" }, line = "Cooking" },
    firstAid = { words = { "First Aid", "Surgeon", "Physician" }, line = "First Aid" },
    fishing = { words = { "Fishing", "Fisherman" }, line = "Fishing" },
    riding = { words = { "Riding", "Pilot" }, line = "Riding" },
}
-- The weapon skill keys, by the spell name a weapon master's rows teach.
C.WEAPON_SPELLS = {
    ["One-Handed Swords"] = "swords", ["Two-Handed Swords"] = "twoHandedSwords", ["One-Handed Axes"] = "axes",
    ["Two-Handed Axes"] = "twoHandedAxes", ["One-Handed Maces"] = "maces", ["Two-Handed Maces"] = "twoHandedMaces",
    Daggers = "daggers", Staves = "staves", Polearms = "polearms", Bows = "bows", Crossbows = "crossbows",
    Guns = "guns", Thrown = "thrown", ["Fist Weapons"] = "fistWeapons",
}
-- The cap a title's rank word trains to; a title with none trains its class's top (below). A
-- capital's "Artisan" title trains to Expert (225): Artisan in a craft is the Master trainers'
-- (round 2; the CMaNGOS rows, Method.gg's and wow-professions' Forever guides agree).
C.TITLE_CAP = { Junior = 75, Journeyman = 150, Expert = 225, Artisan = 225, Master = 300 }
C.PLAIN_CAP = { herbalism = 300, mining = 300, skinning = 300, cooking = 150, firstAid = 150, fishing = 150, riding = 150 }
-- A craft trainer with a plain title ("Alchemist", "Blacksmith"; Forever's village trainers) is read
-- as Journeyman, an untitled village trainer's reach in the 1.12 dump (round 2, spec D15).
C.CRAFT_PLAIN_CAP = 150
C.BOOK_CAP = { Expert = 225, Artisan = 300 }

local function bit(flags, b)
    return math.floor((flags or 0) / b) % 2 == 1
end
C.Bit = bit

local function topCap(rec)
    local top
    for _, c in ipairs(rec.ranks or {}) do top = math.max(top or 0, c) end
    return top
end
C.TopCap = topCap

local function hasWord(title, word)
    return (" " .. title .. " "):find("[^%a]" .. word:gsub("%p", "%%%0") .. "[^%a]") ~= nil
end

--- Whether QuestieDB's side string ("A", "H", "AH", nil) serves the record's faction.
function C.SideOK(faction, side)
    side = side or ""
    local a, h = side:find("A", 1, true) ~= nil, side:find("H", 1, true) ~= nil
    if faction == "Alliance" then return a end
    if faction == "Horde" then return h end
    return a and h
end

-- Levenshtein distance, for the near-miss names a missing record lists ("Felbin" -> "Felben").
local function distance(a, b)
    if math.abs(#a - #b) > 3 then return 99 end
    local prev = {}
    for j = 0, #b do prev[j] = j end
    for i = 1, #a do
        local cur = { [0] = i }
        for j = 1, #b do
            local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
        end
        prev = cur
    end
    return prev[#b]
end
C.Distance = distance

local function nearNames(db, name)
    local out = {}
    for other, list in pairs(db.byName) do
        if other ~= name and distance(other, name) <= 2 then
            for _, n in ipairs(list) do out[#out + 1] = ("%s (%d, %s)"):format(n.name, n.id, n.subName or "no title") end
        end
    end
    table.sort(out)
    return out
end

--- The name check: { ok, npc, msg, suggest = { name, npcID } }.
function C.Name(rec, db)
    if rec.npcID then
        local npc = db.npcs[rec.npcID]
        if not npc then return { ok = false, msg = ("npc %d is not in the source"):format(rec.npcID) } end
        if npc.name ~= rec.name then
            return { ok = false, npc = npc, msg = ("npc %d is named %q"):format(npc.id, npc.name), suggest = { name = npc.name } }
        end
        return { ok = true, npc = npc }
    end
    local same = {}
    for _, npc in ipairs(db.byName[rec.name] or {}) do
        if C.SideOK(rec.faction, npc.faction) then same[#same + 1] = npc end
    end
    if #same == 1 then return { ok = true, npc = same[1], suggest = { npcID = same[1].id } } end
    if #same > 1 then return { ok = false, msg = ("%d NPCs share the name on this side"):format(#same) } end
    local near = nearNames(db, rec.name)
    local msg = "no NPC of this name" .. (#near > 0 and ("; near: " .. table.concat(near, "; ")) or "")
    return { ok = false, msg = msg }
end

-- The role check of a record whose rank is learned from a book.
local function bookRole(rec, npc, db)
    local item = db.items[rec.learn.itemID]
    if not item then return { ok = false, msg = ("book %d is not in the source"):format(rec.learn.itemID) } end
    local sells = false
    for _, v in ipairs(item.vendors or {}) do sells = sells or v == npc.id end
    if not sells then return { ok = false, msg = ("%s is not sold by npc %d"):format(item.name, npc.id) } end
    if item.name ~= rec.learn.item then return { ok = false, msg = ("book %d is named %q"):format(rec.learn.itemID, item.name) } end
    local word = item.name:match("^(%a+)")
    if C.BOOK_CAP[word] ~= topCap(rec) then
        return { ok = false, msg = ("%s trains to %s, the record says %s"):format(item.name, tostring(C.BOOK_CAP[word]), tostring(topCap(rec))) }
    end
    return { ok = true }
end

-- The role check of a record whose rank is learned from a quest.
local function questRole(rec, npc)
    if not bit(npc.flags, C.QUEST_GIVER) then return { ok = false, msg = "no quest giver flag" } end
    for _, q in ipairs(npc.questStarts or {}) do
        if q == rec.learn.questID then return { ok = true } end
    end
    return { ok = false, msg = ("npc %d does not start quest %d"):format(npc.id, rec.learn.questID) }
end

local function titleNames(rec, title)
    for _, key in ipairs(rec.teaches) do
        local skill = C.SKILLS[key]
        for _, w in ipairs(skill and skill.words or {}) do
            if hasWord(title, w) then return key end
        end
    end
    return nil
end

local function titleCap(key, title)
    for word, cap in pairs(C.TITLE_CAP) do
        if hasWord(title, word) then return cap end
    end
    return C.PLAIN_CAP[key] or C.CRAFT_PLAIN_CAP
end

-- The role check of a trainer record: the trainer bit and a title that names the skill and rank.
local function trainerRole(rec, npc)
    if not bit(npc.flags, C.TRAINER) then
        return { ok = false, msg = ("no trainer flag (npcFlags %d, %q)"):format(npc.flags, npc.subName or "") }
    end
    local title = npc.subName or ""
    if not rec.ranks then
        if title == "Weapon Master" then return { ok = true } end
        return { ok = false, msg = ("title %q is not a weapon master's"):format(title) }
    end
    local key = titleNames(rec, title)
    if not key then return { ok = false, msg = ("title %q names none of %s"):format(title, table.concat(rec.teaches, ", ")) } end
    local cap = titleCap(key, title)
    if cap ~= topCap(rec) then
        return { ok = false, msg = ("title %q trains to %s, the record says %s"):format(title, tostring(cap), tostring(topCap(rec))) }
    end
    return { ok = true }
end

--- The role check: { ok, msg }.
function C.Role(rec, npc, db)
    if rec.learn and rec.learn.kind == "book" then return bookRole(rec, npc, db) end
    if rec.learn and rec.learn.kind == "quest" then return questRole(rec, npc) end
    return trainerRole(rec, npc)
end

-- The spawns on the record's uiMap: { { x, y, area }, ... }, and whether any is an instance sentinel.
local function spawnsOn(npc, mapID, db)
    local on, sentinel, areas = {}, false, {}
    for area, pts in pairs(npc.spawns or {}) do
        areas[#areas + 1] = area
        for _, p in ipairs(pts) do
            if p[1] == -1 and p[2] == -1 then sentinel = true
            elseif db.areaToUiMap[area] == mapID then on[#on + 1] = { x = p[1], y = p[2], area = area } end
        end
    end
    table.sort(areas)
    return on, sentinel, areas
end

local function dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end
C.Dist = dist

-- One standing point when every spawn lies within SAME_POINT of the first; nil when they spread.
local function onePoint(pts)
    for _, p in ipairs(pts) do
        if dist(p.x, p.y, pts[1].x, pts[1].y) > C.SAME_POINT then return nil end
    end
    return pts[1]
end

local function round1(v)
    return math.floor(v * 10 + 0.5) / 10
end
C.Round1 = round1

--- The place check: { ok, msg, spawn, area, suggest = { x, y } }.
function C.Place(rec, npc, db)
    local on, sentinel, areas = spawnsOn(npc, rec.mapID, db)
    if #on == 0 then
        local why = sentinel and "the source holds an instance sentinel (inside an instance), no map position"
            or ("no spawn on uiMap %d (AreaIDs %s)"):format(rec.mapID, table.concat(areas, ", "))
        return { ok = false, msg = why }
    end
    local p = onePoint(on)
    if not p then return { ok = false, msg = ("%d spawns spread over the map, no one point"):format(#on) } end
    local suggest = { x = round1(p.x), y = round1(p.y) }
    if rec.x == nil or rec.y == nil then
        return { ok = false, spawn = p, area = p.area, suggest = suggest, msg = "no coordinates shipped" }
    end
    local d = dist(rec.x, rec.y, p.x, p.y)
    if d > C.TOLERANCE then
        return { ok = false, spawn = p, area = p.area, suggest = suggest,
                 msg = ("shipped (%.1f, %.1f) is %.1f map-%% from the spawn (%.2f, %.2f)"):format(rec.x, rec.y, d, p.x, p.y) }
    end
    return { ok = true, spawn = p, area = p.area, offBy = d }
end

--- The duplicate check over every record: { [record id] = { other record ids } } for two records
--- of different NPCs on one shipped point.
function C.Duplicates(records)
    local at, out = {}, {}
    for _, r in ipairs(records) do
        if r.x and r.y then
            local k = ("%d:%.1f:%.1f"):format(r.mapID, r.x, r.y)
            at[k] = at[k] or {}
            table.insert(at[k], r)
        end
    end
    for _, list in pairs(at) do
        for _, a in ipairs(list) do
            for _, b in ipairs(list) do
                if a ~= b and a.name ~= b.name then
                    out[a.id] = out[a.id] or {}
                    table.insert(out[a.id], b.id)
                end
            end
        end
    end
    return out
end

return C
