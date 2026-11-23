-- tools/trainer_probe/report.lua — the trainer probe's writers (GitHub issue #3): report.md,
-- report.json, suggested-patch.tsv and the shipped provenance file
-- (defaults/TrainerProvenance_Forever.lua).
--
-- Licensing (issue #3): what is written holds Skill Master's own records, the checks' verdicts and
-- the sources' commits. A source's value appears only where a check quotes it against one record
-- (a name, a title, a spawn point) or a patch proposes it as that record's corrected number; no
-- source table is copied.

local R = {}

-- ---------------------------------------------------------------------------------------------
-- JSON (a small encoder: the report's values are strings, numbers, booleans and tables)
-- ---------------------------------------------------------------------------------------------

local function isArray(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n == #t
end

local function quote(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        local named = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
        return named[c] or ("\\u%04x"):format(c:byte())
    end) .. '"'
end

local encode

local function encodeTable(t, indent)
    local pad, inner = ("  "):rep(indent), ("  "):rep(indent + 1)
    local parts = {}
    if isArray(t) then
        if #t == 0 then return "[]" end
        for _, v in ipairs(t) do parts[#parts + 1] = inner .. encode(v, indent + 1) end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "]"
    end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = t[k]
        if v == nil then v = t[tonumber(k)] end
        parts[#parts + 1] = inner .. quote(k) .. ": " .. encode(v, indent + 1)
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

function encode(v, indent)
    local kind = type(v)
    if kind == "table" then return encodeTable(v, indent or 0) end
    if kind == "string" then return quote(v) end
    if kind == "number" then
        if v == math.floor(v) then return ("%d"):format(v) end
        return (("%.4f"):format(v):gsub("0+$", ""))
    end
    if kind == "boolean" then return tostring(v) end
    return "null"
end
R.JSON = function(v) return encode(v, 0) .. "\n" end

-- ---------------------------------------------------------------------------------------------
-- Markdown
-- ---------------------------------------------------------------------------------------------

local function cell(s)
    return (tostring(s or ""):gsub("|", "\\|"):gsub("\n", " "))
end

local function verdict(c)
    if c == nil then return "-" end
    return c.ok and "ok" or ("**" .. cell(c.msg) .. "**")
end

local function note(n)
    if n == nil then return "-" end
    return (n.agree and "" or "**") .. cell(n.msg) .. (n.agree and "" or "**")
end

local function sourcesSection(out, run)
    out[#out + 1] = "## Sources"
    out[#out + 1] = ""
    out[#out + 1] = "| Source | Pin | Read for |"
    out[#out + 1] = "| --- | --- | --- |"
    for _, s in ipairs(run.sources) do
        out[#out + 1] = ("| %s | %s | %s |"):format(cell(s.name), cell(s.pin), cell(s.use))
    end
    out[#out + 1] = ""
    for _, l in ipairs(run.layers or {}) do
        out[#out + 1] = ("- QuestieDB layer `%s`: %s, %d NPCs of the table corrected or added%s."):format(
            l.path, l.ok and "loaded" or "not loaded", l.touched, l.err and (" (" .. cell(l.err) .. ")") or "")
    end
    out[#out + 1] = ""
end

local function findingsSection(out, run)
    out[#out + 1] = "## Findings"
    out[#out + 1] = ""
    out[#out + 1] = "Every record that fails a check, by check. A record with no line here is confirmed."
    out[#out + 1] = ""
    for _, check in ipairs({ "name", "faction", "role", "place", "duplicate" }) do
        local rows, bare = {}, {}
        for _, r in ipairs(run.results) do
            local c = r.checks[check]
            if c and not c.ok and c.msg == "no coordinates shipped" then
                bare[#bare + 1] = "`" .. r.id .. "`"
            elseif c and not c.ok then
                rows[#rows + 1] = ("- `%s` %s: %s"):format(r.id, r.name, cell(c.msg))
            end
        end
        out[#out + 1] = ("### %s (%d)"):format(check, #rows + #bare)
        out[#out + 1] = ""
        for _, l in ipairs(rows) do out[#out + 1] = l end
        if #bare > 0 then
            out[#out + 1] = ("- No coordinates shipped, one standing point in the source (suggested-patch.tsv has it), %d records: %s"):format(#bare, table.concat(bare, ", "))
        end
        if #rows + #bare == 0 then out[#out + 1] = "None." end
        out[#out + 1] = ""
    end
    if #(run.rankOff or {}) > 0 then
        out[#out + 1] = "### The 1.12 dump's ranks (cross-check only)"
        out[#out + 1] = ""
        out[#out + 1] = ("Read by ItemTree's method (rank spells over titles), the 1.12 dump has %d titled trainers teach one rank below their title (a Journeyman trainer to 75, an Artisan to 225), where QuestieDB's Forever titles agree with the records. The probe keeps the titles; one in-game look at a Journeyman and an Artisan trainer settles which holds on Forever. Records: %s."):format(#run.rankOff, table.concat(run.rankOff, ", "))
        out[#out + 1] = ""
    end
end

local function recordsSection(out, run)
    out[#out + 1] = "## Every record"
    out[#out + 1] = ""
    out[#out + 1] = "| Record | NPC | Name | Role | Place | Confirmed | 1.12 dump (ItemTree's method) | pfQuest, projected | Method.gg |"
    out[#out + 1] = "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    for _, r in ipairs(run.results) do
        out[#out + 1] = ("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |"):format(r.id, r.npcID or "-",
            verdict(r.checks.name), verdict(r.checks.role), verdict(r.checks.place), r.confirmed and "yes" or "no",
            note(r.era.cmangos), note(r.era.pfquest), note(r.era.methodgg))
    end
    out[#out + 1] = ""
end

local function spotSection(out, run)
    out[#out + 1] = "## In-game spot checks"
    out[#out + 1] = ""
    out[#out + 1] = "No offline source settles these. Each wants a look in game (both factions as listed)."
    out[#out + 1] = ""
    for _, r in ipairs(run.results) do
        if #r.spot > 0 then
            out[#out + 1] = ("- `%s` %s (%s, %s): %s"):format(r.id, r.name, r.faction, r.city, cell(table.concat(r.spot, "; ")))
        end
    end
    out[#out + 1] = ""
    if #(run.foreverQuests or {}) > 0 then
        out[#out + 1] = ("QuestieDB's Forever layers (not the inherited Era one) add quests at %d of these NPCs, Forever content an Era source cannot know: %s."):format(
            #run.foreverQuests, table.concat(run.foreverQuests, ", "))
        out[#out + 1] = ""
    end
    out[#out + 1] = ("### Forever-only trainers Skill Master does not ship (%d)"):format(#run.foreverOnly)
    out[#out + 1] = ""
    out[#out + 1] = "Trainer NPCs in QuestieDB's Forever table with a profession, riding or weapon title and no row in the 1.12 dump: new on Forever, so neither Era source knows them."
    out[#out + 1] = ""
    for _, n in ipairs(run.foreverOnly) do
        out[#out + 1] = ("- %s (npc %d, %s, uiMap %s)"):format(n.name, n.id, cell(n.subName), tostring(n.uiMap or "?"))
    end
    if #run.foreverOnly == 0 then out[#out + 1] = run.cmangos and "None." or "Not computed: no `--cmangos` dump given." end
    out[#out + 1] = ""
end

--- The report's markdown.
function R.Markdown(run)
    local out = {}
    out[#out + 1] = ("# Trainer probe, %s"):format(run.label)
    out[#out + 1] = ""
    out[#out + 1] = ("Generated by `lua tools/trainer_probe.lua` (GitHub issue #3) over %d records of `defaults/Trainers_Forever.lua`. Offline: no game client, no network."):format(#run.results)
    out[#out + 1] = ""
    out[#out + 1] = ("**%d confirmed, %d not.** Tolerance %.1f map-%%; a record is confirmed when its name, side, role and place agree with QuestieDB's Forever NPC table and no other NPC shares its point."):format(run.confirmed, #run.results - run.confirmed, run.tolerance)
    out[#out + 1] = ""
    sourcesSection(out, run)
    findingsSection(out, run)
    spotSection(out, run)
    recordsSection(out, run)
    out[#out + 1] = "## Licensing"
    out[#out + 1] = ""
    out[#out + 1] = "QuestieDB (GPLv3 for contributions), the CMaNGOS dump (GPL-3.0), pfQuest (MIT), ItemTree (All Rights Reserved) and Method.gg are cited, not copied: this report quotes a source only against one of Skill Master's records, and the addon ships only its own corrected numbers and the commits above (`NS.DataMeta.Trainers_Forever`)."
    out[#out + 1] = ""
    return table.concat(out, "\n")
end

--- suggested-patch.tsv: one row per proposed field change.
function R.Patch(run)
    local out = { "id\tfield\tshipped\tsuggested\twhy" }
    for _, r in ipairs(run.results) do
        for _, p in ipairs(r.patch) do
            out[#out + 1] = table.concat({ r.id, p.field, tostring(p.shipped), tostring(p.suggested), p.why }, "\t")
        end
    end
    return table.concat(out, "\n") .. "\n"
end

-- ---------------------------------------------------------------------------------------------
-- The shipped provenance file
-- ---------------------------------------------------------------------------------------------

local function luaString(s)
    return ("%q"):format(s):gsub("\\\n", "\\n")
end

local function num(v)
    if v == nil then return "nil" end
    if v == math.floor(v) then return ("%d"):format(v) end
    return ("%.1f"):format(v)
end

--- defaults/TrainerProvenance_Forever.lua: each record's confirmation (the values the probe
--- confirmed, so a later edit shows) or its reason, and the run's sources in NS.DataMeta.
function R.Provenance(run)
    local out = {
        "local _, NS = ...",
        "-- defaults/TrainerProvenance_Forever.lua — GENERATED by `lua tools/trainer_probe.lua ... --write-provenance`",
        "-- (GitHub issue #3); do not edit by hand, re-run the probe. Read by defaults/Trainers_Forever.lua.",
        "--",
        "-- confirmed: the records the offline probe confirmed, each with the values it confirmed (a record",
        "-- edited since no longer matches, and tests/test_trainers.lua fails until the probe runs again).",
        "-- unverified: every other record, with the reason no source settles it.",
        "",
        "NS.DataMeta = NS.DataMeta or {}",
        "NS.DataMeta.Trainers_Forever = {",
        "    source = \"the offline trainer probe, tools/trainer_probe.lua (GitHub issue #3)\",",
        ("    verified = %s, report = %s, date = %s,"):format(luaString(run.tag), luaString(run.reportDir), luaString(run.date)),
        "    sources = {",
    }
    for _, s in ipairs(run.sources) do
        out[#out + 1] = ("        { name = %s, pin = %s },"):format(luaString(s.name), luaString(s.pin))
    end
    out[#out + 1] = "    },"
    out[#out + 1] = "}"
    out[#out + 1] = ""
    out[#out + 1] = "NS.TrainerProvenance_Forever = {"
    out[#out + 1] = "    confirmed = {"
    for _, r in ipairs(run.results) do
        if r.confirmed then
            out[#out + 1] = ("        [%s] = { npcID = %d, name = %s, mapID = %d, x = %s, y = %s },"):format(
                luaString(r.id), r.npcID, luaString(r.name), r.mapID, num(r.x), num(r.y))
        end
    end
    out[#out + 1] = "    },"
    out[#out + 1] = "    unverified = {"
    for _, r in ipairs(run.results) do
        if not r.confirmed then out[#out + 1] = ("        [%s] = %s,"):format(luaString(r.id), luaString(r.reason)) end
    end
    out[#out + 1] = "    },"
    out[#out + 1] = "}"
    return table.concat(out, "\n") .. "\n"
end

return R
