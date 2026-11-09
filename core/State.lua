local _, NS = ...
-- core/State.lua — session-only runtime state; nothing here is ever written to SavedVariables.
NS.State = NS.State or {}

-- The debug flag (debug-logging-§5): off at every login and /reload, never persisted.
NS.State.debug = false

-- Test mode (preview-mode): session-only, on until turned off, ended by combat.
NS.State.testMode = false

-- Skill points gained since login, counted from SKILL_UP for the main window's summary strip
-- (modules/Blocks.lua) until the session log (T4.3) answers it.
NS.State.sessionGains = 0
