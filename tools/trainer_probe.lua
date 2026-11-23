-- tools/trainer_probe.lua — the offline trainer probe (GitHub issue #3). Dev-only: not in the TOC,
-- never shipped. Run from the repo root:
--
--   lua tools/trainer_probe.lua <path-to-QuestieDB> [--cmangos <ClassicDB.sql[.gz]>]
--       [--pfquest <pfQuest/db/units.lua>] [--methodgg <names.tsv>] [--itemtree <pin text>]
--       [--date YYYY-MM-DD] [--run <suffix>] [--write-provenance]
--
-- It loads defaults/Trainers_Forever.lua headless (an NS table, the way the addon's loader hands
-- one over) and checks every record against QuestieDB's Forever NPC table (name, side, role, place,
-- duplicates: tools/trainer_probe/checks.lua). The optional sources are cross-checks
-- (tools/trainer_probe/era.lua): the CMaNGOS 1.12 dump read by ItemTree's method, pfQuest's Era
-- spawns projected into Forever's frame, and a Method.gg names list. It writes
-- docs/trainer-probe/<date>[-<run>]/report.md, report.json and suggested-patch.tsv, and with
-- --write-provenance the shipped defaults/TrainerProvenance_Forever.lua.
--
-- Every source is untrusted data: Lua sources load only in an empty sandbox
-- (tools/trainer_probe/io.lua), and nothing executes from them.

local HERE = "tools/trainer_probe"
local IO = dofile(HERE .. "/io.lua")
local Q = loadfile(HERE .. "/questiedb.lua")(HERE)
local CM = loadfile(HERE .. "/cmangos.lua")(HERE)
local PF = loadfile(HERE .. "/pfquest.lua")(HERE)
local C = loadfile(HERE .. "/checks.lua")(HERE)
local E = loadfile(HERE .. "/era.lua")(HERE)
local R = loadfile(HERE .. "/report.lua")(HERE)

local Probe = {}

local USAGE = "usage: lua tools/trainer_probe.lua <path-to-QuestieDB> [--cmangos <dump>] [--pfquest <units.lua>]"
    .. " [--methodgg <names.tsv>] [--itemtree <pin>] [--date YYYY-MM-DD] [--run <suffix>] [--write-provenance]"

local VALUED = { cmangos = true, pfquest = true, methodgg = true, itemtree = true, date = true, run = true }

--- Parse the command line: { questiedb, cmangos, pfquest, methodgg, itemtree, date, run, provenance }.
function Probe.Args(argv)
    local opts, i = {}, 1
    while i <= #argv do
        local a = argv[i]
        local flag = a:match("^%-%-([%w-]+)$")
        if flag == "write-provenance" then
            opts.provenance = true
        elseif flag and VALUED[flag] then
            i = i + 1
            opts[flag] = assert(argv[i], "--" .. flag .. " wants a value\n" .. USAGE)
        elseif not flag and not opts.questiedb then
            opts.questiedb = a
        else
            error("unknown argument " .. a .. "\n" .. USAGE)
        end
        i = i + 1
    end
    assert(opts.questiedb, USAGE)
    opts.date = opts.date or os.date("%Y-%m-%d")
    assert(opts.date:match("^%d%d%d%d%-%d%d%-%d%d$"), "--date wants YYYY-MM-DD")
    return opts
end

--- The shipped records, loaded the way the addon's loader runs a file: `local _, NS = ...`.
function Probe.Records(repo)
    local NS = { L = setmetatable({}, { __index = function(_, k) return k end }), DataMeta = {} }
    local fn = assert(loadfile((repo or ".") .. "/defaults/Trainers_Forever.lua"))
    fn("SkillMaster", NS)
    return NS.Trainers_Forever
end

local function changedMap(db, spawn)
    return spawn and db.changedAreas[spawn.area]
end

