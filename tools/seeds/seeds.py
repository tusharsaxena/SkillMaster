#!/usr/bin/env python3
"""tools/seeds/seeds.py: re-validate Skill Master's seed data against WoW Forever's own DB2 tables.

WHAT THIS IS
    Skill Master ships hand-made data tables under defaults/. Four of them name things the client's
    DB2 data also holds, and those are what this tool checks against one pinned wago.tools build of
    the client's own product (`wowf`, clients-§10):

        defaults/Trainers_Forever.lua      trainer records: mapID (a UiMap id: the code hands it to
                                           C_Map and UiMapPoint), mapName, city, subzone, teaches
        defaults/Fishing_Forever.lua       zone rows: enUS zone name, uiMapID, level
        defaults/SkillCatalog_Forever.lua  skill keys: skillLineID, the riding aliasIDs, and the
                                           open and icon spell ids
        (defaults/Preview_Forever.lua is NOT a seed: it is the design mockups' fictional sample
        character, and nothing in it mirrors a DB2 row.)

    What DB2 cannot check is never touched. Positions (x, y), costs, ranks, levels and the zone
    fishing levels are measured or design values the client's tables do not hold. The trainers'
    names are checked against Creature for the record, but the Forever client's Creature table
    holds only companion and mount creatures (189 rows on 1.60.1.70938), so a trainer missing from
    it is no evidence; the tool reports the count and raises no flag. The `verified = false` flags
    are the owner's smoke-pass state, and the tool never writes them.

    Flags (key `shipped:<kind>:<list>:<id>`), over every shipped row:
        trainers   map-unknown  the mapID is no UiMap row
                   map-name     the mapName is not the UiMap row's name
                   map-instance the UiMap sits on no Map row (UiMapAssignment.MapID)
                   subzone      the subzone is no AreaTable or WMOAreaTable name under the map's zone
                   place        the city (when it is not the mapName) is no such name either
                   skill        a `teaches` key is not a SkillCatalog key
        fishing    map-unknown, map-name, map-instance (as above, on the uiMapID and zone name),
                   map-type     the UiMap row is not a zone (Type 3)
        catalog    skill-unknown / skill-name   the skillLineID is no SkillLine row, or its name
                                                differs from the catalog's enUS name
        alias      alias-unknown / alias-name   a riding aliasID is no SkillLine row, or its name
                                                is not one of the riding aliases
        openSpell  spell-unknown / spell-name   the open spell id is no SpellName row, or its name
                                                is not the spell the catalog casts
        iconSpell  spell-unknown                the icon spell id is no SpellName row
    A flag is ruled `keep` or `remove`. `remove` exists only for a trainer or fishing row (the
    one change `apply` can make without inventing data); a catalog, alias or spell flag is fixed by
    hand in the seed file, and its flag disappears on the next derive.

    Candidates (key `<list>:<id>`), ruled `reject` only on this addon:
        fishing    a UiMap zone (Type 3) the zone list lacks. Its level is measured in game, so the
                   rulings say "needs owner review"; the owner adds a zone by hand with its level.
        catalog    a SkillLine row in category 6 (weapon), 9 (secondary) or 11 (profession), with
                   no parent line and no "Racial" or "[DNT]" in its name, that the catalog lacks.
                   A catalog line is a design decision (design §2), so it too is added by hand.
        Trainers get no candidates: the client holds no trainer NPC rows (above), and every
        trainer record is measured or sourced.

THE STEPS
    python3 tools/seeds/seeds.py status [--flavor forever]
    python3 tools/seeds/seeds.py derive --flavor forever --bundle docs/seed-research/<date>-forever --date <date> [--build V] [--replay]
    python3 tools/seeds/seeds.py check  --bundle docs/seed-research/<date>-forever
    python3 tools/seeds/seeds.py rule   --tsv <file> --bundle docs/seed-research/<date>-forever
    python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
    python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>

    `status` prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`. `derive` pins one build,
    fetches each table once into the git-ignored `.cache/` (streamed, `?build=` always, a real
    User-Agent), freezes the tables it read into the bundle's raw/*.csv.gz, and writes SOURCES.md
    and candidates.json; `--replay` re-derives from raw/ alone. `rule` is the only writer of
    forever_rulings.json (keyed by list and id, never by build). `check` exits 1 while anything is
    unruled. `report` writes RULINGS.md. `apply` refuses while anything is unruled, removes only
    the rows ruled `remove`, keeps the file's line endings and layout, and a second run changes
    nothing. The date is always an argument; nothing here reads the clock.

    Copied in shape from AuraMaster's tools/spell-research/retail.py and sid_seeds.py, never
    imported across repos. Whether one shared helper should carry the build pin, the cache, the
    bundle and the rulings is LibKa0s#91.

Python 3.8+ and its standard library only.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import re
import shutil
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
DEFAULTS = REPO / "defaults"
RESEARCH = REPO / "docs" / "seed-research"
RULINGS_PATH = HERE / "forever_rulings.json"

FLAVORS = {"forever": "wowf"}   # flavor -> wago.tools product; Skill Master is Forever-only
BUILDS_URL = "https://wago.tools/api/builds"
TABLE_URL = "https://wago.tools/db2/%s/csv?build=%s"
USER_AGENT = "ka0s-seed-validation (SkillMaster tools/seeds)"
CHUNK = 1 << 16
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# The tables a run reads, and why. This tuple IS the fetch list and the list SOURCES.md records.
TABLES = (
    ("UiMap", "Name_lang, Type, ParentUiMapID: the trainer mapIDs and fishing uiMapIDs (C_Map ids)"),
    ("UiMapAssignment", "UiMapID -> AreaID and MapID: the zone area a place must sit under, and its Map"),
    ("Map", "ID, MapName_lang: the instance (continent) each UiMap sits on"),
    ("AreaTable", "AreaName_lang, ParentAreaID: the subzones and places under a zone"),
    ("WMOAreaTable", "AreaName_lang, AreaTableID: the city districts, which are WMO areas"),
    ("SkillLine", "DisplayName_lang, CategoryID, ParentSkillLineID: the catalog's skill-line ids"),
    ("SpellName", "Name_lang: the catalog's open and icon spell ids"),
    ("Creature", "Name_lang: the trainers' names, reported only (the client table holds no trainers)"),
)

# Ids the build must have, chosen from the game: a short or wrong table is a failed run, never a
# plausible diff.
SENTINELS = (
    ("UiMap", "1453", "Name_lang", "Stormwind City"),
    ("UiMap", "1445", "Name_lang", "Dustwallow Marsh"),
    ("AreaTable", "1519", "AreaName_lang", "Stormwind City"),
    ("AreaTable", "35", "AreaName_lang", "Booty Bay"),
    ("Map", "0", "MapName_lang", "Eastern Kingdoms"),
    ("Map", "1", "MapName_lang", "Kalimdor"),
    ("SkillLine", "356", "DisplayName_lang", "Fishing"),
    ("SkillLine", "43", "DisplayName_lang", "Swords"),
    ("SpellName", "2259", "Name_lang", "Alchemy"),
)
# The seed parse's own floor: names the parser must find, and the least it must read.
SEED_SENTINELS = {"trainers": ("Woo Ping", "Nat Pagle", "Randal Hunter", "Tel'Athir"),
                  "fishing": (1429, 1453, 1423)}
SEED_MINIMUMS = {"trainers": 100, "fishing": 40, "catalog": 31}

CANDIDATE_LISTS = ("fishing", "catalog")
FLAG_LISTS = ("trainers", "fishing", "catalog", "alias", "openSpell", "iconSpell")
REMOVABLE_LISTS = ("trainers", "fishing")
CANDIDATE_RULINGS = ("reject",)
FLAG_RULINGS = ("keep", "remove")
CATALOG_CATEGORIES = ("6", "9", "11")
KEY = re.compile(r"^(?:shipped:(?P<kind>[a-z-]+):)?(?P<list>\w+):(?P<id>[\w.]+)$")


def log(msg: str) -> None:
    print(msg, file=sys.stderr)


def write_repo_text(path: Path, text: str) -> None:
    """Write a text file with CRLF terminators: the repo pins `* text=auto eol=crlf`
    (.gitattributes), and tests/_kit/test_eol.lua fails a tracked file whose disk bytes disagree.
    Bytes, so it does not depend on the Python version."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))


