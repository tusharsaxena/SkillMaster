local _, NS = ...
-- modules/SharedList.lua — reading a client list whose header collapse is shared with the character panel
-- (items SMW-08 and SMW-09 of docs/superpowers/plans/2026-11-26-characterledger-windows.md; the spec's "The collapse
-- trap"). The reputation and currency lists answer only the rows under OPEN headers, and their headers are the
-- character panel's own (the Reputation and Currency tabs). So a full read opens every collapsed header, reads,
-- and closes them again bottom up, the way modules/SkillData.lua reads the skill list. It never does so:
--   * in combat (InCombatLockdown), nor while the panel tab that shows the list is up (the player would see it
--     move), nor without both toggles: then it reads the rows as listed and says the read is partial;
--   * re-entrantly: a header toggle makes the client announce the list changed (UPDATE_FACTION,
--     CURRENCY_DISPLAY_UPDATE), and the latch (SL.Busy) tells the owner's handler that the event is this
--     read's own.
-- The windows' folds are this addon's (modules/Tree.lua) and never come here.
--
-- A list is { name, count(), row(i), isClosed(row), key(row), toggle(i, open), canToggle(), panel() }.
-- NS.SharedList.Read(list) -> rows, complete, reason / .Busy(name) / .Blocked(list)

NS.SharedList = {}
local SL = NS.SharedList

local reading = {}   -- [list name] = true while that list's read runs (the re-entry latch)

--- Whether list `name` is being read now: an event the client sends meanwhile is the read's own.
function SL.Busy(name) return reading[name] == true end

--- Why the read may not open the list's headers now ("combat", "panel shown", "no toggle"), or nil.
function SL.Blocked(list)
    if type(InCombatLockdown) == "function" and InCombatLockdown() then return "combat" end
    if list.panel and NS.Compat.PanelShown(list.panel()) then return "panel shown" end
    if not (list.canToggle and list.canToggle()) then return "no toggle" end
    return nil
end

-- Open every collapsed header top down (a parent's children then list below it and are visited in turn),
-- noting each key opened in `opened` as it goes, so a raise part way still knows what to close.
local function openAll(list, opened)
    local i = 1
    while i <= list.count() do
        local r = list.row(i)
        if r and list.isClosed(r) and list.toggle(i, true) then opened[list.key(r)] = true end
        i = i + 1
    end
end

-- Close what openAll opened, bottom up so the earlier rows keep their indices.
local function closeAgain(list, opened)
    if next(opened) == nil then return end
    for i = list.count(), 1, -1 do
        local r = list.row(i)
        if r and r.isHeader and opened[list.key(r)] then list.toggle(i, false) end
    end
end

local function readRows(list)
    local rows, closed = {}, false
    for i = 1, list.count() do
        local r = list.row(i)
        if r then
            rows[#rows + 1] = r
            if list.isClosed(r) then closed = true end
        end
    end
    return rows, closed
end

--- Every row of `list`, in the panel's order. Answers the rows, whether they are the whole list (no header
--- left closed) and, when they are not, why the headers stayed shut. A read already running answers nil.
function SL.Read(list)
    if reading[list.name] then return nil, false, "busy" end
    local why = SL.Blocked(list)
    local rows, closed
    local opened = {}   -- outside the pcall: a raise after some header opened still closes it again
    reading[list.name] = true
    local ok, err = pcall(function()
        if why == nil then openAll(list, opened) end
        rows, closed = readRows(list)
        closeAgain(list, opened)
    end)
    if not ok then pcall(closeAgain, list, opened) end
    reading[list.name] = nil
    if not ok then error(err, 0) end
    if closed then return rows, false, why or "closed" end
    return rows, true, nil
end
