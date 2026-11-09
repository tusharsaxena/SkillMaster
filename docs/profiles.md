# Profiles — Ka0s Skill Master

AceDB-3.0 profiles are user-visible: the Profiles page (`settings/Profiles.lua`) draws AceDBOptions.

- Every setting except the Minimap button lives in the profile; the Minimap button is per
  installation (`global.minimap`, launcher-§3), so a profile switch never moves or hides it.
- A switch, copy or reset re-runs the migrations, moves the `disabled` hold to the new `enabled`,
  applies the profile's skin, re-applies the window's scale, opacity, lock and position, refreshes
  open panels and shows the first-run skin picker if that profile has not closed it yet.
- The General page's Reset all settings is a profile reset (options-ui-§12): it empties the active
  profile and leaves the others alone.
