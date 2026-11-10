local _, NS = ...
-- modules/Detached.lua — a detached block's own frame (design §2 goal 4, mockup "Detached"): a HUD
-- display (frame-layering-§1 T1, MEDIUM) with a title band (the block's title, its collapse and dock
-- controls) and the block's rows in the compact bar style, movable unless locked, its drop point
-- stored in profile.layout.blocks[id].point (geometry only a drag sets; this module is its one
-- writer, docs/ARCHITECTURE.md).
--
-- The weapon block is the mockup's compact preset: the equipped weapons carry the marker, and with
-- profile.layout.blocks.weapon.belowCapOnly only the equipped weapons and the skills below their
-- cap are shown. An equipment change redraws it.
--
-- NS.Detached.Refresh(anchor) / .RefreshValues() / .StandDown() / .Frame(id) / .Rows(id) / .Render(id)
-- NS.Detached.Entries(id) -> the entries a detached frame draws

NS.Detached = {}
local D = NS.Detached
local LAYERS = NS.Constants.LAYERS
local Perf = NS.Perf

D.WIDTH, D.TITLE_H, D.PAD = 300, 22, 4
D.STYLE = "compact"

local frames = {}

function D.Frame(id) return frames[id] end

--- The rows a detached frame is showing (the suites read them).
function D.Rows(id)
    local f = frames[id]
    return f and f.rowPool.active or {}
end

local function settings(id) return NS.Blocks.Settings(id) end

--- A detached block's strata: the player's pick, one of STRATA_CHOICES, else the HUD tier's.
function D.Strata()
    local layout = (NS.db and NS.db.profile.layout) or NS.defaults.profile.layout
    for _, v in ipairs(LAYERS.STRATA_CHOICES) do if v == layout.detachedStrata then return v end end
    return LAYERS.STRATA.HUD
end

local function isLocked(id)
    return NS.GetSetting("locked") or settings(id).locked == true
end

local function savePoint(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    if type(point) ~= "string" then return end
    settings(f.id).point = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
end

local function applyPoint(f)
    local p = settings(f.id).point
    f:ClearAllPoints()
    if type(p) == "table" then
        f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        -- A first detach lands right of center, stepped per block so two do not stack exactly.
        local step = 0
        for i, id in ipairs(NS.BLOCKS) do if id == f.id then step = i end end
        f:SetPoint("TOPLEFT", UIParent, "CENTER", 240, 200 - 24 * step)
    end
    f:SetScale(settings(f.id).scale or 1)
    -- The player's strata for every detached block (Layout > Detached block strata); the crafting
    -- overlays take it on the sync Refresh ends with.
    f:SetFrameStrata(D.Strata())
end

local function onDragStart(self)
    if isLocked(self.id) then return end
    self:StartMoving()
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(self, true) end
end

local function onDragStop(self)
    self:StopMovingOrSizing()
    savePoint(self)
    if NS.SecureOverlay then NS.SecureOverlay:SetMoving(self, false) end
end

local function belowCapOnly(id)
    return id == "weapon" and settings(id).belowCapOnly == true
end

--- The entries detached block `id` draws: the block's, the equipped weapons marked, and for the
--- weapon block's compact filter only the equipped ones and the learned skills below their cap.
function D.Entries(id)
    local entries = NS.Blocks.Entries(id)
    if id ~= "weapon" then return entries end
    local equipped = NS.SkillHelpers.EquippedWeaponSkills()
    local filter = belowCapOnly(id)
    local out = {}
    for _, r in ipairs(entries) do
        local e = r.entry
        local on = equipped[e.key] == true
        if not filter or on or (e.learned ~= false and (e.rank or 0) < (e.max or 0)) then
            out[#out + 1] = { kind = r.kind, entry = e, marked = on }
        end
    end
    return out
end

local function buildBand(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetText(NS.BlockDefs[f.id].title)
    NS.Skin.Text(f.title, "heading")
    -- The attach mark: the header's detach mark (external-link) turned 180 degrees (FB-15).
    f.dock = NS.Chrome.IconButton(f, "external-link", "-", function() NS.Blocks:Dock(f.id) end,
        NS.L["Dock this block in the main window"])
    NS.Chrome.SetIcon(f.dock, "external-link", "-", true)
    f.collapse = NS.Chrome.IconButton(f, "chevron-down", "v", function() NS.Blocks:ToggleCollapsed(f.id) end)
    f.dock:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    f.collapse:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CHROME)
    NS.Skin.Header(f, { title = f.title, align = "LEFT", right = { f.dock, f.collapse } })
    if not f.dock:GetPoint(1) then
        f.dock:SetPoint("TOPRIGHT", f, "TOPRIGHT", -D.PAD, -2)
        f.collapse:SetPoint("RIGHT", f.dock, "LEFT", -2, 0)
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -5)
    end
end

local function build(id)
    local f = CreateFrame("Frame", "SkillMasterBlock_" .. id, UIParent, "BackdropTemplate")
    f:SetFrameStrata(LAYERS.STRATA.HUD)
    f.id = id
    f:SetWidth(D.WIDTH)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", onDragStart)
    f:SetScript("OnDragStop", onDragStop)
    if NS.SecureOverlay then NS.SecureOverlay:Follow(f) end
    f.body = CreateFrame("Frame", nil, f)
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -D.TITLE_H)
    f.body:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -D.TITLE_H)
    f.body:SetFrameLevel(f:GetFrameLevel() + LAYERS.LEVEL.CONTENT)
    f.rowPool = NS.Rows.NewPool()
    NS.Skin.Shell(f)
    buildBand(f)
    frames[id] = f
    return f
