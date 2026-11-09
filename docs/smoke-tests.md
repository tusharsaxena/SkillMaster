# Smoke tests — Ka0s Skill Master

In-game checks on **WoW Forever** (client 1.60.1). The owner runs them; an agent never marks one
passed (clients-§6, testing). Each check names what to do and what you should see.

## Load

- **SM-LOAD-1** Log in on Forever. The AddOns list shows Ka0s Skill Master with its logo; no Lua error.
- **SM-LOAD-2** On a **Retail** client, open the AddOns list. Ka0s Skill Master is **not listed**
  (the `ExcludeLoadGameType: standard` gate, clients-§9). This also settles the open evolution the
  standard recorded for the Forever load gate.
- **SM-LOAD-3** On a fresh profile the skin picker opens once, previewing in test mode; it defaults to
  WoW Forever. Apply or close it; it does not open again on that profile.

## Window

- **SM-WIN-1** `/skm toggle` opens the window titled Skill Master; Escape and the close button hide it.
- **SM-WIN-2** Drag it, `/reload`: it reopens where it was dropped. `/skm lock`: it no longer drags.
- **SM-WIN-3** `/skm test`: an amber band says the skills shown are sample data. Enter combat: the
  band disappears and test mode is off.
- **SM-WIN-4** Bind a key under Options → Keybindings → Ka0s Skill Master; it toggles the window.

## Launcher and settings

- **SM-LDB-1** The minimap button shows the logo. Left-click opens the settings; right-click shows
  Enabled, Locked, Test mode, Show window. Hovering shows the status tooltip.
- **SM-CFG-1** Settings → AddOns → Ka0s Skill Master: the landing page lists the slash commands; General
  has Master controls, Skin and Keybindings tabs; Profiles works.
- **SM-CFG-2** Uncheck Minimap button: the button hides, and Reset all settings does not bring it back.

## Disabled

- **SM-OFF-1** `/skm disable`: the window hides, `/skm toggle` answers one disabled line, the key
  binding does nothing, the right-click menu grays all but Enabled. `/skm enable` restores it.

## Probe

- **SM-PROBE-1** `/skm probe`: a copy window opens with a JSON report, `skillLines` holding every
  skill (a collapsed header in the Skills tab is collapsed again afterwards). Copy it and send it to
  the author; it settles the assumed rows in `docs/midnight-quirks.md`.

## Skins and diagnostics

- **SM-SKIN-1** `/skm skin`: pick Ka0s Default, Apply. The window and the debug console change look.
- **SM-DIAG-1** `/skm diagnostics`: the report appears in the debug console with the five sections.
