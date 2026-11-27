local addonName, NS = ...
-- modules/Broker.lua — the broker data feeds (design §6.7, plan Task 4.1; feedback round 2, FB-12; owner
-- feedback round 6, R6-9; item SMW-05 of docs/superpowers/plans/2026-11-26-characterledger-windows.md): one
-- LibDataBroker-1.1 "data source" per family of defaults/Families.lua, built from the registry. "Skill
-- Master Stats" (Character Stats, relabeled) keeps its name, so a display's placement stays; the
-- Professions feed, "Character Ledger" until owner feedback round 7 (R7-SM-02), is "Character Ledger Professions",
-- named for its family as the rest are; "Character Ledger Skills", "Character Ledger Currencies", "Character Ledger Reputations"
-- and "Character Ledger Statistics" are new. Each feed's text is its own template (broker.feeds.<family>.template,
-- modules/Template.lua), a skill feed's flashed on a skill-up of its family; its tooltip's sections are its
-- family's blocks, each with its own switch (broker.tooltip.sections.<block id>), and each skill and stat
-- its own tooltip Hide (profile.broker.tooltip), apart from the windows' skills.hidden / stats.hidden.
-- Each feed draws its own pins (GitHub issue #11, SMW-06; modules/Pins.lua): {pinned} joins them, {pinned1}..
-- {pinned5} render one each, and its tooltip lists them first (modules/BrokerTooltip.lua, modules/BrokerPanel.lua).
-- Every feed shares the clicks and the one tooltip machinery below (one tooltip shows at a time); B.Feed()
-- names the one showing. The tooltip's content and the Classic style's lines are modules/BrokerTooltip.lua.
--
-- The tooltip (FB-13): with "Apply skin to the tooltip" on (broker.tooltip.skin, the default) it is
-- this file's own GameTooltip-template frame, painted with the skin's window shell and fonts; off,
-- it is the shared GameTooltip exactly as before. The shared GameTooltip is never painted.
--
-- These are NOT the launcher: core/LauncherSetup.lua's one "launcher" object stays the only click
-- and menu implementation for the addon (launcher-§1). Nothing here is secure. A feed cell's left click
-- toggles its family's window, its right click opens the Broker settings page. In the tooltip itself only
-- a section's fold chevron takes a click (the owner's ask, SMW-07): it folds that section in the tooltip
-- alone (tooltips.ldb.folds, modules/BrokerFolds.lua) and the tooltip redraws in place (B.RedrawTooltip);
-- a row opens, links and menus nothing there, and keeps its hover.
--
-- Consumes SKILLS_UPDATED, SKILL_UP, STATS_UPDATED and BONUSES_UPDATED on its own bus target. The
-- one client read is the main-hand weapon class for {equippedWeapon}, feature-detected.
--
-- B.source: nil for the models the bus handed over, or fn() -> { model, statsModel, statIndex,
-- gains = { total, byKey }, last, pins = { [family] = { key, ... } } } (test mode's sample character,
-- modules/Preview.lua, T5.2). The bus keeps feeding the live state underneath, so turning test mode off shows it again at once.

NS.Broker = {}
local B = NS.Broker
local L = NS.L

local MAIN_HAND = 16
-- The Classic lines' name and value columns (modules/BrokerTooltip.lua): the bar's height is
-- profile.bars.miniHeight, its line's profile.bars.brokerRowHeight; its width Tooltips > Bar width.
B.NAME_W, B.VALUE_W = 128, 124

-- The tooltip's own settings (the Tooltips page, owner feedback round 4).
function B.TipSettings()
    local t = NS.db and NS.db.profile.tooltips
    return t and t.ldb or NS.defaults.profile.tooltips.ldb
end
local tipSettings = B.TipSettings

--- The tooltip's look (Tooltips > Tooltip style, round 6, R6-10): "window", the main window's (its own
--- frame, modules/BrokerPanel.lua), or "classic", the tooltip lines and mini bars.
function B.Style()
    return tipSettings().style == "classic" and "classic" or "window"
end

--- The tooltip's minimum width: the name column, Tooltips > Bar width and the value column. The
--- bars stretch between the two columns, so the width is the least a bar draws.
function B.MinWidth()
    return B.NAME_W + (tonumber(tipSettings().barWidth) or 128) + B.VALUE_W
