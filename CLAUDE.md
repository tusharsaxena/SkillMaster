# CLAUDE.md — Ka0s Skill Master

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard** (URL above). All development here — features,
refactors, doc changes — MUST conform to it. The standard is the source of truth for layout, TOC
shape, the Ace substrate, schema-driven settings, slash/prefix conventions, locales, Compat,
tests/lint, and doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a row in
   `docs/ARCHITECTURE.md` -> `## Documented deviations`, shaped
   `| Rule | What differs | Why | Decided | Re-check trigger |`, where Rule is the `filename-§N`
   reference. That register is the single home: a deviation not in it is not ratified.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations, documented deviations. What this addon actually is.
- **`docs/testing.md`** — how to verify: the headless harness, lint, and the green commit gate.
- Topic detail in `docs/` as needed (`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`,
  `data-flow.md`, `common-tasks.md`, `debug.md`, `midnight-quirks.md`, `smoke-tests.md`, …).

**WoW Forever only** (roster Clients `Forever`, clients-§9): the suite runs under the Forever kit
profile only. Green gate before every commit: `KA0S_KIT_CLIENT=forever lua tests/run.lua` and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0). The kit bounds the suite on load;
`luacheck` loads no kit, so it runs through the bounded runner (testing-§15). Never
auto-stage/commit/push and never bump the version without an explicit instruction.

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.94.0 (MIT).
LibKa0s icons: chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, document, external-link, fullscreen-exit, info, lock, map-marker, move, reset, settings, unlock, volume-high.
