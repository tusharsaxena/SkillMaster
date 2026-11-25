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
import hashlib
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
local function city(c, rows)
    for _, r in ipairs(rows) do
        add{ name = r[1], faction = c.faction, city = c.name, subzone = r[2], mapName = c.name,
             mapID = c.mapID, teaches = { r[3] }, ranks = r[4], npcID = r[5], x = r[6], y = r[7], source = "s" }
    end
end
city({ name = "Stormwind", faction = "Alliance", mapID = 1453, news = "1" }, {
    { "Vel'Morra", "Mage Quarter", "alchemy", J, 900001, 50.0, 50.0 },
    { "Nobody Here", "Lost Quarter", "alchemy", E, 900002, 40.0, 40.0 },
})
for _, r in ipairs({
    { "Brannoc Reedline", "Neutral", "Dustwallow Marsh", "Dustwallow Marsh", 1445, "fishing", { 300 }, 900003, 58.6, 60.1, BOOK },
}) do
    add{ name = r[1], faction = r[2], city = r[3], mapName = r[4], mapID = r[5], teaches = { r[6] },
         ranks = r[7], npcID = r[8], x = r[9], y = r[10], learn = r[11], source = "s" }
end
for _, r in ipairs({
    { "Hesk Dunmarrow", "Alliance", "Stormwind", "Mage Quarter", 1453, 57.1, 57.7, 900004,
      { "swords", "polearms" } },
}) do
    local polearms = false
    add{ name = r[1], faction = r[2], city = r[3], subzone = r[4], mapName = r[3], mapID = r[5],
         x = r[6], y = r[7], npcID = r[8], cost = 1000, teaches = r[9], source = "s",
         costByKey = polearms and COST or nil }
end
for _, r in ipairs({
    { "Randal Hunter", "Alliance", "Human", "Eastvale Logging Camp", "Elwynn Forest", 1429, 900005, nil, nil },
}) do
    add{ name = r[1], faction = r[2], race = r[3], city = r[4], mapName = r[5], mapID = r[6],
         npcID = r[7], x = r[8], y = r[9], cost = 900000, teaches = { "riding" }, ranks = { 75, 150 }, source = "s" }
end
add{ name = "Zara Invented", faction = "Neutral", city = "Elwynn Forest", mapName = "Elwynn Forest",
     mapID = 1429, npcID = 900006, x = 20.0, y = 30.0, cost = 900000, teaches = { "riding" }, ranks = { 75 },
     hold = HOLD, source = SRC }
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


GATHERING = '''local L = NS.L
NS.Gathering_Forever = {
    mining = {
        verified = false, source = "recalled",
        { name = L["Glimmer Vein"],   need = 1 },
        { name = L["Hollow Deposit"], need = 65 },
    },
    herbalism = {
        verified = false, source = "recalled",
        { name = L["Dusk Petal"], need = 1 },
    },
}
'''

# An invented ForeverDB in its real shape (positional rows, string creature keys, spm in 0..1000,
# spw world points through umaa): made-up names, ids from 900000 up, made-up coordinates. Never a
# real ForeverDB row (its data is GPL-3.0; the repo is MIT).
FOREVERDB = {
    "meta": {"build": "2099-01-01", "hash": "feedfacecafe0000", "counts": {}},
    "npc": {"900001": ["Vel'Morra", "Invented Brewer Title", 30, 30, 0],
            "900002": ["Somebody Else", "Alchemist", 30, 30, 0],
            "900003": ["Brannoc Reedline", "Invented Angler Title", 45, 45, 0],
            "900004": ["Hesk Dunmarrow", "Invented Blade Title", 40, 40, 0],
            "900006": ["Zara Invented", "Riding Trainer", 20, 20, 0]},
    "nfac": {"900001": "A", "900002": "A", "900003": "AH", "900004": "A", "900006": "H"},
    # 900001: one spm point at 50.3, 50.1 (on), 900006 at 25.0, 30.0 (off by 5)
    "spm": {"c900001": {"1453": [503, 501]}, "c900006": {"1429": [250, 300]}},
    # 900003: a world point on Map 1 that projects onto UiMap 1445 at 58.6, 60.1
    "spw": {"c900003": [[1, 600.0 - 0.601 * 1000.0, 500.0 - 0.586 * 1000.0]]},
    "umaa": {"900100": [1445, 1, 15, 0, 0, 1, 1, -400.0, -500.0, -1000000, 600.0, 500.0, 1000000]},
    "obj": {"900200": ["Glimmer Vein"], "900201": ["Dusk Petal"]},
    "spf": {"ProfessionTrainers": {"900001": 171, "900002": 356},
            "WeaponMasters": {"900004": [43, 55]}},
}