def write_json(path: Path, doc) -> None:
    write_repo_text(path, json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# A small Lua literal reader (strings, numbers, names, L["..."], tables, call argument lists)
# ---------------------------------------------------------------------------

class LuaTable:
    def __init__(self):
        self.items: list = []
        self.fields: dict = {}


class Name(str):
    """A bare Lua name (an upvalue such as J or E), kept as its text."""


_TOKEN = re.compile(r"""\s+|--[^\n]*|"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|(-?\d+(?:\.\d+)?)|([A-Za-z_]\w*)|(.)""",
                    re.S)


def _unescape(text: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), text)


def read_lua(text: str, pos: int):
    """`(value, end)` of the Lua literal starting at `text[pos]` (a `{` table or a `(` argument
    list, read as a table). Raises ValueError on anything it does not know."""
    tokens = _tokens(text, pos)
    value = _value(tokens)
    return value, tokens.end


class _Tokens:
    def __init__(self, text: str, pos: int):
        self.text, self.pos, self.peeked, self.end = text, pos, None, pos

    def next(self):
        if self.peeked is not None:
            tok, self.peeked = self.peeked, None
            return tok
        while self.pos < len(self.text):
            m = _TOKEN.match(self.text, self.pos)
            self.pos = m.end()
            self.end = self.pos
            if m.group(1) is not None or m.group(2) is not None:
                return ("str", _unescape(m.group(1) if m.group(1) is not None else m.group(2)))
            if m.group(3) is not None:
                num = m.group(3)
                return ("num", float(num) if "." in num else int(num))
            if m.group(4) is not None:
                return ("name", m.group(4))
            if m.group(5) is not None:
                return ("sym", m.group(5))
        return ("eof", None)

    def peek(self):
        if self.peeked is None:
            self.peeked = self.next()
        return self.peeked


def _tokens(text: str, pos: int) -> _Tokens:
    return _Tokens(text, pos)


def _value(t: _Tokens):
    kind, val = t.next()
    if kind == "sym" and val in "{(":
        return _table(t, "}" if val == "{" else ")")
    if kind in ("str", "num"):
        return val
    if kind == "name":
        if val in ("true", "false"):
            return val == "true"
        if val == "nil":
            return None
        if val == "L" and t.peek() == ("sym", "["):
            t.next()
            k, s = t.next()
            if k != "str" or t.next() != ("sym", "]"):
                raise ValueError("L[ must hold one string")
            return s
        return Name(val)
    raise ValueError("unexpected %s %r at %d" % (kind, val, t.pos))


def _table(t: _Tokens, close: str) -> LuaTable:
    out = LuaTable()
    while True:
        if t.peek() == ("sym", close):
            t.next()
            return out
        kind, val = t.peek()
        if kind == "name":
            t.next()
            if t.peek() == ("sym", "="):
                t.next()
                out.fields[val] = _value(t)
            else:
                out.items.append(_after_name(t, val))
        else:
            out.items.append(_value(t))
        sep = t.next()
        if sep == ("sym", close):
            return out
        if sep not in (("sym", ","), ("sym", ";")):
            raise ValueError("expected , or %s, got %r" % (close, sep))


