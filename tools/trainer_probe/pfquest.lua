-- tools/trainer_probe/pfquest.lua — reads pfQuest's vanilla unit database (github.com/shagu/pfQuest,
-- db/units.lua, MIT) for the trainer probe (GitHub issue #3): each creature's spawn points in the
-- Era map frame, { x, y, AreaID }. ItemTree takes its creatures' zones from the same file; the probe
-- uses it as a second, independent Era reading of each trainer's place, projected into Forever's
-- frame through QuestieDB's per-area transform (data/Forever/conversion.json).

local IO = dofile((...) .. "/io.lua")

local PF = {}

--- Read `path` (db/units.lua) in a sandbox holding only the pfDB table it fills: creature id ->
--- { { x, y, area }, ... }.
function PF.Read(path)
    local src = assert(IO.read(path), "cannot read " .. path)
    local env = { pfDB = { units = {} } }
    local ok, err = IO.sandbox(src, "pfquest/units.lua", env)
    assert(ok, "could not load pfQuest units: " .. tostring(err))
    local out = {}
    for id, u in pairs(env.pfDB.units.data or {}) do
        local pts = {}
        for _, c in ipairs(type(u) == "table" and u.coords or {}) do
            pts[#pts + 1] = { x = c[1], y = c[2], area = c[3] }
        end
        out[id] = pts
    end
    return out
end

--- An Era point projected into Forever's frame by area coefficients { sx, ox, sy, oy }
--- (x' = x * sx + ox), or the point itself when the area has none.
function PF.Project(pt, coefficients)
    local c = coefficients and coefficients[pt.area]
    if not c then return pt.x, pt.y end
    return pt.x * c[1] + c[2], pt.y * c[3] + c[4]
end

return PF
