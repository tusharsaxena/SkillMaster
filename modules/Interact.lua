local addonName, NS = ...
-- modules/Interact.lua — what a click on a row does (design §6.2, §6.5, plan Task 3.3):
--   left click   on the row itself: as Open a row from says (round 8, R8-1; NS.Rows.OpenFrom, the
--                row's OnClick): Full row, the default, what its mark does (OnMarkClick); Go icon
--                only, nothing (owner feedback round 4: OnRowClick).
--                On its ACTION MARK (every row's, stat rows' too): a crafting profession: its window,
--                through the mark's secure overlay (modules/SecureOverlay.lua; a click that reaches
--                the plain mark means there is none, in combat or not yet synced); Skinning and
--                Fishing: their own window by skill-line ID (catalog tradeSkill, owner feedback round
--                3), else as the next; a gathering, weapon, Defense, Lockpicking or Riding row:
--                Character -> Skills with that line selected; a stat row: Character -> paper doll
--                (both through the mark's secure overlay when the micro menu is there, so the panel
--                opens untainted); an unlearned row: the trainer popup
--   shift-click  a profession's trade link, any other row as text, into the chat edit box
--   right-click  the row menu (LibKa0s-Widgets-1.0 ContextMenu): pin to its family's broker, hide the
--                row, set a waypoint to the trainer, show the trainers
-- Never secure itself. The LDB tooltip's rows open nothing (SMW-07: only a section's fold acts there).
--
-- NS.Interact.OnRowClick(row, button) -> "none"|"link"|"menu"
-- NS.Interact.OnMarkClick(row, button) -> "secure"|"tradeskill"|"skills"|"paperdoll"|"trainer"|"link"|"menu"
-- NS.Interact.Target(row), .Open(row), .Link(row), .LinkText(row), .TradeLink(row), .Menu(row),
-- .MenuRows(row), .Trainer(row), .OpenSkills(key), .OpenTradeSkill(key), .SkillLineIndex(key),
-- .SelectSkillLine(key), .ShowSkillsTab(key)

NS.Interact = {}
local I = NS.Interact
local L = NS.L

--- Where a plain left click on `row` goes.
function I.Target(row)
    local e = row.entry
    -- A tree family's row (SMW-08..10) opens no panel: its header folds (NS.Rows), its leaf does nothing.
    if NS.Tree.Kind(row.kind) then return "none" end
    if row.kind == "stat" then return "paperdoll" end
    if e.learned == false then return "trainer" end
    local cat = NS.SkillCatalog[e.key]
    if cat and cat.openSpell then return "secure" end
    if cat and cat.tradeSkill then return "tradeskill" end
    return "skills"
end

-- The character panel's sub-frames on WoW Forever (Camelot CharacterFrame.lua: SkillsFrame, not
-- 1.12's SkillFrame, which ToggleCharacter silently ignored; owner feedback round 4).
I.SKILLS_TAB, I.PAPERDOLL_TAB = "SkillsFrame", "PaperDollFrame"

local function toggleCharacter(tab, onlyShow)
    if type(ToggleCharacter) == "function" then ToggleCharacter(tab, onlyShow) end
end

--- The Skills tab's line index for skill `key` (the catalog's line ID or its child line's parent,
--- else the localized name), or nil while its header is collapsed or the line is not listed.
function I.SkillLineIndex(key)
    local cat = NS.SkillCatalog[key]
    if not cat then return nil end
    local name = cat.name and L[cat.name]
    for i = 1, NS.Compat.NumSkillLines() do
        local rec = NS.Compat.SkillLineInfo(i)
        if rec and not rec.isHeader then
            local id = rec.skillLineID
            if (id and (id == cat.skillLineID or rec.parentSkillLineID == cat.skillLineID))
                or (name and rec.name == name) then
                return i
            end
        end
    end
    return nil
end

local function skillsTabShown()
    local f = SkillsFrame
    return type(f) == "table" and f.IsVisible and f:IsVisible() and true or false
end

--- Select skill `key`'s line in Character -> Skills, before or after the tab shows (Forever's tab
--- keeps a selection it finds on show). Answers the line index, or nil.
function I.SelectSkillLine(key)
    local i = key and I.SkillLineIndex(key)
    local ran = i and NS.Compat.SelectSkillLine(i)
    NS.Debug("Click", "Skills tab for %s: line %s, selected by %s", tostring(key), tostring(i), tostring(ran))
    return i
end

