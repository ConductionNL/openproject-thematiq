# Development

This page shows how to build OpenProject with the plugin and run it on your machine.

## What you need

- Docker
- About 4 GB of free memory for the OpenProject container

## Build the image

Run this from the repository root. The build takes under a minute once the base image is on disk.

```bash
docker build -f docker/Dockerfile -t openproject-thematiq:dev .
```

The image starts from `openproject/openproject:17`. `docker/Gemfile.plugins` adds the plugin to the `opf_plugins` group, which is how OpenProject finds it.

## Run it

```bash
docker run -d --name openproject-thematiq \
  -p 127.0.0.1:8080:80 \
  -e OPENPROJECT_HOST__NAME=localhost:8080 \
  -e OPENPROJECT_HTTPS=false \
  -e SECRET_KEY_BASE="$(openssl rand -hex 32)" \
  -v openproject-thematiq-pgdata:/var/openproject/pgdata \
  -v openproject-thematiq-assets:/var/openproject/assets \
  openproject-thematiq:dev
```

The first start seeds the database and takes a few minutes. Open `http://localhost:8080` and sign in as `admin` with password `admin`. OpenProject asks for a new password on the first sign in.

## Check that the plugin loaded

1. Open **Administration**, then **Plugins**. The list shows "Thematiq" with its version.
2. View the source of any page. The head has a `<style id="openproject-thematiq">` tag.

Pages on the sign in layout do not get the style tag. OpenProject only calls the head hook from its base layout.

## Change the code

The plugin is copied into the image, so a change needs a rebuild and a new container. The volumes keep the database.

```bash
docker stop -t 90 openproject-thematiq && docker rm openproject-thematiq
docker build -f docker/Dockerfile -t openproject-thematiq:dev .
```

Then run the `docker run` command again.

## Where things live

| Path | What it holds |
|---|---|
| `lib/open_project/thematiq/engine.rb` | The Rails engine and the plugin registration |
| `lib/open_project/thematiq/hooks.rb` | The view hooks |
| `lib/open_project/thematiq/tokens/` | The token model: token set, validator, last resort values |
| `data/catalogue/`, `lib/open_project/thematiq/catalogue.rb` | The design systems that ship with the plugin, and their loader |
| `lib/open_project/thematiq/variables/` | The variable layer: tokens to CSS variables |
| `lib/open_project/thematiq/store.rb` | What the plugin keeps in OpenProject's settings |
| `app/controllers/thematiq/`, `app/views/thematiq/admin/` | The admin page |
| `test/` | The unit tests, run with `bin/test` |
| `app/views/thematiq/hooks/` | The partials the hooks render |
| `stylesheets/` | The static CSS layers the head hook inlines after the variable layer, in file name order |
| `config/locales/` | All text a user reads |
| `docker/` | The development image |
| `spike/` | The throwaway spike, kept as a reference |

`lib/open_project/thematiq/shell/` and `app/views/thematiq/shell/` are reserved for the shared top bar and project menu.

Next, read [catalogue.md](catalogue.md) for the design systems that ship with the plugin, [tokens.md](tokens.md) for how the tokens reach the page, [geometry.md](geometry.md) for the sizes and [admin-page.md](admin-page.md) for the page an administrator uses.
