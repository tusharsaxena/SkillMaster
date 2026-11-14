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
-- On, every display draws the sample character (modules/Preview.lua); off, the live data again.
-- ---------------------------------------------------------------------------------------------

function NS.IsTestMode() return NS.State.testMode == true end

-- Test mode's surfaces (owner feedback round 5, R5-1): turning it on shows the main window, the
-- Journal and test mode's three toasts (NS.Alerts.ShowTestToasts); turning it off takes the toasts
-- down and hides each window test mode opened, leaving one the player had open. Nothing is stored.
local openedForTest   -- { window = bool, journal = bool }: which windows test mode put up

local function showTestSurfaces()
    local W, J = NS.MainWindow, NS.Journal
    openedForTest = { window = W and not W.IsShown(), journal = J and not J.IsShown() }
    if openedForTest.window then W.Show() end
    if openedForTest.journal then J.Show() end
    if NS.Alerts then NS.Alerts.ShowTestToasts() end
    if NS.WaypointArrow then NS.WaypointArrow.ShowTest() end   -- R6-11: the arrow on a sample trainer
end

local function hideTestSurfaces()
    if NS.Alerts then NS.Alerts.HideTestToasts() end
    if NS.WaypointArrow then NS.WaypointArrow.HideTest() end
    local opened = openedForTest or {}
    openedForTest = nil
    if opened.window then NS.MainWindow.Hide() end
    if opened.journal then NS.Journal.Hide() end
end

--- Flip test mode. Refuses while stood down (the one refusal helper), and refuses to START in
--- combat or while a simulation runs (the two modes are exclusive, H5). Answers the new state.
function NS.ToggleTestMode()
    local refusal = NS.StoodDownRefusal()
    if refusal then NS.Print(refusal) return NS.IsTestMode() end
    if not NS.IsTestMode() and InCombatLockdown() then
        NS.Print(NS.L["Test mode cannot start in combat."])
        NS.Debug("Test", "start refused (in combat)")
        return false
    end
    if not NS.IsTestMode() and NS.Sim and NS.Sim:IsActive() then
        NS.Print(NS.L["Test mode cannot start while a simulation runs."])
        NS.Debug("Test", "start refused (simulation running)")
        return false
    end
    NS.State.testMode = not NS.IsTestMode()
    NS.Debug("Test", "test mode %s", NS.State.testMode and "on" or "off")
    if NS.Preview then NS.Preview.Apply(NS.State.testMode) end
    if NS.MainWindow then NS.MainWindow.Refresh() end
    if NS.State.testMode then showTestSurfaces() else hideTestSurfaces() end
    if NS.Helpers and NS.Helpers.RefreshScalars then NS.Helpers.RefreshScalars() end
    return NS.State.testMode
end

--- Combat ends test mode (preview-mode) and a running simulation.
function addon:OnEnterCombat()
    if NS.Sim and NS.Sim:IsActive() then NS.Sim:Stop("combat") end
    if not NS.IsTestMode() then return end
    NS.State.testMode = false
    NS.Debug("Test", "test mode ended by combat")
    if NS.Preview then NS.Preview.Apply(false) end
    if NS.MainWindow then NS.MainWindow.Refresh() end
    hideTestSurfaces()
end

-- ---------------------------------------------------------------------------------------------
-- Runtime registrations, and the teardown the stand-down latch drives (slash-commands-§7).
-- ---------------------------------------------------------------------------------------------

--- Every game-event registration the running addon holds, made from CURRENT state.
function NS.RegisterRuntime()
    NS.SafeRegisterEvent(addon, "PLAYER_REGEN_DISABLED", "OnEnterCombat", NS.rejectedEvents)
    if NS.SkillData then NS.SkillData:Enable() end
    if NS.Bonuses then NS.Bonuses.RegisterRuntime() end   -- T2.2
    NS.UnitEvents.StandUp()   -- the player's UNIT_* events (Bonuses, StatData), on one unit frame
end

--- Disabled means not running: frames hidden, every event and message unregistered, every timer
--- canceled. The latch logs the edge; nothing here logs one of its own.
function NS.StandDown()
    -- The simulation stops FIRST (H6), so its cleanup runs before anything below tears down.
    if NS.Sim then NS.Sim:Stop("standDown") NS.Sim:HidePanel() end
    NS.State.testMode = false
    openedForTest = nil   -- every window and toast comes down below
    if NS.Preview then NS.Preview.Apply(false) end
    if NS.MainWindow then NS.MainWindow.StandDown() end
    if NS.Detached then NS.Detached.StandDown() end
    if NS.SecureOverlay then NS.SecureOverlay:StandDown() end
    if NS.TrainerPopup then NS.TrainerPopup.Hide() end
    if NS.WaypointArrow then NS.WaypointArrow.StandDown() end   -- R6-11: no arrow stays up
    if NS.Widgets and NS.Widgets.CloseMenu then NS.Widgets.CloseMenu() end   -- the row menu closes with us
    if NS.Journal then NS.Journal.StandDown() end
    if NS.Alerts then NS.Alerts.StandDown() end   -- T4.2: no toast stays up or waits
    NS.HideSkinPicker()
    addon:UnregisterAllEvents()
    NS.UnitEvents.StandDown()
    addon:CancelAllTimers()
    NS.BusStandDown()
    if NS.Broker then NS.Broker.Refresh() end   -- the feed reads "Off" (T4.1)
end

--- Rebuild from current state.
function NS.StandUp()
    NS.BusStandUp()
    NS.RegisterRuntime()
    -- A setting written while stood down was stored but not applied (NS.ApplyLook returns early),
    -- and a simulation's stand-down cleanup skips its re-read: both come back from current state.
    if NS.MainWindow then NS.MainWindow.ApplySettings() end
    if NS.Bonuses then NS.Bonuses.Refresh() end
    if NS.StatData then NS.StatData:Request() end
    if NS.MainWindow then NS.MainWindow.Refresh() end
    if NS.Detached then NS.Detached.Refresh() end
    if NS.Broker then NS.Broker.Refresh() end
end

-- ---------------------------------------------------------------------------------------------
-- Profiles: a switch, copy or reset re-reads everything from the new profile.
-- ---------------------------------------------------------------------------------------------

local function reloadProfile()
    if NS.Sim and NS.Sim:IsActive() then NS.Sim:Stop("profile") end
    NS.HideSkinPicker()
    NS:RunMigrations()
    if NS.ForgetCustomTemplates then NS.ForgetCustomTemplates() end   -- a Custom pick was the old profile's
    NS.SyncEnabledHold()
    NS.ApplySkinChoice()
    if NS.MainWindow then NS.MainWindow.ApplySettings() end
    -- A look change like any other: a FULL relayout of the window and the detached blocks (a
    -- values-only pass keeps the old profile's bar styles while the row set is unchanged), and the
    -- Bars page's preview and the Journal restyle on the same message.
    if NS.Blocks then NS.Blocks.Changed() end
    if NS.Broker then NS.Broker.Refresh() end   -- the feed's template is per profile
    if NS.Alerts then NS.Alerts.Refresh() end   -- T4.2: the toast's position from the new profile
    if NS.WaypointArrow then NS.WaypointArrow.ApplySettings() end   -- R6-11: its switch, scale and point
    if NS.Journal then
        NS.Journal.ApplyGeometry()   -- its drop point and size are per profile
        NS.Journal.ApplyLock()       -- and its lock mark (no `locked` reaction fires on a switch)
    end
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
