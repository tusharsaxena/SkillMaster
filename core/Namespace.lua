local addonName, NS = ...
-- core/Namespace.lua — the identity every later file reads: the folder name, the version fallback,
-- the cyan chat tag and the library-missing sentence.

-- NS is the addon's one private table (architecture-§1); nothing is ever written to _G[addonName].
NS.name = addonName

-- The version fallback. NS.Version() (core/EnvSetup.lua) prefers the TOC's ## Version and only
-- answers this when the manifest cannot be read.
NS.version = "0.1.0"

-- The mandatory cyan chat tag, the initials of Skill Master (slash-commands-§4).
NS.PREFIX = "|cff00ffff[SM]|r"

-- Said once by each degradation stub, so a broken install names the folder it expected.
NS.LIBKA0S_MISSING = NS.L["The LibKa0s library is missing from this installation of Ka0s Skill Master (expected in libs/LibKa0s)"]
