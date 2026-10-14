# Token reference

Generated from the code by `script/generate-docs.rb`. Do not edit by hand: `test/generated_docs_test.rb` fails when this page and the code disagree.

## The roles

18 values every design system has, and `menu`, which is optional. [tokens.md](tokens.md) says how they reach the page.

| Role | Alias for other plugins | Kind | Used for |
|---|---|---|---|
| `primary` | `--thematiq-primary` | color | top bar |
| `primary-deep` | `--thematiq-primary-deep` | color | hover in the top bar, selected text |
| `primary-light` | `--thematiq-primary-light` | color | selected menu item |
| `action` | `--thematiq-action` | color | the one main button |
| `action-deep` | `--thematiq-action-deep` | color | border and hover of the main button |
| `link` | `--thematiq-link` | color | links and work package numbers |
| `accent` | `--thematiq-accent` | color | not used by OpenProject's screens yet |
| `ink` | `--thematiq-ink` | color | main text |
| `text` | `--thematiq-text` | color | not used by OpenProject's screens yet |
| `muted` | `--thematiq-muted` | color | labels and hints |
| `line` | `--thematiq-line` | color | lines between parts |
| `soft` | `--thematiq-soft` | color | hover background |
| `ground` | `--thematiq-ground` | color | page background |
| `chip` | `--thematiq-chip` | color | not used by OpenProject's screens yet |
| `field` | `--thematiq-field` | color | borders of inputs and buttons |
| `radius` | `--thematiq-radius` | length | buttons and menu items |
| `radius-lg` | `--thematiq-radius-lg` | length | inputs and panels |
| `font-family` | `--thematiq-font` | font_family | all text |
| `menu` | `--thematiq-menu` | color | background of the main menu, white when empty |

## thematiq's full vocabulary

185 values under thematiq's own names, optional. "Drawn" values reach OpenProject's or Primer's variables; "carried" values travel through export, import and Figma and are kept, but OpenProject has no place for them. A value a design system leaves out keeps OpenProject's own value.

