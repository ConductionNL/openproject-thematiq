# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Tokens
      # thematiq's full vocabulary: every token name its token sets write, without the "--nldesign-" prefix,
      # and the kind of value each one takes. A token set holds these in an optional flat "vocabulary" block
      # beside its "tokens". See docs/design/full-vocabulary.md.
      #
      # Read from thematiq's css/tokens/ (light and dark files, 65 sets) on 13 October 2026. Left out on purpose:
      #   - the seventeen names that are roles: they live in "tokens", under the role's name (ROLE_NAMES).
      #   - names whose value is an address or an image: logo-url, brand-stripe-image, brand-stripe-image-inverse,
      #     hero-decoration-image, login-watermark-image. A logo is a file in the plugin, never an address.
      #   - hero-image-clip-path: a shape with calc(), which no allow-list here reads safely.
      #
      # A value no set fills keeps OpenProject's own value. Nothing in this list is derived from the roles.
      # The plugin draws some keys (DRAWN) and carries the rest through export, import and Figma untouched.
      module Vocabulary
        PREFIX = "--nldesign-"

        KINDS = {
          "animation-quick" => :duration, "animation-slow" => :duration, "body-font-family" => :font_family,
          "border-radius-pill" => :length, "border-radius-rounded" => :length, "border-radius-small" => :length,
          "brand-stripe-color-1" => :color, "brand-stripe-color-2" => :color, "brand-stripe-color-3" => :color,
          "brand-stripe-height" => :length, "brand-stripe-ratio-1" => :number, "brand-stripe-ratio-2" => :number,
          "brand-stripe-ratio-3" => :number, "color-accent-light" => :color, "color-accent-text" => :color,
          "color-action-text" => :color, "color-background-darker" => :color, "color-button-primary-background" => :color,
          "color-button-primary-border" => :color, "color-button-primary-hover" => :color,
          "color-button-primary-text" => :color, "color-error" => :color, "color-error-hover" => :color,
          "color-error-rgb" => :rgb_triplet, "color-favorite" => :color, "color-focus" => :color,
          "color-focus-rgb" => :rgb_triplet, "color-footer-background" => :color, "color-footer-text" => :color,
          "color-header-background" => :color, "color-header-text" => :color, "color-info" => :color,
          "color-info-rgb" => :rgb_triplet, "color-link-hover" => :color, "color-link-visited" => :color,
          "color-logo-background" => :color, "color-nav-background" => :color, "color-nav-text" => :color,
          "color-placeholder-dark" => :color, "color-placeholder-light" => :color, "color-primary-light-hover" => :color,
          "color-primary-text" => :color, "color-success" => :color, "color-success-rgb" => :rgb_triplet,
          "color-surface" => :color, "color-text-light" => :color, "color-warning" => :color,
          "color-warning-rgb" => :rgb_triplet, "component-badge-background-color" => :color, "component-badge-color" => :color,
          "component-button-active-background-color" => :color, "component-button-active-color" => :color,
          "component-button-border-color" => :color, "component-button-color" => :color,
          "component-button-disabled-background-color" => :color, "component-button-disabled-border-color" => :color,
          "component-button-disabled-color" => :color, "component-button-error-color" => :color,
          "component-button-focus-border-color" => :color, "component-button-hover-background-color" => :color,
          "component-button-hover-border-color" => :color, "component-button-hover-color" => :color,
          "component-button-primary-action-background-color" => :color,
          "component-button-primary-action-border-color" => :color, "component-button-primary-action-color" => :color,
          "component-button-primary-action-hover-background-color" => :color,
          "component-button-primary-action-hover-color" => :color, "component-button-secondary-action-border-color" => :color,
          "component-button-secondary-action-color" => :color,
          "component-button-secondary-action-hover-background-color" => :color,
          "component-content-card-shadow-color" => :color, "component-content-surface-background-color" => :color,
          "component-form-field-label-color" => :color, "component-form-fieldset-border-color" => :color,
          "component-form-select-border-color" => :color, "component-form-select-focus-border-color" => :color,
          "component-heading-1-color" => :color, "component-heading-1-font-size" => :length,
          "component-heading-2-color" => :color, "component-heading-2-font-size" => :length,
          "component-heading-3-color" => :color, "component-heading-3-font-size" => :length,
          "component-heading-4-color" => :color, "component-heading-4-font-size" => :length,
          "component-heading-5-color" => :color, "component-heading-5-font-size" => :length,
          "component-heading-6-color" => :color, "component-heading-6-font-size" => :length,
          "component-heading-color" => :color, "component-heading-font-family" => :font_family,
          "component-link-color" => :color, "component-link-hover-color" => :color, "component-link-visited-color" => :color,
          "component-navigation-active-background-color" => :color, "component-navigation-active-color" => :color,
          "component-navigation-badge-background-color" => :color, "component-navigation-badge-color" => :color,
          "component-ordered-list-color" => :color, "component-paragraph-color" => :color,
          "component-separator-border-color" => :color, "component-status-badge-error-background-color" => :color,
          "component-status-badge-error-color" => :color, "component-status-badge-info-background-color" => :color,
          "component-status-badge-info-color" => :color, "component-status-badge-success-background-color" => :color,
          "component-status-badge-success-color" => :color, "component-status-badge-warning-background-color" => :color,
          "component-status-badge-warning-color" => :color, "component-table-border-color" => :color,
          "component-table-header-background-color" => :color, "component-table-header-color" => :color,
          "component-table-header-font-weight" => :font_weight, "component-table-row-hover-background-color" => :color,
          "component-textbox-background-color" => :color, "component-textbox-border-color" => :color,
          "component-textbox-color" => :color, "component-textbox-disabled-background-color" => :color,
          "component-textbox-disabled-color" => :color, "component-textbox-focus-border-color" => :color,
          "component-textbox-hover-border-color" => :color, "component-textbox-invalid-border-color" => :color,
          "component-unordered-list-color" => :color, "header-border-bottom" => :border, "header-icon-filter" => :filter,
          "header-link-color" => :color, "hero-action-background-color" => :color, "hero-action-color" => :color,
          "hero-background-color" => :color, "hero-body-color" => :color, "hero-title-color" => :color,
          "login-card-shadow-color" => :color, "login-secondary-border-color" => :color, "login-watermark-opacity" => :number,
          "logo-bottom" => :offset, "logo-center" => :length, "logo-filter" => :filter, "logo-height" => :length,
          "logo-inset" => :length, "logo-top" => :offset, "logo-width" => :length, "nav-link-color" => :color,
          "size-lint" => :length, "size-lint-height" => :length, "website-alert-info-border-width" => :length,
          "website-attention-background-color" => :color, "website-attention-border-color" => :color,
          "website-attention-color" => :color, "website-badge-border-radius" => :length, "website-band-max-width" => :size,
          "website-border-radius" => :length, "website-border-radius-large" => :length,
          "website-button-font-weight" => :font_weight, "website-color-text-muted" => :color,
          "website-content-font-size" => :length, "website-control-border-width" => :length,
          "website-date-month-text-transform" => :text_transform, "website-header-gutter" => :length,
          "website-header-max-width" => :size, "website-heading-1-font-size" => :length,
          "website-heading-2-font-size" => :length, "website-heading-3-font-size" => :length,
          "website-hero-search-label-font-size" => :length, "website-hero-search-label-font-weight" => :font_weight,
          "website-lead-font-size" => :length, "website-logo-height" => :length, "website-logo-text-size" => :length,
          "website-logo-width" => :length, "website-nav-current-color" => :color, "website-nav-current-in-line" => :number,
          "website-notice-background-color" => :color, "website-notice-border-color" => :color,
          "website-notice-border-width" => :length, "website-notice-color" => :color, "website-page-gutter" => :length,
          "website-page-max-width" => :size, "website-page-title-line-height" => :number,
          "website-page-title-size" => :length, "website-placeholder-background-color" => :color,
          "website-step-current-background-color" => :color, "website-step-current-color" => :color,
          "website-step-done-color" => :color, "website-step-done-mark-color" => :color, "website-step-marker-size" => :length,
          "website-tab-current-color" => :color, "website-tab-line-color" => :color
        }.freeze

        # The thematiq names the roles are read from and written to. They are not vocabulary keys:
        # a file that names one of them in "vocabulary" is refused, so a value has one home.
        ROLE_NAMES = %w[
          color-primary color-primary-hover color-primary-light color-action color-action-hover color-link color-accent
          color-text color-text-muted color-border color-background-dark color-background color-background-hover
          color-border-dark border-radius border-radius-large font-family
        ].freeze

        # The keys the plugin draws on the page. Every other key is carried, not drawn.
        # It grows with each group the variable layer learns, see Variables::Generator::VOCABULARY.
        DRAWN = %w[
          component-textbox-border-color component-form-select-border-color component-textbox-hover-border-color
          component-textbox-invalid-border-color component-textbox-background-color component-textbox-disabled-background-color
          component-textbox-color component-textbox-disabled-color component-button-secondary-action-color
          component-button-secondary-action-hover-background-color component-button-secondary-action-border-color
          animation-quick animation-slow brand-stripe-color-1 brand-stripe-color-2 brand-stripe-color-3 brand-stripe-height
          brand-stripe-ratio-1 brand-stripe-ratio-2 brand-stripe-ratio-3 color-footer-background color-footer-text
          color-header-background color-header-text
          color-error color-success color-warning component-status-badge-error-background-color component-status-badge-error-color
          component-status-badge-info-background-color component-status-badge-success-background-color
          component-status-badge-success-color component-status-badge-warning-background-color component-status-badge-warning-color
          color-text-light component-separator-border-color color-focus-rgb color-focus border-radius-small border-radius-pill
          component-button-color component-button-border-color component-button-hover-background-color
          component-button-hover-border-color component-button-active-background-color component-button-disabled-background-color
          component-button-disabled-border-color color-error-hover component-button-error-color
          component-table-header-background-color component-table-header-color component-table-border-color
          component-table-row-hover-background-color component-content-surface-background-color component-table-header-font-weight
          component-navigation-active-background-color component-navigation-active-color component-navigation-badge-background-color
          component-navigation-badge-color component-heading-1-font-size component-heading-2-font-size component-heading-3-font-size
          component-heading-4-font-size component-heading-5-font-size component-heading-6-font-size body-font-family
        ].freeze

        module_function

        def keys
          KINDS.keys
        end

        def kind(key)
          KINDS[key]
        end

        def key?(key)
          KINDS.key?(key)
        end

        # The CSS name thematiq gives a key: "color-error" is "--nldesign-color-error".
        def css_name(key)
          "#{PREFIX}#{key}"
        end

        # The key of a thematiq CSS name, or nil when the name is not in the vocabulary.
        def key_of(css_name)
          return nil unless css_name.is_a?(String) && css_name.start_with?(PREFIX)

          key = css_name.delete_prefix(PREFIX)
          key?(key) ? key : nil
        end

        def drawn?(key)
          DRAWN.include?(key)
        end
      end
    end
  end
end
