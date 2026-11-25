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

    ForeverDB evidence (`derive --foreverdb <folder>`, clients-§10's second source). DB2 holds no
    trainer NPC and no game object, so with the folder dev-copilot's `scripts/foreverdb.py fetch`
    printed, the tool also checks, and flags for a ruling (never applies):
        trainers   fdb-npc      the npcID is no ForeverDB npc row
                   fdb-name     the npc row's name is not the record's
                   fdb-side     nfac is not the record's faction (Neutral = "AH")
                   fdb-spot     no spot of the NPC on the record's mapID, or the nearest is more than
                                SPOT_TOLERANCE map-% away (spm points, else spw projected via umaa)
                   fdb-role     spf ProfessionTrainers / WeaponMasters disagree with `teaches`
        gathering  fdb-node     a node or herb name (defaults/Gathering_Forever.lua) is no obj name
    ForeverDB's data is GPL-3.0: candidates.json keeps per-id verdicts and flags quoting only the
    compared field, SOURCES.md the tag, commit and sha256s, and no row is ever written.

THE STEPS
    python3 tools/seeds/seeds.py status [--flavor forever] [--foreverdb-tag T]
    python3 tools/seeds/seeds.py derive --flavor forever --bundle docs/seed-research/<date>-forever --date <date> [--build V] [--replay]
                                        [--foreverdb <folder> [--foreverdb-helper TEXT]] [--foreverdb-cache DIR]
    python3 tools/seeds/seeds.py check  --bundle docs/seed-research/<date>-forever
    python3 tools/seeds/seeds.py rule   --tsv <file> --bundle docs/seed-research/<date>-forever
    python3 tools/seeds/seeds.py report --bundle docs/seed-research/<date>-forever --date <date>
    python3 tools/seeds/seeds.py apply  --bundle docs/seed-research/<date>-forever --date <date>

    `status` prints `CURRENT <build> (<bundle>)` or `NEW <build> (...)`; with --foreverdb-tag the
    bundle is current only when its build and its ForeverDB tag are both the newest. `derive` pins one build,
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
import hashlib
import io
import json
import math
import os
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
USER_AGENT = "SkillMaster-seed-check"
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
SEED_SENTINELS = {"trainers": ("Woo Ping", "Nat Pagle", "Randal Hunter", "Tel'Athir", "Genn Fairweather"),
                  "fishing": (1429, 1453, 1423)}
SEED_MINIMUMS = {"trainers": 190, "fishing": 40, "catalog": 31, "gathering": 30}

CANDIDATE_LISTS = ("fishing", "catalog")
FLAG_LISTS = ("trainers", "fishing", "catalog", "alias", "openSpell", "iconSpell", "gathering")
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
    if name == "nil":
        return None
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


# The add{} fields the trainer reader resolves, and how each value may be written: `{ r[N] }`,
# `r[N]`, `c.<field>` (city()'s head table), or a literal (a string, a number, a `{ ... }` table).
_ADD_FIELDS = ("name", "faction", "city", "subzone", "mapName", "mapID", "teaches", "npcID", "x", "y")
_ADD_FIELD = re.compile(r"\b(%s)\s*=\s*(?:\{\s*r\[(\d+)\]\s*\}|r\[(\d+)\]|c\.(\w+)|(\{[^{}]*\}|\"(?:[^\"\\\\]|\\\\.)*\"|-?\d+(?:\.\d+)?))"
                        % "|".join(_ADD_FIELDS))


def _close_brace(text: str, start: int) -> int:
    """The index just past the `}` that closes the `{` at `text[start]` (strings and comments skipped)."""
    depth, i = 0, start
    while i < len(text):
        ch = text[i]
        if ch in "\"'":
            j = i + 1
            while text[j] != ch:
                j += 2 if text[j] == "\\" else 1
            i = j
        elif text.startswith("--", i):
            i = text.find("\n", i)
            if i < 0:
                break
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise SystemExit("seed parse: an unclosed add{ at %d; update read_trainers." % start)


def _add_spec(body: str) -> dict:
    """`{field: (how, value)}` out of one add{ ... } body: ("wrap", N), ("row", N), ("head", name) or
    ("lit", value)."""
    spec = {}
    for m in _ADD_FIELD.finditer(body):
        field, wrap, row, head, lit = m.groups()
        if wrap:
            spec[field] = ("wrap", int(wrap))
        elif row:
            spec[field] = ("row", int(row))
        elif head:
            spec[field] = ("head", head)
        else:
            spec[field] = ("lit", read_lua("{" + lit + "}", 0)[0].items[0])
    return spec


def _plain(value):
    return list(value.items) if isinstance(value, LuaTable) else value


def _record(spec: dict, row: list, head=None) -> dict:
    out = {"subzone": None, "npcID": None, "x": None, "y": None}
    for field, (how, val) in spec.items():
        if how == "wrap":
            out[field] = [row[val - 1]]
        elif how == "row":
            out[field] = _plain(row[val - 1]) if val <= len(row) else None
        elif how == "head":
            out[field] = head.fields.get(val) if head is not None else None
        else:
            out[field] = _plain(val)
    missing = [f for f in ("name", "faction", "city", "mapName", "mapID", "teaches") if out.get(f) is None]
    if missing:
        raise SystemExit("seed parse: a trainer record without %s (%r); update read_trainers."
                         % (", ".join(missing), out.get("name")))
    return out


def _add_in(text: str, at: int, stop: int) -> dict:
    """The field spec of the first add{ between `at` and `stop`."""
    m = re.compile(r"\badd\s*\{").search(text, at, stop)
    if not m:
        raise SystemExit("seed parse: a trainer block with no add{ (at %d); update read_trainers." % at)
    brace = m.end() - 1
    return _add_spec(text[brace:_close_brace(text, brace)])


def read_trainers(text: str) -> list[dict]:
    """Every trainer record, in file order: each `city()` call, each `for _, r in ipairs({...}) do
    add{...} end` loop, and each standalone `add{...}`. Field positions are read from the add{} the
    rows feed (its `r[N]` references), so a reordered or widened row shape needs no reader change."""
    out: list[dict] = []
    fn = re.search(r"^local function city\(", text, re.M)
    city_spec = _add_in(text, fn.end(), text.index("\nend", fn.end())) if fn else None
    blocks = []
    for m in re.finditer(r"^city\(", text, re.M):
        blocks.append((m.start(), "city", m))
    for m in re.finditer(r"^for _, r in ipairs\(", text, re.M):
        blocks.append((m.start(), "loop", m))
    for m in re.finditer(r"^add\s*\{", text, re.M):
        blocks.append((m.start(), "add", m))
    for _at, kind, m in sorted(blocks, key=lambda b: b[0]):
        if kind == "city":
            if city_spec is None:
                raise SystemExit("seed parse: city() rows but no `local function city`; update read_trainers.")
            call, _end = read_lua(text, m.end() - 1)
            head, rows = call.items[0], call.items[1]
            out += [_record(city_spec, r.items, head) for r in rows.items]
        elif kind == "loop":
            rows, end = read_lua(text, m.end())
            stop = re.compile(r"^end\b", re.M).search(text, end)
            spec = _add_in(text, end, stop.start() if stop else len(text))
            out += [_record(spec, r.items) for r in rows.items]
        else:
            rec, _end = read_lua(text, m.end() - 1)
            out.append(_record({k: ("lit", v) for k, v in rec.fields.items() if k in _ADD_FIELDS}, []))
    seen: dict[str, str] = {}
    for rec in out:
        rec["id"] = slug(rec["name"])
        if rec["id"] in seen:
            raise SystemExit("seed parse: two trainers share the id %r." % rec["id"])
        seen[rec["id"]] = rec["name"]
    return out


def read_gathering(text: str) -> list[dict]:
    """Every node row of defaults/Gathering_Forever.lua: `{id: <list>.<slug>, list, name, need}`."""
    tab = _read_at(text, "NS.Gathering_Forever =")
    out = []
    for lst in sorted(tab.fields):
        for row in tab.fields[lst].items:
            out.append({"id": "%s.%s" % (lst, slug(row.fields["name"])), "list": lst,
                        "name": row.fields["name"], "need": row.fields.get("need")})
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
             "catalog": read_catalog(text("SkillCatalog_Forever.lua")),
             "gathering": read_gathering(text("Gathering_Forever.lua"))}
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
    """The newest live (non-background-download) build the builds API lists for `product`:
    `{version, created_at}`."""
    data = json.load(http_get(BUILDS_URL, accept="application/json"))
    builds = [b for b in data.get(product) or [] if not b.get("is_bgdl")]   # a background download is not live
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


