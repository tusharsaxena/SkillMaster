local _ = ...
-- tests/test_locale.lua — the locale gates (localization-§1, §3, §5, §6, §7).
--
-- NS.L is ONE table that locales/enUS.lua creates. Every gate measures the union of the enUS files,
-- read from the TOC (a topic file added later is read without editing this suite), loaded in TOC
-- order into one fresh namespace and read RAW, so the key-on-miss fallback cannot answer for a
-- missing key. A key written twice is found from the files' text, because the table keeps the last
-- write only.
--
-- Both directions (localization-§3): every literal `L["..."]` in an addon file has an enUS entry,
-- and every enUS key is a string literal somewhere in the addon's own files (enUS keeps no key that
-- nothing reads). The other locales are stubs a translator fills: each one's first statement is its
-- own GetLocale() guard, it writes nothing on another client, and what it writes on its own is a
-- subset of the enUS keys whose format directives match the English's.
--
-- red under: delete an entry a file reads; leave one behind after its last reader goes; write one
-- key twice; leave a `true` unreplaced; ungate a stub or gate it on another locale; put a key in a
-- stub that enUS lacks; drop a `%d` from a translation; route a fresh string without its entry.

local T = _G.SKM_TEST
local test, assertTrue, assertEqual = T.test, T.assertTrue, T.assertEqual

local TOC = "SkillMaster.toc"

local function readFile(rel)
    local f = assert(io.open(rel, "rb"))
    local text = f:read("*a")
    f:close()
    return (text:gsub("\r\n", "\n"))
end

local TOC_FILES = T.Loader.tocFiles(TOC)

local function isEnUS(rel) return rel == "locales/enUS.lua" or rel:match("^locales/enUS_.+%.lua$") ~= nil end