end
-- The bar stops this far short of its line's value (owner feedback round 3: the fixed VALUE_W
-- left a wide gap): the widest value drawn, the tooltip's own right inset and this gap.
B.VALUE_GAP, B.TIP_INSET = 8, 10
local HIDE_POLL = 0.1          -- seconds between the tooltip's leave checks

-- ---------------------------------------------------------------------------------------------
-- The feeds, one per family (SMW-05). `name` is the LibDataBroker name (a key display addons store
-- placements under, so never localized and never changed once shipped; the launcher object is the
-- addon's folder name, "CharacterLedger"), `label` what a display draws, `title` the tooltip's (its window's
-- title, both styles; R7-5), `sections` its family's blocks, `short` the text an unpinned feed shows.
-- ---------------------------------------------------------------------------------------------

B.FEEDS = {}
for fid, fam in NS.EachFamily() do
    B.FEEDS[fid] = { family = fid, name = fam.feed.name, label = fam.feed.label, icon = fam.feed.icon,
                     title = fam.title, sections = fam.blocks, short = fam.short, source = fam.source }
end
B.DEFAULT_FEED = "professions"
-- The two names shipped before the split (a display stores by them).
B.NAME, B.LABEL = B.FEEDS.professions.name, B.FEEDS.professions.label
B.STATS_NAME, B.STATS_LABEL = B.FEEDS.stats.name, B.FEEDS.stats.label

local feed = B.DEFAULT_FEED   -- the feed whose tooltip shows now (B.OnEnter)

--- The feed whose tooltip is up, or was last: a family id.
function B.Feed() return feed end

--- Make `which` the feed showing now (an unknown one is the Professions feed).
function B.SetFeed(which)
    feed = B.FEEDS[which] and which or B.DEFAULT_FEED
    return feed
end

-- The owned tooltip frame's global name (its TextLeftN lines are found by it, as GameTooltip's are).
B.TIP_NAME = "CharacterLedgerBrokerTooltip"

-- The settings page the feed's right-click opens (the Broker page's registration key). The library
-- opens the main panel when no page of that key is built.
B.SETTINGS_PAGE = "broker"

-- ---------------------------------------------------------------------------------------------
-- State: the last models the bus handed over, the session's gains, the flash
-- ---------------------------------------------------------------------------------------------

local model, statIndex, statsModel
local gains = { total = 0, byKey = {} }
local last
local flash, flashTimer = {}, nil   -- flash: [fid] = the flashing text, the skill-up's feed's alone
local objects, rendered = {}, {}    -- [fid] = its LibDataBroker object / its text now

local function clearFlash()
    for k in pairs(flash) do flash[k] = nil end
    if flashTimer then NS.addon:CancelTimer(flashTimer) end
    flashTimer = nil
end

--- Back to a fresh session (the suites call this between cases).
function B.ResetSession()
    gains = { total = 0, byKey = {} }
    last = nil
    clearFlash()
end

local function copyGains(g)
    local byKey = {}
    for k, v in pairs(g.byKey) do byKey[k] = v end
    return { total = g.total, byKey = byKey }
end

--- This session's gains and last skill-up, as a copy (the simulator takes it at start).
function B.SessionState() return { gains = copyGains(gains), last = last } end

--- Put a SessionState() back and end any flash (the simulator's stop).
function B.RestoreSessionState(st)
    if type(st) ~= "table" or type(st.gains) ~= "table" then return end
    gains, last = copyGains(st.gains), st.last
    clearFlash()
    B.Refresh()
end

--- What the feeds draw: B.source's answer while one is set (and true), else the live state.
function B.View()
    local v = B.source and B.source()
    if type(v) == "table" then return v, true end
    return { model = model, statsModel = statsModel, statIndex = statIndex, gains = gains, last = last,
             models = B.TreeModels() }
end

--- The tree families' live models (SMW-08..10), keyed by their provider source (NS.Blocks.PROVIDERS): only the
--- tree families', so a read never makes the stat model scan.
function B.TreeModels()
    local out, P = {}, NS.Blocks and NS.Blocks.PROVIDERS or {}
    for _, fam in pairs(NS.Families) do
        local p = fam.tree and P[fam.source]
        if p then out[fam.source] = p.model() end
    end
    return out
end
local view = B.View

local function setting(path, fallback)
    local v = NS.GetSetting and NS.db and NS.GetSetting(path)
    if v == nil then return fallback end
    return v
end

function B.FlashSeconds() return tonumber(setting("broker.flashSeconds", 5)) or 5 end

--- Feed `fid`'s text template (broker.feeds.<fid>.template, SMW-05; schemaVersion 15 moved the one
--- broker.template to the Professions feed's).
function B.Template(fid)
    local t = setting("broker.feeds." .. (fid or B.DEFAULT_FEED) .. ".template", nil)
    return type(t) == "string" and t or ""
end

-- ---------------------------------------------------------------------------------------------
-- What the tooltip shows: the sections' switches and its own Hide sets (never the window's)
-- ---------------------------------------------------------------------------------------------

