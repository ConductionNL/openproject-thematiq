# Read API, shell-tokens and the shared appearance link

## Purpose

Other apps on the same OpenProject can read the design systems, their style sheets, a contrast check, the deprecated tokens, the own tokens and the icon library through read-only JSON and CSS endpoints. A public shell-tokens endpoint answers in the same shape as thematiq's in Nextcloud, and another product can link a person here to set their light or dark choice. The main code paths are `app/controllers/thematiq/api_controller.rb`, `lib/open_project/thematiq/read_api.rb`, `app/controllers/thematiq/shell_tokens_controller.rb` and `app/controllers/thematiq/appearance_controller.rb`.

## Requirements

### Requirement: Read endpoints for signed-in users

The endpoints under `/thematiq/api/v1/` (`sets`, `sets/:id`, `sets/:id/stylesheet.css`, `sets/:id/manifest`, `contrast`, `deprecations`, `own-tokens` and `icons`) SHALL answer any signed-in user, need no administrator rights and write nothing.

#### Scenario: Not signed in

- **WHEN** a visitor without a session asks for `/thematiq/api/v1/sets`
- **THEN** the answer is a redirect to sign in or 401, and no data is answered

#### Scenario: List of design systems

- **WHEN** a signed-in user asks for `/thematiq/api/v1/sets`
- **THEN** the answer lists every design system, custom ones first, each with its id, name, whether it is custom, whether it is in use, its primary colour and whether it has a dark block

### Requirement: One design system and its style sheet

The plugin SHALL answer one design system in the set shape, its whole style sheet as `text/css` with `nosniff`, and a manifest naming that style sheet and the style tags it replaces; an unknown id SHALL answer 404.

#### Scenario: Unknown id

- **WHEN** a signed-in user asks for `/thematiq/api/v1/sets/nope/stylesheet.css`
- **THEN** the answer is 404

### Requirement: Contrast check

The contrast endpoint SHALL measure two colours the way the plugin does and answer the ratio, the minimum of 4.5, the large text minimum of 3.0 and a verdict of `pass`, `large_text_only`, `fail` or `unknown`.

#### Scenario: Unreadable colour

- **WHEN** one of the two colours does not pass the colour validator
- **THEN** the ratio is null and the verdict is `unknown`

### Requirement: Deprecated tokens

The deprecations endpoint SHALL list every token an administrator marked as deprecated with its severity (`info`, `warning` or `critical`), replacement, removal date, CSS names and whether the date has passed; a deprecation SHALL NOT change any value.

#### Scenario: Past the removal date

- **WHEN** a deprecated token's removal date has passed
- **THEN** it is listed with `due` true and keeps working

### Requirement: Public shell-tokens

`/thematiq/api/shell-tokens` SHALL answer without a session, with no cookie set, the design system in use as version 1 of thematiq's shell-tokens shape (id, name, a revision, the eighteen roles and the logo addresses), cached for 60 seconds.

#### Scenario: Anonymous request

- **WHEN** a client without a session asks for `/thematiq/api/shell-tokens`
- **THEN** the answer is 200 with the eighteen roles of the design system in use

### Requirement: Shared light or dark choice

When an administrator has turned it on, `/thematiq/appearance?mode=light|dark|system` SHALL set the signed-in person's theme and redirect to `return_to` when it is a path on this instance or an address under the Nextcloud address, else to Home.

#### Scenario: Turned off

- **WHEN** the link has not been turned on
- **THEN** the address answers 404

#### Scenario: Unknown mode

- **WHEN** `mode` is not `light`, `dark` or `system`
- **THEN** the answer is 400 and the preference is unchanged