--- The character panel is open (the mark's secure overlay opened it): show its Skills tab, with
--- skill `key`'s line selected and drawn. ToggleCharacter's onlyShow never closes a shown tab.
function I.ShowSkillsTab(key)
    if not skillsTabShown() then toggleCharacter(I.SKILLS_TAB, true) end
    I.SelectSkillLine(key)
    NS.Compat.RefreshSkillsTab()
end

--- Character -> Skills with skill `key`'s line selected (owner feedback round 3), the plain way (no
--- secure overlay: a replaced micro menu). The tab opens unless it is already showing.
function I.OpenSkills(key)
    I.SelectSkillLine(key)
    if not skillsTabShown() then toggleCharacter(I.SKILLS_TAB) end
    I.SelectSkillLine(key)
    NS.Compat.RefreshSkillsTab()
end

--- Skill `key`'s own profession window by its line ID (Skinning, Fishing); the Skills tab when the
--- client does not open it.
function I.OpenTradeSkill(key)
    local cat = NS.SkillCatalog[key]
    if cat and NS.Compat.OpenTradeSkill(cat.skillLineID) then return true end
    NS.Debug("Click", "no profession window for %s: the Skills tab instead", tostring(key))
    I.OpenSkills(key)
    return false
end

--- The trainer popup for `row`'s skill: where to learn it, or where to train its next rank.
function I.Trainer(row)
    if NS.TrainerPopup then NS.TrainerPopup.Show(row.entry.key) end
end