def _after_name(t: _Tokens, name: str):
    """A bare name already consumed as an item: L["x"], or a plain name."""
    if name == "L" and t.peek() == ("sym", "["):
        t.next()
        k, s = t.next()
        if k != "str" or t.next() != ("sym", "]"):
            raise ValueError("L[ must hold one string")
        return s
    if name in ("true", "false"):
        return name == "true"
    return Name(name)


def _read_at(text: str, marker: str, opener: str = "{"):
    """The literal opened by the first `opener` after `marker`; SystemExit when `marker` is absent."""
    at = text.find(marker)
    if at < 0:
        raise SystemExit("seed parse: %r not found; the file's shape changed, so update the reader." % marker)
    start = text.index(opener, at + len(marker))
    return read_lua(text, start)[0]


# ---------------------------------------------------------------------------
# The seed files
# ---------------------------------------------------------------------------

def slug(name: str) -> str:
    """defaults/Trainers_Forever.lua's slug(): the record id when a row names none."""
    return re.sub(r"[^A-Za-z0-9]+", "_", name.lower()).strip("_")


def read_trainers(text: str) -> list[dict]:
    """Every trainer record, in file order: the city() blocks, then the three row loops (Expert and
    Artisan rows of 7 fields, weapon masters of 8, riding instructors of 6)."""
    out: list[dict] = []
    for m in re.finditer(r"^city\(", text, re.M):
        call, _end = read_lua(text, m.end() - 1)
        head, rows = call.items[0], call.items[1]
        for r in rows.items:
            out.append({"name": r.items[0], "faction": head.fields["faction"], "city": head.fields["name"],
                        "subzone": r.items[1], "mapName": head.fields["name"], "mapID": head.fields["mapID"],
                        "teaches": [r.items[2]]})
    for m in re.finditer(r"^for _, r in ipairs\(", text, re.M):
        rows, _end = read_lua(text, m.end())
        for r in rows.items:
            f = r.items
            if len(f) == 7:
                out.append({"name": f[0], "faction": f[1], "city": f[2], "subzone": None, "mapName": f[3],
                            "mapID": f[4], "teaches": [f[5]]})
            elif len(f) == 8:
                out.append({"name": f[0], "faction": f[1], "city": f[2], "subzone": f[3], "mapName": f[2],
                            "mapID": f[4], "teaches": list(f[7].items)})
            elif len(f) == 6:
                out.append({"name": f[0], "faction": f[1], "city": f[3], "subzone": None, "mapName": f[4],
                            "mapID": f[5], "teaches": ["riding"]})
            else:
                raise SystemExit("seed parse: a trainer row of %d fields (%r); update read_trainers." % (len(f), f[0]))
    seen: dict[str, str] = {}
    for rec in out:
        rec["id"] = slug(rec["name"])
        if rec["id"] in seen:
            raise SystemExit("seed parse: two trainers share the id %r." % rec["id"])
        seen[rec["id"]] = rec["name"]
    return out


def read_fishing(text: str) -> list[dict]:
    zones = _read_at(text, "zones =")
    return [{"zone": z.items[0], "id": z.items[1], "level": z.items[2]} for z in zones.items]


def read_catalog(text: str) -> dict:
    """`{keys: {key: {name, kind, openSpell, aliases}}, skillLineIDs, aliasIDs, openSpellIDs,
    iconSpellIDs}` out of defaults/SkillCatalog_Forever.lua."""
    keys: dict[str, dict] = {}
    body_at = text.index("NS.SkillCatalog = {")
    body_end = text.index("\n}\n", body_at)
    body = text[body_at:body_end]
    for m in re.finditer(r"^\s+(\w+)\s*=\s*(craft|gather|weapon)\(", body, re.M):
        args, _end = read_lua(body, m.end() - 1)
        a = args.items
        name = a[0]
        if m.group(2) == "craft":
            open_spell = a[3] if len(a) > 3 else name
        elif m.group(2) == "gather":
            open_spell = a[3] if len(a) > 3 else None
        else:
            open_spell = None
        keys[m.group(1)] = {"name": name, "kind": m.group(2), "openSpell": open_spell, "aliases": []}
    for m in re.finditer(r"^\s+(\w+)\s*=\s*\{\s*category =", body, re.M):
        tab, _end = read_lua(body, body.index("{", m.start()))
        aliases = tab.fields.get("aliases")
        keys[m.group(1)] = {"name": tab.fields["name"], "kind": tab.fields["kind"], "openSpell": None,
                            "aliases": list(aliases.items) if aliases else []}

    def ids(marker: str) -> dict:
        return {k: v for k, v in _read_at(text, marker).fields.items()}

    return {"keys": keys, "skillLineIDs": ids("local SKILL_LINE_IDS ="),
            "aliasIDs": list(_read_at(text, "NS.SkillCatalog.riding.aliasIDs =").items),
            "openSpellIDs": ids("local OPEN_SPELL_IDS ="), "iconSpellIDs": ids("local ICON_SPELL_IDS =")}


def read_seeds(defaults: Path = DEFAULTS) -> dict:
    def text(name: str) -> str:
        return (defaults / name).read_bytes().decode("utf-8").replace("\r\n", "\n")

    seeds = {"trainers": read_trainers(text("Trainers_Forever.lua")),
             "fishing": read_fishing(text("Fishing_Forever.lua")),
             "catalog": read_catalog(text("SkillCatalog_Forever.lua"))}
    return seeds


