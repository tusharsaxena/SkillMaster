local addonName, NS = ...
-- modules/MainWindow.lua — the Skill Master window (standalone-windows): its chrome, its one toggle
-- handler, the test-mode strip, the drag-only position and the Show window key binding button.
-- The docked blocks (T3.2) render into its body.

NS.MainWindow = {}
local W = NS.MainWindow
local L = NS.L
local Perf = NS.Perf
local LAYERS = NS.Constants.LAYERS

W.FRAME_NAME = "SkillMasterMainWindow"
local WIDTH, HEIGHT, TITLE_H = 360, 420, 26

local frame   -- built on first show

local function savePoint()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if type(point) ~= "string" then return end
    -- The window's drag-only geometry: this module is its one writer (docs/ARCHITECTURE.md).
    NS.db.profile.window.point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function applyPoint()
    local p = NS.db and NS.db.profile.window.point
    frame:ClearAllPoints()
    if type(p) == "table" then
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function onDragStart(self)
    if NS.GetSetting("locked") then return end
    self:StartMoving()
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    savePoint()
end

local function buildChrome()
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -7)
    frame.title:SetText(L["Skill Master"])
    NS.Skin.Shell(frame)
    NS.Skin.Text(frame.title, "title")

    local close = NS.MakeCloseButton(frame, function() W.Hide() end)
    if close then
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
        close:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    end
    frame.close = close

    -- The test-mode marker (preview-mode): a localized text band, readable without hovering.
    frame.strip = NS.Widgets.TestStrip(frame, {
        text  = L["Test mode: the skills shown are sample data."],
        owner = addonName,
        onEnd = function() NS.ToggleTestMode() end,
    })
    if frame.strip then
        frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -TITLE_H)
        frame.strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -TITLE_H)
        frame.strip:SetFrameLevel(frame:GetFrameLevel() + LAYERS.LEVEL.OVERLAY)
    end
end

local function build()
    if frame then return frame end
    frame = CreateFrame("Frame", W.FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata(LAYERS.STRATA.WINDOW)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", onDragStart)
    frame:SetScript("OnDragStop", onDragStop)

    buildChrome()

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.empty:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.empty:SetText(L["No skills to show yet."])
    NS.Skin.Text(frame.empty, "muted")

    -- Escape closes it, as every standalone window does.
    UISpecialFrames[#UISpecialFrames + 1] = W.FRAME_NAME
    frame:Hide()
    W.ApplySettings()
    return frame
end

--- The window's body, one pass. The blocks (T3.2) draw here; today it is the empty state and the
--- test-mode marker.
function W.Render()
    if not frame then return end
    local t0 = Perf.on and debugprofilestop()
    local test = NS.IsTestMode()
    if frame.strip then
        frame.strip:SetShown(test)
        frame.title:SetText(L["Skill Master"])
    else
        frame.title:SetText(test and (L["Skill Master"] .. " - " .. L["Test mode"]) or L["Skill Master"])
    end
    if t0 then Perf.Note("windowRender", debugprofilestop() - t0) end
end

--- Re-apply the stored scale, opacity, lock and position.
function W.ApplySettings()
    if not (frame and NS.db) then return end
    frame:SetScale(NS.GetSetting("scale") or 1)
    frame:SetAlpha(NS.GetSetting("alpha") or 1)
    frame:SetMovable(not NS.GetSetting("locked"))
    applyPoint()
end

--- The window frame, or nil before the first show (the suites and the skin-switch test read it).
function W.Frame() return frame end

function W.IsShown() return frame ~= nil and frame:IsShown() == true end

--- Show the window. Refused while stood down, through the one refusal helper.
function W.Show()
    local refusal = NS.StoodDownRefusal()
    if refusal then NS.Print(refusal) return false end
    build():Show()
    W.Render()
    return true
end

function W.Hide()
    if frame then frame:Hide() end
end

--- The ONE toggle handler: `/skm toggle`, the launcher's Show window entry and the key binding.
function W.Toggle()
    if W.IsShown() then W.Hide() return false end
    return W.Show()
end

--- Re-read state after a mode change.
function W.Refresh()
    if W.IsShown() then W.Render() end
end

--- Stand-down: the window is hidden, and stays hidden (Show refuses).
function W.StandDown() W.Hide() end

--- Reset position (the Master-controls button).
function W.ResetPosition()
    if NS.db then NS.db.profile.window.point = false end
    if frame then applyPoint() end
end

-- The Show window key binding (launcher-§6). The button name is permanent: the client stores the
-- player's key against it, so a rename unbinds every player's key.
W.TOGGLE_BUTTON = "SkillMasterToggleWindow"
do
    local button = CreateFrame("Button", W.TOGGLE_BUTTON, UIParent)   -- plain, not a secure template
    button:RegisterForClicks("AnyDown")                               -- one press, one toggle
    button:SetScript("OnClick", function() W.Toggle() end)            -- the handler itself
    button:Hide()
    W.__toggleButton = button   -- the binding suite drives it by reference
    BINDING_HEADER_SKILLMASTER = NS.Constants.BRAND
    local command = ("CLICK %s:LeftButton"):format(W.TOGGLE_BUTTON)
    rawset(_G, "BINDING_NAME_" .. command, L["Toggle the Skill Master window"])
    NS.BINDINGS = { { command = command, tooltip = L["Shows or hides the Skill Master window."] } }
end
