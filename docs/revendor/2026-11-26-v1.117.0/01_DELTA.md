Delta: LibKa0s v1.114.0 -> v1.117.0

Recorded for item SMW-00 of `docs/superpowers/plans/2026-11-26-skillmaster-windows.md` (the spec's call "LibKa0s
v1.117.0 is re-vendored first"). It follows the copy, provenance, icon-declaration and prune mechanics of
`/dev-copilot:wow-revendor-libka0s`. The adoption interview and the issue filing are skipped: the release moves only
ForeverDB, which Skill Master no longer reads (ISF-SM-01), so there is no candidate. The payload comes from the local
tag: `git -C ../LibKa0s archive v1.117.0 LibKa0s testkit tools` (commit `966a08cd`).

## Step 0 pre-flight

The newest single-tag bundle is `2026-11-25-v1.114.0`, base v1.113.0. The provenance line before this re-vendor named
v1.114.0. Result: ok, no base correction.

## 3a Base

- `grep -n 'Bundles' CLAUDE.md` printed line 42, `... v1.114.0 (MIT).`
- Before the copy, `diff -rq --strip-trailing-cr` of the v1.114.0 extract against `libs/LibKa0s` printed only the
  pruned media (`media/sounds`), and against `tests/_kit` printed nothing.
- Range: `git -C ../LibKa0s log --oneline v1.114.0..v1.117.0` is 13 commits (IS-LK-01, ISF-LK-01, ISR3-LK-01 and their
  release records).

## 3b/3c Per-file minors that moved

| File | Old | New |
|---|---|---|
| ForeverDB.lua | MINOR 1 | 4 |

No file was added or removed; `LibKa0s.xml` is unchanged.

## 3d Diffs

After the copy and the prune, `diff -rq --strip-trailing-cr` against the extract prints only the undeclared icons and
the 362 voice-pack files (`LibKa0s sounds: none.`), for `libs/LibKa0s`, and nothing for `tests/_kit`.

## 3e Consumption map

ForeverDB has no lookup outside `libs/` (`tests/test_no_foreverdb.lua` pins that). The copy changes no surface this
addon calls.

## 3f Kit revision

`Kit.VERSION` 62 -> 65: `mock_foreverdb.lua`'s fixture rows for ForeverDB minors 2 to 4 and the ForeverDB_Full fake,
all opt-in. Both payloads move together, as the pairing rule requires.

## 3g Contract delta

None reachable: ForeverDB minors 2 to 4 are additive, and no suite here loads the ForeverDB fake.

## 3h Unrecorded tags

v1.115.0 and v1.116.0 were never vendored here, so there is no span bundle.

## 3i Icon declaration

Kept unchanged (CLAUDE.md:43). The prune refused nothing. README credits unchanged.
