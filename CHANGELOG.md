# Changelog

All notable changes to the plugin. The numbers follow [semantic versioning](https://semver.org/); until 1.0 a minor version may change what an administrator sees.

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
