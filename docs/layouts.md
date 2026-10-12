# Which pages are styled

OpenProject renders its pages through a handful of layouts. This page lists them and says which ones the plugin reaches. The list comes from reading OpenProject 17's source. Three pages were then checked in a running OpenProject 17.9.1: the work package table, the sign in page and a page that does not exist. The sign in page had the full look with a 68 px top bar. The missing page had the colours, the font and the logo, with OpenProject's own 55 px top bar.

## The two hooks

| Hook | Where OpenProject calls it | What the plugin puts there |
|---|---|---|
| `view_layouts_base_html_meta` | In the shared head partial, before OpenProject's stylesheets | The variable layer in its early form, the fonts, the logo and the uploaded icons |
| `view_layouts_base_html_head` | In `layouts/base` only, after OpenProject's stylesheets | The variable layer, the geometry layer, the fonts, the logo and the uploaded icons |

The early form of the variable layer writes everything that depends on source order on the `body` element, so it wins although OpenProject's stylesheets come after it. The geometry layer has no early form. It overrides OpenProject's own rules for the same elements and must come last.

OpenProject writes its own favicon link right after the first hook. So on `layouts/base` the plugin writes an uploaded favicon twice, and the second one comes last. On `only_logo` pages only the first hook runs: the page then has the plugin's link and OpenProject's after it, and the browser picks. That was not looked at in a browser yet.

## The layouts

| Layout | Pages | Colours and font | Sizes |
|---|---|---|---|
| `base` | Most pages | Yes | Yes |
| `admin`, `global`, `my`, `no_menu` | Administration, global pages, My account, and sign in, sign up and lost password | Yes, they render `base` | Yes |
| `angular/angular` | Work package pages | Yes, it fills `base` | Yes |
| `only_logo` | Error pages, the external link warning, the OAuth consent page | Yes, through the early form | No |
| `mailer` | E-mail | No | No |
| `component_preview` | The component preview for developers | No | No |
| no layout | Dialogs, hover cards and other fragments | They sit inside a styled page | They sit inside a styled page |

## What cannot be reached

- **E-mail.** The mailer layouts have hooks around the content and none in the head. E-mail clients also ignore most CSS variables. E-mail keeps OpenProject's look.
- **The component preview.** It has its own head without a hook. It is a developer tool.
- **Static error files.** `404.html` and `500.html` that the web server serves from `public/` never pass through Rails.
- **The sizes on `only_logo` pages.** The top bar on an error page keeps OpenProject's height.

Layouts that other plugins bring were not looked at.

## A page must not fail because of the plugin

Both hooks read the active design system from OpenProject's settings. When that read fails, for example on an error page shown while the database is away, the plugin uses the default design system and the page renders.

To see what a page gets, view its source and look for the `style` tags whose `id` starts with `openproject-thematiq`.
