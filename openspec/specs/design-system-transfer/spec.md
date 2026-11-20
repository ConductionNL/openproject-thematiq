# Design system export, import and Figma transfer

## Purpose

One design system moves between installations as a small JSON file in the set shape, and between OpenProject and Figma as a design token file in one of three formats. The main code paths are `lib/open_project/thematiq/transfer.rb`, `lib/open_project/thematiq/figma.rb`, `lib/open_project/thematiq/figma/reader.rb` and the `export`, `import`, `figma_download` and `figma_upload` actions of `app/controllers/thematiq/admin_controller.rb`.

## Requirements

### Requirement: Export one design system

The plugin SHALL export a catalogue set or a custom design system as a JSON file in the set shape, named `thematiq-<id>.json`; when the design system has uploaded files, the file SHALL name their kinds in an `uploads` note and SHALL NOT contain the files.

#### Scenario: Export with uploads

- **WHEN** an administrator exports a custom design system that has an uploaded logo
- **THEN** the file holds the tokens and an `uploads` entry naming `logo`, without the logo itself

#### Scenario: Unknown id

- **WHEN** an export is asked for an id that does not exist
- **THEN** the answer is 404

### Requirement: Import as a new custom design system

The plugin SHALL read an imported file as hostile input (at most 64 KB, JSON nesting at most 4, the set shape with no unknown key, every value valid) and SHALL add it as a new custom design system; an import SHALL NOT replace an existing design system.

#### Scenario: Broken file

- **WHEN** the imported file is not valid JSON or holds one invalid value
- **THEN** it is refused whole and no design system is added

#### Scenario: Script documentation address

- **WHEN** the imported file has a `documentation_url` that is not an http or https address
- **THEN** it is refused

#### Scenario: File that left uploads behind

- **WHEN** an imported file carries an `uploads` note
- **THEN** the notice names the kinds of file to upload again

### Requirement: Figma download

The plugin SHALL offer every design system as a token file in three formats: W3C Design Tokens (`dtcg`), Tokens Studio, and Tokens Studio in its legacy `value`/`type` spelling. The dark values SHALL travel with the file: in a dark token set and theme for Tokens Studio, and in the plugin's own `$extensions` entry for W3C Design Tokens.

#### Scenario: Unknown format

- **WHEN** a download names a format that is not one of the three
- **THEN** the answer is 404

### Requirement: Figma upload

The plugin SHALL read an uploaded Figma token file, or up to 40 files of a Tokens Studio folder at once, as hostile input, add the result as a new custom design system and show what was imported, what was skipped and why.

#### Scenario: Nothing usable

- **WHEN** the uploaded files hold no token the plugin can use
- **THEN** they are refused and no design system is added

#### Scenario: Round trip

- **WHEN** a design system is downloaded in one of the three formats and uploaded again
- **THEN** the new custom design system has the same values
