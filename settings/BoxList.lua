local addonName, NS = ...
-- settings/BoxList.lua — the boxed list row the Skills page's hide lists and the Layout page's Block
-- order share (feedback round 2, after ConsumableMaster's Priority list): one bounded box per row
-- (LibKa0s-Widgets-1.0's ReorderList row box, options-ui-§18), a drag handle on the left when the
-- list reorders, the entry's icon and name vertically centered, and square action marks on the right.
--
-- NS.OptionsList.Begin(ctx, opts) -> list | nil   opts = { onMove = fn(from, to) | nil }; one per render
-- NS.OptionsList.Row(scroll, list, spec) -> row, label, marks   spec = { text, icon, dimmed, actions = { action... } }
--   action = { image, title, tooltip, dimmed, onClick }
-- NS.OptionsList.Cancel(ctx)                        before anything is drawn (the page's beforeRender)
--
-- The row's name and icon are one AceGUI widget of this addon's own ("SkillMasterListLabel": a fixed
-- row-high frame, the icon and the text centered on it), because AceGUI's Label hangs its text from
-- the top of a row and Flow gives a row no vertical alignment. Nothing is drawn on AceGUI's pooled
-- frames: the box and the handle are the library's, given back by Cancel.

local List = {}
NS.OptionsList = List

-- ROW_H is the box's height, ROW_GAP the spacer after it, STRIDE what the drop arithmetic runs on.
-- The same trio, for the same reason, as ConsumableMaster's Priority list (settings/Category.lua).
List.ROW_H, List.ROW_GAP = 28, 4
List.STRIDE = List.ROW_H + List.ROW_GAP
List.ACTION_W, List.LEAD_W, List.HANDLE_W_FALLBACK = 32, 8, 30
List.ICON = 18

local WIDGET, WIDGET_VERSION = "SkillMasterListLabel", 1

local function aceGUI() return NS.AceGUI or (LibStub and LibStub("AceGUI-3.0", true)) end

local function widgets()
    local W = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
    return W and W.ReorderList and W or nil
end

-- ---------------------------------------------------------------------------------------------
-- The label widget: an icon and a name, centered in a row-high frame
-- ---------------------------------------------------------------------------------------------

local function registerLabel()
    local AceGUI = aceGUI()
    -- The real AceGUI only: a harness factory has no RegisterAsWidget, and its generic widget
    -- answers the same setters (SetText, SetImage, SetColor), so the page draws there too.
    if not (AceGUI and AceGUI.RegisterAsWidget and AceGUI.RegisterWidgetType) then return end
    if (AceGUI.GetWidgetVersion and AceGUI:GetWidgetVersion(WIDGET) or 0) >= WIDGET_VERSION then return end

    local methods = {
        OnAcquire = function(self)
            self:SetHeight(List.ROW_H)
            self:SetText("")
            self:SetImage(nil)
            self:SetColor()
        end,
        SetText = function(self, text) self.label:SetText(text or "") end,
        SetImage = function(self, path)
            self.image:SetTexture(path)
            self.image:SetShown(path ~= nil)
            self.label:ClearAllPoints()
            if path then
                self.label:SetPoint("LEFT", self.image, "RIGHT", 6, 0)
            else
                self.label:SetPoint("LEFT", self.frame, "LEFT", 4, 0)
            end
            self.label:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
        end,
        -- No color: the skin's body text (a token, never a literal: the skin-values gate).
        SetColor = function(self, r, g, b)
            if r then
                self.label:SetTextColor(r, g or r, b or r)
            else
                NS.Skin.Text(self.label, "body")
            end
            self.image:SetDesaturated(r ~= nil)
        end,
    }

    local function constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetHeight(List.ROW_H)
        frame:Hide()
        local image = frame:CreateTexture(nil, "ARTWORK")
        image:SetSize(List.ICON, List.ICON)
        image:SetPoint("LEFT", frame, "LEFT", 4, 0)
        image:SetTexCoord(0.07, 0.93, 0.07, 0.93)   -- the 1.x icon art's baked-in border off
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetWordWrap(false)
        local widget = { type = WIDGET, frame = frame, image = image, label = label }
        for k, fn in pairs(methods) do widget[k] = fn end
        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(WIDGET, constructor, WIDGET_VERSION)
end
registerLabel()

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

function List.Cancel(ctx)
    if ctx and ctx.skmList then ctx.skmList:Cancel() end
    if ctx then ctx.skmList = nil end
end

--- One controller per render: it boxes every row, and with `opts.onMove` gives each a drag handle.
function List.Begin(ctx, opts)
    List.Cancel(ctx)
    local W = widgets()
    if not W then return nil end
    opts = opts or {}
    local list = W.ReorderList({
        stride = List.STRIDE, owner = addonName,
        handleIcon = opts.onMove and NS.Icon and NS.Icon("segment") or nil,
        handleTooltip = opts.onMove and NS.L["Drag to reorder"] or nil,
        onMove = opts.onMove or function() end,
    })
    list.skmReorders = opts.onMove ~= nil
    ctx.skmList = list
    return list
end

local function handleGutter()
    local W = widgets()
    local box = W and W.ROW_BOX
    return (box and box.HANDLE_W) or List.HANDLE_W_FALLBACK
end

--- A fixed slot: the handle's gutter, or a lead space, and what holds the row ROW_H tall.
local function slot(AceGUI, row, width)
    local s = AceGUI:Create("SimpleGroup")
    s:SetLayout(nil)
    s:SetWidth(width)
    s:SetHeight(List.ROW_H)
    row:AddChild(s)
end

local function action(AceGUI, row, a)
    local b = AceGUI:Create("Icon")
    b:SetImage(a.image)
    b:SetImageSize(16, 16)
    b:SetWidth(List.ACTION_W)
    b:SetHeight(List.ROW_H)
    -- The real Icon's SetDisabled(false), run on every acquire, gives the image back its full color,
    -- so a dimmed mark never leaks into the next page that borrows the widget.
    if b.image and b.image.SetVertexColor then b.image:SetVertexColor(1, 1, 1, a.dimmed and 0.35 or 1) end
    if a.onClick then b:SetCallback("OnClick", function() a.onClick() end) end
    if NS.Helpers.AttachTooltip then NS.Helpers.AttachTooltip(b, a.title, a.tooltip) end
    row:AddChild(b)
    return b
end

--- One boxed row in `scroll`: [handle | lead] [icon + name] [actions...], then the gap. Answers the
--- row group, its label and its action marks (the suites read them; nothing is stored on a widget,
--- since AceGUI pools them).
function List.Row(scroll, list, spec)
    local AceGUI = aceGUI()
    if not (AceGUI and scroll) then return nil end
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(List.ROW_H)
    local reorders = list and list.skmReorders
    slot(AceGUI, row, reorders and handleGutter() or List.LEAD_W)
    local label = AceGUI:Create(WIDGET)
    label:SetText(spec.text)
    label:SetImage(spec.icon)
    local muted = spec.dimmed and NS.Bar.Color("sm.muted")
    if muted then label:SetColor(muted[1], muted[2], muted[3]) end
    local actions = spec.actions or {}
    label:SetRelativeWidth(#actions > 0 and (reorders and 0.78 or 0.84) or 0.9)
    row:AddChild(label)
    local marks = {}
    for _, a in ipairs(actions) do marks[#marks + 1] = action(AceGUI, row, a) end
    scroll:AddChild(row)
    if list then
        list:AddRow(row.frame, { ghostText = spec.text, height = List.ROW_H, dimmed = spec.dimmed,
                                 draggable = reorders })
    end
    if NS.Helpers.AddSpacer then NS.Helpers.AddSpacer(scroll, List.ROW_GAP) end
    return row, label, marks
end

--- Close a render's list on its scroll content (the library lays the boxes and handles there).
function List.Finish(list, scroll)
    if list and scroll then list:Finish(scroll.content or scroll.frame) end
end
