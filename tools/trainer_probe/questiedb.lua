-- tools/trainer_probe/questiedb.lua — reads a QuestieDB checkout's Forever data for the trainer
-- probe (GitHub issue #3): the NPC table (data/Forever/foreverNpcDB.lua), the book items' vendors
-- (data/Forever/foreverItemDB.lua), the AreaID -> uiMapID table
-- (support/Forever/Zones/areaIdToUiMapId.lua), the per-area frame transforms
-- (data/Forever/conversion.json) and the four static correction layers QuestieDB folds over the raw
-- NPC table (src/corrections/Forever/{legacy,generated,traces}/ and foreverNPCFixes.lua).
--
-- QuestieDB is GPLv3 for contributions (its LICENSE.md). Nothing read here is written into the
-- addon: the probe compares, and ships only Skill Master's own corrected numbers plus the commit.

local IO = dofile((...) .. "/io.lua")

local Q = {}

-- The NPC row's positional fields (QuestieDB.npcKeys in foreverNpcDB.lua's header).
local NPC = { name = 1, spawns = 7, questStarts = 10, friendlyToFaction = 13, subName = 14, npcFlags = 15 }
-- The item row's fields (QuestieDB.itemKeys).
local ITEM = { name = 1, vendors = 14 }
-- The correction layers, in QuestieDB's Static order (docs/forever.md): legacy, generated
-- delta-base, generated traces, authored Forever fixes.
Q.LAYERS = {
    "src/corrections/Forever/legacy/classicNPCFixes.lua",
    "src/corrections/Forever/generated/foreverBaseNpc.lua",
    "src/corrections/Forever/traces/foreverNpcTraces.lua",
    "src/corrections/Forever/foreverNPCFixes.lua",
}
-- The fields a correction may set that the probe reads (a quest relation it only notes: Forever adds
-- quests at trainers, which an in-game look settles).
local FIELDS = {
    name = true, spawns = true, friendlyToFaction = true, subName = true, npcFlags = true,
    questStarts = true, questStarts_add = true, questEnds = true, questEnds_add = true,
}
-- The NPC flag values the correction providers name (cmangos Unit.h; QuestieDB's npcFlags enum).
-- A later client's flag (BARBER, MAILBOX, TRANSMOGRIFIER) answers 0: the probe reads only the
-- vendor, quest giver and trainer bits.
local NPC_FLAGS = setmetatable({
    NONE = 0, GOSSIP = 1, QUEST_GIVER = 2, VENDOR = 4, FLIGHT_MASTER = 8, TRAINER = 16,
    SPIRIT_HEALER = 32, SPIRIT_GUIDE = 64, INNKEEPER = 128, BANKER = 256, PETITIONER = 512,
    TABARD_DESIGNER = 1024, BATTLEMASTER = 2048, AUCTIONEER = 4096, STABLEMASTER = 8192, REPAIR = 16384,
}, { __index = function() return 0 end })

-- A long-bracket data string (`X = [[return {...}]]`) out of a generated file, run in an empty
-- sandbox: a table constructor and nothing else.
local function dataTable(path, marker)
    local src = assert(IO.read(path), "cannot read " .. path)
    local body = IO.between(src, marker .. " = [[", "]]")
    assert(body, marker .. " not found in " .. path)
    local ok, t = IO.sandbox(body, marker, {})
    assert(ok and type(t) == "table", "could not load " .. marker .. ": " .. tostring(t))
    return t
end

-- The shape the probe uses for one NPC row.
local function npcRecord(id, row)
    return {
        id = id, name = row[NPC.name], subName = row[NPC.subName], flags = row[NPC.npcFlags] or 0,
        faction = row[NPC.friendlyToFaction], spawns = row[NPC.spawns] or {},
        questStarts = row[NPC.questStarts] or {},
    }
end

local function anyKey()
    return setmetatable({}, { __index = function(_, k) return k end })
end

local function anyValue()
    return setmetatable({}, { __index = function() return 0 end })
end

-- The stubs a correction provider imports: npcKeys answer their own field name, so a layer comes
-- back keyed by field; zoneIDs are QuestieDB's own (src/corrections/enum/zones.lua); anything else
-- it asks for answers 0.
local function providerEnv(zoneIDs)
    local modules = {
        QuestieDB = { npcKeys = anyKey(), npcFlags = NPC_FLAGS, npcRanks = anyValue(),
                      waypointPresets = anyValue() },
        ZoneDB = { zoneIDs = zoneIDs },
        Phasing = { phases = anyValue() },
    }
    local created
    local loader = {
        CreateModule = function() created = {} return created end,
        ImportModule = function(_, name) return modules[name] or anyValue() end,
    }
    return { QuestieLoader = loader, setmetatable = setmetatable, pairs = pairs, ipairs = ipairs },
        function() return created end
end

local function zoneIDs(dir)
    local src = IO.read(dir .. "/src/corrections/enum/zones.lua")
    if not src then return anyValue() end
    local lib = { Enum = {} }
    local ok = IO.sandbox(src, "zones.lua", {}, nil, lib)
    return ok and lib.Enum.zoneIDs or anyValue()
end

-- One layer's corrections for the NPCs in `wanted`: { [id] = { field = value } }, or nil and why.
local function layer(dir, path, zones, wanted)
    local src = IO.read(dir .. "/" .. path)
    if not src then return nil, "missing" end
    local env, module = providerEnv(zones)
    local ok, err = IO.sandbox(src, path, env)
    if not ok then return nil, err end
    local m = module()
    if not (m and type(m.Load) == "function") then return nil, "no Load" end
    local okLoad, fixes = pcall(m.Load, m)
    if not okLoad or type(fixes) ~= "table" then return nil, tostring(fixes) end
    local out = {}
    for id, fix in pairs(fixes) do
        -- A known NPC, or one the layer adds (it names it): Forever content the raw table lacks.
        if type(fix) == "table" and (wanted[id] or type(fix.name) == "string") then
            for field, value in pairs(fix) do
                if FIELDS[field] then
                    out[id] = out[id] or {}
                    out[id][field] = value
                end
            end
        end
    end
    return out
end

local function overlay(rec, fix)
    if fix.name ~= nil then rec.name = fix.name end
    if fix.subName ~= nil then rec.subName = fix.subName end
    if fix.npcFlags ~= nil then rec.flags = fix.npcFlags end
    if fix.friendlyToFaction ~= nil then rec.faction = fix.friendlyToFaction end
    if fix.spawns ~= nil then rec.spawns = fix.spawns end
    if fix.questStarts ~= nil then rec.questStarts = fix.questStarts end
    for _, q in ipairs(fix.questStarts_add or {}) do table.insert(rec.questStarts, q) end
end

-- Whether a correction sets a quest relation.
local function questFix(fix)
    return fix.questStarts_add ~= nil or fix.questEnds_add ~= nil or fix.questEnds ~= nil or fix.questStarts ~= nil
end

--- Apply the static correction layers to the NPCs in `npcs` (id -> record, from Q.Read) in
--- QuestieDB's order. Answers one { path, ok, touched, err } per layer; each corrected record
--- gains `corrected = { <layer path>, ... }`, and `foreverQuest` when a Forever layer gave it a quest.
function Q.ApplyLayers(dir, npcs)
    local zones = zoneIDs(dir)
    local results = {}
    for _, path in ipairs(Q.LAYERS) do
        local fixes, err = layer(dir, path, zones, npcs)
        local touched = 0
        for id, fix in pairs(fixes or {}) do
            if not npcs[id] then
                npcs[id] = { id = id, name = fix.name, flags = 0, spawns = {}, questStarts = {}, added = path }
            end
            overlay(npcs[id], fix)
            -- A Forever layer (not the inherited Era one) that adds a quest: Forever content at this NPC.
            if questFix(fix) and not path:find("/legacy/", 1, true) then npcs[id].foreverQuest = true end
            npcs[id].corrected = npcs[id].corrected or {}
            table.insert(npcs[id].corrected, path)
            touched = touched + 1
        end
        results[#results + 1] = { path = path, ok = fixes ~= nil, touched = touched, err = err }
    end
    return results
end

-- area_coefficients out of conversion.json, by pattern (no JSON reader in Lua 5.1): area id ->
-- { sx, ox, sy, oy }, and the set of changed areas (a non-identity transform).
local function coefficients(dir)
    local src = IO.read(dir .. "/data/Forever/conversion.json") or ""
    local block = src:match('"area_coefficients"%s*:%s*(%b{})') or ""
    local out, changed = {}, {}
    for area, body in block:gmatch('"(%d+)"%s*:%s*(%b{})') do
        local c = {
            tonumber(body:match('"scale_x"%s*:%s*([-%d.eE]+)')), tonumber(body:match('"offset_x"%s*:%s*([-%d.eE]+)')),
            tonumber(body:match('"scale_y"%s*:%s*([-%d.eE]+)')), tonumber(body:match('"offset_y"%s*:%s*([-%d.eE]+)')),
        }
        out[tonumber(area)] = c
        if c[1] ~= 1 or c[2] ~= 0 or c[3] ~= 1 or c[4] ~= 0 then changed[tonumber(area)] = true end
    end
    return out, changed
end

--- Read the checkout at `dir`: { sha, npcs (id -> record), byName (name -> { record, ... }),
--- areaToUiMap, coefficients, changedAreas, items (id -> { name, vendors }) }.
function Q.Read(dir)
    local raw = dataTable(dir .. "/data/Forever/foreverNpcDB.lua", "QuestieDB.npcData")
    local npcs, byName = {}, {}
    for id, row in pairs(raw) do
        if type(row) == "table" and type(row[NPC.name]) == "string" then
            local rec = npcRecord(id, row)
            npcs[id] = rec
            byName[rec.name] = byName[rec.name] or {}
            table.insert(byName[rec.name], rec)
        end
    end
    local items = {}
    for id, row in pairs(dataTable(dir .. "/data/Forever/foreverItemDB.lua", "QuestieDB.itemData")) do
        if type(row) == "table" then items[id] = { name = row[ITEM.name], vendors = row[ITEM.vendors] } end
    end
    local zonesPath = dir .. "/support/Forever/Zones/areaIdToUiMapId.lua"
    local areaToUiMap = dataTable(zonesPath, "ZoneDB.private.areaIdToUiMapId")
    local coeff, changed = coefficients(dir)
    return {
        sha = IO.gitHead(dir), npcs = npcs, byName = byName, items = items,
        areaToUiMap = areaToUiMap, coefficients = coeff, changedAreas = changed,
    }
end

--- Re-index `byName` after the layers renamed anything.
function Q.Reindex(db)
    db.byName = {}
    for _, rec in pairs(db.npcs) do
        db.byName[rec.name] = db.byName[rec.name] or {}
        table.insert(db.byName[rec.name], rec)
    end
end

return Q
