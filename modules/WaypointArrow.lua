local _, NS = ...
-- modules/WaypointArrow.lua — Skill Master's own waypoint arrow (owner feedback round 6, R6-11;
-- mockup A, the solid chevron): a trainer's native map pin (NS.Waypoints) is no longer
-- super-tracked, so the client's own arrow stays away, and this small movable frame points the way
-- instead, with the distance under it. Shown whenever Show Skill Master's arrow is on: no other
-- addon's arrow is looked for (owner feedback round 7, R7-7, TomTom support removed).
--
-- NS.WaypointArrow.Show(trainer) / .Hide() / .Clear() / .IsShown() / .Frame() / .Target() /
-- .Wanted() / .Update() / .ShowTest() / .HideTest() / .ApplySettings() / .OnWaypointUpdated() /
-- .StandDown(); the pure math .Rotation(px, py, tx, ty, facing) and .Blend(yards).
--
-- Geometry. WoW world coordinates: x points north, y points west (NS.Compat.MapWorldPos's two
-- yards). GetPlayerFacing() is radians counter-clockwise from north. The bearing to the target,
-- measured the same way, is atan2(ty - py, tx - px): +y is west, so a target due west is +pi/2.
-- The arrow's rotation is bearing - facing, and Texture:SetRotation turns counter-clockwise for a
-- positive angle: the chevron's tip, drawn pointing up (straight ahead), turns towards the target.
--
-- Guards. GetPlayerFacing can answer nil or a secret value (instances, some indoor places) and the
-- positions can be secret or unknown (NS.Compat answers nil then): with no facing the art hides and
-- the distance stays; with no distance (another continent, an instance) the trainer's name shows
-- alone, dim. Within WA.ARRIVE yards the arrow hides, the native pin is cleared and chat says so.
--
-- The color: the skin's accent at WA.FAR yards or more, its sem.good at WA.NEAR or less, a linear
-- blend between; the outline in the skin's bar.border. Never secure: it stays shown in combat.

NS.WaypointArrow = {}
local WA = NS.WaypointArrow
local L = NS.L
local LAYERS = NS.Constants.LAYERS

WA.FRAME_NAME = "SkillMasterWaypointArrow"
--- Seconds between two measures while the arrow is shown (its OnUpdate runs only then).
WA.THROTTLE = 0.03
--- Yards: arrival, the near color's edge and the far color's edge.
WA.ARRIVE, WA.NEAR, WA.FAR = 5, 30, 300
--- The chevron's drawn size, px (the art is 64x64 texels).
WA.ART = 48
--- Test mode's sample: the distance, yards, and the rotation, radians (35 degrees to the left).
WA.SAMPLE_YARDS, WA.SAMPLE_ROTATION = 240, math.rad(35)

local MEDIA = "Interface\\AddOns\\SkillMaster\\media\\waypoint\\"
WA.FILL_TEXTURE, WA.OUTLINE_TEXTURE = MEDIA .. "arrow-fill.tga", MEDIA .. "arrow-outline.tga"

local frame
-- target: the trainer pointed at; world: its world position, once measured (static, so kept);
-- test: test mode's sample on show (the real target, if any, waits under it).
local state = { target = nil, world = nil, test = nil, elapsed = 0 }

function WA.Frame() return frame end
function WA.IsShown() return frame ~= nil and frame:IsShown() == true end
--- The trainer the arrow points at (test mode's sample while it shows), or nil.
function WA.Target() return state.test or state.target end

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) and true or false end
local function plainNumber(v) return not isSecret(v) and type(v) == "number" end

local function profile()
    return (NS.db and NS.db.profile.waypoints) or NS.defaults.profile.waypoints
end

--- Whether a native pin comes with this arrow: Show Skill Master's arrow on.
function WA.Wanted()
    return profile().arrow ~= false
end

-- ---------------------------------------------------------------------------------------------
-- The pure math
-- ---------------------------------------------------------------------------------------------

--- The arrow's rotation (radians, counter-clockwise) from the player at (px, py) facing `facing`
--- to the target at (tx, ty), world yards (x north, y west); nil when any input is not a plain number.
function WA.Rotation(px, py, tx, ty, facing)
    if not (plainNumber(px) and plainNumber(py) and plainNumber(tx) and plainNumber(ty)
        and plainNumber(facing)) then return nil end
    local bearing = math.atan2(ty - py, tx - px)
    local r = bearing - facing
    -- One turn's range, -pi .. pi, so the same direction always reads the same angle.
    while r > math.pi do r = r - 2 * math.pi end
    while r <= -math.pi do r = r + 2 * math.pi end
    return r
end

--- The fill's color at `yards`: the skin's accent at WA.FAR or more, sem.good at WA.NEAR or less,
--- a linear blend between. { r, g, b, a }.
function WA.Blend(yards)
    local far = NS.Bar.Color("text.accent") or { 1, 1, 1, 1 }
    local near = NS.Bar.Color("sem.good") or far
    local t = 1
    if plainNumber(yards) then t = math.max(0, math.min(1, (yards - WA.NEAR) / (WA.FAR - WA.NEAR))) end
    local out = {}
    for i = 1, 3 do out[i] = near[i] + (far[i] - near[i]) * t end
    out[4] = 1
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The native pin
-- ---------------------------------------------------------------------------------------------

