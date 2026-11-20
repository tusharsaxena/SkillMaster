# 02 Candidates: LibKa0s v1.107.0 -> v1.108.0

Source: the tag's `CHANGELOG.md` v1.108.0 block and the API documents it links (Options, Widgets, WaypointArrow,
Skin, testkit 58).

## A. Reached this addon on the re-vendor alone

- The footer lays only its shown marks (LibKa0s#94, Widgets minor 30). This addon's footers show every mark they
  hold, so there is no visible change.
- The drag-strip tooltip's readable-ancestor fallback (LibKa0s#99) and the call-out's close and settings marks
  (LibKa0s#100). This addon draws neither.
- `W.BarStyle`'s gloss under Glass (`glossFromSkin`, default true) on every data bar drawn in the skin's texture, and
  the shared menu's submenu arrow tinted from the menu palette.
- The skin guards of test kit revision 58 (per-family comparison, the StatusBar fill check).

## B. Host change required

- WaypointArrow 3.3's `fontColorFromSkin` and `fontShadowFromSkin`: the seeds and the skin listener are the run's
  SD-SK-SM.2 and SD-SK-SM.3, not offered here.
- `W.OwnerWarnings(owner, sink)` (Widgets minor 30, new): a debug-gated report of a library widget built with no owner
  under an owned window. Not pre-decided by the run; noted for the lead.
- `Core.ApplySkin`'s `skinBands`: this addon's windows are painted by `S.Shell`, so it has no use.

## C. Whole-module adoption

None new in this range (no file or major added).
