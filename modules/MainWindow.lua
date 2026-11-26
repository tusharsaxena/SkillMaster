local _, NS = ...
-- modules/MainWindow.lua — NS.MainWindow, the thin shim over the Professions window (item SMW-04 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md), and the key bindings. The window itself is
-- modules/Window.lua's factory, one instance per family; the Professions one keeps the old window's
-- frame name, its `/sm show` verb, the launcher's Show window entry and the SkillMasterToggleWindow binding
-- (`/sm professions` runs the same toggle; `/sm toggle` is every window's since R5-SM-05). A call that concerned the old one window as a whole (a refresh, the
-- applied settings, a stand-down, Reset position, scroll to a skill) now reaches every family window.

local L = NS.L
local Windows = NS.Windows
local main = Windows.Get("professions")

-- A copy of the Professions window's members (each a function over that one instance), then the overrides.
NS.MainWindow = {}
local W = NS.MainWindow
for k, v in pairs(main) do W[k] = v end

-- Every window: what reached the one window before reaches each family window now.
W.Refresh = Windows.RefreshAll
W.RefreshValues = Windows.RefreshValuesAll
W.ApplySettings = Windows.ApplyAll
W.StandDown = Windows.StandDownAll
W.ResetPosition = Windows.ResetPositions
W.ShowAndScrollTo = Windows.ShowAndScrollTo

-- The key bindings (launcher-§6), in Bindings.xml order: Show window (the Professions window) first,
-- then the other five family windows in the family order, then the Journal. The button names are
-- permanent: the client stores the player's key against them, so a rename unbinds every player's key.
-- Each is plain (no secure template), hidden, one toggle per press, and its click runs that window's one
-- toggle handler, which refuses while stood down exactly as its verb does.
W.TOGGLE_BUTTON = "SkillMasterToggleWindow"
W.JOURNAL_BUTTON = "SkillMasterToggleJournal"
-- The other families' buttons (SMW-04), [fid] = name: permanent once shipped.
W.FAMILY_BUTTONS = {
    skills = "SkillMasterToggleSkills", stats = "SkillMasterToggleStats",
    currencies = "SkillMasterToggleCurrencies", reputations = "SkillMasterToggleReputations",
    statistics = "SkillMasterToggleStatistics",
}

-- Each window's binding label, in the family order.
local LABEL = {
    professions = L["Toggle Professions window"], skills = L["Toggle Skills window"],
    stats = L["Toggle Character Stats window"], currencies = L["Toggle Currencies window"],
    reputations = L["Toggle Reputations window"], statistics = L["Toggle Statistics window"],
}
local TIP = {
    professions = L["Shows or hides the Professions window: primary and secondary professions."],
    skills = L["Shows or hides the Skills window: weapon skills and other skills."],
    stats = L["Shows or hides the Character Stats window: the character panel's stats."],
    currencies = L["Shows or hides the Currencies window."],
    reputations = L["Shows or hides the Reputations window."],
    statistics = L["Shows or hides the Statistics window: the character panel's Statistics tab."],
}

local function bindingButton(name, onClick)
    local button = CreateFrame("Button", name, UIParent)   -- plain, not a secure template
    button:RegisterForClicks("AnyDown")                     -- one press, one toggle
    button:SetScript("OnClick", onClick)                    -- the handler itself
    button:Hide()
    return button
end

local function command(name) return ("CLICK %s:LeftButton"):format(name) end

do
    -- the binding suites drive them by reference
    W.__toggleButton = bindingButton(W.TOGGLE_BUTTON, function() Windows.Toggle("professions") end)
    W.__familyButtons = {}
    for fid, name in pairs(W.FAMILY_BUTTONS) do
        W.__familyButtons[fid] = bindingButton(name, function() Windows.Toggle(fid) end)
    end
    W.__journalButton = bindingButton(W.JOURNAL_BUTTON, function() NS.Journal.Toggle() end)
    BINDING_HEADER_SKILLMASTER = NS.Constants.BRAND
    NS.BINDINGS = {}
    for _, fid in ipairs(NS.FAMILY_ORDER) do
        local cmd = command(fid == "professions" and W.TOGGLE_BUTTON or W.FAMILY_BUTTONS[fid])
        rawset(_G, "BINDING_NAME_" .. cmd, LABEL[fid])
        NS.BINDINGS[#NS.BINDINGS + 1] = { command = cmd, tooltip = TIP[fid] }
    end
    local journal = command(W.JOURNAL_BUTTON)
    rawset(_G, "BINDING_NAME_" .. journal, L["Toggle journal"])
    NS.BINDINGS[#NS.BINDINGS + 1] =
        { command = journal, tooltip = L["Shows or hides the Journal: the skill-up log and your alts."] }
end
