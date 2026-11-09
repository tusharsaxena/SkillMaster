local addonName, NS = ...
-- core/CoreSetup.lua — NS.Print from LibKa0s-Core-1.0, the SafeRegister* family, the shared window
-- chrome, the one MakeCloseButton wrapper and the resize grip (NS.MakeResizable).
--
-- LOAD-BEARING: after core/Namespace.lua (NS.PREFIX) and before everything that prints.
NS.Util = NS.Util or {}

-- The host owns the rejected-event list (events-frames-taint-§1); the [Init] summary and the
-- diagnostics report surface it.
NS.rejectedEvents = NS.rejectedEvents or {}

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- Degrade, never error. The same names the live seam publishes, with honest small bodies:
    -- the chrome degrades to nothing (Core.SKIN's values are the contract), the printer says
    -- "not installed" once, and the SafeRegister* family is one-rung pcall bodies.
    local function probeConcat(v) return table.concat({ v }) end
    NS.IsConcatSafe = function(v) return (pcall(probeConcat, v)) end
    NS.SafeToString = function(v)
        if v == nil then return "nil" end
        if type(v) == "boolean" then return tostring(v) end
        if NS.IsConcatSafe(v) then return tostring(v) end
        return "<secret>"
    end

    NS.SKIN            = {}
    NS.ApplySkin       = function() end
    NS.MakeCloseButton = function() return nil end
    NS.MakeResizable   = function() return nil end   -- no grip: the window keeps its size

    local function reject(rejected, event)
        if type(rejected) ~= "table" then return end
        for i = 1, #rejected do if rejected[i] == event then return end end
        rejected[#rejected + 1] = event
    end
    NS.SafeRegisterEvent = function(target, event, handler, rejected)
        local ok = pcall(target.RegisterEvent, target, event, handler)
        if not ok then reject(rejected, event) end
        return ok
    end
    NS.SafeRegisterUnitEvent = function(frame, event, rejected, unit1, unit2)
        local ok = pcall(frame.RegisterUnitEvent, frame, event, unit1, unit2)
        if not ok then reject(rejected, event) end
        return ok
    end
    NS.SafeRegisterEvents = function(target, events, handler, rejected)
        local n = 0
        for _, event in ipairs(events) do
            if NS.SafeRegisterEvent(target, event, handler, rejected) then n = n + 1 end
        end
        return n
    end

    local announced = false
    NS.Print = function(...)
        if not announced then
            announced = true
            print(NS.PREFIX, NS.L["%s; running on reduced built-in fallbacks."]:format(NS.LIBKA0S_MISSING))
        end
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = NS.SafeToString((select(i, ...))) end
        print(NS.PREFIX, table.concat(parts, " "))
    end
    NS.Util.print = NS.Print
    return
end

NS.IsConcatSafe = lib.IsConcatSafe
NS.SafeToString = lib.SafeToString

NS.SafeRegisterEvent     = lib.SafeRegisterEvent
NS.SafeRegisterUnitEvent = lib.SafeRegisterUnitEvent
NS.SafeRegisterEvents    = lib.SafeRegisterEvents

-- The shared window edge (standalone-windows), published flat.
NS.SKIN      = lib.SKIN
NS.ApplySkin = lib.ApplySkin

-- WRAPPED, and that is a MUST (standalone-windows, anti-patterns #64/#65): the third argument is the
-- folder the close mark is drawn from, which a vendored library cannot infer. Every close control
-- in the addon is built through this wrapper, so
--   grep -rn 'MakeCloseButton(' --include='*.lua' | grep -v '/libs/'
-- returns this definition and NS.MakeCloseButton calls only.
NS.MakeCloseButton = function(parent, onClick)
    return lib.MakeCloseButton(parent, onClick, addonName)
end

-- The bottom-right resize grip (standalone-windows, Resizing); modules/Chrome.lua's
-- NS.Chrome.MakeResizable is the one caller, which coalesces the relayout and saves on release.
NS.MakeResizable = lib.MakeResizable

-- The prefix as a FUNCTION, so a later change to NS.PREFIX is not frozen in at load.
local printer = lib:New({ prefix = function() return NS.PREFIX end })

-- NS.Print and NS.Util.print are ONE function object: AceAddon's AceConsole embed stamps its own
-- :Print over NS.Print, and core/SkillMaster.lua reclaims it from NS.Util.print (architecture-§2).
NS.Print = printer.Print
NS.Util.print = NS.Print
