# openproject-thematiq

An OpenProject plugin that gives OpenProject the same shell as a Nextcloud themed with [thematiq](https://github.com/ConductionNL/thematiq). A user who moves from one product to the other sees the same top bar, navigation, buttons, inputs and tables.

The plugin works on its own. It needs no Nextcloud and no thematiq, and it makes no network requests. The design systems ship inside the plugin.

**Status: early work.** A spike proved the route on OpenProject 17.9.1 community edition. The plugin itself is being built on the `development` branch.

## How it works

1. The plugin ships a catalogue of design systems. Each one is a set of eighteen design tokens.
2. An administrator picks a design system on the "Thematiq design" page in OpenProject's administration.
3. The plugin writes the tokens to the CSS variables OpenProject already uses, and adds a geometry layer for sizes and spacing.
4. It renders the shared top bar and project menu through OpenProject's layout hooks.

The designs are on [identity.conduction.nl/screens](https://identity.conduction.nl/screens/?ds=openproject#openproject).

## What is in this repository now

- The plugin gem at the repository root: `openproject-thematiq.gemspec`, `lib/`, `app/`, `config/` and `stylesheets/`.
- `docker/`: the image that runs OpenProject with the plugin.
- `spike/`: the throwaway plugin, the generated stylesheet and the measuring scripts from the spike, kept as a reference.
- `spike/OP-TWIN-canon.md`: the sizes the shell is measured against.

To build and run it, follow [docs/development.md](docs/development.md). To choose a design system, follow [docs/admin-page.md](docs/admin-page.md).

## Licence

EUPL-1.2