def write_foreverdb(folder: Path, tag: str = "v2099.01.01.1") -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    data = json.dumps(FOREVERDB).encode("utf-8")
    (folder / "foreverdb.json").write_bytes(data)
    src = {"format": 1, "tag": tag, "commit": "0" * 40, "date": "2099-01-02", "origin": ["github"],
           "tocVersion": tag[1:], "meta": {"build": "2099-01-01", "hash": "feedfacecafe0000"},
           "files": [{"path": "ForeverDB/ForeverDB.toc", "bytes": 1, "sha256": "a" * 64, "sha256LF": "a" * 64}],
           "urls": ["https://example.invalid/ForeverDB.toc"], "install": None,
           "json": {"path": "foreverdb.json", "sha256": hashlib.sha256(data).hexdigest()}}
    (folder / "SOURCES.json").write_text(json.dumps(src), encoding="utf-8")
    return folder


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
                           ("SkillCatalog_Forever.lua", CATALOG), ("Gathering_Forever.lua", GATHERING)):
            (self.defaults / name).write_bytes(crlf(text))
        floor = mock.patch.multiple(seeds, SEED_MINIMUMS={"trainers": 1, "fishing": 1, "catalog": 1, "gathering": 1},
                                    SEED_SENTINELS={"trainers": ("Hesk Dunmarrow",), "fishing": (1429,)})
        floor.start()
        self.addCleanup(floor.stop)

    def doc(self, fdb=None):
        return seeds.derive_doc(seeds.DB(self.tables), seeds.read_seeds(self.defaults), "forever",
                                "1.60.1.70938", "", "2026-11-15", fdb)


class LuaReader(unittest.TestCase):
    def test_literals(self):
        value, _end = seeds.read_lua('{ L["Un\'Goro"], 1449, -70, J, { 1, 2 }, x = "y" -- note\n}', 0)
        self.assertEqual(value.items[:3], ["Un'Goro", 1449, -70])
        self.assertEqual(value.items[3], "J")
        self.assertEqual(value.items[4].items, [1, 2])
        self.assertEqual(value.fields, {"x": "y"})

    def test_slug_matches_the_lua(self):
        self.assertEqual(seeds.slug("Vel'Morra"), "vel_morra")
        self.assertEqual(seeds.slug("Doctor Gustaf VanHowzen"), "doctor_gustaf_vanhowzen")


