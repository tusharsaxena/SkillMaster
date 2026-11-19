local _, NS = ...
-- core/WidgetsSetup.lua — NS.Widgets from LibKa0s-Widgets-1.0. Reached today: TestStrip, the windows'
-- test and sim strips, docked under each title bar (`dock = "title"`, Widgets minor 27; the main
-- window, the Journal and the LDB tooltip's Main window style), Footer and FOOTER, the window footers
-- and their height through NS.Chrome.Footer (the main window's legend and the Journal's Alts hint
-- line),
-- Bar, BarStyle, AcquireBar, ReleaseBars, BarText, BarFormatTimer, BarShade and BAR, every data bar
-- (AD-80-SM, LibKa0s#80; the style is NS.BarStyle's, modules/BarStyle.lua),
-- HeaderButtons and HEADER, every window's title-bar marks through NS.Chrome.TitleMarks (AD-86-SM),
-- ContextMenu, the row menu (modules/Interact.lua), and CloseMenu, which the window's OnHide calls
-- so the menu never outlives it.

local lib = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
if lib then
    NS.Widgets = lib
    return
end

-- ── the library-absent data bar ─────────────────────────────────────────────────────────────
-- No fill, no bonus and no marks: a bar of the same height that keeps its text, so a row still
-- reads "107 +25 / 150". Every method the addon calls answers; nothing raises.

local BAR = { TIMER_TICK = 0.2, TIMER_W = 38, INSET = 1, TEMPLATE = "{value} {bonus} / {max}",
              SHADE = { 1, 0.8, 0.64, 0.5 }, PRESETS = {} }

local function barText(value, bonus, cap)
    bonus = tonumber(bonus) or 0
    local mid = bonus > 0 and (" +" .. bonus) or (bonus < 0 and (" " .. bonus) or "")
    return ("%s%s / %s"):format(tostring(tonumber(value) or 0), mid, tostring(tonumber(cap) or 0))
end

local StubBar = {}
function StubBar:SetValues(v)
    v = type(v) == "table" and v or {}
    self.values = v
    self.geom = { fill = 0, bonus = 0, markers = {}, text = v.text or barText(v.value, v.bonus, v.max) }
    self.text:SetText(self.geom.text)
    self.text:SetShown(self.style.showText ~= false)
end
function StubBar:SetTimer() end
function StubBar:ApplyStyle(style)
    self.style = type(style) == "table" and style or self.style or { key = "row" }
    self:SetHeight(tonumber(self.style.height) or 14)
    if self.values then self:SetValues(self.values) end
end
function StubBar:Repaint() self:ApplyStyle(self.style) end
function StubBar:Park() self:ClearAllPoints() end
function StubBar:Layout() end

local function stubBar(parent, opts)
    local bar = CreateFrame("Frame", nil, parent)
    for k, fn in pairs(StubBar) do bar[k] = fn end
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.geom = { fill = 0, bonus = 0, markers = {}, text = "" }
    bar:ApplyStyle(type(opts) == "table" and opts.style or nil)
    return bar
end

-- Degrade, never error: no strip, and the window says "Test mode" in its title instead.
NS.Widgets = {
    Bar        = stubBar,
    BarStyle   = function(key, overrides)
        local s = { key = key or "row" }
        for k, v in pairs(type(overrides) == "table" and overrides or {}) do s[k] = v end
        return s
    end,
    AcquireBar = function(pool, parent, opts)
        pool.free, pool.active = pool.free or {}, pool.active or {}
        local bar = table.remove(pool.free) or stubBar(parent, opts)
        pool.active[#pool.active + 1] = bar
        bar:SetParent(parent)
        bar:ApplyStyle(type(opts) == "table" and opts.style or nil)
        bar:Show()
        return bar
    end,
    ReleaseBars = function(pool)
        local active = pool.active or {}
        for i = #active, 1, -1 do
            active[i]:Park()
            active[i]:Hide()
            pool.free[#pool.free + 1] = active[i]
            active[i] = nil
        end
    end,
    BarText    = barText,
    BarFormatTimer = function(seconds)
        local s = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
        local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
        if h > 0 then return ("%d:%02d:%02d"):format(h, m, s % 60) end
        return ("%d:%02d"):format(m, s % 60)
    end,
    BarShade   = function(c, i)
        local k = BAR.SHADE[i] or BAR.SHADE[#BAR.SHADE]
        return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 }
    end,
    BAR        = BAR,
    TestStrip  = function() return nil end,
    Footer     = function() return nil end,   -- NS.Chrome.Footer builds a bare frame of FOOTER.HEIGHT
    FOOTER     = { HEIGHT = 24, PAD = 8, GRIP = 22, MARK = 16, MARK_ART = 12, MARK_GAP = 4 },
    ContextMenu = function() return nil end,
    CloseMenu  = function() end,
}
