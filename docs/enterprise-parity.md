# Parity with OpenProject's Enterprise design page

OpenProject's Enterprise edition has an administration page called "Design". This page lists what it offers and what this plugin offers for the same need, by its own means.

The plugin never reads, calls or works around `EnterpriseToken`, the `CustomStyle` record or the `custom_styles` controller. It writes nothing to their tables. Where a capability can only be had through those, it is listed here as not built, with the options.

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
| Logo | Upload | A bundled logo for 14 of the 64 design systems. No upload | **Partly built** |
| Mobile logo | Upload | None | **Not built** |
| Favicon | Upload | None | **Not built** |
| Touch icon | Upload | None | **Not built** |
| Custom colours by hand | Five colour fields | The editor: all eighteen tokens of one custom design system | Built, not checked live |
| Move a design between installations | Not offered | Export and import as a JSON file | Built, not checked live |
| PDF export: logo | Upload | None | **Not built, see below** |
| PDF export: cover image | Upload | None | **Not built, see below** |
| PDF export: footer image | Upload | None | **Not built, see below** |
| PDF export: cover text colour | One colour field | None | **Not built, see below** |
| PDF export: fonts | Four font files: regular, bold, italic, bold italic | None | **Not built, see below** |
| Dark theme colours | Not offered. Their colours apply to the light theme, with OpenProject's own mapping for dark | A design system may carry a `dark` block. No bundled set has one | Room made, no data |

"Not checked live" means: unit tested, never rendered in a running OpenProject.

## Why uploads are not built

Logo upload, mobile logo, favicon, touch icon and font upload all need the same three things: a place to keep a file, a check on what was uploaded and a way to serve it.

OpenProject keeps its own files of this kind on the `CustomStyle` record. The plugin must not use that. The clean way is a table of the plugin's own with OpenProject's file uploader, which means a database migration, an upload form, a check that an uploaded SVG holds no script, and a controller that serves the file to people who are not signed in.

None of that could be run while this was written: no OpenProject instance was available to this work. A migration and a public file endpoint that have never run are not something to ship unseen. So they are left for a round with a running instance.

The favicon has one more problem. OpenProject writes its own favicon link after the only hook a plugin gets in that part of the head. With two links, the browser decides which one it uses. Replacing it for certain needs an override of OpenProject's `common/favicons` partial.

## PDF export styling: stopped, with options

OpenProject's PDF exporters read their styling straight from the `CustomStyle` record:

- `app/models/exports/pdf/common/logo.rb` reads `CustomStyle.current.export_logo`.
- `app/models/exports/pdf/components/cover.rb` reads `export_cover` and `export_cover_text_color`.
- `app/models/exports/pdf/components/page.rb` reads `export_footer`.
- `app/models/exports/pdf/common/view.rb` reads the four `export_font_*` files.

There is no setting, hook or parameter in between. The exporters themselves have no licence check; the check sits on the page that fills the record.

So the same capability cannot come from the plugin's own storage through a clean extension point. The options:

| Option | What it takes | Cost and risk |
|---|---|---|
| A. Leave PDF export as it is | Nothing | PDFs keep OpenProject's default logo and font. No risk |
| B. Prepend the plugin's own readers to those four exporter modules | A table and upload form of the plugin's own, plus four small overrides that return the plugin's files | A few days with a running instance. It patches four core classes, so it can break on any OpenProject release, and it must be retested on each one |
| C. Ask OpenProject for an extension point | An upstream issue or pull request that lets a plugin supply the export logo, cover, footer and fonts | Slow and not in our hands. The only clean route |
| D. Write the files into the `CustomStyle` record | Not an option. It uses the storage of the Enterprise feature | Ruled out |

This document recommends A now and C for later. B is possible and is a decision for the product owner, because of the upkeep.

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
| The logo | **The plugin**, for the 14 design systems that bring one. Otherwise the Enterprise logo stays | The plugin's logo rule is more specific and comes later |
| Favicon, touch icon, PDF export | **The Enterprise page** | The plugin does not touch them |
| Sizes | **The plugin** | The Enterprise page has no sizes |

An installation with a token and this plugin should choose one of the two for colours. With both, an administrator who changes a colour on OpenProject's Design page sees no change in the light theme.

To settle any row of this section, try it on an installation that has a token.