-- The character panel from a plain click (the mark's overlay takes the click when it is armed):
-- in combat it says why not, rather than show the panel tainted.
local function plainPanel(fn)
    return function(row)
        if InCombatLockdown() then
            NS.Print(L["The character panel opens from Skill Master out of combat."])
            return
        end
        fn(row)
    end
end

local OPEN = {
    none = function() end,
    skills = plainPanel(function(row) I.OpenSkills(row.entry.key) end),
    tradeskill = function(row) I.OpenTradeSkill(row.entry.key) end,
    paperdoll = plainPanel(function() toggleCharacter(I.PAPERDOLL_TAB) end),
    trainer = function(row) I.Trainer(row) end,
    secure = function(row)
        -- The overlay takes this click when it is armed; reaching here means it is not.
        if InCombatLockdown() then
            NS.Print(L["Profession windows open from Skill Master out of combat."])
        elseif NS.SecureOverlay then
            local SO, key = NS.SecureOverlay, row.entry.key
            NS.Debug("Click", "no armed crafting overlay under the click: re-synced")
            NS.Debug("Click", "before: %s", SO.Describe(key, row))
            NS.Debug("Click", "under the pointer: %s", SO.MouseFoci())
            SO:Sync()
            NS.Debug("Click", "after: %s", SO.Describe(key, row))
        end
    end,
}

--- Do what a plain left click on `row` does. Answers the target.
function I.Open(row)
    local target = I.Target(row)
    OPEN[target](row)
    return target
end

--- The row as chat text: "[Guns 105 +5 / 110]", "[Hit 2.0%]".
function I.LinkText(row)
    local e = row.entry
    local tree = NS.Tree.Kind(row.kind)
    if tree then return tree.linkText(e) end
    if row.kind == "stat" then return ("[%s %s]"):format(e.label, e.display or "") end
    if e.learned == false then return ("[%s: %s]"):format(e.name, L["Not learned"]) end
    return ("[%s %s]"):format(e.name, NS.Widgets.BarText(e.rank, tonumber(e.modifier) or 0, e.max))
end

--- A learned profession's trade link (owner feedback round 4), as its spellbook icon's shift-click
--- gives: the book's spell named for the profession or its open spell. nil for any other row.
function I.TradeLink(row)
    local e = row.kind == "skill" and row.entry
    if not (e and e.learned ~= false and (e.category == "primary" or e.category == "secondary")) then return nil end
    local cat = NS.SkillCatalog[e.key]
    if not cat then return nil end
    local names = { e.name, L[cat.name] }
    if cat.openSpellID then names[#names + 1] = NS.Compat.SpellName(cat.openSpellID) end
    return NS.Compat.TradeSkillLink(names)
end

--- Put the row into the chat edit box (the open one, else a new one): a profession's trade link,
--- else the row as text.
function I.Link(row)
    local text = I.TradeLink(row) or I.LinkText(row)
    if type(ChatEdit_InsertLink) == "function" and ChatEdit_InsertLink(text) then return end
    if type(ChatFrame_OpenChat) == "function" then ChatFrame_OpenChat(text) end
end

local function trainerOf(e)
    if not NS.Trainers then return nil end
    if e.learned == false then return (NS.Rows.TrainerFor(e)) end
    local nr = NS.Trainers:NextRank(e.key, e.rank, e.max)
    return nr and nr.trainers[1]
end

--- Hide through the seam (architecture-§5): the key's own row when the catalog has one, else the
--- whole set's row (settings/Rows.lua), so an unknown "other:" key is still a settings write
--- that the page's Defaults undoes.
local function hideRow(row)
    local kind = row.kind == "stat" and "stats" or "skills"
    local key = row.entry.key
    local p = kind .. ".hidden." .. key
    if NS.FindSchemaRow(p) then return NS.SetByPath(p, true) end
    local set = {}
    for k, v in pairs(NS.db.profile[kind].hidden or {}) do set[k] = v end
    set[key] = true
    return NS.SetByPath(kind .. ".hidden", set)
end

--- The row menu's Pin row (GitHub issue #11, SMW-06): a tick that pins `row` to its own family's broker
--- (NS.Pins.FamilyOfRow: "Pin to the Professions broker"), or unpins it. Pinning never removes another
--- pin; with NS.Pins.MAX pinned there already, an unpinned row's Pin is disabled and says why.
local function pinRow(row)
    local key, fid = row.entry.key, NS.Pins.FamilyOfRow(row)
    local fam = fid and NS.Families[fid]
    -- A test-mode or simulated row is the sample character's: pinning it would write the sample's
    -- row into this character's store (preview-mode: nothing of the live state is written while
    -- either runs).
    local sample = NS.IsTestMode() or (NS.IsSimRunning ~= nil and NS.IsSimRunning())
    local function pinned() return fid ~= nil and NS.Pins.Has(fid, key) end
    local full = fid ~= nil and not pinned() and NS.Pins.Full(fid)
    return { value = "pin", label = L["Pin to the %s broker"]:format(fam and fam.short or ""),
        disabled = sample or fid == nil or full, selected = pinned,
        tooltip = full and L["%d elements are pinned to this broker. Unpin one first."]:format(NS.Pins.MAX) or nil,
        onClick = function()
            if sample or not fid then return end
            -- NS.Pins redraws the feeds' text at once: a layout message alone never reached a feed,
            -- which redraws on the data messages (feedback round 2).
            NS.Pins.Toggle(fid, key)
        end }
end

--- The row menu's rows (a ContextMenu row list; `value` names each for the suites).
function I.MenuRows(row)
    local e = row.entry
    local rows = { { title = true, label = e.name or e.label } }
    -- A tree row (SMW-08..10): pin a row with a value of its own; a tree row is never hidden.
    if NS.Tree.Kind(row.kind) then
        if e.hasBar ~= false then rows[#rows + 1] = pinRow(row) end
        return rows
    end
    if row.kind == "stat" then rows[#rows + 1] = pinRow(row) end
    if row.kind == "skill" then
        rows[#rows + 1] = pinRow(row)
        local trainer = trainerOf(e)
        rows[#rows + 1] = { value = "waypoint", label = L["Set a waypoint to the trainer"], disabled = trainer == nil,
            onClick = function() if trainer then NS.Waypoints:Set(trainer) end end }
        rows[#rows + 1] = { value = "trainers", label = L["Show trainers"], onClick = function() I.Trainer(row) end }
    end
    -- The LDB tooltip opens no menu (SMW-07): its rows hide from the Rows page's LDB tooltip column.
    rows[#rows + 1] = { value = "hide", label = L["Hide this row"], onClick = function() hideRow(row) end }
    return rows
end

--- Open the row menu at the pointer. Answers (and keeps, as I.menu) the library's shared menu.
function I.Menu(row)
    I.menu = NS.Widgets.ContextMenu(row.frame or row, I.MenuRows(row), { owner = addonName, cursor = true })
    return I.menu
end

--- A click on a row (or on its overlay, for the shift and right buttons): the menu, the link, and
--- for a plain left click nothing (owner feedback round 4: the row opens no panel; its mark does).
function I.OnRowClick(row, button)
    if not (row and row.entry) then return nil end
    if NS.RowTooltip then NS.RowTooltip.Hide(row) end
    if button == "RightButton" then
        I.Menu(row)
        return "menu"
    end
    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
        I.Link(row)
        return "link"
    end
    return "none"
end

--- A click on a row's action mark that its overlay did not take: the row's action (I.Open), the
--- shift and right buttons as on the row.
function I.OnMarkClick(row, button)
    if not (row and row.entry) then return nil end
    if button == "RightButton" or (type(IsShiftKeyDown) == "function" and IsShiftKeyDown()) then
        return I.OnRowClick(row, button)
    end
    if NS.RowTooltip then NS.RowTooltip.Hide(row) end
    return I.Open(row)
end
