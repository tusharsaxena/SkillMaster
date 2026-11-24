-- tests/test_sample_names.lua — one source of sample names (FB2-SM-01 of Ka0sAddonsCommonTasks
-- docs/2026-11-24-FEEDBACK_BATCH, decision D1, LibKa0s#104).
--
-- The owner, 2026-11-24: "adopt the predefined test mode names consistently across all addon's
-- test/sim modes". Every named sample person Skill Master draws (test mode's character and alts, the
-- simulator's character) comes from LibKa0s-Sim-1.0's Sim.Sample("forever"), so no `Sample*` or
-- `Mock*` name may be written anywhere in the addon's own files. The walk covers every tracked file
-- but tests/ (the suites check the library's names), libs/ (the library owns them), the frozen
-- bundles (docs/audits, reviews, automated-tests, perf-analysis, revendor, superpowers, trainer-probe
-- and seed-research hold what was true when written) and docs/smoke-tests.md (the owner's checks
-- name what the client shows, with their results recorded).
local T = _G.SKM_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local SKIP = { "^libs/", "^tests/", "^docs/audits/", "^docs/reviews/", "^docs/automated%-tests/",
               "^docs/perf%-analysis/", "^docs/revendor/", "^docs/superpowers/", "^docs/trainer%-probe/",
               "^docs/seed%-research/", "^docs/smoke%-tests%.md$", "^media/" }

local function skipped(path)
    for _, pat in ipairs(SKIP) do if path:find(pat) then return true end end
    return false
end

--- Every `Sample<lower>` / `Mock<lower>` word in `text` (the convention's name shape: Samplehunter,
--- Mockstride, Samplerealm), as "line: word".
local function names(text)
    local out, n = {}, 0
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        for word in line:gmatch("%f[%w](%u%l+)") do
            if word:find("^Sample%l") or word:find("^Mock%l") then out[#out + 1] = n .. ": " .. word end
        end
    end
    return out
end

test("sample names: the matcher finds a planted name and passes an identifier", function()
    assertEqual(#names('local who = "Samplehunter Mockstride"'), 2, "two planted names")
    assertEqual(#names("P.SampleCharacter(); onSampleClear; MockClient"), 0, "identifiers are not names")
end)

test("sample names: no Sample*/Mock* name literal outside tests/, libs/ and the frozen docs", function()
    local p = assert(io.popen("git ls-files"))
    local bad, walked = {}, 0
    for path in p:lines() do
        if not skipped(path) and (path:find("%.lua$") or path:find("%.md$") or path:find("%.toc$")
            or path:find("%.xml$")) then
            local f = io.open(path, "rb")
            if f then
                walked = walked + 1
                for _, hit in ipairs(names(f:read("*a"))) do bad[#bad + 1] = path .. ":" .. hit end
                f:close()
            end
        end
    end
    p:close()
    assertTrue(walked > 50, "the walk read the addon's files, got " .. walked)
    assertEqual(#bad, 0, table.concat(bad, " | "))
end)