# ---------------------------------------------------------------------------
# ForeverDB: the second evidence source for what DB2 cannot hold (clients-§10)
# ---------------------------------------------------------------------------
# ForeverDB (github.com/foreverfraddons/forever-db) is GPL-3.0 data. The tool reads the parsed copy
# dev-copilot's scripts/foreverdb.py caches (`foreverdb.py fetch --tag <tag> --date <date>` prints
# the folder) and writes only verdicts: never a row into the repo, a fixture or a bundle. A verdict
# may quote the one field it compares (an NPC's name, a side, the nearest spot). DB2 stays primary:
# ForeverDB only checks what DB2 holds nothing of (trainer NPCs, their sides and spawns, gathering
# objects), and every disagreement is a flag for a ruling, never an automatic change.

SPOT_TOLERANCE = 1.0   # map-%: the trainer probe's own tolerance (docs/trainer-probe/*/report.md)
SIDES = {"Alliance": "A", "Horde": "H", "Neutral": "AH"}


class ForeverDB:
    """The tables the checks read, out of one cached tag's foreverdb.json."""

    def __init__(self, folder: Path):
        folder = Path(folder)
        try:
            src = json.loads((folder / "SOURCES.json").read_text(encoding="utf-8"))
        except (OSError, ValueError) as err:
            raise SystemExit("--foreverdb %s: no readable SOURCES.json (%s); run foreverdb.py fetch first." % (folder, err))
        data = (folder / "foreverdb.json").read_bytes()
        if hashlib.sha256(data).hexdigest() != src.get("json", {}).get("sha256"):
            raise SystemExit("--foreverdb %s: foreverdb.json does not match its SOURCES.json; re-run foreverdb.py fetch."
                             % folder)
        db = json.loads(data.decode("utf-8"))
        self.sources = src
        self.tag = src.get("tag")
        self.npc = db.get("npc") or {}
        self.nfac = db.get("nfac") or {}
        self.spm = db.get("spm") or {}
        self.spw = db.get("spw") or {}
        self.umaa = [r for r in (db.get("umaa") or {}).values() if isinstance(r, list) and len(r) >= 13]
        spf = db.get("spf") or {}
        self.prof_trainers = spf.get("ProfessionTrainers") or {}
        self.weapon_masters = spf.get("WeaponMasters") or {}
        self.obj_names: set = set()
        for row in (db.get("obj") or {}).values():
            if isinstance(row, list) and row and isinstance(row[0], str):
                self.obj_names.add(row[0])

    def summary(self) -> dict:
        s = self.sources
        return {"tag": self.tag, "commit": s.get("commit"), "tocVersion": s.get("tocVersion"),
                "build": (s.get("meta") or {}).get("build"), "hash": (s.get("meta") or {}).get("hash"),
                "fetched": s.get("date"), "origin": s.get("origin"), "files": s.get("files"),
                "urls": s.get("urls"), "install": ({"path": s["install"].get("path"), "version": s["install"].get("version")}
                                                   if s.get("install") else None),
                "json": s.get("json"), "spotTolerance": SPOT_TOLERANCE}

    def _project(self, ui_map: int, map_id, wx, wy):
        """A world point on `map_id` as `(x, y)` map-% of UiMap `ui_map`, through its UiMapAssignment
        rows (umaa: UiMapID, MapID, AreaID, UiMin xy, UiMax xy, RegionMin xyz, RegionMax xyz); None
        when no row of that UiMap covers it."""
        for r in self.umaa:
            if r[0] != ui_map or r[1] != map_id:
                continue
            u0x, u0y, u1x, u1y = r[3], r[4], r[5], r[6]
            min_x, min_y, max_x, max_y = r[7], r[8], r[10], r[11]
            if not (min_x <= wx <= max_x and min_y <= wy <= max_y) or max_x == min_x or max_y == min_y:
                continue
            x = u0x + (max_y - wy) / (max_y - min_y) * (u1x - u0x)
            y = u0y + (max_x - wx) / (max_x - min_x) * (u1y - u0y)
            return (x * 100, y * 100)
        return None

    def spots(self, npc_id: int, ui_map: int) -> tuple[list, str]:
        """`([(x, y) map-%], source)`: spm's points on the map when it has some, else spw's world
        spawns projected onto it."""
        pts = (self.spm.get("c%d" % npc_id) or {}).get(str(ui_map))
        if isinstance(pts, list) and len(pts) >= 2:
            return [(pts[i] / 10, pts[i + 1] / 10) for i in range(0, len(pts) - 1, 2)], "spm"
        out = []
        for grp in self.spw.get("c%d" % npc_id) or []:
            if not isinstance(grp, list) or len(grp) < 3:
                continue
            for i in range(1, len(grp) - 1, 2):
                p = self._project(ui_map, grp[0], grp[i], grp[i + 1])
                if p:
                    out.append(p)
        return out, "spw"


