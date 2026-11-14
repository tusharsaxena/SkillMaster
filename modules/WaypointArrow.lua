local _, NS = ...
-- modules/WaypointArrow.lua — Skill Master's waypoint arrow, on LibKa0s-WaypointArrow-1.0 (owner
-- feedback round 8, R8-5; the arrow itself was round 6's R6-11). A trainer's native map pin
-- (NS.Waypoints) is not super-tracked, so the client's own arrow stays away, and the library's
-- small movable frame points the way instead, with the distance under it. This file is the thin
-- adapter: the trainer it points at, the settings paths it is configured from, test mode's sample,
-- the profile reload, the native pin it clears and watches, the tooltip and the right-click menu's
-- Skill Master items.
--
-- NS.WaypointArrow.Show(trainer) / .Hide() / .Clear() / .IsShown() / .Frame() / .Target() /
-- .Wanted() / .Update() / .ShowTest() / .HideTest() / .ApplySettings() / .OnWaypointUpdated() /
-- .StandDown() / .Instance() / .ResetPosition() / .OpenSettings() / .ShowTrainers() / .HideArrow() /
-- .TrainerKey(); .PATHS and .SettingsRows(opts) for settings/Trainers.lua.
--
-- What the library owns: the frame (never secure, so it stays shown in combat), the five looks
-- (Flat, Ridge, Raised, Faceted, On the ground), the rotation and its secret-value guards, the
-- distance fade between the far and near colors (the skin's accent and sem.good while "Use the
-- skin's colors" is on), the distance text in the player's font on any side (round 9, R9-1/R9-3:
-- the trainer's name as its optional second line, yards or compact units in Skill Master's words),
-- the scale, the drag (which writes waypoints.arrowX / arrowY through NS.SetByPath, architecture-§5)
-- and the arrow's own lock, and the right-click menu (round 9, R9-2: the library's Clear waypoint,
-- Share in chat, Show on map, Lock / Unlock and Reset position, with Skill Master's Show trainers,
-- Arrow settings... and Hide arrow added here). Within 5 yards it calls onArrive: the native pin is
-- cleared and chat says so. /sm lock no longer holds the arrow: its own Lock does (round 9).
--
-- Without the library major (LibKa0s absent or older than the arrow) Wanted() answers false, so a
-- map pin is super-tracked and the client's own arrow points: the behavior before R6-11.

NS.WaypointArrow = {}
local WA = NS.WaypointArrow
local L = NS.L
local LAYERS = NS.Constants.LAYERS

local Arrow = LibStub and LibStub("LibKa0s-WaypointArrow-1.0", true)
WA.lib = Arrow

WA.FRAME_NAME = "SkillMasterWaypointArrow"
--- Seconds between two measures while the arrow is shown (the library's throttle).
WA.THROTTLE = Arrow and Arrow.THROTTLE or 0.03

--- The profile paths the arrow's settings live at; settings/Trainers.lua hands them to the
--- library's settings block, and ApplySettings configures the instance from them.
WA.PATHS = {
    style = "waypoints.arrowStyle",
    useSkinColors = "waypoints.arrowSkinColors",
    farColor = "waypoints.arrowFar",
    nearColor = "waypoints.arrowNear",
    scale = "waypoints.arrowScale",
    -- Round 9, R9-1: the Text block ("Use the skin's font" sits at font .. "FromSkin") and the
    -- Position block with the arrow's own lock.
    font = "waypoints.arrowFont",
    fontSize = "waypoints.arrowFontSize",
    fontColor = "waypoints.arrowFontColor",
    useClassColorFont = "waypoints.arrowFontClass",
    fontFlags = "waypoints.arrowFontFlags",
    fontShadow = "waypoints.arrowFontShadow",
    textPosition = "waypoints.arrowTextPosition",
    showLabel = "waypoints.arrowShowLabel",
    distanceUnits = "waypoints.arrowUnits",
    x = "waypoints.arrowX",
    y = "waypoints.arrowY",
    lock = "waypoints.arrowLock",
}

--- The settings page the menu's Arrow settings... opens (settings/Trainers.lua's).
WA.SETTINGS_PAGE = "trainers"

local inst
-- target: the trainer pointed at; test: test mode's sample on show (the real target, if any,
-- waits under it, which the library keeps); key: the skill whose trainer popup set the waypoint
-- (the menu's Show trainers reopens it).
local state = { target = nil, test = nil, key = nil }

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) and true or false end

local function profile()
    return (NS.db and NS.db.profile.waypoints) or NS.defaults.profile.waypoints
end