-- The spot-check reasons of one checked record.
local function spotReasons(r, rec, db)
    local out = {}
    if not r.confirmed then out[#out + 1] = "not confirmed: " .. r.reason end
    if r.confirmed and changedMap(db, r.checks.place.spawn) then
        out[#out + 1] = "Forever re-bounded this map; the point is QuestieDB's projection of the Era spawn"
    end
    for _, src in ipairs({ "cmangos", "pfquest", "methodgg" }) do
        local n = r.era[src]
        if n and not n.agree and not n.rankOff and not n.neutral then out[#out + 1] = src .. ": " .. n.msg end
    end
    if rec.learn then out[#out + 1] = ("confirm the rank is learned from %s"):format(rec.learn.item or rec.learn.quest) end
    return out
end

local function addPatch(r, field, shipped, suggested, why)
    if suggested ~= nil and suggested ~= shipped then
        r.patch[#r.patch + 1] = { field = field, shipped = shipped, suggested = suggested, why = why }
    end
end

local function firstFailure(checks)
    for _, k in ipairs({ "name", "faction", "role", "place", "duplicate" }) do
        if checks[k] and not checks[k].ok then return k .. ": " .. checks[k].msg end
    end
    return nil
end

-- The checks of one record: { id, name, npcID, checks, era, patch, confirmed, reason, spot }.
local function checkRecord(rec, src, dupes)
    local r = { id = rec.id, name = rec.name, faction = rec.faction, city = rec.city, mapID = rec.mapID,
                x = rec.x, y = rec.y, checks = {}, era = {}, patch = {} }
    local nameCheck = C.Name(rec, src.qdb)
    r.checks.name = nameCheck
    local npc = nameCheck.npc
    if nameCheck.suggest then addPatch(r, "name", rec.name, nameCheck.suggest.name, "the NPC's name in the source") end
    if npc then
        r.npcID, r.foreverQuest = npc.id, npc.foreverQuest
        addPatch(r, "npcID", rec.npcID, npc.id, "the matched NPC")
        r.checks.faction = C.SideOK(rec.faction, npc.faction) and { ok = true }
            or { ok = false, msg = ("the source's side is %q"):format(tostring(npc.faction)) }
        r.checks.role = C.Role(rec, npc, src.qdb)
        r.checks.place = C.Place(rec, npc, src.qdb)
        local s = r.checks.place.suggest
        if s then
            addPatch(r, "x", rec.x, s.x, r.checks.place.msg)
            addPatch(r, "y", rec.y, s.y, r.checks.place.msg)
        end
        r.era.cmangos = E.Cmangos(rec, npc.id, src.cm)
        r.era.pfquest = E.Pfquest(r.checks.place.spawn, npc.id, src.pf, src.qdb.coefficients)
    end
    r.era.methodgg = E.Methodgg(rec, src.names)
    if dupes[rec.id] then
        r.checks.duplicate = { ok = false, msg = "shares its point with " .. table.concat(dupes[rec.id], ", ") }
    end
    r.reason = firstFailure(r.checks)
    r.confirmed = r.reason == nil and npc ~= nil
    r.spot = spotReasons(r, rec, src.qdb)
    return r
end

local function titled(subName)
    if not subName then return false end
    if subName == "Weapon Master" then return true end
    for _, skill in pairs(C.SKILLS) do
        for _, w in ipairs(skill.words) do
            if (" " .. subName .. " "):find("[^%a]" .. w .. "[^%a]") then return true end
        end
    end
    return false
end

-- The Forever-only trainers: QuestieDB NPCs with the trainer bit and a skill title, absent from the
-- 1.12 dump and from the shipped records.
local function foreverOnly(src, shipped)
    if not src.cm then return {} end
    local out = {}
    for id, npc in pairs(src.qdb.npcs) do
        if C.Bit(npc.flags, C.TRAINER) and titled(npc.subName) and not src.cm.creatures[id] and not shipped[id] then
            local area = next(npc.spawns or {})
            out[#out + 1] = { id = id, name = npc.name, subName = npc.subName, uiMap = area and src.qdb.areaToUiMap[area] }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local function readSources(opts)
    local src = { qdb = Q.Read(opts.questiedb) }
    src.layers = Q.ApplyLayers(opts.questiedb, src.qdb.npcs)
    Q.Reindex(src.qdb)
    local list = { { name = "QuestieDB (github.com/Questie/QuestieDB), data/Forever",
                     pin = "commit " .. tostring(src.qdb.sha), use = "Forever names, titles, flags, sides, spawns, book vendors; the per-area transform" } }
    if opts.cmangos then
        src.cm = CM.Read(opts.cmangos)
        list[#list + 1] = { name = "CMaNGOS classic-db (github.com/cmangos/classic-db), read by ItemTree's method",
                            pin = "sha256 " .. tostring(IO.sha256(opts.cmangos)), use = "1.12 trainer rows, rank books and vendors, rank quests" }
    end
    if opts.pfquest then
        src.pf = PF.Read(opts.pfquest)
        list[#list + 1] = { name = "pfQuest db/units.lua (github.com/shagu/pfQuest)", pin = "sha256 " .. tostring(IO.sha256(opts.pfquest)),
                            use = "Era spawns, projected into Forever's frame" }
    end
    if opts.methodgg then
        local urls
        src.names, urls = E.ReadNames(assert(IO.read(opts.methodgg)))
        list[#list + 1] = { name = "Method.gg WoW Forever profession guides", pin = ("%d pages read %s"):format(#urls, opts.date),
                            use = "which NPCs the guides name (names only)" }
        src.urls = urls
    end
    if opts.itemtree then
        list[#list + 1] = { name = "ItemTree (curseforge.com/wow/addons/itemtree)", pin = opts.itemtree,
                            use = "the method only (Core/TrainerSearch.lua): rank spells over titles, CMaNGOS + pfQuest + QuestieDB" }
    end
    src.list = list
    return src
end

--- Run the probe over `records` with the sources `src`: the run table the writers take.
function Probe.Run(records, src, opts)
    local dupes = C.Duplicates(records)
    local run = { results = {}, confirmed = 0, tolerance = C.TOLERANCE, sources = src.list, layers = src.layers,
                  cmangos = src.cm ~= nil, date = opts.date, urls = src.urls }
    local shipped = {}
    for _, rec in ipairs(records) do
        local r = checkRecord(rec, src, dupes)
        run.results[#run.results + 1] = r
        if r.confirmed then run.confirmed = run.confirmed + 1 end
        if r.npcID then shipped[r.npcID] = true end
    end
    run.foreverOnly = foreverOnly(src, shipped)
    run.rankOff, run.foreverQuests = {}, {}
    for _, r in ipairs(run.results) do
        if r.era.cmangos and r.era.cmangos.rankOff then run.rankOff[#run.rankOff + 1] = r.id end
        if r.foreverQuest then run.foreverQuests[#run.foreverQuests + 1] = r.id end
    end
    run.tag = "questiedb@" .. tostring(src.qdb.sha):sub(1, 12)
    return run
end

local function write(run, opts)
    run.label = opts.date .. (opts.run and ("-" .. opts.run) or "")
    run.reportDir = "docs/trainer-probe/" .. run.label
    IO.mkdirs(run.reportDir)
    IO.writeCRLF(run.reportDir .. "/report.md", R.Markdown(run))
    local json = { date = run.date, label = run.label, tag = run.tag, tolerance = run.tolerance, confirmed = run.confirmed,
                   sources = run.sources, foreverOnly = run.foreverOnly, methodggPages = run.urls,
                   rankOneBelowInDump = run.rankOff, foreverQuests = run.foreverQuests, records = {} }
    for _, r in ipairs(run.results) do
        json.records[#json.records + 1] = { id = r.id, name = r.name, npcID = r.npcID, confirmed = r.confirmed,
            reason = r.reason, spot = r.spot, patch = r.patch, checks = {
                name = r.checks.name and r.checks.name.ok, role = r.checks.role and r.checks.role.ok,
                place = r.checks.place and r.checks.place.ok, faction = r.checks.faction and r.checks.faction.ok,
                duplicate = r.checks.duplicate == nil } }
    end
    IO.writeCRLF(run.reportDir .. "/report.json", R.JSON(json))
    IO.writeCRLF(run.reportDir .. "/suggested-patch.tsv", R.Patch(run))
    if opts.provenance then IO.writeCRLF("defaults/TrainerProvenance_Forever.lua", R.Provenance(run)) end
end

function Probe.Main(argv)
    local opts = Probe.Args(argv)
    local src = readSources(opts)
    local run = Probe.Run(Probe.Records("."), src, opts)
    write(run, opts)
    print(("%d records, %d confirmed; report in %s"):format(#run.results, run.confirmed, run.reportDir))
end

-- Run as a script; return the module when loaded by the headless suite (tests/test_trainer_probe.lua).
if arg and arg[0] and arg[0]:match("trainer_probe%.lua$") then
    Probe.Main(arg)
end
return Probe
