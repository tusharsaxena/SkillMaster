local _, NS = ...
-- modules/Tree.lua — the tree row model and its folds (item SMW-03 of
-- docs/superpowers/plans/2026-11-26-characterledger-windows.md; the spec's "Tree blocks and folding"). One model
-- serves the Reputations, Currencies and Statistics windows and their LDB tooltips.
--
-- An entry is { depth, header, nodeKey, ... } in display order: a header row (a chevron and its title,
-- indented by depth) or a leaf row (a bar or a value). The children of a folded header, every row after it
-- deeper than it, are skipped, so folding a parent hides an open child while keeping the child's own fold.
--
-- THE FOLDS ARE THIS ADDON'S OWN. Reputation and currency headers are also client state shared with the
-- character panel (docs/forever-quirks.md, "Reputations, currencies and Statistics"); a fold here never
-- calls the client's Expand or Collapse, so folding in a window never moves the player's panel. The store is
-- char.fold[family][nodeKey] (named non-setting state; this file is its one writer): true folded, false
-- open, absent the family's default. Keys are strings (Tree.NodeKey), so a number and its string are one key.
-- While test mode or a simulation runs, the folds go to a session store instead (preview-mode: nothing of
-- the live state is written for a sample); it lasts until the UI reloads and is never saved.
--
-- NS.Tree.IsFolded(family, key[, store]) / .SetFolded(family, key, folded[, store]) / .Toggle(family, key[,
--   store]) / .SetAll(family, entries, folded[, store]) / .Visible(entries, family[, store]) /
--   .NodeKey(family, row) / .Store(family). `store`, when given, is a family's own fold table (the LDB
--   tooltip keeps its own, the owner's ruling); else the window's.

NS.Tree = {}
local Tree = NS.Tree

Tree.INDENT = 12   -- px per depth level

-- A family whose headers start folded (the spec's call: every Statistics category starts folded;
-- reputation and currency headers start open).
Tree.DEFAULT_FOLDED = { statistics = true }

-- The node key a header row is folded by, per family (the spec): the header's factionID; the header's
-- name plus its depth (a currency header's currencyID may be 0); the categoryID.
local KEYS = {
    reputations = function(row) return row.factionID end,
    currencies = function(row)
        if row.name == nil or row.currencyListDepth == nil then return nil end
        return tostring(row.name) .. "#" .. tostring(row.currencyListDepth)
    end,
    statistics = function(row) return row.categoryID end,
}

--- The fold key of a client row of `family`, as a string, or nil when the row carries none.
function Tree.NodeKey(family, row)
    local fn = KEYS[family]
    local key = fn and type(row) == "table" and fn(row)
    if key == nil or key == false then return nil end
    return tostring(key)
end

local session = {}   -- family -> folds, while test mode or a simulation runs

local function sampleRunning()
    return NS.IsTestMode() or (NS.IsSimRunning ~= nil and NS.IsSimRunning()) or false
end

--- The window's fold table for `family`: char.fold[family], made on first use, or the session's
--- while test mode or a simulation runs.
function Tree.Store(family)
    if sampleRunning() then
        session[family] = session[family] or {}
        return session[family]
    end
    local char = NS.db and NS.db.char
    if not char then
        session[family] = session[family] or {}
        return session[family]
    end
    char.fold = char.fold or {}
    char.fold[family] = char.fold[family] or {}
    return char.fold[family]
end

local function storeOf(family, store)
    if store then return store end
    if sampleRunning() then return Tree.Store(family) end
    local fold = NS.db and NS.db.char and NS.db.char.fold
    return fold and fold[family] or nil   -- a read never creates the table
end

--- Whether node `key` of `family` is folded: its stored choice, else the family's default.
function Tree.IsFolded(family, key, store)
    if key == nil then return false end
    local s = storeOf(family, store)
    local v = s and s[tostring(key)]
    if v == nil then return Tree.DEFAULT_FOLDED[family] == true end
    return v == true
end

local function changed()
    if NS.Blocks and NS.Blocks.Changed then NS.Blocks.Changed() end
end

--- Stores node `key`'s fold; a keyless node is never stored. Sends LAYOUT_CHANGED (the window redraws).
function Tree.SetFolded(family, key, folded, store)
    if key == nil then return nil end
    local s = store or Tree.Store(family)
    s[tostring(key)] = folded and true or false
    NS.Debug("Click", "%s %s in %s", folded and "folded" or "opened", tostring(key), family)
    changed()
    return folded and true or false
end

--- Flips node `key`'s fold; answers the new state (true folded), nil for a keyless node.
function Tree.Toggle(family, key, store)
    if key == nil then return nil end
    return Tree.SetFolded(family, key, not Tree.IsFolded(family, key, store), store)
end

--- Folds (true) or opens (false) every header among `entries`, with one LAYOUT_CHANGED.
function Tree.SetAll(family, entries, folded, store)
    local s = store or Tree.Store(family)
    for _, e in ipairs(entries or {}) do
        if e.header and e.nodeKey ~= nil then s[tostring(e.nodeKey)] = folded and true or false end
    end
    changed()
end

--- The rows `entries` shows under `family`'s folds, in order: each { entry, depth, indent, header,
--- folded, chevron } (chevron "chevron-right" folded, "chevron-down" open, nil for a leaf).
function Tree.Visible(entries, family, store)
    local out, skipBelow = {}, nil
    for _, e in ipairs(entries or {}) do
        local depth = e.depth or 0
        local inside = skipBelow ~= nil and depth > skipBelow   -- under a folded header: skipped
        if not inside then
            skipBelow = nil
            local header = e.header == true
            local folded = header and Tree.IsFolded(family, e.nodeKey, store) or false
            out[#out + 1] = { entry = e, depth = depth, indent = depth * Tree.INDENT, header = header,
                              folded = folded,
                              chevron = header and (folded and "chevron-right" or "chevron-down") or nil }
            if folded then skipBelow = depth end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The tree families' row kinds (SMW-08..10): what a row of each kind draws and says, registered by its data
-- module (modules/RepData.lua's "reputation", ...). The rows (NS.Rows SetTree), the row tooltip, the broker's
-- pins and lines and the row menu's link read them, so a new kind adds a spec and no branch there. A spec:
--   family            the family whose window draws it
--   values(e)         the bar's values ({ value, max, text, color }), or nil for a row with no bar
--   valueText(e)      the value as text (Rows show: Value only, the Classic tooltip's right column)
--   lines(e)          the row tooltip's lines (NS.RowTooltip's shape)
--   pinText(e)        its text in its feed's {pinned}
--   linkText(e)       its text in chat (a shift-click)
--   icon(e)           its in-game icon texture, or nil
--   pinnable(e)       optional: whether its row menu offers a pin (default: a row whose hasBar is not false)
-- ---------------------------------------------------------------------------------------------

local kinds = {}

--- Register the row kind `kind` (see above).
function Tree.RegisterKind(kind, spec)
    spec.kind = kind
    kinds[kind] = spec
    return spec
end

--- The spec of row kind `kind`, or nil for a kind no tree family registered (a skill, a stat).
function Tree.Kind(kind) return kind ~= nil and kinds[kind] or nil end

--- `entries` (a tree model's order) as block rows under `family`'s folds (`store`, the window's when nil):
--- each { kind, entry, depth, indent, header, folded, chevron, sigKey }, the shape NS.Blocks lays.
function Tree.Rows(entries, family, kind, store)
    local out = {}
    for i, r in ipairs(Tree.Visible(entries, family, store)) do
        r.kind = kind
        r.sigKey = tostring(r.entry.key) .. (r.header and (r.folded and "-" or "+") or "")
        out[i] = r
    end
    return out
end

--- `n` as a whole number with thousands separators ("12,000"); a non-number as text.
function Tree.Number(n)
    local v = tonumber(n)
    if not v then return tostring(n or "") end
    local s = tostring(math.floor(math.abs(v) + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (v < 0 and "-" or "") .. out
end