def fdb_trainer_flags(fdb: ForeverDB, trainers: list[dict], skill_ids: dict) -> tuple[list, dict]:
    """`(flags, verdicts)` for each trainer: its npcID against npc (found, missing, name-mismatch),
    its side against nfac, its point against the NPC's spots on the shipped map (ok, position-off,
    no-spot), and its `teaches` against spf's ProfessionTrainers and WeaponMasters."""
    flags, verdicts = [], {}
    for t in trainers:
        v: dict = {}
        verdicts[t["id"]] = v
        nid = t.get("npcID")
        row = fdb.npc.get(str(nid)) if nid is not None else None
        if not isinstance(row, list) or not row:
            v["npc"] = "missing"
            flags.append(_flag("fdb-npc", "trainers", t["id"], t["name"], "npcID %s is no ForeverDB npc row" % nid))
            continue
        if row[0] != t["name"]:
            v["npc"] = "name-mismatch"
            flags.append(_flag("fdb-name", "trainers", t["id"], t["name"], "ForeverDB npc %d is named %r" % (nid, row[0])))
        else:
            v["npc"] = "found"
        side = fdb.nfac.get(str(nid))
        if side is None:
            v["side"] = "unknown"
        elif side != SIDES.get(t["faction"]):
            v["side"] = "mismatch"
            flags.append(_flag("fdb-side", "trainers", t["id"], t["name"], "shipped %s; ForeverDB nfac says %r"
                               % (t["faction"], side)))
        else:
            v["side"] = "ok"
        if t.get("x") is not None and t.get("y") is not None:
            pts, src = fdb.spots(nid, t["mapID"])
            if not pts:
                v["spot"] = "no-spot"
                flags.append(_flag("fdb-spot", "trainers", t["id"], t["name"], "ForeverDB has no spot of npc %d on UiMap %d"
                                   % (nid, t["mapID"])))
            else:
                best = min(pts, key=lambda p: math.hypot(p[0] - t["x"], p[1] - t["y"]))
                dist = round(math.hypot(best[0] - t["x"], best[1] - t["y"]), 2)
                v["spot"], v["dist"], v["spotSource"] = ("ok" if dist <= SPOT_TOLERANCE else "position-off"), dist, src
                if dist > SPOT_TOLERANCE:
                    flags.append(_flag("fdb-spot", "trainers", t["id"], t["name"],
                                       "shipped %.1f, %.1f; nearest ForeverDB spot (%s, %d) %.1f, %.1f is %.1f map-%% away"
                                       % (t["x"], t["y"], src, len(pts), best[0], best[1], dist)))
        teach = {skill_ids[k] for k in t["teaches"] if k in skill_ids}
        prof = fdb.prof_trainers.get(str(nid))
        weap = fdb.weapon_masters.get(str(nid))
        if isinstance(prof, int):
            v["role"] = "ok" if prof in teach else "mismatch"
            if prof not in teach:
                flags.append(_flag("fdb-role", "trainers", t["id"], t["name"], "spf ProfessionTrainers says skill line %d; "
                                   "the record teaches %s" % (prof, sorted(teach))))
        elif isinstance(weap, list):
            want = {w for w in weap if isinstance(w, int)}
            v["role"] = "ok" if want == teach else "mismatch"
            if want != teach:
                flags.append(_flag("fdb-role", "trainers", t["id"], t["name"], "spf WeaponMasters lacks %s and adds %s"
                                   % (sorted(teach - want), sorted(want - teach))))
        else:
            v["role"] = "absent"
    return flags, verdicts


