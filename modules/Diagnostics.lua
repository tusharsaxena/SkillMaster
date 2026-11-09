local addonName, NS = ...
-- modules/Diagnostics.lua — this addon's sections of `/skm diagnostics` (debug-logging-§14). The
-- library writes the markers, the identity header, a pcall per section and the cap.
NS.Diagnostics = NS.Diagnostics or {}

local TAG = "Diag"

-- Read state, never act: no hold, no event, no timer. `out:add` formats %s only, so raw values.
local function identity(out)
    local db, LC = NS.db, NS.Lifecycle
    out:add(TAG, "schema stored=%s code=%s", db.global.schemaVersion, NS.SCHEMA_VERSION)
    out:add(TAG, "profile=%s", db:GetCurrentProfile())
    out:add(TAG, "enabled=%s stoodDown=%s", NS.GetSetting("enabled"), NS.IsStoodDown())
    out:joined(TAG, "holds", LC:Holds())
end

local function settings(out)
    out:nonDefaults(NS.Schema, NS.GetSetting, function(row) return row.default end, nil,
        { always = { "enabled", "skin.source", "skin.skin" } })
end

local function state(out)
    if NS.IsStoodDown() then out:add(TAG, "stood down: runtime state released") return end
    out:add(TAG, "window shown=%s testMode=%s", NS.MainWindow.IsShown(), NS.IsTestMode())
end

local function skin(out)
    local lib = LibStub and LibStub("LibKa0s-Skin-1.0", true)
    out:add(TAG, "skin engine=%s", lib and lib.MINOR or "absent")
    if not lib then return end
    local source, key = NS.SkinChoice()
    local appliedSource, appliedKey = lib:GetChoice(addonName)
    out:add(TAG, "stored=%s:%s applied=%s:%s", source, key, appliedSource, appliedKey)
end

local function rejected(out)
    out:list(TAG, "rejected events", NS.rejectedEvents)
end

function NS.Diagnostics.Sections()
    return {
        { "identity", identity },
        { "settings", settings },
        { "state",    state },
        { "skin",     skin },
        { "rejected", rejected },
    }
end
