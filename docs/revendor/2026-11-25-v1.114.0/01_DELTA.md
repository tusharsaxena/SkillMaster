Delta: LibKa0s v1.113.0 -> v1.114.0

Recorded for item SF-SM-02 of Ka0sAddonsCommonTasks `docs/2026-11-25-SEEDS_AND_FOREVERDB/` (its `03_SPEC.md` §8
answer 1 and §9). It follows the copy, provenance, icon-declaration and prune mechanics of
`/dev-copilot:wow-revendor-libka0s`. The adoption interview and the issue filing are skipped because the run's spec
pre-decides the work: the one adoption in scope is `LibKa0s-ForeverDB-1.0`. The payload comes from the local tag:
`git -C ../LibKa0s archive v1.114.0 LibKa0s testkit tools` (tag local only for this run, commit `2eaa8fc9`).

## Step 0 pre-flight

The newest single-tag bundle is `2026-11-24-v1.113.0`, base v1.112.0. The provenance line before its re-vendor
(`2b3fdb3`) named v1.112.0. Result: ok, no base correction.

## 3a Base

- `grep -n '[Bb]undles' CLAUDE.md` printed line 42, `... v1.113.0 (MIT).`
- `git log -1 --format=%H -- libs/LibKa0s tests/_kit` is `2a84ed3`, whose CLAUDE.md names v1.113.0. They agree.
- Before the copy, `diff -rq --strip-trailing-cr` of the v1.113.0 extract against `libs/LibKa0s` printed only the
  pruned media, and against `tests/_kit` printed nothing.
- Range: `git -C ../LibKa0s log --oneline v1.113.0..v1.114.0` is 8 commits (SF-LK-01, SF-LK-02, SF-LK-REL).

## 3b/3c Per-file minors that moved

| File | Old | New |
|---|---|---|
| ForeverDB.lua | (new) | MINOR 1 (`LibKa0s-ForeverDB-1.0`) |
| DebugLogDiagnostics.lua | DIAG_MINOR 11 | 12 |

`LibKa0s.xml` gains `ForeverDB.lua` after `Item.lua`. No file was removed. The minors in the old payload matched the
v1.113.0 claim.

## 3d Diffs

After the copy and before the prune, both content and byte diffs were empty in both directions for both payloads.
After the prune, the only differences from the extract are `Only in <extract>/LibKa0s/media/icons` (the undeclared
icons) and `Only in <extract>/LibKa0s/media/sounds` (362 files, `LibKa0s sounds: none.`).

## 3e Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/`: DebugLog is consumed
(`core/DebugLogSetup.lua`, `modules/Diagnostics.lua`). ForeverDB had no lookup before this run; SF-SM-02 adds one
(`modules/ForeverDBSources.lua`).

## 3f Kit revision

`Kit.VERSION` 60 -> 62. Revision 61 adds the opt-in `mock_foreverdb.lua`; revision 62 regenerates
`client_globals_forever.lua` at Ketho `e230342` (10559 names: 17 added, 3 removed, none called here). Both payloads
move together, as the pairing rule requires.

## 3g Contract delta

- **DebugLogDiagnostics minor 12**: the report's `LibKa0s running:` line names ForeverDB, and the identity section
  ends with one `ForeverDB: present=... loaded=... version=...` line from `Status()`, which never loads ForeverDB.
  No member change. No suite here pins `DebugLogDiagnostics 11` or the report's exact line count. No blocker.
- `client_globals_forever.lua` drops `C_GameRules.SetForeverExperiencePreset`, `ShouldShowBattlePetIcon` and
  `SmartNavigation_SetReturnFrameFocusButton`; `grep -rn` finds none of them in this addon. No blocker.

## 3h Unrecorded tags

The audit listing (vendored tags since the store's horizon minus recorded bundle tags) printed nothing. No span
bundle.

## 3i Icon declaration

Kept unchanged (CLAUDE.md:43). The prune refused nothing and removed only undeclared icons and the voice packs.
README credits unchanged (Open Iconic and Phosphor still ship).

## 3j Whole-folder icon tests

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` printed nothing.
`__releaseChrome` has no mirror here.

## Other new surfaces

None beyond ForeverDB and the diagnostics line. The task scopes adoption to ForeverDB alone, so there is nothing else
to record as declined.
