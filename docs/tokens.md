# Tokens and variables

This page explains what a design system is to the plugin and how its tokens reach OpenProject's CSS.

## A design system is eighteen tokens

| Token | Kind |
|---|---|
| `primary`, `primary-deep`, `primary-light`, `action`, `action-deep`, `link`, `accent`, `ink`, `text`, `muted`, `line`, `soft`, `ground`, `chip`, `field` | A CSS colour |
| `radius`, `radius-lg` | A CSS length |
| `font-family` | A CSS font stack |

The plugin makes no network requests. Every design system comes from a file in the plugin or from OpenProject's own settings. [catalogue.md](catalogue.md) describes the file.

## One optional role: the menu background

A design system may have a nineteenth value, `menu`: the background colour of the main menu. Without it the menu is white, as before.

With it, the plugin works out the text colours itself, so a dark menu stays readable:

- The text on the menu is the set's `ink` when that reaches 4.5 to 1 on the menu, and white or near black otherwise.
- The text on the selected item is the set's `primary-deep` when that reads on `primary-light`, and white or near black otherwise.
- Inside the menu, the plugin's colour aliases take the menu's values. Rules written for a white menu keep working on a coloured one.

The same rule decides the text on the top bar and on the main button: white wherever white reads. That is so for all 64 sets from thematiq, so nothing changes for them. A set with a light top bar gets dark text.

## How a value is checked

A token value ends up inside a `<style>` tag. So the plugin accepts a value only when its whole text matches a known syntax:

- Colours: hex, a named colour, or `rgb()`, `hsl()`, `hwb()`, `lab()`, `lch()`, `oklab()` and `oklch()` with plain numbers.
- Lengths: `0`, or a number with `px`, `rem`, `em` or `%`.
- Font stacks: up to 20 families, each a plain name or a quoted name.

A value that fails falls back to the last resort value for that token, in `lib/open_project/thematiq/tokens/defaults.rb`. A file that ships with the plugin gets the same check as any other input.

The last resort values are Cunningham's, the default design system. A test keeps them the same as Cunningham in the catalogue.

## How the tokens reach the page

`OpenProject::Thematiq::Variables::Generator` writes three blocks:

1. `:root` gets radius and font. These apply in every colour mode.
2. `[data-color-mode]` gets the `--thematiq-*` colour aliases, filled from Primer's own variables.
3. The light theme gets the token colours, on OpenProject's variables, on Primer's variables and on the `--thematiq-*` aliases.

## The dark theme

A design system may bring a `dark` block next to `tokens`, with the colour roles for the dark theme. The catalogue has one for 63 of its 64 sets. thematiq derives them; the plugin derives nothing.

```json
{ "id": "example", "name": "Example", "tokens": { "primary": "#1a67a3" }, "dark": { "tokens": { "primary": "#558fe3", "ink": "#e2e3e4" } } }
```

For such a set the generator writes one more block, for `body[data-color-mode="dark"][data-dark-theme="dark"]`. It holds only the roles the dark block names. Everything else stays OpenProject's own dark colour. White surfaces of the light theme are never copied into the dark theme. Radius and font in a dark block are ignored: they do not change with the theme.

Two rules guard the dark theme:

- **A dark block is only used when its main text reads on its page background**, 4.5 to 1. No bundled set fails that since the catalogue of 13 October 2026. Before it, seven did. The rule stays for a design system you import: when it fails, the dark theme keeps OpenProject's own colours.
- **The text on the selected menu item follows a contrast rule.** The plugin takes the dark block's own `primary-deep` when it reads on its `primary-light`, and otherwise whichever of its `ink` and white reads best. No bundled set needs the second step since the corrected catalogue.

With these two rules, every dark block that is used reaches 4.5 to 1 on all six pairs. A test holds that.

A set without a dark block, and the three OpenProject themes, keep OpenProject's own dark colours.

**High contrast.** The two high contrast themes always keep OpenProject's own colours. A person who asks for more contrast should get the colours that were made for that.

In OpenProject 17.9.1 the switch for them is **Increase contrast** under **My account**, **Interface**: with **Light** it gives the light high contrast theme, with **Dark** the dark one. The two other checkboxes in OpenProject's code for this (`force_light_theme_contrast` and `force_dark_theme_contrast`, for **Sync with OS**) are not shown on that page in 17.9.1.

**Sync with OS** was not tested. By reading the source: OpenProject then leaves the theme attributes off the page and sets them with a script. The plugin's rules apply when that script sets `data-color-mode` to `light` or `dark` with the matching theme attribute.

## Run the tests

```bash
bin/test
```

The tests use the Ruby of the OpenProject image and need no database. To check the image itself, follow [development.md](development.md).
