# Uploaded files

An administrator can give a custom design system its own logo, icons and fonts. This page says what the plugin accepts, where it keeps the files and what stays behind when you remove the plugin.

## What you can upload

| Kind | Where it shows | File types | Largest file | Picture size |
|---|---|---|---|---|
| Logo | The top bar | SVG, PNG, JPEG, WebP | 512 KB | 16 px to 2000 by 1000 px |
| Logo for the coloured top bar | The top bar, instead of the logo | SVG, PNG, JPEG, WebP | 512 KB | 16 px to 2000 by 1000 px |
| Mobile logo | The top bar below 850 px | SVG, PNG, JPEG, WebP | 256 KB | 16 px to 1000 by 1000 px |
| Favicon | The browser tab | PNG, ICO, SVG | 128 KB | 16 px to 512 by 512 px |
| Touch icon | The home screen of a phone | PNG | 512 KB | 120 px to 1024 by 1024 px |
| Font | All text that names its family | WOFF2, WOFF, TTF, OTF | 2 MB | |

A design system holds one file of each kind and up to 12 font files. The picture sizes apply to PNG, JPEG, WebP and ICO. An SVG file has no pixel size.

The limits live in `lib/open_project/thematiq/uploads.rb`. The admin page reads them from there.

## Every upload is checked

The plugin trusts nothing about an upload. It ignores the file name and the type the browser sent.

1. **Size first.** A file over the limit of its kind is refused before anything reads it.
2. **Type by content.** The first bytes decide what the file is. A type the kind does not take is refused.
3. **The file must be whole.** For a PNG the plugin walks every chunk and checks every checksum. Nothing may follow the end. JPEG, WebP, ICO and the four font types get a structure check of their own.
4. **Declared size.** The plugin reads the width and height from the file and never decodes the picture. A small file that declares 60,000 by 60,000 pixels is refused.

When a file is refused, nothing is stored and the page says why.

### SVG files are rebuilt

An SVG file can carry script. So the plugin does not store what you upload. It parses the file and writes a new one from two lists: 42 elements and 116 attributes that only draw.

Left out, with everything inside:

- `script`, `foreignObject`, links and every animation element
- every attribute that starts with `on`
- every reference that leaves the file: `href` and `url()` may only point at an id in the same file
- embedded data, unless it is a PNG, JPEG or WebP picture by its own first bytes
- a `style` element or attribute with `@import`, `@font-face`, an outside `url()`, a backslash or `expression()`
- comments and processing instructions

Refused whole:

- a file that declares entities or has a document type with declarations of its own
- a file with more than 5,000 elements, nested deeper than 40, or that draws more than 50,000 elements through `use`
- a file whose root is not `svg` in the SVG namespace

The page tells you when parts were left out. Look at the preview: a logo that relied on one of them may look different.

`lib/open_project/thematiq/uploads/svg.rb` holds the lists. `test/fixtures/uploads/` holds the hostile files the tests feed it.

## Where the files live

The files are in the database, in a table of the plugin's own: `thematiq_uploads`. Each row holds one file with its bytes.

Why the database and not OpenProject's attachment storage:

- **Several servers.** Every server reads the same database. A second web server shows the logo without a shared folder or an S3 bucket.
- **Backup.** A database backup holds the files. You need no second step.
- **No sign in.** The favicon and the sign in page need the file before anyone signed in. OpenProject's attachments belong to a container with permissions, and with S3 they answer with a signed address that expires.
- **Small.** One design system holds at most about 26 MB. Most hold under 1 MB.
- **Ours alone.** The plugin writes to no table of OpenProject. The plugin does not touch the `CustomStyle` record of the Enterprise design page.

What it costs: the database serves the file. A file is read once per browser, because its address can be cached for a year. A browser that asks again with the file's tag gets a short answer, and the bytes stay in the database.

## Install and upgrade

The table comes with a migration. OpenProject runs it when it starts after you install the plugin. To run it by hand:

```bash
bundle exec rake db:migrate
```

Until the migration ran, the plugin behaves as if nothing was uploaded. No page fails.

## Remove the plugin

Removing the gem does not remove the data. Three things stay behind in the database:

| What | Where |
|---|---|
| The uploaded files | The table `thematiq_uploads` |
| The line that says the migration ran | `schema_migrations`, version `20261012090000` |
| The chosen design system and your custom ones | The setting `plugin_openproject_thematiq` |

To take the table out, roll the migration back **before** you remove the gem:

```bash
bundle exec rake db:migrate:down VERSION=20261012090000
```

That drops the table with every uploaded file, and removes the line in `schema_migrations`. It cannot be undone, so make a database backup first.

If the gem is already gone, drop the table by hand:

```sql
DROP TABLE thematiq_uploads;
DELETE FROM schema_migrations WHERE version = '20261012090000';
```

OpenProject works with the table left in place. It takes no part in anything else.