local function tooltipStore()
    local p = NS.db and NS.db.profile
    local b = type(p) == "table" and p.broker
    return type(b) == "table" and type(b.tooltip) == "table" and b.tooltip or nil
end

--- Whether section `id` (a block of its feed's family) is drawn in the tooltip. A block with no
--- default of its own (a later family's) is drawn.
function B.SectionShown(id)
    local v = setting("broker.tooltip.sections." .. id, nil)
    if v == nil then return NS.defaults.profile.broker.tooltip.sections[id] ~= false end
    return v == true
end

--- Whether the tooltip leaves out the skill (`kind` "skill") or stat ("stat") `key`.
function B.HiddenInTooltip(kind, key)
    local store = tooltipStore()
    local set = store and store[kind == "stat" and "hiddenStats" or "hiddenSkills"]
    return type(set) == "table" and set[key] == true
end

--- Whether the tooltip wears the skin (broker.tooltip.skin).
function B.Skinned() return setting("broker.tooltip.skin", true) ~= false end

-- ---------------------------------------------------------------------------------------------
-- The template context
-- ---------------------------------------------------------------------------------------------

--- The skill key of the main-hand weapon: "unarmed" with none, nil for a non-skill item.
function B.MainHandSkill()
    return NS.SkillHelpers.WeaponSkillInSlot(MAIN_HAND)
end

--- The family a skill belongs to (NS.Pins.FamilyOfSkill): the flash's feed.
local function familyOfSkill(key, m) return NS.Pins.FamilyOfSkill(key, m) end

-- A pin's row entry, by its family's provider source: { kind, entry } from the models drawn now, or nil
-- (a key the models do not hold yet). A tree family's (SMW-08..10) is its model's entry by key, its kind its
-- family's row kind (B.PIN_ENTRY falls back to it, below).
B.PIN_ENTRY = {
    skills = function(v, key)
        local e = v.model and v.model.byKey and v.model.byKey[key]
        return e and { kind = "skill", entry = e } or nil
    end,
    stats = function(v, key)
        local e = v.statIndex and v.statIndex[key]
        return e and { kind = "stat", entry = e } or nil
    end,
}
-- A pin's text in its feed's {pinned}, by its row kind: "Fishing 107+25/150", "Ranged Crit 9.1%".
B.PIN_TEXT = {
    skill = function(e) return NS.Template.FormatSkill(e) end,
    stat = function(e) return ("%s %s"):format(e.label or e.key, e.display or "") end,
}

--- Pin `key` of feed `fid` as a row entry ({ kind, entry }) from the models drawn now, or nil.
local function treePin(fid, v, key)
    local fam = NS.Families[fid]
    local m = fam and fam.tree and v.models and v.models[fam.source]
    local e = m and m.byKey and m.byKey[key]
    return e and { kind = fam.rowKind, entry = e } or nil
end

function B.PinEntry(fid, key)
    local f = B.FEEDS[fid]
    local get = f and B.PIN_ENTRY[f.source]
    if get then return get(view(), key) end
    return f and treePin(fid, view(), key) or nil
end

--- Feed `fid`'s pins drawn now, in order, each { kind, entry, key } (a pin its models do not hold is left
--- out): the tooltip's Pinned section, and the texts of {pinned}.
function B.PinnedEntries(fid)
    local out = {}
    for _, key in ipairs(NS.Pins.List(fid)) do
        local r = B.PinEntry(fid, key)
        if r then
            r.key = key
            out[#out + 1] = r
        end
    end
    return out
end

local function pinnedTexts(fid)
    local out = {}
    for _, r in ipairs(B.PinnedEntries(fid)) do
        local tree = NS.Tree.Kind(r.kind)
        local fn = B.PIN_TEXT[r.kind] or (tree and tree.pinText)
        local text = fn and fn(r.entry)
        if text and text ~= "" then out[#out + 1] = text end
    end
    return out
end

-- The context's fields that cost a client read, each read only when a template asks for it ({equippedWeapon},
-- {level}): six feeds re-render on every skills, stats and bonus pass, and most never show either.
local LAZY = {
    mainHand = function(v, sourced) return sourced and v.mainHand or B.MainHandSkill() end,
    level    = function() return NS.Preview.Character().level end,
}

--- The template context for feed `fid` (the Professions feed by default). While a source is set (test
--- mode) the pins and the main hand are its own, so a sample feed never reads this character's store or
--- gear. `pinnedTexts` are the feed's pins as {pinned} and {pinned1}..{pinned5} render them. `mainHand` and
--- `level` are read on first use (LAZY).
function B.Context(fid)
    fid = fid or B.DEFAULT_FEED
    local v, sourced = view()
    local pins = NS.Pins.List(fid)
    local ctx = {
        skills = v.model, stat = v.statIndex, gains = v.gains.total, last = v.last,
        pinned = B.FEEDS[fid] and B.FEEDS[fid].source == "skills" and pins[1] or nil,
        pinnedTexts = pinnedTexts(fid),
    }
    return setmetatable(ctx, { __index = function(t, k)
        local fn = LAZY[k]
        if not fn then return nil end
        local value = fn(v, sourced)
        rawset(t, k, value)
        return value
    end })
end

-- ---------------------------------------------------------------------------------------------
-- Feed text: the template, or the flash while one runs
-- ---------------------------------------------------------------------------------------------

local function hex(token, fallback)
    local r, g, b = NS.Skin.Color(token)
    if not r then return fallback or "ffffffff" end
    return ("ff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
end

--- `text` in the skin's `token` color, as an escape (the tooltip lines', modules/BrokerTooltip.lua).
function B.Colored(token, text)
    return ("|c%s%s|r"):format(hex(token), text)
end

local function flashText(name, new)
    local icon = NS.Icon("chevron-up")
    local mark = icon and ("|T%s:0|t"):format(icon) or "+"
    return B.Colored("sem.good", ("%s %s %d"):format(mark, name, new))
end

--- A template that shows the pinned elements, with nothing pinned to the feed, reads the feed's short
--- name ("Professions", "Character Stats": owner feedback round 3, no pin is the default, and a feed then
--- never guesses one).
local function unpinned(fid, ctx)
    return #ctx.pinnedTexts == 0 and B.Template(fid):find("{pinned}", 1, true) ~= nil
end

--- Feed `fid`'s text now.
function B.FeedText(fid)
    if NS.IsStoodDown() then return L["Off"] end
    if flash[fid] then return flash[fid] end
    local ctx = B.Context(fid)
    local f = B.FEEDS[fid]
    if unpinned(fid, ctx) then return f.short end
    local out = NS.Template.Render(B.Template(fid), ctx)
    if out:gsub("[%s%p]", "") == "" then return f.label end   -- never a blank cell
    return out
end

--- The first stat pinned to the Character Stats feed: its stat entry, or nil.
function B.PinnedStat()
    local r = B.PinnedEntries("stats")[1]
    return r and r.entry or nil
end

--- Re-render every feed's text; an unchanged text is not re-assigned (each write is a display callback).
function B.Refresh()
    if NS.IsStoodDown() then clearFlash() end
    for fid in pairs(B.FEEDS) do
        local new = B.FeedText(fid)
        if rendered[fid] ~= new then
            rendered[fid] = new
            if objects[fid] then objects[fid].text = new end
        end
    end
end

--- Feed `fid`'s text now and its LibDataBroker object (nil without the library); B.Text / B.Object are
--- the Professions feed's, B.StatsText / B.StatsObject the Character Stats feed's.
function B.TextFor(fid) return rendered[fid] end
function B.ObjectFor(fid) return objects[fid] end
function B.Text() return rendered.professions end
function B.Object() return objects.professions end
function B.StatsText() return rendered.stats end
function B.StatsObject() return objects.stats end

local function endFlash()
    flashTimer = nil
    for k in pairs(flash) do flash[k] = nil end
    B.Refresh()
end

--- Flash "^ <name> <new>" on the skill's own family's feed for profile.broker.flashSeconds.
function B.Flash(key, new)
    local e = model and model.byKey[key]   -- the live model: a flash is always a live skill-up
    for k in pairs(flash) do flash[k] = nil end
    flash[familyOfSkill(key, model) or B.DEFAULT_FEED] = flashText(e and e.name or key, new)
    if flashTimer then NS.addon:CancelTimer(flashTimer) end
    flashTimer = NS.addon:ScheduleTimer(endFlash, B.FlashSeconds())
    B.Refresh()
end

--- The feed a flash shows on now, or nil (the suites read it).
function B.Flashing()
    return next(flash)
end

-- ---------------------------------------------------------------------------------------------
-- The bus
-- ---------------------------------------------------------------------------------------------

local function indexStats(m)
    local index = {}
    for _, group in ipairs(NS.StatData.GROUPS) do
        for _, e in ipairs(type(m) == "table" and m[group] or {}) do index[e.key] = e end
    end
    return index
end

local function onSkillsUpdated(_, m)
    if type(m) == "table" then model = m end
    B.Refresh()
end

local function onSkillUp(_, key, old, new)
    local up = (tonumber(new) or 0) - (tonumber(old) or 0)
    if up <= 0 then return end
    gains.total = gains.total + up
    gains.byKey[key] = (gains.byKey[key] or 0) + up
    last = { key = key, new = new }
    B.Flash(key, new)
end

local function onStatsUpdated(_, m)
    if type(m) ~= "table" then return end
    statsModel, statIndex = m, indexStats(m)
    B.Refresh()
end

B.target = NS.NewBusTarget()
if B.target then
    B.target:RegisterMessage(NS.MSG.SKILLS_UPDATED, onSkillsUpdated)
    B.target:RegisterMessage(NS.MSG.SKILL_UP, onSkillUp)
    B.target:RegisterMessage(NS.MSG.STATS_UPDATED, onStatsUpdated)
    B.target:RegisterMessage(NS.MSG.BONUSES_UPDATED, function() B.Refresh() end)
    -- A tree family's model (SMW-08..10): its feed's pins read it.
    for _, fam in pairs(NS.Families) do
        local msg = fam.tree and rawget(NS.MSG, fam.message)
        if msg then B.target:RegisterMessage(msg, function() B.Refresh() end) end
    end
end


-- ---------------------------------------------------------------------------------------------
-- Clicks (design §6.5, Feed row): never secure
-- ---------------------------------------------------------------------------------------------

-- Feed `fid`'s own window (SMW-05): the Professions feed's is the window behind NS.MainWindow.
local function toggleWindow(fid)
    if fid == B.DEFAULT_FEED or not NS.Windows then
        local W = type(NS.MainWindow) == "table" and NS.MainWindow or nil
        if W and type(W.Toggle) == "function" then W.Toggle() end
        return
    end
    NS.Windows.Toggle(fid)
end

local current   -- the frame the feed's tooltip is on now (the showing machinery, below)

--- The feed options: the Broker settings page through the options library's page opener, else
--- the main settings panel (the library absent: its stub prints why), else nothing.
function B.OpenSettings()
    local H = NS.Helpers
    if type(H) == "table" and type(H.OpenOptionsPanel) == "function" then
        return H.OpenOptionsPanel(B.SETTINGS_PAGE)
    end
    if type(NS.OpenOptionsPanel) == "function" then return NS.OpenOptionsPanel() end
    return nil
end

--- Feed `fid`'s own cell (the Professions feed's by default): left toggles its family's window, right
--- opens the feed options.
function B.OnClick(_, button, fid)
    if button == "RightButton" then return B.OpenSettings() end
    toggleWindow(B.FEEDS[fid] and fid or B.DEFAULT_FEED)
end

-- ---------------------------------------------------------------------------------------------
-- The tooltip frame (FB-13): the shared GameTooltip as it is, or this file's own, skinned
-- ---------------------------------------------------------------------------------------------

local ownTip   -- this file's own tooltip frame, made on the first skinned show

local function skinnedTip()
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", B.TIP_NAME, UIParent, "GameTooltipTemplate")
    end
    return ownTip
end

--- The main window's style's frame (modules/BrokerPanel.lua), or nil without it.
local function panel()
    local P = NS.BrokerPanel
    return type(P) == "table" and P.Frame and P or nil
end

--- The frame the tooltip draws on now: in the Main window style the panel (modules/BrokerPanel.lua);
--- in the Classic style the feed's own skinned frame while broker.tooltip.skin is on, else the
--- shared GameTooltip.
function B.Tip()
    if B.Style() == "window" and panel() then return panel().Frame() end
    if B.Skinned() then return skinnedTip() end
    return GameTooltip
end

--- The feed's own tooltip frame, or nil before the first skinned show (the suites read it).
function B.OwnTip() return ownTip end

-- The tooltip's line font strings, found by the frame's global name as the client names them.
local function eachLine(tip, fn)
    local name = tip.GetName and tip:GetName()
    local count = tonumber(tip.NumLines and tip:NumLines()) or 0
    if not name then return end
    for n = 1, count do
        fn(n, _G[name .. "TextLeft" .. n], _G[name .. "TextRight" .. n])
    end
end

--- Paint the owned frame from the active skin: the window shell (backdrop and border, no title
--- band) and every line's font, the title line in the title face. Run after Show, since a
--- tooltip's OnShow lays the template's own backdrop again.
local function paintTip(tip)
    local S = NS.Skin
    S.Shell(tip, { noTopBar = true })
    eachLine(tip, function(n, left, right)
        if left then S.Text(left, n == 1 and "title" or "body") end
        if right then S.Text(right, "body") end
    end)
end

-- ---------------------------------------------------------------------------------------------
-- Showing and hiding the tooltip: it stays while the pointer is on the cell or the tooltip
-- ---------------------------------------------------------------------------------------------

local hooked, owner, poll = {}, nil, nil   -- `current`: declared above, with the clicks

local function stopPoll()
    if poll then NS.addon:CancelTimer(poll) end
    poll = nil
end

-- The shared GameTooltip hides and clears for every frame that uses it: only the feed's own show
-- lets its bars and hit areas go.
local function hookTooltip(tip)
    if hooked[tip] then return end
    hooked[tip] = true
    tip:HookScript("OnHide", function()
        if current ~= tip then return end
        B.ReleaseLines() owner = nil current = nil stopPoll()
        B.TooltipToggled(nil)
    end)
    if tip.HasScript and tip:HasScript("OnTooltipCleared") then
        tip:HookScript("OnTooltipCleared", function() if current == tip then B.ReleaseLines() end end)
    end
end

-- Where the feed's tooltip opens (launcher-§7; LibKa0s#92, AD-92-SM): attached to the display's
-- cell, never the cursor, toward the screen's center, TIP_GAP off the cell, through
-- LibKa0s-Tooltip-1.0's PlaceLauncher (the vertical side by the screen half, the horizontal by its
-- third), which writes a relative point and so needs no size: the panel (Main window style) and
-- the line tooltip (Classic) are placed before they fill. Without the library, or a cell whose
-- geometry cannot be read, centered on the cell, below it in the screen's upper half and above it
-- in the lower.
local function anchor(tip, frame)
    if tip.SetOwner then tip:SetOwner(frame, "ANCHOR_NONE") end
    if NS.Chrome.PlaceLauncher(tip, frame) then return end
    tip:ClearAllPoints()
    local _, y = frame:GetCenter()
    local top = y and UIParent:GetHeight() and y > UIParent:GetHeight() / 2
    if top then tip:SetPoint("TOP", frame, "BOTTOM", 0, -2) else tip:SetPoint("BOTTOM", frame, "TOP", 0, 2) end
