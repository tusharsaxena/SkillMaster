Delta: LibKa0s v1.109.0 -> v1.109.0 (span: v1.109.0)

Written 2026-11-24 by FB-SM-01, beside `../2026-11-24-v1.112.0/`. A records-only back-fill: the one tag this addon
vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-11-14
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt ends ... v1.107.0 v1.108.0 v1.109.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.109.0
```

v1.109.0 was vendored by `5e34844` (base v1.108.0) and re-copied by `41662e7` on the sync follow-ups run's branch,
which kept no revendor bundle for it.