class Seeds(Fixture):
    def test_trainers(self):
        rows = {t["id"]: t for t in seeds.read_seeds(self.defaults)["trainers"]}
        self.assertEqual(sorted(rows), ["brannoc_reedline", "hesk_dunmarrow", "nobody_here", "randal_hunter", "vel_morra",
                                        "zara_invented"])
        self.assertEqual(rows["hesk_dunmarrow"]["teaches"], ["swords", "polearms"])
        self.assertEqual(rows["hesk_dunmarrow"]["npcID"], 900004)
        self.assertEqual(rows["randal_hunter"]["mapName"], "Elwynn Forest")
        self.assertEqual(rows["randal_hunter"]["city"], "Eastvale Logging Camp")
        self.assertIsNone(rows["randal_hunter"]["x"])
        self.assertEqual(rows["brannoc_reedline"]["mapID"], 1445)
        self.assertEqual((rows["brannoc_reedline"]["x"], rows["brannoc_reedline"]["y"]), (58.6, 60.1))
        self.assertEqual(rows["vel_morra"]["faction"], "Alliance")         # city()'s head table
        self.assertEqual(rows["vel_morra"]["subzone"], "Mage Quarter")
        self.assertEqual(rows["zara_invented"]["teaches"], ["riding"])      # a standalone add{}
        self.assertEqual(rows["zara_invented"]["npcID"], 900006)

    def test_the_shipped_trainers_parse(self):
        """The reader against the real defaults/: every record, the sentinels, unique ids."""
        rows = seeds.read_trainers((seeds.DEFAULTS / "Trainers_Forever.lua").read_bytes().decode("utf-8")
                                   .replace("\r\n", "\n"))
        self.assertGreaterEqual(len(rows), 190)
        self.assertTrue(all(r["npcID"] for r in rows))
        names = {r["name"] for r in rows}
        for name in ("Woo Ping", "Genn Fairweather", "Annora", "Shari Stilwell"):
            self.assertIn(name, names)

    def test_gathering(self):
        nodes = seeds.read_seeds(self.defaults)["gathering"]
        self.assertEqual([n["id"] for n in nodes], ["herbalism.dusk_petal", "mining.glimmer_vein", "mining.hollow_deposit"])
        self.assertEqual(nodes[2]["need"], 65)

    def test_catalog(self):
        cat = seeds.read_seeds(self.defaults)["catalog"]
        self.assertEqual(cat["keys"]["alchemy"]["openSpell"], "Alchemy")
        self.assertEqual(cat["keys"]["riding"]["aliases"], ["Horse Riding", "Ram Riding"])
        self.assertEqual(cat["openSpellIDs"], {"alchemy": 2259})
        self.assertEqual(cat["aliasIDs"], [148])

    def test_flags(self):
        kinds = {(f["kind"], f["list"], f["id"]) for f in self.doc()["flags"]}
        self.assertIn(("map-name", "trainers", "vel_morra"), kinds)             # Stormwind vs Stormwind City
        self.assertIn(("subzone", "trainers", "nobody_here"), kinds)            # no such district
        self.assertNotIn(("subzone", "trainers", "vel_morra"), kinds)           # Mage Quarter is a WMO area
        self.assertNotIn(("place", "trainers", "randal_hunter"), kinds)         # Eastvale sits under Elwynn
        self.assertIn(("skill", "trainers", "hesk_dunmarrow"), kinds)                 # polearms: no catalog key
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


