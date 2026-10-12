# Parity with thematiq

This page maps what thematiq does against what this plugin does, so the work to make them equal can be planned. The rule from the owner: both must offer the same, by adding to the side that lacks something, never by removing. The plugin must also do everything OpenProject's Enterprise design page does.

Read on 12 October 2026 from:

- thematiq `development` at `06c92322`. The capability list is thematiq's own: `openspec/parity/capabilities.json`, which it last compared on 26 September.
- This repository: `development` at `f7355d2`, open pull requests #5 and #6, and the branch `feat/shell-top-bar`.
- The boards `OpThemePicker` and `OpThemeEditor`.
- OpenProject 17.9.1, read from the `openproject/openproject:17` image without starting it.

Nothing on this page was run in a browser.

## Summary

### Capabilities of thematiq, status for the plugin

| Status | Rows |
|---|---|
| in plugin | 20 |
| being built | 35 |
| to build, as is | 51 |
| to build, adapted | 56 |
| no counterpart | 3 |
| Total | 165 |

### What the plugin has or is getting, status for thematiq

| Status | Rows |
|---|---|
| in thematiq | 5 |
| being built | 1 |
| to build, as is | 3 |
| to build, adapted | 4 |
| no counterpart | 0 |
| Total | 13 |

### Enterprise design page

| Status | Items |
|---|---|
| has | 5 |
| being built | 13 |
| missing | 6 |
| Total | 24 |

### What to know before you set a budget

1. **107 of 165 rows still have to be built, and 35 more are in flight.** The rows to build are sized 74 S, 28 M and 5 L. Rows that share work with another row are sized S, so the total is on the high side.
2. **"Being built" is thinner than it sounds.** 17 of the 35 rows in flight lean on the picker, the editor, export and import, logo, favicon or PDF styling. None of those has a branch on the remote yet. The catalogue in PR #6 holds one set, `cunningham`. thematiq ships 63 sets, and no generator for the catalogue is on either remote.
3. **The plugin knows 18 values per house style. thematiq knows the full token vocabulary.** Three of the five L rows come from that gap: component tokens, the component bridge and the NL Design System converter. Question 4 decides whether they are built in that form.
4. **The boards and PR #5 disagree.** The boards say one choice switches both products together. PR #5 removes the link to thematiq and forbids any connection. Wave 7 waits on that choice (question 1).
5. **Only 3 rows have no counterpart.** 4 of the 20 "in plugin" rows are things OpenProject core already does, just as Nextcloud core does them for thematiq.

thematiq's list has 190 rows. thematiq has 161 of them, 18 of those in part. The other 29 are things thematiq decided not to build, so they are not capabilities and are left out here. Four capabilities are newer than the list and are added at the end of their group.

## Capability table

The groups are thematiq's own. Paths in the third column are under `openspec/` in thematiq unless they say otherwise. "Nextcloud core" means thematiq's list counts it as present because Nextcloud provides it.

Size is for the work still to do: S is under a day of agent work, M is a few days, L is a week or more. A row that is in the plugin or has no counterpart has no size. A row in flight has a size only when part of it has no branch yet.

### Ready-made government house styles

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `cat-rijkshuisstijl` | Apply the Dutch national government house style (Rijkshuisstijl) without designing anything | `specs/token-sets` | being built | PR #6. The catalogue there holds one set, so this arrives when the thematiq sets are vendored (`syn-upstream-generated`) |  |
| `cat-municipal-sets` | Pick your own municipality or organisation from a list of ready-made house styles | `specs/extended-token-sets` | being built | PR #6, with `cat-rijkshuisstijl` |  |
| `cat-bigcity-systems` | Use the full design systems of the large cities (Utrecht, Amsterdam, Den Haag, Rotterdam) | `specs/extended-token-sets` | being built | PR #6, with `cat-rijkshuisstijl`. Only the 18 shell roles carry over, not the full component layer |  |
| `cat-vng` | Apply the VNG house style for a municipal association or shared service | `specs/vng-token-set` | being built | PR #6, with `cat-rijkshuisstijl` |  |
| `cat-lasuite` | Make the workspace match the French La Suite numerique look so a sovereign workplace bundle shows no visual seam | `specs/token-sets` | being built | PR #6: `cunningham` is the one set in the catalogue and the default |  |
| `cat-searchable-picker` | Find a house style by typing its name in a searchable picker that scales to hundreds of entries (thematiq has this in part) | `specs/token-set-dropdown` | being built | PR #6 has `Catalogue#search`. The picker page has no branch pushed yet, and its board shows no search field | S |
| `cat-swatch-preview` | See a colour swatch and the primary colour of each house style before choosing it | `specs/token-set-dropdown` | being built | Picker, no branch pushed yet. Board `OpThemePicker` draws a card per set |  |
| `cat-stock-option` | Switch back to stock Nextcloud styling with one choice, removing every added stylesheet | `specs/theming-sync` | to build, as is | A choice that emits no stylesheet at all | S |
| `cat-completeness-badge` | See how complete a house style's token vocabulary is before you rely on it | `changes/archive/2026-10-09-token-set-vocabulary-audit` | to build, adapted | Count how many of the 18 roles a set fills. The store already keeps the refused keys | S |
| `cat-design-system-choice` | Choose between whole design systems (NL Design System, La Suite, high contrast, a soft light theme), not only colour sets | `specs/css-architecture` | to build, adapted | The plugin has one geometry layer for every set. A design system would bring its own layer. Unclear how far this should go | M |
| `cat-design-system-docs` | Follow a link from the settings page to the design system's own documentation (thematiq has this in part) | `specs/admin-settings` | to build, as is |  | S |
| `cat-community-sets` | Use community-maintained brand sets for organisations that are not a municipality | `specs/extended-token-sets` | being built | PR #6, with `cat-rijkshuisstijl` |  |
| `cat-starter-templates` | Start from a ready-made template or example theme and adapt it instead of starting blank | `specs/admin-settings` | being built | Editor, no branch pushed yet. Board `OpThemeEditor` starts from an existing set ("Based on Cunningham") |  |
| `cat-marketplace` | Download additional themes from a marketplace or gallery maintained by the vendor or community | `specs/upstream-freshness` | to build, adapted | PR #5 forbids any connection, so a gallery means a file you fetch yourself and import. See question 2 | M |
| `cat-provincial-sets` | Apply a house style for a province or water board (thematiq has this in part) | `specs/extended-token-sets` | being built | PR #6, with `cat-rijkshuisstijl` |  |
| `cat-living-token-docs` | Generate living documentation of the house style's tokens as a core feature | `specs/token-reference` | to build, as is | Generate `docs/tokens.md` from the role list | S |

