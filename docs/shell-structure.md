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

## Two-layer project menu: where each submenu comes from

The design keeps the project menu in the sidebar on every project page. The module you are in opens in place and shows its own items under it. This section says where each module's second level comes from in OpenProject 17.9.1, read from the source in the image.

### What core already renders

Every project menu item with a submenu is rendered by `render_menu_node_with_children` in `lib/redmine/menu_manager/menu_helper.rb`, in this shape:

```
li[data-name]                      .open when the item or one of its children is the current page
  div.main-item-wrapper            the item link, then a button.toggler
  div.main-menu--children-menu-header   a back arrow and the item name again
  ul.main-menu--children           the second level
```

So the second level is already a real `ul` inside the parent's `li`. Core hides it and shows it by swapping the whole sidebar: the list gets the class `closed`, every other row is hidden, and the open row fills the column. The Stimulus controller `menus--main` (`frontend/src/stimulus/controllers/dynamic/menus/main.controller.ts`) does that swap from the arrow button: `descend` toggles `open` and `closed` on the list and on the row.

What differs per module is what sits inside `ul.main-menu--children`.

### Per module

No submenu in the project menu is drawn by the Angular frontend. That includes the saved work package queries: since the frontend rewrite they are a server-rendered Turbo frame.

| Menu item | What fills the second level | Rendered on the server with the page? | Mechanism |
|---|---|---|---|
| Project settings (`settings`) | Plain menu children `settings_*` from `config/initializers/menus.rb` and from modules. Rendered by `render_visible_children_list` | Yes, by core's menu and permission helpers | 1: core's own nested list, shown in place |
| Backlogs (`backlogs`) | Plain menu children `backlog` and `all_sprints` | Yes, the same way | 1 |
| Work packages (`work_packages`) | Child `work_packages_query_select` with the partial `work_packages/menus/menu`: a lazy Turbo frame `work_packages_sidemenu`. `WorkPackages::MenusController#show` authorises, builds the items with `WorkPackages::Menu` (queries through `Query.visible`), renders `OpenProject::Common::SubmenuComponent` | No. The frame loads when it becomes visible | 2: core's frame, shown in place |
| Gantt (`gantt`) | Lazy frame `gantt_menu`, `Gantt::MenusController`, `Gantt::Menu` | No | 2 |
| Boards (`boards`) | Lazy frame `boards_sidemenu`, `Boards::MenusController`, `Boards::Menu`. Adds a "create board" button for a user who may manage boards | No | 2 |
| Calendar (`calendar_view`) | Lazy frame `calendar_sidemenu`, `Calendar::MenusController`, `Calendar::Menu` | No | 2 |
| Team planner (`team_planner_view`) | Lazy frame `team_planner_sidemenu`, `TeamPlanner::MenusController`, `TeamPlanner::Menu` | No | 2 |
| Meetings (`meetings`) | Lazy frame `meeting_sidemenu`, `Meetings::MenusController`, `Meetings::Menu` | No | 2 |
| Time and costs (`costs`) | Lazy frame `cost_reports_sidemenu`, `CostReports::MenusController`, `CostReports::Menu` | No | 2 |
| Documents (`documents`) | Lazy frame `documents_sub_menu`, `Documents::MenusController`, `Documents::Menu` | No | 2 |
| Members (`members`) | Lazy frame `members_menu`, `Members::MenusController`, `Members::Menu`: filters by role, group and status | No | 2 |
| Activity (`activity`) | Lazy frame `activity_menu`, `ActivitiesController#menu`: a form with filters, not a list of links | No | 2 |
| Wiki (`wiki-<slug>`) | Child `wiki_menu_partial` with the partial `wiki/menu_pages_tree`: a frame with `OpenProject::Sidemenu::FilterableTreeComponent`, a Primer tree view that loads the page tree | No | 2 |
| Resource management | Lazy frame `resource_planners_sidemenu`. Only with an Enterprise token | No | 2, not tried: it needs the Enterprise edition |
| Project home, News, Budgets, Roadmap, Forums, Repository | No submenu | | Nothing to nest |

### Why not render the frame modules on the server

Each `Menu` class is plain Ruby with a public `menu_items`, so the page could call it and print the links itself. That was weighed and dropped:

- Each menus controller authorises on its own, passes its own parameters (`on_work_package_path`, `current_href`, `id`, `filters`) and some add a create button or a search field. Printing the links from the page means copying all of that for eleven modules, and guarding eleven more files.
- It runs the module's queries on every project page, where core runs them only when the submenu is on screen.
- The frame is core's own element. Shown in place it keeps core's search, group headers, create button and permission checks, with nothing copied.

So mechanism 1 and mechanism 2 come down to the same move: show core's `ul.main-menu--children` under its parent row instead of in a swapped sidebar. For Project settings and Backlogs the list is there with the page. For the others the frame inside it loads when the row opens.

### What the in-place menu needs

| Need | How |
|---|---|
| The project menu always stays | CSS shows every row in both states of the list, `open` and `closed`. No markup changes |
| The current module opens in place | Core already marks its row `open`. CSS shows `ul.main-menu--children` under an open row |
| Expand and collapse from the parent | Core's own arrow button and `menus--main#descend`. The call toggles `open` on the row, which is all the CSS looks at |
| No back arrow | CSS hides `div.main-menu--children-menu-header` |
| A chevron on the parent | CSS mask on the arrow button |
| `aria-expanded` on the parent control | Core does not set it. A small script sets it on the arrow button and keeps it in step |
| `aria-current="page"` on the current child | Core marks the current link with the class `selected` only. The same script adds the attribute |
| The parent as "contains the current page" | CSS: a selected parent with a selected link below it |
| No icons on level two | CSS hides the icon in a submenu row |
| No inner scrollbar | CSS lets the list grow. The sidebar scrolls as a whole, as core's `#menu-sidebar` already does |

### Not reachable

- **"Show all N" after the first items.** The number is only known after the frame has loaded, and the link target does not exist for every module. Boards, Meetings, Calendar and Team planner have an index page that lists everything. Work packages and Gantt do not: their index page is the table, so a cut list would hide saved queries with no other way to them. The lists are shown in full. Core's search field at the top of a submenu stays, and is how you find an entry in a long list.
- **Arrow keys through the list.** Core's lists are plain links, so Tab moves through them. The wiki tree is a Primer tree view and has arrow keys of its own. Nothing traps Escape.

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
