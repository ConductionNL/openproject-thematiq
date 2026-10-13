# openproject-thematiq

An OpenProject plugin that gives OpenProject the same shell as a Nextcloud themed with [thematiq](https://github.com/ConductionNL/thematiq). A user who moves from one product to the other sees the same top bar, navigation, buttons, inputs and tables.

The plugin works on its own. It needs no Nextcloud and no thematiq, and it makes no network requests. The design systems ship inside the plugin.

**Status: early work.** A spike proved the route on OpenProject 17.9.1 community edition. The plugin itself is being built on the `development` branch.

## How it works

1. The plugin ships a catalogue of 64 design systems, generated from thematiq, and OpenProject's own three colour themes, so the picker lists 67. Each one is a set of eighteen design tokens.
2. An administrator picks a design system on the "Thematiq design" page in OpenProject's administration.
3. The plugin writes the tokens to the CSS variables OpenProject already uses, and adds a geometry layer for sizes and spacing.
4. It renders the shared top bar and project menu through OpenProject's layout hooks.

The designs are on [identity.conduction.nl/screens](https://identity.conduction.nl/screens/?ds=openproject#openproject).

## Try it locally with Docker

This starts a throwaway OpenProject with the plugin on your own machine. You need Docker with Compose and about 4 GB of free memory. It is for trying the plugin out, not for production: it runs without HTTPS and only your own machine can reach it.

1. Get the plugin and start it.

   ```bash
   git clone https://github.com/ConductionNL/openproject-thematiq.git
   cd openproject-thematiq
   docker compose -f docker/compose.yml up -d --build
   ```

2. Wait for the first start. OpenProject creates and fills its database, which takes a few minutes. It took about three minutes on the machine this was tried on, with the OpenProject image already on disk. A later start is faster. This command follows the log; stop following with Ctrl+C once the page opens.

   ```bash
   docker compose -f docker/compose.yml logs -f
   ```

3. Open <http://localhost:8080> and sign in. OpenProject's [Docker documentation](https://www.openproject.org/docs/installation-and-operations/installation/docker/) gives the first login for this image: user `admin`, password `admin`. Choose a new password when OpenProject asks for one.

4. Select your avatar, then **Administration**, then **Thematiq design**. Pick a design system and select **Apply**. [Usage](#usage) has the rest.

Stop it and keep the data:

```bash
docker compose -f docker/compose.yml down
```

Stop it and remove its volumes, so nothing is left:

```bash
docker compose -f docker/compose.yml down -v
```

Is port 8080 already in use? Then the first command fails with "port is already allocated". Put another port in front of every one of these commands, for example `THEMATIQ_PORT=8090 docker compose -f docker/compose.yml up -d --build`, and open that port instead.

To run the end-to-end tests against this instance, follow [docs/testing/e2e.md](docs/testing/e2e.md): `cd test/e2e && npm ci && npx playwright install chromium`, then `THEMATIQ_E2E_URL=http://localhost:8080 THEMATIQ_E2E_PASSWORD='<admin password>' npm test`.

`docker/compose.yml` holds no secret. The first start makes a random `SECRET_KEY_BASE` and keeps it in a volume, because OpenProject needs the same value on every start.

To run a command inside this instance, use `docker compose exec` with the service name `openproject` and a login shell, `bash -lc`. The login shell reads the secret from the volume; without it `bin/rails runner` stops with "INSECURE SECRET_KEY_BASE DETECTED". For example, the list of migrations:

```bash
docker compose -f docker/compose.yml exec openproject bash -lc 'cd /app && bundle exec rake db:migrate:status'
```

Compose names the container `openproject-thematiq-try-openproject-1`. The commands here use the service name, so you do not need it.

## Installation

### What it was tested on

OpenProject 17.9.1, community edition, on the official Docker image `openproject/openproject:17`. Nothing else was tested: no packaged installation, no `-slim` image, no other OpenProject version, no Enterprise edition.

### With Docker

OpenProject installs a plugin by building your own image on top of theirs. These are the steps this repository uses itself.

1. Get the plugin.

   ```bash
   git clone https://github.com/ConductionNL/openproject-thematiq.git
   cd openproject-thematiq
   ```

2. Look at the two files that do the work. `docker/Gemfile.plugins` adds the plugin to the group OpenProject loads plugins from:

   ```ruby
   group :opf_plugins do
     gem "openproject-thematiq", path: "/app/custom-plugins/openproject-thematiq"
   end
   ```

   `docker/Dockerfile` copies the plugin into the image and installs it:

   ```dockerfile
   FROM openproject/openproject:17

   COPY . /app/custom-plugins/openproject-thematiq
   COPY docker/Gemfile.plugins /app/Gemfile.plugins

   RUN bundle config unset deployment && bundle install && bundle config set deployment 'true'
   ```

3. Build the image from the repository root.

   ```bash
   docker build -f docker/Dockerfile -t openproject-thematiq:17 .
   ```

4. Run that image the way you run OpenProject now, with the same volumes and the same environment. Only the image name changes. For a first try on your own machine:

   ```bash
   docker run -d --name openproject-thematiq \
     -p 127.0.0.1:8080:80 \
     -e OPENPROJECT_HOST__NAME=localhost:8080 \
     -e OPENPROJECT_HTTPS=false \
     -e SECRET_KEY_BASE="$(openssl rand -hex 32)" \
     -v openproject-thematiq-pgdata:/var/openproject/pgdata \
     -v openproject-thematiq-assets:/var/openproject/assets \
     openproject-thematiq:17
   ```

5. Sign in as an administrator and open **Administration**. The menu has a new item, **Thematiq design**. **Administration**, **Plugins** lists "Thematiq" with its version.

OpenProject's own instructions for this route are in [Using this container with custom plugins](https://www.openproject.org/docs/installation-and-operations/installation/docker/). They end with an asset precompile step. This plugin does not need it, because it has no frontend code of its own.

### With a packaged installation (DEB or RPM)

This route is untested. OpenProject documents it in [Plugins](https://www.openproject.org/docs/installation-and-operations/configuration/plugins/): a custom Gemfile with the plugin in the `:opf_plugins` group, the `CUSTOM_PLUGIN_GEMFILE` setting and `sudo openproject configure`. Follow their page, and tell us in an issue what you find.

### After an OpenProject upgrade

The plugin lives in your image, so a new OpenProject needs a new image.

1. Pull the new OpenProject image and the latest version of this repository.
2. Build the image again with the command from step 3.
3. Start OpenProject on the new image.

The plugin styles OpenProject by class names that can change between OpenProject versions. After an upgrade, look at the top bar, the sidebar and the work package table before you let users in. The top bar, the project menu and the home page also lean on 17 files of OpenProject itself; when one of them changed, the plugin turns those parts off and says so in the log. [docs/shell-structure.md](docs/shell-structure.md#when-an-openproject-upgrade-breaks-this) tells you what to do then.

### Remove the plugin

The plugin changes none of OpenProject's own data. It has one table of its own, `thematiq_uploads`, for the files you upload.

1. To take that table out, roll its migration back while the plugin is still installed. This deletes every uploaded file, so make a database backup first.

   On the instance from [Try it locally with Docker](#try-it-locally-with-docker):

   ```bash
   docker compose -f docker/compose.yml exec openproject bash -lc 'cd /app && bundle exec rake db:migrate:down VERSION=20261012090000'
   ```

   On a container you started with `docker run --name openproject-thematiq`, as in [With Docker](#with-docker):

   ```bash
   docker exec openproject-thematiq bash -lc 'cd /app && bundle exec rake db:migrate:down VERSION=20261012090000'
   ```

2. Start OpenProject on the plain `openproject/openproject:17` image again, with the same volumes. Do not restart on the plugin's image in between: the image runs the migrations on every start, so a restart with the plugin still installed creates the table again, empty.

If you skip step 1, the table stays in the database. OpenProject works with it there. One row also stays in the `settings` table, named `plugin_openproject_thematiq`, which OpenProject ignores without the plugin. [docs/uploads.md](docs/uploads.md#remove-the-plugin) tells you how to drop the table by hand later.

This was tested on the Docker route with OpenProject 17.9.1, on the compose instance: the rollback, then the plain image on the same volumes (OpenProject starts and works, the plugin's pages answer 404), then the plugin's image again (everything comes back, uploads included when the table was kept). See [the first full test](docs/testing/2026-10-13-first-full-test.md#the-two-experiments-that-change-the-instance).

### What is not supported yet

The plugin is early work. It styles the light and the dark theme. In OpenProject's high contrast themes OpenProject's own colours stay; in OpenProject 17.9.1 you switch to them with **Increase contrast** under **My account**, **Interface**. E-mail keeps OpenProject's look. Error pages get the colours and the font, not the sizes. A logo ships for 15 of the 64 design systems and a font for 52; the rest keep OpenProject's logo and fall back to a font on the reader's device. You can upload a logo, icons and fonts for a custom design system. PDF exports keep OpenProject's look; [docs/enterprise-parity.md](docs/enterprise-parity.md) has the full comparison with OpenProject's Enterprise design page. The `-slim` image, the packaged installation and the Enterprise edition are untested. Only English is translated.

## Usage

### Pick a design system

1. Open **Administration**, then **Thematiq design**.
2. Type part of a name in **Search design systems** and select **Search**, or scroll the list.
3. Select a design system and select **Apply**.

Everyone sees the chosen design system on their next page.

### Edit a design system

1. On **Thematiq design**, select **Customise** next to the design system you want to start from.
2. Give it a name and change the values you want. They are in four groups: branding, content area, buttons and links, typography. Under **More values** is thematiq's full vocabulary in closed groups, such as status colours, forms and tables; each value says whether OpenProject draws it. Leave a field empty to keep the original value.
3. Watch the preview beside the form. It follows what you type, and nothing is saved yet. Each colour shows the contrast of the text that goes with it.
4. A changed value has the badge **Changed**. **Reset** puts one value back, **Reset group** a whole group.
5. Select **Save and apply**.

You can keep up to 50 custom design systems.

### Download for Figma and upload from Figma

1. On **Thematiq design**, select **Figma** next to a design system and choose a format: W3C design tokens, Tokens Studio, or Tokens Studio in its legacy spelling. Your browser saves a token file.
2. To bring a token set in, select **Upload from Figma** on the same page and choose the file. For a Tokens Studio folder, choose all its files at once.
3. The plugin adds a new custom design system and shows what it imported, what it skipped and why. Pick it in the list and select **Apply** to use it.

The W3C file has the layout thematiq writes, so it moves between the two. [docs/figma.md](docs/figma.md) has the formats, the names and what a round trip loses.

### Upload a logo, icons and fonts

A custom design system can carry your own files.

1. On **Thematiq design**, select **Edit** next to your custom design system. A new one must be saved first.
2. Scroll to **Logo, icons and fonts**.
3. Choose a file next to the kind you want and select **Upload**. The limits are stated next to each field.
4. The file is in use at once. **Replace** swaps it, **Remove** takes it away after you confirm.

You can upload a logo, a logo for the coloured top bar, a mobile logo, a favicon, a touch icon and up to 12 font files. For a font, type its family name and pick its weight and style. Then name the same family in the value **Font**.

The plugin checks every file by its content and refuses what it does not know. It rebuilds an SVG file without script. [docs/uploads.md](docs/uploads.md) has the limits and the checks.

### Export and import

Use this to move a design system from one OpenProject to another.

1. On **Thematiq design**, select **Export** next to a design system. Your browser saves a small JSON file.
2. On the other OpenProject, open **Thematiq design**. Under **Import a design system**, choose the file and select **Import**.
3. The file is added there as a new custom design system. Pick it in the list and select **Apply**.

An import never replaces a design system that is there. Uploaded files do not travel in the file: upload them again on the other OpenProject. [docs/admin-page.md](docs/admin-page.md) has the details.

## What is in this repository now

- The plugin gem at the repository root: `openproject-thematiq.gemspec`, `lib/`, `app/`, `config/` and `stylesheets/`.
- `docker/`: the image that runs OpenProject with the plugin.
- `spike/`: the throwaway plugin, the generated stylesheet and the measuring scripts from the spike, kept as a reference.
- `spike/OP-TWIN-canon.md`: the sizes the shell is measured against.

To build and run it, follow [docs/development.md](docs/development.md). To choose a design system, follow [docs/admin-page.md](docs/admin-page.md).

## Licence

EUPL-1.2
