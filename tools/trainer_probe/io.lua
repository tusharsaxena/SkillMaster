-- tools/trainer_probe/io.lua — the probe's file and sandbox helpers (GitHub issue #3). Dev-only: not
-- in the TOC, never shipped.
--
-- Every external source is untrusted data. A Lua source is loaded only through IO.sandbox: compiled
-- with loadstring, its environment replaced by a table holding nothing but the stubs the caller
-- passes (no io, os, require, load or string library), then run. A source that needs anything else
-- fails to load and the probe reports it, rather than reaching past the sandbox.

local IO = {}

--- The whole file at `path` as a string, or nil and the error.
function IO.read(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local s = f:read("*a")
    f:close()
    return s
end

--- Whether `path` can be opened for reading.
function IO.exists(path)
    local f = io.open(path, "rb")
    if f then f:close() end
    return f ~= nil
end

--- Write `text` to `path` with CRLF line endings (the repo's pin, .gitattributes `eol=crlf`: a
--- generator writes past git's filters, so it writes the pinned terminator itself).
function IO.writeCRLF(path, text)
    local f = assert(io.open(path, "wb"))
    f:write((text:gsub("\r\n", "\n"):gsub("\n", "\r\n")))
    f:close()
end

--- Make directory `path` and its parents (a shell mkdir -p on a quoted path).
function IO.mkdirs(path)
    assert(not path:find("'", 1, true), "a path with a quote: " .. path)
    assert(os.execute("mkdir -p '" .. path .. "'") == 0, "mkdir failed: " .. path)
end

--- Compile `src` as chunk `name` and run it in an environment holding `env` alone, with `...`
--- bound to the extra arguments. Answers true and the chunk's first return, or false and the error.
function IO.sandbox(src, name, env, ...)
    local fn, err = loadstring(src, "=" .. name)
    if not fn then return false, err end
    setfenv(fn, env or {})
    return pcall(fn, ...)
end

--- The text between `open` and the next `close` after it in `s`, plain matches, or nil.
function IO.between(s, open, close, init)
    local _, a = s:find(open, init or 1, true)
    if not a then return nil end
    local b = s:find(close, a + 1, true)
    if not b then return nil end
    return s:sub(a + 1, b - 1), b + #close
end

--- The commit sha a git checkout at `dir` sits on, read from its .git files (no git process): HEAD,
--- then the ref it names (loose, then packed-refs). Nil when `dir` is not a checkout.
function IO.gitHead(dir)
    local head = IO.read(dir .. "/.git/HEAD")
    if not head then return nil end
    head = head:gsub("%s+$", "")
    local ref = head:match("^ref: (.+)$")
    if not ref then return head:match("^%x+$") end
    local loose = IO.read(dir .. "/.git/" .. ref)
    if loose then return (loose:gsub("%s+$", "")) end
    local packed = IO.read(dir .. "/.git/packed-refs") or ""
    for line in packed:gmatch("[^\n]+") do
        local sha, name = line:match("^(%x+) (%S+)$")
        if name == ref then return sha end
    end
    return nil
end

--- A file's sha256, through the system's sha256sum (no Lua implementation in 5.1), or nil.
function IO.sha256(path)
    assert(not path:find("'", 1, true), "a path with a quote: " .. path)
    local p = io.popen("sha256sum '" .. path .. "' 2>/dev/null")
    if not p then return nil end
    local out = p:read("*a") or ""
    p:close()
    return out:match("^(%x+)")
end

return IO
