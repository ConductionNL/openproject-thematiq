# Design: a frontend route next to the default route

**Status: decided by the owner, being built.** The plugin reaches 151 of thematiq's capabilities without a frontend build. A second install route rebuilds OpenProject's Angular frontend with the plugin's own Angular module, so the rows that need the frontend can be built. The default route stays the default and does not change.

Everything below was read in the image `openproject/openproject:17.9.1` (pinned by digest in `docker/Dockerfile`) or measured on it. Where a number is an estimate, it says so.

## What OpenProject 17.9.1 offers a plugin

OpenProject has a mechanism for plugins with a frontend. Its own modules use it: budgets, costs, avatars, documents, GitHub, GitLab, meetings and wikis each ship a `frontend/module/main.ts`.

| Part | What it does | Where in core |
|---|---|---|
| The `:opf_plugins` group | A gem in this group of the Gemfile counts as a plugin. `docker/Gemfile.plugins` already puts this plugin there | `lib/open_project/plugins/frontend_linking/generator.rb`, `load_known_opf_plugins` |
| `frontend/module/` in the gem | A plugin with this folder gets a symlink `frontend/src/app/features/plugins/linked/<gem name>` to it | `create_frontend_plugins_links` |
| `frontend/module/main.ts` | Must export an `NgModule` named `PluginModule`. The generator imports it into `linked-plugins.module.ts`, which `app.module.ts` imports. So the plugin's module is part of the application, loaded on every page that boots Angular | `generate_plugin_module`, `linked-plugins.module.ts.erb` |
| `frontend/module/global_styles.*` | Optional. Imported into OpenProject's global Sass | `generate_plugin_sass`, `frontend/src/global_styles/openproject.sass` |
| `rake openproject:plugins:register_frontend` | Writes the links and the two generated files | `lib/tasks/plugins.rake` |
| `rake assets:angular` | Links the plugins, runs `npm run build` in `frontend/`, then writes `config/frontend_assets.manifest.json`, the map Rails reads to find the hashed bundle files | `lib/tasks/assets.rake`, `lib/open_project/assets.rb` |
| `preserveSymlinks: true` | The Angular build resolves the plugin's imports (`@angular/core`, `core-app/...`) from OpenProject's `frontend/`, not from the plugin's real folder | `frontend/angular.json` |
| The plugin context | `window.OpenProject.pluginContext` holds core services (toasts, modals, the API client, I18n, path helper and more) and four hooks for work package context menus and creation. For code outside the Angular compiler; a linked module can inject services directly | `frontend/src/app/features/plugins/plugin-context.ts`, `hook-service.ts` |
| Custom elements | A linked module registers its components as custom elements (`registerCustomElement('opce-...', Component, { injector })`), so a server view renders them with `angular_component_tag` | `modules/avatars/frontend/module/main.ts` |
| Frontend strings | `rake assets:export_locales` writes every `*.js.*` key of every loaded locale file, the plugin's included, to `frontend/src/locales/`. A string the module shows lives under `en.js.thematiq` | `config/i18n.yml` |

### What the image ships, and what it leaves out

- The frontend sources are in the image: `frontend/` is 29 MB, with `package-lock.json`, `angular.json` and `src/`.
- `node_modules` is not. `docker/prod/setup/precompile-assets.sh` removes it after the image's own build.
- Node 24.19.0 and npm are in the image, at `/usr/local/bin`.
- The built frontend is in `public/assets/frontend` (140 MB of the 236 MB in `public/assets`).

### Why OpenProject's documented step does nothing here

OpenProject's Docker documentation, "Using this container with custom plugins", runs `./docker/prod/setup/precompile-assets.sh` after `bundle install`. That script starts with:

```bash
if [ -f config/frontend_assets.manifest.json ]; then
  echo "Assets have already been precompiled. Reusing."
```

The official image ships that manifest, so on top of the image the script never compiles anything. A plugin's Angular module is never linked. This is why `docker/Dockerfile` notes that the step does nothing, and why the frontend route runs the steps of `assets:angular` itself.

### Two things that break when the steps run on top of the image

