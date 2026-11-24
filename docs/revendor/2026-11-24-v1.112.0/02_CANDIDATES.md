# 02 Candidates: LibKa0s v1.109.0 -> v1.112.0

Source: the tag's `CHANGELOG.md` v1.110.0 to v1.112.0 blocks and the API documents they link (Core 20.1, Widgets
30.3.7.17.3.8.8.7.2.2, Skin 18.1.28.11.20.19.2.1.21.1.4.9, Compat 6, testkit 60).

## A. Reached this addon on the re-vendor alone

- A disabled primary button paints as a disabled button (SkinPaintControls minor 21). None is disabled here today.
- High Contrast's HUD shadow at 1, -1 (SkinDefsOthers minor 11): the detached bars' text under High Contrast.
- The copy window as a companion (WidgetsCopyWindow minor 7): the debug console's Copy opens a window with the
  close alone.
- The test kit's client profiles carry the bank shape (revision 60). Nothing here reads the bank.

## B. Host change required

- `HeaderButtons(bar, { companion = true })` for the trainer popup: item FB-SM-03.
- `FollowColor` for the class -> skin -> swatch ladder: item FB-SM-02.

## C. Whole-module adoption

None new in this range (no file or major added).
