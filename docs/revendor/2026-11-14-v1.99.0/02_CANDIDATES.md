# Candidates

## A. Delivered on the copy

- The `v1.99.0` tag itself: the provenance line names a tag again, and `tests/test_vendor_sync.lua`
  goes back to the kit's default tag pattern.

## B. Host change required

None. Nothing in `faa4621..v1.99.0` moved under a major Skill Master consumes.

## C. Whole-module adoption

1. **`LibKa0s-Callout-1.0`** (key 2.3): the center-screen call-out and countdown, now with its
   settings as host schema rows (`SchemaRows`) on the host's write route. Evidence: LibKa0s
   `CHANGELOG.md`, the v1.98.0 block; `docs/api/Callout/version-2.3-docs.md`. Would touch a new
   module, `settings/Schema.lua`, `defaults/Profile.lua` and a settings page. Additive. No recorded
   decline exists. Recommendation: never or not now; Skill Master has no countdown or center-screen
   text.
