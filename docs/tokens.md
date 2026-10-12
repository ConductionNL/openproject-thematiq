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
- Font stacks: up to 12 families, each a plain name or a quoted name.

A value that fails falls back to the last resort value for that token, in `lib/open_project/thematiq/tokens/defaults.rb`. A file that ships with the plugin gets the same check as any other input.

The last resort values have no `accent`, `text` and `chip`. The variables for those three are then left out, so OpenProject's own values apply.

## How the tokens reach the page

`OpenProject::Thematiq::Variables::Generator` writes three blocks:

1. `:root` gets radius and font. These apply in every colour mode.
2. `[data-color-mode]` gets the `--thematiq-*` colour aliases, filled from Primer's own variables.
3. The light theme gets the token colours, on OpenProject's variables, on Primer's variables and on the `--thematiq-*` aliases.

A design system has no dark values. So the dark theme and both high contrast themes keep OpenProject's own colours. Only radius and font follow the tokens there.

## Run the tests

```bash
bin/test
```

The tests use the Ruby of the OpenProject image and need no database. To check the image itself, follow [development.md](development.md).