local function clearNativePin()
    if type(C_Map) == "table" and type(C_Map.ClearUserWaypoint) == "function" then
        pcall(C_Map.ClearUserWaypoint)
    end
end

local function targetWorld(t)
    if state.world and state.world.of == t then return state.world end
    if not (t and t.mapID and t.x and t.y) then return nil end
    local instance, x, y = NS.Compat.MapWorldPos(t.mapID, t.x / 100, t.y / 100)
    if instance == nil then return nil end
    state.world = { instance, x, y, of = t }
    return state.world
end

-- ---------------------------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------------------------

local function savePoint()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" or not NS.db then return end
    -- Named non-setting state: this module is its one writer (docs/ARCHITECTURE.md).
    NS.db.profile.waypoints.arrowFrame = NS.db.profile.waypoints.arrowFrame or {}
    NS.db.profile.waypoints.arrowFrame.point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function applyPoint()
    local saved = profile().arrowFrame
    local p = type(saved) == "table" and saved.point
    frame:ClearAllPoints()
    if type(p) == "table" then
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end
end

local function onDragStart(self)
    if NS.GetSetting and NS.GetSetting("locked") then return end   -- the profile's lock (/sm lock)
    self:StartMoving()
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    savePoint()
end

local function tipLine(s, token)
    local c = NS.Bar.Color(token) or NS.Bar.Color("text.body") or { 1, 1, 1 }
    GameTooltip:AddLine(s, c[1], c[2], c[3], true)
end

local function placeText(t)
    local where = NS.Rows.Place(t)
    if t.subzone and t.subzone ~= where then where = where .. ", " .. t.subzone end
    return where
end

local function onEnter(self)
    local t = WA.Target()
    if not (GameTooltip and t) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    tipLine(t.name, "text.accent")
    tipLine(placeText(t), "text.body")
    tipLine(L["Right-click to clear the waypoint. Drag to move the arrow."], "text.muted")
    GameTooltip:Show()
end

