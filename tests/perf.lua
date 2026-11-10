-- tests/perf.lua — offline perf scenarios (performance-§9). OUTSIDE the green gate: timings are for
-- orientation within one run, never across machines. Run: KA0S_KIT_CLIENT=forever lua tests/perf.lua
--   [--out path.json] [--label text]

local Loader     = dofile("tests/_kit/loader.lua")
dofile("tests/client_pin.lua")(Loader)   -- Forever-only: every run is the Forever profile (clients-§9)
local buildMocks = dofile("tests/wow_mock.lua")
Loader.addonName = "SkillMaster"

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        if arg[i] == "--out" then opts.out = arg[i + 1]; i = i + 2
        elseif arg[i] == "--label" then opts.label = arg[i + 1] or opts.label; i = i + 2
        else
            io.stderr:write("usage: lua tests/perf.lua [--out path] [--label text]\n")
            os.exit(2)
        end
    end
end

local mocks, NS = buildMocks(), {}
Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS, mocks)
Loader.loadAll(Loader.tocFiles("SkillMaster.toc"), NS, mocks)
NS.addon:OnInitialize()
NS.db.profile.skin.pickerSeen = true
NS.addon:OnEnable()
NS.MainWindow.Show()

-- api/iter: calls of the client's global functions (and C_* namespace members) per iteration,
-- counted by wrapping each one the mocks publish. Frame methods are not counted.
local apiCalls = 0
local function counted(fn) return function(...) apiCalls = apiCalls + 1 return fn(...) end end
for k, v in pairs(mocks) do
    if type(k) == "string" and k:sub(1, 2) ~= "__" and k ~= "LibStub" then
        if type(v) == "function" then
            mocks[k] = counted(v)
        elseif type(v) == "table" and k:sub(1, 2) == "C_" then
            for m, f in pairs(v) do if type(f) == "function" then v[m] = counted(f) end end
        end
    end
end

local function measure(name, iters, fn)
    collectgarbage("collect")
    local kb0, t0 = collectgarbage("count"), os.clock()
    apiCalls = 0
    for _ = 1, iters do fn() end
    local ms = (os.clock() - t0) * 1000 / iters
    local bytes = math.max(0, (collectgarbage("count") - kb0) * 1024 / iters)
    return { name = name, iters = iters, ms = ms, api = apiCalls / iters, bytes = bytes }
end

NS.Blocks:Detach("other")   -- one detached block for the detached scenario

local rows = {
    -- The window body with capture off: the gated bracket must cost one boolean test.
    measure("windowRenderOff", 1000, function() NS.Perf.on = false; NS.MainWindow.Render() end),
    -- The same pass with capture on: the bracket's clock reads and note.
    measure("windowRenderOn", 1000, function() NS.Perf.on = true; NS.MainWindow.Render() end),
    -- A settings read through the seam, the shape every per-pass read takes.
    measure("settingsRead", 10000, function() return NS.GetSetting("scale") end),
    -- The event paths (performance-§2's buckets): a bonus refresh, a stat pass, a skill scan, and
    -- one detached block's rows.
    measure("bonusRefresh", 1000, function() NS.Bonuses.Refresh() end),
    measure("statScan", 1000, function() NS.StatData:Scan() end),
    measure("skillScan", 1000, function() NS.SkillData:Scan() end),
    measure("detachedRender", 1000, function() NS.Detached.Render("other") end),
}
NS.Perf.on = false

print(("Ka0s Skill Master — offline perf  (v%s, label '%s')"):format(NS.Version(), opts.label))
print("")
print(("%-22s %8s %12s %12s %12s"):format("scenario", "iters", "ms/iter", "api/iter", "bytes/iter"))
for _, r in ipairs(rows) do
    print(("%-22s %8d %12.5f %12.1f %12.1f"):format(r.name, r.iters, r.ms, r.api, r.bytes))
end
print("")
print("timings are for orientation only — compare scenarios within a run, never across machines")

if opts.out then
    local parts = {}
    for i, r in ipairs(rows) do
        parts[i] = ('{"scenario":"%s","iters":%d,"msPerIter":%.6f,"apiPerIter":%.1f,"bytesPerIter":%.1f}')
            :format(r.name, r.iters, r.ms, r.api, r.bytes)
    end
    local f = assert(io.open(opts.out, "w"))
    f:write('{"label":"' .. opts.label .. '","scenarios":[' .. table.concat(parts, ",") .. "]}\n")
    f:close()
end
