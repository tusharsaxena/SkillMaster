local addonName, NS = ...
-- core/EnvSetup.lua — this addon's TOC metadata and version, through LibKa0s-Env-1.0.

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil.
--- @param field string  "Version", "Title", "Notes", ...
--- @return string|nil
function NS.Meta(field)
    if Env then return Env.GetAddOnMetadata(addonName, field) end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    return nil
end

--- This addon's version, preferring the TOC over the fallback constant. Never nil.
--- NS.version is read at call time (core/Namespace.lua).
--- @return string
function NS.Version()
    if Env then return Env.Version(addonName, NS.version) or "?" end
    return NS.Meta("Version") or NS.version or "?"
end
