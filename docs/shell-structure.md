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
| Logo first, then the row of apps, then the app switcher | Override `top_menu_left_menu_items`: call `super`, add the row, move the app switcher to the end. Done in the markup so the focus order matches what you see | Built |
| No app name in the bar | The logo names the product and the marked tile names the place. The logo link keeps core's name, "Home" | Built |
| Brand block as wide as the sidebar | CSS in the geometry layer: the block takes `--main-menu-width`, the logo starts 24 px in, the rule is the block's last pixel. The geometry layer pins that width to 264 px, so the rule stays at 264 when the sidebar is collapsed, and on pages without a sidebar | Built |
| Row of apps and modules | The same override renders it. See "The row of apps" below | Built |
| Logo of the design system | One CSS rule from the head hook sets the background image of core's logo link. Without a logo in the token set, OpenProject's own logo stays | Built |
| App switcher as a two column popover | CSS on core's dialog. It stays a modal dialog, so focus trap and Escape keep working | Built |
| App switcher, Nextcloud column | Hook `module_menu_dialog_content_before` renders a fixed list of six links. Only when a Nextcloud address is set | Built. The list is fixed |
| App switcher, OpenProject column | Core's own module list, restyled. It comes from core's menu and permission helpers | Built |
| A second line under each app name | The plugin's own list, see "The list under the nine-dot button" | Built |
| Search | Core's own field, restyled | Built. The placeholder is core's text |
| Bell instead of the inbox icon | CSS mask on core's link. The link keeps its name, "Notifications" | Built |
| Unread dot | Core's own indicator, restyled as a dot. It shows when the real unread count is above zero | Built |
| Help | Core's own menu, outline icon by CSS mask | Built |
| Account button with avatar, name and role | Override the private `lateral_user_menu_button(dialog, avatar)`: pass the avatar plus the name and role as the button content, then `super`. Core's own account menu opens | Built |
| No green quick add button | CSS turns it into a plain icon button. Hiding it would take "new project" and "invite user" away from the bar, and the project menu does not offer those | Built as a plain plus. See open questions |
| Outline icons in the bar | CSS mask per icon | Built for six icons |

### The row of apps

Core's top bar helpers take a row of items without a view override. `top_menu_left_menu_items` returns the parts of the left side as a list, and the override adds one part to it.

| Part | Where it comes from | Status |
|---|---|---|
| OpenProject's modules | `more_top_menu_items`, core's own list for the app switcher. It runs each item's `if:` condition, so a user only gets what core would show them | Built |
| Nextcloud's apps | The fixed list of `Shell::NextcloudApps`, only when a Nextcloud address is set | Built |
| Which entries, in which order | The plugin setting `top_bar_apps`, a list of keys. See below | Built, with a field on the admin page: **Tiles in the top bar** |
| Icon | The outline icon of the design for the modules the design draws. Any other module keeps the icon core gives it | Built |
| Name | Real text in the link. It shows under the icon on the current tile and on hover and focus | Built |
| Current tile | `aria-current="page"`, a fill and a line under the tile. It follows core's `current_menu_item`, so a project's work package page marks Work packages. Wiki, Members, Project settings and the administration mark nothing | Built |
| A current entry outside the row takes the last place | `Shell::AppRow.pick` | Built |
| Below 1240 px the row folds, the current tile stays | CSS | Built. The current tile sits after the button on screen and before it in the focus order |
| Below 1012 px | No tile. Core's compact header has no room for one | Built |
| App switcher as the nine-dot button at the end | The dialog button of the plugin's own list, moved like core's was | Built. Named "All apps and modules", with `aria-haspopup="dialog"` and `aria-expanded` |
| The list: heading, a line of text per entry, current entry, "Manage apps" | The plugin's own list in place of core's | Built, see below |

### The list under the nine-dot button

