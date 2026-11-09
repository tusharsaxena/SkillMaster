local _, NS = ...
-- settings/Broker.lua — the Broker page (design §6.7): each data feed's text template and the
-- skill-up flash. A write repaints the feeds at once (NS.Broker.Refresh).
local L = NS.L
local P = NS.defaults.profile.broker
local PAGE, FEEDS, FLASH = "broker", L["Feeds"], L["Skill-up flash"]

local function refresh()
    if NS.Broker and NS.Broker.Refresh then NS.Broker.Refresh() end
end

local TOKENS = table.concat(NS.Template.TOKENS, ", ")

local function template(id, label)
    return {
        path = "broker.templates." .. id, page = PAGE, group = FEEDS, subgroup = L["Text"], type = "string",
        wide = true, default = P.templates[id], label = label,
        desc = L["What this feed shows on your broker display. Tokens: %s."]:format(TOKENS),
    }
end

NS.RegisterSchemaRows(NS.Live({
    template("all", L["Skill Master: All"]),
    template("professions", L["Skill Master: Professions"]),
    template("weapons", L["Skill Master: Weapons"]),
    template("stats", L["Skill Master: Stats"]),
    { path = "broker.flashSeconds", page = PAGE, group = FEEDS, subgroup = FLASH, type = "number",
      default = P.flashSeconds, min = 0, max = 30, step = 1, label = L["Flash duration (seconds, 0 = off)"],
      desc = L["How long a feed shows the skill that just went up (^ Bows 81) in place of its text."] },
}, refresh))

NS.RegisterSchemaPage(PAGE, L["Broker"], {
    defaultsTooltip = L["Restore every Broker setting on this profile to its default."],
})
