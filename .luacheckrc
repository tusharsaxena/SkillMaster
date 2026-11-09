std = "lua51"
max_line_length = false
codes = true

-- Only vendored and frozen trees are out of scope; the test tree is linted (lint).
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/", "tests/_kit/" }
ignore = { "212/self", "212/event" }

globals = {
  "SkillMasterDB",               -- the SavedVariables write target
  "SkillMasterPerfDB",           -- the perf capture ring (core/PerfSetup.lua, performance-§5)
  "StaticPopupDialogs",          -- the reset confirmation (settings/General.lua)
  "BINDING_HEADER_SKILLMASTER",  -- the key binding's category title (modules/MainWindow.lua)
  "UISpecialFrames",             -- Escape closes the main window (modules/MainWindow.lua)
}

read_globals = {
  "_G", "LibStub",
  "CreateFrame", "UIParent",
  "InCombatLockdown",
  "C_AddOns",
  "debugprofilestop",            -- the perf bracket's clock (performance-§2)
  "Settings", "StaticPopup_Show", "YES", "NO",
}

-- The harness global is declared here, not in read_globals, so addon source cannot reach it (lint).
files["tests/"] = {
  globals = { "_G.SKM_TEST" },
}
