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

local function measure(name, iters, fn)
    collectgarbage("collect")
    local kb0, t0 = collectgarbage("count"), os.clock()
    for _ = 1, iters do fn() end
    local ms = (os.clock() - t0) * 1000 / iters
    local bytes = math.max(0, (collectgarbage("count") - kb0) * 1024 / iters)
    return { name = name, iters = iters, ms = ms, api = 0, bytes = bytes }
end

local rows = {
    -- The window body with capture off: the gated bracket must cost one boolean test.
    measure("windowRenderOff", 1000, function() NS.Perf.on = false; NS.MainWindow.Render() end),
    -- The same pass with capture on: the bracket's clock reads and note.
    measure("windowRenderOn", 1000, function() NS.Perf.on = true; NS.MainWindow.Render() end),
    -- A settings read through the seam, the shape every per-pass read takes.
    measure("settingsRead", 10000, function() return NS.GetSetting("scale") end),
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
