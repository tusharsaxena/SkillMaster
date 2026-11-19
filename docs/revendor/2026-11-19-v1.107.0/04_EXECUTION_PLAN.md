# 04 Execution plan

One commit, AF-RV-SM: both payloads copied whole from the v1.107.0 extract, the provenance line rolled
(CLAUDE.md:40), the icon declaration kept (CLAUDE.md:41), the prune run with the tag's `tools/prune-icons.lua`,
this bundle and the v1.106.0 span bundle. The standard reference refresh to v2.115.0 rides in the same commit.
No adoption, so no characterization test; the gate is the existing suite, including `tests/test_vendor_sync.lua`.
