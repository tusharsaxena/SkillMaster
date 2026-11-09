local _, NS = ...
-- settings/Schema.lua — the schema (one row per setting: panel, CLI and reset from one table) and
-- the single write seam NS.SetByPath, built on LibKa0s-Schema-1.0 (architecture-§5).
--
-- LOAD-BEARING: publishes NS.Schema, NS.SchemaRuntime, NS.RegisterSchemaRows and NS.SetByPath,
-- which settings/Slash.lua, settings/OptionsSetup.lua and settings/General.lua read at load.

NS.Schema = NS.Schema or {}
local BRAND = NS.Constants.BRAND

-- The degradation stub (options-ui-§1, route (a)): the library table's surface and an instance
-- that still reads and writes the profile, so `/skm enable` lands on a library-absent load.
local function HostSchemaStub()
    local stubLib = {}
    local function copy(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, x in pairs(v) do out[k] = copy(x) end
        return out
    end
    function stubLib.SplitPath(path)
        local parts = {}
        if path ~= nil then
            for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
        end
        return parts
    end
    local function partsOf(p) return type(p) == "table" and p or stubLib.SplitPath(p) end
    function stubLib.Read(root, p, first)
        local parts, node = partsOf(p), root
        first = first or 1
        if type(root) ~= "table" or #parts < first then return nil end
        for i = first, #parts do
            if type(node) ~= "table" then return nil end
            node = node[parts[i]]
        end
        return node
    end
    function stubLib.Write(root, p, value, first)
        local parts, node = partsOf(p), root
        first = first or 1
        if type(root) ~= "table" or #parts < first then return end
        for i = first, #parts - 1 do
            if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
            node = node[parts[i]]
        end
        node[parts[#parts]] = value
    end
    function stubLib.SameValue(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        for k, v in pairs(a) do if not stubLib.SameValue(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end

    local function instanceReads(S, d, rows, through)
        local function resolve(parts, id)
            if type(d.resolveRoot) ~= "function" then return nil end
            return d.resolveRoot(parts, id)
        end
        function S.AllRows() return rows end
        function S.FindRow(path)
            if type(path) ~= "string" then return nil end
            for _, row in ipairs(rows) do
                if type(row) == "table" and row.path == path then return row end
            end
        end
        local function writeRow(path) return S.FindRow(path) or (type(path) == "string" and through[path]) end
        function S.AddRows(list, at)
            if type(list) ~= "table" then return 0 end
            at = type(at) == "number" and math.floor(at) or #rows + 1
            if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
            for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
            return #list
        end
        function S.Reindex() end
        function S.Get(path, id)
            local row = S.FindRow(path)
            if row and type(row.get) == "function" then return row.get(id) end
            if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
            local parts = stubLib.SplitPath(path)
            local root, first = resolve(parts, id)
            if type(root) ~= "table" then return nil end
            return stubLib.Read(root, parts, first)
        end
        return resolve, writeRow
    end

    local function instanceWrites(S, d, resolve, writeRow)
        local function prepare(path, value, id)
            local row = writeRow(path)
            if not row then return nil, BRAND .. ": no setting " .. tostring(path) end
            local w = { row = row, path = path, value = value, rid = id }
            w.stored = type(row.set) ~= "function" and not row.sessionOnly
            if w.stored then
                w.parts = stubLib.SplitPath(path)
                local r, f = resolve(w.parts, id)
                if type(r) == "table" then w.root, w.first = r, f end
            end
            if type(row.validate) == "function" then
                local ok, why = row.validate(value, id)
                if not ok then return nil, BRAND .. ": invalid value for " .. path, why end
            end
            if w.stored and not w.root then return nil, BRAND .. ": nowhere to store " .. path end
            return w
        end
        local function commit(w)
            if type(w.row.set) == "function" then
                w.row.set(w.value)
            elseif w.stored then
                stubLib.Write(w.root, w.parts, copy(w.value), w.first)
            end
            if type(w.row.onChange) == "function" then w.row.onChange(w.value, w.rid) end
            if type(d.announce) == "function" then d.announce(w.row, w.path, w.value, w.rid) end
        end
        function S.Set(path, value, id)
            local w, err, why = prepare(path, value, id)
            if not w then return false, err, why end
            commit(w)
            return true
        end
        function S.SetMany(entries, opts)
            local id = type(opts) == "table" and opts.instanceId or nil
            local ws = {}
            for i, e in ipairs(type(entries) == "table" and entries or {}) do
                local w, err, why = prepare(type(e) == "table" and e.path, type(e) == "table" and e.value, id)
                if not w then return false, err, why, i end
                ws[i] = w
            end
            for _, w in ipairs(ws) do commit(w) end
            return true
        end
    end

    local function instanceBulk(S, d)
        local depth = 0
        function S.Default(path)
            local row = S.FindRow(path)
            return row and copy(row.default)
        end
        function S.ApplyDefault(row, id)
            if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then return false end
            local exempt = d.resetExempt
            if depth > 0 and type(exempt) == "table" and exempt[row.path] then return false end
            return S.Set(row.path, copy(row.default), id)
        end
        function S.BulkBegin() depth = depth + 1 end
        function S.BulkEnd() if depth > 0 then depth = depth - 1 end end
        function S.BulkRun(act, scope, fn)
            S.BulkBegin(act, scope)
            local ok, err = pcall(fn, { profileReset = false })
            S.BulkEnd(act, scope)
            if not ok then error(err, 0) end
        end
        function S.BulkAdd() end
        function S.InBulk() return depth > 0 end
        function S.CountOffDefault() return 0 end
        function S.ResetCounted(fn) fn() end
        function S.ConsumeResetCount() return nil end
        function S.Validate()
            if type(d.print) == "function" then
                d.print(BRAND .. ": LibKa0s-Schema-1.0 is missing, so the schema was not checked")
            end
            return 0, 0, 0
        end
    end

    function stubLib.New(_, d)
        local S, through = {}, {}
        for _, p in ipairs(type(d.writeThrough) == "table" and d.writeThrough or {}) do
            if type(p) == "string" then through[p] = { path = p, writeThrough = true } end
        end
        local resolve, writeRow = instanceReads(S, d, d.rows, through)
        instanceWrites(S, d, resolve, writeRow)
        instanceBulk(S, d)
        return S
    end
    return stubLib
end

local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or HostSchemaStub()
NS.__schemaLib = SchemaLib   -- the surface-parity case reads the stub through this

local MINIMAP_PATH = NS.Constants.MINIMAP_PATH

local S = SchemaLib:New({
    rows = NS.Schema,
    -- The composed Master-controls rows the host verbs write (options-ui-§1, route (a)).
    writeThrough = { "enabled", "locked" },
    -- `global.*` lives in the AceDB global store; everything else in the active profile.
    resolveRoot = function(parts)
        local db = NS.db
        if parts[1] == "global" then return db and db.global, 2 end
        return db and db.profile, 1
    end,
    -- A write through `writeThrough` on a hollow load still reaches its reaction.
    announce = function(row)
        if row.writeThrough and NS.MasterReactions and NS.MasterReactions[row.path] then
            NS.MasterReactions[row.path]()
        end
    end,
    debug        = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    debugEnabled = function() return NS.State.debug == true end,
    print        = function(line) NS.Print(line) end,
    -- The minimap row survives every reset (launcher-§3, anti-pattern #83).
    resetExempt  = { [MINIMAP_PATH] = true },
})
NS.SchemaRuntime      = S
NS.RegisterSchemaRows = S.AddRows
NS.FindSchemaRow      = S.FindRow
NS.SetByPath          = S.Set          -- THE single write seam (architecture-§5)
NS.ApplyDefault       = S.ApplyDefault
NS.ResolvePath        = SchemaLib.Read

--- A setting's current value, falling back to the defaults tree before the store exists.
function NS.GetSetting(path)
    local v = S.Get(path)
    if v ~= nil then return v end
    local parts = SchemaLib.SplitPath(path)
    if parts[1] == "global" then return SchemaLib.Read(NS.defaults.global, parts, 2) end
    return SchemaLib.Read(NS.defaults.profile, parts, 1)
end

--- The rows one settings page renders, in declaration order.
function NS.SchemaForPage(pageKey)
    local out = {}
    for _, row in ipairs(NS.Schema) do
        if row.page == pageKey then out[#out + 1] = row end
    end
    return out
end

--- The global reset is a profile reset (options-ui-§12), counted for its one [Set] line.
function NS.ResetProfileCounted(db)
    S.ResetCounted(function() db:ResetProfile() end, function(row)
        return row.path ~= MINIMAP_PATH and row.page ~= "profiles"
    end)
end

local VALID_PAGES = { general = true, profiles = true }
local function defaultsRoot(parts, row)
    if row.page == "profiles" or type(row.get) == "function" then return nil end
    if parts[1] == "global" then return NS.defaults.global, 2 end
    return NS.defaults.profile, 1
end

--- Every path resolves against the defaults tree; answers the error count.
function NS.ValidateSchema()
    return S.Validate({ pages = VALID_PAGES, defaultsRoot = defaultsRoot })
end
