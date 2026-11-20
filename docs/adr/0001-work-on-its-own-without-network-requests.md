# 1. The plugin works on its own and makes no network requests by default

- Status: accepted
- Source: [README.md](../../README.md) (introduction) and [docs/tokens.md](../tokens.md) ("A design system is eighteen tokens")

## Context

The plugin gives OpenProject the look of a Nextcloud themed with thematiq. It could have read its design systems from a running thematiq or Nextcloud, or from a remote service. That would tie an OpenProject installation to another product being reachable.

## Decision

The plugin works on its own. It needs no Nextcloud and no thematiq. The design systems ship inside the plugin, as files in `data/catalogue/`, or come from OpenProject's own settings. The plugin makes no network requests unless an administrator turns on the gallery or the pull of another instance's setup, and both are off by default.

## Consequences

- An installation without outbound network access gets the full feature set apart from those two opt-in features.
- The catalogue in the plugin has to be refreshed from thematiq by a change to this repository ([docs/catalogue.md](../catalogue.md) says how), not at runtime.
- Any new feature that needs the network has to be off by default and turned on by an administrator, as the gallery and the setup pull are.
