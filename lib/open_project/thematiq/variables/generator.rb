# frozen_string_literal: true

require "open_project/thematiq/contrast"

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
        # What a hover or a line looks like on a menu of any colour: a little of the opposite, see-through.
        MENU_OVERLAY = "rgba(127, 127, 127, 0.25)"
        DARK_SCOPE = 'body[data-color-mode="dark"][data-dark-theme="dark"]'
        MODE_SCOPE = "[data-color-mode]"
        # The same block for a page where this CSS comes before OpenProject's own stylesheets:
        # one element more in the selector, so it wins without relying on source order.
        EARLY_MODE_SCOPE = "body[data-color-mode]"
        WHITE = "#ffffff"

        # OpenProject's own design variables, the ones its Enterprise design page writes.
        OPENPROJECT_COLORS = {
          "--header-bg-color" => :primary,
          "--header-item-font-color" => :on_primary,
          "--header-item-font-hover-color" => :on_primary,
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
          "--button--primary-font-color" => :on_action,
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
          "--thematiq-on-primary" => [:on_primary, "var(--header-item-font-color)"],
          "--thematiq-on-action" => [:on_action, "var(--button-primary-fgColor-rest)"],
          "--thematiq-menu" => [WHITE, "var(--main-menu-bg-color)"],
          "--thematiq-on-menu" => [:ink, "var(--main-menu-font-color)"]
        }.freeze

        # The search field and the current tile of the top bar: a layer of the bar's text colour over the bar
        # (canon: 12% for the field, 16% for the tile). In the light and dark theme the layer is as strong as the
        # canon allows while the text on it keeps 4.5 to 1 (first full test, findings 16 and 17). Elsewhere, in
        # the high contrast themes, the canon's own layer.
        BAR_TINTS = {
          "--thematiq-bar-field" => [0.12, "rgba(255, 255, 255, .12)"],
          "--thematiq-bar-current" => [0.16, "color-mix(in srgb, var(--thematiq-on-primary) 16%, transparent)"]
        }.freeze

        ROOT_SHAPE = {
          "--thematiq-radius" => :radius,
          "--thematiq-radius-lg" => :"radius-lg",
          "--thematiq-font" => :"font-family",
          "--body-font-family" => :"font-family"
        }.freeze

        ROOT_ALIASES = ROOT_SHAPE.reject { |variable, _| variable == "--body-font-family" }.freeze
        BODY_FONT = { "--body-font-family" => :"font-family" }.freeze

        # Values of thematiq's full vocabulary the plugin draws, see Tokens::Vocabulary. A variable lists the keys
        # it can take, the first one a set fills wins. A set that fills none of them leaves the variable alone:
        # OpenProject keeps its own value, nothing is derived. A filled key wins over what the roles write.
        # Light theme only. The dark and high contrast themes keep OpenProject's own values.
        #
        # Status colours: Primer's danger, attention and success scales. They colour banners, flash messages,
        # form errors and labels. The text colour of a status badge is the darker one, so it is preferred for the
        # text variable; the status colour itself fills and draws the strong border. Primer's "accent" scale is
        # the link and the primary here, so the info colour is carried and not drawn.
        VOCABULARY_COLORS = {
          "--fgColor-danger" => %w[component-status-badge-error-color color-error],
          "--bgColor-danger-emphasis" => %w[color-error],
          "--borderColor-danger-emphasis" => %w[color-error],
          "--bgColor-danger-muted" => %w[component-status-badge-error-background-color],
          "--fgColor-attention" => %w[component-status-badge-warning-color color-warning],
          "--bgColor-attention-emphasis" => %w[color-warning],
          "--borderColor-attention-emphasis" => %w[color-warning],
          "--bgColor-attention-muted" => %w[component-status-badge-warning-background-color],
          "--fgColor-success" => %w[component-status-badge-success-color color-success],
          "--bgColor-success-emphasis" => %w[color-success],
          "--borderColor-success-emphasis" => %w[color-success],
          "--bgColor-success-muted" => %w[component-status-badge-success-background-color],
          "--bgColor-accent-muted" => %w[component-status-badge-info-background-color]
        }.freeze

        # The vocabulary keys this layer draws. Tokens::Vocabulary::DRAWN must name the same, a test holds them together.
        def self.drawn_keys
          VOCABULARY_COLORS.values.flatten.uniq.sort
        end

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
            block(LIGHT_SCOPE, without_drawn(declarations(OPENPROJECT_COLORS) + declarations(PRIMER_COLORS), VOCABULARY_COLORS) +
                               light_aliases + menu_color_declarations + vocabulary_declarations(VOCABULARY_COLORS))
          ]
          blocks << block("#{LIGHT_SCOPE} #main-menu", menu_declarations) if @token_set["menu"]
          blocks << block(DARK_SCOPE, dark_declarations) if Contrast.dark_usable?(@token_set)
          blocks.join("\n")
        end

        private

        def declarations(map)
          map.filter_map do |variable, source|
            value = resolve(source)
            "  #{variable}: #{value};" if value
          end
        end

        # One line per variable of the map that the set fills a key for, from the first key it fills.
        def vocabulary_declarations(map)
          map.filter_map do |variable, keys|
            value = keys.lazy.filter_map { |key| @token_set.vocabulary[key] }.first
            "  #{variable}: #{value};" if value
          end
        end

        # The role lines without the variables the vocabulary fills, so each variable is written once.
        def without_drawn(lines, map)
          drawn = map.select { |_variable, keys| keys.any? { |key| @token_set.vocabulary.key?(key) } }.keys
          lines.reject { |line| drawn.include?(line[/\A\s*(--[A-Za-z0-9-]+):/, 1]) }
        end

        def fallback_aliases
          COLOR_ALIASES.merge(BAR_TINTS).map { |variable, (_token, fallback)| "  #{variable}: #{fallback};" }
        end

        def light_aliases
          declarations(COLOR_ALIASES.transform_values(&:first)) +
            bar_tint_declarations(@token_set["primary"] && [@token_set["primary"], Contrast.on(@token_set, "primary")])
        end

        def bar_tint_declarations(bar)
          return [] unless bar

          BAR_TINTS.filter_map do |variable, (share, _fallback)|
            value = Contrast.tint(*bar, share)
            "  #{variable}: #{value};" if value
          end
        end

        # :on_primary and :on_action are not tokens. They are the text colour for that background,
        # from the contrast rule: white wherever white reads, which is every set generated from thematiq.
        def resolve(source)
          case source
          when :on_primary then @token_set["primary"] && Contrast.on(@token_set, "primary")
          when :on_action then @token_set["action"] && Contrast.on(@token_set, "action")
          when Symbol then @token_set[source.to_s]
          else source
          end
        end

        # A set with a menu colour gets the menu's variables from that colour, and the text on it from a
        # contrast rule: the set's ink when it reads on the menu, white or near black otherwise.
        def menu_color_declarations
          menu = @token_set["menu"]
          return [] unless menu

          text = Contrast.on_menu(@token_set)
          ["  --main-menu-bg-color: #{menu};", "  --main-menu-font-color: #{text};", "  --main-menu-hover-font-color: #{text};",
           "  --main-menu-bg-hover-background: #{MENU_OVERLAY};", "  --thematiq-menu: #{menu};", "  --thematiq-on-menu: #{text};"]
        end

        # Inside the main menu the aliases get the menu's values, so every rule written for a white menu
        # keeps working on a coloured one without knowing about it.
        def menu_declarations
          text = Contrast.on_menu(@token_set)
          selected = Contrast.on_selected(@token_set)
          ["  --thematiq-surface: #{@token_set['menu']};", "  --thematiq-ink: #{text};", "  --thematiq-text: #{text};",
           "  --thematiq-muted: #{text};", "  --thematiq-soft: #{MENU_OVERLAY};", "  --thematiq-line: #{MENU_OVERLAY};",
           # A link inside a coloured menu, such as "Show all", takes the menu's text colour. The link colour
           # is chosen for a white page and read 2.7 to 1 on the navy menu.
           "  --thematiq-link: #{text};",
           "  --thematiq-primary-deep: #{selected};", "  --main-menu-selected-font-color: #{selected};"]
        end

        # The dark theme only gets what the design system's dark block names. A literal such as white
        # has no dark counterpart in the token set, so those entries stay OpenProject's own.
        # The text on the top bar and on the main button follows the same contrast rule as in the light theme.
        def dark_declarations
          dark = @token_set.dark_tokens
          colours = OPENPROJECT_COLORS.merge(PRIMER_COLORS).merge(COLOR_ALIASES.transform_values(&:first)).filter_map do |variable, source|
            value = case source
                    when :on_primary then dark["primary"] && Contrast.on(dark, "primary")
                    when :on_action then dark["action"] && Contrast.on(dark, "action")
                    when Symbol then dark[source.to_s]
                    end
            "  #{variable}: #{value};" if value
          end
          colours + bar_tint_declarations(dark["primary"] && [dark["primary"], Contrast.on(dark, "primary")]) +
            dark_selected_declarations(dark)
        end

        # The selected menu item in the dark theme: its text from the contrast rule, written last so it decides.
        def dark_selected_declarations(dark)
          return [] unless dark["primary-light"]

          text = Contrast.dark_on_selected(dark)
          ["  --main-menu-selected-font-color: #{text};", "  --thematiq-primary-deep: #{text};"]
        end

        def block(selector, lines)
          "#{selector} {\n#{lines.join("\n")}\n}"
        end
      end
    end
  end
end
