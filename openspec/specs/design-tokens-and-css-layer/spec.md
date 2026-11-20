# Design tokens and the CSS variable layer

## Purpose

Every design system is a token set of eighteen checked roles, optional extra roles, an optional dark block and an optional set of values from thematiq's full vocabulary. The plugin writes the set to the CSS variables OpenProject and Primer already read, and inlines the result in the page head. The main code paths are `lib/open_project/thematiq/tokens/validator.rb`, `lib/open_project/thematiq/tokens/token_set.rb`, `lib/open_project/thematiq/variables/generator.rb`, `lib/open_project/thematiq/stylesheet.rb` and `app/views/thematiq/hooks/_head.html.erb`.

## Requirements

### Requirement: Allow-list validation of token values

The plugin SHALL accept a token value only when its whole text matches the safe syntax of its kind (colour, length, font family stack and the vocabulary kinds) and SHALL rebuild font stacks, borders, filters and RGB triplets from their parsed parts.

#### Scenario: Value outside the allow-list

- **WHEN** a catalogue or stored set holds a value that fails its validator
- **THEN** the value of the base is used and the key is listed as rejected

#### Scenario: Strict import

- **WHEN** an imported set has an unknown key or one value that fails validation
- **THEN** the whole set is refused

### Requirement: Variable layer

The plugin SHALL write a validated set to OpenProject's design variables, to Primer's variables and to `--thematiq-*` aliases, and SHALL leave out every variable whose token the set does not have, so OpenProject's own value stays.

#### Scenario: Light theme

- **WHEN** a page is drawn in OpenProject's light theme
- **THEN** the token colours apply under `body[data-color-mode="light"][data-light-theme="light"]`

#### Scenario: Early variant for other layouts

- **WHEN** a layout calls the meta hook but not the head hook (error pages, for example)
- **THEN** an early variant of the variable layer is written before OpenProject's stylesheets and wins by a more specific selector

### Requirement: Dark theme

The plugin SHALL write the set's dark colours under `body[data-color-mode="dark"][data-dark-theme="dark"]` only when the set has a dark block whose text colour on its background reaches a contrast of 4.5 to 1 (or cannot be measured); otherwise OpenProject's own dark values stay.

#### Scenario: Set without a usable dark block

- **WHEN** a set has no dark block, or its dark `ink` on `ground` is below 4.5 to 1
- **THEN** no dark block is written

### Requirement: Brand stripe

The plugin SHALL draw thematiq's brand stripe as one gradient only for a set whose vocabulary gives all three stripe colours, in their ratios, with a height of 4px when none is given.

#### Scenario: Two stripe colours

- **WHEN** a set gives only two of the three stripe colours
- **THEN** no brand stripe variable is written

### Requirement: Own tokens

An administrator SHALL be able to add up to 100 own tokens named `--thematiq-org-<name>` of a fixed list of kinds, each checked by the validator of its kind, with an optional dark colour; they SHALL be written on `:root` on every page and the dark values in the dark theme.

#### Scenario: Invalid own token

- **WHEN** an own token's value fails the validator of its kind
- **THEN** nothing is stored and the reason is shown

### Requirement: Administrator's own CSS

The plugin SHALL accept free CSS from an administrator only as style rules and `@media` blocks, SHALL refuse the whole submission and name the parts when any part holds `@import`, another at-rule, `url()`, escapes or a forbidden property, and SHALL serve the rewritten CSS last in the head only while it is turned on.

#### Scenario: CSS with url()

- **WHEN** an administrator saves CSS in which one part contains `url()`
- **THEN** nothing is stored and the refused parts are listed

### Requirement: Style tags follow the page

Each style tag the plugin writes SHALL carry `data-turbo-track="reload"`, so a page whose design system differs from the previous one is loaded whole by Turbo.

#### Scenario: Leaving a project with its own design system

- **WHEN** a user moves from a project with its own design system to a page without one
- **THEN** the plugin's style tags are replaced by those of the new page
