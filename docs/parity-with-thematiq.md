# Parity with thematiq

This page maps what thematiq does against what this plugin does, so the work to make them equal can be planned. The rule from the owner: both must offer the same, by adding to the side that lacks something, never by removing. The plugin must also do everything OpenProject's Enterprise design page does.

First read on 12 October 2026. Brought up to date on 14 October 2026 from:

- This repository: the pull requests merged into `development`, #1 to #75, and since then each pull request updates the rows it builds. A row in an open pull request says "being built" and names it.
- thematiq `development`, for the reverse table only. thematiq's capability list was not read again: it is the one of 26 September (`openspec/parity/capabilities.json`).
- OpenProject 17.9.1 and the end-to-end suite of this repository, run on a live instance.

A row that says "in plugin" names the pull request or the file that built it. Size is only given for work still to do.

## Summary

### Capabilities of thematiq, status for the plugin

| Status | Rows |
|---|---|
| in plugin | 97 |
| being built | 0 |
| to build, as is | 22 |
| to build, adapted | 43 |
| no counterpart | 3 |
| Total | 165 |

On 12 October it was 20 in plugin, 34 being built, 51 to build as is, 57 to build adapted and 3 without a counterpart.

### What the plugin has or is getting, status for thematiq

| Status | Rows |
|---|---|
| in thematiq | 6 |
| being built | 1 |
| to build, as is | 2 |
| to build, adapted | 4 |
| no counterpart | 0 |
| Total | 13 |

### Enterprise design page

| Status | Items |
|---|---|
| has | 17 |
| being built | 0 |
| missing | 7 |
| Total | 24 |

The seven missing items are all PDF export styling, which OpenProject reads from `CustomStyle` only. [enterprise-parity.md](enterprise-parity.md) has the options.

### What to know before you set a budget

