local _, NS = ...
-- modules/SubBlocks.lua — detached sub-categories (R5-SM-09, owner feedback round 5, addendum A1: "Allow
-- detaching sub categories (e.g. Alliance, Other here) ... Or any of the nested sub categories here ... or sub
-- categories here"). Every header of a tree family (a reputation header such as Alliance or Steamwheedle Cartel,
-- a Statistics category at any depth such as Character or Wealth, a currency header such as Player vs. Player)
-- carries a detach mark (modules/Rows.lua). Detached, it is a window of its own, drawn exactly as a detached
-- block is (modules/Detached.lua): it moves, joins other windows (modules/Groups.lua), resizes, remembers its
-- place and its collapse, and survives /reload; its rows are the header's subtree, and the window it came from
-- leaves that subtree out while it is detached (modules/BlockProviders.lua). Its dock mark puts it back.
--
-- A sub-block's id is "sub:<family>:<nodeKey>": the header's fold key (modules/Tree.lua's NodeKey), stable across
-- sessions: a faction header's factionID, a currency header's "<name>#<depth>", a Statistics categoryID. It looks
-- like a block everywhere a block is read: NS.BlockDefs[id] answers SB.Def(id) (title and short its header's
-- name, source its family's, filter its node key) and NS.Blocks.Settings(id) its stored row.
--
-- profile.layout.subs[id] = { docked = false, name, collapsed, point, width } is named non-setting state
-- (architecture-§5); this module is its one owner (Detach, Dock, SetCollapsed, SetWidth; the drag's drop point
-- through NS.Detached, as a block's). A row is present only while its sub-category is detached. The LDB tooltip
-- keeps the whole tree: a detached sub-category leaves its window, not its feed.
--
-- NS.SubBlocks.Id(family, nodeKey) / .Parse(id) / .IsSub(id) / .Ids() / .Settings(id) / .Def(id) / .Name(id) /
--   .Absent(id) / .Detach(family, nodeKey, name) / .Dock(id) / .SetCollapsed(id, v) / .SetWidth(id, w) / .Normalize(subs) /
--   .Subtree(order, node) / .Without(order, family) / .OpenStore(order, family, node) / .Shown(family)

NS.SubBlocks = {}
local SB = NS.SubBlocks
local L = NS.L

SB.PREFIX = "sub:"

--- The id of `family`'s header `nodeKey` detached.
function SB.Id(family, nodeKey) return SB.PREFIX .. tostring(family) .. ":" .. tostring(nodeKey) end

local function treeFamily(family)
    local fam = family and NS.Families[family]
    return fam ~= nil and fam.tree == true
end

--- The family and node key of sub-block `id`, or nil for any other id.
function SB.Parse(id)
    if type(id) ~= "string" or id:sub(1, #SB.PREFIX) ~= SB.PREFIX then return nil end
    local family, node = id:sub(#SB.PREFIX + 1):match("^([^:]+):(.+)$")
    if not treeFamily(family) then return nil end
    return family, node
end

function SB.IsSub(id) return SB.Parse(id) ~= nil end

--- `subs` made well formed, in place (pure: the suites and the schemaVersion 18 step drive it): an id that is no
--- sub-block's or a row that is no table goes; each kept row is detached, its name a string or nil, its point a
--- table or false, its width a block's (NS.Groups.Model.CleanWidth) or nil, its collapse a boolean.
function SB.Normalize(subs)
    if type(subs) ~= "table" then return subs end
    for id, s in pairs(subs) do
        if not SB.IsSub(id) or type(s) ~= "table" then
            subs[id] = nil
        else
            s.docked = false
            if type(s.name) ~= "string" then s.name = nil end
            if type(s.point) ~= "table" then s.point = false end
            s.width = NS.Groups.Model.CleanWidth(s.width)
            s.collapsed = s.collapsed == true
        end
    end
    return subs
end

local function store()
    local layout = NS.db and NS.db.profile.layout
    if not layout then return nil end
    if type(layout.subs) ~= "table" then layout.subs = {} end
    return layout.subs
end

--- Sub-block `id`'s stored row while it is detached, else nil.
function SB.Settings(id)
    local s = store()
    local row = s and SB.IsSub(id) and s[id]
    return type(row) == "table" and row or nil
end

--- The detached sub-blocks' ids, sorted (a stable order to draw and place in).
function SB.Ids()
    local out = {}
    for id, s in pairs(store() or {}) do
        if type(s) == "table" and SB.IsSub(id) then out[#out + 1] = id end
    end
    table.sort(out)
    return out
end

-- The model family `family` draws now: test mode's sample (the block engine's source), else its own provider's
-- live model alone (never every provider's: a def is read on every render).
local function modelOf(family)
    local fam, B = NS.Families[family], NS.Blocks
    if not (fam and B) then return nil end
    if B.source then return (B.Models() or {})[fam.source] end
    local provider = B.PROVIDERS and B.PROVIDERS[fam.source]
    return provider and provider.model() or nil
end

local function headerIn(order, node)
    for i, e in ipairs(type(order) == "table" and order or {}) do
        if e.header and e.nodeKey ~= nil and tostring(e.nodeKey) == tostring(node) then return i, e end
    end
    return nil
end

--- What sub-block `id`'s window is titled: its header's name in the model now, else the name stored at the detach.
function SB.Name(id)
    local family, node = SB.Parse(id)
    if not family then return tostring(id) end
    local m = modelOf(family)
    local _, e = headerIn(m and m.order, node)
    if e and e.name and e.name ~= "" then return e.name end
    local s = SB.Settings(id)
    return (s and s.name) or tostring(node)
end

--- Whether sub-block `id`'s header is missing from this character's tree (R5-REV): its family's model, read in
--- full, holds no such header (another character's faction header or currency group on a shared profile, a
--- header another locale names otherwise). Its window then stays hidden and its row is kept. Unknown is not
--- missing: no model yet, an empty one, or a partial read (combat, the panel up).
function SB.Absent(id)
    local family, node = SB.Parse(id)
    if not family then return false end
    local m = modelOf(family)
    if type(m) ~= "table" or type(m.order) ~= "table" or #m.order == 0 or m.complete == false then return false end
    return headerIn(m.order, node) == nil
end

--- Sub-block `id` as a block def (NS.BlockDefs' shape), or nil for any other id.
function SB.Def(id)
    local family, node = SB.Parse(id)
    if not family then return nil end
    local name = SB.Name(id)
    return { id = id, title = name, short = name, source = NS.Families[family].source, filter = node,
             family = family, sub = true, node = node }
end

local function changed()
    if NS.Blocks and NS.Blocks.Changed then NS.Blocks.Changed() end
end

--- Detach `family`'s header `nodeKey` (named `name`) into its own window. Answers its id, or nil when it is no tree
--- family's header or is detached already.
function SB.Detach(family, nodeKey, name)
    if not treeFamily(family) or nodeKey == nil then return nil end
    local s = store()
    local id = SB.Id(family, nodeKey)
    if not s or s[id] ~= nil then return nil end
    s[id] = { docked = false, collapsed = false, point = false, name = type(name) == "string" and name or nil }
    NS.Debug("Layout", "detached %s", id)
    changed()
    return id
end

--- Put sub-block `id` back into the window it came from (its dock mark, Dock all). Answers whether it was detached.
function SB.Dock(id)
    local s = store()
    if not (s and SB.Settings(id)) then return false end
    s[id] = nil
    if NS.Groups then NS.Groups.Leave(id) end
    NS.Debug("Layout", "docked %s", id)
    changed()
    return true
end

--- Collapse (true) or open sub-block `id`'s window. Answers whether it changed.
function SB.SetCollapsed(id, collapsed)
    local s = SB.Settings(id)
    if not s then return false end
    collapsed = collapsed and true or false
    if s.collapsed == collapsed then return false end
    s.collapsed = collapsed
    changed()
    return true
end

--- Sub-block `id`'s window width (its resize grip's release), in a block's range.
function SB.SetWidth(id, w)
    local s = SB.Settings(id)
    if not s then return false end
    s.width = NS.Groups.Model.CleanWidth(w)
    changed()
    return true
end

-- ---------------------------------------------------------------------------------------------
-- The rows: a header's subtree, and a window's tree without its detached subtrees
-- ---------------------------------------------------------------------------------------------

--- The entries under header `node` of `order` (every later entry deeper than it), and the depth they rebase by
--- (the header's own plus one, so its children draw at depth 0). An absent header answers none.
function SB.Subtree(order, node)
    local i, h = headerIn(order, node)
    if not i then return {}, 0 end
    local depth, out = h.depth or 0, {}
    for j = i + 1, #order do
        local e = order[j]
        if (e.depth or 0) <= depth then break end
        out[#out + 1] = e
    end
    return out, depth + 1
end

--- The node keys of `family` detached now, as a set of strings.
local function detachedNodes(family)
    local set, any = {}, false
    for _, id in ipairs(SB.Ids()) do
        local f, node = SB.Parse(id)
        if f == family then set[node], any = true, true end
    end
    return set, any
end

--- `order` without the detached sub-categories of `family` (each header and its subtree): what a window draws.
--- Answers `order` itself when none is detached.
function SB.Without(order, family)
    local set, any = detachedNodes(family)
    if not any then return order end
    local out, skipBelow = {}, nil
    for _, e in ipairs(order) do
        local depth = e.depth or 0
        if not (skipBelow and depth > skipBelow) then
            skipBelow = nil
            if e.header and e.nodeKey ~= nil and set[tostring(e.nodeKey)] then
                skipBelow = depth
            else
                out[#out + 1] = e
            end
        end
    end
    return out
end

--- A fold store for reading a detached sub-category's rows (the Statistics' lazy reads, SD:Open): header `node`
--- and every header above it read as open, every other node as the window's own folds have it.
function SB.OpenStore(order, family, node)
    local open = { [tostring(node)] = true }
    local i, h = headerIn(order, node)
    if i then
        local depth = h.depth or 0
        for j = i - 1, 1, -1 do
            local e = order[j]
            if e.header and e.nodeKey ~= nil and (e.depth or 0) < depth then
                open[tostring(e.nodeKey)] = true
                depth = e.depth or 0
            end
        end
    end
    local base = NS.Tree.Store(family)
    return setmetatable({}, { __index = function(_, k)
        if open[k] then return false end
        return base[k]
    end })
end

--- Whether a window of `family`'s detached sub-categories shows now (their own, or a merged window holding one).
function SB.Shown(family)
    local D, G = NS.Detached, NS.Groups
    for _, id in ipairs(SB.Ids()) do
        if SB.Parse(id) == family then
            local f = D and D.Frame(id)
            if f and f:IsShown() then return true end
            local gid = G and G.Of(id)
            local g = gid and G.Frame(gid)
            if g and g:IsShown() then return true end
        end
    end
    return false
end

SB.DETACH_TIP = L["Detach this category into its own window"]