class ForeverDBEvidence(Fixture):
    def setUp(self):
        super().setUp()
        self.fdb = seeds.ForeverDB(write_foreverdb(self.tmp / "fdb"))

    def flags(self):
        return {(f["kind"], f["id"]): f for f in self.doc(self.fdb)["flags"] if f["kind"].startswith("fdb-")}

    def test_no_evidence_without_the_option(self):
        doc = self.doc()
        self.assertNotIn("foreverdb", doc)
        self.assertFalse([f for f in doc["flags"] if f["kind"].startswith("fdb-")])

    def test_trainer_verdicts(self):
        doc = self.doc(self.fdb)
        v = doc["foreverdb"]["verdicts"]["trainers"]
        self.assertEqual(v["vel_morra"]["npc"], "found")
        self.assertEqual(v["vel_morra"]["spot"], "ok")
        self.assertEqual(v["vel_morra"]["spotSource"], "spm")
        self.assertEqual(v["vel_morra"]["role"], "ok")
        self.assertEqual(v["nobody_here"]["npc"], "name-mismatch")
        self.assertEqual(v["brannoc_reedline"]["spot"], "ok")                 # spw projected through umaa
        self.assertEqual(v["brannoc_reedline"]["spotSource"], "spw")
        self.assertEqual(v["brannoc_reedline"]["side"], "ok")                 # Neutral is "AH"
        self.assertEqual(v["randal_hunter"]["npc"], "missing")
        self.assertNotIn("spot", v["randal_hunter"])
        self.assertEqual(v["zara_invented"]["spot"], "position-off")
        self.assertEqual(doc["foreverdb"]["tag"], "v2099.01.01.1")
        self.assertEqual(doc["shipped"]["gathering"], 3)

    def test_trainer_flags(self):
        flags = self.flags()
        self.assertIn(("fdb-name", "nobody_here"), flags)
        self.assertIn("'Somebody Else'", flags[("fdb-name", "nobody_here")]["detail"])
        self.assertIn(("fdb-role", "nobody_here"), flags)             # spf says Fishing, it teaches Alchemy
        self.assertIn(("fdb-npc", "randal_hunter"), flags)
        self.assertIn(("fdb-side", "zara_invented"), flags)           # Neutral shipped, "H" in nfac
        self.assertIn(("fdb-spot", "zara_invented"), flags)
        self.assertIn("5.0 map-% away", flags[("fdb-spot", "zara_invented")]["detail"])
        self.assertIn(("fdb-role", "hesk_dunmarrow"), flags)                # WeaponMasters adds a line the record lacks
        self.assertNotIn(("fdb-spot", "vel_morra"), flags)
        self.assertNotIn(("fdb-side", "brannoc_reedline"), flags)
        self.assertNotIn(("fdb-spot", "brannoc_reedline"), flags)

    def test_gathering_flags(self):
        flags = self.flags()
        self.assertIn(("fdb-node", "mining.hollow_deposit"), flags)
        self.assertNotIn(("fdb-node", "mining.glimmer_vein"), flags)
        self.assertEqual(self.doc(self.fdb)["foreverdb"]["verdicts"]["gathering"]["herbalism.dusk_petal"], "found")

    def test_a_gathering_flag_is_keep_only(self):
        r = {}
        with self.assertRaises(SystemExit):
            seeds.set_ruling(r, "shipped:fdb-node:gathering:mining.hollow_deposit", "remove", "no such node")
        seeds.set_ruling(r, "shipped:fdb-node:gathering:mining.hollow_deposit", "keep", "fixed by hand")

    def test_a_changed_cache_is_refused(self):
        folder = self.tmp / "fdb"
        (folder / "foreverdb.json").write_bytes(b"{}")
        with self.assertRaises(SystemExit):
            seeds.ForeverDB(folder)

    def test_sources_and_rulings_keep_no_rows(self):
        doc = self.doc(self.fdb)
        doc["foreverdb"]["helper"] = "fixture"
        sources = seeds.format_sources(doc, {})
        self.assertIn("v2099.01.01.1", sources)
        self.assertIn("a" * 64, sources)
        rulings = seeds.format_rulings_md(doc, {}, "2099-01-02")
        self.assertIn("ForeverDB v2099.01.01.1", rulings)
        for text in (sources, json.dumps(doc["foreverdb"])):
            self.assertNotIn("Invented Brewer Title", text)            # an npc title: a row field never compared
            self.assertNotIn("Invented Blade Title", text)

    def test_replay_refetches_the_pinned_tag(self):
        bundle = self.tmp / "2099-01-02-forever"
        (bundle / "raw").mkdir(parents=True)
        for name, path in self.tables.items():
            (bundle / "raw" / path.name).write_bytes(path.read_bytes())
        cache = self.tmp / "cache"
        write_foreverdb(cache / "v2099.01.01.1")
        argv = ["--defaults", str(self.defaults), "--rulings", str(self.tmp / "r.json"), "derive", "--flavor",
                "forever", "--bundle", str(bundle), "--date", "2099-01-02", "--build", "9.9.9", "--replay",
                "--foreverdb", str(cache / "v2099.01.01.1"), "--foreverdb-helper", "fixture helper"]
        self.assertEqual(seeds.main(argv), 0)
        first = (bundle / "candidates.json").read_bytes()
        self.assertIn(b"fixture helper", (bundle / "SOURCES.md").read_bytes())
        again = argv[:argv.index("--foreverdb")] + ["--foreverdb-cache", str(cache)]
        self.assertEqual(seeds.main(again), 0)                       # the tag and helper come from the bundle
        self.assertEqual((bundle / "candidates.json").read_bytes(), first)
        with self.assertRaises(SystemExit):                          # the pinned tag is not cached
            seeds.main(argv[:argv.index("--foreverdb")] + ["--foreverdb-cache", str(self.tmp / "empty")])

    def test_status_follows_the_tag(self):
        root = self.tmp / "research"
        bundle = root / "2026-11-15-forever"
        bundle.mkdir(parents=True)
        (bundle / "candidates.json").write_text(json.dumps({"build": "1.2", "foreverdb": {"tag": "v1"}}),
                                                encoding="utf-8")
        found = seeds.bundles(root, "forever")
        self.assertTrue(seeds.status_line("1.2", found, "v1").startswith("CURRENT 1.2"))
        self.assertTrue(seeds.status_line("1.2", found, "v2").startswith("NEW 1.2 (ForeverDB v2"))
        self.assertTrue(seeds.status_line("1.2", found).startswith("CURRENT 1.2"))


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
        self.assertEqual(trainers, crlf(TRAINERS.replace('    { "Nobody Here", "Lost Quarter", "alchemy", E, 900002, 40.0, 40.0 },\n', "")))
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