local function get(path)
    local node = (NS.db and NS.db.profile) or NS.defaults.profile
    for seg in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[seg]
    end
    return node
end

--- Whether a native pin comes with this arrow: Show Skill Master's arrow on, and the library there.
function WA.Wanted()
    return Arrow ~= nil and profile().arrow ~= false
end

-- ---------------------------------------------------------------------------------------------
-- The native pin
-- ---------------------------------------------------------------------------------------------

local function clearNativePin()
    if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
        pcall(C_Map.ClearUserWaypoint)
    end
end

-- ---------------------------------------------------------------------------------------------
-- The host callbacks
-- ---------------------------------------------------------------------------------------------

local function tipLine(s, token)
    local c = NS.Bar.Color(token) or NS.Bar.Color("text.body") or { 1, 1, 1 }
    GameTooltip:AddLine(s, c[1], c[2], c[3], true)
end

local function placeText(t)
    local where = NS.Rows.Place(t)
    if t.subzone and t.subzone ~= where then where = where .. ", " .. t.subzone end
    return where
end

--- The trainer the arrow points at (test mode's sample while it shows), or nil.
function WA.Target() return state.test or state.target end

local function onEnter(f)
    local t = WA.Target()
    if not (GameTooltip and t) then return end
    GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
    tipLine(t.name, "text.accent")
    tipLine(placeText(t), "text.body")
    local locked = inst ~= nil and inst:IsLocked()
    tipLine(locked and L["Right-click for options."] or L["Right-click for options. Drag to move the arrow."],
        "text.muted")
    GameTooltip:Show()
end

local function onLeave(f)
    if GameTooltip and GameTooltip:IsOwned(f) then GameTooltip:Hide() end
end

-- Without the Widgets major (no menu) a right-click still clears, as before round 9.
local function onClick(_, button)
    if button == "RightButton" then WA.Clear() end
end

-- The library writes a drag's offsets, the lock and Reset position here: the settings seam. The
-- write came from no settings widget, so the open panel's widgets (the Position sliders, the Lock
-- toggle) re-read their values here, as a widget's own set() would have them do.
local function setSetting(path, value)
    if NS.SetByPath then NS.SetByPath(path, value) end
    local H = NS.Helpers
    if type(H) == "table" and type(H.RefreshScalars) == "function" then H.RefreshScalars() end
end

-- Arrived: the library has already forgotten the target and hidden the frame.
local function onArrive()
    local t = state.target
    state.target = nil
    clearNativePin()
    if t then NS.Print(L["You have arrived: %s"]:format(t.name)) end
end

-- The library's words, keyed as its STRINGS (round 9, R9-2/R9-3): the distance in both units, the
-- sample's fallback label and the menu.
local ARROW_STRINGS = {
    DISTANCE = L["%d yd"], DISTANCE_COMPACT = L["%.1fk yd"], SAMPLE = L["Waypoint"],
    MENU_CLEAR = L["Clear waypoint"], MENU_SHARE = L["Share in chat"], MENU_MAP = L["Show on map"],
    MENU_LOCK = L["Lock the arrow"], MENU_UNLOCK = L["Unlock the arrow"], MENU_RESET = L["Reset position"],
    MENU_SHARE_TIP = L["Opens the chat box with a /way line for this waypoint. Press Enter to send it to the channel the box is set to, or edit it first. Nothing is sent until you do."],
    MENU_NO_MAP = L["This waypoint has no map point to share or show."],
    MENU_COMBAT = L["Not available in combat."],
}

-- The position of the stock item `id` in `items`, or nil.
local function indexOf(items, id)
    for i, row in ipairs(items) do if row.id == id then return i end end
    return nil
end

