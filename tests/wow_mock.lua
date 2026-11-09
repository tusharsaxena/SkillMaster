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
    installBindings(M)
    -- Frames answer strata and level (frame-layering-§5): the window sets both.
    installLayers(M)
    -- Distinct, recording regions: the window's title and the test strip's line are read back.
    installPaint(M)
    return M
end