Core renders the list and names its button inside one method, `TopMenu::ModuleMenu#render_module_top_menu_node`. No hook reaches the button, and core's list has no place for a second line or a current mark. A helper prepend that calls `super` cannot change either without rewriting core's HTML afterwards. So `Shell::AppSwitcher` renders the plugin's own list in that method's place:

- The same `Primer::Alpha::Dialog`, a modal dialog with core's focus trap and Escape, with the classes and test selector core gives it, so the row of tiles moves it the same way.
- Core's own items: `module_top_menu_item_groups`, so which modules a user sees is core's decision, and a module without a licence keeps core's upsell icon. The Nextcloud apps come first, in a column of their own, when a Nextcloud address is set.
- Core's two hooks of the dialog are still called, so other plugins add to it as before. The plugin's own Nextcloud hook steps aside.
- The heading "All apps and modules", and as a note how many of them are in the bar. A second line per entry from `thematiq.shell.app_switcher.lines` in `en.yml`; a module of another plugin has none. The current entry is marked with `aria-current="page"`, by the same rule as the current tile. "Manage apps" for an administrator, to **Tiles in the top bar**.
- A small script keeps `aria-expanded` in step with the dialog and moves between the entries with the arrow keys, Home and End.

It leans on `module_menu.rb`, which the guard already checks for the top bar: it is installed with the top bar and off with it. When rendering fails, core's list renders and the log says why. The cost is one core method copied in shape (about twenty lines) that must be compared with core's on every release.

Differences from the design: it is a dialog of links, not a `role="menu"`, because core's dialog is one and Tab keeps working; the note counts the tiles ("7 of them are in the bar") where the design says "The first seven", because an own row need not be the first entries; Mail's line is "Your mailbox" where the board names the user.

**The setting.** `top_bar_apps` in `Setting.plugin_openproject_thematiq`, read through `OpenProject::Thematiq::Shell.top_bar_apps`. It is a list of keys separated by commas. A Nextcloud app has the key of its name (`files`, `mail`, `calendar`, `tasks`, `talk`, `contacts`). A module has the name of its item in core's top menu (`home`, `my_page`, `projects`, `work_packages`, `gantt`, `team_planners`, `boards`, `meetings`, `news`, `cost_reports_global`, `wikis`). Empty gives the default, `none` gives no row, and there are at most twelve.

