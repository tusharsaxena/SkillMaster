-- tests/test_loadorder.lua — the load lists, the load-bearing positions and the TOC's Forever shape.
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local Loader = dofile("tests/_kit/loader.lua")

local function read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return (s:gsub("\r\n", "\n"))
end

test("loadorder: the runner loads exactly the TOC's files and the library XML's files", function()
    assertEqual(table.concat(T.loadedAddonFiles, ","), table.concat(Loader.tocFiles("SkillMaster.toc"), ","))
    assertEqual(table.concat(T.loadedLibFiles, ","), table.concat(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), ","))
end)

test("loadorder: FONT_MONO resolved from the Media seam, not the fallback (MediaSetup before Constants)", function()
    assertTrue(NS.Constants.FONT_MONO ~= NS.Constants.FALLBACK_FONT, "FONT_MONO fell back: " .. NS.Constants.FONT_MONO)
    assertTrue(NS.Constants.FONT_MONO:find("JetBrainsMono", 1, true) ~= nil, NS.Constants.FONT_MONO)
end)

test("loadorder: NS.Print is reclaimed from AceConsole and is the same object as NS.Util.print", function()
    assertTrue(NS.Print == NS.Util.print, "NS.Print and NS.Util.print diverged (architecture-§2)")
end)

test("toc: the Forever-only shape (clients-§9): one 16001 number and both gating lines, in order", function()
    local toc = read("SkillMaster.toc")
    local lines = {}
    for line in toc:gmatch("[^\n]+") do lines[#lines + 1] = line end
    assertEqual(lines[1], "## Interface: 16001")
    assertEqual(lines[2], "## AllowLoadGameType: camelot")
    assertEqual(lines[3], "## ExcludeLoadGameType: standard")
    assertEqual(lines[4], "## Title: Ka0s Skill Master")
    assertTrue(toc:find("## SavedVariables: SkillMasterDB, SkillMasterPerfDB\n", 1, true) ~= nil, "SavedVariables")
    assertTrue(toc:find("## IconTexture: Interface\\AddOns\\SkillMaster\\media\\logos\\skillmaster.logo.128.tga\n",
        1, true) ~= nil, "IconTexture is the addon's own 128 px logo")
end)

test("clients-§9: no Retail branch, no client read and no retail declaration in the addon's source", function()
    -- red under: any `IsRetail(` call, a WOW_PROJECT_* read or a clients = { "retail" } row.
    local hits = {}
    for _, path in ipairs(Loader.tocFiles("SkillMaster.toc")) do
        local src = read(path):gsub("%-%-[^\n]*", "")
        for _, needle in ipairs({ "IsRetail", "WOW_PROJECT_", "ClientKey", '"retail"' }) do
            if src:find(needle, 1, true) then hits[#hits + 1] = path .. ": " .. needle end
        end
    end
    assertEqual(#hits, 0, table.concat(hits, "; "))
end)

test("loadorder: the one MakeCloseButton wrapper is the only caller of the library factory", function()
    for _, path in ipairs(Loader.tocFiles("SkillMaster.toc")) do
        local src = read(path):gsub("%-%-[^\n]*", "")
        for call in src:gmatch("[%w_%.:]*MakeCloseButton%(") do
            assertTrue(call == "NS.MakeCloseButton(" or call == "lib.MakeCloseButton(",
                path .. " calls " .. call .. " (standalone-windows: build every close control through the wrapper)")
        end
    end
end)
