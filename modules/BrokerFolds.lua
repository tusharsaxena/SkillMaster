local _, NS = ...
-- modules/BrokerFolds.lua — the LDB tooltip's own folds (item SMW-07 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md; the spec's "The LDB tooltip: only the fold
-- works"). The owner's ask: in the tooltip, a category's expand/collapse chevron is the one interaction, and
-- its fold is the tooltip's alone (the owner's ruling): folding a section there never collapses its block in
-- the window, nor a window's collapse the tooltip's section.
--
-- The store is tooltips.ldb.folds (named non-setting state, per profile; this file is its one writer):
--   blocks[blockId] = true   a folded section (absent: open)
--   nodes[family]            a tree family's header folds, as NS.Tree takes a fold table (modules/Tree.lua:
--                            true folded, false open, absent the family's default)
-- Each toggle redraws the tooltip in place (NS.Broker.RedrawTooltip), keeping its scroll.
--
-- NS.Broker.TipFolded(id) / .SetTipFolded(id, folded) / .ToggleTipFold(id) / .TipNodeStore(family) /
-- .ToggleTipNode(family, key)

local B = NS.Broker

local function store()
    local p = NS.db and NS.db.profile
    local t = type(p) == "table" and p.tooltips
    local ldb = type(t) == "table" and t.ldb
    if type(ldb) ~= "table" then return nil end
    if type(ldb.folds) ~= "table" then ldb.folds = {} end
    local f = ldb.folds
    if type(f.blocks) ~= "table" then f.blocks = {} end
    if type(f.nodes) ~= "table" then f.nodes = {} end
    return f
end

--- Whether block `id`'s section is folded in the LDB tooltip.
function B.TipFolded(id)
    local f = store()
    return f ~= nil and f.blocks[id] == true
end

--- Fold (true) or open (false) block `id`'s section in the LDB tooltip. Answers the state stored.
function B.SetTipFolded(id, folded)
    local f = store()
    if not (f and id) then return nil end
    f.blocks[id] = folded and true or nil
    NS.Debug("Click", "%s %s in the LDB tooltip", folded and "folded" or "opened", tostring(id))
    return folded and true or false
end

--- A section chevron's click: flip block `id`'s fold and draw the tooltip again where it stands. Answers
--- the new state (true folded).
function B.ToggleTipFold(id)
    local now = B.SetTipFolded(id, not B.TipFolded(id))
    B.RedrawTooltip()
    return now
end

--- The LDB tooltip's fold table for tree family `family` (NS.Tree's `store` argument), made on first use.
function B.TipNodeStore(family)
    local f = store()
    if not f then return {} end
    if type(f.nodes[family]) ~= "table" then f.nodes[family] = {} end
    return f.nodes[family]
end

--- A tree header's chevron in the tooltip: flip node `key` of `family` in the tooltip's own folds, never the
--- window's, and draw the tooltip again. Answers the new state (true folded), nil for a keyless node.
function B.ToggleTipNode(family, key)
    local now = NS.Tree.Toggle(family, key, B.TipNodeStore(family))
    B.RedrawTooltip()
    return now
end