def check_seed_floor(seeds: dict) -> list[str]:
    """What the seed parse should have found and did not (the parser's own coverage gate)."""
    missing = []
    names = {t["name"] for t in seeds["trainers"]}
    missing += ["trainer %r" % n for n in SEED_SENTINELS["trainers"] if n not in names]
    zones = {z["id"] for z in seeds["fishing"]}
    missing += ["fishing zone %d" % z for z in SEED_SENTINELS["fishing"] if z not in zones]
    for key, floor in SEED_MINIMUMS.items():
        got = len(seeds[key]["keys"]) if key == "catalog" else len(seeds[key])
        if got < floor:
            missing.append("%s: %d rows read, at least %d expected" % (key, got, floor))
    return missing


# ---------------------------------------------------------------------------
# The build's tables
# ---------------------------------------------------------------------------

def http_get(url: str, accept: str = "text/csv"):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    try:
        return urllib.request.urlopen(req, timeout=300)
    except urllib.error.HTTPError as err:   # 403: the User-Agent; 400: the table is not on the build
        raise SystemExit("HTTP %s fetching %s: %s" % (err.code, url, err.reason))
    except urllib.error.URLError as err:
        raise SystemExit("Could not reach %s: %s (a run that is not --replay needs the network)" % (url, err.reason))


def live_build(product: str) -> dict:
    """The newest build the builds API lists for `product`: `{version, created_at}`."""
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = data.get(product) or []
    if not builds:
        raise SystemExit("The builds API lists no %r builds; pass --build." % product)
    return {"version": builds[0]["version"], "created_at": builds[0].get("created_at", "")}


def fetch_table(table: str, build: str, cache_dir: Path) -> Path:
    """One table's CSV in the per-build cache, streamed to a .part file renamed on completion."""
    path = cache_dir / build / ("%s.csv" % table)
    if path.exists():
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    part = path.with_suffix(".csv.part")
    log("  fetching %s ..." % (TABLE_URL % (table, build)))
    with http_get(TABLE_URL % (table, build)) as resp, part.open("wb") as out:
        shutil.copyfileobj(resp, out, CHUNK)
    part.replace(path)
    return path


def iter_rows(path: Path):
    """The rows of a `.csv` or `.csv.gz`, streamed, as dicts keyed by header name."""
    if path.suffix == ".gz":
        handle = io.TextIOWrapper(gzip.open(path, "rb"), encoding="utf-8", newline="")
    else:
        handle = path.open("r", encoding="utf-8", newline="")
    with handle:
        yield from csv.DictReader(handle)


class DB:
    """The facts the checks read, out of the tables `{name: path}`."""

    def __init__(self, tables: dict[str, Path]):
        self.uimap = {int(r["ID"]): {"name": r["Name_lang"], "type": int(r["Type"]), "parent": int(r["ParentUiMapID"])}
                      for r in iter_rows(tables["UiMap"])}
        self.ui_areas: dict[int, set] = defaultdict(set)
        self.ui_maps: dict[int, set] = defaultdict(set)
        for r in iter_rows(tables["UiMapAssignment"]):
            ui = int(r["UiMapID"])
            if int(r["AreaID"]):
                self.ui_areas[ui].add(int(r["AreaID"]))
            self.ui_maps[ui].add(int(r["MapID"]))
        self.maps = {int(r["ID"]): r["MapName_lang"] for r in iter_rows(tables["Map"])}
        self.areas = {int(r["ID"]): {"name": r["AreaName_lang"], "parent": int(r["ParentAreaID"])}
                      for r in iter_rows(tables["AreaTable"])}
        self.children: dict[int, set] = defaultdict(set)
        for aid, a in self.areas.items():
            self.children[a["parent"]].add(aid)
        self.wmo: dict[str, set] = defaultdict(set)
        for r in iter_rows(tables["WMOAreaTable"]):
            self.wmo[r["AreaName_lang"]].add(int(r["AreaTableID"]))
        self.area_by_name: dict[str, set] = defaultdict(set)
        for aid, a in self.areas.items():
            self.area_by_name[a["name"]].add(aid)
        self.skills = {int(r["ID"]): {"name": r["DisplayName_lang"], "category": r["CategoryID"],
                                      "parent": int(r["ParentSkillLineID"] or 0), "flags": int(r["Flags"] or 0)}
                       for r in iter_rows(tables["SkillLine"])}
        self.spells = {int(r["ID"]): r["Name_lang"] for r in iter_rows(tables["SpellName"])}
        self.creatures = {r["Name_lang"] for r in iter_rows(tables["Creature"])}
        self._raw = tables

    def sentinels(self) -> list[str]:
        facts = {"UiMap": lambda i: self.uimap.get(i, {}).get("name"),
                 "AreaTable": lambda i: self.areas.get(i, {}).get("name"),
                 "Map": lambda i: self.maps.get(i),
                 "SkillLine": lambda i: self.skills.get(i, {}).get("name"),
                 "SpellName": lambda i: self.spells.get(i)}
        missing = ["%s %s is %r, expected %r" % (t, i, facts[t](int(i)), want)
                   for t, i, _col, want in SENTINELS if facts[t](int(i)) != want]
        if not self.wmo.get("The Great Forge"):
            missing.append("WMOAreaTable has no 'The Great Forge'")
        return missing

    def zone_areas(self, ui_map: int) -> set:
        """Every AreaTable id under the UiMap's assigned areas (the areas and all their children)."""
        todo, seen = list(self.ui_areas.get(ui_map, ())), set()
        while todo:
            aid = todo.pop()
            if aid in seen:
                continue
            seen.add(aid)
            todo.extend(self.children.get(aid, ()))
        return seen

    def place_status(self, name: str, ui_map: int) -> str:
        """`ok`, `elsewhere` (the name exists under another zone) or `unknown`."""
        under = self.zone_areas(ui_map)
        ids = self.area_by_name.get(name, set()) | self.wmo.get(name, set())
        if ids & under:
            return "ok"
        return "elsewhere" if ids else "unknown"