end

--- The Classic style's lines on `tip` for feed `which`, shown, skinned and sized; then the rows' hover
--- areas and the sections' fold chevrons (modules/BrokerTooltip.lua B.AddHit).
local function drawLines(tip, which)
    local rows = B.FillTooltip(tip, which)
    tip:Show()
    if tip == ownTip then paintTip(tip) end
    -- Tooltips > Font size, after the skin's fonts, then one more layout pass for both.
    NS.Chrome.TooltipFontSize(tip, tipSettings().fontSize, 1)
    tip:Show()   -- a shown tooltip lays itself out again for the new fonts
    for _, row in ipairs(rows) do B.AddHit(tip, row) end
end

-- The feed whose tooltip is up, as WINDOW_TOGGLED's sibling FEED_TOOLTIP_TOGGLED tells it (SMW-10: the Statistics
-- model reads only while its window or tooltip shows): `fid` now up (nil: none), the one before it down.
local tipFeed = nil
function B.TooltipToggled(fid)
    if tipFeed == fid then return end
    local was = tipFeed
    tipFeed = fid
    if was then NS.bus:SendMessage(NS.MSG.FEED_TOOLTIP_TOGGLED, was, false) end
    if fid then NS.bus:SendMessage(NS.MSG.FEED_TOOLTIP_TOGGLED, fid, true) end
