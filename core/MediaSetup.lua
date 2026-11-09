local addonName, NS = ...
-- core/MediaSetup.lua — NS.Icon / NS.MediaFont from LibKa0s-Media-1.0, and the one RegisterLSM call.

-- LOAD-BEARING position: core/Constants.lua resolves FONT_MONO from NS.MediaFont at file load, so
-- this file must be published first (the TOC says so beside both lines).
--
-- Every call passes addonName, this file's first vararg: a texture path is absolute from
-- Interface\AddOns\ and the library is vendored, so it cannot know which folder it was copied into.

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon (extensionless), or nil. Only names declared on the
--- CLAUDE.md `LibKa0s icons:` line are shipped; nil means "draw something else".
--- @param name string
--- @return string|nil
function NS.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil when the library is absent.
--- @param name string
--- @return string|nil
function NS.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

-- At FILE LOAD, not PLAYER_LOGIN: LibSharedMedia is vendored and has already run, and a shipped
-- default naming a face LSM has not heard of would otherwise resolve to nothing.
if Media then Media.RegisterLSM(addonName) end
