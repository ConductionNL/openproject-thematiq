# openproject-thematiq

An OpenProject plugin that gives OpenProject the same shell as a Nextcloud themed with [thematiq](https://github.com/ConductionNL/thematiq). A user who moves from one product to the other sees the same top bar, navigation, buttons, inputs and tables.

The plugin works on its own. It needs no Nextcloud and no thematiq, and it makes no network requests unless an administrator turns on the [gallery](#the-gallery-and-the-catalogue-notice), which is off by default. The design systems ship inside the plugin.

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

The plugin is early work. It styles the light and the dark theme. In OpenProject's high contrast themes OpenProject's own colours stay; in OpenProject 17.9.1 you switch to them with **Increase contrast** under **My account**, **Interface**. E-mail keeps OpenProject's look unless you turn on [e-mail in the house style](#e-mail-in-the-house-style). Error pages get the colours and the font, not the sizes. A logo ships for 15 of the 64 design systems and a font for 52; the rest keep OpenProject's logo and fall back to a font on the reader's device. You can upload a logo, icons and fonts for a custom design system. PDF exports keep OpenProject's look; [docs/enterprise-parity.md](docs/enterprise-parity.md) has the full comparison with OpenProject's Enterprise design page. The `-slim` image, the packaged installation and the Enterprise edition are untested. Only English is translated.

## Usage

### Pick a design system

1. Open **Administration**, then **Thematiq design**.
2. Type part of a name in **Search design systems** and select **Search**, or scroll the list.
3. Select a design system and select **Apply**. A page shows what changes: the shell now and after, and every value that differs, light and dark. Nothing is applied yet.
4. Untick a value to keep its value of now. Then the result is saved as a new custom design system.
5. Select **Apply**. The page repaints at once. Everyone else sees the design system on their next page.

### Try a design system first

On the page of step 3, select **Try it yourself first**. Only you see that design system, on every page, until you select **Publish to everyone** or **Discard** in the banner at the foot of the page. A trial ends by itself after a day.

### Legal links, a brand stripe and a sign-in background

- **Legal links.** Under **Legal links**, give the addresses of a privacy statement, an imprint and an accessibility statement. They show at the end of every page and on the sign-in page, in the design system's footer colours.
- **Brand stripe.** A design system with thematiq's three stripe colours draws them under the top bar, in their ratios.
- **Sign-in background.** A custom design system can carry a photo for behind the sign-in page: upload it under **Logo, icons and fonts**.

### Try a design system on OpenProject's components

**Playground**, a link on **Thematiq design**, shows OpenProject's own components in each state: buttons, fields with an error and disabled, messages, labels, a counter and a list. Choose a design system and only that page's content area wears it. Nothing is applied. Under **Your own component**, paste HTML and CSS you are building: your CSS reads the design system's variables, such as `var(--thematiq-primary)`, in a frame that runs no script; nothing is stored. A design system's component tokens (text fields, selects, the secondary button, the table, the navigation and more) reach the matching Primer variables.

### Government icons

The plugin ships thematiq's government icon sets (RVO, OpenGemeenten, Den Haag, DSFR; 2,526 icons, each rebuilt by the plugin's SVG check), with their licences. Any app on the instance uses an icon by name at `/thematiq/icons/<set>/<name>.svg`; `/thematiq/api/v1/icons` lists them. **Icon library** on Thematiq design shows the sets.

### The gallery and the catalogue notice

thematiq publishes its catalogue of design systems. Under **Gallery**, a link on **Thematiq design**, turn on **Read the gallery from the address below**: the plugin then reads that one https address (thematiq's own on GitHub, or one you give). **Check now** lists the design systems this plugin does not have, or has with other values, and **Add** makes one a custom design system. The picker checks once a day and says when thematiq published a newer catalogue; **Dismiss** hides that until the next one. This is the plugin's only network connection, and it is off until you turn it on. A nightly workflow in this repository proposes the newer catalogue as a pull request.

### A shared light or dark choice

Turn on **Let another product set a person's light or dark choice by link**. Another product, such as Nextcloud with thematiq, then links a signed-in person to `/thematiq/appearance?mode=dark&return_to=/` (or `light`, or `system`) to set their OpenProject choice the same way and send them back. `return_to` may be a path here or an address under the Nextcloud address. It is only a link the person follows; off by default.

### E-mail in the house style

Under **E-mail**, tick **Send e-mail in the house style**: every e-mail OpenProject sends gets a band in the primary colour with the app's title and the logo at the top, and your organisation's text and the legal links at the end. Mail clients drop style sheets, so all of it is inline. OpenProject's own header and footer texts stay. It is off until you turn it on.

### Plan a switch

Under **Planned switch**, choose a design system and a date and time. The first page after that time makes the switch, for everyone, and the history names it. There is no background job: on a quiet instance the switch happens with the first visitor after the time.

### Lock a project's design system

On a project's **Project settings**, **Design**, an instance admin can tick **Lock this project's design system**. Its project admins then see it, but cannot change it.

### Go back to an earlier version

Every change is kept in **History**, a link on **Thematiq design**: when, who, and what. Select **Restore** next to a change. A page lists what the restore changes. Nothing is written until you select **Restore this version**. A restore is a change of its own, so it can be undone too. Uploaded logos, icons and fonts are not part of a version.

### Edit a design system

1. On **Thematiq design**, select **Customise** next to the design system you want to start from.
2. Give it a name and change the values you want. They are in four groups: branding, content area, buttons and links, typography. Under **More values** is thematiq's full vocabulary in closed groups, such as status colours, forms and tables; each value says whether OpenProject draws it. Leave a field empty to keep the original value.
3. Watch the preview beside the form. It follows what you type, and nothing is saved yet. Each colour shows the contrast of the text that goes with it.
   Each colour also has a field for the dark theme, empty to keep the dark value of the base, and an opacity control next to its colour picker. Above the preview, choose whether to see it as the design system of the instance or a project (the whole page) or of a module (the content area only).
4. A changed value has the badge **Changed**. **Reset** puts one value back, **Reset group** a whole group.
5. Select **Save and apply**.

You can keep up to 50 custom design systems.

### Start from your colours

1. On **Thematiq design**, under **Start from your colours**, give a name, your main colour and a background colour.
2. Select **Open in the editor**. The plugin works out the shades of the main colour and a link colour that reads on white. Nothing is saved yet: the editor shows every value and its contrast.
3. Change what you want and select **Save and apply**. Add a logo once it is saved, under **Logo, icons and fonts**.

### Bring your own house style

- **A CSS file of design tokens.** On **Thematiq design**, under **A CSS file of design tokens**, choose a file with custom properties as thematiq writes a token set (`--nldesign-color-primary` and so on, dark values in a block or media query that says dark). References with `var()` are followed. The file becomes a new custom design system, and a page lists what was read and what was left out.
- **An NL Design System theme.** Under **An NL Design System theme**, choose a built theme CSS, a W3C Design Tokens JSON or a Style Dictionary `tokens.json`. thematiq's own converter table (`data/mapping/nlds-to-nextcloud.json`, vendored from thematiq) decides what each token becomes and what is worked out when the theme has none. A report lists every token and what was left out. Component tokens are not carried.
- **A font library.** Under **Font library**, upload your organisation's fonts once. Every design system whose font names the family uses them, the shipped ones too; a design system's own upload of the same family wins.
- **Your own CSS.** Under **Your own CSS**, write rules for what the tokens cannot say and turn it on. The plugin reads it part by part and writes it anew: style rules and `@media` only, no `@import`, no `url()`, no escapes. One part that does not fit refuses all of it, and the parts are named. It comes last on every page.
- **Your own tokens.** Under **Your own tokens**, add a value as `--thematiq-org-<name>`, with a dark value if you like. It is on every page for your CSS and other plugins.

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

## Run it in production

### Move the whole setup

**The whole setup** on Thematiq design downloads one file with everything: the design system in use, the custom design systems, the rules for projects, the Nextcloud address, the tiles of the top bar and the choices per project and module. Read it on the other OpenProject under the same heading: a page shows what it changes, and nothing changes until you select **Import this setup**. Projects are matched by identifier. Uploaded logos, icons and fonts are not in the file.

### The history for an auditor

**Download the history as CSV**, next to the setup download, gives every change with its time, who made it, what and whether it can still be restored.

### From the command line

Run these in OpenProject's directory. In the compose instance: `docker compose -f docker/compose.yml exec openproject bash -lc 'cd /app && bundle exec rake thematiq:status'`.

| Task | What it does |
|---|---|
| `rake thematiq:status` | The design system in use and the counts |
| `rake thematiq:list` | Every design system, id and name |
| `rake "thematiq:apply[zuiddrecht]"` | Makes a design system the one in use |
| `rake "thematiq:bundle:export[setup.json]"` | Writes the setup to a file, or to the screen without one |
| `rake "thematiq:bundle:import[setup.json]"` | Makes a configuration file the setup. With `DRY_RUN=1` it only lists the changes |
| `rake thematiq:history` | The newest 50 changes |
| `rake "thematiq:restore[42]"` | Restores a version of the history. `DRY_RUN=1` works here too |
| `rake thematiq:health` | The health report as JSON; exits 1 when something is degraded |

A task that changes the setup leaves a row in the history.

### The design system as code

Set the environment variable `THEMATIQ_DESIGN_SYSTEM` to the id of a design system, for example `zuiddrecht`. It wins over the admin page, which then says so and turns Apply off. An id that is not there is ignored, and the admin page and the health report say so. `docker/compose.yml` passes the variable through: `THEMATIQ_DESIGN_SYSTEM=zuiddrecht docker compose -f docker/compose.yml up -d`.

### A branding package that applies itself

Set `THEMATIQ_BUNDLE_FILE` to the path of a configuration file inside the container, mounted from your deployment. When OpenProject starts, the plugin makes it the setup, once per version of the file: an unchanged file is not applied again, so later changes on the admin page stay until the file changes. A file that does not read is refused whole and the log says why; OpenProject starts anyway. Each application is a row in the history.

### An environment marker

Under **Environment marker**, give a label such as Test and a colour: it shows at the top of every page, the sign-in page included, so nobody works in the wrong OpenProject. `THEMATIQ_ENVIRONMENT_LABEL` sets it as code and wins over the field.

### Deprecated tokens

Under **Deprecated tokens**, mark a token your organisation is moving away from: a severity, what to use instead and by when. Nothing changes value; the editor shows the notice next to the token and other apps read the list at `/thematiq/api/v1/deprecations`. Past its date it says "Due for removal" and still works.

### A brand manager who is not an administrator

Give someone a global role with the permission **Manage the design**. They see **Thematiq design** in the administration and can do everything on it, and nothing else of the administration. Their changes carry their name in the history.

### A contrast report for an audit

**Contrast report for an audit**, on **Thematiq design**, lists every design system in use, for the instance, each project and each module, with each pair of text and background the shell draws, light and dark, against WCAG 2.1 success criterion 1.4.3. Print it or download it as JSON; `rake thematiq:compliance[report.json]` writes the same, and `STRICT=1` makes it fail on a pair under 4.5 to 1. `docs/contrast-report.md` and `docs/token-reference.md` are generated from the code by `script/generate-docs.rb`.

### Read endpoints for other apps

Other apps on this OpenProject read the catalogue, one design system, its style sheets, own tokens, deprecations, the icon list and a contrast check; another product reads the design system in use in thematiq's shell-tokens shape. [docs/api.md](docs/api.md) lists them.

### Metrics

Set `THEMATIQ_METRICS_TOKEN` to a secret of 24 characters or more, and `GET /thematiq/metrics` answers Prometheus' text format to a scraper that sends `Authorization: Bearer <token>`: whether the plugin is healthy, the design system in use, the counts of custom design systems, scopes and history rows. Without the variable the address answers 404. It opens no connection itself: the scraper comes to it.

### Health

`GET /admin/thematiq/health`, for an administrator, answers JSON: the version, the catalogue, the design system in use, whether the plugin's tables are there and whether a core file the shell leans on changed. The status is 200 when all is well and 503 with a list of problems otherwise. `rake thematiq:health` gives the same without a session.

## What is in this repository now

- The plugin gem at the repository root: `openproject-thematiq.gemspec`, `lib/`, `app/`, `config/` and `stylesheets/`.
- `docker/`: the image that runs OpenProject with the plugin.
- `spike/`: the throwaway plugin, the generated stylesheet and the measuring scripts from the spike, kept as a reference.
- `spike/OP-TWIN-canon.md`: the sizes the shell is measured against.

To build and run it, follow [docs/development.md](docs/development.md). To choose a design system, follow [docs/admin-page.md](docs/admin-page.md).

## Licence

EUPL-1.2
