# 3. A design system per project and per module, the most specific choice wins

- Status: accepted (the owner decided the open questions; built)
- Source: [docs/design/scopes.md](../design/scopes.md)

## Context

At first one design system styled the whole of OpenProject. A shared instance may serve several organisations, each with its own house style, and a module may be shown to another audience.

## Decision

- A design system can be chosen for the instance, a project, a module instance wide, and a module in a project. The most specific choice wins, in this order: module in this project, this project, this module instance wide, a parent project (nearest first), the instance. Subprojects inherit from their parent.
- A project's design system styles its whole page, the top bar and the logo included. A module's design system reaches the content area only.
- The choices live in a table of the plugin's own, `thematiq_scopes` (project, module, design system), unique on project and module, with a foreign key so a deleted project takes its rows. The instance's own choice stays in the plugin's settings.
- Letting projects choose is off by default. A project admin picks from an allowed list with a new permission, "Choose design system", given to no role by default. Only an instance admin makes or edits a design system or uploads files.

## Consequences

- An instance that wants one house style everywhere gets it without doing anything.
- A subproject changes when its parent changes; the project's page says where its design system comes from.
- A page that shows several projects at once, such as the global work package list, gets the instance design system.
- Every style tag of the plugin carries `data-turbo-track="reload"`, so moving between projects swaps the style tags instead of adding to them.
- The module is read from `current_menu_item` in a core file that `script/check-core.rb` guards.
