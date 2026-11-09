local _, NS = ...
-- settings/Profiles.lua — the Profiles page: AceDBOptions drawn by AceConfigDialog into a canvas
-- page, the one untabbed page besides the landing page (options-ui-§13).
--
-- LOAD-BEARING: registers LAST, so Profiles is the last subcategory (options-ui-§3).
local L = NS.L
local APPNAME = "SkillMaster-Profiles"

local function build(parentCategory)
    local AceDBOptions    = LibStub("AceDBOptions-3.0", true)
    local AceConfig       = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = LibStub("AceGUI-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI and NS.db) then return nil end
    local H = NS.Helpers
    AceConfig:RegisterOptionsTable(APPNAME, AceDBOptions:GetOptionsTable(NS.db))
    local ctx = H.CreatePanel("SkillMasterProfilesPanel", L["Profiles"], {
        pageKey = "profiles", defaultsButton = false,
    })
    local container
    H.SetRenderer(ctx, function()
        if not container then
            container = AceGUI:Create("SimpleGroup")
            container:SetLayout("Fill")
            container.frame:SetParent(ctx.body)
            container.frame:ClearAllPoints()
            container.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", 8, -8)
            container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
        end
        container.frame:Show()
        AceConfigDialog:Open(APPNAME, container)
        NS.SkinPaintAceTree(container)
    end)
    return Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, L["Profiles"])
end

NS.RegisterOptionsPage("profiles", L["Profiles"], build)
