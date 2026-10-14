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

        # The top bar of the shell, as Nextcloud with thematiq draws it (the dossiq bar): thematiq's header colours
        # where the set gives them, the primary colour and its text otherwise. Zuiddrecht's header is white with
        # ink. The fill of the app button and the search field and the bar's lines follow the bar: the set's ground
        # and line on a light bar, a layer of the bar's text on a coloured one. The second value is the fallback
        # outside the light theme.
        BAR_ALIASES = {
          "--thematiq-bar" => "var(--header-bg-color)",
          "--thematiq-on-bar" => "var(--header-item-font-color)",
          "--thematiq-bar-fill" => "color-mix(in srgb, var(--thematiq-on-bar) 12%, var(--thematiq-bar))",
          "--thematiq-bar-line" => "color-mix(in srgb, var(--thematiq-on-bar) 25%, var(--thematiq-bar))",
          "--thematiq-bar-edge" => "var(--thematiq-bar)",
          "--thematiq-bar-muted" => "var(--thematiq-on-bar)"
        }.freeze
        BAR_KEYS = %w[color-header-background color-header-text].freeze

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
          # The plugin's footer with the legal links (sur-footer-links): thematiq's footer colours.
          "--thematiq-v-footer-bg" => %w[color-footer-background], "--thematiq-v-footer-text" => %w[color-footer-text],
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
          "--bgColor-accent-muted" => %w[component-status-badge-info-background-color],
          # Text on a coloured fill, such as a label or a status fill.
          "--fgColor-onEmphasis" => %w[color-text-light],
          # The quiet line between parts: separators and dividers.
          "--borderColor-muted" => %w[component-separator-border-color],
          # The focus ring. thematiq's focus colour is often see-through (rgba at 50%), which a ring must not be:
          # its opaque channels come first, and the colour itself only counts when it is opaque.
          "--focus-outlineColor" => %w[color-focus-rgb color-focus],
          # Buttons. The default button in its states, on Primer's variables and OpenProject's own text colour
          # of its older buttons. The danger button: its text at rest is the error colour, its fill on hover and
          # when pressed the error hover colour, with the text the set gives for it.
          # The main button stays the action role's: thematiq's color-button-primary-* are carried, so a set keeps
          # the owner's rule that the action colour, and only that, fills the one main button.
          "--button-default-fgColor-rest" => %w[component-button-color],
          "--button--font-color" => %w[component-button-color],
          "--button-default-borderColor-rest" => %w[component-button-border-color],
          "--button-default-bgColor-hover" => %w[component-button-hover-background-color],
          "--button-default-borderColor-hover" => %w[component-button-hover-border-color],
          "--button-default-bgColor-active" => %w[component-button-active-background-color],
          "--button-default-bgColor-disabled" => %w[component-button-disabled-background-color],
          "--button-default-borderColor-disabled" => %w[component-button-disabled-border-color],
          "--button-danger-fgColor-rest" => %w[color-error],
          "--button-danger-iconColor-rest" => %w[color-error],
          "--button-danger-bgColor-hover" => %w[color-error-hover],
          "--button-danger-borderColor-hover" => %w[color-error-hover],
          "--button-danger-bgColor-active" => %w[color-error-hover],
          "--button-danger-fgColor-hover" => %w[component-button-error-color],
          "--button-danger-fgColor-active" => %w[component-button-error-color],
          # The table: its header row, its lines and the row under the pointer. The header and the lines are the
          # geometry layer's own (stylesheets/geometry/60-table.css), which reads these with its canon as fallback.
          # The row under the pointer is OpenProject's own variable for the work package table.
          "--thematiq-v-table-head" => %w[component-table-header-background-color],
          "--thematiq-v-table-head-ink" => %w[component-table-header-color],
          "--thematiq-v-table-line" => %w[component-table-border-color],
          "--box-list-item-bg-hover-color" => %w[component-table-row-hover-background-color],
          # The workspace behind the content: OpenProject's page background.
          "--body-background" => %w[component-content-surface-background-color],
          # The selected entry and the count of the project menu, read by the geometry and shell layers with the
          # primary light and primary deep as fallback. thematiq draws the selected entry as a 16% wash of its
          # colour with the label on top (Nextcloud 34 and later), and so does this: the wash is how thematiq
          # draws the token, the label colour is chosen for it.
          "--thematiq-v-nav-active-wash" => %w[component-navigation-active-background-color],
          "--thematiq-v-nav-active-ink" => %w[component-navigation-active-color],
          "--thematiq-v-nav-badge-bg" => %w[component-navigation-badge-background-color],
          "--thematiq-v-nav-badge-ink" => %w[component-navigation-badge-color]
        }.freeze

        NAV_KEYS = %w[component-navigation-active-background-color component-navigation-active-color
                      component-navigation-badge-background-color component-navigation-badge-color].freeze
        NAV_WASH = 16

        # Corners. Primer defines these on :root, beside the radius the roles already write.
        # thematiq's "rounded" corner (28px) has no Primer step of its own, so it is carried.
        VOCABULARY_SHAPE = {
          "--borderRadius-small" => %w[border-radius-small],
          "--borderRadius-full" => %w[border-radius-pill],
          # The weight of the table header's text, in every theme. The geometry layer falls back to the canon's 600.
          "--thematiq-v-table-head-weight" => %w[component-table-header-font-weight],
          # Headings: Primer's --h1-size to --h6-size, which OpenProject 17.9.1 never sets and reads with a fallback
          # (h1 and the .h1 to .h6 and .f1 to .f6 classes from 768 px up). A set that leaves them out keeps those.
          "--h1-size" => %w[component-heading-1-font-size], "--h2-size" => %w[component-heading-2-font-size],
          "--h3-size" => %w[component-heading-3-font-size], "--h4-size" => %w[component-heading-4-font-size],
          "--h5-size" => %w[component-heading-5-font-size], "--h6-size" => %w[component-heading-6-font-size],
          # The body text's own font, where thematiq gives one apart from the font of the whole set.
          "--body-font-family" => %w[body-font-family],
          # Motion. OpenProject has no variable for it, so these reach the plugin's own animations only.
          "--thematiq-v-animation-quick" => %w[animation-quick], "--thematiq-v-animation-slow" => %w[animation-slow]
        }.freeze

        # The colour of the shell's top bar: thematiq's header background when it is a plain colour, the primary
        # otherwise. nil when neither can be measured. The logo follows the same rule (Shell::Logo).
        def self.bar_colour(tokens, vocabulary)
          header = vocabulary && vocabulary["color-header-background"]
          bar = header if header && Contrast.rgba(header)&.last == 1.0
          bar ||= tokens["primary"]
          bar if bar && Contrast.rgba(bar)
        end

        # The text on the bar: thematiq's header text when it reads on the bar, else white or the darkest that reads.
        def self.on_bar(tokens, vocabulary)
          bar = bar_colour(tokens, vocabulary)
          return nil unless bar

          wanted = vocabulary && vocabulary["color-header-text"]
          return wanted if wanted && (Contrast.ratio(wanted, bar) || 0) >= Contrast::MINIMUM

          Contrast.best_on(bar, [WHITE, tokens["ink"], "#1b1c1d"].compact)
        end

        # The vocabulary keys this layer draws. Tokens::Vocabulary::DRAWN must name the same, a test holds them together.
        def self.drawn_keys
          (VOCABULARY_COLORS.merge(VOCABULARY_SHAPE).values.flatten + STRIPE_KEYS + BAR_KEYS).uniq.sort
        end

        PRIMER_SHAPE = {
          "--borderRadius-medium" => :"radius-lg",
          "--fontStack-system" => :"font-family",
          "--fontStack-sansSerif" => :"font-family"
        }.freeze

        # The content area of a page: OpenProject's main element. A design system chosen for a module reaches it only.
        CONTENT = "#content-wrapper"

        # early: true gives the variant for the top of the head, before OpenProject's stylesheets.
        # It moves everything that would otherwise depend on source order onto the body element.
        # content: true gives the variant for the content area of a page: the same variables, written on the
        # content element, so they reach the content and nothing around it. It has no menu block.
        def initialize(token_set, early: false, content: false)
          @token_set = token_set
          @early = early
          @content = content
        end

        def css
          blocks = [
            "/* openproject-thematiq, variable layer. Generated from a validated token set. */",
            block(":root", declarations(@early ? ROOT_ALIASES : ROOT_SHAPE)),
            block(@early ? EARLY_MODE_SCOPE : MODE_SCOPE,
                  (@early ? declarations(BODY_FONT) : []) + without_drawn(declarations(PRIMER_SHAPE), VOCABULARY_SHAPE) +
                  fallback_aliases + vocabulary_declarations(VOCABULARY_SHAPE) + brand_stripe_declarations),
            block(LIGHT_SCOPE, without_drawn(declarations(OPENPROJECT_COLORS) + declarations(PRIMER_COLORS), VOCABULARY_COLORS) +
                               light_aliases + menu_color_declarations + vocabulary_declarations(VOCABULARY_COLORS) +
                               bar_declarations(@token_set, @token_set.vocabulary))
          ]
          blocks << block("#{LIGHT_SCOPE} #main-menu", menu_declarations) if @token_set["menu"] && !@content
          blocks << block(DARK_SCOPE, dark_declarations) if Contrast.dark_usable?(@token_set)
          blocks.join("\n")
        end

        # thematiq's brand stripe (x-brand-stripe): three colours in their ratios, as one gradient under the top bar and on
        # the sign-in page. Only a set that gives all three colours has one. Each value has passed its validator.
        STRIPE_VARIABLES = %w[--thematiq-v-brand-stripe --thematiq-v-brand-stripe-height].freeze
        STRIPE_KEYS = %w[brand-stripe-color-1 brand-stripe-color-2 brand-stripe-color-3 brand-stripe-height
                         brand-stripe-ratio-1 brand-stripe-ratio-2 brand-stripe-ratio-3].freeze

        def brand_stripe_declarations
          vocabulary = @token_set.vocabulary
          colours = (1..3).map { |index| vocabulary["brand-stripe-color-#{index}"] }
          return [] if colours.any?(&:nil?)

          ratios = (1..3).map { |index| (vocabulary["brand-stripe-ratio-#{index}"] || "1").to_f }
          ratios = [1.0, 1.0, 1.0] unless ratios.all?(&:positive?)
          total = ratios.sum
          first = (ratios[0] / total * 100).round(2)
          second = ((ratios[0] + ratios[1]) / total * 100).round(2)
          gradient = "linear-gradient(to right, #{colours[0]} 0 #{first}%, #{colours[1]} #{first}% #{second}%, #{colours[2]} #{second}% 100%)"
          ["  --thematiq-v-brand-stripe: #{gradient};", "  --thematiq-v-brand-stripe-height: #{vocabulary['brand-stripe-height'] || '4px'};"]
        end

        private

        def declarations(map)
          map.filter_map do |variable, source|
            value = resolve(source)
            "  #{variable}: #{value};" if value
          end
        end

        # One line per variable of the map that the set fills a key for, from the first key it fills.
        def vocabulary_declarations(map, source = @token_set.vocabulary)
          vocabulary_values(map, source).map { |variable, value| "  #{variable}: #{value};" }
        end

        # variable => value, for the variables of the map the set fills a usable key for.
        def vocabulary_values(map, source = @token_set.vocabulary)
          map.each_with_object({}) do |(variable, keys), result|
            value = keys.lazy.filter_map { |key| vocabulary_value(key, source) }.first
            result[variable] = value if value
          end
        end

        # The value of one key as a variable takes it. Three channels become rgb(). A focus colour that is
        # see-through, or that the plugin cannot measure, does not count.
        def vocabulary_value(key, source = @token_set.vocabulary)
          value = source[key]
          return nil unless value
          return "rgb(#{value})" if key == "color-focus-rgb"
          return nil if key == "color-focus" && Contrast.rgba(value)&.last != 1.0
          # A set with a menu colour has the plugin's contrast rule for the text on it. The navigation colours of
          # thematiq are chosen for a white menu, so they stay off a coloured one.
          return nil if NAV_KEYS.include?(key) && @token_set["menu"]
          return "color-mix(in srgb, #{value} #{NAV_WASH}%, var(--thematiq-surface))" if key == "component-navigation-active-background-color"

          value
        end

        # The role lines without the variables the vocabulary fills, so each variable is written once.
        def without_drawn(lines, map, source = @token_set.vocabulary)
          drawn = vocabulary_values(map, source).keys
          lines.reject { |line| drawn.include?(line[/\A\s*(--[A-Za-z0-9-]+):/, 1]) }
        end

        def fallback_aliases
          COLOR_ALIASES.merge(BAR_TINTS).map { |variable, (_token, fallback)| "  #{variable}: #{fallback};" } +
            BAR_ALIASES.map { |variable, fallback| "  #{variable}: #{fallback};" }
        end

        # The quiet text of the bar (the organisation's name, the role, the search placeholder): the set's muted
        # colour where it reads on the bar, the bar's own text otherwise.
        def muted_on_bar(tokens, bar, text)
          muted = tokens["muted"]
          muted && (Contrast.ratio(muted, bar) || 0) >= Contrast::MINIMUM ? muted : text
        end

        # The colours of the shell's top bar for one set of tokens and its vocabulary. A header colour that is not a
        # plain colour the plugin can measure, or a header text that does not read on it, is not used.
        def bar_declarations(tokens, vocabulary)
          bar = self.class.bar_colour(tokens, vocabulary)
          return [] unless bar

          text = self.class.on_bar(tokens, vocabulary)
          light = text.to_s.downcase != WHITE
          fill = (light && tokens["ground"]) || Contrast.tint(bar, text, 0.12) || bar
          line = (light && tokens["line"]) || Contrast.tint(bar, text, 0.25) || bar
          { "--thematiq-bar" => bar, "--thematiq-on-bar" => text, "--thematiq-bar-fill" => fill,
            "--thematiq-bar-line" => line, "--thematiq-bar-edge" => light ? line : bar,
            "--thematiq-bar-muted" => muted_on_bar(tokens, bar, text) }.map { |variable, value| "  #{variable}: #{value};" }
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
          # The dark variant's own vocabulary, where the light value is drawn. It replaces the role's line.
          vocabulary = @token_set.dark_vocabulary
          without_drawn(colours, VOCABULARY_COLORS, vocabulary) +
            bar_tint_declarations(dark["primary"] && [dark["primary"], Contrast.on(dark, "primary")]) +
            dark_selected_declarations(dark) + vocabulary_declarations(VOCABULARY_COLORS, vocabulary) +
            bar_declarations(dark, vocabulary)
        end

        # The selected menu item in the dark theme: its text from the contrast rule, written last so it decides.
        def dark_selected_declarations(dark)
          return [] unless dark["primary-light"]

          text = Contrast.dark_on_selected(dark)
          ["  --main-menu-selected-font-color: #{text};", "  --thematiq-primary-deep: #{text};"]
        end

        def block(selector, lines)
          "#{scoped(selector)} {\n#{lines.join("\n")}\n}"
        end

        def scoped(selector)
          return selector unless @content

          selector == ":root" ? CONTENT : "#{selector} #{CONTENT}"
        end
      end
    end
  end
end
