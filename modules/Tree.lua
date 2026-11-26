local _, NS = ...
-- modules/Tree.lua — the tree row model and its folds (item SMW-03 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md; the spec's "Tree blocks and folding"). One model
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
