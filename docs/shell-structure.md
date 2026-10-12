# Shell structure: what a plugin can reach

This page lists every way a plugin can change OpenProject's top bar and project menu, and what each part of the design needs. It was read from the source inside the `openproject/openproject:17` image, version 17.9.1. Check it again on every OpenProject release.

## The short version

- OpenProject builds the top bar and the project menu in **helper methods**, not in views. A view override cannot reach either.
- Four view hooks touch the shell. All four only **add** markup. None can replace or reorder what core renders.
- Most of the design is reachable with CSS on core's own markup, one hook, and a handful of small helper overrides that call `super`.
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
| Logo of the design system | One CSS rule from the head hook sets the background image of core's logo link. Without a logo in the token set, OpenProject's own logo stays | Built |
| App switcher as a two column popover | CSS on core's dialog. It stays a modal dialog, so focus trap and Escape keep working | Built |
| App switcher, Nextcloud column | Hook `module_menu_dialog_content_before` renders a fixed list of six links. Only when a Nextcloud address is set | Built. The list is fixed |
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

The list is Files, Mail, Calendar, Tasks, Talk and Contacts. It does not ask Nextcloud which apps are installed, or which ones the user may open.

The address is one optional plugin setting: the key `nextcloud_url` in `Setting.plugin_openproject_thematiq`, read through `OpenProject::Thematiq::Shell.nextcloud_url`. Only an `http` or `https` address counts. When it is empty the app switcher shows OpenProject's own modules and no Nextcloud column. The admin page has no field for it yet.

OpenProject opens these links in a new tab, because its link handling treats another host as external.

## Project menu: item by item

| Item in the design | Mechanism | Status |
|---|---|---|
| Width, item height, active item | CSS in the geometry layer | Built |
| "Create work package" on top | No hook renders above the menu. Override `render_projects_top_menu_node`: a link plus `super`. Only for a user who may add work packages in the project | Built |
| Project switcher with initials and a "Project" label | The switcher is a view component, so a view override cannot reach it. Override the public `Header::ProjectSelectComponent#trigger_label` | Built |
| Group titles (Plan, Work together) | The project menu is a flat list. Override `render_menu_node`: `super`, with a title row before the first item of a group. A fixed map says which item goes under which title | Built |
| Count on Work packages | A menu item's `badge:` is a translation key. Override the private `badge_for`: `super` plus the number of open work packages the user may see. One count query per project page | Built |
| Members and Project settings at the bottom | The same override puts a spacer row before the first of the two. Core already renders them last | Built |
| Outline icons | CSS mask per item, for the twelve items the design draws | Built. Other items keep core's icon |
| Saved queries on the work package page | See below | Built: the project menu stays, the queries open with the arrow |

Which items a user sees is still core's decision. The overrides add rows around the items that `first_level_menu_items_for` and `render_menu_node` let through. A user who may not see Members gets no Members row, and no spacer.

An item this plugin does not know, from another plugin for example, stays in the group of the item before it.

### Saved queries

On the work package page core "descends" into the Work packages item: the project menu slides away and the query list takes its place, with a back arrow. The design keeps the project menu in view.

The query list is a real feature. A user needs it to open a saved view. Three ways to keep both:

1. **Leave it.** Core's behaviour. The design is not met on this one page.
2. **Keep the project menu, open the queries with the arrow.** Core already renders an arrow button on every item with a submenu, and its own controller opens and closes the submenu. On the work package page the plugin renders the list in its open state, so the project menu shows and the arrow leads to the queries. One click more than core, nothing removed.
3. **Move the queries to the page.** A dropdown next to the page title. That is new interface in the Angular work package page, and a plugin cannot add it without a frontend build.

The plugin does the second. It takes two small changes to what core returns: the class of the list (`menu_root closed` becomes `menu_root open`) and the class of the Work packages row. The arrow also gets its name back, "Open Work packages sub-menu". Core leaves that name empty on the selected item, because core never shows the arrow there.

This applies to the items in `ProjectMenu::STAY_ON_PROJECT_MENU`, which holds `work_packages` only. Gantt, Boards, Meetings, Wiki, Members and Project settings keep core's behaviour: on their pages the submenu shows. Their submenus are how you move between boards or between settings pages, so hiding them behind a click costs more there. Add a name to the list to change one.

## Icons

OpenProject draws icons from three places:

1. The gem `openproject-octicons` (19.37.0). Rails renders these as inline SVG through `Primer::Beta::Octicon`.
2. The package `@openproject/octicons-angular`. These are compiled into the frontend bundle.
3. The old icon font `openproject-icon-font`, used through classes such as `icon-search`.

A plugin without a frontend build can only reach the first one, by patching the gem's symbol table at boot. That would leave the Angular pages, including the work package table, on filled icons, so the result would be mixed. Replacing all three means rebuilding the frontend and drawing a replacement for the whole icon font. That is a fork in all but name.