1. **The schema cache.** The image carries `db/schema_cache.yml`, written after its own asset build. Rails reads it at boot, and with the null database (`DATABASE_URL=nulldb://db`, the same trick the image's own build uses) loading it fails with `ArgumentError: undefined class/module ActiveRecord::ConnectionAdapters::PostgreSQL::`. The build stage removes the file. That stage is thrown away, so the final image keeps its cache.
2. **The heap size.** Core's `npm run build` starts node with `--max_old_space_size=4096`, written in `frontend/package.json`. An option on node's command line wins over `NODE_OPTIONS`, so the heap cannot be set from outside the script. The frontend route calls `ng build` itself, with the same flags as core's script and the heap from the build argument `THEMATIQ_NODE_MEMORY_MB` (6144 by default). Core files are not edited.

## The route

`docker/Dockerfile` gets stages, and the default stays the last one, so a build without `--target` gives the same image as today.

| Stage | From | What it does |
|---|---|---|
| `plugin` | the pinned OpenProject image | The plugin and `Gemfile.plugins`, `bundle install`. What the Dockerfile does today |
| `frontend-build` | `plugin` | `npm ci` in `frontend/`; `register_frontend` and `export_locales` with the null database; `ng build` with the plugin's module linked; `assets:rebuild_manifest`; a stamp `frontend-build.json`. Thrown away |
| `frontend` | `plugin` | The default image with the rebuilt `public/assets/frontend`, the new manifest and the stamp copied in. No `node_modules`, no build cache |
| `default` | `plugin` | The default route. Last, so it is what `docker build` gives |

```bash
# Default route, unchanged
docker build -f docker/Dockerfile -t openproject-thematiq:17 .

# Frontend route
docker build -f docker/Dockerfile --target frontend -t openproject-thematiq:frontend .

# Frontend route with compose, on port 8081, with volumes of its own
docker compose -f docker/compose.yml --profile frontend up -d --build openproject-frontend
```

The compose service is named on purpose: `--profile frontend up` without a service name starts both instances.

The stamp names the plugin version and a digest of `frontend/module/`. At runtime the plugin compares it with the sources on disk, so the admin page says one of three things: the default route, the frontend route in step, or a frontend route built from older module sources (a plugin updated without a rebuild).

## What it costs

Measured once on the machine of the build lane, 16 October 2026: 14 CPU threads, 23 GB of memory shared with other work, Docker Desktop on WSL 2, the OpenProject image already on disk, no build cache.

| Step | Time |
|---|---|
| `bundle install` (the default route does this too) | 31 s |
| `npm ci` in `frontend/`, 1,163 packages | 67 s |
| `register_frontend` and `export_locales` | 59 s |
| `ng build --configuration production` | 82 s (the bundle itself in 80 s) |
| `assets:rebuild_manifest` and the stamp | 14 s |
| **The whole frontend target** | 266 s, about four and a half minutes |

| What | Measured |
|---|---|
| Peak memory of the `ng build` step (the step's cgroup `memory.peak`) | 5,912 MB. The cgroup counts the page cache too, so the heap itself is less |
| Heap given to node | 6144 MB (`THEMATIQ_NODE_MEMORY_MB`) |
| Image size, default route | 2.27 GB |
| Image size, frontend route | 2.41 GB: 143 MB more, the new bundle in a layer of its own over the old one |
| Build cache the frontend target leaves behind (`node_modules` and the stage's layers) | About 1.25 GB per build: 1.05 GB of `node_modules`, 174 MB of bundle, the rest small |

This is far less than feared: the Angular build is esbuild, not webpack. On a GitHub runner (4 CPU threads, 16 GB) it is slower; the CI job's timings are the number for that machine. A 10 GB free-memory rule for the build machine leaves room for the 6 GB the step took.

**Upgrade work per OpenProject release**, on top of what the default route already needs (`core_guard.rb`, the checksums, the pixel diff):

1. Bump the image digest, as today. The frontend route builds from the same `FROM`.
2. Build the frontend target. A changed `assets.rake`, `frontend_linking/` or `angular.json` shows up here first: the build fails, it does not pass quietly.
3. The plugin's module imports OpenProject's own code (`@openproject/octicons-angular` for the icon pack). A renamed or removed export breaks the build of the module, which is the point: the default route never sees it.
4. Run the e2e suite with `THEMATIQ_E2E_FRONTEND=1` against the frontend route.

Estimate, not measured: half an hour per release when nothing moved, a day when core reorganised the frontend.

**Risks.**

- The frontend route ships a bundle OpenProject did not build. A bug in it is the plugin's to find.
- OpenProject's frontend build is not something core promises plugins outside its repository. Core's own eight modules use the mechanism, but it is internal and can change in any release.
- Memory: the build needs several GB free. The compose file says so, and the CI job runs on a 16 GB runner.

## The eight open rows, one by one

| Row | Needs the frontend route? | Why |
|---|---|---|
| `ast-icon-pack` | **Yes** | The Angular pages draw icons from `@openproject/octicons-angular`, compiled into the bundle. The package exports each icon's data (`gearIconData`, ...) as one shared object that the component and `toDOMString` read. A linked module can import those objects and replace their paths before the first page renders. Without a build, the only way in is to rewrite the DOM after Angular, which Angular would undo or fight |
| `ast-icon-pack-indicator` | With the icon pack | A line on the admin page, server side. It needs nothing from the frontend itself, but it says which pack is active, and on the default route the answer is "none can be" |
| `cat-design-system-choice` | **No** | Choosing a whole design system (NL Design System, La Suite, high contrast, a soft light theme) is a layer above the colour sets in the catalogue and the admin page, and a shell layer per design system. All of that is server side and CSS. The one part that needs the frontend is the icon pack a design system brings, which comes with `ast-icon-pack`. The row stays with the shell lane |
| `x-workplace-layout` | **Only for a new kind of card** | The Home grid is `opce-my-page`, an Angular element. Restyling its widgets as cards on a quiet surface is CSS: no build. A new widget type (a card the design draws that OpenProject has no widget for) needs `Grids::Configuration.register_widget` on the server and an Angular component in the bundle: that half needs the frontend route. Which cards the design wants is shell work, in the shell lane's round |
| `cat-design-system-docs` | **No** | The reason is data: the catalogue carries no address of a design system's own documentation. A link needs that address first |
| `sur-mobile-desktop-clients` | **No** | The reason is a client: nothing shows that OpenProject's mobile app reads a theme value. A frontend build changes the web bundle, not another app |
| `gov-federated-share` | **No** | The reason is a connection: a live share between instances needs one instance to fetch the other's configuration. An admin-enabled, off by default connection could do it, like the gallery's; that is a server change, not a frontend one |
| `sur-generated-documents` (PDF styling) | **No** | Stopped by the owner. The PDF exporters read `CustomStyle` only; a frontend build does not reach them |

So the frontend route unlocks two rows: the icon pack and its indicator. The other six keep a reason that is not the frontend.

## The icon pack on the frontend route

How it is built, so the PR can be checked against it:

1. **Which pack.** As thematiq does it: the active token set's design system names its packs (`nldesign`: rvo, open-gemeenten, den-haag; `lasuite`: dsfr), a set without a design system counts as `nldesign`, and an administrator may override. The plugin ships the table in `data/icon-packs.json`, taken from thematiq's `design-systems.json` and `token-sets.json`.
2. **Which icon for which.** OpenProject's icons have other names than the packs'. A table per pack maps an octicon name to a pack icon. rvo and open-gemeenten are pictograms at 48 units, not interface icons, so the Dutch packs map through den-haag's interface icons; dsfr maps through its own. An icon without a counterpart keeps core's.
3. **How it reaches the page.** The head hook names the pack in a `meta` tag. The plugin's Angular module waits for the pack's JSON (a static file of the plugin, same origin, cached) in an app initializer, then replaces the paths of the mapped icon data objects. Every Angular icon drawn after that has the pack's shape. Icons the server renders (`Primer::Beta::Octicon`, class `octicon-<name>`) are swapped by the same module when they enter the page.
4. **What it does not reach.** The old icon font (`icon-*` classes) keeps core's glyphs. Each one needs a drawn counterpart and a CSS rule, which is work per icon, not per route.
