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

Four design systems have another pair under 4.5 to 1:

| Design system | Pair | Contrast |
|---|---|---|
| `cunningham` | `muted` on `ground` | 4.49 |
| `haarlemmermeer` | `primary-deep` on `primary-light` | 4.23 |
| `noordoostpolder` | `primary-deep` on `primary-light` | 4.30 |
| `vught` | `primary-deep` on `primary-light` | 4.35 |

The plugin does not change these colours. They come from thematiq, and the fix belongs there. The picker marks each of the four with a line that names the pair.

A custom design system gets the same check. The picker marks it when a pair falls short.

### What the check does not cover

- It reads hex colours, `rgb()` and `rgba()`. For another syntax it answers "unknown". The test fails when a bundled set has an unknown pair, so none has one today.
- It covers the light theme. In the dark theme and the high contrast themes the colours are OpenProject's own.
- It covers six pairs, not every text on every surface.

## Not checked in a browser

These need a running OpenProject and were not done:

- Keyboard order through the enlarged top bar, sidebar and table.
- Whether the focus ring stays visible on the 40 px buttons, the 42 px menu items and the cards of the picker.
- A screen reader on the picker and the editor.

The picker and the editor are plain forms with native radio buttons, text fields and buttons, a label on every field and an error text tied to its field. That is by construction, not by test.

To check contrast after a catalogue change, run `bin/test` and update the table above.