### Applying and switching a theme

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `app-one-click` | Re-brand the whole workspace, its apps and the login page in one action | `specs/css-architecture` | being built | Picker, no branch pushed yet. PR #6 says the picker follows next | M |
| `app-diff-dialog` | See exactly which colour values will change before you apply a new house style | `specs/token-set-apply-dialog` | to build, as is |  | M |
| `app-choose-what-changes` | Tick which individual values to take over when switching house style, and keep the rest | `specs/token-set-apply-dialog` | to build, as is | With `app-diff-dialog` | S |
| `app-no-reload` | Switch house style and see it repaint the page you are on without reloading | `specs/theming-sync` | to build, adapted | Swap the inline `<style id="openproject-thematiq">` tag. OpenProject pages mix Turbo and Angular, so both need a check | M |
| `app-live-preview-shell` | Preview the house style on a mock of the real app shell (header, navigation, buttons) inside the settings page | `specs/admin-settings` | being built | Editor, no branch pushed yet. Board `OpThemeEditor` has a live preview of the shell |  |
| `app-login-preview` | Preview how the login page will look before publishing | `specs/admin-settings` | to build, as is | After `sur-login-page` | S |
| `app-trial-session` | Try a house style in your own session only, while everyone else keeps the current one | `specs/theme-preview` | to build, as is | The picker board has a Preview button. It does not say whether that is a trial in your own session | M |
| `app-trial-banner` | See a banner reminding you that you are looking at a trial theme, with a way back | `specs/theme-preview` | to build, as is | With `app-trial-session` | S |
| `app-trial-publish` | Publish a theme you have been trialling to everyone in one step | `specs/theme-preview` | to build, as is | With `app-trial-session` | S |
| `app-trial-discard` | Discard a trial theme and return to what everyone else sees | `specs/theme-preview` | to build, as is | With `app-trial-session` | S |
| `app-component-playground` | Look at buttons, inputs, note cards, list items and the login card in each of their states while you edit the tokens they read | `specs/theme-preview` | to build, adapted | Show Primer components instead of Nextcloud ones | M |
| `app-primary-lock` | Make the brand primary colour drive every component, or deliberately let components keep their own colours | `specs/component-tokens` | to build, adapted | One switch: the `action` role follows `primary`, or keeps its own value | S |
| `app-runtime-no-deploy` | Change the brand at runtime from an admin screen, without a redeployment or configuration management run | `specs/admin-settings` | being built | PR #6: the store keeps the id of the active set in OpenProject settings. Changing it needs the picker |  |
| `app-scheduled-switch` | Schedule a theme change for a date, such as a campaign or a holiday look | `specs/config-portability` | to build, adapted | An OpenProject background job instead of a Nextcloud one. `test/no_network_test.rb` in PR #5 refuses a background job today, so that test changes | M |
| `app-rollback-history` | Roll back to an earlier version of the theme from a version history | `specs/theming-audit` | to build, as is |  | M |
| `app-reset-core` | Reset Nextcloud's own theming values back to stock in one action | `specs/theming-sync` | to build, adapted | Reset OpenProject's own design values (`CustomStyle`, `DesignColor`). See question 6 | S |
| `app-simple-theme-switch` | Let people who are not token specialists switch between brand themes without learning the token editor | `specs/token-set-dropdown` | being built | Picker, no branch pushed yet |  |
| `app-branding-package` | Ship the tokens, templates and the theme stylesheet as one branding package that applies itself when a site is connected | `specs/theme-as-code` | to build, adapted | Apply a configuration bundle at boot from a file or an environment variable | M |

