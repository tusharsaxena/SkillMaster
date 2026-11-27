local _, NS = ...
-- defaults/Gathering_Forever.lua — the skill each mining node and herb needs before it can be
-- gathered (design §8), ascending. Read by modules/Helpers.lua's Nodes(key, rank).
--
-- Validated for GitHub issue #10 (the owner, 2026-11-27: from the sources, not in game): each need is
-- the WoW Forever client's own Lock table (wago.tools wowf 1.60.1.71139; LockType 2 Herbalism, 3
-- Mining) at the lock the 1.12 server gives that node (cMaNGOS classic-db gameobject_template data0),
-- and every name is a ForeverDB object (the seeds run, docs/seed-research/2026-11-27-forever). All 41
-- agree. Forever-only nodes (Starsilver, Cold Iron, Amber...) are not listed: no source gives their
-- lock. The names are localized through NS.L so a non-enUS client shows its own node names once a
-- translator fills them in.

local L = NS.L

NS.Gathering_Forever = {
    mining = {
        verified = "wowf@1.60.1.71139", source = "WoW Forever DB2 Lock (wowf 1.60.1.71139) at the 1.12 node locks (cMaNGOS)",
        { name = L["Copper Vein"],            need = 1 },
        { name = L["Tin Vein"],               need = 65 },
        { name = L["Incendicite Mineral Vein"], need = 65 },
        { name = L["Silver Vein"],            need = 75 },
        { name = L["Lesser Bloodstone Deposit"], need = 75 },
        { name = L["Iron Deposit"],           need = 125 },
        { name = L["Indurium Mineral Vein"],  need = 150 },
        { name = L["Gold Vein"],              need = 155 },
        { name = L["Mithril Deposit"],        need = 175 },
        { name = L["Truesilver Deposit"],     need = 230 },
        { name = L["Dark Iron Deposit"],      need = 230 },
        { name = L["Small Thorium Vein"],     need = 245 },
        { name = L["Rich Thorium Vein"],      need = 275 },
    },
    herbalism = {
        verified = "wowf@1.60.1.71139", source = "WoW Forever DB2 Lock (wowf 1.60.1.71139) at the 1.12 node locks (cMaNGOS)",
        { name = L["Peacebloom"],          need = 1 },
        { name = L["Silverleaf"],          need = 1 },
        { name = L["Earthroot"],           need = 15 },
        { name = L["Mageroyal"],           need = 50 },
        { name = L["Briarthorn"],          need = 70 },
        { name = L["Stranglekelp"],        need = 85 },
        { name = L["Bruiseweed"],          need = 100 },
        { name = L["Wild Steelbloom"],     need = 115 },
        { name = L["Grave Moss"],          need = 120 },
        { name = L["Kingsblood"],          need = 125 },
        { name = L["Liferoot"],            need = 150 },
        { name = L["Fadeleaf"],            need = 160 },
        { name = L["Goldthorn"],           need = 170 },
        { name = L["Khadgar's Whisker"],   need = 185 },
        { name = L["Wintersbite"],         need = 195 },
        { name = L["Firebloom"],           need = 205 },
        { name = L["Purple Lotus"],        need = 210 },
        { name = L["Arthas' Tears"],       need = 220 },
        { name = L["Sungrass"],            need = 230 },
        { name = L["Blindweed"],           need = 235 },
        { name = L["Ghost Mushroom"],      need = 245 },
        { name = L["Gromsblood"],          need = 250 },
        { name = L["Golden Sansam"],       need = 260 },
        { name = L["Dreamfoil"],           need = 270 },
        { name = L["Mountain Silversage"], need = 280 },
        { name = L["Plaguebloom"],         need = 285 },
        { name = L["Icecap"],              need = 290 },
        { name = L["Black Lotus"],         need = 300 },
    },
}
