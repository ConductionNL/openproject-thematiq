# Shell structure: what a plugin can reach

This page lists every way a plugin can change OpenProject's top bar and project menu, and what each part of the design needs. It was read from the source inside the `openproject/openproject:17` image, version 17.9.1. Check it again on every OpenProject release.

## The short version

- OpenProject builds the top bar and the project menu in **helper methods**, not in views. A view override cannot reach either.
- Four view hooks touch the shell. All four only **add** markup. None can replace or reorder what core renders.
- Most of the design is reachable with CSS on core's own markup, one hook, and three small helper overrides that call `super`.
- This plugin overrides **no core view**.

## Where core renders the shell

| Part | Rendered by | Kind |
|---|---|---|
| Page frame, `<header>`, `<nav id="main-menu">` | `app/views/layouts/base.html.erb` | view |
| Left of the top bar: app switcher, logo | `Redmine::MenuManager::TopMenuHelper#render_top_menu_left` in `lib/redmine/menu_manager/top_menu_helper.rb` | helper |
| App switcher dialog | `TopMenu::ModuleMenu#render_module_top_menu_node` in `lib/redmine/menu_manager/top_menu/module_menu.rb` | helper |
| Search | `TopMenuHelper#render_top_menu_search`, which renders the Angular element `opce-global-search` | helper and Angular |
| Quick add, notifications, help, account | `TopMenuHelper#render_top_menu_right`, with one module each under `lib/redmine/menu_manager/top_menu/` | helper |
| Unread count | The Angular element `opce-in-app-notification-bell`. It polls the API and renders `.op-ian-bell--indicator` | Angular |
| Project switcher | `Header::ProjectSelectComponent` in `app/components/header/` | view component |
| Project menu items | `Redmine::MenuManager::MenuHelper#render_main_menu` in `lib/redmine/menu_manager/menu_helper.rb`, from the items in `config/initializers/menus.rb` | helper |
| Saved queries on the work package page | The menu item `work_packages_query_select`, a child of `work_packages`, with the partial `work_packages/menus/menu` | menu item with a partial |

## Extension points

| Extension point | Where it runs | What it allows |
|---|---|---|
| Hook `view_layouts_base_html_head` | `base.html.erb`, in `<head>` | Add tags to the head. The plugin inlines its CSS here. |
| Hook `view_layouts_base_top_menu` | `base.html.erb`, first thing inside `.op-app-header--end` | Add markup before the quick add button. It cannot reach the logo block or the inside of any button. |
| Hook `module_menu_dialog_content_before` and `module_menu_dialog_content_after` | `module_menu.rb`, inside the app switcher dialog body | Add markup before or after core's module list. Only called when the user has at least one module item. |
| Hook `view_layouts_base_main_menu` | `base.html.erb`, after the menu items | Add markup **below** the project menu. Nothing above it. |
| Hook `view_layouts_base_sidebar` | `base.html.erb`, inside `#sidebar` at the bottom of the menu column | Add markup at the very bottom. |
| Hook `view_layouts_base_body_bottom` | `base.html.erb`, end of `<body>` | Add markup or a script with a nonce. Useful for JavaScript, not for structure. |
| `override_core_views!` | `OpenProject::Plugins::ActsAsOpEngine`. It moves the plugin's `app/views` to the front of the view path | Replace any file under `app/views`, such as the 223 line `base.html.erb`. It does **not** reach helpers or view components, so it cannot change the top bar buttons, the menu items or the project switcher. |
| Menu API: `menu :project_menu, ...` in the plugin's `register` block, or `Redmine::MenuManager.map` | Menu definition | Add, move (`before:`, `after:`, `last:`) or delete menu items. Items keep core's permission check. A `badge:` is a translation key, not a number. The project menu has no groups. |
| `Module#prepend` on a helper or component | Ruby | Wrap any helper method and call `super`. This is how the plugin puts text inside the logo block and the account button. It leans on private method names, so the plugin guards it with checksums. |
| CSS from the head hook | Every page on the base layout | Restyle, hide, reorder visually, and swap an icon with a mask. It cannot add text a screen reader can read. |

A failing hook does not break the page. `OpenProject::Hook.call_hook` rescues the error and logs it, and the page renders without the hook's markup.

## Top bar: item by item

| Item in the design | Mechanism | Status |
|---|---|---|
| Bar height, order, spacing | CSS | Built |
| Logo first, app switcher second | Override `top_menu_left_menu_items`: call `super`, move the first element to the end. Done in the markup so the focus order matches what you see | Built |
| App name as real text | Override `render_logo`: `super` plus a `<strong>` with `Setting.app_title` | Built |
| App switcher as a two column popover | CSS on core's dialog. It stays a modal dialog, so focus trap and Escape keep working | Built |
| App switcher, Nextcloud column | Hook `module_menu_dialog_content_before` renders a fixed list of six links | Built. The list is fixed |
| App switcher, OpenProject column | Core's own module list, restyled. It comes from core's menu and permission helpers | Built |
| A second line under each app name | Core's list has no description per item. It would need a replacement of a private method and a text per menu item | Not built |
| Search | Core's own field, restyled | Built. The placeholder is core's text |
| Bell instead of the inbox icon | CSS mask on core's link. The link keeps its name, "Notifications" | Built |
| Unread dot | Core's own indicator, restyled as a dot. It shows when the real unread count is above zero | Built |
| Help | Core's own menu, outline icon by CSS mask | Built |
| Account button with avatar, name and role | Override the private `lateral_user_menu_button(dialog, avatar)`: pass the avatar plus the name and role as the button content, then `super`. Core's own account menu opens | Built |
| No green quick add button | CSS turns it into a plain icon button. Hiding it would take "new project" and "invite user" away from the bar, and the project menu does not offer those | Built as a plain plus. See open questions |
| Outline icons in the bar | CSS mask per icon | Built for six icons |

