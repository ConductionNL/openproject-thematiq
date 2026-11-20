# Custom design systems and the style editor

## Purpose

An administrator can make custom design systems: a base design system plus overrides, edited in a style editor with a live preview, or started from two colours, a CSS file of design tokens or an NL Design System theme. The main code paths are `lib/open_project/thematiq/custom_draft.rb`, `lib/open_project/thematiq/editor.rb`, `lib/open_project/thematiq/short_form.rb`, `lib/open_project/thematiq/css_tokens.rb`, `lib/open_project/thematiq/nlds_converter.rb` and the `edit`, `update_custom`, `from_colours`, `css_upload` and `nlds_upload` actions of `app/controllers/thematiq/admin_controller.rb`.

## Requirements

### Requirement: Limit and ids

The plugin SHALL keep at most 50 custom design systems, with ids `custom`, `custom-2` and so on, and SHALL refuse to open or save a new one when no id is free.

#### Scenario: At the limit

- **WHEN** 50 custom design systems exist and an administrator starts a new one
- **THEN** the request is refused with an error

### Requirement: Editor with preview

The editor SHALL group the values (among them branding, content area, buttons and links, typography, and thematiq's full vocabulary in closed groups under "More values"), SHALL keep an empty field at the base's value, and SHALL render preview and reset without saving; Save SHALL store the design system and make it the one in use.

#### Scenario: Invalid colour

- **WHEN** an administrator saves a value that fails its validator
- **THEN** nothing is saved and the editor shows the error

#### Scenario: Save and apply

- **WHEN** an administrator saves valid values
- **THEN** the custom design system is stored, applied and recorded in the history as `save_custom`

### Requirement: Dark values and references

The editor SHALL accept a dark value per colour on top of the base's dark colours, and a value MAY name another token of the same kind (such as `{primary}`) and follow it.

#### Scenario: Dark field left empty

- **WHEN** a colour's dark field is empty
- **THEN** the dark value of the base is kept

### Requirement: Documentation address

A custom design system MAY carry the address of its own documentation, which SHALL be an http or https address.

#### Scenario: Script address

- **WHEN** an administrator gives a `javascript:` address as documentation
- **THEN** the editor refuses it

### Requirement: Start from your colours

Two six-digit hex colours (a main colour and a background) SHALL give a draft with derived brand values that opens in the editor unsaved.

#### Scenario: Not a hex colour

- **WHEN** either colour is not a six-digit hex value
- **THEN** no draft opens and an error is shown

### Requirement: CSS file of design tokens

The plugin SHALL read an uploaded CSS file as declarations only, follow `var()` references, check every value by its kind, take dark values from a block or media query that says dark, save the result as a new custom design system, and report what was read and what was left out.

#### Scenario: File without tokens

- **WHEN** the uploaded CSS holds no usable token
- **THEN** it is refused and no design system is added

### Requirement: NL Design System theme

The plugin SHALL convert a built theme CSS, a W3C Design Tokens JSON or a Style Dictionary `tokens.json` by the vendored table `data/mapping/nlds-to-nextcloud.json` into a new custom design system, without component tokens, and show a report per token.

#### Scenario: Converted theme

- **WHEN** an administrator uploads an NL Design System theme
- **THEN** a new custom design system is added and the report lists what was left out

### Requirement: Delete with confirmation

Deleting a custom design system SHALL ask for confirmation on a separate page and then remove its uploaded files and the scope choices that name it.

#### Scenario: Confirmed delete

- **WHEN** an administrator confirms the delete
- **THEN** the design system, its uploads and its scope rows are gone and a history row `delete_custom` is written

### Requirement: Component playground

The playground SHALL draw OpenProject's components in a chosen design system in the content area only, and pasted HTML and CSS SHALL be drawn in a sandboxed frame that runs no script, with the CSS checked by the same rules as the administrator's own CSS; nothing is stored.

#### Scenario: CSS that reaches outward

- **WHEN** the pasted CSS contains `url()` or `@import`
- **THEN** the CSS is refused and the errors are shown
