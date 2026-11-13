local _, NS = ...
-- modules/Waypoints.lua — a trainer's waypoint (design §2 goal 7, plan Task 3.3): TomTom when it is
-- loaded, else the client's native user waypoint (C_Map.SetUserWaypoint, feature-detected), else
-- the directions in chat. A trainer without coordinates (most profession trainers: the data never
-- guesses a pin, defaults/Trainers_Forever.lua) always goes to chat.
--
-- NS.Waypoints:Set(trainer) -> "tomtom"|"native"|"chat"; :Method(trainer); :Blocked(trainer);
-- :Print(trainer); :Directions(trainer)

NS.Waypoints = {}
local Wp = NS.Waypoints
local L = NS.L

local function hasCoords(t)
    return type(t.mapID) == "number" and type(t.x) == "number" and type(t.y) == "number"
end

local function tomtomReady()
    return type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function"
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

--- Which of the three a Set would use for `t`, without setting anything. The preference
--- (waypoints.method) narrows the order: "auto" is TomTom, the map pin, then chat; "tomtom" is
--- the same; "native" skips TomTom; "chat" always prints.
function Wp:Method(t)
    local pref = setting("waypoints.method", "auto")
    if pref == "chat" or not (t and hasCoords(t)) then return "chat" end
    if pref ~= "native" and tomtomReady() then return "tomtom" end
    if nativeReady(t) then return "native" end
    return "chat"
end

--- Why a Set for `t` could only print to chat (owner feedback round 6, R6-6: the trainer popup's
--- Set waypoint button is disabled then): "nocoords" (the data has no coordinates for it),
--- "chat" (Waypoint method is Chat only) or "noprovider" (no TomTom and no native pin here); nil
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

local function viaTomTom(t)
    return pcall(TomTom.AddWaypoint, TomTom, t.mapID, t.x / 100, t.y / 100,
        { title = t.name, persistent = false, minimap = true, world = true })
end

local function viaNative(t)
    return pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(t.mapID, t.x / 100, t.y / 100))
        if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
end

--- Set the waypoint for trainer `t` by the first method that works; a failing provider falls to
--- the next. Answers the method used.
function Wp:Set(t)
    local method = Wp:Method(t)
    if method == "tomtom" and viaTomTom(t) then
        announce(L["Waypoint set (TomTom): %s"]:format(Wp:Directions(t)))
        return "tomtom"
    end
    if (method == "tomtom" or method == "native") and nativeReady(t) and viaNative(t) then
        announce(L["Map pin set: %s"]:format(Wp:Directions(t)))
        return "native"
    end
    Wp:Print(t)
    return "chat"
end