| Key | thematiq's CSS name | Kind | Group in the editor | In OpenProject |
|---|---|---|---|---|
| `color-error` | `--nldesign-color-error` | color | status | drawn |
| `color-error-hover` | `--nldesign-color-error-hover` | color | status | drawn |
| `color-error-rgb` | `--nldesign-color-error-rgb` | rgb_triplet | status | carried |
| `color-favorite` | `--nldesign-color-favorite` | color | status | carried |
| `color-info` | `--nldesign-color-info` | color | status | carried |
| `color-info-rgb` | `--nldesign-color-info-rgb` | rgb_triplet | status | carried |
| `color-success` | `--nldesign-color-success` | color | status | drawn |
| `color-success-rgb` | `--nldesign-color-success-rgb` | rgb_triplet | status | carried |
| `color-warning` | `--nldesign-color-warning` | color | status | drawn |
| `color-warning-rgb` | `--nldesign-color-warning-rgb` | rgb_triplet | status | carried |
| `component-status-badge-error-background-color` | `--nldesign-component-status-badge-error-background-color` | color | status | drawn |
| `component-status-badge-error-color` | `--nldesign-component-status-badge-error-color` | color | status | drawn |
| `component-status-badge-info-background-color` | `--nldesign-component-status-badge-info-background-color` | color | status | drawn |
| `component-status-badge-info-color` | `--nldesign-component-status-badge-info-color` | color | status | carried |
| `component-status-badge-success-background-color` | `--nldesign-component-status-badge-success-background-color` | color | status | drawn |
| `component-status-badge-success-color` | `--nldesign-component-status-badge-success-color` | color | status | drawn |
| `component-status-badge-warning-background-color` | `--nldesign-component-status-badge-warning-background-color` | color | status | drawn |
| `component-status-badge-warning-color` | `--nldesign-component-status-badge-warning-color` | color | status | drawn |
| `color-link-hover` | `--nldesign-color-link-hover` | color | links | carried |
| `color-link-visited` | `--nldesign-color-link-visited` | color | links | carried |
| `component-link-color` | `--nldesign-component-link-color` | color | links | carried |
| `component-link-hover-color` | `--nldesign-component-link-hover-color` | color | links | carried |
| `component-link-visited-color` | `--nldesign-component-link-visited-color` | color | links | carried |
| `color-placeholder-dark` | `--nldesign-color-placeholder-dark` | color | text | carried |
| `color-placeholder-light` | `--nldesign-color-placeholder-light` | color | text | carried |
| `color-primary-light-hover` | `--nldesign-color-primary-light-hover` | color | text | carried |
| `color-primary-text` | `--nldesign-color-primary-text` | color | text | carried |
| `color-text-light` | `--nldesign-color-text-light` | color | text | drawn |
| `component-ordered-list-color` | `--nldesign-component-ordered-list-color` | color | text | carried |
| `component-paragraph-color` | `--nldesign-component-paragraph-color` | color | text | carried |
| `component-unordered-list-color` | `--nldesign-component-unordered-list-color` | color | text | carried |
| `color-background-darker` | `--nldesign-color-background-darker` | color | surfaces | carried |
| `color-surface` | `--nldesign-color-surface` | color | surfaces | carried |
| `component-content-card-shadow-color` | `--nldesign-component-content-card-shadow-color` | color | surfaces | carried |
| `component-content-surface-background-color` | `--nldesign-component-content-surface-background-color` | color | surfaces | drawn |
| `component-separator-border-color` | `--nldesign-component-separator-border-color` | color | surfaces | drawn |
| `color-focus` | `--nldesign-color-focus` | color | focus | drawn |
| `color-focus-rgb` | `--nldesign-color-focus-rgb` | rgb_triplet | focus | drawn |
| `border-radius-pill` | `--nldesign-border-radius-pill` | length | radii | drawn |
| `border-radius-rounded` | `--nldesign-border-radius-rounded` | length | radii | carried |
| `border-radius-small` | `--nldesign-border-radius-small` | length | radii | drawn |
| `color-action-text` | `--nldesign-color-action-text` | color | controls | carried |
| `color-button-primary-background` | `--nldesign-color-button-primary-background` | color | controls | carried |
| `color-button-primary-border` | `--nldesign-color-button-primary-border` | color | controls | carried |
| `color-button-primary-hover` | `--nldesign-color-button-primary-hover` | color | controls | carried |
| `color-button-primary-text` | `--nldesign-color-button-primary-text` | color | controls | carried |
| `component-button-active-background-color` | `--nldesign-component-button-active-background-color` | color | controls | drawn |
| `component-button-active-color` | `--nldesign-component-button-active-color` | color | controls | carried |
| `component-button-border-color` | `--nldesign-component-button-border-color` | color | controls | drawn |
| `component-button-color` | `--nldesign-component-button-color` | color | controls | drawn |
| `component-button-disabled-background-color` | `--nldesign-component-button-disabled-background-color` | color | controls | drawn |
| `component-button-disabled-border-color` | `--nldesign-component-button-disabled-border-color` | color | controls | drawn |
| `component-button-disabled-color` | `--nldesign-component-button-disabled-color` | color | controls | carried |
| `component-button-error-color` | `--nldesign-component-button-error-color` | color | controls | drawn |
| `component-button-focus-border-color` | `--nldesign-component-button-focus-border-color` | color | controls | carried |
| `component-button-hover-background-color` | `--nldesign-component-button-hover-background-color` | color | controls | drawn |
| `component-button-hover-border-color` | `--nldesign-component-button-hover-border-color` | color | controls | drawn |
| `component-button-hover-color` | `--nldesign-component-button-hover-color` | color | controls | carried |
| `component-button-primary-action-background-color` | `--nldesign-component-button-primary-action-background-color` | color | controls | carried |
| `component-button-primary-action-border-color` | `--nldesign-component-button-primary-action-border-color` | color | controls | carried |
| `component-button-primary-action-color` | `--nldesign-component-button-primary-action-color` | color | controls | carried |
| `component-button-primary-action-hover-background-color` | `--nldesign-component-button-primary-action-hover-background-color` | color | controls | carried |
| `component-button-primary-action-hover-color` | `--nldesign-component-button-primary-action-hover-color` | color | controls | carried |
| `component-button-secondary-action-border-color` | `--nldesign-component-button-secondary-action-border-color` | color | controls | drawn |
| `component-button-secondary-action-color` | `--nldesign-component-button-secondary-action-color` | color | controls | drawn |
| `component-button-secondary-action-hover-background-color` | `--nldesign-component-button-secondary-action-hover-background-color` | color | controls | drawn |
| `component-form-field-label-color` | `--nldesign-component-form-field-label-color` | color | forms | carried |
| `component-form-fieldset-border-color` | `--nldesign-component-form-fieldset-border-color` | color | forms | carried |
| `component-form-select-border-color` | `--nldesign-component-form-select-border-color` | color | forms | drawn |
| `component-form-select-focus-border-color` | `--nldesign-component-form-select-focus-border-color` | color | forms | carried |
| `component-textbox-background-color` | `--nldesign-component-textbox-background-color` | color | forms | drawn |
| `component-textbox-border-color` | `--nldesign-component-textbox-border-color` | color | forms | drawn |
| `component-textbox-color` | `--nldesign-component-textbox-color` | color | forms | drawn |
| `component-textbox-disabled-background-color` | `--nldesign-component-textbox-disabled-background-color` | color | forms | drawn |
| `component-textbox-disabled-color` | `--nldesign-component-textbox-disabled-color` | color | forms | drawn |
| `component-textbox-focus-border-color` | `--nldesign-component-textbox-focus-border-color` | color | forms | carried |
| `component-textbox-hover-border-color` | `--nldesign-component-textbox-hover-border-color` | color | forms | drawn |
| `component-textbox-invalid-border-color` | `--nldesign-component-textbox-invalid-border-color` | color | forms | drawn |
| `component-table-border-color` | `--nldesign-component-table-border-color` | color | table | drawn |
| `component-table-header-background-color` | `--nldesign-component-table-header-background-color` | color | table | drawn |
| `component-table-header-color` | `--nldesign-component-table-header-color` | color | table | drawn |
| `component-table-header-font-weight` | `--nldesign-component-table-header-font-weight` | font_weight | table | drawn |
| `component-table-row-hover-background-color` | `--nldesign-component-table-row-hover-background-color` | color | table | drawn |
| `body-font-family` | `--nldesign-body-font-family` | font_family | headings | drawn |
| `component-heading-1-color` | `--nldesign-component-heading-1-color` | color | headings | carried |
| `component-heading-1-font-size` | `--nldesign-component-heading-1-font-size` | length | headings | drawn |
| `component-heading-2-color` | `--nldesign-component-heading-2-color` | color | headings | carried |
| `component-heading-2-font-size` | `--nldesign-component-heading-2-font-size` | length | headings | drawn |
| `component-heading-3-color` | `--nldesign-component-heading-3-color` | color | headings | carried |
| `component-heading-3-font-size` | `--nldesign-component-heading-3-font-size` | length | headings | drawn |
| `component-heading-4-color` | `--nldesign-component-heading-4-color` | color | headings | carried |
| `component-heading-4-font-size` | `--nldesign-component-heading-4-font-size` | length | headings | drawn |
| `component-heading-5-color` | `--nldesign-component-heading-5-color` | color | headings | carried |
| `component-heading-5-font-size` | `--nldesign-component-heading-5-font-size` | length | headings | drawn |
| `component-heading-6-color` | `--nldesign-component-heading-6-color` | color | headings | carried |
| `component-heading-6-font-size` | `--nldesign-component-heading-6-font-size` | length | headings | drawn |
| `component-heading-color` | `--nldesign-component-heading-color` | color | headings | carried |
| `component-heading-font-family` | `--nldesign-component-heading-font-family` | font_family | headings | carried |
| `animation-quick` | `--nldesign-animation-quick` | duration | motion | drawn |
| `animation-slow` | `--nldesign-animation-slow` | duration | motion | drawn |
| `color-header-background` | `--nldesign-color-header-background` | color | header | carried |
| `color-header-text` | `--nldesign-color-header-text` | color | header | carried |
| `color-nav-background` | `--nldesign-color-nav-background` | color | header | carried |
| `color-nav-text` | `--nldesign-color-nav-text` | color | header | carried |
| `component-badge-background-color` | `--nldesign-component-badge-background-color` | color | header | carried |
| `component-badge-color` | `--nldesign-component-badge-color` | color | header | carried |
| `component-navigation-active-background-color` | `--nldesign-component-navigation-active-background-color` | color | header | drawn |
| `component-navigation-active-color` | `--nldesign-component-navigation-active-color` | color | header | drawn |
| `component-navigation-badge-background-color` | `--nldesign-component-navigation-badge-background-color` | color | header | drawn |
| `component-navigation-badge-color` | `--nldesign-component-navigation-badge-color` | color | header | drawn |
| `header-border-bottom` | `--nldesign-header-border-bottom` | border | header | carried |
| `header-icon-filter` | `--nldesign-header-icon-filter` | filter | header | carried |
| `header-link-color` | `--nldesign-header-link-color` | color | header | carried |
| `nav-link-color` | `--nldesign-nav-link-color` | color | header | carried |
| `brand-stripe-color-1` | `--nldesign-brand-stripe-color-1` | color | brand | drawn |
| `brand-stripe-color-2` | `--nldesign-brand-stripe-color-2` | color | brand | drawn |
| `brand-stripe-color-3` | `--nldesign-brand-stripe-color-3` | color | brand | drawn |
| `brand-stripe-height` | `--nldesign-brand-stripe-height` | length | brand | drawn |
| `brand-stripe-ratio-1` | `--nldesign-brand-stripe-ratio-1` | number | brand | drawn |
| `brand-stripe-ratio-2` | `--nldesign-brand-stripe-ratio-2` | number | brand | drawn |
| `brand-stripe-ratio-3` | `--nldesign-brand-stripe-ratio-3` | number | brand | drawn |
| `color-accent-light` | `--nldesign-color-accent-light` | color | brand | carried |
| `color-accent-text` | `--nldesign-color-accent-text` | color | brand | carried |
| `color-footer-background` | `--nldesign-color-footer-background` | color | brand | drawn |
| `color-footer-text` | `--nldesign-color-footer-text` | color | brand | drawn |
| `color-logo-background` | `--nldesign-color-logo-background` | color | brand | carried |
| `logo-bottom` | `--nldesign-logo-bottom` | offset | brand | carried |
| `logo-center` | `--nldesign-logo-center` | length | brand | carried |
| `logo-filter` | `--nldesign-logo-filter` | filter | brand | carried |
| `logo-height` | `--nldesign-logo-height` | length | brand | carried |
| `logo-inset` | `--nldesign-logo-inset` | length | brand | carried |
| `logo-top` | `--nldesign-logo-top` | offset | brand | carried |
| `logo-width` | `--nldesign-logo-width` | length | brand | carried |
| `size-lint` | `--nldesign-size-lint` | length | brand | carried |
| `size-lint-height` | `--nldesign-size-lint-height` | length | brand | carried |
| `hero-action-background-color` | `--nldesign-hero-action-background-color` | color | website | carried |
| `hero-action-color` | `--nldesign-hero-action-color` | color | website | carried |
| `hero-background-color` | `--nldesign-hero-background-color` | color | website | carried |
| `hero-body-color` | `--nldesign-hero-body-color` | color | website | carried |
| `hero-title-color` | `--nldesign-hero-title-color` | color | website | carried |
| `login-card-shadow-color` | `--nldesign-login-card-shadow-color` | color | website | carried |
| `login-secondary-border-color` | `--nldesign-login-secondary-border-color` | color | website | carried |
| `login-watermark-opacity` | `--nldesign-login-watermark-opacity` | number | website | carried |
| `website-alert-info-border-width` | `--nldesign-website-alert-info-border-width` | length | website | carried |
| `website-attention-background-color` | `--nldesign-website-attention-background-color` | color | website | carried |
| `website-attention-border-color` | `--nldesign-website-attention-border-color` | color | website | carried |
| `website-attention-color` | `--nldesign-website-attention-color` | color | website | carried |
| `website-badge-border-radius` | `--nldesign-website-badge-border-radius` | length | website | carried |
| `website-band-max-width` | `--nldesign-website-band-max-width` | size | website | carried |
| `website-border-radius` | `--nldesign-website-border-radius` | length | website | carried |
| `website-border-radius-large` | `--nldesign-website-border-radius-large` | length | website | carried |
| `website-button-font-weight` | `--nldesign-website-button-font-weight` | font_weight | website | carried |
| `website-color-text-muted` | `--nldesign-website-color-text-muted` | color | website | carried |
| `website-content-font-size` | `--nldesign-website-content-font-size` | length | website | carried |
| `website-control-border-width` | `--nldesign-website-control-border-width` | length | website | carried |
| `website-date-month-text-transform` | `--nldesign-website-date-month-text-transform` | text_transform | website | carried |
| `website-header-gutter` | `--nldesign-website-header-gutter` | length | website | carried |
| `website-header-max-width` | `--nldesign-website-header-max-width` | size | website | carried |
| `website-heading-1-font-size` | `--nldesign-website-heading-1-font-size` | length | website | carried |
| `website-heading-2-font-size` | `--nldesign-website-heading-2-font-size` | length | website | carried |
| `website-heading-3-font-size` | `--nldesign-website-heading-3-font-size` | length | website | carried |
| `website-hero-search-label-font-size` | `--nldesign-website-hero-search-label-font-size` | length | website | carried |
| `website-hero-search-label-font-weight` | `--nldesign-website-hero-search-label-font-weight` | font_weight | website | carried |
| `website-lead-font-size` | `--nldesign-website-lead-font-size` | length | website | carried |
| `website-logo-height` | `--nldesign-website-logo-height` | length | website | carried |
| `website-logo-text-size` | `--nldesign-website-logo-text-size` | length | website | carried |
| `website-logo-width` | `--nldesign-website-logo-width` | length | website | carried |
| `website-nav-current-color` | `--nldesign-website-nav-current-color` | color | website | carried |
| `website-nav-current-in-line` | `--nldesign-website-nav-current-in-line` | number | website | carried |
| `website-notice-background-color` | `--nldesign-website-notice-background-color` | color | website | carried |
| `website-notice-border-color` | `--nldesign-website-notice-border-color` | color | website | carried |
| `website-notice-border-width` | `--nldesign-website-notice-border-width` | length | website | carried |
| `website-notice-color` | `--nldesign-website-notice-color` | color | website | carried |
| `website-page-gutter` | `--nldesign-website-page-gutter` | length | website | carried |
| `website-page-max-width` | `--nldesign-website-page-max-width` | size | website | carried |
| `website-page-title-line-height` | `--nldesign-website-page-title-line-height` | number | website | carried |
| `website-page-title-size` | `--nldesign-website-page-title-size` | length | website | carried |
| `website-placeholder-background-color` | `--nldesign-website-placeholder-background-color` | color | website | carried |
| `website-step-current-background-color` | `--nldesign-website-step-current-background-color` | color | website | carried |
| `website-step-current-color` | `--nldesign-website-step-current-color` | color | website | carried |
| `website-step-done-color` | `--nldesign-website-step-done-color` | color | website | carried |
| `website-step-done-mark-color` | `--nldesign-website-step-done-mark-color` | color | website | carried |
| `website-step-marker-size` | `--nldesign-website-step-marker-size` | length | website | carried |
| `website-tab-current-color` | `--nldesign-website-tab-current-color` | color | website | carried |
| `website-tab-line-color` | `--nldesign-website-tab-line-color` | color | website | carried |