# ---------------------------------------------------------------------------
# Flags and candidates
# ---------------------------------------------------------------------------

def _flag(kind: str, lst: str, ident, name: str, detail: str) -> dict:
    return {"key": "shipped:%s:%s:%s" % (kind, lst, ident), "kind": kind, "list": lst, "id": str(ident),
            "name": name, "detail": detail}


def map_flags(db: DB, lst: str, ident, label: str, ui_map, map_name) -> list[dict]:
    out = []
    row = db.uimap.get(ui_map)
    if row is None:
        return [_flag("map-unknown", lst, ident, label, "uiMapID %s is no UiMap row" % ui_map)]
    if map_name is not None and map_name != row["name"]:
        out.append(_flag("map-name", lst, ident, label, "%r; UiMap %d is %r" % (map_name, ui_map, row["name"])))
    instances = db.ui_maps.get(ui_map, set())
    if not instances or not all(m in db.maps for m in instances):
        out.append(_flag("map-instance", lst, ident, label, "UiMap %d sits on Map %s" % (ui_map, sorted(instances))))
    return out


def trainer_flags(db: DB, trainers: list[dict], catalog_keys) -> list[dict]:
    out = []
    for t in trainers:
        out += map_flags(db, "trainers", t["id"], t["name"], t["mapID"], t["mapName"])
        if t["mapID"] in db.uimap:
            places = [("subzone", t["subzone"])]
            if t["city"] != t["mapName"]:
                places.append(("place", t["city"]))
            for kind, place in places:
                if place is None:
                    continue
                status = db.place_status(place, t["mapID"])
                if status != "ok":
                    where = ("named only outside UiMap %d's zone" % t["mapID"] if status == "elsewhere"
                             else "named nowhere in AreaTable or WMOAreaTable")
                    out.append(_flag(kind, "trainers", t["id"], t["name"], "%r is %s" % (place, where)))
        for key in t["teaches"]:
            if key not in catalog_keys:
                out.append(_flag("skill", "trainers", t["id"], t["name"], "teaches %r, not a SkillCatalog key" % key))
    return out


def fishing_flags(db: DB, zones: list[dict]) -> list[dict]:
    out = []
    for z in zones:
        out += map_flags(db, "fishing", z["id"], z["zone"], z["id"], z["zone"])
        row = db.uimap.get(z["id"])
        if row is not None and row["type"] != 3:
            out.append(_flag("map-type", "fishing", z["id"], z["zone"], "UiMap %d is Type %d, not a zone (3)"
                             % (z["id"], row["type"])))
    return out


def catalog_flags(db: DB, cat: dict) -> list[dict]:
    out = []
    for key, sid in sorted(cat["skillLineIDs"].items()):
        want = cat["keys"].get(key, {}).get("name")
        row = db.skills.get(sid)
        if row is None:
            out.append(_flag("skill-unknown", "catalog", key, want or key, "skillLineID %d is no SkillLine row" % sid))
        elif row["name"] != want:
            out.append(_flag("skill-name", "catalog", key, want or key, "SkillLine %d is %r" % (sid, row["name"])))
    aliases = set(cat["keys"].get("riding", {}).get("aliases", ()))
    for sid in cat["aliasIDs"]:
        row = db.skills.get(sid)
        if row is None:
            out.append(_flag("alias-unknown", "alias", sid, "riding", "aliasID %d is no SkillLine row" % sid))
        elif row["name"] not in aliases:
            out.append(_flag("alias-name", "alias", sid, row["name"], "SkillLine %d %r is not a riding alias"
                             % (sid, row["name"])))
    for key, sid in sorted(cat["openSpellIDs"].items()):
        want = cat["keys"].get(key, {}).get("openSpell")
        name = db.spells.get(sid)
        if name is None:
            out.append(_flag("spell-unknown", "openSpell", key, want or key, "spell %d is no SpellName row" % sid))
        elif name != want:
            out.append(_flag("spell-name", "openSpell", key, want or key, "spell %d is %r" % (sid, name)))
    for key, sid in sorted(cat["iconSpellIDs"].items()):
        if sid not in db.spells:
            out.append(_flag("spell-unknown", "iconSpell", key, key, "spell %d is no SpellName row" % sid))
    return out


def fishing_candidates(db: DB, zones: list[dict]) -> list[dict]:
    shipped = {z["id"] for z in zones}
    out = []
    for ui, row in sorted(db.uimap.items()):
        if row["type"] == 3 and ui not in shipped:
            parent = db.uimap.get(row["parent"], {}).get("name", "none")
            out.append({"key": "fishing:%d" % ui, "list": "fishing", "id": str(ui), "name": row["name"],
                        "notes": ["UiMap Type 3 (zone), parent %s (%d)" % (parent, row["parent"])]})
    return out


def catalog_candidates(db: DB, cat: dict) -> list[dict]:
    shipped = set(cat["skillLineIDs"].values()) | set(cat["aliasIDs"])
    out = []
    for sid, row in sorted(db.skills.items()):
        if (row["category"] in CATALOG_CATEGORIES and row["parent"] == 0 and sid not in shipped
                and "Racial" not in row["name"] and "[DNT]" not in row["name"]):
            out.append({"key": "catalog:%d" % sid, "list": "catalog", "id": str(sid), "name": row["name"],
                        "notes": ["SkillLine category %s, Flags %d, no parent line" % (row["category"], row["flags"])]})
    return out