**The field.** **Administration**, **Thematiq design**, **Tiles in the top bar**: the row of the design, an own row, or no tiles. An own row has twelve places, each a list of the keys in `Shell::AppRow::KNOWN` (the six Nextcloud apps and the fifteen modules of core's top menu in 17.9.1), filled from left to right. Empty places and repeats are dropped; an own row without a tile is refused. A key the setting already held, from another plugin for example, stays on offer.

**The default** is the row of the design: `files, mail, calendar, work_packages, boards, gantt, meetings`.

**When an entry is not there for this user**, because no Nextcloud address is set or core hides the module, it is left out and the row is filled up to its length from core's own order: Home, My page, My time tracking, then Projects, Work packages, Gantt, Team planners, Boards, Meetings, News, Time and costs, Wiki. So without a Nextcloud address the default row is Work packages, Boards, Gantt, Meetings, Home, My page, My time tracking. A module the instance has no licence for is never in the row. It stays in the app switcher, where core marks it.

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
| Submenus of the modules | The two-layer menu, see below | Built: the project menu stays on every page, the second level opens in place |

Which items a user sees is still core's decision. The overrides add rows around the items that `first_level_menu_items_for` and `render_menu_node` let through. A user who may not see Members gets no Members row, and no spacer.

An item this plugin does not know, from another plugin for example, stays in the group of the item before it.

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

### What is built

`stylesheets/shell/30-nested-menu.css` shows core's second level under its row, to the sizes of "Navigation, nested" in the canon. `lib/open_project/thematiq/shell/assets/project_menu.js` is inlined at the end of the page through the hook `view_layouts_base_body_bottom`. Both mechanisms landed in one change, because they are the same rule on the same `ul`.

No Ruby override was added for it. Two from the first project menu went away: the class of the list is no longer rewritten, and the Work packages row keeps core's `open` class.

The CSS only applies while the project menu overrides are on. Every rule is scoped to a menu that holds the project switcher's initials, which only the override renders. When a guarded core file changes, the overrides and the two-layer menu switch off together and core's sidebar swap is back.

### What the in-place menu needs

| Need | How |
|---|---|
| The project menu always stays | CSS shows every row in both states of the list, `open` and `closed`. No markup changes |
| The current module opens in place | Core already marks its row `open`. CSS shows `ul.main-menu--children` under an open row |
| Expand and collapse from the parent | Core's own arrow button and `menus--main#descend`. The call toggles `open` on the row, which is all the CSS looks at |
| No back arrow | CSS hides `div.main-menu--children-menu-header` |
| A chevron on the parent | CSS mask on the arrow button: right when closed, down when open |
| `aria-expanded`, `aria-controls` and a label on the parent control | Core sets none of the first two, and labels the button "Open ... sub-menu" in both states. The script sets "Expand ..." or "Collapse ..." and keeps the state in step |
| The create action as a quiet last row | CSS on the create button core renders in a module's frame. Only modules that have one show it, and only to a user who may create |
| More than 8 entries: the first 6 and "Show all N" | The script counts the entries once the list is on screen, hides the rest and adds a button. The button shows them in place and moves focus to the first one that was hidden. The current entry is never hidden. Without the script every entry shows |
| `aria-current="page"` on the current child | Core marks the current link with the class `selected` only. The same script adds the attribute |
| The parent as "contains the current page" | CSS: a selected parent with a selected link below it |
| No icons on level two | CSS hides the icon in a submenu row |
| No inner scrollbar | CSS lets the list grow. The sidebar scrolls as a whole, as core's `#menu-sidebar` already does |

### Differences from the design

- **No search field.** Core puts a search field at the top of most submenus. The design has none, so it is hidden. "Show all" takes its place for a long list.
- **The create row keeps core's text**, "Board" for example, where the design says "New board". Work packages has no create row: core has no "save this view" action in the submenu.
- **The toggle label uses the item's name as it is written**: "Collapse Work packages". The design writes it in lower case, which is wrong for names in other languages.
- **Opening a row moves focus to its first entry** when the list is already loaded. That is core's `descend`. Closing leaves focus on the toggle.
- **Arrow keys.** Core's lists are plain links, so Tab moves through them. The wiki tree is a Primer tree view and has arrow keys of its own. Nothing traps Escape.
- **The wiki tree is not shortened.** It is a tree, not a list, and has its own filter.
- **Resource management** was not tried. Its submenu needs the Enterprise edition.

## Home and My page as one page

### How each is built in 17.9.1

| | Home (`/`) | My page (`/my/page`) |
|---|---|---|
| Controller | `HomescreenController#index`, open to anonymous visitors when the instance allows them | `My::PageController#show`, signed in users only |
| Content | Fixed blocks, the same for everyone, each with a condition: welcome text, favourite projects, new features, meetings, account, news, community, administration, upsell. Then a row of links | A grid of widgets per user, stored through the API |
| Rendered by | The server. Each block is a view component under `Homescreen::Blocks`, in `Grids::WidgetGridComponent` | The Angular element `opce-my-page`. The server renders a page header and that one tag |
| Who changes it | An administrator sets the welcome text. Nobody arranges the blocks | The user adds, moves and removes widgets |
| A plugin can add | A block: push a name to `OpenProject::Static::Homescreen.manage :blocks` and ship a component `Homescreen::Blocks::<Name>`. No frontend build | A widget type needs two halves: `Grids::Configuration.register_widget` on the server, and an Angular component in the frontend bundle. The second half needs a frontend build |

Two facts decide what is possible:

- `opce-my-page` always loads the grid of the My page. It asks for the scope `myPagePath()`, not for the page it sits on. So the tag shows the user's own grid on any page.
- A widget type cannot be added without a frontend build. That goes for the "turbo" widgets too: each still has its own compiled component.

### Options

| Option | What it takes | What it costs |
|---|---|---|
| a. Home renders the user's grid, with the welcome text above it and the other Home blocks below | An override of `HomescreenController#index` that renders a plugin template for a signed in user. No frontend build | The Home blocks stay server blocks. A user cannot move or remove them like widgets |
| b. Home redirects to My page | One redirect | An anonymous visitor has no landing page, and the administrator's welcome text is gone for everyone |
| c. Every Home block becomes a real widget in the grid | A frontend build with one Angular component per block, in step with every OpenProject release | That is the fork this plugin avoids |

### What is built: option a

For a signed in user, Home is one page without a sidebar:

1. A greeting, and "Create work package" for a user who may create one in any project.
2. The instance announcement, when there is one.
3. The administrator's welcome text, when it is switched on. The same component and the same setting as before.
4. The user's own grid of widgets, drawn by `opce-my-page`. Adding, moving and removing widgets works as on My page, because it is that element.
5. "More on this instance": every other Home block and the row of links, each with core's own condition.

The address `/my/page` leads to Home. The item "My page" is taken out of the app switcher, the global menu and the account menu, so there is one item.

An anonymous visitor gets OpenProject's own Home, unchanged. My page needs a user.

Nothing a user or an administrator had is gone: every Home block is on the page, the welcome text is set in the same place, and the grid is the same grid.

### Differences from the design

- **Widgets are two across**, as the user's grid stores them. The design draws three. The grid's columns belong to the user and the Angular element.
- **The welcome text is a block above the grid**, not a widget in it. A widget type needs a frontend build.
- **No "Edit page" button.** The grid is always editable: its controls show on hover and focus.
- **Which widgets a new user starts with** is core's default: assigned to me, created by me. "Due this week", "my projects" and "my time this week" exist as widget types and a user can add them. Changing the default set is a small change in a later round.
- **The two Nextcloud widgets are not built.** Each would need a widget type, so a frontend build, and a server side that calls Nextcloud for the signed in user: recent files through WebDAV or the files API, unread mail through the Mail app's API, with a token per user. OpenProject's own Nextcloud integration holds such tokens for file storages and could be the base.

## The Gantt page

The board `OpGantt` draws the Gantt page of a project: the table left and the timeline right, a header with the first day of each week over one letter per day, weekends shaded, a dashed today line with a label, bars of 20 px in the action colour, a parent as an outlined summary bar, milestone diamonds, dependency lines, a row of chips with Today, a zoom list and a view switch, Export PDF and Create, and a legend under the chart.

OpenProject draws the chart in Angular (`frontend/src/app/features/work-packages/components/wp-table/timeline/`). A plugin without a frontend build cannot change those components, so `Shell::Gantt` works on core's markup:

| Part of the board | Mechanism | Status |
|---|---|---|
| Rows of 48 px, the table frame, the header row of the table | The geometry layer, as on the work package page | Built |
| Bars: 20 px, radius 4, the action colour | CSS on core's bar. Core colours each bar by its type with an `!important` rule, which the stylesheet overrides | Built |
| A parent as an outlined summary bar | CSS on a timeline row with the class `__hierarchy-root-*`, which core gives only to a row with children | Built. The board says "Epic"; any parent gets the outline |
| Milestone diamond | Core's diamond, 14 px, in the type colour of the milestone | Built |
| Labels | The subject after the bar in 12 px. Core's date labels beside the bar are hidden: the dates are in the table | Built |
| Header: the first day of each week over one letter per day | The script rewrites the text of core's header cells at the Days and Weeks levels. The dates come from the left of core's today line | Built. Core's own labels stay for Months and up |
| Weekends shaded | CSS on core's `wp-timeline--non-working-day` | Built. Core only marks them at Days and Weeks |
| Today line and its label | CSS on core's line; the label is `content: attr(data-label)`, set by the script from `en.yml` | Built |
| Dependency lines | Core draws its lines for rows of 40 px (`wp-timeline-relations.directive.ts` multiplies by 40), so with rows of 48 px they miss the bars. The script reads which bar follows which from the classes of core's lines, hides those, and draws its own in one SVG | Built |
| Chips "All open" and "Milestones only" | Links to core's own two default Gantt views (`Gantt::DefaultQueryGeneratorService`), with the count of open work packages on the first | Built. "Critical path" is left out: OpenProject has no critical path |
| Today | Scrolls the timeline to the today line | Built |
| Zoom | A list of core's five levels. It presses core's zoom buttons, which the stylesheet hides | Built. The board lists three levels |
| View switch | Links to the project's Work packages and Boards, taken from the project menu, so a module that is off or not allowed has no link | Built |
| Export PDF | Opens core's export dialog, the entry "Export" of core's "More actions" menu | Built. The dialog offers every format, PDF among them |
| Create | Core's Create button | Built. It opens the create dialog, see below |
| Legend | Rendered by the script under the chart | Built |
| Title "Gantt chart" and the line under it | Core's title is the name of the view and can be edited and saved. It stays | Not built |
| Core's other toolbar buttons (Include projects, Baseline, Filter, details, zen mode, More actions) | Not on the board. They stay, because each is a feature | Kept |

Everything is scoped to the class `thematiq-gantt` on the body, which only the script sets. The script is rendered by the hook `view_layouts_base_body_bottom` on a project's Gantt page, and only while the core files of the part `gantt` in `core_guard.rb` are those of 17.9.1. When one differs, core's Gantt shows with the plugin's colours and nothing else.

What it costs on an upgrade: eleven guarded frontend files. A change in the bar markup, the header or the line classes trips the guard; a change in the Angular bundle that keeps these files does not, and shows in the pixel diff.

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
| `lib/redmine/menu_manager/top_menu_helper.rb` | `Shell::TopBar#top_menu_left_menu_items`, through `super` | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/top_menu/user_menu.rb` | `Shell::TopBar#lateral_user_menu_button`, a private method with two arguments | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/top_menu/module_menu.rb` | `Shell::AppSwitcher#render_module_top_menu_node`, which renders the plugin's list in place of core's and calls core's `module_top_menu_item_groups`; the private `more_top_menu_items` the row of apps reads | Checksum in `core_guard.rb` |
| `app/views/layouts/base.html.erb` | The header and menu markup the files in `stylesheets/shell/` style, and where the hooks run | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/menu_helper.rb` | `Shell::ProjectMenu::Helper`: `render_menu`, `render_menu_node`, `render_menu_toggler`, `badge_for`. One of them fills in a label core leaves empty | Checksum in `core_guard.rb` |
| `frontend/src/stimulus/controllers/dynamic/menus/main.controller.ts` | The two-layer menu: the arrow button's `descend` must keep toggling `open` on the row | Checksum in `core_guard.rb` |
| `frontend/src/global_styles/layout/_main_menu.sass` | The two-layer menu: the rules that hide and show rows in the `open` and `closed` states, which the CSS undoes | Checksum in `core_guard.rb` |
| `app/components/open_project/common/submenu_component.html.erb` and `.sass` | The two-layer menu: the classes of the links, group headers, search field and create button in a module's frame | Checksum in `core_guard.rb` |
| `lib/redmine/menu_manager/top_menu/projects_menu.rb` | `Shell::ProjectMenu::Helper#render_projects_top_menu_node` | Checksum in `core_guard.rb` |
| Eight files of core's create dialog and create actions, listed under `create_dialog` in `core_guard.rb` | `Shell::CreateDialog`: the script and `stylesheets/shell/70-create-modal.css` | Checksum in `core_guard.rb`; the script is not rendered when one differs |
| `app/components/header/project_select_component.rb` and `.html.erb` | `Shell::ProjectMenu::Switcher#trigger_label`, which the template prints inside the button | Checksum in `core_guard.rb` |

| `app/controllers/homescreen_controller.rb`, `app/views/homescreen/index.html.erb`, `app/components/homescreen/blocks_grid_component.rb`, `config/initializers/homescreen.rb` | `Shell::Home::HomePage#index`, and the plugin's Home template, which renders everything core's Home view renders | Checksum in `core_guard.rb` |
| `modules/my_page/app/controllers/my/page_controller.rb` | `Shell::Home::MyPage#show`, a redirect to Home | Checksum in `core_guard.rb` |
| Eleven files of core's Gantt, listed under `gantt` in `core_guard.rb`: the timeline cells, header, grid, today line and dependency lines, the zoom buttons, the "More actions" menu and the default Gantt views | `Shell::Gantt`: the script and `stylesheets/shell/60-gantt.css` | Checksum in `core_guard.rb`; the script is not rendered when one differs |

`lib/open_project/thematiq/shell/core_guard.rb` records the SHA-256 of each file in OpenProject 17.9.1.

- **At boot** the plugin compares them, for the top bar, the project menu and the home page apart. If a file of one part differs, the overrides of that part are not installed. Core's own top bar or project menu renders, and the log has an error that names the files.
- **In a check** you run `script/check-core.rb` inside the image. It exits 1 and prints the files that changed.

```bash
docker run --rm --entrypoint ruby openproject-thematiq:dev \
  /app/custom-plugins/openproject-thematiq/script/check-core.rb
```

Three of the guarded files are frontend sources (`frontend/src/...`). The image ships them next to the compiled bundle. If a later image leaves them out, the check reports them as changed and the project menu overrides stay off until the list is adjusted.

The checksums do not cover the Angular bundle. The search field, the unread indicator and the avatar are Angular elements, and the CSS names their classes. A change there shows up in the pixel diff, not in this check.

### When an OpenProject upgrade breaks this

You notice it in one of three ways: `script/check-core.rb` exits 1, the log says "The top bar overrides are off" or "The project menu overrides are off", or the shell shows without the row of apps, the account name, the create action or the group titles.

1. Run `script/check-core.rb` in the new image. It names the core files that changed.
2. Open each one next to the override that leans on it. The table above says which.
   - For `lib/open_project/thematiq/shell/app_switcher.rb`: core's `render_module_top_menu_node` still renders a `Primer::Alpha::Dialog` with the hooks before and after its list, and `module_top_menu_item_groups` still returns groups of menu items.
   - For `lib/open_project/thematiq/shell/top_bar.rb`: `top_menu_left_menu_items` still returns the app switcher first, `more_top_menu_items` still returns the menu items of the app switcher, and `lateral_user_menu_button(dialog, avatar)` still puts `avatar` inside the button.
   - For `lib/open_project/thematiq/shell/project_menu.rb`: `render_menu` still sets `@menu`, `render_menu_node` still returns one `<li>` per item, `badge_for(item)` still returns a span or nil, and the switcher template still prints `trigger_label` inside the button.
   - For `lib/open_project/thematiq/shell/home.rb`: compare core's `homescreen/index.html.erb` with `app/views/thematiq/shell/home.html.erb`. Whatever core's view renders, the plugin's must render too. While this part is off, Home and My page are two pages again and "My page" is back in the menus.
   - For `stylesheets/shell/30-nested-menu.css` and the script: a row with a submenu is still `li` with `div.main-item-wrapper` and `ul.main-menu--children`, the arrow button still toggles `open` on the row, and a module's frame still uses the `op-submenu--*` classes.
3. If they hold, nothing in the plugin needs to change. Update the checksum and `CORE_VERSION` in `core_guard.rb`.
4. If one moved, change the override to fit, then update the checksum.
5. Start the instance and compare the top bar with the design, with `spike/pixdiff.py`.

Until someone does this, OpenProject keeps working. Its own top bar and project menu render with the plugin's colours and sizes, and without what the overrides add.

## Create work package as a dialog

The board `OpCreateWorkPackage` opens a new work package in a dialog over the page you are on. Core opens it as a page (`/projects/:id/work_packages/new`) or in the split view (`.../create_new`).

### What 17.9.1 offers

| Route | What it is | Fit |
|---|---|---|
| Core's create page or split view, in an iframe in a dialog | The whole Angular create form | Two Angular apps on one page, and the page's own layout inside the dialog. Dropped |
| The Angular create form (`wp-new`) moved into a dialog | Angular components | Needs a frontend build. Dropped |
| `WorkPackages::Dialogs::CreateDialogComponent`, a Primer dialog at `/projects/:id/work_packages/dialog/new` | Core's own dialog. Core uses it for "new child" on the relations tab and in Backlogs. It answers with a Turbo stream that opens the dialog, saves through `WorkPackages::CreateService`, shows errors in place, and redirects back on success | Chosen |

### What is built

`Shell::CreateDialog` renders a small script at the end of every page for a signed-in user. It catches a click on:

- "Create work package" in the project menu,
- the Create button of the work package, Gantt and other Angular pages (`button.add-work-package`),
- a work package type in the quick add menu of the top bar, and any other link to `/projects/:id/work_packages/new` or `.../create_new`,

and fetches core's dialog for that project, with the type and the parent of the link, the way core's own `async-dialog` links do. The type, subject, description, the required custom fields, the permission check (`add_work_packages`), the validation and the save are core's.

| Need | How |
|---|---|
| Focus moves into the dialog | Core puts it in the subject |
| Escape closes, focus returns | Core's Primer dialog closes on Escape. The script puts focus back on the control that opened it: the project menu action, the Create button, or the quick add button when the action was in its menu |
| Closing returns to where you were | Nothing navigates until a save |
| Saving refreshes the view | Core redirects back to the page the dialog was opened on, so the list, the Gantt chart or the board reloads with the new work package and core's notice |
| A click with Ctrl, Cmd, Shift or the middle button | Opens core's page in a new tab, as before |
| The board's look | `stylesheets/shell/70-create-modal.css`: 640 px wide, the project name above the title, the type label shown, fields of 40 px, a footer with a line on top. The title and the submit button say "Create work package" |

### Differences from the board

- **Fewer fields.** Core's dialog has the type, the subject, the description and the required custom fields. The board also draws Parent, Assignee, Priority, Start date, Due date and "Link the project folder in Nextcloud". Adding them means overriding core's form class, which is the part that keeps validation and custom fields core's. They are set on the work package after it is created. A parent comes along when the action had one, such as "new child".
- **The page's Create button opens the dialog directly.** Core shows a list of types first; the dialog has its own type field, as the board draws it.
- **Outside a project** (the quick add menu on a page without a project, the global work package page), core's page opens. Core's dialog needs a project.

### What it costs on an upgrade

Eight guarded core files, the part `create_dialog` in `core_guard.rb`: the dialog controller, the dialog and form components, the form class, core's `async-dialog` controller, the quick add menu, the Create button and its list of types. When one differs, the script is not rendered and every create action opens core's page again. The route `work_packages/dialog/new` itself is in `config/routes.rb`, which changes on every release and is not guarded: if it moves, the fetch fails and the script opens core's page.

## Open questions

- **Quick add.** The design has no quick add button. The plugin keeps it as a plain plus, because removing it takes "new project" and "invite user" out of the bar. Hide it with one CSS rule once those two have another home.
- **Search placeholder.** The design says "Search files, work packages or people". Core's search finds work packages and projects, so the plugin keeps core's text.
- **Nextcloud apps.** The fixed list should become a call to Nextcloud's navigation API, cached per user.
- **Nextcloud address.** The setting `nextcloud_url` needs a field on the admin page.
- **Count position.** The count sits after the label. The design puts it at the right edge of the row.
- **Narrow screens.** The geometry layer sets the desktop columns at every width. The shell layer puts core's compact header back below 1012 px. That reset belongs in the geometry layer.
