# Testing — Ka0s Skill Master

## The headless suite

```sh
KA0S_KIT_CLIENT=forever lua tests/run.lua        # serial
KA0S_KIT_CLIENT=forever lua tests/run.lua --list # the case inventory, written to docs/test-cases.md
```

**Forever profile only** (clients-§6, clients-§9): this is a `Forever` addon, so every run, the
commit gate included, sets `KA0S_KIT_CLIENT=forever`, as the standard writes the commands. The
suite is also pinned: `tests/client_pin.lua` wraps the kit Loader's `MockClient.apply` so every mock
set defaults to the Forever profile, and `tests/run.lua`, `tests/perf.lua` and
`tests/degraded_env.lua` call it right after loading the kit. A bare `lua tests/run.lua` or
`tests/_kit/run-automated-tests.sh` therefore runs as Forever too, and `KA0S_KIT_CLIENT=retail`
raises: a Retail run tests a client the addon does not ship on. The kit is not edited.

The harness is the vendored LibKa0s testkit in `tests/_kit/` (never edited; a kit problem is fixed
upstream and re-vendored). `tests/run.lua` loads `libs/LibKa0s/LibKa0s.xml`'s files and the TOC's
files into one mocked environment, runs `OnInitialize`, and declares every suite: the addon's own
under `tests/` and the kit's (`test_eol`, `test_prose`, `test_layout_cap`, `test_diagnostics_contract`,
`test_lizard_sighted`, `test_skin_values`, `test_skin_switch`, `test_client_globals`) by directory.
`tests/wow_mock.lua` is a thin extender over the kit's base mock. Three suites are named by the
rules that mandate them: `test_surface_parity` (testing-§8, every degradation stub against a real
library-absent load from `tests/degraded_env.lua`), `test_vendor_sync` (testing-§11, delegating to the
kit) and `test_disabled` (slash-commands-§7's ten steps). `test_m5_leftovers` holds the M5 closing
cases, among them the display-glyph guard (`Kit.assertDisplayGlyphs` over `modules/`, `settings/`,
`locales/`, `core/` and `defaults/`: no string literal carries a character a shipped skin face cannot
draw) and the profile pin's own cases.

Several kit suites read `git ls-files`, so a new file must be staged before it is checked.

## Lint

```sh
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .   # 0 warnings / 0 errors
```

`tests/` is linted; only `libs/`, `tests/_kit/` and the frozen stores are excluded (`.luacheckrc`).

## The green commit gate

Both commands above, green, before every commit (testing-§4). Nothing else gates a commit.

| Suite | What it is | Checkpoint |
|---|---|---|
| lint | `luacheck .` | gates every commit and the tag |
| tests | the headless suite, Forever profile | gates every commit and the tag |
| perf | the offline scenarios (`tests/perf.lua`) | recorded at release; gates the tag only through the release battery |
| complexity | `lizard` over the kit's sighted shadow | recorded at release; the tag needs zero functions above CCN 15 |

The gate as one command: `KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded
tests/_kit/run-automated-tests.sh --no-bundle` (all four suites, nothing written; lizard reports no
function above CCN 15). The full four-suite record is `tests/_kit/run-automated-tests.sh --release X.Y.Z` at release
([automated-tests/README.md](automated-tests/README.md)).

## Also

- [test-cases.md](test-cases.md) — the generated inventory, the authoritative pass count behind the
  README's tests badge. Regenerate it, and the badge, whenever the suite changes.
- [smoke-tests.md](smoke-tests.md) — the in-game checks, run by the owner on WoW Forever.