What works is a swap per icon in the shell: hide core's SVG and draw the outline icon as a CSS mask in the colour of the text. The button or link keeps its accessible name, because the name was never in the icon. The top bar does this for six icons and the project menu for twelve. Markup the plugin renders itself, the create action and the Nextcloud tiles, uses inline SVG with `currentColor`.

Items the design does not draw keep core's filled icon: News, Budgets, Documents, Activity, Roadmap, Forums and Repository, and anything another plugin adds. Each one needs a drawn outline icon and one CSS line.

**Finding: the shell's own icons are swapped. A swap across the application is not feasible without forking core.** The cost of the rest: a frontend build in the release pipeline for the Angular icons, and a replacement font with the same code points for every glyph of the icon font, kept in step with every OpenProject release.

## Upgrade guard

### Core views this plugin overrides

None. `override_core_views!` is not called, and the plugin ships no file under `app/views` with a core path.

### Core code this plugin leans on

| Core file | What leans on it | What guards it |
|---|---|---|
| `lib/redmine/menu_manager/top_menu_helper.rb` | `Shell::TopBar#top_menu_left_menu_items` and `#render_logo`, both through `super` | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/top_menu/user_menu.rb` | `Shell::TopBar#lateral_user_menu_button`, a private method with two arguments | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/top_menu/module_menu.rb` | The hook `module_menu_dialog_content_before` and the dialog markup the popover CSS styles | Checksum in `core_guard.rb` |
| `app/views/layouts/base.html.erb` | The header and menu markup the files in `stylesheets/shell/` style, and where the hooks run | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/menu_helper.rb` | `Shell::ProjectMenu::Helper`: `render_menu`, `render_menu_node`, `render_menu_toggler`, `menu_node_options`, `badge_for`. Two of them replace a class or a label in the string core returns | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/top_menu/projects_menu.rb` | `Shell::ProjectMenu::Helper#render_projects_top_menu_node` | Checksum in `core_guard.rb` |
| `app/components/header/project_select_component.rb` and `.html.erb` | `Shell::ProjectMenu::Switcher#trigger_label`, which the template prints inside the button | Checksum in `core_guard.rb` |

`lib/open_project/thematiq/shell/core_guard.rb` records the SHA-256 of each file in OpenProject 17.9.1.

- **At boot** the plugin compares them, for the top bar and for the project menu apart. If a file of one part differs, the overrides of that part are not installed. Core's own top bar or project menu renders, and the log has an error that names the files.
- **In a check** you run `script/check-core.rb` inside the image. It exits 1 and prints the files that changed.

```bash
docker run --rm --entrypoint ruby openproject-thematiq:dev \
  /app/custom-plugins/openproject-thematiq/script/check-core.rb
```

The checksums do not cover the Angular bundle. The search field, the unread indicator and the avatar are Angular elements, and the CSS names their classes. A change there shows up in the pixel diff, not in this check.

### When an OpenProject upgrade breaks this

You notice it in one of three ways: `script/check-core.rb` exits 1, the log says "The top bar overrides are off" or "The project menu overrides are off", or the shell shows without the app name, the account name, the create action or the group titles.

1. Run `script/check-core.rb` in the new image. It names the core files that changed.
2. Open each one next to the override that leans on it. The table above says which.
   - For `lib/open_project/thematiq/shell/top_bar.rb`: `top_menu_left_menu_items` still returns the app switcher first, `render_logo` still returns the logo block, and `lateral_user_menu_button(dialog, avatar)` still puts `avatar` inside the button.
   - For `lib/open_project/thematiq/shell/project_menu.rb`: `render_menu` still writes `class="menu_root closed"` and sets `@menu`, `render_menu_node` still returns one `<li>` per item, `menu_node_options` still returns the `open` class, `badge_for(item)` still returns a span or nil, and the switcher template still prints `trigger_label` inside the button.
3. If they hold, nothing in the plugin needs to change. Update the checksum and `CORE_VERSION` in `core_guard.rb`.
4. If one moved, change the override to fit, then update the checksum.
5. Start the instance and compare the top bar with the design, with `spike/pixdiff.py`.

Until someone does this, OpenProject keeps working. Its own top bar and project menu render with the plugin's colours and sizes, and without what the overrides add.

## Open questions

- **Quick add.** The design has no quick add button. The plugin keeps it as a plain plus, because removing it takes "new project" and "invite user" out of the bar. Hide it with one CSS rule once those two have another home.
- **Search placeholder.** The design says "Search files, work packages or people". Core's search finds work packages and projects, so the plugin keeps core's text.
- **Nextcloud apps.** The fixed list should become a call to Nextcloud's navigation API, cached per user.
- **Nextcloud address.** The setting `nextcloud_url` needs a field on the admin page.
- **Submenus.** Only the work package page keeps the project menu in view. The design shows it on every project page. Extending `STAY_ON_PROJECT_MENU` does that, at the price of one more click to reach a board list or a settings page.
- **Count position.** The count sits after the label. The design puts it at the right edge of the row.
- **Narrow screens.** The geometry layer sets the desktop columns at every width. The shell layer puts core's compact header back below 1012 px. That reset belongs in the geometry layer.
