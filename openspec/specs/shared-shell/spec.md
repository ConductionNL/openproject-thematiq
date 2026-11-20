# Shared shell

## Purpose

The plugin draws OpenProject's top bar, project menu, app switcher, account menu, home page and sign-in page the way a Nextcloud themed with thematiq draws them, so users see one shell across both products. The parts are in `lib/open_project/thematiq/shell/` and installed by `lib/open_project/thematiq/shell.rb`; view hooks are registered in `lib/open_project/thematiq/hooks.rb`; `lib/open_project/thematiq/shell/core_guard.rb` holds checksums of the core files the overrides lean on.

## Requirements

### Requirement: Overrides only on known core files

The plugin SHALL install the top bar, project menu, home and create dialog overrides only when the core files each part leans on match the checksums in `CoreGuard`, and SHALL otherwise leave that part as OpenProject draws it and log which files differ.

#### Scenario: Core file changed after an upgrade

- **WHEN** a core file the top bar leans on differs from its recorded checksum
- **THEN** OpenProject's own top bar renders and the log names the changed files

### Requirement: Top bar

The top bar SHALL show the design system's logo first and the app switcher after it, and SHALL show a row of app and module tiles only when an administrator set an own row of at most 12 entries; the default row is empty.

#### Scenario: Own row

- **WHEN** an administrator saves an own row of tiles
- **THEN** the tiles show in the top bar in that order

#### Scenario: Empty own row

- **WHEN** an administrator submits an own row with no entries
- **THEN** it is refused

### Requirement: App switcher

The nine-dot button SHALL open the plugin's own list in place of core's, with core's modules as core allows them, a Nextcloud column only when a Nextcloud address is set, the current entry marked, "Manage apps" for an administrator, and `aria-expanded` on the button.

#### Scenario: No Nextcloud address

- **WHEN** no Nextcloud address is set
- **THEN** the list shows OpenProject's modules only, in one column

### Requirement: Account menu

For a signed-in user the account menu SHALL be a dropdown under the avatar with core's own entries and conditions; it SHALL open on click, on the pointer and from the keyboard, and close on Escape with the focus returned to the button.

#### Scenario: Ordinary member

- **WHEN** a member who is not an administrator opens the account menu
- **THEN** it has no Administration entry

### Requirement: Project menu

The project menu SHALL show second-level items under their parent item (two layers) on core's own menu markup, with the items and permissions still decided by core.

#### Scenario: Item with a submenu

- **WHEN** a user opens a project menu item that has a submenu
- **THEN** its second level shows under the item instead of in a swapped sidebar

### Requirement: Home and My page

For a signed-in user, Home SHALL show the user's My page grid together with the Home blocks that have no widget, and the address of My page SHALL lead to Home; an anonymous visitor SHALL get OpenProject's own Home.

#### Scenario: Visit My page

- **WHEN** a signed-in user opens `/my/page`
- **THEN** the merged Home page is shown

### Requirement: Sign-in page

The sign-in pages of the account controller SHALL show no top bar, the design system's logo above a card and core's own form unchanged.

#### Scenario: Sign-in form

- **WHEN** a visitor opens the sign-in page
- **THEN** core's fields, button and checks are used as they are

### Requirement: Legal links and e-mail

When an administrator gives addresses for a privacy statement, an imprint or an accessibility statement, the plugin SHALL link them at the end of every page and on the sign-in page; when e-mail in the house style is turned on, every e-mail SHALL get a band in the primary colour at the top and the organisation's text and legal links at the end, all inline.

#### Scenario: E-mail style off

- **WHEN** e-mail in the house style has not been turned on
- **THEN** OpenProject's e-mail is sent unchanged
