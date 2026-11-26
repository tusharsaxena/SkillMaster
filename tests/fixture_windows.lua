-- tests/fixture_windows.lua — the suites' view of the three skill and stat windows as one (SMW-04 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md). Before the split, one window drew the eight
-- skill and stat blocks; the cases written against it read its rows, its headers and its frame. This
-- view shows the Professions, Skills and Character Stats windows together and answers their rows and
-- headers as one list, so those cases keep asserting what each block draws; a member it does not
-- define is the Professions window's (NS.MainWindow). Test code only: the addon has no such group.
return function(NS)
    local FAMILIES = { "professions", "skills", "stats" }
    local function each(fn)
        for _, fid in ipairs(FAMILIES) do fn(NS.Windows.Get(fid)) end
    end
    local view = {}
    function view.Show()
        local ok = true
        each(function(w) ok = w.Show() and ok end)
        return ok
    end
    function view.Hide() NS.Windows.HideAll() end
    function view.Refresh(relayout) NS.Windows.RefreshAll(relayout) end
    function view.RefreshValues() NS.Windows.RefreshValuesAll() end
    function view.ApplySettings() NS.Windows.ApplyAll() end
    function view.Render() each(function(w) w.Render() end) end
    function view.IsShown()
        local shown = true
        each(function(w) shown = shown and w.IsShown() end)
        return shown
    end
    local function concat(member)
        local out = {}
        each(function(w)
            for _, x in ipairs(w[member]()) do out[#out + 1] = x end
        end)
        return out
    end
    function view.Rows() return concat("Rows") end
    function view.Headers() return concat("Headers") end
    function view.HeaderFor(id)
        local w = NS.Windows.ForBlock(id)
        return w and w.HeaderFor(id) or nil
    end
    --- The window block `id` docks in (its frame, its scroll).
    function view.WindowOf(id) return NS.Windows.ForBlock(id) end
    return setmetatable(view, { __index = function(_, k) return NS.MainWindow[k] end })
end
