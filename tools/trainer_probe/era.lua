-- tools/trainer_probe/era.lua — the trainer probe's cross-checks (GitHub issue #3): what each
-- record's NPC looks like in the sources that are not QuestieDB's Forever table. They never confirm
-- or refute a record on their own (they describe Classic Era, or a guide's reading of Forever); a
-- disagreement puts the record on the in-game spot-check list.
--
--   cmangos  ItemTree's method: what the NPC's trainer rows teach in the 1.12 dump (the rank
--            spells' line and top cap, or a weapon master's weapon skills), the books it sells
--            and the rank quests it gives.
--   pfquest  the NPC's Era spawn, projected into Forever's frame, against QuestieDB's.
--   methodgg whether a Method.gg WoW Forever guide names the NPC (a names list the owner's run
--            collects; the probe reads names and professions only, and writes yes or no).

local here = ...
local C = loadfile(here .. "/checks.lua")(here)
local CM = loadfile(here .. "/cmangos.lua")(here)
local PF = loadfile(here .. "/pfquest.lua")(here)

local E = {}

-- Projected Era points within this of QuestieDB's Forever spawn agree.
E.AGREE = 0.5

local function keysOf(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

local function weaponNote(rec, names)
    local taught, want = {}, {}
    for name in pairs(names) do
        local key = C.WEAPON_SPELLS[name]
        if key then taught[key] = true end
    end
    for _, k in ipairs(rec.teaches) do want[k] = true end
    local missing, extra = {}, {}
    for k in pairs(want) do if not taught[k] then missing[#missing + 1] = k end end
    for k in pairs(taught) do if not want[k] then extra[#extra + 1] = k end end
    table.sort(missing)
    table.sort(extra)
    if #missing == 0 and #extra == 0 then return { agree = true, msg = "teaches the same weapon skills" } end
    return { agree = false, msg = ("weapon skills differ: shipped only %s; 1.12 only %s"):format(
        #missing > 0 and table.concat(missing, ", ") or "none", #extra > 0 and table.concat(extra, ", ") or "none") }
end

-- The 1.12 dump's trainer rows teach one rank below their NPC's title throughout (a "Journeyman
-- Alchemist" teaches Apprentice there, an "Artisan" Expert): a cap exactly one rank below the
-- record's, or no rank at all where the record's top is Journeyman, is that pattern (`rankOff`),
-- which the report counts once rather than listing per record.
local function rankNote(rec, trains)
    local skill = C.SKILLS[rec.teaches[1]]
    local t = skill and trains[skill.line]
    local top = C.TopCap(rec)
    if not t then
        -- An Apprentice-only record with no rank row says nothing either way (the dump's Journeyman
        -- enchanters teach no Enchanting rank spell; Method.gg has them teach Apprentice).
        return { agree = false, neutral = top == 75, rankOff = top == 150,
                 msg = ("teaches no %s rank in the 1.12 dump"):format(skill and skill.line or rec.teaches[1]) }
    end
    if t.cap == top then return { agree = true, msg = ("teaches %s to %d"):format(skill.line, t.cap) } end
    return { agree = false, cap = t.cap, rankOff = top - t.cap == 75,
             msg = ("teaches %s to %d in the 1.12 dump, the record says %d"):format(skill.line, t.cap, top) }
end

local function learnNote(rec, entry, cm)
    local list, ids
    if rec.learn.kind == "book" then
        list = cm.books[rec.learn.itemID]
        ids = list and list.vendors
    else
        list = cm.quests[rec.learn.questID]
        ids = list and list.givers
    end
    if not list then return { agree = false, msg = ("the 1.12 dump has no rank %s %d"):format(rec.learn.kind, rec.learn.itemID or rec.learn.questID) } end
    for _, id in ipairs(ids or {}) do
        if id == entry then return { agree = true, msg = ("%s %q, as in 1.12"):format(rec.learn.kind, list.name or list.title) } end
    end
    return { agree = false, msg = ("1.12 has %q from other NPCs (%s)"):format(list.name or list.title, table.concat(ids or {}, ", ")) }
end

--- The CMaNGOS note for record `rec` matched to NPC id `entry`: { agree, msg }, or nil without a dump.
function E.Cmangos(rec, entry, cm)
    if not cm then return nil end
    local c = cm.creatures[entry]
    if not c then return { agree = false, missing = true, msg = ("npc %d is not in the 1.12 dump: Forever content"):format(entry) } end
    if c.Name ~= rec.name then return { agree = false, msg = ("the 1.12 dump names npc %d %q"):format(entry, c.Name) } end
    if rec.learn then return learnNote(rec, entry, cm) end
    local trains, names = CM.Trains(cm, entry)
    if not rec.ranks then return weaponNote(rec, names) end
    return rankNote(rec, trains)
end

--- The pfQuest note: the Era spawn projected through `coefficients`, against QuestieDB's spawn.
function E.Pfquest(spawn, entry, pf, coefficients)
    if not (pf and spawn) then return nil end
    for _, p in ipairs(pf[entry] or {}) do
        if p.area == spawn.area then
            local x, y = PF.Project(p, coefficients)
            local d = C.Dist(x, y, spawn.x, spawn.y)
            return { agree = d <= E.AGREE, msg = ("Era (%.1f, %.1f) projects to (%.2f, %.2f), %.2f map-%% off"):format(p.x, p.y, x, y, d) }
        end
    end
    return { agree = false, msg = ("no Era spawn in AreaID %d"):format(spawn.area) }
end

--- The Method.gg note: whether its guides name the NPC under one of the record's skills.
function E.Methodgg(rec, names)
    if not names then return nil end
    local rows = names[rec.name]
    -- A guide names one or two trainers per city, so a name it leaves out says nothing (neutral).
    if not rows then return { agree = false, neutral = true, msg = "not named on the guides" } end
    for _, row in ipairs(rows) do
        for _, k in ipairs(rec.teaches) do
            if row.profession == k or (row.profession == "weapons" and not rec.ranks) then
                return { agree = true, msg = ("named under %s"):format(row.profession) }
            end
        end
    end
    local seen = {}
    for _, row in ipairs(rows) do seen[row.profession] = true end
    return { agree = false, msg = ("named under %s only"):format(table.concat(keysOf(seen), ", ")) }
end

--- Read a Method.gg names list (tab-separated, a header row, `profession` and `name` columns):
--- name -> { { profession }, ... }, and the source URLs it cites.
function E.ReadNames(text)
    local out, urls, cols = {}, {}, nil
    for line in text:gmatch("[^\r\n]+") do
        local fields = {}
        for f in (line .. "\t"):gmatch("([^\t]*)\t") do fields[#fields + 1] = f end
        if not cols then
            cols = {}
            for i, f in ipairs(fields) do cols[f] = i end
        else
            local name, prof, url = fields[cols.name], fields[cols.profession], fields[cols.url or 0]
            out[name] = out[name] or {}
            table.insert(out[name], { profession = prof })
            if url and url ~= "" then urls[url] = true end
        end
    end
    return out, keysOf(urls)
end

return E
