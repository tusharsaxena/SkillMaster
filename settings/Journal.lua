local _, NS = ...
-- settings/Journal.lua — the Journal page (modules/Journal.lua, modules/SessionLog.lua): how much of
-- the session log a character keeps and the Alts tab's filter on open. `journal.point` is the
-- window's drag-only drop point and has no row.
local L = NS.L
local P = NS.defaults.profile.journal
local PAGE, JOURNAL = "journal", L["Journal"]

NS.RegisterSchemaRows(NS.Live({
    { path = "journal.keep", page = PAGE, group = JOURNAL, type = "number", default = P.keep,
      min = 50, max = 2000, step = 50, label = L["Skill-ups to keep"],
      desc = L["How many skill-ups the Session Log keeps per character; the oldest go first."],
      -- Lowering it trims at once; a profile switch to a lower value never does (review F-015).
      onChange = function(v)
          if NS.SessionLog and NS.SessionLog.Trim then NS.SessionLog:Trim(v) end
          NS.ApplyLook()
      end },
    { path = "journal.filter", page = PAGE, group = JOURNAL, type = "string", default = P.filter,
      label = L["Alts tab opens on"], desc = L["The skills the Alts tab shows when the Journal opens."],
      values = { { value = "professions", text = L["Professions"] }, { value = "weapons", text = L["Weapons"] },
                 { value = "other", text = L["Other"] } } },
}))

NS.RegisterSchemaPage(PAGE, L["Journal"], {
    defaultsTooltip = L["Restore every Journal setting on this profile to its default. The log itself is kept."],
})