### Bringing your own brand

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `aut-upload-css` | Upload your own house style as a CSS file of design tokens | `specs/custom-token-sets` | to build, adapted | A thematiq CSS file has the full vocabulary. The plugin needs the mapping to 18 roles, which today is PHP in thematiq (`ShellTokenController`) | M |
| `aut-upload-dtcg` | Upload your own house style as a W3C Design Tokens (DTCG) JSON file | `specs/custom-token-sets` | to build, adapted | Same mapping as `aut-upload-css`, from DTCG JSON | M |
| `aut-upload-validate` | Get told on upload which tokens are missing or invalid before the set is accepted | `specs/custom-token-sets` | being built | PR #5 adds the strict mode for imported files. The import page has no branch pushed yet |  |
| `aut-upload-security` | Be protected from uploaded styles that could run script or load outside resources (unsafe content is refused with reasons) | `specs/custom-token-sets` | in plugin | `lib/open_project/thematiq/tokens/validator.rb` |  |
| `aut-custom-list-delete` | List, activate and delete the house styles you uploaded | `specs/custom-token-sets` | being built | Picker and import, no branch pushed yet | S |
| `aut-custom-export` | Download a house style you uploaded, to reuse or share it | `specs/custom-token-sets` | being built | Export, no branch pushed yet | S |
| `aut-convert-nlds-theme` | Convert an existing NL Design System theme from its upstream token format into a working set | `specs/theming-sync` | to build, adapted | The converter is JavaScript in thematiq (`scripts/convert-nlds-theme.mjs`). Port it or run it at build time | L |
| `aut-token-editor` | Edit individual colour tokens in the browser with a colour picker | `specs/token-set-apply-dialog` | being built | Editor, no branch pushed yet. Board `OpThemeEditor` | M |
| `aut-token-editor-tabs` | Browse the editable tokens grouped in tabs (for example primary, background, text, status) | `specs/token-editor-ui` | to build, adapted | The board edits four colours, type, radius and logo in one list. Tabs make sense once all 18 roles are editable | S |
| `aut-token-reset` | Reset one edited token to its house style value without touching the others | `specs/token-editor-ui` | to build, as is | The board has "Discard changes" for everything, not per token | S |
| `aut-token-live` | See an edited token take effect immediately, before saving | `specs/token-editor-ui` | being built | Editor, no branch pushed yet |  |
| `aut-overrides-persist` | Save your token edits so they survive a restart and apply to everyone (thematiq has this in part) | `specs/custom-css-overrides` | being built | Editor, no branch pushed yet ("Save and apply") |  |
| `aut-overrides-import-export` | Export your token edits as a file and import them again on another instance | `specs/token-import-export` | being built | Export and import, no branch pushed yet |  |
| `aut-custom-css` | Add your own free-form CSS rules for things tokens cannot express | `specs/custom-css-freeform` | to build, as is | Needs the sanitiser first | S |
| `aut-custom-css-sanitise` | Have free-form CSS checked on the server before it is saved, with unsafe rules refused | `specs/custom-css-freeform` | to build, as is | Port thematiq's CSS sanitiser from PHP to Ruby | M |
| `aut-component-scoped` | Change the tokens of one component type (for example buttons) without changing the global palette | `specs/component-tokens` | to build, adapted | OpenProject's components are Primer. Scope to Primer's component variables. See question 4 | L |
| `aut-dark-variant-auto` | Get a dark variant of your house style derived automatically | `specs/dark-mode` | to build, as is | `docs/tokens.md`: the token set has no dark values yet. Port thematiq's dark palette logic | M |
| `aut-semantic-aliases` | Define tokens as references to other tokens so one change flows through the semantic layer (thematiq has this in part) | `specs/custom-token-sets` | to build, as is | With `aut-upload-dtcg` | S |
| `aut-multi-brand-themes` | Maintain several brands or themes in one token source and switch between them | `specs/theming-audit` | being built | PR #6: one catalogue file holds every set |  |
| `aut-git-sync` | Store and version the token source in a Git repository with pull requests | `specs/theme-as-code` | being built | PR #6: `data/catalogue/shell-catalogue.json` lives in the repository |  |
| `aut-colour-only-ui` | Set a brand with nothing more than a primary colour, a background colour and a logo in a simple form | `specs/simple-brand-form` | being built | Editor, no branch pushed yet. The board is this simple form |  |
| `aut-motion-tokens` | Define motion, duration and easing as tokens of the house style | `specs/dark-mode` | to build, adapted | The 18 roles hold no motion. Add roles and use them in the geometry layer | S |
| `aut-broken-reference-list` | See one list of every broken token reference in the house style before publishing it | `specs/custom-token-sets` | to build, as is | With `aut-upload-dtcg` | S |
| `aut-light-dark-values` | Give a colour token separate light and dark values in the house style editor | `specs/dark-mode` | to build, as is | With `aut-dark-variant-auto` | S |
| `aut-add-token` | Add a new design token from the house style editor without changing the theme code | `specs/theming-audit` | to build, adapted | The validator accepts 18 known keys only. Adding a token means widening the role set. See question 4 | M |
| `aut-alpha-hex` | Set colour tokens with transparency using 8-digit hex values | `specs/dark-mode` | in plugin | `lib/open_project/thematiq/tokens/validator.rb` accepts 4 and 8 digit hex |  |
| `aut-component-preview` | See your own components rendered with the house style tokens while you build them, before publishing | `specs/own-component-preview` | to build, adapted | With `app-component-playground` | S |
| `x-action-colour` | Give the main button a colour of its own, apart from the brand colour (newer than thematiq's list) | `changes/action-colour-token` | in plugin | `lib/open_project/thematiq/variables/generator.rb`: the `action` and `action-deep` roles |  |

### Fonts and typography

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `typ-bundled-open-fonts` | Use the house style's open fonts (Fira Sans, Inter) served from the instance itself, with no external font service | `specs/css-architecture` | to build, as is | PR #6: the catalogue has a `fonts` list the loader ignores. Today only the font stack is set, no font file is served | M |
| `typ-air-gapped` | Keep typography working on an air-gapped instance under the default content security policy | `specs/custom-fonts` | being built | PR #5: `test/no_network_test.rb`. Complete once the fonts ship |  |
| `typ-upload-font` | Upload your organisation's own licensed webfont | `specs/custom-fonts` | to build, as is |  | M |
| `typ-font-validate` | Have an uploaded font checked for format and size before it is accepted | `specs/custom-fonts` | to build, as is | With `typ-upload-font` | S |
| `typ-font-list-delete` | List and delete the fonts you uploaded | `specs/custom-fonts` | to build, as is | With `typ-upload-font` | S |
| `typ-font-login` | Show your own font on the login page, before anyone has signed in | `specs/custom-fonts` | to build, adapted | After `sur-login-page` | S |
| `typ-marianne-gated` | Enable the French State Marianne typeface only after confirming you are entitled to it | `specs/claim-accuracy` | to build, as is |  | S |
| `typ-font-tokens` | Set font family, size and weight through tokens per house style | `specs/token-editor-ui` | to build, as is | Font family is in (`lib/open_project/thematiq/variables/generator.rb`). Size and weight are not tokens yet | S |
| `typ-org-font-library` | Offer site owners a central library of approved organisation fonts to choose from (thematiq has this in part) | `specs/custom-fonts` | to build, as is | With `typ-upload-font` | S |

### Logos, icons and imagery

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `ast-logo-sync` | Set the workspace logo to your organisation's logo when you pick its house style | `specs/token-set-dropdown` | being built | PR #6 carries a logo per set. Its own text: "Nothing shows a bundled logo yet" | S |
| `ast-background-sync` | Set the login background to match the house style | `specs/token-set-dropdown` | to build, adapted | OpenProject's sign-in layout (`only_logo.html.erb`) has no background image. Draw one with CSS | S |
| `ast-upload-logo` | Upload a logo of your own | Nextcloud core Theming page | being built | Logo upload, no branch pushed yet. Board `OpThemeEditor` has "Replace" | S |
| `ast-upload-background` | Upload a login background image of your own | Nextcloud core Theming page | to build, adapted | With `ast-background-sync` | S |
| `ast-favicon` | Set the browser tab icon (favicon) to your organisation's | Nextcloud core Theming page | being built | Favicon, no branch pushed yet | S |
| `ast-icon-library` | Reuse a library of government icons by name from any app on the instance | `specs/icon-assets` | to build, adapted | Serve the icons from a plugin route. Unclear which OpenProject plugin would use them | M |
| `ast-org-logos` | Reuse bundled logos of government organisations by name | `specs/icon-assets` | being built | PR #6: `data/catalogue/logos/`, only logos marked redistributable |  |
| `ast-icon-pack` | Have the icon style follow the design system you chose (for example a municipal icon pack) (thematiq has this in part) | `specs/icon-packs` | to build, adapted | A swap per region with CSS masks. `docs/shell-structure.md` on `feat/shell-top-bar` found a full swap needs a fork | L |
| `ast-icon-pack-indicator` | See which icon pack is active on the settings page | `specs/icon-packs` | to build, as is | After `ast-icon-pack` | S |
| `ast-icon-contrast` | Keep icons legible against the brand colours, with contrast fixes for dark and light backgrounds (thematiq has this in part) | `specs/css-architecture` | to build, as is |  | S |
| `ast-dark-logo` | Use a separate logo for dark mode (thematiq has this in part) | `specs/compliance-evidence` | being built | PR #6: `inverse_file` per set. Shown nowhere yet | S |

### Where the theme reaches

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `sur-all-pages` | Style every Nextcloud page, including apps from other vendors, not only a single portal | `specs/css-architecture` | in plugin | `lib/open_project/thematiq/hooks.rb`, on the base layout. The sign-in layout is a separate row |  |
| `sur-conduction-apps` | Have every Conduction app pick up the house style through shared tokens | `specs/app-token-set-selection` | in plugin | `lib/open_project/thematiq/variables/generator.rb` writes `--thematiq-*` aliases any OpenProject plugin can read |  |
| `sur-login-page` | Style the login page, including before any session exists | `specs/css-architecture` | to build, adapted | The head hook does not run on the sign-in layout. Use the hook `view_layouts_base_html_meta` in `_common_head.html.erb` | S |
| `sur-header-nav` | Style the header and app navigation bar in the house style | `specs/css-architecture` | in plugin | `stylesheets/geometry/20-top-bar.css`, `30-sidebar.css` and `lib/open_project/thematiq/variables/generator.rb` |  |
| `sur-menu-labels` | Show text labels instead of icons only in the app menu | `specs/menu-labels` | no counterpart | Nextcloud's icon-only app menu. OpenProject's menus always show text |  |
| `sur-hide-slogan` | Hide the Nextcloud slogan on the login page | `specs/hide-slogan` | no counterpart | The slogan line on Nextcloud's login page. OpenProject's sign-in page has none |  |
| `sur-public-pages` | Style public share and link pages that visitors without an account see | `specs/css-architecture` | in plugin | `hooks.rb`: pages for visitors use the same base layout. Not checked in a browser |  |
| `sur-email` | Send notification emails in the house style | `specs/email-theming` | to build, adapted | OpenProject's mail layout (`app/views/layouts/mailer.html.erb`) and its hooks, with inline colours | M |
| `sur-email-footer` | Add a compliance footer (organisation name, address, legal text) to every email | `specs/email-theming` | to build, adapted | OpenProject already has a footer text setting (`emails_footer`). Fill it, or add a block through the mail hook | S |
| `sur-component-bridge` | Map community component tokens (Utrecht) onto the workspace's own components | `specs/component-tokens` | to build, adapted | Map the community component tokens onto Primer components. See question 4 | L |
| `sur-nc-variable-mapping` | Map every Nextcloud colour variable to a design token, so no stock colour leaks through | `specs/nextcloud-variable-mapping` | in plugin | `lib/open_project/thematiq/variables/generator.rb` maps the roles onto OpenProject's and Primer's variables, light theme only. How many variables stay unmapped is not measured |  |
| `sur-error-contrast` | Keep error and status messages readable in every house style | `specs/css-architecture` | to build, as is |  | S |
| `sur-status-tokens` | Colour success, warning and error states from the house style's status tokens | `specs/css-architecture` | to build, adapted | The 18 roles hold no status colours. Add them and map them onto Primer's danger, success and attention | M |
| `sur-mobile-desktop-clients` | Carry the brand into the desktop and mobile sync clients (thematiq has this in part) | Nextcloud core theming capability | to build, adapted | Not checked whether OpenProject's mobile app reads any theme value | M |
| `sur-custom-domain` | Serve the branded workspace on the organisation's own domain name | Nextcloud core | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (host name setting) |  |
| `sur-footer-links` | Add legal links (privacy statement, imprint, accessibility statement) to the footer and login page | Nextcloud core Theming page | to build, adapted | OpenProject has `consent_info` and `registration_footer`, no imprint or privacy link settings. Add links through a hook | S |
| `sur-web-app-name` | Change the product name, slogan and web address shown to users | Nextcloud core Theming page | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (`Setting.app_title`). `feat/shell-top-bar` shows it in the top bar |  |
| `sur-selection-colour` | Have selected and highlighted text take the brand colour in a readable, translucent form | `specs/token-editor-ui` | to build, as is |  | S |
| `sur-generated-documents` | Have documents the system generates (letters, PDF exports, reports) carry the house style: logo, cover, footer and fonts (thematiq has this in part) | `specs/document-house-style` | being built | PDF export styling, no branch pushed yet | M |
| `sur-assistant-logo` | Show the organisation's logo as an approved mark inside the AI assistant, so users can see the assistant is the one their organisation sanctioned (thematiq has this in part) | `specs/assistant-approved-mark` | no counterpart | An AI assistant panel. The OpenProject 17.9.1 image has none in its controllers, views or modules |  |
| `sur-per-app-brand` | Give a collaboration or social app of the suite its own brand name, large and small logo and theme colour from a central brand center | `specs/per-app-theming` | to build, adapted | OpenProject is one app. The nearest thing is a name, logo and colour per project. See question 5 | M |
| `x-brand-stripe` | Draw an optional stripe of three colours under the top bar and on the login page (newer than thematiq's list) | `specs/brand-stripe` | to build, as is |  | S |
| `x-workplace-layout` | Draw the workplace layout: a top bar with the person's name and role, content as cards (newer than thematiq's list) | `specs/workplace-layout` | being built | Branch `feat/shell-top-bar`, no pull request yet: top bar with name and role. Cards on a quiet surface are not started | M |

### Scoping a theme

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `sco-per-app-exclude` | Exclude individual apps from the house style and leave them stock while you test | `specs/per-app-theming` | to build, adapted | Leave one OpenProject module (Boards, Meetings, Gantt) on stock styling. See question 5 | S |
| `sco-per-group` | Give a group of users a different house style on a shared instance | `specs/admin-settings` | to build, as is | OpenProject has groups. Resolve the set per user in the head hook | M |
| `sco-group-priority` | Decide which house style wins for a user who is in several themed groups | `specs/admin-settings` | to build, as is | With `sco-per-group` | S |
| `sco-login-unaffected` | Keep the login page on the instance-wide style while groups have their own | `specs/admin-settings` | to build, as is | With `sco-per-group` | S |
| `sco-user-choice` | Let each user choose a theme (light, dark, high contrast) for themselves | Nextcloud core Appearance settings | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (light, dark, high contrast in `app/models/user_preference.rb`). The plugin leaves it alone |  |
| `sco-user-follow-os` | Follow the user's operating system preference for dark mode and high contrast | `specs/dark-mode` | in plugin | OpenProject core does this, as Nextcloud core does for thematiq (`sync_with_os`) |  |
| `sco-per-site` | Give each site, portal or department its own theme (thematiq has this in part) | `specs/per-group-theming` | to build, adapted | A set per project. See question 5 | M |
| `sco-app-token-catalogue` | Let another app on the instance list the available house styles for its own picker without admin rights | `specs/app-token-set-selection` | to build, as is | A read endpoint that lists the sets | S |
| `sco-suite-wide-appearance` | Respect a user's light or dark choice from the central portal in every application of the suite (thematiq has this in part) | `specs/dark-mode` | to build, adapted | Needs one stored light or dark choice that both products read. No such link exists. See question 1 | L |

### Accessibility and contrast

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `acc-contrast-on-upload` | Get a warning about insufficient colour contrast when you upload a house style | `specs/custom-token-sets` | to build, as is | With the import | S |
| `acc-contrast-evaluate` | Check any pair of colours against WCAG contrast from within an app | `specs/app-token-set-selection` | to build, as is |  | S |
| `acc-shipped-audit` | Rely on every shipped house style having been checked automatically for WCAG contrast | `specs/token-set-contrast-audit` | to build, as is | Add a contrast check per set to `bin/test` | S |
| `acc-contrast-report-doc` | Read a published contrast report per house style | `specs/token-set-contrast-audit` | to build, as is | After `acc-shipped-audit` | S |
| `acc-compliance-report` | Download an evidence report of the contrast of your active configuration for an audit | `specs/compliance-evidence` | to build, as is |  | M |
| `acc-compliance-cli` | Produce that compliance report from the command line | `specs/compliance-evidence` | to build, adapted | A rake task instead of an `occ` command | S |
| `acc-high-contrast-set` | Apply a maximum-contrast (WCAG AAA) theme instance-wide | `specs/high-contrast-token-set` | being built | PR #6, with `cat-rijkshuisstijl`. OpenProject's own high contrast themes stay as they are |  |
| `acc-forced-colors` | Cooperate with the operating system's forced colours and high-contrast modes (thematiq has this in part) | `specs/high-contrast-token-set` | to build, as is |  | S |
| `acc-dark-mode` | Offer a dark mode of the house style | `specs/dark-mode` | to build, as is | With `aut-dark-variant-auto`. Today the dark themes keep OpenProject's colours | S |
| `acc-dark-generate-cli` | Regenerate the dark variants from the command line after changing sets | `specs/dark-mode` | to build, adapted | A rake task instead of an `occ` command | S |
| `acc-focus-indicators` | Show visible focus indicators in the house style's colours | `specs/css-architecture` | to build, as is | `lib/open_project/thematiq/variables/generator.rb` sets the focus colour. The indicator itself is not checked | S |
| `acc-reduced-motion` | Respect a user's preference for reduced motion | `specs/dark-mode` | to build, as is |  | S |
| `acc-keyboard-admin` | Operate the whole theming settings page with the keyboard alone | `specs/admin-panel-accessibility` | to build, as is | A check on the picker and the editor once they exist | S |
| `acc-vocabulary-audit` | Check that a house style defines the full token vocabulary so nothing falls back to an unreadable default | `changes/archive/2026-10-09-token-set-vocabulary-audit` | in plugin | `lib/open_project/thematiq/tokens/token_set.rb`: a missing or refused role falls back and is listed |  |

### Governance and change control

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `gov-admin-only` | Allow only administrators to change the theme | `specs/admin-settings` | in plugin | `app/controllers/thematiq/admin_controller.rb` |  |
| `gov-delegated-role` | Delegate theme editing to a brand manager who is not a full administrator | `lib/Settings/Admin.php` | to build, adapted | A global permission in OpenProject's roles instead of Nextcloud's delegated settings | S |
| `gov-audit-log` | See who changed which theming setting, from what to what, and when | `specs/prometheus-metrics` | to build, adapted | A table of the plugin's own. Not checked whether OpenProject has an admin audit log to write to | M |
| `gov-audit-export` | Export the theming audit log for an auditor | `specs/prometheus-metrics` | to build, as is | With `gov-audit-log` | S |
| `gov-audit-append-only` | Rely on the audit log not being editable after the fact | `specs/prometheus-metrics` | to build, as is | With `gov-audit-log` | S |
| `gov-otap-bundle` | Promote the complete theme configuration from test to acceptance to production as one file | `specs/config-portability` | to build, as is | More than one set: the whole configuration in one file | M |
| `gov-otap-cli` | Export and import that configuration bundle from the command line for scripted deployments | `specs/config-portability` | to build, adapted | Rake tasks instead of `occ` commands | S |
| `gov-federated-share` | Share the theme configuration with other instances through federated configuration sharing (thematiq has this in part) | `specs/federated-config-sharing` | to build, adapted | Import the bundle file by hand. A live share needs the link PR #5 removes. See question 1 | S |
| `gov-config-as-code` | Declare the theme in deployment configuration (for example Helm values) so it is versioned with the infrastructure | `specs/theme-as-code` | to build, adapted | OpenProject reads settings from `OPENPROJECT_*` environment variables. Name the set there | S |
| `gov-app-store-install` | Install and update the theming from the platform's app store | `appinfo/info.xml` | to build, adapted | OpenProject has no plugin store. Publish the gem and an image | S |
| `gov-open-source` | Use, inspect and change the theming software under an open source licence | `specs/claim-accuracy` | in plugin | `LICENSE` (EUPL-1.2) |  |
| `gov-licence-clarity` | See the licence of every bundled font and asset stated in the product | `specs/claim-accuracy` | being built | PR #6: `licence` and `redistributable` per logo. Fonts follow with `typ-bundled-open-fonts` |  |
| `gov-environment-marker` | Show a visible difference between the test and the production environment, so nobody works in the wrong one | `specs/config-portability` | to build, as is |  | S |
| `gov-token-deprecation` | Mark a token as deprecated with a severity, a replacement token and a removal date, so teams that consume the house style see it before it disappears | `specs/theming-audit` | to build, adapted | The catalogue has a `version`. Mark a role as deprecated there | S |
| `gov-lock-per-space` | Lock the organisation theme on selected sites or spaces, so their owners cannot change the branding, while other spaces keep their freedom | `specs/per-group-theming` | to build, adapted | With `sco-per-site`: lock the set on chosen projects | S |
| `gov-no-public-cdn` | Use the brand center and its branding governance without publishing brand assets on a public content delivery network | `specs/custom-fonts` | being built | PR #5: nothing in the plugin opens a connection |  |
| `gov-central-brand-library` | Keep one house style in a central library that many sites or departments on the instance use, edited only by the brand team | `specs/admin-settings` | to build, adapted | With `sco-per-site`: the catalogue is the library | S |

### Staying current with upstream

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `syn-upstream-generated` | Get house styles generated from the official NL Design System token sources rather than copied by hand | `specs/token-sync-workflow` | to build, adapted | Generate the catalogue from thematiq's token sets. No generator is on either remote | M |
| `syn-nightly-pr` | Receive upstream token changes as proposed updates through a nightly synchronisation (thematiq has this in part) | `specs/token-sync-workflow` | to build, adapted | A scheduled workflow in the plugin repository that regenerates the catalogue and opens a pull request | S |
| `syn-freshness-check` | Opt in to a daily check that tells you when your house style is behind the upstream tokens | `specs/upstream-freshness` | to build, adapted | A daily check needs a connection, which PR #5 forbids. See question 2 | S |
| `syn-freshness-dismiss` | Dismiss an upstream-update notice until the next change | `specs/upstream-freshness` | to build, adapted | With `syn-freshness-check` | S |
| `syn-freshness-status` | See when the upstream check last ran and what it found | `specs/upstream-freshness` | to build, adapted | With `syn-freshness-check` | S |
| `syn-nc-theming-sync` | Keep Nextcloud's built-in theming colours and logo in line with the chosen house style | `specs/token-set-dropdown` | to build, adapted | Keep OpenProject's own design values in line. Core only applies them with an Enterprise licence. See question 6 | S |
| `syn-nc-theming-edit` | Edit Nextcloud's built-in theming values from the same settings page | `specs/theming-sync` | to build, adapted | With `syn-nc-theming-sync` | S |
| `syn-upgrade-migration` | Keep your settings intact when the app is renamed or upgraded | `specs/app-identity` | to build, as is | PR #5 leaves a stale address and token set in the settings of an earlier install | S |
| `aut-dtcg-colour-objects` | Read and write tokens in the stable DTCG specification, including colour values stored as objects with an explicit colour space | `specs/token-set-dtcg-export` | to build, as is | With `aut-upload-dtcg` | S |

### Integration and operations

| Capability | What it does | In thematiq | Status for the plugin | Remark | Size |
|---|---|---|---|---|---|
| `int-capability-api` | Let clients and other apps read the active house style through the platform capabilities API | `specs/theming-capability` | to build, adapted | OpenProject has no capabilities document. Serve the active set as JSON in the shape of thematiq's `shell-tokens` version 1 | S |
| `int-token-set-api` | Let other apps list the house style catalogue through an API | `specs/app-token-set-selection` | to build, as is | With `sco-app-token-catalogue` | S |
| `int-stylesheet-manifest` | Let a page fetch the stylesheets a house style needs, in cascade order, to swap it in place | `specs/css-architecture` | to build, adapted | The plugin writes one inline style. Serve the CSS of a set from an endpoint | S |
| `int-metrics` | Monitor theming through Prometheus metrics (active set, overrides, syncs) | `specs/prometheus-metrics` | to build, adapted | The Prometheus client is in OpenProject's Gemfile. Not checked how a plugin adds a metric | M |
| `int-health` | Check that the theming app is healthy from a monitoring system | `specs/prometheus-metrics` | to build, adapted | Add a check next to those in `config/initializers/health_checks.rb` | S |
| `int-tokens-for-other-apps` | Let other apps style themselves with the same CSS variables, with no build step | `specs/css-architecture` | in plugin | `lib/open_project/thematiq/variables/generator.rb`: the `--thematiq-*` aliases |  |
| `int-no-js-overhead` | Apply the theme as pure CSS with no JavaScript cost on ordinary pages | `specs/css-architecture` | in plugin | `app/views/thematiq/hooks/_head.html.erb` inlines CSS, no script |  |
| `int-cli-set-theme` | Set the active theme from the command line | `specs/theme-cli` | to build, adapted | A rake task instead of an `occ` command | S |
| `int-docs-site` | Read end-user and admin documentation for every theming feature | `specs/docs-content` | in plugin | `docs/` in the repository. Markdown, no site |  |
| `int-sovereign-bundle` | Ship as part of a sovereign workplace bundle with one brand across all its components (thematiq has this in part) | `specs/token-sets` | in plugin | This is what the plugin is for (`README.md`) |  |
| `x-shell-tokens-api` | Let another product read the active house style as 18 values and a logo (newer than thematiq's list) | `docs/features/shell-tokens-api.md` | in plugin | `lib/open_project/thematiq/tokens/client.rb` on `development`. PR #5 removes it. See question 1 |  |

## The reverse table

What the plugin has or is getting, checked against thematiq.

| What | In the plugin | Status for thematiq | Remark | Size |
|---|---|---|---|---|
| A favicon of your own | Being built, no branch pushed yet | in thematiq | Nextcloud core's Theming page takes the upload. `lib/Service/ThemingService.php` lets a house style bring one |  |
| A touch icon for the home screen | Not found in any branch, pull request, doc or board | to build, adapted | thematiq's list has this as decided no (`ast-mobile-logo`, 28 Sep). Not checked whether Nextcloud core derives one from the logo. See question 3 | S |
| A separate logo for small screens | Not found in any branch, pull request, doc or board | to build, adapted | Same row in thematiq's list, `ast-mobile-logo`. See question 3 | S |
| PDF export styling: logo, cover, cover text colour, footer and fonts | Being built, no branch pushed yet | being built | `lib/Service/DocumentStyleService.php` is built. The app that renders the documents does not read it yet (`sur-generated-documents`, change `filinq/templates-house-style-from-thematiq`) |  |
| Export and import one design system as a file | Being built. PR #5 has the strict check for an imported file | in thematiq | `specs/custom-token-sets` and `specs/token-import-export`, in thematiq's own CSS and DTCG formats |  |
| Read and write the plugin's own set file: 18 roles and a logo | PR #6 defines the shape (`docs/catalogue.md`) | to build, as is | thematiq answers the same 18 roles over HTTP (`docs/features/shell-tokens-api.md`). It cannot export or import them as a file. Without this, a set made in the plugin cannot move to Nextcloud | S |
| A geometry layer for the shell: sizes and spacing, the same for every set | `stylesheets/geometry/` | in thematiq | `css/workplace-layout.css` and `css/header-workplace.css` (`specs/workplace-layout`). The 68 px top bar is there. The other canon sizes were not compared |  |
| A written canon of sizes that the shell is measured against | `spike/OP-TWIN-canon.md`, measured in `docs/geometry.md` | to build, as is | The canon was measured from the Nextcloud boards. No test in thematiq measures Nextcloud against it | S |
| A top bar that shows the person's name and role | Branch `feat/shell-top-bar`, no pull request yet | in thematiq | `specs/workplace-layout` |  |
| An app switcher that also lists the other product's apps | Branch `feat/shell-top-bar`: a fixed list of six Nextcloud apps | to build, adapted | Nextcloud's app menu gets a column with OpenProject's modules. It needs OpenProject's address. The only mention of OpenProject in thematiq's code is `ShellTokenController` | M |
| A pixel-diff check of the shell against the design | `spike/pixdiff.py` only. The README promises a check on every OpenProject release. No workflow runs it | to build, adapted | thematiq has Playwright visual tests for the playground (`tests/e2e/visual/`). None compares the shell with the canon | M |
| A search field in the picker | PR #6 has `Catalogue#search`. The board `OpThemePicker` draws no search field | to build, as is | thematiq's own list says "in part" (`cat-searchable-picker`): the dropdown is a plain select with 47 options | S |
| A guard that notices when the host product changed underneath | Branch `feat/shell-top-bar`: `shell/core_guard.rb` keeps checksums of four OpenProject files | in thematiq | `specs/nextcloud-variable-inventory` records every Nextcloud variable and fails a test when coverage drops. A different mechanism for the same risk |  |

## Enterprise design page

OpenProject 17.9.1 offers the items below under **Administration**, **Design**. Read from `app/controllers/custom_styles_controller.rb`, `app/views/custom_styles/`, `app/helpers/custom_styles_helper.rb`, `app/components/custom_styles/` and `lib/open_project/custom_styles/`.

| Tab | What the page offers | Plugin | Remark |
|---|---|---|---|
| Page | Five tabs: Interface, Branding, Default colors, PDF export styles, PDF export font | being built | One page that names the active set (PR #5). The picker and editor follow, no branch pushed yet |
| Page | Color theme select with three themes: OpenProject (default), OpenProject Gray, OpenProject Navy Blue | being built | The picker, no branch pushed yet. The board has one "OpenProject example" set. Gray and Navy Blue are in no catalogue or board |
| Page | The select shows "(Custom)" once a colour is edited, and asks before a theme overwrites custom colours | missing | The board keeps an edited set as a named set of its own, which covers the first half. No confirmation is drawn |
| Page | A theme can bring its own logo (Gray does) | being built | PR #6: a logo per set |
| Interface | Primary button colour | has | Role `action` (`variables/generator.rb`) |
| Interface | Accent colour, for links and highlights | has | Role `link` |
| Interface | Header background | has | Role `primary` |
| Interface | Main menu background | missing | The generator fixes it to white. No role holds it |
| Interface | Main menu when selected | has | Role `primary-light` |
| Interface | Edit each of the five colours in a dialog, as a hex value, next to a swatch of the value in use | being built | The editor, no branch pushed yet. The board has pickers for Primary, Action, Ink and Lines |
| Branding | Custom logo desktop: upload, preview, delete | being built | No branch pushed yet. The board has "Replace" for an SVG logo |
| Branding | Custom logo mobile: upload, preview, delete | missing | Not found in any branch, pull request, doc or board |
| Branding | Custom favicon: upload, preview, delete | being built | Named in the programme brief. No branch pushed yet |
| Branding | Custom touch icon: upload, preview, delete | missing | Not found anywhere. In the 17.9.1 view this upload posts to the favicon field (`_branding.html.erb`), so do not copy the form as is |
| Branding | Logo, mobile logo, favicon and touch icon are served without signing in, cached for a year | missing | Needed for the sign-in page. PR #6 knows the path of a bundled logo. No route serves it |
| Default colors | List, add and edit the colours used for statuses, types and priorities | has | OpenProject core. This tab is not behind the licence check (`inactive_guard: default_colors_tab?`), so the plugin needs nothing. See question 7 |
| PDF export styles | Custom export logo (PNG or JPG) | being built | PDF export styling, named in the programme brief. No branch pushed yet |
| PDF export styles | Custom export cover background (PNG or JPG) | being built | Same |
| PDF export styles | Text colour on the cover, as a 3 or 6 digit hex value | being built | Same |
| PDF export styles | Custom export footer image, shown only while the feature flag `minutes_styling_meeting_pdf` is on | being built | Same |
| PDF export styles | A button that opens a demo PDF | being built | Same |
| PDF export font | Four font files: Regular, Bold, Italic, Bold Italic | being built | Same |
| PDF export font | Each file is checked: a valid TTF, under 30 MB. Each can be deleted | being built | Same |
| Reach | The colours and logo apply on every layout, the sign-in page included (`_common_head.html.erb`) | missing | The plugin's head hook runs on the base layout only (`docs/development.md`). Row `sur-login-page` |

The exports read the files straight from `CustomStyle.current` (`app/models/exports/pdf/`). How the plugin's PDF styling reaches the exports is for the lane that builds it.

## Proposed order

Each wave can be built and released without the next one. Sizes count the rows of the capability table.

| Wave | What an admin gets | Rows | Size | Needs |
|---|---|---|---|---|
| 0. Finish what is started | The catalogue with thematiq's sets, the picker, the editor, export and import, logo, favicon, PDF export styling and the top bar. This is the Enterprise page plus the shared shell. | 36 | 7 S, 5 M | Nothing. Every later wave needs the picker and the store from this one. |
| 1. Complete the look | Sign-in page, bundled fonts, dark values, status colours, a stock option, and the small accessibility rules (focus, forced colours, reduced motion). | 18 | 15 S, 3 M | Wave 0. An admin notices these gaps on day one: a themed app behind a stock sign-in page, and a dark theme that ignores the house style. |
| 2. Switch safely | See what changes before you apply, try a set in your own session, switch without a reload, go back to an earlier version. | 11 | 7 S, 4 M | Wave 0 for the picker. The sign-in preview needs wave 1. |
| 3. Bring your own house style | Upload CSS or DTCG tokens, convert an NL Design System theme, upload fonts, free-form CSS with a sanitiser, more roles. | 17 | 11 S, 5 M, 1 L | Wave 0 for the import. The size of this wave depends on question 4. |
| 4. Run it in production | Audit log, configuration bundle, command line tasks, configuration from the environment, compliance report, health check, metrics, read endpoints, a delegated role, a released gem. | 26 | 21 S, 5 M | Wave 0. Independent of waves 1 to 3. |
| 5. Scope and schedule | A set per group, a set per project, locks, a planned switch. | 9 | 5 S, 4 M | Wave 0, and wave 1 if groups should also get dark values. Question 5 decides what "per app" means here. |
| 6. More surfaces and components | Emails, component tokens on Primer, the playground, icon packs, the brand stripe, sign-in background, footer links. | 14 | 7 S, 4 M, 3 L | Wave 1 for the sign-in rows. Two of the three L rows here depend on question 4. |
| 7. Keep both products in step | A nightly regenerated catalogue, upstream notices, a gallery, a shared light or dark choice, OpenProject's own design values. | 11 | 8 S, 2 M, 1 L | Questions 1, 2 and 6. Do not start this wave before they are answered. |
| T. thematiq catches up | The reverse table: touch icon, mobile logo, the set file, the canon check, the app switcher column, the pixel-diff check, the picker search | 7 | 5 S, 2 M | Runs beside any wave. The set file comes first: it is what lets a set move between the products without a link. |

**Wave 0, finish what is started:** `cat-rijkshuisstijl`, `cat-municipal-sets`, `cat-bigcity-systems`, `cat-vng`, `cat-lasuite`, `cat-searchable-picker`, `cat-swatch-preview`, `cat-community-sets`, `cat-starter-templates`, `cat-provincial-sets`, `app-one-click`, `app-live-preview-shell`, `app-runtime-no-deploy`, `app-simple-theme-switch`, `aut-upload-validate`, `aut-custom-list-delete`, `aut-custom-export`, `aut-token-editor`, `aut-token-live`, `aut-overrides-persist`, `aut-overrides-import-export`, `aut-multi-brand-themes`, `aut-git-sync`, `aut-colour-only-ui`, `typ-air-gapped`, `ast-logo-sync`, `ast-upload-logo`, `ast-favicon`, `ast-org-logos`, `ast-dark-logo`, `acc-high-contrast-set`, `gov-licence-clarity`, `syn-upstream-generated`, `sur-generated-documents`, `gov-no-public-cdn`, `x-workplace-layout`

**Wave 1, complete the look:** `cat-stock-option`, `cat-completeness-badge`, `cat-design-system-docs`, `aut-dark-variant-auto`, `typ-bundled-open-fonts`, `typ-font-login`, `typ-marianne-gated`, `ast-icon-contrast`, `sur-login-page`, `sur-error-contrast`, `sur-status-tokens`, `acc-forced-colors`, `acc-dark-mode`, `acc-focus-indicators`, `acc-reduced-motion`, `syn-upgrade-migration`, `sur-selection-colour`, `aut-light-dark-values`

**Wave 2, switch safely:** `app-diff-dialog`, `app-choose-what-changes`, `app-no-reload`, `app-login-preview`, `app-trial-session`, `app-trial-banner`, `app-trial-publish`, `app-trial-discard`, `app-primary-lock`, `app-rollback-history`, `aut-token-reset`

**Wave 3, bring your own house style:** `aut-upload-css`, `aut-upload-dtcg`, `aut-convert-nlds-theme`, `aut-token-editor-tabs`, `aut-custom-css`, `aut-custom-css-sanitise`, `aut-semantic-aliases`, `typ-upload-font`, `typ-font-validate`, `typ-font-list-delete`, `typ-font-tokens`, `typ-org-font-library`, `acc-contrast-on-upload`, `aut-motion-tokens`, `aut-dtcg-colour-objects`, `aut-broken-reference-list`, `aut-add-token`

**Wave 4, run it in production:** `sco-app-token-catalogue`, `acc-contrast-evaluate`, `acc-shipped-audit`, `acc-contrast-report-doc`, `acc-compliance-report`, `acc-compliance-cli`, `acc-dark-generate-cli`, `acc-keyboard-admin`, `gov-delegated-role`, `gov-audit-log`, `gov-audit-export`, `gov-audit-append-only`, `gov-otap-bundle`, `gov-otap-cli`, `gov-config-as-code`, `gov-app-store-install`, `int-capability-api`, `int-token-set-api`, `int-stylesheet-manifest`, `int-metrics`, `int-health`, `int-cli-set-theme`, `gov-environment-marker`, `gov-token-deprecation`, `cat-living-token-docs`, `app-branding-package`

**Wave 5, scope and schedule:** `app-scheduled-switch`, `sco-per-app-exclude`, `sco-per-group`, `sco-group-priority`, `sco-login-unaffected`, `sco-per-site`, `gov-lock-per-space`, `sur-per-app-brand`, `gov-central-brand-library`

**Wave 6, more surfaces and components:** `cat-design-system-choice`, `app-component-playground`, `aut-component-scoped`, `ast-background-sync`, `ast-upload-background`, `ast-icon-library`, `ast-icon-pack`, `ast-icon-pack-indicator`, `sur-email`, `sur-email-footer`, `sur-component-bridge`, `sur-footer-links`, `aut-component-preview`, `x-brand-stripe`

**Wave 7, keep both products in step:** `cat-marketplace`, `app-reset-core`, `sur-mobile-desktop-clients`, `gov-federated-share`, `syn-nightly-pr`, `syn-freshness-check`, `syn-freshness-dismiss`, `syn-freshness-status`, `syn-nc-theming-sync`, `syn-nc-theming-edit`, `sco-suite-wide-appearance`

## Open questions for the owner

1. **Does one choice switch both products?** The boards say yes. PR #5 makes the plugin stand alone. Choose: (a) stand alone only, an admin picks on each side and moves a set as a file, (b) stand alone by default, with an optional setting to follow thematiq, (c) always linked, as on the boards.
2. **May the plugin ever open a connection?** A gallery and an upstream notice need one. Choose: (a) never, files only, (b) only when an admin turns that feature on.
3. **thematiq decided against 29 rows, a mobile logo and touch icon among them.** The plugin must have those two to match the Enterprise page. Choose: (a) reopen them in thematiq, (b) the plugin gets them and thematiq's decision stands.
4. **How deep do tokens go in the plugin?** Choose: (a) stay at a small set of roles, and convert a full thematiq house style to roles on import, (b) grow to the full vocabulary and map it onto OpenProject's Primer components. Option (b) is where the L rows are.
5. **What is "an app" in OpenProject?** thematiq can exclude an app, brand an app and lock a space. Choose: (a) a project, (b) a module such as Boards or Meetings, (c) both.
6. **OpenProject's own design values.** thematiq keeps Nextcloud's own theming in line with the house style. Choose: (a) the plugin leaves OpenProject's design values alone, (b) it keeps them in line on installs that have an Enterprise licence.
7. **Default colors.** OpenProject offers that tab without a licence. Choose: (a) the plugin links to it, (b) the plugin repeats it on its own page.

## What this page could not determine

- Whether the editor, export and import, logo, favicon and PDF styling exist anywhere. They have no branch or pull request on the remote. Their "being built" status rests on the programme brief and the boards.
- Whether a mobile logo and a touch icon are planned for the plugin. Nothing names them.
- Whether the catalogue generator exists. PR #6 says it was not there when the catalogue was built.
- Rows marked "not checked" in the tables: OpenProject's mobile app, an admin audit log in OpenProject, how a plugin adds a metric, and whether Nextcloud derives a touch icon.
- thematiq's list was read on 26 September. Capabilities added after that date may be missing beyond the four found.
