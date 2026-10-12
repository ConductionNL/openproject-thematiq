# Tokens and variables

This page explains what a design system is to the plugin and how its tokens reach OpenProject's CSS.

## A design system is eighteen tokens

| Token | Kind |
|---|---|
| `primary`, `primary-deep`, `primary-light`, `action`, `action-deep`, `link`, `accent`, `ink`, `text`, `muted`, `line`, `soft`, `ground`, `chip`, `field` | A CSS colour |
| `radius`, `radius-lg` | A CSS length |
| `font-family` | A CSS font stack |

The plugin makes no network requests. Every design system comes from a file in the plugin or from OpenProject's own settings. [catalogue.md](catalogue.md) describes the file.

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

A design system may bring a `dark` block next to `tokens`: the fifteen colour roles, each optional.

```json
{ "id": "example", "name": "Example", "tokens": { "primary": "#1a67a3" }, "dark": { "primary": "#0b1f33", "ink": "#f0f6fc" } }
```

When a set has one, the generator writes a fourth block for `body[data-color-mode="dark"][data-dark-theme="dark"]`. It holds only the roles the block names. Everything else stays OpenProject's own dark colour. White surfaces of the light theme are never copied into the dark theme.

None of the 64 bundled design systems has a `dark` block today, and the plugin does not derive one. So the dark theme keeps OpenProject's own colours, and only radius and font follow the tokens there. The two high contrast themes always keep OpenProject's colours.

"Sync with OS" was not tested. By reading the source: OpenProject then leaves the theme attributes off the page and sets them with a script. The plugin's rules apply when that script sets `data-color-mode` to `light` or `dark` with the matching theme attribute.

## Run the tests

```bash
bin/test
```

The tests use the Ruby of the OpenProject image and need no database. To check the image itself, follow [development.md](development.md).
