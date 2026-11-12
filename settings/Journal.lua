local _, NS = ...
-- settings/Journal.lua — the Journal page (modules/Journal.lua, modules/SessionLog.lua): how much of
-- the log a character keeps, the range the Log tab shows (the window's own picker writes the same
-- row, FB-32) and the Alts sub-tab on open (one per main-window block, FB-33). `journal.point` and
-- `journal.size` are the window's drag-only geometry and have no row.
local L = NS.L
local P = NS.defaults.profile.journal
local PAGE, JOURNAL = "journal", L["Journal"]

local function rangeValues()
    local out = {}
    for i, r in ipairs(NS.Journal.RANGE_ORDER) do out[i] = { value = r, text = NS.Journal.RangeLabel(r) } end
    return out
end

-- The Alts sub-tabs, by the main window's block titles.
local function filterValues()
    local out = {}
    for i, id in ipairs(NS.Journal.FILTER_ORDER) do out[i] = { value = id, text = NS.BlockDefs[id].title } end
    return out
end

NS.RegisterSchemaRows(NS.Live({
    { path = "journal.keep", page = PAGE, group = JOURNAL, type = "number", default = P.keep,
      min = 50, max = 2000, step = 50, label = L["Skill-ups to keep"],
      desc = L["How many skill-ups the Log keeps per character; the oldest go first."],
      -- Lowering it trims at once; a profile switch to a lower value never does (review F-015).
      onChange = function(v)
          if NS.SessionLog and NS.SessionLog.Trim then NS.SessionLog:Trim(v) end
          NS.ApplyLook()
      end },
    { path = "journal.range", page = PAGE, group = JOURNAL, type = "string", default = P.range,
      label = L["Log shows"], desc = L["The skill-ups the Log tab lists and sums: this session, the last few days or all of them."],
      values = rangeValues(),
      -- The Journal alone reads it: a repaint of the open window, not a full look change.
      onChange = function() if NS.Journal then NS.Journal.Refresh() end end },
    { path = "journal.filter", page = PAGE, group = JOURNAL, type = "string", default = P.filter,
      label = L["Alts tab opens on"], desc = L["The block the Alts tab shows when the Journal opens."],
      values = filterValues() },
}))

NS.RegisterSchemaPage(PAGE, L["Journal"], {
    defaultsTooltip = L["Restore every Journal setting on this profile to its default. The log itself is kept."],
})
