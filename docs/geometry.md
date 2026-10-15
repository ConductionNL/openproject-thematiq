# Geometry

The geometry layer sets sizes and spacing. It is the same for every token set.

## Where it lives

`stylesheets/geometry/` holds one file per region. The head hook inlines them after the variable layer, in file name order.

| File | Region |
|---|---|
| `10-variables.css` | Sizes OpenProject exposes as variables |
| `20-top-bar.css` | Top bar |
| `30-sidebar.css` | Sidebar |
| `40-page-header.css` | Page frame and page header |
| `50-controls.css` | Buttons, inputs and selects |
| `60-table.css` | Work package table |

Each rule has a comment with the value from `spike/OP-TWIN-canon.md` it stands for.

## Rules for this layer

- Selectors are OpenProject 17.9 class names. They can change with an OpenProject release, so keep each rule small and tied to one canon value.
- No colour literals. Use the `--thematiq-*` aliases from the variable layer. Outside the light theme they point at Primer's own values, which keeps the dark and high contrast themes readable.
- No text in generated content. The spike wrote the app name with `::after`. That is left out, because screen readers do not read it reliably. The shell adds the app name as real markup.
- `bin/test` checks these rules.

## Measured against the canon

Measured with computed styles at 1440 x 1000 on the work package table of the demo project, light theme.

| Part | Canon | OpenProject 17 | With the plugin |
|---|---|---|---|
| Top bar height | 68 px | 55 px | 68 px |
| Sidebar width | 264 px | 280 px | 264 px |
| Navigation item height | 42 px | 36 px | 42 px |
| Primary button height | 48 px | 34 px | 48 px |
| Table row height | 44 px | 40 px | 44 px |
| Body text size | 15 px | 14 px | 15 px |
| Table header row height | 44 px | not measured | 45 px |

The table header row is 1 px over. Its bottom border adds to the 44 px.

To change a size, edit the file for its region and run `bin/test`.
