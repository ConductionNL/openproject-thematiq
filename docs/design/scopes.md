# Design: a design system per project and per module

**Status: a proposal to read. No code has been written for it.**

Today one design system styles the whole of OpenProject. thematiq can style one app differently from the rest. In OpenProject that becomes two things: a project can have its own design system, and a module can have its own.

## What a scope is

| Scope | Example | Who would want it |
|---|---|---|
| Instance | Every page | Everyone. This is what exists today |
| Project | Every page under `/projects/town-hall/` | A shared instance where each organisation or programme has its own house style |
| Module | Every Meetings page, in every project | A module that is shown to another audience, such as a public board |
| Module in a project | Meetings in the project "Town hall" | Rare. It falls out of the other two |

## Which one wins

The most specific choice wins:

1. Module in this project
2. This project
3. This module, instance wide
4. A parent project, nearest first
5. The instance

Projects come before modules because a project is the unit people recognise: "this is the town hall's space". Parent projects are in the list because OpenProject's own settings mostly follow the project tree, and a programme with twenty sub-projects should be set once.

The trade-off: with inheritance, a sub-project changes when its parent changes, and somebody will be surprised. Without it, twenty sub-projects are set by hand. This page chooses inheritance and shows on the project's page where its design system comes from.

## Where the choice is stored

A table of the plugin's own:

| Column | Holds |
|---|---|
| `project_id` | A project, or empty for the instance |
| `module_name` | A module, such as `meetings`, or empty for all |
| `design_system_id` | An id from the catalogue, or a custom design system |

One row per scope, unique on project and module. The instance row replaces the `active_id` setting of today.

Why a table and not settings: the instance choice fits in OpenProject's settings, a choice per project does not. Settings are one hash that every process caches whole, and a thousand projects would sit in it. A table also gives a foreign key, so a deleted project takes its row with it.

Custom design systems move from settings to a table of their own in the same step. More than one custom design system is already asked for; scopes make it necessary.

## How the head hook knows the scope

The hooks get the controller that draws the page. From it:

- **The project:** OpenProject sets `@project` on project pages. The shared head already reads it.
- **The module:** the page's current menu item, which OpenProject already works out to mark the menu. A small table in the plugin maps menu items to module names. The controller name is the fallback.

Pages without a project use the instance row: the home page, My page, the administration, the sign in page, error pages.

One thing does not work: a page that shows several projects at once, such as the global work package list or a portfolio. It is not "in" a project, so it gets the instance design system. The rows of other projects on it are not restyled.

## What an instance admin may do, and a project admin

| Action | Instance admin | Project admin |
|---|---|---|
| Choose the instance design system | Yes | No |
| Choose a design system per module | Yes | No |
| Allow projects to have their own design system | Yes, one switch, off by default | No |
| Limit which design systems projects may choose | Yes, a list | No |
| Choose the design system of a project | Yes | Yes, from the allowed list, when the switch is on |
| Make or edit a custom design system | Yes | No |
| Upload a logo or a font | Yes | No |

A project admin picks; a project admin does not author. Making a design system means putting CSS values and files on pages that people outside the project see, and that stays with the instance admin.

The project admin's right is a new permission, "Choose design system", in the project's role settings, so it follows OpenProject's own way of giving rights.

The trade-off: the switch that lets projects differ is off by default. A municipality that wants one house style everywhere gets that without doing anything. An instance shared by several organisations turns it on.

## The top bar and the logo

The top bar belongs to the instance in most people's eyes, and the project menu to the project. Two honest options:

- **Whole page follows the scope.** Top bar, logo, menu and content all change when you enter a project. Clear, and it is what "this project has its own house style" means. Moving between projects makes the top bar change colour.
- **Top bar stays, the rest follows.** The instance keeps its top bar and logo everywhere, and a project changes the menu and the content. Calmer, and it needs every rule to know which part it belongs to.

This page proposes the first for projects and the second for modules: a module changes the content area only. A module is a view inside a place, not a place.

## Caching

- The CSS for one design system is already built once and kept in memory. That stays, keyed by design system.
- Which design system applies to a page is one lookup. Kept per request, and across requests in OpenProject's cache, keyed by project and module, cleared when a row changes or a project moves in the tree.
- The font and logo files are static and cached by the browser, as now.
- Turbo keeps the `head` between page visits and merges new style tags into it. Moving from one project to another must replace the plugin's style tags, not add to them. This is the part most likely to go wrong and it needs a browser.

## Build order

Each step is one pull request.

1. **The tables and the lookup.** A migration, the model, the order of winning, with tests. The instance row is filled from today's setting. Nothing on the page changes. Needs one run in a real instance because of the migration.
2. **The hooks ask the lookup.** Still only the instance row exists, so the page is the same. Proves the path.
3. **Module scope, instance admin only.** Smallest visible step: one module, content area only.
4. **Project scope, instance admin only.** With the Turbo question answered in a browser.
5. **The permission and the project settings page.** Project admins choose from the allowed list.
6. **Inheritance in the project tree**, with the line that says where a design system comes from.

## Open questions

- Does the top bar follow the project, as proposed, or stay?
- Is inheritance from parent projects wanted from the start, or only after someone asks?
- Should a module scope reach the project menu item of that module, or the content area only?

To decide: the three questions above. Step 1 can start without them.