1. **65 of 165 rows still have to be built, and 0 are in open pull requests.** The rows to build are sized 46 S, 16 M and 3 L.
2. **Waves 0 and 1 are done** apart from nine rows, two of them blocked or waiting on a design (PDF export styling, the cards of the workplace layout). **Wave 2 is done** (#68 to #71, #76). **Wave 4 is partly done** (#69, #72 to #74): the audit log and its export, the configuration file, the command line, the environment, the health report and the release. The status per wave is under [Proposed order](#proposed-order).
3. **The plugin knows thematiq's full vocabulary since #54.** 185 values, of which the plugin draws the ones OpenProject has a place for. The L rows left are a full component bridge, the NL Design System converter and an icon pack.
4. **PDF export styling is blocked by OpenProject itself**, not by work: the exporters read `CustomStyle` only.
5. **Only 3 rows have no counterpart.** 4 of the "in plugin" rows are things OpenProject core already does, just as Nextcloud core does them for thematiq.

thematiq's list has 190 rows. thematiq has 161 of them, 18 of those in part. The other 29 are things thematiq decided not to build, so they are not capabilities and are left out here. Four capabilities are newer than the list and are added at the end of their group.

## Capability table

The groups are thematiq's own. Paths in the third column are under `openspec/` in thematiq unless they say otherwise. "Nextcloud core" means thematiq's list counts it as present because Nextcloud provides it.

Size is for the work still to do: S is under a day of agent work, M is a few days, L is a week or more. A row that is in the plugin or has no counterpart has no size. A row in flight has a size only when part of it has no branch yet.

### Ready-made government house styles

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `cat-rijkshuisstijl` | Apply the Dutch national government house style (Rijkshuisstijl) without designing anything | `specs/token-sets` | in plugin | `data/catalogue/shell-catalogue.json`: 64 sets generated from thematiq's token sets (#13, #40, #65) |  |
| `cat-municipal-sets` | Pick your own municipality or organisation from a list of ready-made house styles | `specs/extended-token-sets` | in plugin | The same catalogue (#13), found by name in the picker |  |
| `cat-bigcity-systems` | Use the full design systems of the large cities (Utrecht, Amsterdam, Den Haag, Rotterdam) | `specs/extended-token-sets` | in plugin | The same catalogue. Since #54 to #66 each set brings thematiq's full vocabulary; the values OpenProject has a place for are drawn, the rest is carried |  |
| `cat-vng` | Apply the VNG house style for a municipal association or shared service | `specs/vng-token-set` | in plugin | The same catalogue (#13) |  |
| `cat-lasuite` | Make the workspace match the French La Suite numerique look so a sovereign workplace bundle shows no visual seam | `specs/token-sets` | in plugin | `cunningham` is in the catalogue and is the default (#6, #40) |  |
| `cat-searchable-picker` | Find a house style by typing its name in a searchable picker that scales to hundreds of entries (thematiq has this in part) | `specs/token-set-dropdown` | in plugin | #7: a search field on the picker, run on the server. It finds custom design systems too (#43) |  |
| `cat-swatch-preview` | See a colour swatch and the primary colour of each house style before choosing it | `specs/token-set-dropdown` | in plugin | #7: a small picture of the shell per design system |  |
| `cat-stock-option` | Switch back to stock Nextcloud styling with one choice, removing every added stylesheet | `specs/theming-sync` | to build, adapted | #24 lists OpenProject's own three themes as design systems. A choice that emits no stylesheet at all is not built | S |
| `cat-completeness-badge` | See how complete a house style's token vocabulary is before you rely on it | `changes/archive/2026-10-09-token-set-vocabulary-audit` | to build, adapted | Count how many of the 18 roles a set fills. The store already keeps the refused keys | S |
| `cat-design-system-choice` | Choose between whole design systems (NL Design System, La Suite, high contrast, a soft light theme), not only colour sets | `specs/css-architecture` | to build, adapted | The plugin has one geometry layer for every set. A design system would bring its own layer. Unclear how far this should go | M |
| `cat-design-system-docs` | Follow a link from the settings page to the design system's own documentation (thematiq has this in part) | `specs/admin-settings` | to build, as is |  | S |
| `cat-community-sets` | Use community-maintained brand sets for organisations that are not a municipality | `specs/extended-token-sets` | in plugin | The same catalogue (#13) |  |
| `cat-starter-templates` | Start from a ready-made template or example theme and adapt it instead of starting blank | `specs/admin-settings` | in plugin | #8: "Customise" takes any set as the base. #71 adds "Start from your colours" |  |
| `cat-marketplace` | Download additional themes from a marketplace or gallery maintained by the vendor or community | `specs/upstream-freshness` | to build, adapted | #5 removed every connection, so a gallery means a file you fetch yourself and import (#10). See question 2 | M |
| `cat-provincial-sets` | Apply a house style for a province or water board (thematiq has this in part) | `specs/extended-token-sets` | in plugin | The same catalogue (#13) |  |
| `cat-living-token-docs` | Generate living documentation of the house style's tokens as a core feature | `specs/token-reference` | to build, as is | Generate `docs/tokens.md` from the role list | S |

### Applying and switching a theme

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `app-one-click` | Re-brand the whole workspace, its apps and the login page in one action | `specs/css-architecture` | in plugin | #7: select and Apply. With #70 Apply first shows what changes |  |
| `app-diff-dialog` | See exactly which colour values will change before you apply a new house style | `specs/token-set-apply-dialog` | in plugin | #70: the apply dialog lists every value that changes, light and dark, and applies nothing until Apply |  |
| `app-choose-what-changes` | Tick which individual values to take over when switching house style, and keep the rest | `specs/token-set-apply-dialog` | in plugin | #70: untick a value to keep its value of now. The result is a new custom design system |  |
| `app-no-reload` | Switch house style and see it repaint the page you are on without reloading | `specs/theming-sync` | in plugin | #70: Apply in the dialog swaps the plugin's style tags in place, Turbo and Angular pages alike. Other open tabs follow on their next page |  |
| `app-live-preview-shell` | Preview the house style on a mock of the real app shell (header, navigation, buttons) inside the settings page | `specs/admin-settings` | in plugin | #8, #35: the editor's preview of the shell follows typing. #70: the dialog draws the shell now and after, following the boxes. #68: the preview as a project's or a module's design system |  |
| `app-login-preview` | Preview how the login page will look before publishing | `specs/admin-settings` | in plugin | #76: a picture of the sign-in page in the editor, drawn live, and in the apply dialog |  |
| `app-trial-session` | Try a house style in your own session only, while everyone else keeps the current one | `specs/theme-preview` | in plugin | #70: a trial in the administrator's own session, on every page, for a day at most. Nobody else sees it |  |
| `app-trial-banner` | See a banner reminding you that you are looking at a trial theme, with a way back | `specs/theme-preview` | in plugin | #70: a banner at the foot of every page with Publish and Discard |  |
| `app-trial-publish` | Publish a theme you have been trialling to everyone in one step | `specs/theme-preview` | in plugin | #70: "Publish to everyone" |  |
| `app-trial-discard` | Discard a trial theme and return to what everyone else sees | `specs/theme-preview` | in plugin | #70: "Discard" |  |
| `app-component-playground` | Look at buttons, inputs, note cards, list items and the login card in each of their states while you edit the tokens they read | `specs/theme-preview` | to build, adapted | Show Primer components instead of Nextcloud ones | M |
| `app-primary-lock` | Make the brand primary colour drive every component, or deliberately let components keep their own colours | `specs/component-tokens` | in plugin | #76: "The main button follows the primary colour", per custom design system. The typed values of Action are kept for when it is off |  |
| `app-runtime-no-deploy` | Change the brand at runtime from an admin screen, without a redeployment or configuration management run | `specs/admin-settings` | in plugin | #7: the admin page changes the design at runtime |  |
| `app-scheduled-switch` | Schedule a theme change for a date, such as a campaign or a holiday look | `specs/config-portability` | to build, adapted | An OpenProject background job instead of a Nextcloud one. `test/no_network_test.rb` refuses a background job of the plugin today (#5), so that test changes | M |
| `app-rollback-history` | Roll back to an earlier version of the theme from a version history | `specs/theming-audit` | in plugin | #69: every change keeps the whole setup as a version; a restore first shows what it changes |  |
| `app-reset-core` | Reset Nextcloud's own theming values back to stock in one action | `specs/theming-sync` | to build, adapted | Reset OpenProject's own design values (`CustomStyle`, `DesignColor`). See question 6 | S |
| `app-simple-theme-switch` | Let people who are not token specialists switch between brand themes without learning the token editor | `specs/token-set-dropdown` | in plugin | #7: the picker |  |
| `app-branding-package` | Ship the tokens, templates and the theme stylesheet as one branding package that applies itself when a site is connected | `specs/theme-as-code` | to build, adapted | #72 and #73 give the configuration file and a task that imports it. Applying one at boot from a file or a variable is not built | S |

### Bringing your own brand

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `aut-upload-css` | Upload your own house style as a CSS file of design tokens | `specs/custom-token-sets` | to build, adapted | A thematiq CSS file has the full vocabulary. The plugin needs the mapping to 18 roles, which today is PHP in thematiq (`ShellTokenController`) | M |
| `aut-upload-dtcg` | Upload your own house style as a W3C Design Tokens (DTCG) JSON file | `specs/custom-token-sets` | in plugin | #36: "Upload from Figma" reads W3C design tokens and Tokens Studio files (`docs/figma.md`), the vocabulary included (#55) |  |
| `aut-upload-validate` | Get told on upload which tokens are missing or invalid before the set is accepted | `specs/custom-token-sets` | in plugin | #10: an imported file is checked strictly and refused with a reason. #36 lists what it skipped and why |  |
| `aut-upload-security` | Be protected from uploaded styles that could run script or load outside resources (unsafe content is refused with reasons) | `specs/custom-token-sets` | in plugin | `lib/open_project/thematiq/tokens/validator.rb` |  |
| `aut-custom-list-delete` | List, activate and delete the house styles you uploaded | `specs/custom-token-sets` | in plugin | #25: up to 50 custom design systems, listed, applied and deleted after a question (#44) |  |
| `aut-custom-export` | Download a house style you uploaded, to reuse or share it | `specs/custom-token-sets` | in plugin | #10: Export per design system |  |
| `aut-convert-nlds-theme` | Convert an existing NL Design System theme from its upstream token format into a working set | `specs/theming-sync` | to build, adapted | The converter is JavaScript in thematiq (`scripts/convert-nlds-theme.mjs`). Port it or run it at build time | L |
| `aut-token-editor` | Edit individual colour tokens in the browser with a colour picker | `specs/token-set-apply-dialog` | in plugin | #8, #35: a field and a colour picker per value |  |
| `aut-token-editor-tabs` | Browse the editable tokens grouped in tabs (for example primary, background, text, status) | `specs/token-editor-ui` | in plugin | #35: the four groups of thematiq's tabs, and fourteen closed groups of the vocabulary (#56) |  |
| `aut-token-reset` | Reset one edited token to its house style value without touching the others | `specs/token-editor-ui` | in plugin | #8, #35: Reset per value, per group and all |  |
| `aut-token-live` | See an edited token take effect immediately, before saving | `specs/token-editor-ui` | in plugin | #35: a script with OpenProject's nonce draws the preview while you type |  |
| `aut-overrides-persist` | Save your token edits so they survive a restart and apply to everyone (thematiq has this in part) | `specs/custom-css-overrides` | in plugin | #8: "Save and apply" keeps the name, the base and the overrides |  |
| `aut-overrides-import-export` | Export your token edits as a file and import them again on another instance | `specs/token-import-export` | in plugin | #10 and the Figma formats of #36 |  |
| `aut-custom-css` | Add your own free-form CSS rules for things tokens cannot express | `specs/custom-css-freeform` | to build, as is | Needs the sanitiser first | S |
| `aut-custom-css-sanitise` | Have free-form CSS checked on the server before it is saved, with unsafe rules refused | `specs/custom-css-freeform` | to build, as is | Port thematiq's CSS sanitiser from PHP to Ruby | M |
| `aut-component-scoped` | Change the tokens of one component type (for example buttons) without changing the global palette | `specs/component-tokens` | to build, adapted | #59 draws thematiq's button component tokens on Primer's buttons. Other components have no tokens of their own yet. See question 4 | M |
| `aut-dark-variant-auto` | Get a dark variant of your house style derived automatically | `specs/dark-mode` | in plugin | The catalogue carries the dark blocks thematiq derives (#27, #66). The plugin itself derives nothing: a custom design system keeps its base's dark values, and #68 takes dark values by hand |  |
| `aut-semantic-aliases` | Define tokens as references to other tokens so one change flows through the semantic layer (thematiq has this in part) | `specs/custom-token-sets` | to build, as is | #36 resolves references in curly braces when a Figma file is read, so the stored set holds values, not references | S |
| `aut-multi-brand-themes` | Maintain several brands or themes in one token source and switch between them | `specs/theming-audit` | in plugin | #6, #13: one catalogue file holds every set |  |
| `aut-git-sync` | Store and version the token source in a Git repository with pull requests | `specs/theme-as-code` | in plugin | `data/catalogue/shell-catalogue.json` lives in the repository |  |
| `aut-colour-only-ui` | Set a brand with nothing more than a primary colour, a background colour and a logo in a simple form | `specs/simple-brand-form` | in plugin | #71: "Start from your colours": a name, a main and a background colour open in the editor, unsaved; a logo is added once it is saved |  |
| `aut-motion-tokens` | Define motion, duration and easing as tokens of the house style | `specs/dark-mode` | to build, adapted | The vocabulary carries `animation-quick` and `animation-slow` (#54). OpenProject has no motion variables to draw them on | S |
| `aut-broken-reference-list` | See one list of every broken token reference in the house style before publishing it | `specs/custom-token-sets` | in plugin | #36: the upload report names every reference it could not follow, and why |  |
| `aut-light-dark-values` | Give a colour token separate light and dark values in the house style editor | `specs/dark-mode` | in plugin | #68: a dark field under every colour, roles and vocabulary alike. Empty keeps the base's dark value, else OpenProject's own |  |
| `aut-add-token` | Add a new design token from the house style editor without changing the theme code | `specs/theming-audit` | to build, adapted | The vocabulary widened the set to 185 values (#54), but an administrator cannot add one. See question 4 | M |
| `aut-alpha-hex` | Set colour tokens with transparency using 8-digit hex values | `specs/dark-mode` | in plugin | `lib/open_project/thematiq/tokens/validator.rb` accepts 4 and 8 digit hex. #68 adds an opacity control per colour |  |
| `aut-component-preview` | See your own components rendered with the house style tokens while you build them, before publishing | `specs/own-component-preview` | to build, adapted | With `app-component-playground` | S |
| `x-action-colour` | Give the main button a colour of its own, apart from the brand colour (newer than thematiq's list) | `changes/action-colour-token` | in plugin | `lib/open_project/thematiq/variables/generator.rb`: the `action` and `action-deep` roles |  |

### Fonts and typography

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `typ-bundled-open-fonts` | Use the house style's open fonts (Fira Sans, Inter) served from the instance itself, with no external font service | `specs/css-architecture` | in plugin | #15: 52 of the 64 sets get their font from the plugin itself |  |
| `typ-air-gapped` | Keep typography working on an air-gapped instance under the default content security policy | `specs/custom-fonts` | in plugin | `test/no_network_test.rb`; the fonts are served by the plugin (#15) |  |
| `typ-upload-font` | Upload your organisation's own licensed webfont | `specs/custom-fonts` | in plugin | #32: up to 12 font files per custom design system |  |
| `typ-font-validate` | Have an uploaded font checked for format and size before it is accepted | `specs/custom-fonts` | in plugin | #30: checked by their content |  |
| `typ-font-list-delete` | List and delete the fonts you uploaded | `specs/custom-fonts` | in plugin | #32, #44 |  |
| `typ-font-login` | Show your own font on the login page, before anyone has signed in | `specs/custom-fonts` | in plugin | #16: the sign-in page and the logo-only layout get the fonts |  |
| `typ-marianne-gated` | Enable the French State Marianne typeface only after confirming you are entitled to it | `specs/claim-accuracy` | to build, as is |  | S |
| `typ-font-tokens` | Set font family, size and weight through tokens per house style | `specs/token-editor-ui` | in plugin | #64: heading sizes and the body font from the vocabulary. Weights are carried |  |
| `typ-org-font-library` | Offer site owners a central library of approved organisation fonts to choose from (thematiq has this in part) | `specs/custom-fonts` | to build, as is | Fonts are uploaded per custom design system (#32). No shared library | S |

### Logos, icons and imagery

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `ast-logo-sync` | Set the workspace logo to your organisation's logo when you pick its house style | `specs/token-set-dropdown` | in plugin | #15: a logo ships for 15 sets and shows when the set is picked |  |
| `ast-background-sync` | Set the login background to match the house style | `specs/token-set-dropdown` | to build, adapted | OpenProject's sign-in layout (`only_logo.html.erb`) has no background image. Draw one with CSS | S |
| `ast-upload-logo` | Upload a logo of your own | Nextcloud core Theming page | in plugin | #32: logo, logo for the coloured top bar and mobile logo |  |
| `ast-upload-background` | Upload a login background image of your own | Nextcloud core Theming page | to build, adapted | With `ast-background-sync` | S |
| `ast-favicon` | Set the browser tab icon (favicon) to your organisation's | Nextcloud core Theming page | in plugin | #32: favicon and touch icon |  |
| `ast-icon-library` | Reuse a library of government icons by name from any app on the instance | `specs/icon-assets` | to build, adapted | Serve the icons from a plugin route. Unclear which OpenProject plugin would use them | M |
| `ast-org-logos` | Reuse bundled logos of government organisations by name | `specs/icon-assets` | in plugin | `data/catalogue/logos/`, only logos marked redistributable |  |
| `ast-icon-pack` | Have the icon style follow the design system you chose (for example a municipal icon pack) (thematiq has this in part) | `specs/icon-packs` | to build, adapted | A swap per region with CSS masks. `docs/shell-structure.md` (#11) found a full swap needs a fork | L |
| `ast-icon-pack-indicator` | See which icon pack is active on the settings page | `specs/icon-packs` | to build, as is | After `ast-icon-pack` | S |
| `ast-icon-contrast` | Keep icons legible against the brand colours, with contrast fixes for dark and light backgrounds (thematiq has this in part) | `specs/css-architecture` | to build, as is |  | S |
| `ast-dark-logo` | Use a separate logo for dark mode (thematiq has this in part) | `specs/compliance-evidence` | in plugin | #15, #47: the variant for dark backgrounds is used where the bar is dark, in the dark theme too |  |

### Where the theme reaches

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `sur-all-pages` | Style every Nextcloud page, including apps from other vendors, not only a single portal | `specs/css-architecture` | in plugin | `lib/open_project/thematiq/hooks.rb`, on the base layout. The sign-in layout is a separate row |  |
| `sur-conduction-apps` | Have every Conduction app pick up the house style through shared tokens | `specs/app-token-set-selection` | in plugin | `lib/open_project/thematiq/variables/generator.rb` writes `--thematiq-*` aliases any OpenProject plugin can read |  |
| `sur-login-page` | Style the login page, including before any session exists | `specs/css-architecture` | in plugin | #16: the sign-in page and every page on the logo-only layout get the early style tags |  |
| `sur-header-nav` | Style the header and app navigation bar in the house style | `specs/css-architecture` | in plugin | `stylesheets/geometry/20-top-bar.css`, `30-sidebar.css` and `lib/open_project/thematiq/variables/generator.rb` |  |
| `sur-menu-labels` | Show text labels instead of icons only in the app menu | `specs/menu-labels` | no counterpart | Nextcloud's icon-only app menu. OpenProject's menus always show text |  |
| `sur-hide-slogan` | Hide the Nextcloud slogan on the login page | `specs/hide-slogan` | no counterpart | The slogan line on Nextcloud's login page. OpenProject's sign-in page has none |  |
| `sur-public-pages` | Style public share and link pages that visitors without an account see | `specs/css-architecture` | in plugin | `hooks.rb`: pages for visitors use the same layouts. The sign-in page is checked in a browser (`signin.spec.js`) |  |
| `sur-email` | Send notification emails in the house style | `specs/email-theming` | to build, adapted | OpenProject's mail layout (`app/views/layouts/mailer.html.erb`) and its hooks, with inline colours | M |
| `sur-email-footer` | Add a compliance footer (organisation name, address, legal text) to every email | `specs/email-theming` | to build, adapted | OpenProject already has a footer text setting (`emails_footer`). Fill it, or add a block through the mail hook | S |
| `sur-component-bridge` | Map community component tokens (Utrecht) onto the workspace's own components | `specs/component-tokens` | to build, adapted | #57 to #64 draw thematiq's component tokens where Primer has a variable for them. A full bridge per component is not built. See question 4 | M |
| `sur-nc-variable-mapping` | Map every Nextcloud colour variable to a design token, so no stock colour leaks through | `specs/nextcloud-variable-mapping` | in plugin | `lib/open_project/thematiq/variables/generator.rb` maps the roles and the vocabulary onto OpenProject's and Primer's variables, light and dark (#27, #57 to #66) |  |
| `sur-error-contrast` | Keep error and status messages readable in every house style | `specs/css-architecture` | to build, as is | #57 draws the status colours of a set. Their contrast is not checked | S |
| `sur-status-tokens` | Colour success, warning and error states from the house style's status tokens | `specs/css-architecture` | in plugin | #57: the status colours of the vocabulary reach Primer's danger, success and attention |  |
| `sur-mobile-desktop-clients` | Carry the brand into the desktop and mobile sync clients (thematiq has this in part) | Nextcloud core theming capability | to build, adapted | Not checked whether OpenProject's mobile app reads any theme value | M |
| `sur-custom-domain` | Serve the branded workspace on the organisation's own domain name | Nextcloud core | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (host name setting) |  |
| `sur-footer-links` | Add legal links (privacy statement, imprint, accessibility statement) to the footer and login page | Nextcloud core Theming page | to build, adapted | OpenProject has `consent_info` and `registration_footer`, no imprint or privacy link settings. Add links through a hook | S |
| `sur-web-app-name` | Change the product name, slogan and web address shown to users | Nextcloud core Theming page | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (`Setting.app_title`). Since #29 the top bar shows app tiles instead of the name |  |
| `sur-selection-colour` | Have selected and highlighted text take the brand colour in a readable, translucent form | `specs/token-editor-ui` | to build, as is |  | S |
| `sur-generated-documents` | Have documents the system generates (letters, PDF exports, reports) carry the house style: logo, cover, footer and fonts (thematiq has this in part) | `specs/document-house-style` | to build, adapted | OpenProject's PDF exports read `CustomStyle` only, which the plugin never touches. A draft request for an extension point is in `docs/upstream/pdf-export-extension-point.md`, not sent | M |
| `sur-assistant-logo` | Show the organisation's logo as an approved mark inside the AI assistant, so users can see the assistant is the one their organisation sanctioned (thematiq has this in part) | `specs/assistant-approved-mark` | no counterpart | An AI assistant panel. The OpenProject 17.9.1 image has none in its controllers, views or modules |  |
| `sur-per-app-brand` | Give a collaboration or social app of the suite its own brand name, large and small logo and theme colour from a central brand center | `specs/per-app-theming` | to build, adapted | #67 gives each project and module its own design system, its logo included. A brand name per project is not built. See question 5 | S |
| `x-brand-stripe` | Draw an optional stripe of three colours under the top bar and on the login page (newer than thematiq's list) | `specs/brand-stripe` | to build, as is | The vocabulary carries the stripe's values (#54). Nothing draws them | S |
| `x-workplace-layout` | Draw the workplace layout: a top bar with the person's name and role, content as cards (newer than thematiq's list) | `specs/workplace-layout` | to build, as is | #12, #29, #61: the top bar; #33: Home and My page as one page. Cards on a quiet surface are not built | S |

### Scoping a theme

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `sco-per-app-exclude` | Exclude individual apps from the house style and leave them stock while you test | `specs/per-app-theming` | to build, adapted | #67 gives a module its own design system, not none. See question 5 | S |
| `sco-per-group` | Give a group of users a different house style on a shared instance | `specs/admin-settings` | to build, as is | OpenProject has groups. Resolve the set per user in the head hook | M |
| `sco-group-priority` | Decide which house style wins for a user who is in several themed groups | `specs/admin-settings` | to build, as is | With `sco-per-group` | S |
| `sco-login-unaffected` | Keep the login page on the instance-wide style while groups have their own | `specs/admin-settings` | to build, as is | With `sco-per-group` | S |
| `sco-user-choice` | Let each user choose a theme (light, dark, high contrast) for themselves | Nextcloud core Appearance settings | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (light, dark, high contrast in `app/models/user_preference.rb`). The plugin leaves it alone |  |
| `sco-user-follow-os` | Follow the user's operating system preference for dark mode and high contrast | `specs/dark-mode` | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (`sync_with_os`) |  |
| `sco-per-site` | Give each site, portal or department its own theme (thematiq has this in part) | `specs/per-group-theming` | in plugin | #67: a design system per project, inherited by subprojects, chosen by a project admin when the instance allows it |  |
| `sco-app-token-catalogue` | Let another app on the instance list the available house styles for its own picker without admin rights | `specs/app-token-set-selection` | to build, as is | A read endpoint that lists the sets | S |
| `sco-suite-wide-appearance` | Respect a user's light or dark choice from the central portal in every application of the suite (thematiq has this in part) | `specs/dark-mode` | to build, adapted | Needs one stored light or dark choice that both products read. No such link exists. See question 1 | L |

### Accessibility and contrast

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `acc-contrast-on-upload` | Get a warning about insufficient colour contrast when you upload a house style | `specs/custom-token-sets` | in plugin | The picker names the pairs with too little contrast for every design system, an imported one included (#14); the editor shows each ratio (#35) |  |
| `acc-contrast-evaluate` | Check any pair of colours against WCAG contrast from within an app | `specs/app-token-set-selection` | to build, as is |  | S |
| `acc-shipped-audit` | Rely on every shipped house style having been checked automatically for WCAG contrast | `specs/token-set-contrast-audit` | in plugin | #14: `test/contrast_test.rb` checks every set of the catalogue |  |
| `acc-contrast-report-doc` | Read a published contrast report per house style | `specs/token-set-contrast-audit` | to build, as is | After `acc-shipped-audit` | S |
| `acc-compliance-report` | Download an evidence report of the contrast of your active configuration for an audit | `specs/compliance-evidence` | to build, as is |  | M |
| `acc-compliance-cli` | Produce that compliance report from the command line | `specs/compliance-evidence` | to build, adapted | A rake task instead of an `occ` command | S |
| `acc-high-contrast-set` | Apply a maximum-contrast (WCAG AAA) theme instance-wide | `specs/high-contrast-token-set` | in plugin | `hoog-contrast` is in the catalogue (#13). OpenProject's own high contrast themes keep OpenProject's colours |  |
| `acc-forced-colors` | Cooperate with the operating system's forced colours and high-contrast modes (thematiq has this in part) | `specs/high-contrast-token-set` | in plugin | The plugin's own top bar and menus have `forced-colors` rules (`stylesheets/shell/`) |  |
| `acc-dark-mode` | Offer a dark mode of the house style | `specs/dark-mode` | in plugin | #27, #66: the dark block of a set reaches OpenProject's dark theme |  |
| `acc-dark-generate-cli` | Regenerate the dark variants from the command line after changing sets | `specs/dark-mode` | to build, adapted | A rake task instead of an `occ` command | S |
| `acc-focus-indicators` | Show visible focus indicators in the house style's colours | `specs/css-architecture` | in plugin | #58: the focus ring takes the set's focus colour, checked in `vocabulary.spec.js` |  |
| `acc-reduced-motion` | Respect a user's preference for reduced motion | `specs/dark-mode` | in plugin | The plugin's one animation, the nested menu, stops under reduced motion (`stylesheets/shell/30-nested-menu.css`) |  |
| `acc-keyboard-admin` | Operate the whole theming settings page with the keyboard alone | `specs/admin-panel-accessibility` | in plugin | Native controls throughout. Checked with axe and by keyboard in the end-to-end suite (#37, #49) |  |
| `acc-vocabulary-audit` | Check that a house style defines the full token vocabulary so nothing falls back to an unreadable default | `changes/archive/2026-10-09-token-set-vocabulary-audit` | in plugin | `lib/open_project/thematiq/tokens/token_set.rb`: a missing or refused role falls back and is listed |  |

### Governance and change control

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `gov-admin-only` | Allow only administrators to change the theme | `specs/admin-settings` | in plugin | `app/controllers/thematiq/admin_controller.rb` |  |
| `gov-delegated-role` | Delegate theme editing to a brand manager who is not a full administrator | `lib/Settings/Admin.php` | to build, adapted | A global permission in OpenProject's roles instead of Nextcloud's delegated settings | S |
| `gov-audit-log` | See who changed which theming setting, from what to what, and when | `specs/prometheus-metrics` | in plugin | #69: one row per change with who and when, in a table of the plugin's own; #72 downloads it as CSV |  |
| `gov-audit-export` | Export the theming audit log for an auditor | `specs/prometheus-metrics` | in plugin | #72: the history as CSV, with cells that look like a formula quoted |  |
| `gov-audit-append-only` | Rely on the audit log not being editable after the fact | `specs/prometheus-metrics` | in plugin | #69: the model refuses an update or a delete. Only the setup of rows older than the newest 50 is cleared |  |
| `gov-otap-bundle` | Promote the complete theme configuration from test to acceptance to production as one file | `specs/config-portability` | in plugin | #72: the whole setup as one file, projects by identifier; reading it shows what it changes first |  |
| `gov-otap-cli` | Export and import that configuration bundle from the command line for scripted deployments | `specs/config-portability` | in plugin | #73: `rake thematiq:bundle:export` and `thematiq:bundle:import`, with `DRY_RUN=1` |  |
| `gov-federated-share` | Share the theme configuration with other instances through federated configuration sharing (thematiq has this in part) | `specs/federated-config-sharing` | to build, adapted | Import the configuration file of #72 by hand. A live share needs a connection, which #5 removed. See question 1 | S |
| `gov-config-as-code` | Declare the theme in deployment configuration (for example Helm values) so it is versioned with the infrastructure | `specs/theme-as-code` | in plugin | #73: `THEMATIQ_DESIGN_SYSTEM` names the design system and wins over the admin page |  |
| `gov-app-store-install` | Install and update the theming from the platform's app store | `appinfo/info.xml` | in plugin | OpenProject has no plugin store. #74 prepares version 0.2.0 with a changelog; publishing the gem and an image is the owner's step |  |
| `gov-open-source` | Use, inspect and change the theming software under an open source licence | `specs/claim-accuracy` | in plugin | `LICENSE` (EUPL-1.2) |  |
| `gov-licence-clarity` | See the licence of every bundled font and asset stated in the product | `specs/claim-accuracy` | in plugin | #15: a licence per logo and font in the catalogue (`docs/logos-and-fonts.md`) |  |
| `gov-environment-marker` | Show a visible difference between the test and the production environment, so nobody works in the wrong one | `specs/config-portability` | to build, as is |  | S |
| `gov-token-deprecation` | Mark a token as deprecated with a severity, a replacement token and a removal date, so teams that consume the house style see it before it disappears | `specs/theming-audit` | to build, adapted | The catalogue has a `version`. Mark a role as deprecated there | S |
| `gov-lock-per-space` | Lock the organisation theme on selected sites or spaces, so their owners cannot change the branding, while other spaces keep their freedom | `specs/per-group-theming` | to build, adapted | #67: projects choose only when the instance allows it, from a list. A lock per project is not built | S |
| `gov-no-public-cdn` | Use the brand center and its branding governance without publishing brand assets on a public content delivery network | `specs/custom-fonts` | in plugin | #5: nothing in the plugin opens a connection (`test/no_network_test.rb`) |  |
| `gov-central-brand-library` | Keep one house style in a central library that many sites or departments on the instance use, edited only by the brand team | `specs/admin-settings` | in plugin | #67: the instance's design systems are the library projects choose from, and only an instance admin authors them |  |

### Staying current with upstream

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `syn-upstream-generated` | Get house styles generated from the official NL Design System token sources rather than copied by hand | `specs/token-sync-workflow` | in plugin | #13, #65: the catalogue is generated from thematiq's token sets |  |
| `syn-nightly-pr` | Receive upstream token changes as proposed updates through a nightly synchronisation (thematiq has this in part) | `specs/token-sync-workflow` | to build, adapted | A scheduled workflow in the plugin repository that regenerates the catalogue and opens a pull request | S |
| `syn-freshness-check` | Opt in to a daily check that tells you when your house style is behind the upstream tokens | `specs/upstream-freshness` | to build, adapted | A daily check needs a connection. Since #5 the plugin opens none; it could be an opt-in an admin turns on, off by default. See question 2 | S |
| `syn-freshness-dismiss` | Dismiss an upstream-update notice until the next change | `specs/upstream-freshness` | to build, adapted | With `syn-freshness-check` | S |
| `syn-freshness-status` | See when the upstream check last ran and what it found | `specs/upstream-freshness` | to build, adapted | With `syn-freshness-check` | S |
| `syn-nc-theming-sync` | Keep Nextcloud's built-in theming colours and logo in line with the chosen house style | `specs/token-set-dropdown` | to build, adapted | Keep OpenProject's own design values in line. Core only applies them with an Enterprise licence. See question 6 | S |
| `syn-nc-theming-edit` | Edit Nextcloud's built-in theming values from the same settings page | `specs/theming-sync` | to build, adapted | With `syn-nc-theming-sync` | S |
| `syn-upgrade-migration` | Keep your settings intact when the app is renamed or upgraded | `specs/app-identity` | in plugin | #5: the keys of the version with a live link are removed; the one custom set of an early version moves into the list (#25) |  |
| `aut-dtcg-colour-objects` | Read and write tokens in the stable DTCG specification, including colour values stored as objects with an explicit colour space | `specs/token-set-dtcg-export` | in plugin | #36: a colour object in sRGB is read and written |  |

### Integration and operations

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `int-capability-api` | Let clients and other apps read the active house style through the platform capabilities API | `specs/theming-capability` | to build, adapted | OpenProject has no capabilities document. Serve the active set as JSON in the shape of thematiq's `shell-tokens` version 1 | S |
| `int-token-set-api` | Let other apps list the house style catalogue through an API | `specs/app-token-set-selection` | to build, as is | With `sco-app-token-catalogue` | S |
| `int-stylesheet-manifest` | Let a page fetch the stylesheets a house style needs, in cascade order, to swap it in place | `specs/css-architecture` | to build, adapted | The plugin writes one inline style. Serve the CSS of a set from an endpoint | S |
| `int-metrics` | Monitor theming through Prometheus metrics (active set, overrides, syncs) | `specs/prometheus-metrics` | to build, adapted | The Prometheus client is in OpenProject's Gemfile. Not checked how a plugin adds a metric | M |
| `int-health` | Check that the theming app is healthy from a monitoring system | `specs/prometheus-metrics` | in plugin | #73: `GET /admin/thematiq/health` for administrators, 200 or 503 with the problems, and `rake thematiq:health` |  |
| `int-tokens-for-other-apps` | Let other apps style themselves with the same CSS variables, with no build step | `specs/css-architecture` | in plugin | `lib/open_project/thematiq/variables/generator.rb`: the `--thematiq-*` aliases |  |
| `int-no-js-overhead` | Apply the theme as pure CSS with no JavaScript cost on ordinary pages | `specs/css-architecture` | in plugin | `app/views/thematiq/hooks/_head.html.erb` inlines CSS, no script |  |
| `int-cli-set-theme` | Set the active theme from the command line | `specs/theme-cli` | in plugin | #73: `rake thematiq:apply[id]` |  |
| `int-docs-site` | Read end-user and admin documentation for every theming feature | `specs/docs-content` | in plugin | `docs/` in the repository. Markdown, no site |  |
| `int-sovereign-bundle` | Ship as part of a sovereign workplace bundle with one brand across all its components (thematiq has this in part) | `specs/token-sets` | in plugin | This is what the plugin is for (`README.md`) |  |
| `x-shell-tokens-api` | Let another product read the active house style as 18 values and a logo (newer than thematiq's list) | `docs/features/shell-tokens-api.md` | to build, adapted | #5 removed the client and every connection: network only for what an admin turns on. A set moves by file instead (#10). See question 1 | S |

## The reverse table

What the plugin has or is getting, checked against thematiq.

| What | In the plugin | Status for thematiq | Remark | Size |
|---|---|---|---|---|
| A favicon of your own | In the plugin since #32 | in thematiq | Nextcloud core's Theming page takes the upload. `lib/Service/ThemingService.php` lets a house style bring one |  |
| A touch icon for the home screen | In the plugin since #32 | to build, adapted | thematiq's list has this as decided no (`ast-mobile-logo`, 28 Sep). Not checked whether Nextcloud core derives one from the logo. See question 3 | S |
| A separate logo for small screens | In the plugin since #32: the mobile logo, below 850 px | to build, adapted | Same row in thematiq's list, `ast-mobile-logo`. See question 3 | S |
| PDF export styling: logo, cover, cover text colour, footer and fonts | Not built. OpenProject's exports read `CustomStyle` only, which the plugin never touches; a draft request for an extension point is in `docs/upstream/pdf-export-extension-point.md` | being built | `lib/Service/DocumentStyleService.php` is built. The app that renders the documents does not read it yet (`sur-generated-documents`, change `filinq/templates-house-style-from-thematiq`) |  |
| Export and import one design system as a file | In the plugin since #10, with the Figma formats of #36 | in thematiq | `specs/custom-token-sets` and `specs/token-import-export`, in thematiq's own CSS and DTCG formats |  |
| Read and write the plugin's own set file: 18 roles and a logo | In the plugin since #10, with the vocabulary since #54 | in thematiq | thematiq `c76980e3` reads the plugin's file on upload. Not checked whether thematiq writes it |  |
| A geometry layer for the shell: sizes and spacing, the same for every set | `stylesheets/geometry/` | in thematiq | `css/workplace-layout.css` and `css/header-workplace.css` (`specs/workplace-layout`). The 68 px top bar is there. The other canon sizes were not compared |  |
| A written canon of sizes that the shell is measured against | `spike/OP-TWIN-canon.md`, measured in `docs/geometry.md` | to build, as is | The canon was measured from the Nextcloud boards. No test in thematiq measures Nextcloud against it | S |
| A top bar that shows the person's name and role | In the plugin since #12, with a row of app tiles since #29 | in thematiq | `specs/workplace-layout` |  |
| An app switcher that also lists the other product's apps | In the plugin since #12 and #61: Nextcloud's apps in a second column, when an admin gives Nextcloud's address | to build, adapted | Nextcloud's app menu gets a column with OpenProject's modules. It needs OpenProject's address. The only mention of OpenProject in thematiq's code is `ShellTokenController` | M |
| A pixel-diff check of the shell against the design | In the plugin since #26: `script/pixel/` with reference images. No workflow runs it on each OpenProject release | to build, adapted | thematiq has Playwright visual tests for the playground (`tests/e2e/visual/`). None compares the shell with the canon | M |
| A search field in the picker | In the plugin since #7 | to build, as is | thematiq's own list says "in part" (`cat-searchable-picker`): the dropdown is a plain select with 47 options | S |
| A guard that notices when the host product changed underneath | In the plugin since #12: `shell/core_guard.rb` keeps checksums of 17 OpenProject files; `script/check-core.rb` and, with #73, the health report say which changed | in thematiq | `specs/nextcloud-variable-inventory` records every Nextcloud variable and fails a test when coverage drops. A different mechanism for the same risk |  |

## Enterprise design page

OpenProject 17.9.1 offers the items below under **Administration**, **Design**. Read from `app/controllers/custom_styles_controller.rb`, `app/views/custom_styles/`, `app/helpers/custom_styles_helper.rb`, `app/components/custom_styles/` and `lib/open_project/custom_styles/`.

| Tab | What the page offers | Plugin | Remark |
|---|---|---|---|
| Page | Five tabs: Interface, Branding, Default colors, PDF export styles, PDF export font | has | The picker, the editor, the Figma page and the history, as pages instead of tabs |
| Page | Color theme select with three themes: OpenProject (default), OpenProject Gray, OpenProject Navy Blue | has | #24: the three themes are design systems in the picker, with the 64 of the catalogue |
| Page | The select shows "(Custom)" once a colour is edited, and asks before a theme overwrites custom colours | has | #8, #25: an edited design system is kept as a custom one. #70: Apply first shows what changes |
| Page | A theme can bring its own logo (Gray does) | has | #15: a logo per set |
| Interface | Primary button colour | has | Role `action` (`variables/generator.rb`) |
| Interface | Accent colour, for links and highlights | has | Role `link` |
| Interface | Header background | has | Role `primary` |
| Interface | Main menu background | has | #24: the optional role `menu` |
| Interface | Main menu when selected | has | Role `primary-light` |
| Interface | Edit each of the five colours in a dialog, as a hex value, next to a swatch of the value in use | has | #35: a field, a swatch and a colour picker per value, on the editor page |
| Branding | Custom logo desktop: upload, preview, delete | has | #32 |
| Branding | Custom logo mobile: upload, preview, delete | has | #32 |
| Branding | Custom favicon: upload, preview, delete | has | #32 |
| Branding | Custom touch icon: upload, preview, delete | has | #32: a field of its own |
| Branding | Logo, mobile logo, favicon and touch icon are served without signing in, cached for a year | has | #31: `/thematiq/files/<id>`, public, by a 64 character id |
| Default colors | List, add and edit the colours used for statuses, types and priorities | has | OpenProject core. This tab is not behind the licence check (`inactive_guard: default_colors_tab?`), so the plugin needs nothing. See question 7 |
| PDF export styles | Custom export logo (PNG or JPG) | missing | OpenProject's exports read `CustomStyle` only. See `docs/enterprise-parity.md` |
| PDF export styles | Custom export cover background (PNG or JPG) | missing | Same |
| PDF export styles | Text colour on the cover, as a 3 or 6 digit hex value | missing | Same |
| PDF export styles | Custom export footer image, shown only while the feature flag `minutes_styling_meeting_pdf` is on | missing | Same |
| PDF export styles | A button that opens a demo PDF | missing | Same |
| PDF export font | Four font files: Regular, Bold, Italic, Bold Italic | missing | Same |
| PDF export font | Each file is checked: a valid TTF, under 30 MB. Each can be deleted | missing | Same |
| Reach | The colours and logo apply on every layout, the sign-in page included (`_common_head.html.erb`) | has | #16: the early style tags on the shared head reach the sign-in page and the logo-only layout |

The exports read the files straight from `CustomStyle.current` (`app/models/exports/pdf/`). How the plugin's PDF styling reaches the exports is for the lane that builds it.

## Proposed order

Each wave can be built and released without the next one. Sizes count the rows of the capability table.

| Wave | What an admin gets | Rows | Size | Needs |
|---|---|---|---|---|
| 0. Finish what is started | Land pull requests #5 to #8, then the catalogue with thematiq's sets, export and import, logo, favicon, PDF export styling and the top bar. This is the Enterprise page plus the shared shell. | 35 | 7 S, 3 M | Nothing. Every later wave needs the picker and the store from this one. |
| 1. Complete the look | Sign-in page, bundled fonts, dark values, status colours, a stock option, and the small accessibility rules (focus, forced colours, reduced motion). | 18 | 15 S, 3 M | Wave 0. An admin notices these gaps on day one: a themed app behind a stock sign-in page, and a dark theme that ignores the house style. |
| 2. Switch safely | See what changes before you apply, try a set in your own session, switch without a reload, go back to an earlier version. | 12 | 8 S, 4 M | Wave 0 for the picker. The sign-in preview needs wave 1. |
| 3. Bring your own house style | Upload CSS or DTCG tokens, convert an NL Design System theme, upload fonts, free-form CSS with a sanitiser, more roles. | 17 | 11 S, 5 M, 1 L | Wave 0 for the import. The size of this wave depends on question 4. |
| 4. Run it in production | Audit log, configuration bundle, command line tasks, configuration from the environment, compliance report, health check, metrics, read endpoints, a delegated role, a released gem. | 26 | 21 S, 5 M | Wave 0. Independent of waves 1 to 3. |
| 5. Scope and schedule | A set per group, a set per project, locks, a planned switch. | 9 | 5 S, 4 M | Wave 0, and wave 1 if groups should also get dark values. Question 5 decides what "per app" means here. |
| 6. More surfaces and components | Emails, component tokens on Primer, the playground, icon packs, the brand stripe, sign-in background, footer links. | 14 | 7 S, 4 M, 3 L | Wave 1 for the sign-in rows. Two of the three L rows here depend on question 4. |
| 7. Keep both products in step | A nightly regenerated catalogue, upstream notices, a gallery, a shared light or dark choice, OpenProject's own design values. | 11 | 8 S, 2 M, 1 L | Questions 1, 2 and 6. Do not start this wave before they are answered. |
| T. thematiq catches up | The reverse table: touch icon, mobile logo, the set file, the canon check, the app switcher column, the pixel-diff check, the picker search | 7 | 5 S, 2 M | Runs beside any wave. The set file comes first: it is what lets a set move between the products without a link. |

**Status on 14 October 2026.** Wave 0: done, apart from PDF export styling (`sur-generated-documents`, blocked by OpenProject) and the cards of `x-workplace-layout`. Wave 1: done, apart from `cat-stock-option`, `cat-completeness-badge`, `cat-design-system-docs`, `typ-marianne-gated`, `ast-icon-contrast`, `sur-error-contrast` and `sur-selection-colour`; `aut-light-dark-values` is in #68. Wave 2: done (#68 to #71, #76). Wave 3: 9 of 17 rows are in, the Figma upload and the font uploads among them; free CSS, own tokens and the NL Design System converter are not. Wave 4: 9 of 26 rows are in (#69, #72 to #74) (audit, configuration file, command line, environment, health, release); the compliance report, metrics, read endpoints and a delegated role are not started. Wave 5: 2 of 9 rows are in (#67, a design system per project); groups, locks and a planned switch are not. Waves 6 and 7: not started.

**Wave 0, finish what is started:** `cat-rijkshuisstijl`, `cat-municipal-sets`, `cat-bigcity-systems`, `cat-vng`, `cat-lasuite`, `cat-searchable-picker`, `cat-swatch-preview`, `cat-community-sets`, `cat-starter-templates`, `cat-provincial-sets`, `app-one-click`, `app-live-preview-shell`, `app-runtime-no-deploy`, `app-simple-theme-switch`, `aut-upload-validate`, `aut-custom-list-delete`, `aut-custom-export`, `aut-token-editor`, `aut-token-reset`, `aut-overrides-persist`, `aut-overrides-import-export`, `aut-multi-brand-themes`, `aut-git-sync`, `typ-air-gapped`, `ast-logo-sync`, `ast-upload-logo`, `ast-favicon`, `ast-org-logos`, `ast-dark-logo`, `acc-high-contrast-set`, `gov-licence-clarity`, `syn-upstream-generated`, `sur-generated-documents`, `gov-no-public-cdn`, `x-workplace-layout`

**Wave 1, complete the look:** `cat-stock-option`, `cat-completeness-badge`, `cat-design-system-docs`, `aut-dark-variant-auto`, `typ-bundled-open-fonts`, `typ-font-login`, `typ-marianne-gated`, `ast-icon-contrast`, `sur-login-page`, `sur-error-contrast`, `sur-status-tokens`, `acc-forced-colors`, `acc-dark-mode`, `acc-focus-indicators`, `acc-reduced-motion`, `syn-upgrade-migration`, `sur-selection-colour`, `aut-light-dark-values`

**Wave 2, switch safely:** `app-diff-dialog`, `app-choose-what-changes`, `app-no-reload`, `app-login-preview`, `app-trial-session`, `app-trial-banner`, `app-trial-publish`, `app-trial-discard`, `app-primary-lock`, `app-rollback-history`, `aut-token-live`, `aut-colour-only-ui`

**Wave 3, bring your own house style:** `aut-upload-css`, `aut-upload-dtcg`, `aut-convert-nlds-theme`, `aut-token-editor-tabs`, `aut-custom-css`, `aut-custom-css-sanitise`, `aut-semantic-aliases`, `typ-upload-font`, `typ-font-validate`, `typ-font-list-delete`, `typ-font-tokens`, `typ-org-font-library`, `acc-contrast-on-upload`, `aut-motion-tokens`, `aut-dtcg-colour-objects`, `aut-broken-reference-list`, `aut-add-token`

**Wave 4, run it in production:** `sco-app-token-catalogue`, `acc-contrast-evaluate`, `acc-shipped-audit`, `acc-contrast-report-doc`, `acc-compliance-report`, `acc-compliance-cli`, `acc-dark-generate-cli`, `acc-keyboard-admin`, `gov-delegated-role`, `gov-audit-log`, `gov-audit-export`, `gov-audit-append-only`, `gov-otap-bundle`, `gov-otap-cli`, `gov-config-as-code`, `gov-app-store-install`, `int-capability-api`, `int-token-set-api`, `int-stylesheet-manifest`, `int-metrics`, `int-health`, `int-cli-set-theme`, `gov-environment-marker`, `gov-token-deprecation`, `cat-living-token-docs`, `app-branding-package`

**Wave 5, scope and schedule:** `app-scheduled-switch`, `sco-per-app-exclude`, `sco-per-group`, `sco-group-priority`, `sco-login-unaffected`, `sco-per-site`, `gov-lock-per-space`, `sur-per-app-brand`, `gov-central-brand-library`

**Wave 6, more surfaces and components:** `cat-design-system-choice`, `app-component-playground`, `aut-component-scoped`, `ast-background-sync`, `ast-upload-background`, `ast-icon-library`, `ast-icon-pack`, `ast-icon-pack-indicator`, `sur-email`, `sur-email-footer`, `sur-component-bridge`, `sur-footer-links`, `aut-component-preview`, `x-brand-stripe`

**Wave 7, keep both products in step:** `cat-marketplace`, `app-reset-core`, `sur-mobile-desktop-clients`, `gov-federated-share`, `syn-nightly-pr`, `syn-freshness-check`, `syn-freshness-dismiss`, `syn-freshness-status`, `syn-nc-theming-sync`, `syn-nc-theming-edit`, `sco-suite-wide-appearance`

## Open questions for the owner

1. **Does one choice switch both products?** The boards say yes. PR #5 makes the plugin stand alone. *Since then: the plugin stands alone, and a design system moves between the products as a file (thematiq `c76980e3` reads the plugin's file). A live link would come under the answer to question 2. Still open whether to build one.* Choose: (a) stand alone only, an admin picks on each side and moves a set as a file, (b) stand alone by default, with an optional setting to follow thematiq, (c) always linked, as on the boards.
2. **May the plugin ever open a connection?** A gallery and an upstream notice need one. Choose: (a) never, files only, (b) only when an admin turns that feature on. *Decided: (b), off by default.*
3. **thematiq decided against 29 rows, a mobile logo and touch icon among them.** The plugin must have those two to match the Enterprise page. Choose: (a) reopen them in thematiq, (b) the plugin gets them and thematiq's decision stands. *The plugin has them since #32; thematiq's side is open.*
4. **How deep do tokens go in the plugin?** Choose: (a) stay at a small set of roles, and convert a full thematiq house style to roles on import, (b) grow to the full vocabulary and map it onto OpenProject's Primer components. Option (b) is where the L rows are. *Built as (b): the full vocabulary is in since #54; Primer's components get the values they have a variable for.*
5. **What is "an app" in OpenProject?** thematiq can exclude an app, brand an app and lock a space. Choose: (a) a project, (b) a module such as Boards or Meetings, (c) both. *Decided: (c), see `docs/design/scopes.md` and #67.*
6. **OpenProject's own design values.** thematiq keeps Nextcloud's own theming in line with the house style. Choose: (a) the plugin leaves OpenProject's design values alone, (b) it keeps them in line on installs that have an Enterprise licence.
7. **Default colors.** OpenProject offers that tab without a licence. Choose: (a) the plugin links to it, (b) the plugin repeats it on its own page.

## What this page could not determine

- thematiq's own capability list was not read again; rows thematiq added after 26 September may be missing.
- OpenProject's mobile app, an admin audit log in OpenProject itself, how a plugin adds a Prometheus metric, and whether Nextcloud derives a touch icon: still not checked.
- The thematiq side of the reverse table was only read again for the set file.
