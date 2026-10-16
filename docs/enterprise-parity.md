# Parity with OpenProject's Enterprise design page

OpenProject's Enterprise edition has an administration page called "Design". This page lists what it offers and what this plugin offers for the same need, by its own means.

The plugin never reads, calls or works around `EnterpriseToken`, the `CustomStyle` record or the `custom_styles` controller. It writes nothing to their tables. Where core reads that record with no extension point, as the PDF exporters do, the plugin answers in core's place from its own values and leaves core's reader in charge when it has none.

The left column comes from reading OpenProject 17's source: `app/controllers/custom_styles_controller.rb`, `app/views/custom_styles/`, `app/models/custom_style.rb`, `app/models/design_color.rb` and `lib/open_project/custom_styles/`. Nothing here was tried with an Enterprise token.

## The table

| Capability | Theirs | Ours | Status |
|---|---|---|---|
| Preset themes | Three colour themes: OpenProject, OpenProject Gray and OpenProject Navy Blue | 64 design systems from thematiq, checked live, plus those same three themes as design systems of the plugin's own making | The three: built, not checked live |
| Primary button colour | `primary-button-color` | The tokens `action` and `action-deep` | Built, not checked live |
| Accent colour | `accent-color`, used for links and highlights | The token `link`. The token `accent` exists and no OpenProject variable uses it yet | Built, not checked live |
| Header background | `header-bg-color` | The token `primary` | Built, measured live in an earlier round |
| Main menu background | `main-menu-bg-color` | The optional role `menu`. The text on it follows a contrast rule | Built, not checked live |
| Selected menu item | `main-menu-bg-selected-background` | The tokens `primary-light` and `primary-deep` | Built, measured live in an earlier round |
| Text, lines, fields, page background | Not offered | The tokens `ink`, `muted`, `line`, `soft`, `ground` and `field` | Built, more than theirs |
| Corners | Not offered | The tokens `radius` and `radius-lg` | Built, more than theirs |
| Font of the interface | Not offered | The token `font-family`, with 13 font families served by the plugin | Built, not checked live |
| Sizes of top bar, menu, buttons, rows | Not offered | The geometry layer | Built, measured live in an earlier round |
| Logo | Upload | A bundled logo for 15 of the 64 design systems. Upload for a custom design system: SVG, PNG, JPEG or WebP, with a second file for the coloured top bar | Built, not checked live |
| Mobile logo | Upload | Upload for a custom design system, shown below 850 px | Built, not checked live |
| Favicon | Upload | Upload for a custom design system: PNG, ICO or SVG | Built, not checked live |
| Touch icon | Upload | Upload for a custom design system: PNG | Built, not checked live |
| Fonts of the interface as files | Not offered | Upload of up to 12 font files per custom design system | Built, more than theirs, not checked live |
| Custom colours by hand | Five colour fields | The editor: all eighteen tokens of one custom design system | Built, not checked live |
| Move a design between installations | Not offered | Export and import as a JSON file | Built, not checked live |
| PDF export: logo | Upload | Upload for a custom design system: PNG or JPEG | Built, checked live on 17.9.1, see below |
| PDF export: cover image | Upload | Upload for a custom design system: PNG or JPEG | Built, checked live on 17.9.1, see below |
| PDF export: footer image | Upload | Upload for a custom design system: PNG or JPEG | Built, checked live on 17.9.1, see below |
| PDF export: cover text colour | One colour field | The value "Cover text" (`pdf-cover-text`) of a design system | Built, checked live on 17.9.1, see below |
| PDF export: fonts | Four font files: regular, bold, italic, bold italic | The same four TrueType cuts, uploaded for a custom design system | Built, checked live on 17.9.1, see below |
| Dark theme colours | Not offered. Their colours apply to the light theme, with OpenProject's own mapping for dark | A design system may carry a `dark` block. No bundled set has one | Room made, no data |

"Not checked live" means: unit tested, never rendered in a running OpenProject.

## How uploads are built

The plugin keeps uploaded files in a table of its own, `thematiq_uploads`, checks every file by its content and serves it from an endpoint of its own. It uses none of the storage of the Enterprise design page. [uploads.md](uploads.md) has the limits, the checks and the storage choice.

What differs from theirs:

- **Per design system.** Their files belong to the installation. Ours belong to one custom design system, so two design systems can have two logos.
- **SVG.** An uploaded SVG file is rebuilt from an allow-list, so it holds no script.
- **The favicon link.** OpenProject writes its own favicon link after the first hook a plugin gets. On normal pages the plugin writes its link again after it. On error pages, the external link warning and OAuth consent there is one hook only, and the browser picks between the two links.
- **PDF export.** The files of PDF exports are their own kinds, PNG, JPEG and TrueType only, because that is what OpenProject's exporter embeds. The logo of the top bar does not reach a PDF. See below.

"Not checked live" for these rows means: unit tested, the table and the endpoint run against a PostgreSQL without OpenProject, the form rendered without OpenProject. Not yet run in a real OpenProject.

## PDF export styling

OpenProject's PDF exporters read their styling straight from the `CustomStyle` record, in four core files with no setting, hook or parameter in between. The product owner chose to patch those four, with a guard that switches the patch off when one of them changes. `lib/open_project/thematiq/pdf_export/patches.rb` prepends a reader to each:

| Core file | What core reads | What the plugin prepends |
|---|---|---|
| `app/models/exports/pdf/common/logo.rb` | `CustomStyle.current.export_logo` | `custom_logo_image_filename`: the PDF logo |
| `app/models/exports/pdf/components/cover.rb` | `export_cover`, `export_cover_text_color` | `custom_cover_image_file`: the cover picture; `validate_cover_text_color`: the value "Cover text" |
| `app/models/exports/pdf/components/page.rb` | `export_footer` | `custom_footer_image`: the footer picture; `configure_page_size!`: remembers the styling of this export for the fonts |
| `app/models/exports/pdf/common/view.rb` | the four `export_font_*` files | `View.valid_custom_font?` and `View#custom_font_files`: the four TrueType cuts |

Each reader answers from the plugin when the design system has the value, and calls core's own reader otherwise. So an installation without PDF files exports as before, and with an Enterprise token core's Design page still fills whatever the plugin leaves empty. The plugin reads nothing of that record itself.

Which design system: the one of the whole page of the exported project, by the rules of [scopes](design/scopes.md), the project's own, then its parents', then the instance's. A work package takes its project; a list or report its query's project; a meeting its meeting's project. An export without a project, such as the list of projects, takes the instance's design system, or a group's for its members. A trial of a design system in an administrator's session does not reach exports: the export reads no session.

How a file reaches Prawn, which reads files by path: the plugin writes the stored bytes once to `openproject-thematiq-pdf/` in the system's temporary folder, named by their SHA-256, and checks that checksum again on each export. The folder is made for OpenProject's user alone. Before a picture is handed to core, Prawn builds it once; a file it cannot embed, or a font TTFunk cannot read, falls back to core's file and is logged, so a design system never stops an export.

The fonts are read by the View and by class methods that know nothing of the exporter. `configure_page_size!`, which every exporter with pages calls before its document exists, keeps the export's styling in `ActiveSupport::CurrentAttributes`; Rails resets it after each request and job. An export that sets no page size, such as a document from a PDF template, takes the instance's fonts while its logo follows the work package's project.

### When an OpenProject upgrade changes a file

The four files are the part `pdf_export` of `lib/open_project/thematiq/shell/core_guard.rb`, with their SHA-256 of 17.9.1; 17.9.2 has them byte for byte. When one differs, the patches are not installed, exports keep OpenProject's own styling, and the log says:

```
[openproject-thematiq] The PDF export patches are off. These core files differ from OpenProject 17.9.1 and 17.9.2: ...
```

The rest of the plugin stays on. `script/check-core.rb` fails on the same files. Read the new core file, adjust `patches.rb`, then update the checksum.

### What is not built

- **Defaults for the catalogue's design systems.** None has a PDF logo or font: the catalogue's logos are SVG and its fonts WOFF2, and the exporter embeds neither. A catalogue design system only exports in core's style. A custom design system based on one takes the uploads.
- **Named colours for the cover text.** "Cover text" takes a hex or `rgb()` colour; a named colour leaves core's colour.

The request to OpenProject for an extension point, [upstream/pdf-export-extension-point.md](upstream/pdf-export-extension-point.md), was not sent. It is kept: if OpenProject adds such a place, the patch can go.

## If an Enterprise token is present

Then OpenProject's Design page and this plugin both write colour variables. This is a reading of the source. It was not tested, because no token was used.

OpenProject's shared head partial, `app/views/layouts/_common_head.html.erb`, writes in this order:

1. The hook `view_layouts_base_html_meta`. The plugin's early style tag goes here.
2. OpenProject's stylesheets.
3. `custom_styles/inline_css_logo`: the logo rule.
4. `custom_styles/primer_color_mapping`: OpenProject's mapping from its own variables to Primer's.
5. `custom_styles/inline_css`: the Enterprise colours, on `:root`. Only with a token.

Then `layouts/base` calls `view_layouts_base_html_head`, where the plugin's full style tag goes. So the plugin's CSS comes last on a normal page.

What follows from that:

| What | Who wins | Why |
|---|---|---|
| Header, button, accent and selected item colours, light theme | **The plugin** | The Enterprise page writes them on `:root`. The plugin writes them on the `body` element, which is closer to every element on the page, and it comes later |
| Main menu background, light theme | **The plugin, with white** | Same reason. An Enterprise main menu colour would be lost. This is the gap in the table above |
| The same colours in the dark theme and the high contrast themes | **OpenProject and its Design page** | The plugin writes no colours there unless the design system has a `dark` block |
| The logo | **The plugin**, for the 15 design systems that bring one and for a custom design system with an uploaded logo. Otherwise the Enterprise logo stays | The plugin's logo rule is more specific and comes later |
| Favicon, touch icon | **Not known.** Both write a link when both have a file | The Enterprise links come after the plugin's first hook and before its second |
| PDF export | **The plugin**, for each value its design system has. The Enterprise page for the rest | The plugin's readers answer first and call core's reader when they have no value |
| Sizes | **The plugin** | The Enterprise page has no sizes |

An installation with a token and this plugin should choose one of the two for colours. With both, an administrator who changes a colour on OpenProject's Design page sees no change in the light theme.

To settle any row of this section, try it on an installation that has a token.