local function onLeave(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function onMouseUp(_, button)
    if button == "RightButton" then WA.Clear() end
end

-- Defined below; armed by present(), disarmed by takeDown(). No OnHide disarms it: the client
-- fires OnHide on a shown child when its parent hides (Alt-Z, a cinematic) and none of ours re-arms
-- on the way back, while a hidden frame runs no OnUpdate anyway (R6-11 review).
local onUpdate

local function build()
    frame = CreateFrame("Frame", WA.FRAME_NAME, UIParent)
    frame:SetSize(WA.ART + 16, WA.ART + 22)
    frame:SetFrameStrata(LAYERS.STRATA.HUD)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", onDragStart)
    frame:SetScript("OnDragStop", onDragStop)
    frame:SetScript("OnMouseUp", onMouseUp)
    frame:SetScript("OnEnter", onEnter)
    frame:SetScript("OnLeave", onLeave)
    -- The outline under the fill, one sublevel apart; both white art tinted by SetVertexColor.
    frame.outline = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    frame.outline:SetTexture(WA.OUTLINE_TEXTURE)
    frame.outline:SetSize(WA.ART, WA.ART)
    frame.outline:SetPoint("TOP", frame, "TOP", 0, 0)
    frame.fill = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    frame.fill:SetTexture(WA.FILL_TEXTURE)
    frame.fill:SetSize(WA.ART, WA.ART)
    frame.fill:SetPoint("TOP", frame, "TOP", 0, 0)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.text:SetPoint("TOP", frame.fill, "BOTTOM", 0, -2)
    NS.Skin.Text(frame.text, "body")
    frame.textRole = "body"
    frame:Hide()
end

-- ---------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------

local function paintArt(rotation, yards)
    local shown = rotation ~= nil
    frame.fill:SetShown(shown)
    frame.outline:SetShown(shown)
    if not shown then return end
    frame.fill:SetRotation(rotation)
    frame.outline:SetRotation(rotation)
    local c = WA.Blend(yards)
    frame.fill:SetVertexColor(c[1], c[2], c[3], 1)
    local o = NS.Bar.Color("bar.border") or { 0, 0, 0, 1 }
    frame.outline:SetVertexColor(o[1], o[2], o[3], o[4] or 1)
end

-- The line under the art: the yards in the body role, or with no distance the name alone, dim.
-- The role is painted only when it changes: the skin records each call, and this runs every tick.
local function paintText(t, yards)
    local role = yards and "body" or "muted"
    if frame.textRole ~= role then
        NS.Skin.Text(frame.text, role)
        frame.textRole = role
    end
    frame.text:SetText(yards and L["%d yd"]:format(math.floor(yards + 0.5)) or t.name)
end

local function facing()
    if type(GetPlayerFacing) ~= "function" then return nil end
    local ok, f = pcall(GetPlayerFacing)
    if not ok or not plainNumber(f) then return nil end
    return f
end

--- One measure: the player's place and facing against the target, then the art and the text. In
--- test mode the sample's fixed distance and rotation. Arrival hides the arrow and clears the pin.
function WA.Update()
    if not frame then return end
    if state.test then
        paintArt(WA.SAMPLE_ROTATION, WA.SAMPLE_YARDS)
        paintText(state.test, WA.SAMPLE_YARDS)
        return
    end
    local t = state.target
    if not t then return WA.Hide() end
    local w = targetWorld(t)
    local instance, px, py = NS.Compat.PlayerWorldPos()
    local yards = instance ~= nil and NS.Trainers.Distance({ instance, px, py }, w) or nil
    if yards and yards <= WA.ARRIVE then
        NS.Print(L["You have arrived: %s"]:format(t.name))
        return WA.Clear()
    end
    local rotation = yards and WA.Rotation(px, py, w[2], w[3], facing()) or nil
    paintArt(rotation, yards)
    paintText(t, yards)
end

onUpdate = function(_, elapsed)
    state.elapsed = state.elapsed + (elapsed or 0)
    if state.elapsed < WA.THROTTLE then return end
    state.elapsed = 0
    WA.Update()
end

local function present()
    if not frame then build() end
    frame:SetScale(profile().arrowScale or 1)
    applyPoint()
    frame:Show()
    state.elapsed = 0
    frame:SetScript("OnUpdate", onUpdate)
    WA.Update()
end

-- ---------------------------------------------------------------------------------------------
-- Show, hide, clear
-- ---------------------------------------------------------------------------------------------

-- The frame down and its OnUpdate disarmed, explicitly: this is the one place it is disarmed.
local function takeDown()
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

--- Point the arrow at trainer `t` (its native pin was just set), retargeting a shown arrow.
function WA.Show(t)
    if not (t and t.mapID and t.x and t.y) then return end
    state.target, state.world = t, nil
    present()
end

--- Hide the arrow and forget the target (the native pin, if any, stays).
function WA.Hide()
    state.target, state.world = nil, nil
    if state.test then return end   -- test mode's sample stays until test mode ends
    takeDown()
end

--- Right-click: the waypoint goes, the native pin with it, and the arrow hides. In test mode the
--- sample only goes (no pin was set for it): a real waypoint under it is pointed at again.
function WA.Clear()
    if state.test then
        state.test = nil
        if state.target and WA.Wanted() then return present() end
        takeDown()
        return
    end
    if state.target then clearNativePin() end
    WA.Hide()
end

--- Test mode (preview-mode): the arrow on a sample trainer, at a sample distance and angle. Nothing
--- is written. Shown only where a real pin would show it (Show Skill Master's arrow on).
function WA.ShowTest()
    if not WA.Wanted() then return end
    local list = NS.Trainers:For("swords")
    local sample
    for _, t in ipairs(list or {}) do
        if t.mapID and t.x and t.y then sample = t break end
    end
    if not sample then return end
    state.test = sample
    present()
end

--- Test mode ended: the sample goes; a real waypoint set before it is pointed at again.
function WA.HideTest()
    if not state.test then return end
    state.test = nil
    if state.target and WA.Wanted() then return present() end
    takeDown()
end

--- The page's two rows, and a profile switch, copy or reset: the scale (and, while shown, the saved
--- point) applies at once; the arrow off hides it and hands the live native pin back to the
--- client's own arrow (the old behavior).
function WA.ApplySettings()
    if frame then
        frame:SetScale(profile().arrowScale or 1)
        if frame:IsShown() then applyPoint() end
    end
    if WA.Wanted() then return end
    local had = state.target ~= nil
    state.test = nil
    WA.Hide()
    if had and type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
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
    local instance, wx, wy = NS.Compat.MapWorldPos(point.uiMapID, x, y)
    if instance == nil then return nil end
    return { instance, wx, wy }
end

--- USER_WAYPOINT_UPDATED: the native pin was cleared, or replaced elsewhere (the world map's own
--- pin), so the arrow hides. A pin whose place the client cannot say keeps the arrow.
function WA.OnWaypointUpdated()
    if not state.target or type(C_Map) ~= "table" then return end
    if type(C_Map.HasUserWaypoint) == "function" then
        local ok, has = pcall(C_Map.HasUserWaypoint)
        if ok and has == false then return WA.Hide() end
    end
    local pin, w = pinWorld(), targetWorld(state.target)
    if pin and w then
        local d = NS.Trainers.Distance(pin, w)
        if d == nil or d > 2 then WA.Hide() end
    end
end

--- The stand-down: the arrow and test mode's sample come down; nothing waits.
function WA.StandDown()
    state.test = nil
    WA.Hide()
end

-- A tracked bus target: the stand-down takes it down and the stand-up replays it.
WA.events = NS.NewBusTarget()
if WA.events then
    NS.SafeRegisterEvent(WA.events, "USER_WAYPOINT_UPDATED", function() WA.OnWaypointUpdated() end, NS.rejectedEvents)
end
