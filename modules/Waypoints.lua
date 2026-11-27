local _, NS = ...
-- modules/Waypoints.lua — a trainer's waypoint (design §2 goal 7, plan Task 3.3): a TomTom waypoint
-- when the real TomTom is loaded, else the client's native user waypoint (C_Map.SetUserWaypoint,
-- feature-detected), else the directions in chat. A trainer without coordinates (most profession
-- trainers: the data never guesses a pin, defaults/Trainers_Forever.lua) always goes to chat. The
-- native pin comes with Character Ledger's own arrow (modules/WaypointArrow.lua, round 6, R6-11) and is
-- not super-tracked, unless Show Character Ledger's arrow is off: then the pin is super-tracked and the
-- client's arrow points.
--
-- TomTom (AF-SM-TOMTOM, owner img-19, 2026-11-19): with TomTom loaded, the native pin left nothing,
-- because TomTom takes the client's user waypoint over and clears it, and Character Ledger's arrow
-- follows the pin away. So the real TomTom, told by its folder name (NS.Compat.TomTom; round 7's
-- R7-7 dropped TomTom over another addon answering TomTom's API, which this still ignores), gets the
-- waypoint and its arrow points; ours stays hidden. A TomTom that raises falls back to the pin.
--
-- NS.Waypoints:Set(trainer) -> "tomtom"|"native"|"chat"; :Method(trainer); :Blocked(trainer);
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

--- Which a Set would use for `t`, without setting anything. The preference (waypoints.method):
--- "auto" is TomTom when the real addon is loaded, else the map pin, else chat; "chat" always prints.
function Wp:Method(t)
    local pref = setting("waypoints.method", "auto")
    if pref == "chat" or not (t and hasCoords(t)) then return "chat" end
    if NS.Compat.TomTom() then return "tomtom" end
    if nativeReady(t) then return "native" end
    return "chat"
end

--- Why a Set for `t` could only print to chat (owner feedback round 6, R6-6: the trainer popup's
--- Set waypoint button is disabled then): "nocoords" (the data has no coordinates for it),
--- "chat" (Waypoint method is Chat only) or "noprovider" (no TomTom and no native pin on this
--- client); nil when a Set would place a waypoint.
function Wp:Blocked(t)
    if not (t and hasCoords(t)) then return "nocoords" end
    if Wp:Method(t) ~= "chat" then return nil end
    if setting("waypoints.method", "auto") == "chat" then return "chat" end
    return "noprovider"
end

-- No trainer is shown as unverified (the owner, 2026-11-25: "i dont want to ship anything which
-- shows waypoint unverified - if it comes up, or a user reports it, ill fix it then"). The probe's
-- per-record provenance (verified, unverified) stays in the data for the probe and the suites.

local function announce(line)
    if setting("waypoints.announce", true) ~= false then NS.Print(line) end
end

--- "Buliwyf Stonehand: Ironforge, The Military Ward (62.2, 89.6)".
function Wp:Directions(t)
    local where = NS.Rows.Place(t)
    if t.subzone and t.subzone ~= where then where = where .. ", " .. t.subzone end
    if hasCoords(t) then where = where .. (" (%.1f, %.1f)"):format(t.x, t.y) end
    local text = L["%s: %s"]:format(t.name, where)
    -- GitHub issue #3: a book or quest after the place, "Shandrina: Ashenvale (49.5, 67.1) · Sells
    -- Expert Cookbook".
    local learn = NS.Trainers.LearnNote(t)
    if learn then text = text .. " \194\183 " .. learn end
    return text
end

function Wp:Print(t) NS.Print(Wp:Directions(t)) end

-- TomTom's waypoint, its own arrow pointing (x, y as 0..1 fractions). Answers whether it was placed.
local function viaTomTom(t)
    local tt = NS.Compat.TomTom()
    if not tt then return false end
    return (pcall(tt.AddWaypoint, tt, t.mapID, t.x / 100, t.y / 100, {
        title = t.name, from = L["Character Ledger"], persistent = false, minimap = true, world = true,
    }))
end

-- The native pin, super-tracked (the client's own arrow) unless Character Ledger's arrow points the way
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

--- Set the waypoint for trainer `t`: TomTom's (its arrow, never ours), the map pin (with Skill
--- Master's arrow while it is wanted), or chat when neither can be set; a TomTom that raises falls
--- to the pin. Answers the method used.
function Wp:Set(t)
    local method = Wp:Method(t)
    if method == "tomtom" then
        if viaTomTom(t) then
            if NS.WaypointArrow then NS.WaypointArrow.Hide() end   -- TomTom's arrow points now
            announce(L["Waypoint set (TomTom): %s"]:format(Wp:Directions(t)))
            return "tomtom"
        end
        method = nativeReady(t) and "native" or "chat"
    end
    local own = arrowWanted()
    if method == "native" and viaNative(t, own) then
        if own then NS.WaypointArrow.Show(t) end
        announce(L["Map pin set: %s"]:format(Wp:Directions(t)))
        return "native"
    end
    Wp:Print(t)
    return "chat"
end
