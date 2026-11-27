-- tests/test_trainers_tabs.lua — FB-SM-06 (the owner's feedback batch, 2026-11-24, S3: "Split
-- Trainers and Waypoint into 2 separate tabs"). The Trainers and Waypoints page keeps its key
-- ("trainers") and its title, and its rows fall into two groups, so RenderTabbedSchema draws two
-- tabs: Trainers (the trainer data and the trainer popup) first, then Waypoints (the method, the
-- chat line, and Character Ledger's arrow with its text and position).
local T = _G.SKM_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue
local L = NS.L

local function groups(rows)
    local out, seen = {}, {}
    for _, row in ipairs(rows) do
        if row.group and not seen[row.group] then seen[row.group] = true; out[#out + 1] = row.group end
    end
    return out
end

test("FB-SM-06 the Trainers and Waypoints page: two tabs, Trainers then Waypoints", function()
    local rows = NS.SchemaForPage("trainers")
    assertTrue(#rows > 0, "the page keeps its key")
    local g = groups(rows)
    assertEqual(#g, 2, "two groups, two tabs")
    assertEqual(g[1], L["Trainers"], "Trainers first")
    assertEqual(g[2], L["Waypoints"], "then Waypoints")
end)

test("FB-SM-06 each row on its tab", function()
    local at = {}
    for _, row in ipairs(NS.SchemaForPage("trainers")) do at[row.path] = row end
    for _, path in ipairs({ "trainers.showAll", "trainers.nameColor",
                            "trainers.useClassColorName", "trainers.nameColorFromSkin" }) do
        assertTrue(at[path] ~= nil, path .. " is on the page")
        assertEqual(at[path].group, L["Trainers"], path .. " on the Trainers tab")
    end
    for _, path in ipairs({ "waypoints.method", "waypoints.announce", "waypoints.arrow",
                            "waypoints.arrowScale", "waypoints.arrowFontSize", "waypoints.arrowX" }) do
        assertTrue(at[path] ~= nil, path .. " is on the page")
        assertEqual(at[path].group, L["Waypoints"], path .. " on the Waypoints tab")
    end
end)
