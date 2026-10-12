# Tokens and variables

This page explains where the plugin gets its design tokens and how they reach OpenProject's CSS.

## Where the tokens come from

The plugin reads the active token set from thematiq:

```
GET <nextcloud base url>/apps/thematiq/api/shell-tokens
```

The answer is one JSON document with `version`, `id`, `name`, `revision`, `tokens` and `logo`. The plugin supports `version` 1.

| Token | Kind |
|---|---|
| `primary`, `primary-deep`, `primary-light`, `action`, `action-deep`, `link`, `accent`, `ink`, `text`, `muted`, `line`, `soft`, `ground`, `chip`, `field` | A CSS colour |
| `radius`, `radius-lg` | A CSS length |
| `font-family` | A CSS font stack |

## When the plugin fetches

- A background job asks thematiq every five minutes. It sends the last `revision` in `If-None-Match`, so an unchanged set costs one small request.
- An admin can fetch at once from the admin page.
- A page request never fetches. It reads the stored copy from OpenProject's settings.

A fetch waits at most 3 seconds for the connection, 5 seconds for data and 8 seconds in total. It does not follow redirects and it refuses an answer over 256 KB.

## What happens when thematiq does not answer

The plugin keeps the last token set it fetched. A failed fetch never removes it.

Without a base URL, or before the first good fetch, the plugin uses the bundled default set in `lib/open_project/thematiq/tokens/defaults.rb`. That set has no value for `accent`, `text` and `chip`. The variables for those three are left out, so OpenProject's own values apply.

## How a value is checked

A token value ends up inside a `<style>` tag. So the plugin accepts a value only when its whole text matches a known syntax:

- Colours: hex, a named colour, or `rgb()`, `hsl()`, `hwb()`, `lab()`, `lch()`, `oklab()` and `oklch()` with plain numbers.
- Lengths: `0`, or a number with `px`, `rem`, `em` or `%`.
- Font stacks: up to 12 families, each a plain name or a quoted name.

A value that fails falls back to the bundled value for that token. The check runs again each time the stored copy is read.

## How the tokens reach the page

`OpenProject::Thematiq::Variables::Generator` writes three blocks:

1. `:root` gets radius and font. These apply in every colour mode.
2. `[data-color-mode]` gets the `--thematiq-*` colour aliases, filled from Primer's own variables.
3. The light theme gets the token colours, on OpenProject's variables, on Primer's variables and on the `--thematiq-*` aliases.

The token set has no dark values yet. So the dark theme and both high contrast themes keep OpenProject's own colours. Only radius and font follow the tokens there.

## Try it without a Nextcloud

`docker/fake-thematiq.rb` answers like the endpoint. Start it inside the container:

```bash
docker exec -d openproject-thematiq ruby /app/custom-plugins/openproject-thematiq/docker/fake-thematiq.rb
```

Then use `http://127.0.0.1:9911` as the base URL.

## Run the tests

```bash
bin/test
```

The tests use the Ruby of the OpenProject image and need no database. To check the image itself, follow [development.md](development.md).
