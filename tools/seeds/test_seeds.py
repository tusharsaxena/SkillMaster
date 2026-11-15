#!/usr/bin/env python3
"""tools/seeds/test_seeds.py: offline tests for seeds.py (unittest; pytest runs them too).

No network: every DB2 table is a tiny fixture CSV written to a temporary folder, and every seed
file a few lines of Lua in the shape defaults/ uses.

    python3 -m pytest -q tools/seeds
    python3 -m unittest discover -s tools/seeds

MUTATION-CHECKED (2026-11-15): test_apply_refuses_while_unruled was run against a seeds.py whose
plan_apply guard (`if unruled: raise SystemExit(...)`) was commented out. It failed (the apply went
ahead and removed the row), and passed again once the guard was restored.
"""

from __future__ import annotations

import gzip
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import seeds  # noqa: E402

TABLES = {
    "UiMap": "Name_lang,ID,ParentUiMapID,Flags,System,Type\n"
             "\"Eastern Kingdoms\",1415,947,0,0,2\n"
             "\"Stormwind City\",1453,1415,0,0,3\n"
             "\"Elwynn Forest\",1429,1415,2,0,3\n"
             "\"Dustwallow Marsh\",1445,1414,2,0,3\n"
             "Badlands,1418,1415,2,0,3\n"
             "\"Warsong Gulch\",1460,1413,0,0,6\n",
    "UiMapAssignment": "ID,UiMapID,OrderIndex,MapID,AreaID\n1,1453,0,0,1519\n2,1429,0,0,12\n"
                       "3,1445,0,1,15\n4,1418,0,0,3\n",
    "Map": "ID,Directory,MapName_lang\n0,Azeroth,\"Eastern Kingdoms\"\n1,Kalimdor,Kalimdor\n",
    "AreaTable": "ID,ZoneName,AreaName_lang,ContinentID,ParentAreaID\n1519,Stormwind,\"Stormwind City\",0,0\n"
                 "12,Elwynn,\"Elwynn Forest\",0,0\n88,Eastvale,\"Eastvale Logging Camp\",0,12\n"
                 "15,Dustwallow,\"Dustwallow Marsh\",1,0\n3,Badlands,Badlands,0,0\n35,BootyBay,\"Booty Bay\",0,33\n",
    "WMOAreaTable": "AreaName_lang,ID,WMOID,AreaTableID\n\"Mage Quarter\",1,10,1519\n\"The Great Forge\",2,11,1537\n",
    "SkillLine": "DisplayName_lang,ID,CategoryID,ParentSkillLineID,Flags\nFishing,356,9,0,128\n"
                 "Swords,43,6,0,128\nAlchemy,171,11,0,128\nRiding,762,9,0,144\n\"Horse Riding\",148,9,0,144\n"
                 "Poisons,40,9,0,128\n\"Dwarven Racial\",101,9,0,146\nAlchemy,2937,11,171,0\n",
    "SpellName": "ID,Name_lang\n2259,Alchemy\n7620,Fishing\n",
    "Creature": "ID,Name_lang\n7380,Siamese\n",
}

TRAINERS = '''local _, NS = ...
local J, E, A = { 75, 150 }, { 75, 150, 225 }, { 75, 150, 225, 300 }
local G, S = A, J
city({ name = "Stormwind", faction = "Alliance", mapID = 1453, news = "1" }, {
    { "Tel'Athir", "Mage Quarter", "alchemy", J },
    { "Nobody Here", "Lost Quarter", "alchemy", E },
})
for _, r in ipairs({
    { "Nat Pagle", "Neutral", "Dustwallow Marsh", "Dustwallow Marsh", 1445, "fishing", { 300 } },
}) do
end
for _, r in ipairs({
    { "Woo Ping", "Alliance", "Stormwind", "Mage Quarter", 1453, 57.1, 57.7,
      { "swords", "polearms" } },
}) do
end
for _, r in ipairs({
    { "Randal Hunter", "Alliance", "Human", "Eastvale Logging Camp", "Elwynn Forest", 1429 },
}) do
end
'''

FISHING = '''local L = NS.L
NS.Fishing_Forever = {
    verified = false,
    zones = {
        { L["Elwynn Forest"], 1429, -70 }, { L["Stormwind City"], 1453, -70 },
        { L["Gone Zone"], 9999, 55 },
        { L["Warsong Gulch"], 1460, 55 },
    },
}
'''

CATALOG = '''local function craft(name, category, order, openSpell) end
NS.SkillCatalog = {
    alchemy         = craft("Alchemy", "primary", 1),
    fishing         = gather("Fishing", "secondary", 3),
    swords          = weapon("Swords", 12),
    daggers         = weapon("Daggers", 5),
    riding      = { category = "other", kind = "riding", name = "Riding", order = 3, opensSkillsTab = true,
                    aliases = { "Horse Riding", "Ram Riding" } },
}
local SKILL_LINE_IDS = {
    alchemy = 171, fishing = 356, swords = 43, daggers = 999, riding = 762,
}
local OPEN_SPELL_IDS = {
    alchemy = 2259,   -- a trailing comment
}
local ICON_SPELL_IDS = { alchemy = 2259, fishing = 1 }
NS.SkillCatalog.riding.aliasIDs = { 148 }
'''