end

--- Draw block `id` into its frame: the rows (none while collapsed) and the frame's height.
function D.Render(id)
    local f = frames[id]
    if not f then return end
    local t0 = Perf.on and debugprofilestop()
    NS.Rows.ReleaseAll(f.rowPool)
    local collapsed = settings(id).collapsed
    NS.Chrome.SetIcon(f.collapse, collapsed and "chevron-right" or "chevron-down",
        collapsed and ">" or "v")
    local y = 0
    if not collapsed then
        y = NS.Blocks.LayRows(D.Entries(id), f.body, f.rowPool, 0, D.STYLE, D.PAD)
    end
    f.body:SetHeight(math.max(y, 1))
    f:SetHeight(D.TITLE_H + y + D.PAD)
    f:SetMovable(not isLocked(id))
    if t0 then Perf.Note("detachedRender", debugprofilestop() - t0) end
end

--- Show every detached block's frame and hide every docked block's. Nothing shows while stood down.
--- `anchor == false` (a data repaint) leaves a frame already on screen where it is, so a frame the
--- player is dragging is not re-anchored; a layout change, a first show and the default re-anchor.
function D.Refresh(anchor)
    local down = NS.IsStoodDown and NS.IsStoodDown()
    for _, id in ipairs(NS.BLOCKS) do
        local s = settings(id)
        local f = frames[id]
        if s.docked == false and not down then
            f = f or build(id)
            if anchor ~= false or not f:IsShown() then applyPoint(f) end
            f:Show()
            D.Render(id)
        elseif f then
            NS.Rows.ReleaseAll(f.rowPool)
            f:Hide()
        end
    end
    NS.Blocks.UpdateSpeedWatch()
    if NS.SecureOverlay then NS.SecureOverlay:Sync() end
end

--- Redraw the shown rows' values without moving anything (a bonus tick, combat).
function D.RefreshValues()
    local lookup
    for _, f in pairs(frames) do
        if f:IsShown() then
            lookup = lookup or NS.Blocks.Lookup(NS.Blocks.Data())
            NS.Rows.RefreshValues(f.rowPool, lookup)
        end
    end
end

--- Stand-down: every detached frame hidden, its rows parked.
function D.StandDown()
    for _, f in pairs(frames) do
        NS.Rows.ReleaseAll(f.rowPool)
        f:Hide()
    end
end

-- The equipped marker and the compact filter follow the equipment: a shown weapon block redraws.
-- A tracked bus target, stood down with the addon (LibKa0s-Bus-1.0).
local function onEquipmentChanged()
    local f = frames.weapon
    if f and f:IsShown() then
        D.Render("weapon")
        if NS.SecureOverlay then NS.SecureOverlay:Sync() end
    end
end

D.events = NS.NewBusTarget()
if D.events then
    NS.SafeRegisterEvent(D.events, "PLAYER_EQUIPMENT_CHANGED", onEquipmentChanged, NS.rejectedEvents)
end
