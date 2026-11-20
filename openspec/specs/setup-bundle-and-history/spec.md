# Setup bundle, history and restore

## Purpose

The plugin's whole setup (its settings and the choices per project and module) is one document, the bundle. It downloads as a configuration file, is read back after a preview, applies itself at start from `THEMATIQ_BUNDLE_FILE`, and is kept with every change in an append-only history that can be restored. The main code paths are `lib/open_project/thematiq/bundle.rb`, `lib/open_project/thematiq/boot_bundle.rb`, `app/models/thematiq/change.rb`, the bundle and history actions of `app/controllers/thematiq/admin_controller.rb`, and `lib/tasks/thematiq.rake`.

## Requirements

### Requirement: Bundle contents

A bundle SHALL hold the format `openproject-thematiq-bundle`, version 1, the plugin settings listed in `Bundle::SETTING_KEYS` and the scope rows with projects named by identifier; it SHALL NOT hold uploaded files, the share key or the share settings.

#### Scenario: Download the whole setup

- **WHEN** an administrator downloads the whole setup
- **THEN** a JSON file named `openproject-thematiq-setup-<date>.json` is sent

### Requirement: Checked import with a preview

Reading a bundle SHALL treat it as hostile input (at most 2 MB, no unknown key, every part checked by the store's own rules, projects matched by identifier) and SHALL refuse the whole bundle when one part fails; the admin page SHALL show what the bundle changes and write nothing until the administrator confirms.

#### Scenario: Preview

- **WHEN** an administrator uploads a valid configuration file
- **THEN** a page lists what it changes and nothing is written yet

#### Scenario: Hostile file

- **WHEN** the uploaded file is not a bundle, too large or has one invalid part
- **THEN** it is refused and nothing changes

#### Scenario: Confirm

- **WHEN** the administrator confirms the import
- **THEN** the file is read and checked again, applied in one transaction, and a history row `bundle_import` is written

### Requirement: Append-only history

Every change to the setup SHALL write one history row with the action, the person (or none for the command line and start-up), a detail and the bundle after the change; rows SHALL NOT be updated or deleted through the model, and only the 50 newest rows SHALL keep their bundle.

#### Scenario: Old row

- **WHEN** a row is older than the 50 newest
- **THEN** it keeps who, what and when but can no longer be restored

#### Scenario: History cannot be written

- **WHEN** writing a history row fails
- **THEN** the change itself still succeeds and the log says no version was kept

### Requirement: Restore with a preview

Restoring a version SHALL first list what it changes, SHALL write nothing until confirmed, SHALL refuse a version whose bundle no longer passes the checks, and SHALL be recorded as a change of its own.

#### Scenario: Restore a version

- **WHEN** an administrator confirms the restore of a restorable version
- **THEN** that setup is applied and a history row `restore` is written

### Requirement: History as CSV

The history SHALL download as CSV with the columns time, user, action, detail and restorable, and a cell that starts like a spreadsheet formula SHALL be prefixed with a quote.

#### Scenario: Formula-like detail

- **WHEN** a detail starts with `=`
- **THEN** the CSV cell starts with `'=`

### Requirement: Bundle file at start

When `THEMATIQ_BUNDLE_FILE` names a file, the plugin SHALL apply it at start only when its SHA-256 digest differs from the one applied last, SHALL let only one process apply it, SHALL refuse a file that does not read and still let OpenProject start, and SHALL record each application in the history.

#### Scenario: Unchanged file

- **WHEN** OpenProject restarts with the same bundle file
- **THEN** the file is not applied again and later changes from the admin page stay

### Requirement: Command line

The rake tasks `thematiq:bundle:export`, `thematiq:bundle:import`, `thematiq:history` and `thematiq:restore` SHALL export, import, list the newest 50 changes and restore a version; import and restore SHALL list the changes and change nothing when `DRY_RUN=1`.

#### Scenario: Dry run

- **WHEN** `rake "thematiq:restore[42]"` runs with `DRY_RUN=1`
- **THEN** the changes are printed and nothing is written
