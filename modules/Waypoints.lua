local _, NS = ...
-- modules/Waypoints.lua — a trainer's waypoint (design §2 goal 7, plan Task 3.3): the client's native
-- user waypoint (C_Map.SetUserWaypoint, feature-detected), else the directions in chat. A trainer
-- without coordinates (most profession trainers: the data never guesses a pin,
-- defaults/Trainers_Forever.lua) always goes to chat. The native pin comes with Skill Master's own
-- arrow (modules/WaypointArrow.lua, round 6, R6-11) and is not super-tracked, unless Show Skill
-- Master's arrow is off: then the pin is super-tracked and the client's arrow points. No TomTom
-- (owner feedback round 7, R7-7: another addon answering TomTom's API hid Skill Master's arrow).
--
-- NS.Waypoints:Set(trainer) -> "native"|"chat"; :Method(trainer); :Blocked(trainer);
-- :Print(trainer); :Directions(trainer)

NS.Waypoints = {}
local Wp = NS.Waypoints
local L = NS.L

local function hasCoords(t)
    return type(t.mapID) == "number" and type(t.x) == "number" and type(t.y) == "number"
end

local function nativeReady(t)
    local ok = type(C_Map) == "table" and type(C_Map.SetUserWaypoint) == "function"
        and type(UiMapPoint) == "table" and type(UiMapPoint.CreateFromCoordinates) == "function"
    if ok and type(C_Map.CanSetUserWaypointOnMap) == "function" then ok = C_Map.CanSetUserWaypointOnMap(t.mapID) end
    return ok and true or false
end

local function setting(path, fallback)
    local v = NS.GetSetting and NS.db and NS.GetSetting(path)
    if v == nil then return fallback end
    return v
end

--- Which of the two a Set would use for `t`, without setting anything. The preference
--- (waypoints.method): "auto" is the map pin, else chat; "chat" always prints.
function Wp:Method(t)
    local pref = setting("waypoints.method", "auto")
    if pref == "chat" or not (t and hasCoords(t)) then return "chat" end
    if nativeReady(t) then return "native" end
    return "chat"
end

--- Why a Set for `t` could only print to chat (owner feedback round 6, R6-6: the trainer popup's
--- Set waypoint button is disabled then): "nocoords" (the data has no coordinates for it),
--- "chat" (Waypoint method is Chat only) or "noprovider" (no native pin on this client); nil
--- when a Set would place a waypoint.
function Wp:Blocked(t)
    if not (t and hasCoords(t)) then return "nocoords" end
    if Wp:Method(t) ~= "chat" then return nil end
    if setting("waypoints.method", "auto") == "chat" then return "chat" end
    return "noprovider"
end

--- The " (unverified)" mark for trainer data not checked on WoW Forever, unless the Trainers and
--- Waypoints page turned it off (trainers.unverified); "" otherwise.
function Wp.UnverifiedMark(t)
    if t.verified == false and setting("trainers.unverified", true) ~= false then
        return " " .. L["(unverified)"]
    end
    return ""
end

local function announce(line)
    if setting("waypoints.announce", true) ~= false then NS.Print(line) end
end

--- "Buliwyf Stonehand: Ironforge, The Military Ward (62.2, 89.6)".
function Wp:Directions(t)
    local where = NS.Rows.Place(t)
    if t.subzone and t.subzone ~= where then where = where .. ", " .. t.subzone end
    if hasCoords(t) then where = where .. (" (%.1f, %.1f)"):format(t.x, t.y) end
    local text = L["%s: %s"]:format(t.name, where)
    return text .. Wp.UnverifiedMark(t)
end

function Wp:Print(t) NS.Print(Wp:Directions(t)) end

-- The native pin, super-tracked (the client's own arrow) unless Skill Master's arrow points the way
-- (round 6, R6-11: NS.WaypointArrow.Wanted); then the pin is set and explicitly not
-- super-tracked, so an earlier pin's client arrow goes away too.
local function viaNative(t, ownArrow)
    return pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(t.mapID, t.x / 100, t.y / 100))
        if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            C_SuperTrack.SetSuperTrackedUserWaypoint(not ownArrow)
        end
    end)
end

local function arrowWanted()
    return NS.WaypointArrow ~= nil and NS.WaypointArrow.Wanted()
end

--- Set the waypoint for trainer `t`: the map pin (with Skill Master's arrow while it is wanted), or
--- chat when the pin cannot be set. Answers the method used.
function Wp:Set(t)
    local method = Wp:Method(t)
    local own = arrowWanted()
    if method == "native" and viaNative(t, own) then
        if own then NS.WaypointArrow.Show(t) end
        announce(L["Map pin set: %s"]:format(Wp:Directions(t)))
        return "native"
    end
    Wp:Print(t)
    return "chat"
end
