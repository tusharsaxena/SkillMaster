# Common tasks — Ka0s Skill Master

## Add a setting

- Add its default to `defaults/Profile.lua`.
- Add one row to the page file that owns it (`settings/General.lua` today) with `path`, `page`,
  `group`, `type`, `label`, `desc`, `default` (read from `NS.defaults`) and `onChange`.
- Give the label and desc `enUS` keys in `locales/enUS.lua`.
- Run the suite: `test_schema` checks the path resolves against the defaults and carries a group.

## Add a slash verb

- Append a `{name, L["desc"], function(rest) ... end}` triple to `NS.COMMANDS` in `settings/Slash.lua`.
- A feature verb is refused while disabled by the dispatcher; add nothing for that.
- Add its desc to `locales/enUS.lua`; `test_disabled` step 7 will check its refusal line.

## Add a bus message

- Add the constant to `NS.MSG` in `core/Bus.lua` with its sender and payload in a comment.
- Send with `NS.bus:SendMessage(NS.MSG.X, ...)`; subscribe on a target from `NS.NewBusTarget()`.
- Add its row to `ARCHITECTURE.md`'s Message Bus table and to `test_bus`.

## Add a locale string

- Add `L["The English text"] = true` to `locales/enUS.lua` and use `L["The English text"]` at the call
  site. The key is the English string, in US spelling (localization-§5). Write each key once, and
  delete it when its last reader goes: `test_locale` fails on a missing, a repeated or an unread key.
- A translation goes in `locales/<locale>.lua` (stubs for deDE, esES, esMX, frFR, itIT, koKR, ptBR,
  ruRU, zhCN, zhTW), below that file's `GetLocale()` gate, keyed by the enUS string, with the same
  format directives in the same order.

## Add a perf bucket

- Declare it in `core/PerfSetup.lua`'s `buckets`, bracket the code with
  `local t0 = Perf.on and debugprofilestop()` / `if t0 then Perf.Note("key", debugprofilestop() - t0) end`,
  and extend `tests/test_perf.lua` so the bucket is shown to be reached.
