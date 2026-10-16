# Accessibility

This page says what was measured, what was not, and which design systems fall short.

## Contrast of text

The plugin puts text on a design system's colours. `OpenProject::Thematiq::Contrast` computes the WCAG 2 contrast for six pairs, and `bin/test` runs it over every design system in the catalogue.

| Pair | Where it shows |
|---|---|
| White on `primary` | The top bar |
| White on `action` | The main button |
| `ink` on `ground` | Main text on the page background |
| `muted` on `ground` | Labels and hints on the page background |
| `link` on white | Links and work package numbers in a table |
| `primary-deep` on `primary-light` | The selected menu item |

### Result for the 64 bundled design systems

White on `primary` and white on `action` reach 4.5 to 1 in all 64.

No other pair is under 4.5 to 1. Until the catalogue of 16 October 2026 three were: the selected menu item of `haarlemmermeer` (4.23), `noordoostpolder` (4.30) and `vught` (4.35), their `primary-deep` on `primary-light`. Since then every set carries a menu colour (thematiq #1300), and a set with a menu colour gets the plugin's rule for the selected item: its own `primary-deep` when it reads, else white or near black, whichever reads. For these three that is near black, 15 to 1. The other 61 keep their own `primary-deep`.

The text on the main menu follows the same rule, the set's ink when it reads on the menu. Every menu is white except `noordwijk` (`#f2f7fa`, black text, 19.5 to 1).

A custom design system gets the same check. The picker marks it when a pair falls short.

### The dark theme

The same pairs are computed for each set's dark block, with links on the page background in place of white.

- No bundled dark block is left out any more. The rule stays: a dark block whose main text does not read on its page background, 4.5 to 1, is not used. Until the catalogue of 13 October 2026 it left out seven sets.
- The selected menu item reads in every bundled dark block as the catalogue gives it. The plugin's contrast rule still picks a text colour that reads, for a design system you import.
- 63 dark blocks carry a menu colour, which the dark theme now draws, with the text on it by the same rule. Every one reads at 7 to 1 or more.

### The search field and the current tile of the top bar

Both lay a little of the bar's text colour over the bar: 12% for the search field and 16% for the current tile, as in the design. On a bar that is just dark enough for white, that layer takes white under 4.5 to 1. The plugin makes the layer as strong as the design allows while the text on it keeps 4.5 to 1, in the light and the dark theme. On Zuiddrecht both become 10%, `#4a78ae`, 4.58 to 1; on Cunningham nothing changes. A test holds this for every bundled set. In the high contrast themes the bar is OpenProject's and the layer is the design's.

### What the check does not cover

- It reads hex colours, `rgb()` and `rgba()`. For another syntax it answers "unknown". The test fails when a bundled set has an unknown pair, so none has one today.
- It covers the light theme and the dark blocks. In the high contrast themes the colours are OpenProject's own.
- It covers six pairs, not every text on every surface.

## Not checked in a browser

These need a running OpenProject and were not done:

- Keyboard order through the enlarged top bar, sidebar and table.
- Whether the focus ring stays visible on the 40 px buttons, the 42 px menu items and the cards of the picker.
- A screen reader on the picker and the editor.

The picker and the editor are plain forms with native radio buttons, text fields and buttons, a label on every field and an error text tied to its field. That is by construction, not by test.

To check contrast after a catalogue change, run `bin/test` and update the table above.