def fdb_gathering_flags(fdb: ForeverDB, nodes: list[dict]) -> tuple[list, dict]:
    """`(flags, verdicts)`: each node or herb name against ForeverDB's object names (obj)."""
    flags, verdicts = [], {}
    for n in nodes:
        found = n["name"] in fdb.obj_names
        verdicts[n["id"]] = "found" if found else "missing"
        if not found:
            flags.append(_flag("fdb-node", "gathering", n["id"], n["name"], "no ForeverDB object is named %r" % n["name"]))
    return flags, verdicts


def derive_doc(db: DB, seeds: dict, flavor: str, build: str, created: str, date: str, fdb: ForeverDB = None) -> dict:
    missing = db.sentinels() + check_seed_floor(seeds)
    if missing:
        raise SystemExit("coverage gate FAILED: %s. Fix the reader or the fetch before ruling anything."
                         % "; ".join(missing))
    cat = seeds["catalog"]
    flags = (trainer_flags(db, seeds["trainers"], cat["keys"]) + fishing_flags(db, seeds["fishing"])
             + catalog_flags(db, cat))
    candidates = fishing_candidates(db, seeds["fishing"]) + catalog_candidates(db, cat)
    matched = sorted(t["name"] for t in seeds["trainers"] if t["name"] in db.creatures)
    evidence = None
    if fdb is not None:
        tflags, tverdicts = fdb_trainer_flags(fdb, seeds["trainers"], cat["skillLineIDs"])
        gflags, gverdicts = fdb_gathering_flags(fdb, seeds["gathering"])
        flags += tflags + gflags
        evidence = dict(fdb.summary(), verdicts={"trainers": tverdicts, "gathering": gverdicts})
    doc = {
        "flavor": flavor, "product": FLAVORS[flavor], "build": build, "buildCreated": created, "date": date,
        "tool": "tools/seeds/seeds.py derive",
        "shipped": {"trainers": len(seeds["trainers"]), "fishing": len(seeds["fishing"]),
                    "catalog": len(cat["skillLineIDs"]), "alias": len(cat["aliasIDs"]),
                    "openSpell": len(cat["openSpellIDs"]), "iconSpell": len(cat["iconSpellIDs"])},
        "creature": {"tableRows": len(db.creatures), "trainersMatched": matched,
                     "note": "the client's Creature table holds companions and mounts, not trainers: report only"},
        "candidates": candidates, "flags": flags,
    }
    if evidence is not None:
        doc["shipped"]["gathering"] = len(seeds["gathering"])
        doc["foreverdb"] = evidence
    return doc