-- The menu's rows: the library's, with Show trainers after Show on map and Arrow settings... and
-- Hide arrow last (the owner's order, round 9). `target` is the library's: nil under test mode's
-- sample (or with no target), where Show trainers is off as the library's Show on map is; Arrow
-- settings... is off in combat, where the options library refuses to open the panel.
local function menuItems(items, target)
    local key = target ~= nil and WA.TrainerKey() or nil
    table.insert(items, (indexOf(items, "map") or #items) + 1, {
        id = "trainers", label = L["Show trainers"], disabled = key == nil,
        tooltip = L["Open Skill Master's trainer popup for this trainer's skill."],
        onClick = function() WA.ShowTrainers() end })
    local combat = InCombatLockdown and InCombatLockdown() or false
    items[#items + 1] = { id = "settings", label = L["Arrow settings..."], disabled = combat,
        tooltip = combat and L["Not available in combat."]
            or L["Open Trainers and Waypoints, where the arrow's look, text and position are set."],
        onClick = function() WA.OpenSettings() end }
    items[#items + 1] = { id = "hide", label = L["Hide arrow"],
        tooltip = L["Turn off Show Skill Master's arrow: the game's own arrow points to the map pin. Trainers and Waypoints turns it back on."],
        onClick = function() WA.HideArrow() end }
    return items
end

--- The library instance, built on first use (nil without the library).
function WA.Instance()
    if inst or not Arrow then return inst end
    inst = Arrow:New({
        addon = NS.name, name = WA.FRAME_NAME, strata = LAYERS.STRATA.HUD, skin = NS.name,
        -- Round 9, R9-1: the drag, the lock and Reset position write the settings paths; the
        -- arrow's own Lock is its one drag gate (no canDrag: /sm lock is the windows').
        paths = WA.PATHS, set = setSetting,
        onClick = onClick, onEnter = onEnter, onLeave = onLeave, onArrive = onArrive,
        onClear = function() WA.Clear() end, onSampleClear = function() WA.Clear() end,
        menuItems = menuItems, strings = ARROW_STRINGS,
        debug = function(_, msg) if NS.Debug then NS.Debug("Arrow", "%s", tostring(msg)) end end,
    })
    inst:ConfigureFrom(get, WA.PATHS)
    return inst
end

--- The library's frame, or nil before the arrow was first shown (or without the library).
function WA.Frame()
    local a = inst
    return a and a:Frame() or nil
end

function WA.IsShown() return inst ~= nil and inst:IsShown() end

--- One measure now (a shown arrow measures on its own every THROTTLE seconds).
function WA.Update() if inst then inst:Update() end end

-- The profile's settings (the position among them) onto the instance, before it shows.
local function configure(a)
    a:ConfigureFrom(get, WA.PATHS)
end

-- ---------------------------------------------------------------------------------------------
-- Show, hide, clear
-- ---------------------------------------------------------------------------------------------

local function spec(t)
    return { mapID = t.mapID, x = t.x / 100, y = t.y / 100, label = t.name }
end

-- The skill the menu's Show trainers opens for `t`: the open trainer popup's when it lists `t`
-- (its Set waypoint set this one), else the first skill `t` teaches.
local function keyFor(t)
    local P = NS.TrainerPopup
    if P and P.IsShown() and P.Key then
        for _, row in ipairs(P.Trainers() or {}) do
            if row == t then return P.Key() end
        end
    end
    return type(t.teaches) == "table" and t.teaches[1] or nil
end

--- The skill key the menu's Show trainers opens the trainer popup on, or nil.
function WA.TrainerKey()
    local t = WA.Target()
    if not t then return nil end
    if t == state.target and state.key then return state.key end
    return keyFor(t)
end

--- Point the arrow at trainer `t` (its native pin was just set), retargeting a shown arrow.
function WA.Show(t)
    if not (t and t.mapID and t.x and t.y) then return end
    local a = WA.Instance()
    if not a then return end
    state.target, state.key = t, keyFor(t)
    configure(a)
    a:SetTarget(spec(t))
end

--- Hide the arrow and forget the target (the native pin, if any, stays). Test mode's sample stays
--- until test mode ends.
function WA.Hide()
    state.target, state.key = nil, nil
    if inst then inst:Clear() end
end

--- The menu's Clear waypoint (and a right-click without the menu): the waypoint goes, the native
--- pin with it, and the arrow hides. In test mode the sample only goes (no pin was set for it): a
--- real waypoint under it is pointed at again.
function WA.Clear()
    if state.test then return WA.HideTest() end
    if state.target then clearNativePin() end
    WA.Hide()
end

