-- tests/wow_mock.lua — Ka0s Skill Master's WoW-API mock: the kit's shared base
-- (tests/_kit/mock_base.lua) plus the handful of APIs that are this addon's own.
--
-- Returns a builder, so each run gets a fresh, isolated environment.

local base = dofile("tests/_kit/mock_base.lua")
local installBindings = dofile("tests/_kit/mock_bindings.lua")
local installLayers   = dofile("tests/_kit/mock_layers.lua")
local installPaint    = dofile("tests/_kit/mock_paint.lua")

return function()
    local M = base()
    M.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    M.UISpecialFrames = {}
    M.YES, M.NO = "Yes", "No"
    M.StaticPopupDialogs = {}
    -- The player's race and faction, which every client answers: a render of a model with a racial
    -- bonus (Guns, a Dwarf's) reads them, whichever suite published the model (suites swap these).
    M.UnitRace = function() return "Human", "Human" end
    M.UnitFactionGroup = function() return "Alliance", "Alliance" end
    -- The pointer in screen px (round 5, R5-6b: a section dragged out of a merged window).
    M.__cursor = { 0, 0 }
    M.GetCursorPosition = function() return M.__cursor[1], M.__cursor[2] end
    M.__popups = {}
    M.StaticPopup_Show = function(name) M.__popups[#M.__popups + 1] = name end
    -- The TOC fields the addon reads through NS.Meta.
    M.__metadata = {
        Version = "0.1.0",
        Notes   = "Weapon skills, professions and character stats as customizable bars, for WoW Forever.",
    }
    M.C_AddOns = M.C_AddOns or {}
    M.C_AddOns.GetAddOnMetadata = function(_, field) return M.__metadata[field] end
    -- The launcher's two libraries, as fakes that record what the addon hands them.
    M.__ldbObjects = {}
    M.__libs["LibDataBroker-1.1"] = {
        NewDataObject = function(_, name, tbl)
            if M.__ldbObjects[name] then return nil end
            M.__ldbObjects[name] = tbl
            return tbl
        end,
        GetDataObjectByName = function(_, name) return M.__ldbObjects[name] end,
    }
    M.__minimapButtons = {}
    M.__libs["LibDBIcon-1.0"] = {
        Register = function(_, name, object, db)
            M.__minimapButtons[name] = { object = object, db = db, shown = not (db and db.hide) }
        end,
        IsRegistered = function(_, name) return M.__minimapButtons[name] ~= nil end,
        Show = function(_, name) local b = M.__minimapButtons[name] if b then b.shown = true end end,
        Hide = function(_, name) local b = M.__minimapButtons[name] if b then b.shown = false end end,
        GetMinimapButton = function(_, name) return M.__minimapButtons[name] end,
    }
    -- AceDB 40's db.keys and db.char, which the kit's AceDB fake leaves out (the session log keeps
    -- its ring in db.char, the alt snapshots key by db.keys). Built as the real library builds them
    -- off a client without regional names: char "Name - Realm", realm the realm; db.char is
    -- sv.char[that key] with the defaults' char section merged in.
    local aceDB = M.__libs["AceDB-3.0"]
    local kitNew = aceDB.New
    aceDB.New = function(self, tbl, defaults, ...)
        local db = kitNew(self, tbl, defaults, ...)
        local ctx = M.__context
        db.keys = db.keys or { char = ctx.name .. " - " .. ctx.realm, realm = ctx.realm }
        if db.char == nil and type(db.sv) == "table" then
            db.sv.char = db.sv.char or {}
            local section = db.sv.char[db.keys.char] or {}
            for k, v in pairs(defaults and defaults.char or {}) do
                if section[k] == nil then section[k] = type(v) == "table" and {} or v end
            end
            db.sv.char[db.keys.char] = section
            db.char = section
        end
        return db
    end
    installBindings(M)
    -- Frames answer strata and level (frame-layering-§5): the window sets both.
    installLayers(M)
    -- Distinct, recording regions: the window's title and the test strip's line are read back.
    installPaint(M)
    return M
end
