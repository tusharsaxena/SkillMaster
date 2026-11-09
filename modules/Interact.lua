local addonName, NS = ...
-- modules/Interact.lua — what a click on a row does (design §6.2, §6.5, plan Task 3.3):
--   left click   a crafting profession: its window, through its secure overlay (modules/
--                SecureOverlay.lua; a click that reaches the plain row means there is none, in
--                combat or not yet synced); a gathering, weapon, Defense, Lockpicking or Riding row:
--                Character -> Skills; a stat row: Character -> paper doll; an unlearned row: the
--                trainer popup
--   shift-click  the row as text into the chat edit box
--   right-click  the row menu (LibKa0s-Widgets-1.0 ContextMenu): pin to the broker feed, hide the
--                row, set a waypoint to the trainer, show the trainers
-- Never secure itself; the broker's rows (T4.1) reuse Target and Open, never the overlays.
--
-- NS.Interact.OnRowClick(row, button) -> "secure"|"skills"|"paperdoll"|"trainer"|"link"|"menu"
-- NS.Interact.Target(row), .Open(row), .Link(row), .LinkText(row), .Menu(row), .MenuRows(row),
-- .Trainer(row)

NS.Interact = {}
local I = NS.Interact
local L = NS.L

--- Where a plain left click on `row` goes.
function I.Target(row)
    local e = row.entry
    if row.kind == "stat" then return "paperdoll" end
    if e.learned == false then return "trainer" end
    local cat = NS.SkillCatalog[e.key]
    if cat and cat.openSpell then return "secure" end
    return "skills"
end

local function toggleCharacter(tab)
    if type(ToggleCharacter) == "function" then ToggleCharacter(tab) end
end

--- The trainer popup for `row`'s skill: where to learn it, or where to train its next rank.
function I.Trainer(row)
    if NS.TrainerPopup then NS.TrainerPopup.Show(row.entry.key) end
end

local OPEN = {
    skills = function() toggleCharacter("SkillFrame") end,
    paperdoll = function() toggleCharacter("PaperDollFrame") end,
    trainer = function(row) I.Trainer(row) end,
    secure = function()
        -- The overlay takes this click when it is armed; reaching here means it is not.
        if InCombatLockdown() then
            NS.Print(L["Profession windows open from Skill Master out of combat."])
        elseif NS.SecureOverlay then
            NS.SecureOverlay:Sync()
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
    if row.kind == "stat" then return ("[%s %s]"):format(e.label, e.display or "") end
    if e.learned == false then return ("[%s: %s]"):format(e.name, L["Not learned"]) end
    return ("[%s %s]"):format(e.name, NS.Bar.Text(e.rank, tonumber(e.modifier) or 0, e.max))
end

--- Put the row's text into the chat edit box (the open one, else a new one).
function I.Link(row)
    local text = I.LinkText(row)
    if type(ChatEdit_InsertLink) == "function" and ChatEdit_InsertLink(text) then return end
    if type(ChatFrame_OpenChat) == "function" then ChatFrame_OpenChat(text) end
end

local function trainerOf(e)
    if not NS.Trainers then return nil end
    if e.learned == false then return (NS.Rows.TrainerFor(e)) end
    local nr = NS.Trainers:NextRank(e.key, e.rank, e.max)
    return nr and nr.trainers[1]
end

local function hideRow(row)
    local kind = row.kind == "stat" and "stats" or "skills"
    NS.db.profile[kind].hidden[row.entry.key] = true
    NS.Blocks.Changed()
end

--- The row menu's rows (a ContextMenu row list; `value` names each for the suites).
function I.MenuRows(row)
    local e = row.entry
    local rows = { { title = true, label = e.name or e.label } }
    if row.kind == "skill" then
        local key = e.key
        rows[#rows + 1] = { value = "pin", label = L["Pin to the broker feed"], radio = true,
            selected = function() return NS.db.char ~= nil and NS.db.char.pinned == key end,
            onClick = function()
                if NS.db.char then NS.db.char.pinned = key end
                NS.Blocks.Changed()
            end }
        local trainer = trainerOf(e)
        rows[#rows + 1] = { value = "waypoint", label = L["Set a waypoint to the trainer"], disabled = trainer == nil,
            onClick = function() if trainer then NS.Waypoints:Set(trainer) end end }
        rows[#rows + 1] = { value = "trainers", label = L["Show trainers"], onClick = function() I.Trainer(row) end }
    end
    rows[#rows + 1] = { value = "hide", label = L["Hide this row"], onClick = function() hideRow(row) end }
    return rows
end

--- Open the row menu at the pointer. Answers (and keeps, as I.menu) the library's shared menu.
function I.Menu(row)
    I.menu = NS.Widgets.ContextMenu(row, I.MenuRows(row), { owner = addonName, cursor = true })
    return I.menu
end

--- A click on a row (or on its overlay, for the shift and right buttons).
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
    return I.Open(row)
end