def derive_doc(db: DB, seeds: dict, flavor: str, build: str, created: str, date: str) -> dict:
    missing = db.sentinels() + check_seed_floor(seeds)
    if missing:
        raise SystemExit("coverage gate FAILED: %s. Fix the reader or the fetch before ruling anything."
                         % "; ".join(missing))
    cat = seeds["catalog"]
    flags = (trainer_flags(db, seeds["trainers"], cat["keys"]) + fishing_flags(db, seeds["fishing"])
             + catalog_flags(db, cat))
    candidates = fishing_candidates(db, seeds["fishing"]) + catalog_candidates(db, cat)
    matched = sorted(t["name"] for t in seeds["trainers"] if t["name"] in db.creatures)
    return {
        "flavor": flavor, "product": FLAVORS[flavor], "build": build, "buildCreated": created, "date": date,
        "tool": "tools/seeds/seeds.py derive",
        "shipped": {"trainers": len(seeds["trainers"]), "fishing": len(seeds["fishing"]),
                    "catalog": len(cat["skillLineIDs"]), "alias": len(cat["aliasIDs"]),
                    "openSpell": len(cat["openSpellIDs"]), "iconSpell": len(cat["iconSpellIDs"])},
        "creature": {"tableRows": len(db.creatures), "trainersMatched": matched,
                     "note": "the client's Creature table holds companions and mounts, not trainers: report only"},
        "candidates": candidates, "flags": flags,
    }


# ---------------------------------------------------------------------------
# Bundles and rulings
# ---------------------------------------------------------------------------

def bundles(root: Path, flavor: str) -> list[Path]:
    return sorted(p for p in root.glob("*-%s" % flavor) if (p / "candidates.json").exists())


def bundle_build(bundle: Path) -> str:
    return json.loads((bundle / "candidates.json").read_text(encoding="utf-8"))["build"]


