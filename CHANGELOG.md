# Changelog

All notable changes to the plugin. The numbers follow [semantic versioning](https://semver.org/); until 1.0 a minor version may change what an administrator sees.

## 0.3.0, not yet released

### Editor and switching

- A picture of the sign-in page in the editor and in the apply dialog, and "The main button follows the primary colour" per custom design system (#76).

### Bring your own house style

- A CSS file of design tokens, as thematiq writes a token set, light and dark, with references followed (#83).
- Your own CSS, off by default: an allow-list parser writes it anew from checked parts and serves it last (#83).
- Your own tokens as `--thematiq-org-<name>`, light and dark (#83); motion tokens on the plugin's own animation (#83).
- An NL Design System theme converted by thematiq's own table: built theme CSS, W3C tokens or Style Dictionary (#84).
- A font library: fonts uploaded once for every design system that names their family (#85).

### Running it in production

- Read endpoints for other apps: the catalogue, one design system, its style sheets and manifest, a contrast check, and thematiq's shell-tokens answer without a session (#77).
- A contrast report for an audit, as a page and JSON, with `rake thematiq:compliance` and `rake thematiq:dark`; two generated documents, the contrast of every shipped set and the token reference (#78).
- An environment marker on every page, from the admin page or `THEMATIQ_ENVIRONMENT_LABEL`; token deprecations, shown in the editor and listed for other apps (#79).
- The global permission "Manage the design" for a brand manager who is not an administrator (#80).
- Prometheus metrics at `/thematiq/metrics`, off until `THEMATIQ_METRICS_TOKEN` is set (#81).
- A branding package that applies itself at start: `THEMATIQ_BUNDLE_FILE` (#82).

### Scope and schedule

- A planned switch to a design system at a date and time, made by the first page after it; a lock on a project's design system (#86).
- A design system per group of people, in priority order; the sign-in page keeps the instance's (#99).

### More surfaces and components

- A brand stripe under the top bar, legal links at the end of every page and on the sign-in page, and a background behind the sign-in page (#87).
- The list under the nine-dot button in three columns (#89).
- E-mail in the house style, off by default, with the organisation's text and the legal links (#91).
- thematiq's form control and secondary button tokens on Primer's variables, and a playground of OpenProject's components in a chosen design system (#92).
- thematiq's government icon sets, 2,526 icons rebuilt by the plugin's SVG check, by name for any app (#93).
- A preview of your own component, in a frame that runs no script (#94).

### Keeping both products in step

- A gallery of thematiq's published catalogue and a notice when it is newer, behind an admin switch that is off by default: the plugin's only network connection. A nightly workflow proposes the newer catalogue as a pull request. Another product can set a person's light or dark choice by a link, off by default (#95).

### Small things

- The picker says how much of thematiq's vocabulary each shipped design system fills; the contrast report measures the status colours; selected text takes the brand colour; an upload of the Marianne typeface asks for the entitlement first (#98).

### Database

No new table since 0.2.0. Uploads take one more kind, `login_background`, and the font library uses the set id `library` in `thematiq_uploads`.

## 0.2.0, not yet released

The first version meant for others to install. It was tested on OpenProject 17.9.1 community edition, on the official Docker image `openproject/openproject:17`.

### Design systems

- A catalogue of 64 design systems generated from thematiq's token sets, with OpenProject's own three colour themes: 67 in the picker. Each set brings its logo where it may be shared (15), its font (52) and thematiq's full vocabulary of 185 values (#6, #13, #15, #24, #40, #65).
- A picker with a search field and a small picture per design system (#7, #43, #49).
- Custom design systems, up to 50: a base plus the values you change (#8, #25).
- Export and import of one design system as a file, and the Figma formats: W3C design tokens and Tokens Studio, both ways (#10, #36, #55).
- Uploads per custom design system: logo, logo for the coloured top bar, mobile logo, favicon, touch icon and up to 12 fonts, checked by content (#30, #31, #32).
- A design system per project and per module. Projects may choose only when the instance allows it, from a list (#67).

### Editor

- Groups like thematiq's tabs, a live preview, the contrast next to each colour, changed badges, reset per value, group and all (#35).
- Thematiq's full vocabulary in closed groups under "More values" (#56).
- A dark value and an opacity control per colour, and a preview as a project's or a module's design system (#68).
- "Start from your colours": a name and two colours open in the editor (#71).

### Switching safely

- The apply dialog: what changes before anything is applied, values you can keep, and a repaint without a reload (#70).
- A trial in your own session, with a banner to publish or discard (#70).
- A history of every change with who made it, and a restore after a dry run (#69).

### Running it in production

- The whole setup as one configuration file, read after a dry run, and the history as CSV (#72).
- Command line tasks, the design system from the environment variable `THEMATIQ_DESIGN_SYSTEM`, and a health report for administrators (#73).

### The shell

- The shared top bar with a row of app tiles and the app switcher with Nextcloud's apps; the two-layer project menu; Home and My page as one page (#12, #18, #28, #29, #33, #60, #61).
- The variable layer draws the roles and the vocabulary on OpenProject's and Primer's variables, light and dark; a geometry layer for the sizes of the canon (#2, #3, #27, #57 to #66).
- The sign-in page and the logo-only layout get the design system too (#16).

### Database

Three tables of the plugin's own, each with its migration: `thematiq_uploads` (#30), `thematiq_scopes` (#67) and `thematiq_changes` (#69). OpenProject runs them on start.

### Known limits

PDF exports and e-mail keep OpenProject's look. OpenProject's high contrast themes keep OpenProject's colours. Only English is translated. The `-slim` image, the packaged installation and the Enterprise edition are untested.