local function enUSFiles()
    local out = {}
    for _, rel in ipairs(TOC_FILES) do if isEnUS(rel) then out[#out + 1] = rel end end
    return out
end
local ENUS_FILES = enUSFiles()

-- Every other locale's files: { rel, locale }.
local function stubFiles()
    local out = {}
    for _, rel in ipairs(TOC_FILES) do
        local loc = rel:match("^locales/(%l%l%u%u)[%w_]*%.lua$")
        if loc and loc ~= "enUS" then out[#out + 1] = { rel = rel, locale = loc } end
    end
    return out
end

-- The addon's own files in TOC order, less the locales.
local function addonFiles()
    local out = {}
    for _, rel in ipairs(TOC_FILES) do
        if not rel:match("^locales/") then out[#out + 1] = rel end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- A small Lua lexer: every string literal of a chunk, decoded, with what precedes it. Comments and
-- long strings are honored so a `--` inside a literal or a quote inside a comment cannot confuse it.
-- ---------------------------------------------------------------------------------------------

local NAMED = { a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", v = "\v" }

local function decode(raw)
    local out, i = {}, 1
    while i <= #raw do
        local c = raw:sub(i, i)
        if c ~= "\\" then
            out[#out + 1], i = c, i + 1
        else
            local digits = raw:match("^%d%d?%d?", i + 1)
            if digits then
                out[#out + 1], i = string.char(tonumber(digits)), i + 1 + #digits
            else
                local e = raw:sub(i + 1, i + 1)
                out[#out + 1], i = NAMED[e] or e, i + 2
            end
        end
    end
    return table.concat(out)
end

-- The end of a long bracket opened at `pos` (`[[`, `[==[`), or nil when `pos` opens none.
local function longClose(text, pos)
    local eq = text:match("^%[(=*)%[", pos)
    if not eq then return nil end
    local _, stop = text:find("]" .. eq .. "]", pos + #eq + 2, true)
    return stop or #text, #eq
end

-- The closing quote of a short string opened at `pos`.
local function shortClose(text, pos, q)
    local i = pos + 1
    while i <= #text do
        local c = text:sub(i, i)
        if c == "\\" then i = i + 2
        elseif c == q or c == "\n" then return i
        else i = i + 1 end
    end
    return #text
end

-- { text, routed } per literal: routed when the literal is the index of `L[` (bare or `NS.L[`).
local function literalsOf(text)
    local out, i, n = {}, 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == "-" and text:sub(i + 1, i + 1) == "-" then
            local stop = longClose(text, i + 2)
            i = (stop or (text:find("\n", i, true) or n)) + 1
        elseif c == '"' or c == "'" then
            local stop = shortClose(text, i, c)
            local before = text:sub(1, i - 1)
            local routed = before:match("%f[%w_]L%[$") ~= nil
            out[#out + 1] = { text = decode(text:sub(i + 1, stop - 1)), routed = routed }
            i = stop + 1
        elseif c == "[" and longClose(text, i) then
            local stop, eq = longClose(text, i)
            out[#out + 1] = { text = text:sub(i + eq + 2, stop - eq - 2):gsub("^\n", ""), routed = false }
            i = stop + 1
        else
            i = i + 1
        end
    end
    return out
end

-- One file's key lines as { path, line, key }.
local function keyLinesOf(path)
    local out, n = {}, 0
    for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        local raw = line:match('^L%["(.-)"%]%s*=')
        if raw then out[#out + 1] = { path = path, line = n, key = decode(raw) } end
    end
    return out
end

local function enUSKeyLines()
    local out = {}
    for _, path in ipairs(ENUS_FILES) do
        for _, k in ipairs(keyLinesOf(path)) do out[#out + 1] = k end
    end
    return out
end

-- The enUS table: the files in TOC order into one fresh namespace, read raw.
local function enUS()
    local NS = {}
    for _, path in ipairs(ENUS_FILES) do assert(loadfile(path))("SkillMaster", NS) end
    assertTrue(type(NS.L) == "table", "locales/enUS.lua publishes NS.L")
    local raw = {}
    for k, v in pairs(NS.L) do raw[k] = v end
    return raw, NS.L
end

local function firstStatement(text)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line:find("%S") and not line:find("^%s*%-%-") then return line end
    end
    return nil
end

-- A stub run on a client of `clientLocale`, into a recording NS.L: the keys it wrote, with values.
local function stubWrites(path, clientLocale)
    local written = {}
    local L = setmetatable({}, { __newindex = function(t, k, v)
        written[#written + 1] = { key = k, value = v }
        rawset(t, k, v)
    end })
    local chunk = assert(loadfile(path))
    setfenv(chunk, setmetatable({ GetLocale = function() return clientLocale end }, { __index = _G }))
    chunk("SkillMaster", { L = L })
    return written
end

local function directives(s)
    local out = {}
    for d in s:gsub("%%%%", ""):gmatch("%%[-+ #0]*%d*%.?%d*[%a]") do out[#out + 1] = d:sub(-1) end
    return table.concat(out, ",")
end

-- ---------------------------------------------------------------------------------------------

test("locale: the enUS files are the TOC's, the base first, before every other locale", function()
    assertTrue(#ENUS_FILES >= 1, "the TOC lists locales/enUS.lua")
    assertEqual(ENUS_FILES[1], "locales/enUS.lua")
    local firstStub
    for i, rel in ipairs(TOC_FILES) do
        if rel:match("^locales/") and not isEnUS(rel) then firstStub = firstStub or i end
        if isEnUS(rel) then assertTrue(firstStub == nil, rel .. " loads after a translation") end
    end
end)

test("locale: NS.L answers the key on a miss, and every entry answers a string, never `true`", function()
    local raw, L = enUS()
    assertEqual(L["a key nobody wrote"], "a key nobody wrote")
    for k, v in pairs(raw) do
        assertEqual(type(v), "string", "L[" .. k .. "] answers a " .. type(v))
        assertEqual(v, k, "an enUS value differs from its key")
    end
end)

test("locale: every routed literal has an enUS entry", function()
    local raw = enUS()
    local missing = {}
    for _, rel in ipairs(addonFiles()) do
        for _, lit in ipairs(literalsOf(readFile(rel))) do
            if lit.routed and raw[lit.text] == nil then missing[#missing + 1] = rel .. ": " .. lit.text end
        end
    end
    assertEqual(#missing, 0, "routed with no enUS entry:\n" .. table.concat(missing, "\n"))
end)

test("locale: every enUS key is read by the addon's own files (localization-§3, no dead key)", function()
    local seen = {}
    for _, rel in ipairs(addonFiles()) do
        for _, lit in ipairs(literalsOf(readFile(rel))) do seen[lit.text] = true end
    end
    local dead = {}
    for _, k in ipairs(enUSKeyLines()) do
        if not seen[k.key] then dead[#dead + 1] = k.path .. ":" .. k.line .. ": " .. k.key end
    end
    assertEqual(#dead, 0, "enUS keys nothing reads:\n" .. table.concat(dead, "\n"))
end)

test("locale: no key is written twice in the enUS files", function()
    local first, dups = {}, {}
    for _, k in ipairs(enUSKeyLines()) do
        local at = k.path .. ":" .. k.line
        if first[k.key] then dups[#dups + 1] = at .. ": " .. k.key .. ", first at " .. first[k.key]
        else first[k.key] = at end
    end
    assertEqual(#dups, 0, table.concat(dups, "\n"))
end)

test("locale: the lexer is falsifiable, a routed literal and a dead key are both seen", function()
    local lits = literalsOf('-- L["in a comment"]\nlocal a = L["Routed \\194\\183"] .. NS.L[\'b\'] .. "plain"\n'
        .. 'local s = [[long]] --[[ L["gone"] ]]')
    local got = {}
    for _, l in ipairs(lits) do got[#got + 1] = l.text .. (l.routed and "!" or "") end
    assertEqual(table.concat(got, "|"), "Routed \194\183!|b!|plain|long")
end)

test("locale: each stub is gated on its own locale, silent elsewhere, and a subset of enUS", function()
    local raw = enUS()
    local stubs = stubFiles()
    for _, s in ipairs(stubs) do
        local text = readFile(s.rel)
        assertEqual(firstStatement(text), 'if GetLocale() ~= "' .. s.locale .. '" then return end',
            s.rel .. "'s first statement is its own guard")
        assertEqual(#stubWrites(s.rel, s.locale == "deDE" and "frFR" or "deDE"), 0,
            s.rel .. " wrote on another client")
        for _, w in ipairs(stubWrites(s.rel, s.locale)) do
            assertTrue(raw[w.key] ~= nil, s.rel .. " translates a key enUS lacks: " .. tostring(w.key))
            assertEqual(type(w.value), "string", s.rel .. ": " .. tostring(w.key))
            assertEqual(directives(w.value), directives(w.key), s.rel .. " changes the format of " .. w.key)
        end
    end
end)

test("locale: the stub gate is falsifiable, an ungated chunk writes on every client", function()
    local path = os.tmpname()
    local f = assert(io.open(path, "w"))
    f:write('local _, NS = ...\nNS.L["Skill"] = "Fertigkeit"\n')
    f:close()
    local writes = #stubWrites(path, "frFR")
    os.remove(path)
    assertEqual(writes, 1)
    assertEqual(directives("%d of %s (%.1f%%)"), "d,s,f")
end)
