local _, NS = ...
-- defaults/Racials_Forever.lua — the racial weapon-skill bonuses Bonuses attributes as permanent
-- (design §5.2, plan Task 2.2). Keyed by UnitRace's second return (the race file token), then by
-- the skill catalog's stable key (defaults/SkillCatalog_Forever.lua, T2.1).

--
-- WoW Forever has NONE (GitHub issue #10; wago.tools product wowf, build 1.60.1.71139). The racial
-- skill lines (754 Human, 125 Orc, 101 Dwarf, 733 Troll) hold no spell whose SpellEffect adds weapon
-- skill. Vanilla's Sword Specialization (20597) is "Ruthless" (+1% crit) and Axe Specialization
-- (20574) "Savage" (+1% crit); Mace (20864), Gun (20595), Bow (26290) and Throwing (20558)
-- Specialization are gone from SpellName. The only +5 weapon-skill spells are ring runes (442813...),
-- which say they do not stack with racials. Gnome Engineering Specialization (20593) adds no skill.
-- So byRace is empty; Bonuses keeps the hook for a client that has them.

NS.Racials_Forever = {
    source   = "WoW Forever DB2 (wowf 1.60.1.71139): no racial weapon-skill bonus; vanilla's Weapon "
        .. "Specializations are removed or repurposed as crit passives",
    verified = "wowf@1.60.1.71139",
    byRace = {},
}
