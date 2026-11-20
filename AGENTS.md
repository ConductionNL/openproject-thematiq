# AGENTS.md

Instructions for coding agents working in this repository. People can read it too: it only names commands and paths that exist here.

## What this is

openproject-thematiq is an OpenProject plugin (a Ruby gem with a Rails engine) that gives OpenProject the same shell as a Nextcloud themed with thematiq: the same top bar, navigation, buttons, inputs and tables. It works on its own, needs no Nextcloud, and ships its design systems inside the plugin ([README.md](README.md)).

## Setup

Everything runs in Docker, on the pinned image `openproject/openproject:17.9.1`. There is no local Ruby or Node setup to do.

Start a throwaway OpenProject with the plugin on <http://localhost:8080> (first start takes a few minutes, sign in as `admin` / `admin`):

```bash
docker compose -f docker/compose.yml up -d --build
docker compose -f docker/compose.yml logs -f
docker compose -f docker/compose.yml down      # keep the data
docker compose -f docker/compose.yml down -v   # remove the volumes too
```

Set `THEMATIQ_PORT=8090` in front of each command when port 8080 is taken. [docs/development.md](docs/development.md) has the plain `docker run` route and where each part of the code lives.

## Build

```bash
docker build -f docker/Dockerfile -t openproject-thematiq:dev .                      # default route
docker build -f docker/Dockerfile --target frontend -t openproject-thematiq:frontend .  # rebuilds OpenProject's Angular frontend with frontend/module
```

The plugin is copied into the image, so a code change needs a rebuild and a new container. The frontend route is described in [docs/design/frontend-build-variant.md](docs/design/frontend-build-variant.md).

## Test

The three checks CI runs on every pull request ([.github/workflows/test.yml](.github/workflows/test.yml)). They need Docker and the OpenProject image, no database:

```bash
bin/test            # Ruby unit tests, test/**/*_test.rb (Minitest)
bin/test-frontend   # unit tests of the Angular module, test/frontend/**/*.test.ts (node --test)
bin/check-syntax    # compiles every Ruby file, the locale files and the ERB templates
```

End-to-end tests (Playwright) run against a running instance, for example the compose one above. See [docs/testing/e2e.md](docs/testing/e2e.md):

```bash
cd test/e2e
npm ci
npx playwright install chromium
THEMATIQ_E2E_URL=http://localhost:8080 THEMATIQ_E2E_PASSWORD='<admin password>' npm test
```

Run the end-to-end suite only against a test instance: an interrupted run can leave a custom design system named "E2E ..." behind.

## Lint and quality

There is no separate linter configured in this repository. The quality gate is the three commands under Test: `bin/check-syntax`, and `bin/test`, which also checks the rules of the geometry layer ([docs/geometry.md](docs/geometry.md)) and that the generated documents match the code.

When you change tokens or the catalogue, regenerate the two generated documents and commit them (`test/generated_docs_test.rb` fails when they disagree with the code):

```bash
docker run --rm -v "$PWD":/plugin -w /plugin --entrypoint ruby openproject/openproject:17.9.1 -Ilib script/generate-docs.rb
```

On a new OpenProject release, run `script/check-core.rb` inside the image (see its header). It fails when a core file the shell leans on has changed.

## Architecture decisions

The design notes, each with what was decided and why, are in [docs/design/](docs/design/).

## Conventions you can check in the code

- Code is named by what it does: `tokens/`, `variables/`, `store.rb`, `transfer.rb`, `health.rb`, each under `lib/open_project/thematiq/`.
- Design systems are data, not code: they ship as JSON in `data/catalogue/` and are read by `lib/open_project/thematiq/catalogue.rb`. An instance can also be set from configuration (`THEMATIQ_DESIGN_SYSTEM`, `THEMATIQ_BUNDLE_FILE` in `docker/compose.yml`).
- Every token value is checked against a known syntax before it reaches a `<style>` tag ([docs/tokens.md](docs/tokens.md)).
- The geometry layer in `stylesheets/geometry/` uses no colour literals, only the `--thematiq-*` aliases.
- Core OpenProject files are not edited. The plugin uses hooks, its own Rails engine and prepended modules.
- All text a user reads lives in `config/locales/`.
- The plugin makes no network requests unless an administrator turns on the gallery or the pull of another instance's setup.
- Changes a user sees go in [CHANGELOG.md](CHANGELOG.md).

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`, for example `fix(contrast): read rgb() arguments without a backtracking pattern` or `docs(e2e): list the federated share spec`. Work goes to `development` through a pull request; `main` gets merges from `development`.
