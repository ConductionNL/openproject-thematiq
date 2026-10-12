# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Variables
      # The variable layer: writes one token set to the CSS variables OpenProject already reads.
      # This is the durable layer. It holds no selectors of OpenProject's markup, only variables.
      #
      # It writes three blocks:
      #   1. :root              radius and font. These do not depend on the colour mode.
      #   2. [data-color-mode]  the --thematiq-* colour aliases, filled from Primer's own variables.
      #                         This keeps the geometry layer correct in dark and high contrast modes.
      #   3. the light theme    the token colours on OpenProject's variables, on Primer's variables
      #                         and on the --thematiq-* aliases.
      #
      # A symbol in the maps below is a token key. A string is a literal CSS value.
      # An entry whose token is missing from the set is left out, so OpenProject's own value stays.
      class Generator
        LIGHT_SCOPE = 'body[data-color-mode="light"][data-light-theme="light"]'
        DARK_SCOPE = 'body[data-color-mode="dark"][data-dark-theme="dark"]'
        MODE_SCOPE = "[data-color-mode]"
        # The same block for a page where this CSS comes before OpenProject's own stylesheets:
        # one element more in the selector, so it wins without relying on source order.
        EARLY_MODE_SCOPE = "body[data-color-mode]"
        WHITE = "#ffffff"

        # OpenProject's own design variables, the ones its Enterprise design page writes.
        OPENPROJECT_COLORS = {
          "--header-bg-color" => :primary,
          "--header-item-font-color" => WHITE,
          "--header-item-font-hover-color" => WHITE,
          "--header-item-bg-hover-color" => :"primary-deep",
          "--header-border-bottom-width" => "0",
          "--header-border-bottom-color" => :"primary-deep",
          "--accent-color" => :link,
          "--accent-color--major1" => :"primary-deep",
          "--accent-color--minor1" => :"primary-light",
          "--primary-button-color" => :action,
          "--primary-button-color--major1" => :"action-deep",
          "--button--primary-background-color" => :action,
          "--button--primary-background-hover-color" => :"action-deep",
          "--button--primary-border-color" => :"action-deep",
          "--button--primary-font-color" => WHITE,
          "--button--background-color" => WHITE,
          "--button--font-color" => :ink,
          "--main-menu-bg-color" => WHITE,
          "--main-menu-font-color" => :ink,
          "--main-menu-selected-font-color" => :"primary-deep",
          "--main-menu-hover-font-color" => :ink,
          "--main-menu-bg-selected-background" => :"primary-light",
          "--main-menu-bg-hover-background" => :soft,
          "--main-menu-border-color" => :line,
          "--main-menu-border-width" => "1px",
          "--body-font-color" => :ink,
          "--content-link-color" => :link
        }.freeze

        # Primer's variables. Primer defines them on [data-color-mode], so :root does not reach them.
        PRIMER_COLORS = {
          "--fgColor-default" => :ink,
          "--fgColor-muted" => :muted,
          "--fgColor-accent" => :link,
          "--bgColor-accent-emphasis" => :primary,
          "--borderColor-default" => :field,
          "--borderColor-accent-emphasis" => :primary,
          "--focus-outlineColor" => :primary,
          "--control-borderColor-rest" => :field,
          "--control-checked-bgColor-rest" => :primary,
          "--button-primary-bgColor-rest" => :action,
          "--button-primary-bgColor-hover" => :"action-deep",
          "--button-primary-borderColor-rest" => :"action-deep",
          "--button-default-bgColor-rest" => WHITE,
          "--button-default-borderColor-rest" => :field
        }.freeze

        # The aliases the geometry layer and the shell use. One per colour token, plus two surfaces.
        # The second value is what the alias falls back to outside the light theme.
        COLOR_ALIASES = {
          "--thematiq-primary" => [:primary, "var(--header-bg-color)"],
          "--thematiq-primary-deep" => [:"primary-deep", "var(--fgColor-accent)"],
          "--thematiq-primary-light" => [:"primary-light", "var(--bgColor-accent-muted)"],
          "--thematiq-action" => [:action, "var(--button-primary-bgColor-rest)"],
          "--thematiq-action-deep" => [:"action-deep", "var(--button-primary-borderColor-rest)"],
          "--thematiq-link" => [:link, "var(--fgColor-accent)"],
          "--thematiq-accent" => [:accent, "var(--fgColor-accent)"],
          "--thematiq-ink" => [:ink, "var(--fgColor-default)"],
          "--thematiq-text" => [:text, "var(--fgColor-default)"],
          "--thematiq-muted" => [:muted, "var(--fgColor-muted)"],
          "--thematiq-line" => [:line, "var(--borderColor-muted)"],
          "--thematiq-soft" => [:soft, "var(--bgColor-muted)"],
          "--thematiq-ground" => [:ground, "var(--bgColor-default)"],
          "--thematiq-chip" => [:chip, "var(--bgColor-neutral-muted)"],
          "--thematiq-field" => [:field, "var(--borderColor-default)"],
          "--thematiq-surface" => [WHITE, "var(--bgColor-default)"],
          "--thematiq-on-primary" => [WHITE, "var(--header-item-font-color)"],
          "--thematiq-on-action" => [WHITE, "var(--button-primary-fgColor-rest)"]
        }.freeze

        ROOT_SHAPE = {
          "--thematiq-radius" => :radius,
          "--thematiq-radius-lg" => :"radius-lg",
          "--thematiq-font" => :"font-family",
          "--body-font-family" => :"font-family"
        }.freeze

        ROOT_ALIASES = ROOT_SHAPE.reject { |variable, _| variable == "--body-font-family" }.freeze
        BODY_FONT = { "--body-font-family" => :"font-family" }.freeze

        PRIMER_SHAPE = {
          "--borderRadius-medium" => :"radius-lg",
          "--fontStack-system" => :"font-family",
          "--fontStack-sansSerif" => :"font-family"
        }.freeze

        # early: true gives the variant for the top of the head, before OpenProject's stylesheets.
        # It moves everything that would otherwise depend on source order onto the body element.
        def initialize(token_set, early: false)
          @token_set = token_set
          @early = early
        end

        def css
          blocks = [
            "/* openproject-thematiq, variable layer. Generated from a validated token set. */",
            block(":root", declarations(@early ? ROOT_ALIASES : ROOT_SHAPE)),
            block(@early ? EARLY_MODE_SCOPE : MODE_SCOPE,
                  (@early ? declarations(BODY_FONT) : []) + declarations(PRIMER_SHAPE) + fallback_aliases),
            block(LIGHT_SCOPE, declarations(OPENPROJECT_COLORS) + declarations(PRIMER_COLORS) + light_aliases)
          ]
          blocks << block(DARK_SCOPE, dark_declarations) if @token_set.dark?
          blocks.join("\n")
        end

        private

        def declarations(map)
          map.filter_map do |variable, source|
            value = resolve(source)
            "  #{variable}: #{value};" if value
          end
        end

        def fallback_aliases
          COLOR_ALIASES.map { |variable, (_token, fallback)| "  #{variable}: #{fallback};" }
        end

        def light_aliases
          declarations(COLOR_ALIASES.transform_values(&:first))
        end

        def resolve(source)
          source.is_a?(Symbol) ? @token_set[source.to_s] : source
        end

        # The dark theme only gets what the design system's dark block names. A literal such as white
        # has no dark counterpart in the token set, so those entries stay OpenProject's own.
        def dark_declarations
          OPENPROJECT_COLORS.merge(PRIMER_COLORS).merge(COLOR_ALIASES.transform_values(&:first)).filter_map do |variable, source|
            value = source.is_a?(Symbol) ? @token_set.dark_tokens[source.to_s] : nil
            "  #{variable}: #{value};" if value
          end
        end

        def block(selector, lines)
          "#{selector} {\n#{lines.join("\n")}\n}"
        end
      end
    end
  end
end
