local _, NS = ...
-- modules/AltsTrees.lua — the Journal's Alts sub-tabs of the tree families (items SMW-08 and SMW-09 of
-- docs/superpowers/plans/2026-11-26-skillmaster-windows.md): Reputations (#6), each character's standing with
-- every faction its snapshot holds (modules/Alts.lua, record.reps), and Currencies (#7), each character's amount
-- of every currency (record.currencies), a bar where it has a cap. Statistics has no sub-tab (the spec's call).
-- Registered with modules/Journal.lua (J.RegisterAltRows / J.RegisterAltKind), which draws them.

local J = NS.Journal

--- Every key of `set` (a record's snapshot set by name) across `list`'s records, by name: keys, names.
local function unionByName(list, set)
    local names, keys = {}, {}
    for _, item in ipairs(list) do
        for key, v in pairs(item.record[set] or {}) do
            if not names[key] then
                names[key] = v.name or key
                keys[#keys + 1] = key
            end
        end
    end
    table.sort(keys, function(a, b)
        if names[a] ~= names[b] then return tostring(names[a]) < tostring(names[b]) end
        return a < b
    end)
    return keys, names
end
J.UnionByName = unionByName

J.RegisterAltRows("reputations", "reputation", function(list) return unionByName(list, "reps") end)
J.RegisterAltKind("reputation", "reps", function(cell, v)
    cell.value:SetText(v.standing or "")
    local color = NS.Compat.FactionBarColor(v.reaction) or NS.SkinColor("sm.barFill")
    J.CellBar(cell, v.exalted and 1 or (tonumber(v.value) or 0), v.exalted and 1 or math.max(tonumber(v.max) or 1, 1), color)
end, function(v, key, name)   -- the Reputations window's row (RepData's kind): a snapshot holds barred rows only
    return { key = key, name = v.name or name, reaction = v.reaction, standing = v.standing, value = v.value,
             max = v.max, exalted = v.exalted, hasBar = true }
end)

J.RegisterAltRows("currencies", "currency", function(list) return unionByName(list, "currencies") end)
J.RegisterAltKind("currency", "currencies", function(cell, v)
    local q, max = tonumber(v.quantity) or 0, tonumber(v.maxQuantity) or 0
    cell.value:SetText(max > 0 and ("%s / %s"):format(NS.Tree.Number(q), NS.Tree.Number(max)) or NS.Tree.Number(q))
    if max <= 0 then return cell.bar:Hide() end
    J.CellBar(cell, math.min(q, max), max, NS.BarStyle.Swatch("barColor", "sm.barFill", "useClassColorBar"))
end, function(v, key, name)   -- the Currencies window's row (CurrencyData's kind): a bar where it has a cap
    local q, max = tonumber(v.quantity) or 0, tonumber(v.maxQuantity) or 0
    return { key = key, name = v.name or name, quantity = q, maxQuantity = max, icon = v.icon, hasBar = max > 0 }
end)