end

--- The feed whose tooltip is up, or nil.
function B.TooltipFeed() return tipFeed end

--- Take the feed's tooltip down, whichever frame it is on (the skin switch's write).
function B.HideTooltip()
    stopPoll()
    local tip = current
    if tip and tip:IsShown() then tip:Hide() end
    B.ReleaseLines()
    owner, current = nil, nil
    B.TooltipToggled(nil)
end

--- Show feed `which`'s tooltip (a family id, the Professions feed by default) on its display cell `frame`.
function B.OnEnter(frame, which)
    which = B.SetFeed(which)
    local tip = B.Tip()
    stopPoll()
    if current and current ~= tip then B.HideTooltip() end
    hookTooltip(tip)
    anchor(tip, frame)
    owner, current = frame, tip
    B.TooltipToggled(which)   -- before the fill: a model that reads on first use reads now (SMW-10)
    if panel() and tip == panel().Frame() then
        panel().Fill()
        tip:Show()
        return
    end
    drawLines(tip, which)
end

--- Draw the tooltip showing now again where it stands (a fold chevron's click, SMW-07): the Main window
--- style refills its body at the same scroll offset (clamped), the Classic style its lines. Answers whether
--- a tooltip was up to redraw.
function B.RedrawTooltip()
    local tip = current
    if not (tip and tip:IsShown()) then return false end
    if panel() and tip == panel().Frame() then
        panel().Fill(true)
        return true
    end
    if tip.ClearLines then tip:ClearLines() end
    drawLines(tip, feed)
    return true
end

local function stillHovered(tip)
    if tip:IsMouseOver() then return true end
    return owner ~= nil and owner.IsMouseOver ~= nil and owner:IsMouseOver()
end

--- Whether the tooltip is still the feed's: another frame may have taken the shared GameTooltip
--- since (SetOwner).
local function ownsTip(tip)
    if owner == nil or current ~= tip then return false end
    if type(tip.GetOwner) ~= "function" then return true end
    return tip:GetOwner() == owner
end

function B.OnLeave()
    local tip = current
    stopPoll()
    if not tip then return end
    poll = NS.addon:ScheduleRepeatingTimer(function()
        local mine = ownsTip(tip)
        if mine and tip:IsShown() and stillHovered(tip) then return end
        stopPoll()
        if mine then tip:Hide() end
        owner = nil
    end, HIDE_POLL)
end


-- ---------------------------------------------------------------------------------------------
-- The data objects, one per family, built at load (LibDataBroker-1.1 loads in the TOC's # Libraries
-- block), in the family order
-- ---------------------------------------------------------------------------------------------

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if LDB then
    for _, fid in ipairs(NS.FAMILY_ORDER) do
        local f = B.FEEDS[fid]
        objects[fid] = LDB:NewDataObject(f.name, {
            type  = "data source",
            label = f.label,
            text  = f.short,
            icon  = f.icon or NS.Constants.LOGO_ICON_PATH,   -- its family's (R5-SM-04); the launcher keeps the logo
            OnClick = function(frame, button) B.OnClick(frame, button, fid) end,
            OnEnter = function(frame) B.OnEnter(frame, fid) end,
            OnLeave = function() B.OnLeave() end,
        })
    end
else
    NS.Debug("Broker", "%s: LibDataBroker-1.1 absent, no data feed", addonName)
end
