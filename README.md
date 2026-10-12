# openproject-thematiq

An OpenProject plugin that gives OpenProject the same shell as a Nextcloud themed with [thematiq](https://github.com/ConductionNL/thematiq). A user who moves from one product to the other sees the same top bar, navigation, buttons, inputs and tables.

The plugin works on its own. It needs no Nextcloud and no thematiq, and it makes no network requests. The design systems ship inside the plugin.

**Status: early work.** A spike proved the route on OpenProject 17.9.1 community edition. The plugin itself is being built on the `development` branch.

## How it works

1. The plugin ships a catalogue of 64 design systems, generated from thematiq. Each one is a set of eighteen design tokens.
2. An administrator picks a design system on the "Thematiq design" page in OpenProject's administration.
3. The plugin writes the tokens to the CSS variables OpenProject already uses, and adds a geometry layer for sizes and spacing.
4. It renders the shared top bar and project menu through OpenProject's layout hooks.

The designs are on [identity.conduction.nl/screens](https://identity.conduction.nl/screens/?ds=openproject#openproject).

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

The plugin styles OpenProject by class names that can change between OpenProject versions. After an upgrade, look at the top bar, the sidebar and the work package table before you let users in. The top bar and the project menu also lean on eight files of OpenProject itself; when one of them changed, the plugin turns those parts off and says so in the log. [docs/shell-structure.md](docs/shell-structure.md#when-an-openproject-upgrade-breaks-this) tells you what to do then.

### Remove the plugin

The plugin changes none of OpenProject's own data. It has one table of its own, `thematiq_uploads`, for the files you upload.

1. To take that table out, roll its migration back while the plugin is still installed. This deletes every uploaded file, so make a database backup first.

   ```bash
   docker exec openproject-thematiq bash -lc 'cd /app && bundle exec rake db:migrate:down VERSION=20261012090000'
   ```

2. Start OpenProject on the plain `openproject/openproject:17` image again.

If you skip step 1, the table stays in the database. OpenProject works with it there. One row also stays in the `settings` table, named `plugin_openproject_thematiq`, which OpenProject ignores without the plugin. [docs/uploads.md](docs/uploads.md#remove-the-plugin) tells you how to drop the table by hand later. Removing the plugin was not tested.

### What is not supported yet

The plugin is early work. It styles the light theme only; the dark theme and the high contrast themes keep OpenProject's colours. E-mail keeps OpenProject's look. Error pages get the colours and the font, not the sizes. A logo ships for 14 of the 64 design systems and a font for 42; the rest keep OpenProject's logo and fall back to a font on the reader's device. You can upload a logo, icons and fonts for a custom design system. PDF exports keep OpenProject's look; [docs/enterprise-parity.md](docs/enterprise-parity.md) has the full comparison with OpenProject's Enterprise design page. The `-slim` image, the packaged installation and the Enterprise edition are untested. Only English is translated.

## Usage

### Pick a design system

1. Open **Administration**, then **Thematiq design**.
2. Type part of a name in **Search design systems** and select **Search**, or scroll the list.
3. Select a design system and select **Apply**.

Everyone sees the chosen design system on their next page.

### Edit a design system

1. On **Thematiq design**, select **Customise** next to the design system you want to start from.
2. Give it a name and change the values you want: colours, corners, font. Leave a field empty to keep the original value.
3. Select **Preview** to see the shell with your values. Nothing is saved yet.
4. Select **Save and apply**.

You can keep up to 50 custom design systems.

### Upload a logo, icons and fonts

A custom design system can carry your own files.

1. On **Thematiq design**, select **Edit** next to your custom design system. A new one must be saved first.
2. Scroll to **Logo, icons and fonts**.
3. Choose a file next to the kind you want and select **Upload**. The limits are stated next to each field.
4. The file is in use at once. **Replace** swaps it, **Remove** takes it away.

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