# ---------------------------------------------------------------------------
# Bundles and rulings
# ---------------------------------------------------------------------------

def bundles(root: Path, flavor: str) -> list[Path]:
    return sorted(p for p in root.glob("*-%s" % flavor) if (p / "candidates.json").exists())


def bundle_build(bundle: Path) -> str:
    return json.loads((bundle / "candidates.json").read_text(encoding="utf-8"))["build"]


def bundle_tag(bundle: Path):
    return (json.loads((bundle / "candidates.json").read_text(encoding="utf-8")).get("foreverdb") or {}).get("tag")


def status_line(live: str, found: list[Path], tag: str = None) -> str:
    """`CURRENT <build> (<bundle>)` or `NEW <build> ...`; the first word is what
    /dev-copilot:validate-seeds reads. With `tag` (the newest ForeverDB tag), the newest bundle is
    current only when its build and its tag are both the newest."""
    if not found:
        return "NEW %s (no bundle yet)" % live
    built = bundle_build(found[-1])
    had = bundle_tag(found[-1]) if tag else None
    if built == live and had == tag:
        return "CURRENT %s (%s)" % (live + (" + ForeverDB %s" % tag if tag else ""), found[-1].name)
    if built == live:
        return "NEW %s (ForeverDB %s; last ruled %s, %s)" % (live, tag, had or "none", found[-1].name)
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
    f = doc.get("foreverdb")
    if f:
        lines += ["## ForeverDB (second evidence source, clients-§10)", "",
                  "ForeverDB's data is GPL-3.0, so this bundle keeps no raw rows: only the pin below, the "
                  "per-id verdicts in `candidates.json` (`foreverdb.verdicts`) and the flags. A replay "
                  "re-fetches the pinned tag, which is immutable, through dev-copilot's "
                  "`scripts/foreverdb.py fetch --tag %s --date <date>`." % f["tag"], "",
                  "- Repository: https://github.com/foreverfraddons/forever-db",
                  "- Tag: `%s`, commit `%s` (TOC `## Version` %s; meta.build %s, meta.hash `%s`)"
                  % (f["tag"], f.get("commit") or "unknown", f.get("tocVersion"), f.get("build"), f.get("hash")),
                  "- Fetched: %s, from %s" % (f.get("fetched"), " + ".join(f.get("origin") or ())),
                  "- Helper: %s" % (f.get("helper") or "not recorded")]
        if f.get("install"):
            lines.append("- Owner's install read: version %s (`%s`), confirmed against the tag by its sha256"
                         % (f["install"].get("version"), f["install"].get("path")))
        lines += ["- Spot tolerance: %.1f map-%% (the trainer probe's)" % f.get("spotTolerance", SPOT_TOLERANCE), "",
                  "| File | Bytes | sha256 (as fetched) | sha256 (LF) |", "| --- | --- | --- | --- |"]
        for fl in f.get("files") or ():
            lines.append("| `%s` | %s | `%s` | `%s` |" % (fl.get("path"), fl.get("bytes"), fl.get("sha256"), fl.get("sha256LF")))
        lines += ["", "URLs: %s" % ", ".join("`%s`" % u for u in f.get("urls") or ()) or "URLs: none (install read)", ""]
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
    f = doc.get("foreverdb")
    if f:
        tally_v: dict = defaultdict(int)
        for v in f["verdicts"]["trainers"].values():
            for part in ("npc", "side", "spot", "role"):
                if part in v:
                    tally_v["%s %s" % (part, v[part])] += 1
        for v in f["verdicts"]["gathering"].values():
            tally_v["node %s" % v] += 1
        lines += ["ForeverDB %s (commit %s) verdicts: %s." % (f["tag"], (f.get("commit") or "unknown")[:12],
                                                           ", ".join("%s %d" % kv for kv in sorted(tally_v.items()))), ""]
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