### What the account button shows

- An administrator sees "Administrator". Core gives an administrator every role, so a list of roles would mean nothing.
- Anyone else sees their roles in the current project.
- Outside a project there is no role, and the button shows the name only.

### The Nextcloud column is fixed

The list is Files, Mail, Calendar, Tasks, Talk and Contacts. It does not ask Nextcloud which apps are installed, or which ones the user may open. The address comes from the first Nextcloud file storage configured in OpenProject. Without one it falls back to a placeholder constant in `lib/open_project/thematiq/shell/nextcloud_apps.rb`. Replace both with the plugin setting once the settings page has a Nextcloud address.

OpenProject opens these links in a new tab, because its link handling treats another host as external.

## Project menu: item by item

| Item in the design | Mechanism | Status |
|---|---|---|
| Width, item height, active item | CSS | Other lane |
| Members and Project settings at the bottom | CSS. Core already renders them last | Not built |
| "Create work package" on top | No hook renders above the menu. Options: override `render_projects_top_menu_node` to add a link before the project switcher, or add it below with a hook and move it with CSS `order`. The second breaks the focus order | Not built |
| Project switcher with initials and a "Project" label | The switcher is a view component, so a view override cannot reach it. Override the public `Header::ProjectSelectComponent#trigger_label` to return the initials, the label and the name | Not built |
| Group titles (Plan, Work together) | The project menu is a flat list. Needs an override of `render_menu` that inserts title rows between items, with a fixed map from item name to group. Core still decides which items a user sees | Not built |
| Count badges | A menu item's `badge:` is a translation key. A number needs an override of the private `badge_for`, and one count query per page for each badge | Not built |
| Saved queries on the work package page | Core swaps the project menu for the query list. See below | Not changed |

### Saved queries

On the work package page core "descends" into the Work packages item: the project menu slides away and the query list takes its place, with a back arrow. The design keeps the project menu in view.

The query list is a real feature. A user needs it to open a saved view. Three ways to keep both:

1. **Leave it.** Core's behaviour, restyled by the other lane. Nothing can break. The design is not met on this one page.
2. **Show the queries under the Work packages item.** CSS keeps the root menu visible and shows the child list in place. It reaches the design's frame, but the list has a search field and about a dozen entries, so it pushes every item below it off the screen. It also fights the Stimulus controller `menus--main`, which sets the open and closed classes.
3. **Move the queries to the page.** A dropdown next to the page title. That is new interface in the Angular work package page, and a plugin cannot add it without a frontend build.

The least risky is the first. The second is worth a try in a later change, with the list collapsed by default.

## Icons

OpenProject draws icons from three places:

1. The gem `openproject-octicons` (19.37.0). Rails renders these as inline SVG through `Primer::Beta::Octicon`.
2. The package `@openproject/octicons-angular`. These are compiled into the frontend bundle.
3. The old icon font `openproject-icon-font`, used through classes such as `icon-search`.

A plugin without a frontend build can only reach the first one, by patching the gem's symbol table at boot. That would leave the Angular pages, including the work package table, on filled icons, so the result would be mixed. Replacing all three means rebuilding the frontend and drawing a font with a few hundred glyphs. That is a fork in all but name.

What works is a swap per icon in a region the plugin owns: hide core's SVG and draw the outline icon as a CSS mask. The button keeps its accessible name. The top bar does this for six icons. The project menu has about twenty and could do the same.

**Finding: a wholesale swap is not feasible without forking core. A swap per region is.**

## Upgrade guard

The helper overrides and the CSS lean on four core files. `lib/open_project/thematiq/shell/core_guard.rb` records the SHA-256 of each one in OpenProject 17.9.1.

- **At boot** the plugin compares them. If one differs, it does not install the helper overrides. The core top bar renders, and the log has an error that names the files.
- **In a check** you run `script/check-core.rb` inside the image. It exits 1 and prints the files that changed.

```bash
docker run --rm --entrypoint ruby openproject-thematiq:dev \
  /app/custom-plugins/openproject-thematiq/script/check-core.rb
```

After a change in core: read the new file next to `lib/open_project/thematiq/shell/top_bar.rb`, adjust, then update the checksum and `CORE_VERSION`.

## Open questions

- **Quick add.** The design has no quick add button. The plugin keeps it as a plain plus, because removing it takes "new project" and "invite user" out of the bar. Hide it with one CSS rule once those two have another home.
- **Search placeholder.** The design says "Search files, work packages or people". Core's search finds work packages and projects, so the plugin keeps core's text.
- **Nextcloud apps.** The fixed list should become a call to Nextcloud's navigation API, cached per user.