def crlf(text: str) -> bytes:
    return text.replace("\n", "\r\n").encode("utf-8")


class Fixture(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.tables = {}
        for name, body in TABLES.items():
            path = self.tmp / ("%s.csv.gz" % name)
            with gzip.open(path, "wb") as fh:
                fh.write(body.encode("utf-8"))
            self.tables[name] = path
        self.defaults = self.tmp / "defaults"
        self.defaults.mkdir()
        for name, text in (("Trainers_Forever.lua", TRAINERS), ("Fishing_Forever.lua", FISHING),
                           ("SkillCatalog_Forever.lua", CATALOG)):
            (self.defaults / name).write_bytes(crlf(text))
        floor = mock.patch.multiple(seeds, SEED_MINIMUMS={"trainers": 1, "fishing": 1, "catalog": 1},
                                    SEED_SENTINELS={"trainers": ("Woo Ping",), "fishing": (1429,)})
        floor.start()
        self.addCleanup(floor.stop)

    def doc(self):
        return seeds.derive_doc(seeds.DB(self.tables), seeds.read_seeds(self.defaults), "forever",
                                "1.60.1.70938", "", "2026-11-15")


class LuaReader(unittest.TestCase):
    def test_literals(self):
        value, _end = seeds.read_lua('{ L["Un\'Goro"], 1449, -70, J, { 1, 2 }, x = "y" -- note\n}', 0)
        self.assertEqual(value.items[:3], ["Un'Goro", 1449, -70])
        self.assertEqual(value.items[3], "J")
        self.assertEqual(value.items[4].items, [1, 2])
        self.assertEqual(value.fields, {"x": "y"})

    def test_slug_matches_the_lua(self):
        self.assertEqual(seeds.slug("Tel'Athir"), "tel_athir")
        self.assertEqual(seeds.slug("Doctor Gustaf VanHowzen"), "doctor_gustaf_vanhowzen")


class Seeds(Fixture):
    def test_trainers(self):
        rows = {t["id"]: t for t in seeds.read_seeds(self.defaults)["trainers"]}
        self.assertEqual(sorted(rows), ["nat_pagle", "nobody_here", "randal_hunter", "tel_athir", "woo_ping"])
        self.assertEqual(rows["woo_ping"]["teaches"], ["swords", "polearms"])
        self.assertEqual(rows["randal_hunter"]["mapName"], "Elwynn Forest")
        self.assertEqual(rows["randal_hunter"]["city"], "Eastvale Logging Camp")
        self.assertEqual(rows["nat_pagle"]["mapID"], 1445)

    def test_catalog(self):
        cat = seeds.read_seeds(self.defaults)["catalog"]
        self.assertEqual(cat["keys"]["alchemy"]["openSpell"], "Alchemy")
        self.assertEqual(cat["keys"]["riding"]["aliases"], ["Horse Riding", "Ram Riding"])
        self.assertEqual(cat["openSpellIDs"], {"alchemy": 2259})
        self.assertEqual(cat["aliasIDs"], [148])

    def test_flags(self):
        kinds = {(f["kind"], f["list"], f["id"]) for f in self.doc()["flags"]}
        self.assertIn(("map-name", "trainers", "tel_athir"), kinds)             # Stormwind vs Stormwind City
        self.assertIn(("subzone", "trainers", "nobody_here"), kinds)            # no such district
        self.assertNotIn(("subzone", "trainers", "tel_athir"), kinds)           # Mage Quarter is a WMO area
        self.assertNotIn(("place", "trainers", "randal_hunter"), kinds)         # Eastvale sits under Elwynn
        self.assertIn(("skill", "trainers", "woo_ping"), kinds)                 # polearms: no catalog key
        self.assertIn(("map-unknown", "fishing", "9999"), kinds)
        self.assertIn(("map-type", "fishing", "1460"), kinds)
        self.assertNotIn(("map-name", "fishing", "1453"), kinds)
        self.assertIn(("skill-unknown", "catalog", "daggers"), kinds)
        self.assertIn(("spell-unknown", "iconSpell", "fishing"), kinds)

    def test_candidates(self):
        keys = {c["key"] for c in self.doc()["candidates"]}
        self.assertIn("fishing:1418", keys)        # a Type 3 zone the list lacks
        self.assertNotIn("fishing:1429", keys)     # shipped
        self.assertNotIn("fishing:1415", keys)     # a continent (Type 2)
        self.assertIn("catalog:40", keys)          # Poisons
        self.assertNotIn("catalog:101", keys)      # a racial line
        self.assertNotIn("catalog:2937", keys)     # a child line

    def test_coverage_gate(self):
        tables = dict(self.tables)
        path = self.tmp / "UiMap.empty.csv.gz"
        with gzip.open(path, "wb") as fh:
            fh.write(b"Name_lang,ID,ParentUiMapID,Flags,System,Type\n")
        tables["UiMap"] = path
        with self.assertRaises(SystemExit):
            seeds.derive_doc(seeds.DB(tables), seeds.read_seeds(self.defaults), "forever", "b", "", "2026-11-15")


class Rulings(Fixture):
    def test_rule_refuses_what_apply_cannot_do(self):
        r = {}
        with self.assertRaises(SystemExit):
            seeds.set_ruling(r, "fishing:1418", "accept", "a level nobody measured")
        with self.assertRaises(SystemExit):
            seeds.set_ruling(r, "shipped:skill-unknown:catalog:daggers", "remove", "fix by hand instead")
        with self.assertRaises(SystemExit):
            seeds.set_ruling(r, "shipped:subzone:trainers:nobody_here", "remove", "")
        seeds.set_ruling(r, "shipped:subzone:trainers:nobody_here", "remove", "no such trainer")
        self.assertEqual(r["shipped:subzone:trainers:nobody_here"]["ruling"], "remove")

    def test_check_exits_1_while_unruled(self):
        bundle = self.tmp / "2026-11-15-forever"
        bundle.mkdir()
        doc = self.doc()
        seeds.write_json(bundle / "candidates.json", doc)
        rulings = self.tmp / "r.json"
        args = mock.Mock(bundle=bundle, rulings=rulings)
        self.assertEqual(seeds.cmd_check(args), 1)
        seeds.save_rulings(rulings, {k: {"ruling": "keep" if k.startswith("shipped:") else "reject", "reason": "x"}
                                     for k in seeds.all_keys(doc)})
        self.assertEqual(seeds.cmd_check(args), 0)

    def test_status_line(self):
        root = self.tmp / "research"
        self.assertTrue(seeds.status_line("1.2", []).startswith("NEW 1.2"))
        bundle = root / "2026-11-15-forever"
        bundle.mkdir(parents=True)
        (bundle / "candidates.json").write_text(json.dumps({"build": "1.2"}), encoding="utf-8")
        found = seeds.bundles(root, "forever")
        self.assertEqual(seeds.status_line("1.2", found), "CURRENT 1.2 (2026-11-15-forever)")
        self.assertTrue(seeds.status_line("1.3", found).startswith("NEW 1.3 (last ruled 1.2"))


class Apply(Fixture):
    def ruled(self, removing=()):
        doc = self.doc()
        rulings = {}
        for key in seeds.all_keys(doc):
            removable = key.startswith("shipped:") and key.split(":")[2] in seeds.REMOVABLE_LISTS
            ruling = ("remove" if removable and any(key.endswith(":" + r) for r in removing)
                      else "keep" if key.startswith("shipped:") else "reject")
            seeds.set_ruling(rulings, key, ruling, "fixture")
        return doc, rulings

    def test_apply_refuses_while_unruled(self):
        doc, rulings = self.ruled(removing=("nobody_here",))
        rulings.pop(next(iter(rulings)))
        before = (self.defaults / "Trainers_Forever.lua").read_bytes()
        with self.assertRaises(SystemExit):
            seeds.apply_bundle(doc, rulings, self.defaults)
        self.assertEqual((self.defaults / "Trainers_Forever.lua").read_bytes(), before)

    def test_apply_removes_keeps_crlf_and_is_idempotent(self):
        doc, rulings = self.ruled(removing=("nobody_here", "9999"))
        changes = seeds.apply_bundle(doc, rulings, self.defaults)
        self.assertEqual(len(changes), 2)
        trainers = (self.defaults / "Trainers_Forever.lua").read_bytes()
        fishing = (self.defaults / "Fishing_Forever.lua").read_bytes()
        self.assertNotIn(b"Nobody Here", trainers)
        self.assertNotIn(b"Gone Zone", fishing)
        self.assertEqual(trainers, crlf(TRAINERS.replace('    { "Nobody Here", "Lost Quarter", "alchemy", E },\n', "")))
        self.assertEqual(fishing, crlf(FISHING.replace('        { L["Gone Zone"], 9999, 55 },\n', "")))
        self.assertEqual(seeds.apply_bundle(doc, rulings, self.defaults), [])
        self.assertEqual((self.defaults / "Trainers_Forever.lua").read_bytes(), trainers)

    def test_remove_row_on_a_shared_line(self):
        text = '        { L["A"], 1, -70 }, { L["B"], 2, -70 }, { L["C"], 3, 55 },\n'
        self.assertEqual(seeds.remove_row(text, "fishing", {"zone": "B", "id": 2}),
                         '        { L["A"], 1, -70 }, { L["C"], 3, 55 },\n')
        self.assertEqual(seeds.remove_row(text, "fishing", {"zone": "C", "id": 3}),
                         '        { L["A"], 1, -70 }, { L["B"], 2, -70 },\n')


if __name__ == "__main__":
    unittest.main()
