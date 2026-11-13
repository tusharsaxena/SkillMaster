-- tests/test_vendor_sync.lua — the vendored-payload gate (testing-§11), delegated to the kit.
--
-- libs/LibKa0s/ and tests/_kit/ must be byte-identical to what LibKa0s published at the ref the
-- root CLAUDE.md provenance line names; the comparison is the kit's, nothing is reimplemented here.
--
-- The ref is a tag (`vX.Y.Z`) or, while the payload is vendored from an unmerged LibKa0s branch
-- (round 8, R8-5: the waypoint arrow before its tag), a commit sha: the kit's default pattern reads
-- only a tag, so this one reads either. A documented deviation (docs/ARCHITECTURE.md); with the
-- tag re-vendored, the line names a tag again and this pattern still reads it.
local PROVENANCE = "[Bb]undles %[LibKa0s%]%b() ([v%x][%w%.]*)"

local VendorSync = dofile("tests/_kit/vendor_sync.lua")
VendorSync.register(_G.SKM_TEST, { provenancePattern = PROVENANCE })
