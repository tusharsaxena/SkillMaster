local _, NS = ...
-- modules/WaypointArrow.lua — Skill Master's waypoint arrow, on LibKa0s-WaypointArrow-1.0 (owner
-- feedback round 8, R8-5; the arrow itself was round 6's R6-11). A trainer's native map pin
-- (NS.Waypoints) is not super-tracked, so the client's own arrow stays away, and the library's
-- small movable frame points the way instead, with the distance under it. This file is the thin
-- adapter: the trainer it points at, the settings paths it is configured from, test mode's sample,
-- the profile reload, the native pin it clears and watches, and the tooltip and right-click.
--
-- NS.WaypointArrow.Show(trainer) / .Hide() / .Clear() / .IsShown() / .Frame() / .Target() /
-- .Wanted() / .Update() / .ShowTest() / .HideTest() / .ApplySettings() / .OnWaypointUpdated() /
-- .StandDown() / .Instance(); .PATHS and .SettingsRows(opts) for settings/Trainers.lua.
--
-- What the library owns: the frame (never secure, so it stays shown in combat), the five looks
-- (Flat, Ridge, Raised, Faceted, On the ground), the rotation and its secret-value guards, the
-- distance fade between the far and near colors (the skin's accent and sem.good while "Use the
-- skin's colors" is on), the distance text, the scale and the drag, whose point it hands back here
-- to persist (waypoints.arrowFrame.point). Within 5 yards it calls onArrive: the native pin is
-- cleared and chat says so.
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
}

local inst
-- target: the trainer pointed at; test: test mode's sample on show (the real target, if any,
-- waits under it, which the library keeps).
local state = { target = nil, test = nil }

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

local function savedPoint()
    local saved = profile().arrowFrame
    local p = type(saved) == "table" and saved.point
    return type(p) == "table" and p or nil
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
    tipLine(L["Right-click to clear the waypoint. Drag to move the arrow."], "text.muted")
    GameTooltip:Show()
end

local function onLeave(f)
    if GameTooltip and GameTooltip:IsOwned(f) then GameTooltip:Hide() end
end

local function onClick(_, button)
    if button == "RightButton" then WA.Clear() end
end

-- A drag ended: the point on the profile. Named non-setting state, this module its one writer
-- (docs/ARCHITECTURE.md). A reset (nil) puts the default back.
local function onMoved(point)
    if not NS.db then return end
    local wp = NS.db.profile.waypoints
    wp.arrowFrame = type(wp.arrowFrame) == "table" and wp.arrowFrame or {}
    wp.arrowFrame.point = point or false
end

-- Arrived: the library has already forgotten the target and hidden the frame.
local function onArrive()
    local t = state.target
    state.target = nil
    clearNativePin()
    if t then NS.Print(L["You have arrived: %s"]:format(t.name)) end
end

--- The library instance, built on first use (nil without the library).
function WA.Instance()
    if inst or not Arrow then return inst end
    inst = Arrow:New({
        addon = NS.name, name = WA.FRAME_NAME, strata = LAYERS.STRATA.HUD, skin = NS.name,
        point = savedPoint(),
        onMoved = onMoved,
        canDrag = function() return not (NS.GetSetting and NS.GetSetting("locked")) end,   -- /sm lock
        onClick = onClick, onEnter = onEnter, onLeave = onLeave, onArrive = onArrive,
        format = function(yards) return L["%d yd"]:format(math.floor(yards + 0.5)) end,
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

-- The profile's settings and point onto the instance, before it shows.
local function configure(a)
    a:ConfigureFrom(get, WA.PATHS)
    a:SetPosition(savedPoint())
end

-- ---------------------------------------------------------------------------------------------
-- Show, hide, clear
-- ---------------------------------------------------------------------------------------------

local function spec(t)
    return { mapID = t.mapID, x = t.x / 100, y = t.y / 100, label = t.name }
end

--- Point the arrow at trainer `t` (its native pin was just set), retargeting a shown arrow.
function WA.Show(t)
    if not (t and t.mapID and t.x and t.y) then return end
    local a = WA.Instance()
    if not a then return end
    state.target = t
    configure(a)
    a:SetTarget(spec(t))
end

--- Hide the arrow and forget the target (the native pin, if any, stays). Test mode's sample stays
--- until test mode ends.
function WA.Hide()
    state.target = nil
    if inst then inst:Clear() end
end

--- Right-click: the waypoint goes, the native pin with it, and the arrow hides. In test mode the
--- sample only goes (no pin was set for it): a real waypoint under it is pointed at again.
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

--- A settings row, and a profile switch, copy or reset: the style, colors and scale (and the saved
--- point) apply at once; the arrow off hides it and hands the live native pin back to the client's
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

--- The library's settings block (style, the skin's colors, far, near, scale) at WA.PATHS, each
--- row's change re-applying the settings; no rows without the library. `opts` carries page,
--- group, subgroup and L as the library takes them.
function WA.SettingsRows(opts)
    if not (Arrow and type(Arrow.SettingsRows) == "function") then return {} end
    local o = {}
    for k, v in pairs(opts or {}) do o[k] = v end
    o.paths = WA.PATHS
    o.onChange = function() WA.ApplySettings() end
    return Arrow.SettingsRows(o)
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
