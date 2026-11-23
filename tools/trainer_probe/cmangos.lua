-- tools/trainer_probe/cmangos.lua — reads a CMaNGOS Classic content database dump
-- (github.com/cmangos/classic-db, Full_DB/*.sql or .sql.gz) for the trainer probe (GitHub issue #3).
--
-- This is ItemTree's method, replicated (the owner's comment on #3; ItemTree's own trainer search,
-- Core/TrainerSearch.lua, and its published compiler, github.com/Rockjaw-Bonesnapper-Co/
-- itemtree-era-sources): a trainer's profession and top rank come from the rank spells its trainer
-- rows teach (npc_trainer and npc_trainer_template, each "learn" spell resolved through
-- spell_template to the spell it teaches), not from its title. The same resolution names the books
-- (item_template rows whose spell teaches a rank) with their vendors (npc_vendor and
-- npc_vendor_template), and the quests whose reward teaches a rank with their givers
-- (quest_template, creature_questrelation).
--
-- The dump is GPL-3.0 and describes patch 1.12. Nothing read here is written into the addon.

local CM = {}

local LEARN_SPELL = 36   -- SPELL_EFFECT_LEARN_SPELL
-- The rank words a rank spell's Rank1 carries, and the cap each trains to.
CM.RANK_CAP = { Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 }

-- What the probe keeps from each table, by column name: the dump's CREATE TABLE gives the indices.
local WANT = {
    creature_template = { "Entry", "Name", "SubName", "NpcFlags", "TrainerType", "TrainerTemplateId",
                          "VendorTemplateId" },
    npc_trainer = { "entry", "spell", "spellcost", "reqskillvalue", "reqlevel" },
    npc_trainer_template = { "entry", "spell", "spellcost", "reqskillvalue", "reqlevel" },
    npc_vendor = { "entry", "item" },
    npc_vendor_template = { "entry", "item" },
    spell_template = { "Id", "Effect1", "Effect2", "Effect3", "EffectTriggerSpell1", "EffectTriggerSpell2",
                       "EffectTriggerSpell3", "SpellName", "Rank1" },
    item_template = { "entry", "class", "name", "spellid_1", "spellid_2" },
    quest_template = { "entry", "Title", "RewSpell", "RewSpellCast" },
    creature_questrelation = { "id", "quest" },
}

local ESCAPES = { n = "\n", r = "\r", t = "\t", ["0"] = "\0", Z = "\26" }

-- A quoted SQL string starting at `pos` (the opening quote): its value and the index past it.
local function readString(s, pos)
    local buf, i = {}, pos + 1
    while true do
        local q = s:find("[\\']", i)
        if not q then return table.concat(buf), #s + 1 end
        buf[#buf + 1] = s:sub(i, q - 1)
        local c = s:sub(q, q)
        if c == "\\" then
            local e = s:sub(q + 1, q + 1)
            buf[#buf + 1] = ESCAPES[e] or e
            i = q + 2
        elseif s:sub(q + 1, q + 1) == "'" then
            buf[#buf + 1] = "'"
            i = q + 2
        else
            return table.concat(buf), q + 1
        end
    end
end

-- A bare SQL value (number or NULL) at `pos`: its value and the index of the delimiter after it.
local function readBare(s, pos)
    local q = s:find("[,)]", pos)
    local raw = s:sub(pos, q - 1)
    if raw == "NULL" then return nil, q end
    return tonumber(raw) or raw, q
end

-- One tuple's values starting just past its "(": the row (by column index) and the index past ")".
local function readTuple(s, pos)
    local row, n = {}, 0
    while true do
        local v
        if s:sub(pos, pos) == "'" then v, pos = readString(s, pos) else v, pos = readBare(s, pos) end
        n = n + 1
        row[n] = v
        local d = s:sub(pos, pos)
        pos = pos + 1
        if d ~= "," then return row, pos end
    end
end

--- Every tuple of an `INSERT INTO ... VALUES (...),(...);` line, each handed to `onRow(row)`.
function CM.Tuples(line, onRow)
    local _, pos = line:find("VALUES", 1, true)
    pos = (pos or #line) + 1
    while true do
        local p = line:find("[(;]", pos)
        if not p or line:sub(p, p) == ";" then return end
        local row
        row, pos = readTuple(line, p + 1)
        onRow(row)
    end
end

-- The kept columns of one row, by name.
local function pick(row, index)
    local out = {}
    for name, i in pairs(index) do out[name] = row[i] end
    return out
end

local function columnIndex(cols, names)
    local at, index = {}, {}
    for i, c in ipairs(cols) do at[c] = i end
    for _, n in ipairs(names) do
        index[n] = assert(at[n], "the dump's table lacks column " .. n)
    end
    return index
end

local function open(path)
    if path:match("%.gz$") then
        assert(not path:find("'", 1, true), "a path with a quote: " .. path)
        return assert(io.popen("gzip -dc '" .. path .. "'"))
    end
    return assert(io.open(path, "rb"))
end

-- The CREATE TABLE column parse and the INSERT dispatch, line by line, for the tables in WANT.
local function scan(path)
    local tables, cols, current = {}, {}, nil
    for name in pairs(WANT) do tables[name] = {} end
    local f = open(path)
    for line in f:lines() do
        local created = line:match("^CREATE TABLE `([%w_]+)`")
        if created then
            current = WANT[created] and created or nil
            cols[created] = {}
        elseif current and line:match("^  `") then
            table.insert(cols[current], line:match("^  `([^`]+)`"))
        else
            local into = line:match("^INSERT INTO `([%w_]+)`")
            if into and WANT[into] then
                local index = columnIndex(cols[into], WANT[into])
                local rows = tables[into]
                CM.Tuples(line, function(row) rows[#rows + 1] = pick(row, index) end)
            end
        end
    end
    f:close()
    return tables
end

local function byKey(rows, key)
    local out = {}
    for _, r in ipairs(rows) do out[r[key]] = r end
    return out
end

local function multi(rows, key)
    local out = {}
    for _, r in ipairs(rows) do
        local k = r[key]
        out[k] = out[k] or {}
        table.insert(out[k], r)
    end
    return out
end

-- The spell a spell id teaches: a learn spell's trigger, else the spell itself.
local function teaches(spells, id)
    local s = spells[id]
    if not s then return id end
    for i = 1, 3 do
        if s["Effect" .. i] == LEARN_SPELL and (s["EffectTriggerSpell" .. i] or 0) > 0 then
            return s["EffectTriggerSpell" .. i]
        end
    end
    return id
end

--- The rank a spell id teaches, through `teaches`: { line = <spell name>, cap } or nil.
function CM.RankOf(db, id)
    local s = db.spells[teaches(db.spells, id)]
    local cap = s and CM.RANK_CAP[s.Rank1 or ""]
    if not cap then return nil end
    return { line = s.SpellName, cap = cap, spell = s.Id }
end

--- The spell name a trainer row teaches (a weapon skill's "Two-Handed Swords"), or nil.
function CM.TaughtName(db, id)
    local s = db.spells[teaches(db.spells, id)]
    return s and s.SpellName
end

-- The rank books: item id -> { name, rank = RankOf, vendors = { creature id, ... } }.
local function books(db, t)
    local vendors = multi(t.npc_vendor, "item")
    local templateItems = multi(t.npc_vendor_template, "entry")
    for _, c in pairs(db.creatures) do
        for _, v in ipairs(templateItems[c.VendorTemplateId or 0] or {}) do
            vendors[v.item] = vendors[v.item] or {}
            table.insert(vendors[v.item], { entry = c.Entry, item = v.item })
        end
    end
    local out = {}
    for _, item in ipairs(t.item_template) do
        local rank = CM.RankOf(db, item.spellid_1 or 0) or CM.RankOf(db, item.spellid_2 or 0)
        if rank then
            local ids = {}
            for _, v in ipairs(vendors[item.entry] or {}) do ids[#ids + 1] = v.entry end
            table.sort(ids)
            out[item.entry] = { id = item.entry, name = item.name, rank = rank, vendors = ids }
        end
    end
    return out
end

-- The rank quests: quest id -> { title, rank, givers = { creature id, ... } }.
local function quests(db, t)
    local givers = multi(t.creature_questrelation, "quest")
    local out = {}
    for _, q in ipairs(t.quest_template) do
        local rank = CM.RankOf(db, q.RewSpellCast or 0) or CM.RankOf(db, q.RewSpell or 0)
        if rank then
            local ids = {}
            for _, g in ipairs(givers[q.entry] or {}) do ids[#ids + 1] = g.id end
            table.sort(ids)
            out[q.entry] = { id = q.entry, title = q.Title, rank = rank, givers = ids }
        end
    end
    return out
end

--- Read the dump at `path`: { creatures (entry -> row), byName (name -> { row, ... }),
--- trainerRows (entry -> { npc_trainer rows, its template's rows }), spells, books, quests }.
function CM.Read(path)
    local t = scan(path)
    local db = { spells = byKey(t.spell_template, "Id"), creatures = byKey(t.creature_template, "Entry") }
    db.byName = multi(t.creature_template, "Name")
    local own, template = multi(t.npc_trainer, "entry"), multi(t.npc_trainer_template, "entry")
    db.trainerRows = {}
    for entry, c in pairs(db.creatures) do
        local rows = {}
        for _, r in ipairs(own[entry] or {}) do rows[#rows + 1] = r end
        for _, r in ipairs(template[c.TrainerTemplateId or 0] or {}) do rows[#rows + 1] = r end
        if #rows > 0 then db.trainerRows[entry] = rows end
    end
    db.books = books(db, t)
    db.quests = quests(db, t)
    return db
end

--- What creature `entry` trains: { [line] = { cap = top cap, rows = { npc_trainer row, ... } } }
--- for the rank spells, plus `names` (every taught spell's name, a set).
function CM.Trains(db, entry)
    local out, names = {}, {}
    for _, r in ipairs(db.trainerRows[entry] or {}) do
        local rank = CM.RankOf(db, r.spell)
        if rank then
            local cur = out[rank.line] or { cap = 0, rows = {} }
            if rank.cap > cur.cap then cur.cap = rank.cap end
            table.insert(cur.rows, { cap = rank.cap, cost = r.spellcost, level = r.reqlevel, skill = r.reqskillvalue })
            out[rank.line] = cur
        end
        local name = CM.TaughtName(db, r.spell)
        if name then names[name] = true end
    end
    return out, names
end

return CM
