local addonName, NS = ...
-- core/SkillMaster.lua — AceAddon registration (NS promoted to the addon object), the lifecycle
-- callbacks, the stand-down / stand-up pair and test mode.
--
-- LOAD-BEARING: NewAddon(NS, ...) stamps AceConsole's :Print over NS.Print at FILE SCOPE, so this
-- follows core/CoreSetup.lua and reclaims the printer straight after.

local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
NS.Print = NS.Util.print   -- the reclaim: the same object every settings file captured (architecture-§2)

-- ---------------------------------------------------------------------------------------------
-- Test mode (preview-mode): session-only, on until turned off, ended by combat. Three surfaces,
-- one handler: the `test` verb, the launcher's Test mode entry and the Master-controls checkbox.
-- ---------------------------------------------------------------------------------------------

function NS.IsTestMode() return NS.State.testMode == true end

--- Flip test mode. Refuses while stood down (the one refusal helper) and refuses to START in
--- combat. Answers the new state.
function NS.ToggleTestMode()
    local refusal = NS.StoodDownRefusal()
    if refusal then NS.Print(refusal) return NS.IsTestMode() end
    if not NS.IsTestMode() and InCombatLockdown() then
        NS.Print(NS.L["Test mode cannot start in combat."])
        NS.Debug("Test", "start refused (in combat)")
        return false
    end
    NS.State.testMode = not NS.IsTestMode()
    NS.Debug("Test", "test mode %s", NS.State.testMode and "on" or "off")
    if NS.MainWindow then NS.MainWindow.Refresh() end
    if NS.Helpers and NS.Helpers.RefreshScalars then NS.Helpers.RefreshScalars() end
    return NS.State.testMode
end

--- Combat ends test mode (preview-mode).
function addon:OnEnterCombat()
    if not NS.IsTestMode() then return end
    NS.State.testMode = false
    NS.Debug("Test", "test mode ended by combat")
    if NS.MainWindow then NS.MainWindow.Refresh() end
end

-- ---------------------------------------------------------------------------------------------
-- Runtime registrations, and the teardown the stand-down latch drives (slash-commands-§7).
-- ---------------------------------------------------------------------------------------------

--- Every game-event registration the running addon holds, made from CURRENT state.
function NS.RegisterRuntime()
    NS.SafeRegisterEvent(addon, "PLAYER_REGEN_DISABLED", "OnEnterCombat", NS.rejectedEvents)
    if NS.SkillData then NS.SkillData:Enable() end
    if NS.Bonuses then NS.Bonuses.RegisterRuntime(addon) end   -- T2.2
end

--- Disabled means not running: frames hidden, every event and message unregistered, every timer
--- canceled. The latch logs the edge; nothing here logs one of its own.
function NS.StandDown()
    NS.State.testMode = false
    if NS.MainWindow then NS.MainWindow.StandDown() end
    if NS.Detached then NS.Detached.StandDown() end
    if NS.SecureOverlay then NS.SecureOverlay:StandDown() end
    if NS.TrainerPopup then NS.TrainerPopup.Hide() end
    if NS.Widgets and NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end   -- the row menu closes with us
    if NS.Journal then NS.Journal.StandDown() end
    if NS.Alerts then NS.Alerts.StandDown() end   -- T4.2: no toast stays up or waits
    NS.HideSkinPicker()
    addon:UnregisterAllEvents()
    addon:CancelAllTimers()
    NS.BusStandDown()
end

--- Rebuild from current state.
function NS.StandUp()
    NS.BusStandUp()
    NS.RegisterRuntime()
    if NS.MainWindow then NS.MainWindow.Refresh() end
    if NS.Detached then NS.Detached.Refresh() end
end

-- ---------------------------------------------------------------------------------------------
-- Profiles: a switch, copy or reset re-reads everything from the new profile.
-- ---------------------------------------------------------------------------------------------

local function reloadProfile()
    NS.HideSkinPicker()
    NS:RunMigrations()
    NS.SyncEnabledHold()
    NS.ApplySkinChoice()
    if NS.MainWindow then NS.MainWindow.ApplySettings() end
    if NS.MainWindow then NS.MainWindow.Refresh() end
    if NS.Detached then NS.Detached.Refresh() end
    if NS.Alerts then NS.Alerts.Refresh() end   -- T4.2: the toast's position from the new profile
    if NS.Helpers and NS.Helpers.RefreshAllPanels then NS.Helpers.RefreshAllPanels() end
    NS.MaybeShowSkinPicker()
end

function addon:OnInitialize()
    NS:InitDB()
    NS:RunMigrations()          -- before anything reads NS.db.profile (savedvariables-§1)
    local db = NS.db
    db.RegisterCallback(addon, "OnProfileChanged", function(_, _, key)
        NS.Debug("Set", "switched to profile '%s'", key)
        reloadProfile()
    end)
    db.RegisterCallback(addon, "OnProfileCopied", function(_, _, source)
        NS.Debug("Set", "copied profile '%s' into '%s'", source, db:GetCurrentProfile())
        reloadProfile()
    end)
    db.RegisterCallback(addon, "OnProfileReset", function()
        NS.Debug("Set", "reset profile '%s' to defaults", db:GetCurrentProfile())
        reloadProfile()
    end)
    NS.ApplySkinChoice()
    NS.RegisterSlash()
    NS.CreateOptionsPanel()     -- eager category, lazy body (options-ui-§1, §5)
end

function addon:OnEnable()
    NS.Launcher:Register()
    NS.SyncEnabledHold()
    if not NS.IsStoodDown() then NS.RegisterRuntime() end
    if NS.MainWindow then NS.MainWindow.ApplySettings() end
    if NS.Detached and not NS.IsStoodDown() then NS.Detached.Refresh() end
    NS.MaybeShowSkinPicker()
end
