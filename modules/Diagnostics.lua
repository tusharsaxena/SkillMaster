local addonName, NS = ...
-- modules/Diagnostics.lua — this addon's sections of `/skm diagnostics` (debug-logging-§14). The
-- library writes the markers, the identity header, a pcall per section and the cap. The domain
-- sections (model, probe, bonuses, layout) read the live models, the caches and the stored layout;
-- none scans, collects, expands a Skills-tab header or builds a frame.
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

local function yesNo(v) return v and "yes" or "no" end

-- The live skill model (never test mode's preview), the stat model and the two stores.
local function skillCounts(m)
    local total, learned = 0, 0
    for _, e in pairs(m and m.byKey or {}) do
        total = total + 1
        if e.learned ~= false then learned = learned + 1 end
    end
    return total, learned
end

local function statCount(m)
    local n = 0
    for _, group in ipairs(NS.StatData.GROUPS) do n = n + #((m and m[group]) or {}) end
    return n
end

local function model(out)
    local m = NS.SkillData:Model()
    local total, learned = skillCounts(m)
    out:add(TAG, "model skills=%s learned=%s unlearned=%s", total, learned, total - learned)
    local order = m and m.order or {}
    local cats = {}
    for _, c in ipairs(NS.SkillData.CATEGORIES) do cats[#cats + 1] = c .. "=" .. #(order[c] or {}) end
    out:add(TAG, "model rows %s", table.concat(cats, " "))
    local stats = NS.StatData:Model()
    out:add(TAG, "model stats=%s scanned=%s", statCount(stats), yesNo(stats))
    local gains = NS.SessionLog:Gains()
    out:add(TAG, "model session log entries=%s session gains=%s", #NS.SessionLog:Entries(), gains)
    out:add(TAG, "model alts=%s preview source=%s", #NS.Alts:List(), NS.Blocks.source and "on" or "off")
    if NS.IsStoodDown() then out:add(TAG, "model stood down: the last scan is kept, nothing rescans") end
end

-- The probe's read-only half: which skill API this client has, and which probed globals.
local function probe(out)
    local p = NS.Probe.Summary()
    out:add(TAG, "probe skill api=%s lines=%s", p.source, p.lines)
    out:add(TAG, "probe apis present=%s/%s TomTom=%s", p.present, p.total, yesNo(p.tomtom))
    out:list(TAG, "probe apis missing:", p.missing)
end

-- Every skill carrying a modifier, then the cached bonus sources. The cache is read as it stands:
-- collecting it would scan the gear's tooltips, which is an action, not a read.
local function modifiers()
    local items = {}
    for key, e in pairs(NS.SkillData:Model().byKey) do
        local mod, temp = tonumber(e.modifier) or 0, tonumber(e.tempPoints) or 0
        if e.learned ~= false and (mod ~= 0 or temp ~= 0) then
            items[#items + 1] = ("%s=%+d (temp %d)"):format(key, mod, temp)
        end
    end
    table.sort(items)
    return items
end

local function bonuses(out)
    out:list(TAG, "bonus skills", modifiers())
    local B = NS.Bonuses
    local cache = B.__cache
    if not cache then out:add(TAG, "bonus cache empty (nothing collected yet)") return end
    out:add(TAG, "bonus cache sources=%s items=%s buffs=%s liveTemp=%s", #cache, #(B.__items or {}),
        #(B.__buffs or {}), yesNo(B.__ticker))
    local items = {}
    for _, c in ipairs(cache) do
        items[#items + 1] = ("%s %+d %s %s"):format(tostring(c.name), tonumber(c.amount) or 0,
            tostring(c.kind), tostring(c.source))
    end
    out:list(TAG, "bonus sources:", items)
end

-- The stored window and block layout, and which detached frames exist.
local function frameState(id)
    local f = NS.Detached.Frame(id)
    if not f then return "none" end
    return f:IsShown() and "shown" or "hidden"
end

local function layout(out)
    local p = NS.db.profile
    out:add(TAG, "layout window scale=%s alpha=%s locked=%s point=%s maxHeight=%s summary=%s",
        p.scale, p.alpha, p.locked, p.window.point and "set" or "default", p.layout.maxHeight, p.layout.summary)
    for _, id in ipairs(NS.BLOCKS) do
        local b = NS.Blocks.Settings(id)
        out:add(TAG, "block %s docked=%s order=%s collapsed=%s scale=%s locked=%s point=%s frame=%s", id,
            b.docked, b.order, b.collapsed, b.scale, b.locked, b.point and "set" or "default", frameState(id))
    end
    out:joined(TAG, "docked order:", NS.Blocks.Docked())
    out:joined(TAG, "detached:", NS.Blocks.Undocked())
end

-- The simulator (preview-mode, H8): the session, the step and the seam.
local function sim(out)
    local st = NS.Sim:Status()
    out:add(TAG, "sim active=%s panel=%s scenario=%s step=%s/%s events=%s", st.active == true,
        NS.Sim:IsPanelShown(), st.scenario or "-", st.pos or 0, st.total or 0, st.events or 0)
    out:add(TAG, "sim seam keys=%s unwrapped=%s", #NS.SimSeam:Keys(), #NS.SimSeam:Unwrapped())
    out:add(TAG, "preview data=%s", NS.Preview.IsOn())
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
        { "model",    model },
        { "probe",    probe },
        { "bonuses",  bonuses },
        { "layout",   layout },
        { "sim",      sim },
        { "rejected", rejected },
    }
end
