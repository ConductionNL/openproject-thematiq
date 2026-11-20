# Uploads: logos, icons, fonts and PDF export files

## Purpose

A stored custom design system can carry uploaded files: logos, a favicon, a touch icon, a sign-in background, fonts and the files of PDF exports. A font library holds fonts for every design system. Files are checked by their content, stored in the plugin's table `thematiq_uploads` and served on a public route. The main code paths are `lib/open_project/thematiq/uploads.rb`, `lib/open_project/thematiq/uploads/inspector.rb`, `lib/open_project/thematiq/uploads/svg.rb`, `lib/open_project/thematiq/uploads/response.rb`, `app/controllers/thematiq/files_controller.rb` and the `update_files` action of `app/controllers/thematiq/admin_controller.rb`.

## Requirements

### Requirement: Kinds and limits

The plugin SHALL accept only the kinds listed in `Uploads::KINDS` (logo, logo for the coloured top bar, mobile logo, favicon, touch icon, sign-in background, font, and the PDF export logo, cover, footer and four TrueType font cuts), each with its own formats, byte limit and image dimensions, at most 12 font files per design system, and one file for every other kind, which a new upload replaces.

#### Scenario: Too large

- **WHEN** an administrator uploads a logo larger than its kind's limit
- **THEN** it is refused and the error states the limit

#### Scenario: Not yet saved

- **WHEN** files are uploaded for an id that is neither a stored custom design system nor the font library
- **THEN** the answer is 404

### Requirement: Content inspection

The plugin SHALL decide a file's format from its content, refuse what it does not recognise or what does not fit its kind, and rebuild an SVG file from an allow-list so no script survives.

#### Scenario: SVG with a script

- **WHEN** an administrator uploads an SVG logo that contains a script element
- **THEN** the stored file is rebuilt without it and the notice says the file was cleaned

#### Scenario: Wrong content

- **WHEN** a file's content is not one of the formats its kind accepts
- **THEN** it is refused

### Requirement: Public file route

The plugin SHALL serve an uploaded file at `/thematiq/files/<token>` without a session, only for a token of 64 lowercase hex characters looked up in its own table, with the content type decided at upload, `nosniff`, a content security policy that allows no script, and a long immutable cache with an ETag.

#### Scenario: Near miss

- **WHEN** a request asks for a token with a trailing slash, of the wrong length or not in the table
- **THEN** the answer is 404 and no file is read from disk

#### Scenario: Cached copy

- **WHEN** a request sends an `If-None-Match` that matches the file's ETag
- **THEN** the answer is 304

### Requirement: Remove with confirmation

Removing an uploaded file SHALL ask for confirmation first and SHALL be recorded in the history.

#### Scenario: Confirmed removal

- **WHEN** an administrator confirms the removal of a file
- **THEN** the file is gone and a history row `remove_upload` is written

### Requirement: Font library

The font library SHALL hold fonts only, and every design system whose font names a family in the library SHALL use it; a design system's own upload of the same family wins.

#### Scenario: Non-font upload to the library

- **WHEN** an administrator uploads a logo to the font library
- **THEN** it is refused

### Requirement: PDF export files

When a design system has PDF export uploads, PDF exports of a project that wears it SHALL use its PDF logo, footer picture, cover picture and fonts; a value left empty SHALL keep OpenProject's own, and the patch SHALL stay off when the core exporter files differ from their recorded checksums.

#### Scenario: No PDF uploads

- **WHEN** the design system of an exported project has no PDF export files
- **THEN** the export keeps OpenProject's look
