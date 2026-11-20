# Design system catalogue and picker

## Purpose

The plugin ships a catalogue of design systems inside the gem and lets an administrator pick the one in use on the "Thematiq design" admin page. The catalogue is read by `lib/open_project/thematiq/catalogue.rb` from `data/catalogue/shell-catalogue.json` plus OpenProject's own colour themes in `data/catalogue/openproject-themes.json`; the picker, comparison, trial and planned switch live in `app/controllers/thematiq/admin_controller.rb`, `lib/open_project/thematiq/trial.rb` and `lib/open_project/thematiq/store.rb`.

## Requirements

### Requirement: Bundled catalogue

The plugin SHALL load its design systems from the bundled catalogue files, pass every set through the token validator, skip any entry that does not have the set shape or reuses a taken or reserved `custom` id, and never raise while loading.

#### Scenario: Unusable catalogue file

- **WHEN** the catalogue file is missing, too large, not valid JSON or holds no usable set
- **THEN** the catalogue holds the last resort token set from `Tokens::Defaults`
- **AND** the catalogue records a short error code that the health report reads

#### Scenario: Default design system

- **WHEN** no design system has been chosen on a fresh install
- **THEN** the design system in use is `cunningham`, or the first set when the catalogue has no `cunningham`

### Requirement: Search and filter in the picker

The picker SHALL list every catalogue set and every custom design system, narrow both by a search query in which every word (at most eight) must be part of the name or id, and narrow them further to one whole design system (such as NL Design System or La Suite) when a known one is given.

#### Scenario: Search narrows the list

- **WHEN** an administrator searches for part of a design system's name
- **THEN** only the sets whose name or id contain every word of the query are listed

#### Scenario: Unknown design system filter

- **WHEN** the design system filter names an id the plugin does not know
- **THEN** every set is shown

### Requirement: Documentation link

A set SHALL link to its own documentation address when it has one, else to the documentation address of the whole design system it belongs to, and only http or https addresses without credentials SHALL be accepted.

#### Scenario: Set of a design system with documentation

- **WHEN** a set belongs to NL Design System and has no address of its own
- **THEN** the picker links to the design system's documentation in a new tab with `rel="noopener noreferrer"`

### Requirement: Compare before apply

Choosing a design system SHALL first show every value that differs from the one in use, light and dark, without applying anything; applying SHALL then make it the design system in use, and values left unticked SHALL be kept by saving the result as a new custom design system.

#### Scenario: Apply with every value ticked

- **WHEN** an administrator applies a design system from the comparison page with every value ticked
- **THEN** it becomes the design system in use for everyone and a history row `apply` is written
- **AND** a request that asks for JSON receives the new style sheets so the page repaints without a reload

#### Scenario: Design system set by the environment

- **WHEN** `THEMATIQ_DESIGN_SYSTEM` names an existing design system
- **THEN** applying from the admin page is refused

### Requirement: Trial in the administrator's session

An administrator SHALL be able to try a design system in their own session on every page, for at most one day, and then publish it to everyone or discard it; nobody else SHALL see the trial.

#### Scenario: Trial ends by itself

- **WHEN** a trial was started more than 24 hours ago, or the person is no longer an administrator
- **THEN** the person sees the design system everyone sees

### Requirement: Planned switch

The plugin SHALL let an administrator plan a switch to a design system at a future time (at most 20 planned), and SHALL make the switch on the first page drawn after that time, with no background job, recording it in the history.

#### Scenario: Time in the past

- **WHEN** a switch is planned for a time that has already passed
- **THEN** nothing is stored and an error is shown

### Requirement: Gallery check

The plugin SHALL read thematiq's published catalogue only when an administrator turned the gallery on, only from one https address, and SHALL list the sets it does not have or has with other values, each of which can be added as a custom design system.

#### Scenario: Gallery off

- **WHEN** the gallery has not been turned on
- **THEN** the plugin makes no request to the gallery address
