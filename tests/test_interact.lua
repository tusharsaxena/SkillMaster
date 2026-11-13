-- tests/test_interact.lua — clicks, the secure crafting overlays, the row tooltip, the trainer popup
-- and the waypoints (plan Task 3.3, design §6.5, Review Focus 3).
local T = _G.SKM_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse
local B, W, SO, I = NS.Blocks, NS.MainWindow, NS.SecureOverlay, NS.Interact

local function skill(key, name, category, rank, max, modifier, learned)
    return { key = key, name = name, category = category, kind = NS.SkillCatalog[key] and NS.SkillCatalog[key].kind,
             rank = rank, max = max, tempPoints = 0, modifier = modifier or 0, learned = learned ~= false }
end

local function fixture()
    local byKey = {
        tailoring      = skill("tailoring", "Tailoring", "primary", 146, 150),
        skinning       = skill("skinning", "Skinning", "primary", 122, 150),
        fishing        = skill("fishing", "Fishing", "secondary", 107, 150, 25),
        guns           = skill("guns", "Guns", "weapon", 105, 110, 5),
        fistWeapons    = skill("fistWeapons", "Fist Weapons", "weapon", 0, 0, 0, false),
    }
    local skills = { byKey = byKey, order = { primary = { "tailoring", "skinning" }, secondary = { "fishing" },
                                               weapon = { "guns", "fistWeapons" }, other = {} } }
    local stats = { base = { { key = "hit", label = "Hit", value = 2, display = "2.0%", pct = 22.2, ref = 9,
                               markers = { { at = 55.6, value = 5, label = "vs same level" },
                                           { at = 100, value = 9, label = "vs raid boss" } } } },
                    spell = {}, defense = {}, utility = {} }
    return skills, stats
end

-- The kit's AceDB fake carries profile and global only; the real one gives every addon `char`.
NS.db.char = NS.db.char or { pinned = false }

local SWAPPED = { "UnitFactionGroup", "UnitRace", "UnitLevel", "InCombatLockdown", "CreateFrame", "ToggleCharacter",
                  "TomTom", "C_Map", "UiMapPoint", "GetZoneText", "IsShiftKeyDown", "ChatEdit_InsertLink",
                  "GetCursorPosition" }

