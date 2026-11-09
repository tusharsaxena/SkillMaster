if GetLocale() ~= "deDE" then return end
-- locales/deDE.lua — the deDE translation of locales/enUS.lua, a stub until a translator fills it.
--
-- The gate above is this file's first statement (localization-§1): on every other client it writes
-- nothing. Each line is `L["<the enUS key>"] = "<translation>"`, keeping the key's format directives
-- in order; a key with no line here renders its English through NS.L's fallback. Translate first
-- the strings matched against the client's own text, because they are game data rather than
-- display: the skill-line names and Skills-tab headers (the T2.1 block, read by NS.SkillNameToKey),
-- the three tooltip patterns of the T2.2 block, the zone names of the fishing table and the mining
-- node and herb names (the T2.4 block). Until those carry this client's spelling, a skill this
-- client names differently lands in the Other block and its bonuses are not attributed.

local _, NS = ...
local L = NS.L -- luacheck: no unused