def status_line(live: str, found: list[Path]) -> str:
    """`CURRENT <build> (<bundle>)` or `NEW <build> ...`; the first word is what
    /dev-copilot:validate-seeds reads."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    built = bundle_build(found[-1])
    if built == live:
        return "CURRENT %s (%s)" % (live, found[-1].name)
    return "NEW %s (last ruled %s, %s)" % (live, built, found[-1].name)


def load_rulings(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def save_rulings(path: Path, rulings: dict) -> None:
    write_repo_text(path, json.dumps(rulings, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def read_tsv(path: Path) -> list[tuple[str, str, str]]:
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit("%s: a ruling line is key<TAB>ruling<TAB>reason; got %r" % (path, line))
        out.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return out


def set_ruling(rulings: dict, key: str, ruling: str, reason: str) -> None:
    """Record one ruling; a malformed key, ruling or reason is a SystemExit naming it."""
    m = KEY.match(key)
    if not m:
        raise SystemExit("%r is not <list>:<id> or shipped:<kind>:<list>:<id>." % key)
    lst, kind = m.group("list"), m.group("kind")
    if kind:
        if lst not in FLAG_LISTS:
            raise SystemExit("%r: unknown flag list %r." % (key, lst))
        allowed = FLAG_RULINGS if lst in REMOVABLE_LISTS else ("keep",)
        why = "a %s flag is fixed by hand in the seed file, never removed by apply" % lst
    else:
        if lst not in CANDIDATE_LISTS:
            raise SystemExit("%r: unknown candidate list %r." % (key, lst))
        allowed = CANDIDATE_RULINGS
        why = ("a %s candidate is added by hand (its level or design entry is the owner's), so it is "
               "only ever rejected here" % lst)
    if ruling not in allowed:
        raise SystemExit("ruling for %s must be %s; got %r (%s)." % (key, " or ".join(allowed), ruling, why))
    reason = (reason or "").strip()
    if not reason or "\n" in reason:
        raise SystemExit("reason for %s must be one non-empty line." % key)
    rulings[key] = {"ruling": ruling, "reason": reason}


def load_candidates(bundle: Path) -> dict:
    path = bundle / "candidates.json"
    if not path.exists():
        raise SystemExit("%s has no candidates.json: run seeds.py derive first." % bundle)
    return json.loads(path.read_text(encoding="utf-8"))


def all_keys(doc: dict) -> list[str]:
    return [c["key"] for c in doc["candidates"]] + [f["key"] for f in doc["flags"]]


def unruled_keys(doc: dict, rulings: dict) -> list[str]:
    return [k for k in all_keys(doc) if k not in rulings]


# ---------------------------------------------------------------------------
# Apply: remove ruled rows, keeping the file's bytes otherwise
# ---------------------------------------------------------------------------

def _row_start(text: str, lst: str, row: dict) -> int:
    if lst == "trainers":
        pat = r'\{ "%s",' % re.escape(row["name"])
    else:
        pat = r'\{ L\["%s"\], %s,' % (re.escape(row["zone"]), row["id"])
    found = [m.start() for m in re.finditer(pat, text)]
    if len(found) > 1:
        raise SystemExit("apply refused: %r matches %d rows; remove it by hand." % (pat, len(found)))
    return found[0] if found else -1


def remove_row(text: str, lst: str, row: dict) -> str:
    """`text` without the row's `{ ... }` literal and its trailing separator; a line left blank goes
    too. A row that is not there leaves `text` unchanged (apply is idempotent)."""
    start = _row_start(text, lst, row)
    if start < 0:
        return text
    _value, end = read_lua(text, start)
    tail = re.match(r",[ \t]*", text[end:])
    end += tail.end() if tail else 0
    line_start = text.rfind("\n", 0, start) + 1
    line_end = text.find("\n", end)
    line_end = len(text) if line_end < 0 else line_end
    rest = text[line_start:start] + text[end:line_end]
    if not rest.strip():
        return text[:line_start] + text[line_end + 1:]
    if text[end:line_end].strip() == "" and text[line_start:start].strip():
        return text[:start].rstrip(" \t") + text[end:]
    return text[:start] + text[end:]


def plan_apply(doc: dict, rulings: dict) -> list[dict]:
    """The flags ruled `remove`, deduplicated by row. Refuses (SystemExit) while anything is unruled."""
    unruled = unruled_keys(doc, rulings)
    if unruled:
        raise SystemExit("apply refused: %d key(s) unruled (seeds.py check lists them)." % len(unruled))
    seen, out = set(), []
    for f in doc["flags"]:
        if rulings[f["key"]]["ruling"] == "remove" and (f["list"], f["id"]) not in seen:
            seen.add((f["list"], f["id"]))
            out.append(f)
    return out


def apply_bundle(doc: dict, rulings: dict, defaults: Path = DEFAULTS) -> list[str]:
    removals = plan_apply(doc, rulings)
    seeds = read_seeds(defaults)
    files = {"trainers": defaults / "Trainers_Forever.lua", "fishing": defaults / "Fishing_Forever.lua"}
    rows = {"trainers": {t["id"]: t for t in seeds["trainers"]},
            "fishing": {str(z["id"]): z for z in seeds["fishing"]}}
    changes = []
    for lst, path in files.items():
        raw = path.read_bytes().decode("utf-8")
        crlf = "\r\n" in raw
        text = raw.replace("\r\n", "\n")
        before = text
        for f in removals:
            if f["list"] != lst or f["id"] not in rows[lst]:
                continue
            text = remove_row(text, lst, rows[lst][f["id"]])
            changes.append("%s: -%s (%s)" % (lst, f["id"], f["name"]))
        if text != before:
            path.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
    return changes


# ---------------------------------------------------------------------------
# SOURCES.md and RULINGS.md
# ---------------------------------------------------------------------------

def _cell(text) -> str:
    return str(text or "").replace("|", "\\|")


def format_sources(doc: dict, sizes: dict) -> str:
    lines = ["# Sources: Skill Master seed validation, %s (%s)" % (doc["date"], doc["flavor"]), "",
             "Written by `tools/seeds/seeds.py derive`. Do not edit by hand.", "",
             "- Product: wago.tools `%s` (WoW Forever)" % doc["product"],
             "- Build: `%s` (created %s, per %s)" % (doc["build"], doc["buildCreated"] or "unknown", BUILDS_URL),
             "- Run date: %s (passed as `--date`; the tool reads no clock)" % doc["date"],
             "- User-Agent: `%s`" % USER_AGENT, "",
             "| Table | URL | Bytes (csv) | Why |", "| --- | --- | --- | --- |"]
    for table, why in TABLES:
        lines.append("| %s | `%s` | %s | %s |" % (table, TABLE_URL % (table, doc["build"]), sizes.get(table, "?"), why))
    lines += ["", "Each table is frozen as `raw/<Table>.csv.gz`; `seeds.py derive --replay` re-derives from "
              "them with no network and no cache.", ""]
    return "\n".join(lines)


def format_rulings_md(doc: dict, rulings: dict, date: str) -> str:
    tally: dict[str, int] = defaultdict(int)
    for key in all_keys(doc):
        tally[rulings.get(key, {}).get("ruling", "unruled")] += 1
    lines = ["# Rulings: Skill Master seed validation, %s (%s, build %s)" % (doc["date"], doc["flavor"], doc["build"]),
             "", "Generated by `tools/seeds/seeds.py report` on %s from this bundle's `candidates.json` and "
             "`tools/seeds/forever_rulings.json`. Do not edit by hand." % date, "",
             "Shipped rows checked: %s." % ", ".join("%s %d" % (k, v) for k, v in sorted(doc["shipped"].items())),
             "", "%d candidates, %d flags: %s." % (len(doc["candidates"]), len(doc["flags"]),
                                                   ", ".join("%d %s" % (n, r) for r, n in sorted(tally.items()))), "",
             "Creature: %d distinct names on the build; trainer names found in it: %d (%s)." % (
                 doc["creature"]["tableRows"], len(doc["creature"]["trainersMatched"]), doc["creature"]["note"]), ""]
    unruled = unruled_keys(doc, rulings)
    if unruled:
        lines += ["## Unruled: %d" % len(unruled), ""] + ["- `%s`" % k for k in unruled] + [""]
    lines += ["## Candidates", ""]
    for lst in CANDIDATE_LISTS:
        rows = [c for c in doc["candidates"] if c["list"] == lst]
        if not rows:
            continue
        lines += ["### %s: %d" % (lst, len(rows)), "", "| Id | Name | Notes | Ruling | Reason |",
                  "| --- | --- | --- | --- | --- |"]
        for c in rows:
            r = rulings.get(c["key"], {})
            lines.append("| `%s` | %s | %s | %s | %s |" % (c["id"], _cell(c["name"]), _cell("; ".join(c["notes"])),
                                                         r.get("ruling", "**unruled**"), _cell(r.get("reason"))))
        lines.append("")
    lines += ["## Shipped-row flags: %d" % len(doc["flags"]), ""]
    if doc["flags"]:
        lines += ["| Kind | List | Id | Name | Detail | Ruling | Reason |", "| --- | --- | --- | --- | --- | --- | --- |"]
        for f in doc["flags"]:
            r = rulings.get(f["key"], {})
            lines.append("| %s | %s | `%s` | %s | %s | %s | %s |" % (
                f["kind"], f["list"], f["id"], _cell(f["name"]), _cell(f["detail"]),
                r.get("ruling", "**unruled**"), _cell(r.get("reason"))))
    else:
        lines.append("None.")
    lines.append("")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def _date(value: str) -> str:
    if not DATE_RE.match(value):
        raise argparse.ArgumentTypeError("a date is YYYY-MM-DD; got %r" % value)
    return value


def bundle_tables(bundle: Path, build: str, replay: bool, cache_dir: Path) -> tuple[dict, dict]:
    """`({table: path}, {table: csv bytes})`, from raw/ on a replay, else fetched and frozen."""
    raw = bundle / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    paths, sizes = {}, {}
    for table, _why in TABLES:
        member = raw / ("%s.csv.gz" % table)
        if replay:
            if not member.exists():
                raise SystemExit("--replay: %s is missing; run derive once without --replay." % member)
        else:
            source = fetch_table(table, build, cache_dir)
            with source.open("rb") as src, gzip.GzipFile(member, "wb", compresslevel=9, mtime=0) as dst:
                shutil.copyfileobj(src, dst, CHUNK)
        with gzip.open(member, "rb") as fh:
            sizes[table] = sum(len(chunk) for chunk in iter(lambda: fh.read(CHUNK), b""))
        paths[table] = member
    return paths, sizes


def cmd_status(args) -> int:
    print(status_line(live_build(FLAVORS[args.flavor])["version"], bundles(args.root, args.flavor)))
    return 0


def cmd_derive(args) -> int:
    product = FLAVORS[args.flavor]
    prior = args.bundle / "candidates.json"
    if args.replay:
        if not prior.exists() and not args.build:
            raise SystemExit("--replay needs the bundle's candidates.json (for its build) or --build.")
        old = json.loads(prior.read_text(encoding="utf-8")) if prior.exists() else {}
        build, created = args.build or old["build"], old.get("buildCreated", "")
    elif args.build:
        build, created = args.build, ""
    else:
        live = live_build(product)
        build, created = live["version"], live["created_at"]
    tables, sizes = bundle_tables(args.bundle, build, args.replay, args.cache_dir)
    doc = derive_doc(DB(tables), read_seeds(args.defaults), args.flavor, build, created, args.date)
    write_json(prior, doc)
    write_repo_text(args.bundle / "SOURCES.md", format_sources(doc, sizes))
    unruled = unruled_keys(doc, load_rulings(args.rulings))
    log("build %s: %d candidates, %d flags, %d unruled; shipped %s" % (
        build, len(doc["candidates"]), len(doc["flags"]), len(unruled), doc["shipped"]))
    return 0


def cmd_rule(args) -> int:
    todo = [(k, args.ruling, args.reason) for k in (args.key or ())]
    if args.tsv:
        todo += read_tsv(args.tsv)
    if not todo:
        raise SystemExit("rule needs --key (with --ruling and --reason) or --tsv.")
    known = set(all_keys(load_candidates(args.bundle))) if args.bundle else None
    rulings = load_rulings(args.rulings)
    for key, ruling, reason in todo:
        if known is not None and key not in known:
            raise SystemExit("%s is not a candidate or flag in %s/candidates.json." % (key, args.bundle))
        set_ruling(rulings, key, ruling, reason)
    save_rulings(args.rulings, rulings)
    log("Recorded %d ruling(s) in %s" % (len(todo), args.rulings))
    return 0


def cmd_check(args) -> int:
    doc = load_candidates(args.bundle)
    unruled = unruled_keys(doc, load_rulings(args.rulings))
    if not unruled:
        print("OK: every candidate and flag in %s is ruled." % args.bundle.name)
        return 0
    rows = {c["key"]: c for c in doc["candidates"]}
    rows.update({f["key"]: f for f in doc["flags"]})
    print("%d unruled:" % len(unruled))
    for key in unruled:
        print("  %s  %s  %s" % (key, rows[key]["name"], rows[key].get("detail") or "; ".join(rows[key].get("notes", ()))))
    return 1


def cmd_report(args) -> int:
    doc = load_candidates(args.bundle)
    write_repo_text(args.bundle / "RULINGS.md", format_rulings_md(doc, load_rulings(args.rulings), args.date))
    log("Wrote %s" % (args.bundle / "RULINGS.md"))
    return 0


def cmd_apply(args) -> int:
    changes = apply_bundle(load_candidates(args.bundle), load_rulings(args.rulings), args.defaults)
    for line in changes:
        log("  " + line)
    log("%d change(s) to defaults/ (%s)" % (len(changes), args.date))
    return 0


def parse_args(argv):
    p = argparse.ArgumentParser(description="Re-validate Skill Master's seed data against a wago.tools build.",
                                epilog="The contract is docs/validate-seeds.md.")
    p.add_argument("--rulings", type=Path, default=RULINGS_PATH)
    p.add_argument("--defaults", type=Path, default=DEFAULTS, help="the seed files' folder")
    p.add_argument("--cache-dir", type=Path, default=HERE / ".cache")
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("status", help="is there a live build newer than the newest bundle?")
    s.add_argument("--flavor", choices=sorted(FLAVORS), default="forever")
    s.add_argument("--root", type=Path, default=RESEARCH)
    d = sub.add_parser("derive", help="flags and candidates into the bundle's candidates.json")
    d.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    d.add_argument("--bundle", type=Path, required=True)
    d.add_argument("--date", type=_date, required=True)
    d.add_argument("--build", default=None, help="pin this build instead of the live one")
    d.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    r = sub.add_parser("rule", help="record rulings (the only writer of the rulings file)")
    r.add_argument("--key", action="append")
    r.add_argument("--ruling")
    r.add_argument("--reason")
    r.add_argument("--tsv", type=Path)
    r.add_argument("--bundle", type=Path)
    for name, helptext in (("check", "exit 1 while anything is unruled"),
                           ("report", "write the bundle's RULINGS.md"),
                           ("apply", "remove the rows ruled `remove` from the seed files")):
        c = sub.add_parser(name, help=helptext)
        c.add_argument("--bundle", type=Path, required=True)
        if name != "check":
            c.add_argument("--date", type=_date, required=True)
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    return {"status": cmd_status, "derive": cmd_derive, "rule": cmd_rule, "check": cmd_check,
            "report": cmd_report, "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