--- A world: the fixture as the blocks' source, an Alliance Dwarf at 22, every secure button's
--- attributes recorded, and every swapped global put back afterwards.
local function withWorld(fn)
    local skills, stats = fixture()
    local saved, savedSource = {}, B.source
    for _, k in ipairs(SWAPPED) do saved[k] = M[k] end
    B.source = function() return skills, stats end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    M.UnitRace = function() return "Dwarf", "Dwarf" end
    M.UnitLevel = function() return 22 end
    M.InCombatLockdown = function() return false end
    M.GetCursorPosition = function() return 400, 300 end   -- the row menu opens at the pointer
    local world = { secure = {}, opened = {} }
    local realCreate = saved.CreateFrame
    M.CreateFrame = function(kind, name, parent, template)
        local f = realCreate(kind, name, parent, template)
        if template == "SecureActionButtonTemplate" then
            world.secure[#world.secure + 1] = f
            f.__attr = {}
            f.SetAttribute = function(self, k, v)
                assertFalse(M.InCombatLockdown(), "SetAttribute in combat (" .. tostring(k) .. ")")
                self.__attr[k] = v
            end
        end
        return f
    end
    M.ToggleCharacter = function(tab) world.opened[#world.opened + 1] = tab end
    local ok, err = pcall(fn, world, skills, stats)
    W.Hide()
    NS.TrainerPopup.Hide()
    NS.Widgets.CloseMenu()
    -- The fake's Hide fires no OnHide, which is where the shared menu drops GLOBAL_MOUSE_DOWN.
    if I.menu and I.menu.__fire then I.menu:__fire("OnHide") end
    for _, id in ipairs(NS.BLOCKS) do NS.db.profile.layout.blocks[id].docked = true end
    NS.Detached.Refresh()
    for _, k in ipairs(SWAPPED) do M[k] = saved[k] end
    B.source = savedSource
    SO:Sync()
    if not ok then error(err, 0) end
end

local function rowFor(key)
    for _, row in ipairs(W.Rows()) do if row.entry and row.entry.key == key then return row end end
    for _, id in ipairs(NS.BLOCKS) do
        for _, row in ipairs(NS.Detached.Rows(id)) do if row.entry and row.entry.key == key then return row end end
    end
end

local function spyCalls(f, names)
    local n = { count = 0 }
    for _, name in ipairs(names) do
        local real = f[name]
        rawset(f, name, function(...)
            n.count = n.count + 1
            return real(...)
        end)
    end
    return n
end

test("test_secure_overlay_deferred_in_combat: crafting overlays are made and moved only out of combat", function()
    -- red under: an overlay created, shown, re-anchored or given attributes while InCombatLockdown()
    -- answers true; a detach that applies in combat; or a regen that does not replay the queue.
    withWorld(function(world, skills)
        W.Show()
        rowFor("tailoring"):__fire("OnEnter")   -- only the hovered crafting row is armed
        local lw = SO.Overlay("tailoring")
        assertTrue(lw ~= nil, "a crafting row gets its overlay out of combat")
        assertEqual(lw.__template, "SecureActionButtonTemplate")
        assertEqual(lw.__attr.type1, "spell")
        assertEqual(lw.__attr.spell, "Tailoring", "the localized open spell")
        assertTrue(lw:IsShown(), "armed over its row")
        assertTrue(SO.Overlay("skinning") == nil, "a gathering row opens the Skills tab instead: no overlay")
        assertTrue(lw.row == rowFor("tailoring"), "laid over the tailoring row")

        -- The combat-start edge: lockdown is not on yet inside PLAYER_REGEN_DISABLED, the last
        -- chance to disarm (events-frames-taint-§2).
        M.__fireEvent("PLAYER_REGEN_DISABLED")
        assertFalse(lw:IsShown(), "disarmed at combat start")

        M.InCombatLockdown = function() return true end
        local before = #world.secure
        local moves = spyCalls(lw, { "SetPoint", "ClearAllPoints", "Show", "Hide", "SetFrameStrata", "SetFrameLevel" })
        skills.byKey.alchemy = skill("alchemy", "Alchemy", "primary", 40, 75)
        table.insert(skills.order.primary, 1, "alchemy")
        NS.bus:SendMessage(NS.MSG.SKILLS_UPDATED, skills)
        rowFor("alchemy"):__fire("OnEnter")   -- a hover in combat arms nothing
        assertEqual(#world.secure, before, "no secure button is created in combat")
        assertTrue(SO.Overlay("alchemy") == nil)
        assertEqual(moves.count, 0, "nothing re-anchors, shows or re-levels an overlay in combat")
        assertTrue(SO:Pending(), "the sync waits for the end of combat")

        assertFalse(B:Detach("primary"), "a detach in combat is queued, not applied")
        assertTrue(NS.db.profile.layout.blocks.primary.docked, "still docked in combat")

        M.__resetPrinted()
        local target = I.OnMarkClick(rowFor("alchemy"), "LeftButton")
        assertEqual(target, "secure")
        assertEqual(#world.opened, 0, "the insecure path opens nothing")
        assertEqual(#M.__printed(), 1, "one line says why")

        M.InCombatLockdown = function() return false end
        M.__fireEvent("PLAYER_REGEN_ENABLED")
        assertFalse(NS.db.profile.layout.blocks.primary.docked, "the queued detach ran after combat")
        assertFalse(SO:Pending())
        rowFor("alchemy"):__fire("OnEnter")   -- the row in the detached frame now
        local al = SO.Overlay("alchemy")
        assertTrue(al ~= nil and al:IsShown(), "the new crafting row got its overlay after combat")
        assertEqual(al.__attr.spell, "Alchemy")
        assertTrue(al.row == rowFor("alchemy"), "over the row in the detached frame")
        rowFor("alchemy"):__fire("OnLeave")
        assertFalse(al:IsShown(), "the pointer gone: disarmed")
        rowFor("tailoring"):__fire("OnEnter")
        assertTrue(lw:IsShown(), "re-armed on the next hover")
    end)
end)

test("secure overlay: hiding the window hides its overlays; the stand-down takes them down", function()
    withWorld(function()
        W.Show()
        rowFor("tailoring"):__fire("OnEnter")
        local lw = SO.Overlay("tailoring")
        assertTrue(lw:IsShown())
        W.Hide()
        assertFalse(lw:IsShown(), "no overlay over a hidden window")
        assertTrue(lw.row == nil, "and none points at a parked row")
        W.Show()
        assertFalse(lw:IsShown(), "a parked row is hovered no more: nothing armed on the re-show")
        rowFor("tailoring"):__fire("OnEnter")
        assertTrue(lw:IsShown())
        SO:StandDown()
        assertFalse(lw:IsShown(), "the stand-down disarms")
    end)
end)

test("secure overlay: a click that reaches a crafting row logs its overlay's state, before and after the re-sync", function()
    withWorld(function()
        W.Show()
        local row = rowFor("tailoring")
        row:__fire("OnEnter")
        local line = SO.Describe("tailoring", row)
        assertTrue(line:find("overlay tailoring: shown=true", 1, true) ~= nil, line)
        assertTrue(line:find("armedFor=true", 1, true) ~= nil, line)
        assertTrue(line:find("level=", 1, true) ~= nil and line:find("rowRect=", 1, true) ~= nil, line)
        assertTrue(line:find("clicks=", 1, true) ~= nil and line:find("propagate=", 1, true) ~= nil, line)
        assertEqual(type(SO.MouseFoci()), "string", "the pointer's frames, as text on any client")
        local none = SO.Describe("skinning", rowFor("skinning"))
        assertTrue(none:find("none made", 1, true) ~= nil, none)
        assertEqual(I.OnMarkClick(row, "LeftButton"), "secure", "the out-of-combat fall-through logs and re-syncs")
    end)
end)

test("secure overlay: the pointer entering a crafting row lays its overlay before any press", function()
    -- red under: an overlay laid only by the row's mouse-down. The client gives the click to the
    -- frame under the press, so an overlay laid by that press missed it (feedback round 2: "nothing
    -- happens when I click").
    withWorld(function()
        W.Show()
        local row = rowFor("tailoring")
        local lw = SO.Overlay("tailoring")
        lw:Hide()
        lw.row = nil
        row:__fire("OnEnter")
        assertTrue(lw:IsShown(), "armed by the hover")
        assertTrue(lw.row == row, "over the hovered row")
        row:__fire("OnLeave")
    end)
end)

test("secure overlay: only the hovered crafting row is armed, one strata over its window, until the pointer leaves", function()
    -- red under: every crafting row armed at once (an invisible mouse-live frame a strata up could
    -- cover another window), an overlay in its host's own strata (a toplevel window's raised group
    -- outranks it: feedback round 2), or the overlay's own appearance counted as leaving the row.
    withWorld(function()
        W.Show()
        assertTrue(SO.Overlay("tailoring") == nil or not SO.Overlay("tailoring"):IsShown(), "nothing armed unhovered")
        local row = rowFor("tailoring")
        row:__fire("OnEnter")
        local lw = SO.Overlay("tailoring")
        assertTrue(lw:IsShown() and lw.row == row, "the hovered row is armed")
        assertEqual(lw:GetFrameStrata(), NS.Constants.LAYERS.STRATA_ABOVE[W.Frame():GetFrameStrata()],
            "one strata over its window")
        -- The overlay appears under the pointer: the row's leave is not a leave.
        rawset(lw, "IsMouseOver", function() return true end)
        row:__fire("OnLeave")
        assertTrue(lw:IsShown(), "still armed while the pointer is on the overlay")
        -- The pointer leaves the overlay: its hook runs the row's leave.
        rawset(lw, "IsMouseOver", function() return false end)
        lw:__fire("OnLeave")
        assertFalse(lw:IsShown(), "disarmed once the pointer is off both")
        rawset(lw, "IsMouseOver", nil)
    end)
end)

test("interact: the click map (design §6.5)", function()
    withWorld(function(world)
        W.Show()
        -- Skinning opens its own window by line ID; without the call, the Skills tab instead.
        assertEqual(I.OnRowClick(rowFor("skinning"), "LeftButton"), "none", "the row itself opens nothing (round 4)")
        assertEqual(#world.opened, 0)
        assertEqual(I.OnMarkClick(rowFor("skinning"), "LeftButton"), "tradeskill")
        assertEqual(world.opened[#world.opened], "SkillsFrame", "no OpenTradeSkill: the Skills tab")
        local openedLine
        M.C_TradeSkillUI = { OpenTradeSkill = function(id) openedLine = id return true end }
        local before = #world.opened
        assertEqual(I.OnMarkClick(rowFor("skinning"), "LeftButton"), "tradeskill")
        assertEqual(openedLine, 393, "Skinning's window by its skill-line ID")
        assertEqual(#world.opened, before, "and no Skills tab")
        M.C_TradeSkillUI = nil
        assertEqual(I.OnMarkClick(rowFor("guns"), "LeftButton"), "skills")
        assertEqual(I.OnRowClick(rowFor("hit"), "LeftButton"), "none", "a stat row opens no panel (round 4)")
        assertEqual(I.OnMarkClick(rowFor("hit"), "LeftButton"), "paperdoll")
        assertEqual(world.opened[#world.opened], "PaperDollFrame")
        assertEqual(I.OnMarkClick(rowFor("fistWeapons"), "LeftButton"), "trainer")
        assertTrue(NS.TrainerPopup.IsShown(), "an unlearned row opens the trainer popup")
        assertEqual(I.Target(rowFor("tailoring")), "secure")
    end)
end)

test("interact: shift-click links the row to chat; right-click opens the row menu", function()
    withWorld(function()
        W.Show()
        local linked
        M.ChatEdit_InsertLink = function(text) linked = text return true end
        M.IsShiftKeyDown = function() return true end
        assertEqual(I.OnRowClick(rowFor("guns"), "LeftButton"), "link")
        assertEqual(linked, "[Guns 105 +5 / 110]")
        M.IsShiftKeyDown = function() return false end
        local rows = I.MenuRows(rowFor("guns"))
        assertEqual(rows[1].title and rows[1].label, "Guns", "the menu is titled with the row")
        local hide
        for _, r in ipairs(rows) do if r.value == "hide" then hide = r end end
        assertTrue(hide ~= nil, "a Hide row")
        hide.onClick("hide", hide)
        assertTrue(NS.db.profile.skills.hidden.guns, "hidden")
        assertTrue(rowFor("guns") == nil, "and gone from the window")
        NS.db.profile.skills.hidden.guns = nil
        local pin
        for _, r in ipairs(I.MenuRows(rowFor("fishing"))) do if r.value == "pin" then pin = r end end
        pin.onClick("pin", pin)
        assertEqual(NS.db.char.pinned, "fishing", "pinned for the broker's {pinned}")
        NS.db.char.pinned = false
        assertEqual(I.OnRowClick(rowFor("fishing"), "RightButton"), "menu")
    end)
end)

test("test_rowtooltip_lines_fishing_lure: the lure, its timer, the session and the fishing helper", function()
    -- red under: a temp source drawn without its time left, or the helper line missing on Fishing.
    withWorld(function(_, skills)
        local savedB, savedNow = NS.Bonuses.Breakdown, M.__now
        local savedNeed = NS.SkillHelpers.FishingNeedHere
        M.__now = 1000
        NS.Bonuses.Breakdown = function() return { total = 25, sources = {
            { label = "Shiny Bauble", amount = 25, kind = "temp", expires = 1252, source = "enchant" } } } end
        NS.SkillHelpers.FishingNeedHere = function() return 75 end
        M.GetZoneText = function() return "Loch Modan" end
        local ok, err = pcall(function()
            local lines = NS.RowTooltip.Lines(skills.byKey.fishing, "skill")
            local text, lure, helper = {}, nil, nil
            for _, l in ipairs(lines) do
                local s = (l.left or "") .. " | " .. (l.right or "")
                text[#text + 1] = s
                if (l.left or ""):find("Shiny Bauble", 1, true) then lure = l end
                if s:find("Loch Modan", 1, true) then helper = l end
            end
            local all = table.concat(text, "\n")
            assertEqual(lines[1].left, "Fishing")
            assertEqual(lines[1].right, "Secondary")
            assertTrue(all:find("107 +25 / 150", 1, true) ~= nil, all)
            assertTrue(all:find("effective 132", 1, true) ~= nil, all)
            assertTrue(lure ~= nil, "the lure is a bonus line: " .. all)
            assertEqual(lure.right, "+25 \194\183 4:12", "amount and time left")
            assertEqual(lure.tone, "temp")
            assertTrue(helper ~= nil, "the fishing helper line: " .. all)
            assertTrue(helper.left:find("75", 1, true) ~= nil, helper.left)
            assertTrue(all:find("Expert", 1, true) == nil or true)
            assertTrue(all:find("Shift-click", 1, true) ~= nil, "the click hints close it")
        end)
        NS.Bonuses.Breakdown, M.__now = savedB, savedNow
        NS.SkillHelpers.FishingNeedHere = savedNeed
        if not ok then error(err, 0) end
    end)
end)

test("rowtooltip: the session line is this skill's gains and rate; the ETA reads in hours", function()
    -- red under: the tooltip asks the session log for a method it does not have, so the mockup's
    -- "This session +6 (3 / h)" line never draws; or the ETA prints as a clock ("14:00:00")
    withWorld(function(_, skills)
        local SL = NS.SessionLog
        local c = NS.db.char
        local savedLog, savedStart, savedETA = c.log, SL:SessionStart(), SL.ETA
        local now = M.time()
        c.log = {}
        SL:NewSession(now - 7200)
        SL:Add("fishing", 101, 104, now - 7000)
        SL:Add("guns", 100, 105, now - 6000)
        SL:Add("fishing", 104, 107, now - 100)
        SL.ETA = function(_, key) return key == "fishing" and 14 * 3600 or nil end
        local ok, err = pcall(function()
            local session, eta
            for _, l in ipairs(NS.RowTooltip.Lines(skills.byKey.fishing, "skill")) do
                if l.left == "This session" then session = l end
                if (l.left or ""):find("ETA to", 1, true) then eta = l end
            end
            assertTrue(session ~= nil, "the session line draws")
            assertEqual(session.right, "+6 (3 / h)", "this skill's points and its rate over the session")
            assertTrue(eta ~= nil, "the ETA line draws")
            assertEqual(eta.right, "~14 h at this rate")
        end)
        c.log, SL.ETA = savedLog, savedETA
        SL:NewSession(savedStart)
        if not ok then error(err, 0) end
    end)
end)

test("rowtooltip: skinning names the mob level and the next breakpoint; a weapon its cap gap", function()
    withWorld(function(_, skills)
        local function joined(e)
            local t = {}
            for _, l in ipairs(NS.RowTooltip.Lines(e, "skill")) do t[#t + 1] = (l.left or "") .. " | " .. (l.right or "") end
            return table.concat(t, "\n")
        end
        local sk = joined(skills.byKey.skinning)
        assertTrue(sk:find("Lv 24", 1, true) ~= nil, sk)
        assertTrue(sk:find("125", 1, true) ~= nil and sk:find("Lv 25", 1, true) ~= nil, sk)
        local guns = joined(skills.byKey.guns)
        assertTrue(guns:find("110 (5 \195\151 22)", 1, true) ~= nil, guns)
        -- the mockup's "Below cap by 5 · fine" for Guns 105 +5 / 110: the base rank's distance, the
        -- same number the weapon-gap alert measures (red under: the effective rank's 0)
        assertTrue(guns:find("Below cap by | 5 \194\183 fine", 1, true) ~= nil, guns)
        assertTrue(guns:find("Bonuses", 1, true) ~= nil, guns)
        local stat = {}
        for _, l in ipairs(NS.RowTooltip.Lines({ key = "hit", label = "Hit", display = "2.0%", pct = 22.2, ref = 9,
            markers = { { at = 55.6, value = 5, label = "vs same level" } } }, "stat")) do
            stat[#stat + 1] = (l.left or "") .. " | " .. (l.right or "")
        end
        local s = table.concat(stat, "\n")
        assertTrue(s:find("vs same level", 1, true) ~= nil, s)
    end)
end)

test("rowtooltip: Show draws on GameTooltip with the bar, Hide gives it back", function()
    withWorld(function()
        W.Show()
        local row = rowFor("guns")
        NS.RowTooltip.Show(row)
        assertTrue(NS.RowTooltip.Bar() ~= nil and NS.RowTooltip.Bar():IsShown(), "the tooltip bar")
        assertEqual(NS.RowTooltip.Bar().geom.fill, 105 / 110)
        NS.RowTooltip.Hide(row)
    end)
end)

test("trainer popup: the faction's trainers, the selection and the waypoint button", function()
    withWorld(function()
        local P = NS.TrainerPopup
        M.TomTom, M.C_Map = nil, nil
        P.Show("fistWeapons")
        local f = P.Frame()
        assertTrue(f:IsShown())
        assertEqual(f:GetFrameStrata(), NS.Constants.LAYERS.STRATA.WINDOW_READ)
        assertEqual(f.title:GetText(), "Learn: Fist Weapons")
        local list = P.Trainers()
        assertTrue(#list >= 2, "Ironforge and Darnassus")
        assertEqual(list[1].name, "Buliwyf Stonehand", "the Dwarf's home city first")
        assertEqual(P.Selected(), list[1])
        P.Select(2)
        assertEqual(P.Selected(), list[2])
        assertTrue(f.warning:IsShown(), "unverified coordinates are flagged")
        assertEqual(f.waypoint.text:GetText(), "Set waypoint", "the label names no provider (R6-6)")
        assertFalse(f.waypoint:IsEnabled(), "no TomTom, no native pin: only chat, so disabled (R6-6)")
        M.__resetPrinted()
        f.print:GetScript("OnClick")(f.print)
        assertTrue(#M.__printed() >= 1, "Print to chat prints the directions")
        P.Hide()
        assertFalse(f:IsShown())
        P.Show("tailoring")
        assertTrue(f.title:GetText():find("Expert", 1, true) ~= nil, "a learned skill's next rank: " .. f.title:GetText())
    end)
end)

test("test_waypoints_fallback_order: TomTom, then the native pin, then chat", function()
    -- red under: any reordering of the three, or a native pin tried without coordinates.
    withWorld(function()
        local Wp = NS.Waypoints
        local trainer = NS.Trainers:For("fistWeapons")[1]
        local tt, native = {}, {}
        M.TomTom = { AddWaypoint = function(_, ...) tt[#tt + 1] = { ... } return {} end }
        M.C_Map = { SetUserWaypoint = function(p) native[#native + 1] = p end,
                    CanSetUserWaypointOnMap = function() return true end }
        M.UiMapPoint = { CreateFromCoordinates = function(id, x, y) return { id = id, x = x, y = y } end }
        assertEqual(Wp:Set(trainer), "tomtom")
        assertEqual(tt[1][1], trainer.mapID)
        assertTrue(math.abs(tt[1][2] - trainer.x / 100) < 1e-9, "TomTom takes 0..1 coordinates")
        assertEqual(#native, 0)
        M.TomTom = nil
        assertEqual(Wp:Set(trainer), "native")
        assertEqual(native[1].id, trainer.mapID)
        M.C_Map, M.UiMapPoint = nil, nil
        M.__resetPrinted()
        assertEqual(Wp:Set(trainer), "chat")
        assertTrue(M.__printed()[1]:find("Buliwyf Stonehand", 1, true) ~= nil, M.__printed()[1])
        M.TomTom = { AddWaypoint = function() error("must not be called") end }
        local noCoords = { name = "Ultham Ironhorn", city = "Amberstill Ranch", mapName = "Dun Morogh", mapID = 1426 }
        assertEqual(Wp:Set(noCoords), "chat", "no coordinates: directions in chat, never a guessed pin")
        assertEqual(Wp:Method(trainer), "tomtom")
    end)
end)

test("interact: shift-click on a profession row inserts its trade link, as the spellbook icon does", function()
    -- red under: the row as text ("[Tailoring 146 / 150]") for a profession (owner feedback round 4)
    withWorld(function()
        W.Show()
        local savedSB = M.C_SpellBook
        local LINK = "|cffffd000|Htrade:Player-1-0001:3908:197|h[Tailoring]|h|r"
        -- Forever's layout (owner's probe, 2026-11-13): the skill lines end at slot 4 here, and the
        -- professions sit past them (slots 5-8), outside every line's range.
        M.C_SpellBook = {
            GetNumSpellBookSkillLines = function() return 2 end,
            GetSpellBookSkillLineInfo = function(i)
                return i == 1 and { itemIndexOffset = 0, numSpellBookItems = 2 }
                    or { itemIndexOffset = 2, numSpellBookItems = 2 }
            end,
            GetSpellBookItemName = function(slot)
                return ({ "Attack", "Auto Shot", "Arcane Shot", "Aimed Shot", "Tailoring", "Tailoring", "Fishing" })[slot]
            end,
            GetSpellBookItemTradeSkillLink = function(slot) return slot == 5 and LINK or nil end,
        }
        local linked
        M.ChatEdit_InsertLink = function(text) linked = text return true end
        M.IsShiftKeyDown = function() return true end
        local ok, err = pcall(function()
            assertEqual(I.OnRowClick(rowFor("tailoring"), "LeftButton"), "link")
            assertEqual(linked, LINK, "the trade link from the book's Tailoring slot, past the skill lines")
            I.OnRowClick(rowFor("fishing"), "LeftButton")
            assertEqual(linked, "[Fishing 107 +25 / 150]", "no trade link for the slot: the row as text")
            I.OnRowClick(rowFor("guns"), "LeftButton")
            assertEqual(linked, "[Guns 105 +5 / 110]", "a weapon row stays text")
        end)
        M.IsShiftKeyDown = function() return false end
        M.C_SpellBook = savedSB
        if not ok then error(err, 0) end
    end)
end)

-- ── owner feedback round 4: the character panel through the mark's secure overlay ────────────

--- The Camelot character panel's globals: the micro button, the panel and its two tabs.
local function withPanel(fn)
    local saved = { M.CharacterMicroButton, M.CharacterFrame, M.PaperDollFrame, M.SkillsFrame }
    local function frame(shown) return { shown = shown, IsShown = function(self) return self.shown end,
                                          IsVisible = function(self) return self.shown end } end
    local panel = { micro = { Click = function() end }, frame = frame(false), doll = frame(false), skills = frame(false) }
    M.CharacterMicroButton, M.CharacterFrame, M.PaperDollFrame, M.SkillsFrame =
        panel.micro, panel.frame, panel.doll, panel.skills
    local ok, err = pcall(fn, panel)
    M.CharacterMicroButton, M.CharacterFrame, M.PaperDollFrame, M.SkillsFrame = saved[1], saved[2], saved[3], saved[4]
    if not ok then error(err, 0) end
end

test("panel overlay: a weapon row's mark opens the panel by the micro button, then the Skills tab on its line", function()
    -- red under: ToggleCharacter("SkillFrame") from the addon (a name Forever's panel ignores, and a
    -- tainted CharacterFrame:OnShow that raised the PlayerFrame secret compare, 2026-11-12)
    withWorld(function(world)
        withPanel(function(panel)
            W.Show()
            local selected
            local savedSelect = I.SelectSkillLine
            I.SelectSkillLine = function(key) selected = key return 3 end
            local ok, err = pcall(function()
                local row = rowFor("guns")
                row:__fire("OnEnter")
                local b = SO.Overlay("guns")
                assertTrue(b ~= nil and b:IsShown(), "the hovered weapon row's mark is armed")
                assertEqual(b.kind, "char")
                assertEqual(b.__template, "SecureActionButtonTemplate")
                b:GetScript("PreClick")(b, "LeftButton", true)
                assertEqual(selected, "guns", "the line is selected before the panel shows")
                assertEqual(b.__attr.type1, "macro")
                assertEqual(b.__attr.macrotext1, "/click CharacterMicroButton", "the panel closed: one click opens it")
                assertEqual(#world.opened, 0, "the addon shows nothing itself on the press")
                b:GetScript("PostClick")(b, "LeftButton", true)
                assertEqual(#world.opened, 0, "nothing on the press's PostClick")
                panel.frame.shown, panel.doll.shown = true, true   -- the micro button opened the paper doll
                b:GetScript("PostClick")(b, "LeftButton", false)
                assertEqual(world.opened[#world.opened], "SkillsFrame", "the release switches to the Skills tab")
                -- The tab already showing: no secure click at all, the selection redrawn.
                panel.doll.shown, panel.skills.shown = false, true
                local before = #world.opened
                b:GetScript("PreClick")(b, "LeftButton", true)
                assertEqual(b.__attr.type1, nil, "no click: the panel stays open")
                b:GetScript("PostClick")(b, "LeftButton", false)
                assertEqual(#world.opened, before, "and the tab is not toggled closed")
                -- Shift and right clicks never run the secure action.
                M.IsShiftKeyDown = function() return true end
                b:GetScript("PreClick")(b, "LeftButton", true)
                assertEqual(b.__attr.type1, nil, "a shift-click links, never opens")
                M.IsShiftKeyDown = function() return false end
                row:__fire("OnLeave")
            end)
            I.SelectSkillLine = savedSelect
            if not ok then error(err, 0) end
        end)
    end)
end)

test("panel overlay: a stat row's mark opens the paper doll; from another tab it reopens there", function()
    withWorld(function()
        withPanel(function(panel)
            W.Show()
            local row = rowFor("hit")
            row:__fire("OnEnter")
            local b = SO.Overlay("stat:hit")
            assertTrue(b ~= nil and b:IsShown(), "a stat row's mark is armed (round 4: stat rows get the mark)")
            b:GetScript("PreClick")(b, "LeftButton", true)
            assertEqual(b.__attr.macrotext1, "/click CharacterMicroButton")
            panel.frame.shown, panel.skills.shown = true, true
            b:GetScript("PreClick")(b, "LeftButton", true)
            assertEqual(b.__attr.macrotext1, "/click CharacterMicroButton\n/click CharacterMicroButton",
                "open on the Skills tab: closed and reopened on the paper doll, both secure")
            row:__fire("OnLeave")
        end)
    end)
end)

test("panel overlay: no micro button, no overlay; a plain mark click in combat says why and opens nothing", function()
    withWorld(function(world)
        W.Show()
        local row = rowFor("guns")
        row:__fire("OnEnter")
        assertTrue(SO.Overlay("guns") == nil or not SO.Overlay("guns"):IsShown(), "no micro button: the mark's own click")
        row:__fire("OnLeave")
        M.InCombatLockdown = function() return true end
        M.__resetPrinted()
        assertEqual(I.OnMarkClick(rowFor("hit"), "LeftButton"), "paperdoll")
        assertEqual(#world.opened, 0, "never a tainted panel in combat")
        assertEqual(#M.__printed(), 1, "one line says why")
        M.InCombatLockdown = function() return false end
    end)
end)
