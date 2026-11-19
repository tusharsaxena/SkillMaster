Delta: LibKa0s v1.106.0 -> v1.106.0 (span: v1.106.0)

Written 2026-11-19 by AF-RV-SM, beside `../2026-11-19-v1.107.0/`. A records-only back-fill: the one tag this addon
vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-11-14
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt ends ... v1.101.0 v1.105.0 v1.106.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.106.0
```

v1.106.0 was vendored by `6b43bd7` (base v1.105.0) on the LibKa0s v1.105 adoption run's branch, which kept no
revendor bundle for it.
