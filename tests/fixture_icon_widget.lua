-- tests/fixture_icon_widget.lua — an AceGUI "Icon" for the harness whose image is a painting Texture
-- on a painting frame, as the client's is (the kit's fake Icon records its image as call arguments,
-- so nothing can be tinted on it). For settings/BoxList.lua's action marks (SD-SK-SM.1): the
-- skin-defaults suite and the BoxList skin-switch surface install it while they run.
--
-- local install = dofile("tests/fixture_icon_widget.lua")
-- local uninstall = install(NS, mocks)   -- then uninstall() to put the harness's Icon back
return function(NS, M)
    local AceGUI = NS.AceGUI or M.__libs["AceGUI-3.0"]
    local reg = AceGUI.WidgetRegistry
    local saved = reg.Icon
    local function ctor()
        reg.Icon = nil
        local w = AceGUI:Create("Icon")   -- the harness's plain widget, its setters and its Release
        reg.Icon = ctor
        w.frame = M.CreateFrame("Button", nil, M.UIParent)
        w.frame.obj = w
        w.image = w.frame:CreateTexture(nil, "ARTWORK")
        w.SetImage = function(self, path) self.image:SetTexture(path) return self end
        return w
    end
    reg.Icon = ctor
    return function() reg.Icon = saved end, AceGUI
end