--- Test mode (preview-mode): the arrow on a sample trainer, at the library's sample distance and
--- angle. Nothing is written. Shown only where a real pin would show it (Show Skill Master's arrow on).
function WA.ShowTest()
    if not WA.Wanted() then return end
    local sample
    for _, t in ipairs(NS.Trainers:For("swords") or {}) do
        if t.mapID and t.x and t.y then sample = t break end
    end
    if not sample then return end
    local a = WA.Instance()
    state.test = sample
    configure(a)
    a:ShowSample(sample.name)
end

--- Test mode ended: the sample goes; a real waypoint set before it is pointed at again.
function WA.HideTest()
    if not state.test then return end
    state.test = nil
    if not inst then return end
    if state.target and not WA.Wanted() then inst:Clear() end
    inst:HideSample()
end

--- A settings row, and a profile switch, copy or reset: the look, text, scale and position apply
--- at once; the arrow off hides it and hands the live native pin back to the client's
--- own arrow (the old behavior).
function WA.ApplySettings()
    if inst then configure(inst) end
    if WA.Wanted() then return end
    local had = state.target ~= nil
    state.test = nil
    WA.Hide()
    if inst then inst:HideSample() end
    if had and type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
end

--- The menu's and the settings page's Reset position: the default offsets, written through the
--- settings seam by the library.
function WA.ResetPosition()
    local a = WA.Instance()
    if a then a:ResetPosition() end
end

--- The menu's Arrow settings...: the Trainers and Waypoints page, where the Waypoint arrow, Arrow
--- text and Arrow position subgroups sit (the options library's page opener, else the main panel).
function WA.OpenSettings()
    local H = NS.Helpers
    if type(H) == "table" and type(H.OpenOptionsPanel) == "function" then
        return H.OpenOptionsPanel(WA.SETTINGS_PAGE)
    end
    if type(NS.OpenOptionsPanel) == "function" then return NS.OpenOptionsPanel() end
    return nil
end

--- The menu's Show trainers: Skill Master's trainer popup on the target trainer's skill.
function WA.ShowTrainers()
    local key = WA.TrainerKey()
    if key and NS.TrainerPopup then NS.TrainerPopup.Show(key) end
end

--- The menu's Hide arrow: Show Skill Master's arrow off, through its setting, whose change hides
--- the arrow and hands the map pin to the game's own arrow.
function WA.HideArrow()
    setSetting("waypoints.arrow", false)
end

--- The library's settings blocks (the look; round 9, the Text and Position blocks) at WA.PATHS,
--- each row's change re-applying the settings, composed by Skill Master's options instance
--- (`opts.options`, NS.Helpers by default). Answers the rows and the afterSubgroup hooks (the
--- Position block's Reset position button); `{}, {}` without the library. `opts` carries page,
--- group, subgroup, textSubgroup, positionSubgroup and L as the library takes them.
function WA.SettingsRows(opts)
    if not (Arrow and type(Arrow.SettingsRows) == "function") then return {}, {} end
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.paths = WA.PATHS
    if o.options == nil then o.options = NS.Helpers end
    o.onChange = function() WA.ApplySettings() end
    o.onResetPosition = function() WA.ResetPosition() end
    local rows, hooks = Arrow.SettingsRows(o)
    return rows, hooks or {}
end

-- ---------------------------------------------------------------------------------------------
-- The native pin's own changes
-- ---------------------------------------------------------------------------------------------

-- A world position { instance, x, y } from a map point, or nil.
local function world(mapID, x, y)
    local instance, wx, wy = NS.Compat.MapWorldPos(mapID, x, y)
    if instance == nil then return nil end
    return { instance, wx, wy }
end

-- The native pin's place in world yards, or nil when the client cannot say.
local function pinWorld()
    if type(C_Map.GetUserWaypoint) ~= "function" then return nil end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or isSecret(point) or type(point) ~= "table" then return nil end
    local pos = point.position
    if isSecret(pos) or type(pos) ~= "table" then return nil end
    local x, y = pos.x, pos.y
    if type(pos.GetXY) == "function" then
        local okXY, gx, gy = pcall(pos.GetXY, pos)
        if okXY then x, y = gx, gy end
    end
    return world(point.uiMapID, x, y)
end

--- USER_WAYPOINT_UPDATED: the native pin was cleared, or replaced elsewhere (the world map's own
--- pin), so the arrow hides. A pin whose place the client cannot say keeps the arrow.
function WA.OnWaypointUpdated()
    local t = state.target
    if not t or type(C_Map) ~= "table" then return end
    if type(C_Map.HasUserWaypoint) == "function" then
        local ok, has = pcall(C_Map.HasUserWaypoint)
        if ok and has == false then return WA.Hide() end
    end
    local pin, w = pinWorld(), world(t.mapID, t.x / 100, t.y / 100)
    if pin and w then
        local d = NS.Trainers.Distance(pin, w)
        if d == nil or d > 2 then WA.Hide() end
    end
end

--- The stand-down: the arrow and test mode's sample come down; nothing waits.
function WA.StandDown()
    state.test = nil
    WA.Hide()
    if inst then inst:HideSample() end
end

-- A tracked bus target: the stand-down takes it down and the stand-up replays it.
WA.events = NS.NewBusTarget()
if WA.events then
    NS.SafeRegisterEvent(WA.events, "USER_WAYPOINT_UPDATED", function() WA.OnWaypointUpdated() end, NS.rejectedEvents)
end
