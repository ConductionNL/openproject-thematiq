# Design systems per project, module and group

## Purpose

Besides the instance's design system, the plugin lets a design system be chosen for a project, for a module, for a module inside a project, and for a group of people. The rules that decide which choice wins are in `lib/open_project/thematiq/scopes.rb`; `lib/open_project/thematiq/page_scope.rb` applies them once per request; choices are rows of `app/models/thematiq/scope.rb`, edited through `app/controllers/thematiq/project_design_controller.rb` and the admin page.

## Requirements

### Requirement: Order of precedence

The plugin SHALL resolve two design systems per page: the one of the whole page (project, then the nearest parent project, then the instance) and the one of the content area (module in this project, project, module instance wide, parent project, instance), passing over any choice that names a design system that no longer exists.

#### Scenario: Project choice

- **WHEN** a project has its own design system
- **THEN** its whole page, including the top bar and the menu, wears that design system

#### Scenario: Module choice

- **WHEN** a module has its own design system and the project has none
- **THEN** only the content area (`#content-wrapper`) wears the module's design system

#### Scenario: Resolution fails

- **WHEN** working out the page's design system raises an error
- **THEN** the page uses the catalogue's default design system and the error is logged

### Requirement: Projects may not choose by default

A project admin SHALL be able to choose only when an instance admin has allowed projects to choose and has given the project role the permission "Choose design system", and SHALL pick only from the list the instance admin allows (every design system when that list is empty).

#### Scenario: Not allowed

- **WHEN** a project admin opens a project's Design settings while projects may not choose
- **THEN** the page answers 403

#### Scenario: Instance admin

- **WHEN** an instance admin opens the same page
- **THEN** the page opens and every design system can be chosen

### Requirement: Locked project

An instance admin SHALL be able to lock a project's design system; while it is locked, only an instance admin SHALL be able to change it.

#### Scenario: Project admin saves a locked project

- **WHEN** a project admin submits the Design settings of a locked project
- **THEN** the answer is 403 and nothing changes

### Requirement: Design system per group

The plugin SHALL let an administrator give groups their own design system in an ordered list of at most 100 rows; for a signed-in member the first matching group's design system SHALL take the instance's place, while project and module choices still win and the sign-in page keeps the instance's.

#### Scenario: Member of two groups

- **WHEN** a person belongs to two groups that each have a design system
- **THEN** the design system of the group listed first applies

### Requirement: Deleted design system

Deleting a custom design system SHALL remove every project and module choice that names it, so those places inherit again.

#### Scenario: Delete a chosen custom design system

- **WHEN** an administrator deletes a custom design system a project had chosen
- **THEN** that project uses the design system it inherits