def fdb_cache_root(override: Path = None) -> Path:
    """dev-copilot scripts/foreverdb.py's cache root (its cache_root())."""
    if override is not None:
        return override
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return Path(base) / "ka0s-seeds" / "foreverdb"


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
    print(status_line(live_build(FLAVORS[args.flavor])["version"], bundles(args.root, args.flavor), args.foreverdb_tag))
    return 0


def cmd_derive(args) -> int:
    product = FLAVORS[args.flavor]
    prior = args.bundle / "candidates.json"
    old: dict = {}
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
    fdb_dir, helper = args.foreverdb, args.foreverdb_helper
    if args.replay and fdb_dir is None and old.get("foreverdb"):
        fdb_dir = fdb_cache_root(args.foreverdb_cache) / old["foreverdb"]["tag"]
        helper = helper or old["foreverdb"].get("helper")
        if not (fdb_dir / "SOURCES.json").exists():
            raise SystemExit("--replay: the bundle pins ForeverDB %s, which is not cached; re-fetch it (the tag is "
                             "immutable): foreverdb.py fetch --tag %s --date <date>" % (old["foreverdb"]["tag"],
                                                                                         old["foreverdb"]["tag"]))
    tables, sizes = bundle_tables(args.bundle, build, args.replay, args.cache_dir)
    fdb = ForeverDB(fdb_dir) if fdb_dir is not None else None
    doc = derive_doc(DB(tables), read_seeds(args.defaults), args.flavor, build, created, args.date, fdb)
    if fdb is not None:
        doc["foreverdb"]["helper"] = helper
    write_json(prior, doc)
    write_repo_text(args.bundle / "SOURCES.md", format_sources(doc, sizes))
    unruled = unruled_keys(doc, load_rulings(args.rulings))
    log("build %s%s: %d candidates, %d flags, %d unruled; shipped %s" % (
        build, " + ForeverDB %s" % fdb.tag if fdb else "", len(doc["candidates"]), len(doc["flags"]), len(unruled),
        doc["shipped"]))
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
    s.add_argument("--foreverdb-tag", default=None, help="the newest ForeverDB tag (foreverdb.py status)")
    d = sub.add_parser("derive", help="flags and candidates into the bundle's candidates.json")
    d.add_argument("--flavor", choices=sorted(FLAVORS), required=True)
    d.add_argument("--bundle", type=Path, required=True)
    d.add_argument("--date", type=_date, required=True)
    d.add_argument("--build", default=None, help="pin this build instead of the live one")
    d.add_argument("--replay", action="store_true", help="read only the bundle's raw/, no network")
    d.add_argument("--foreverdb", type=Path, default=None,
                   help="the folder `foreverdb.py fetch --tag <tag> --date <date>` printed (ForeverDB evidence)")
    d.add_argument("--foreverdb-helper", default=None,
                   help="which foreverdb.py made that folder (e.g. `dev-copilot 2.12.0 <commit>`), for SOURCES.md")
    d.add_argument("--foreverdb-cache", type=Path, default=None,
                   help="the helper's cache root (default ${XDG_CACHE_HOME:-~/.cache}/ka0s-seeds/foreverdb), "
                        "where --replay finds the bundle's pinned tag")
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
