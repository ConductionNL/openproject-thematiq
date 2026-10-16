# frozen_string_literal: true

module OpenProject
  module Thematiq
    # WCAG 2 contrast between two colours, for the text the plugin puts on a design system's colours.
    # It reads hex colours and rgb(). For any other syntax it answers nil: unknown, not "fine".
    module Contrast
      MINIMUM = 4.5

      # The pairs the shell draws: the text on the top bar and on the main button (white, see #on),
      # and the main text, the muted text and links on the page background and on white.
      PAIRS = {
        "on-primary" => ["#ffffff", "primary"],
        "on-action" => ["#ffffff", "action"],
        "ink-on-ground" => %w[ink ground],
        "muted-on-ground" => %w[muted ground],
        "link-on-white" => ["link", "#ffffff"],
        "primary-deep-on-primary-light" => %w[primary-deep primary-light]
      }.freeze

      module_function

      def ratio(foreground, background)
        back = rgba(background)
        fore = rgba(foreground)
        return nil unless back && fore && back[3] == 1.0

        # A see-through text colour is mixed with what is behind it first.
        mixed = fore.first(3).zip(back.first(3)).map { |f, b| (f * fore[3]) + (b * (1 - fore[3])) }
        a = luminance(mixed)
        b = luminance(back.first(3))
        lighter, darker = [a, b].max, [a, b].min
        ((lighter + 0.05) / (darker + 0.05)).round(2)
      end

      # The candidate that reads best on a background. The first one wins when it reaches 4.5 to 1,
      # so a design system's own choice is kept whenever it is good enough.
      def best_on(background, candidates)
        usable = candidates.compact
        first = usable.first
        return first if first && (ratio(first, background) || 0) >= MINIMUM

        usable.max_by { |candidate| ratio(candidate, background) || 0 } || first
      end

      # The text colour the plugin puts on one of a set's colours: white when white reads on it,
      # which is so for every set generated from thematiq, and otherwise the better of white and the set's ink.
      def on(token_set, role)
        best_on(token_set[role], ["#ffffff", token_set["ink"], "#1b1c1d"])
      end

      # The text on the selected menu item: the set's own primary-deep when it reads, else white or near black.
      # Only a set with a menu colour gets this rule; every set of the catalogue has one since thematiq #1300.
      def on_selected(token_set)
        return token_set["primary-deep"] unless token_set["menu"]

        best_on(token_set["primary-light"], [token_set["primary-deep"], "#ffffff", "#1b1c1d"])
      end

      NAV_KEYS = %w[component-navigation-active-background-color component-navigation-active-color].freeze
      # thematiq draws its selected entry as a 16% wash of its colour over the menu, as Variables::Generator does.
      NAV_WASH = 0.16

      # thematiq's own selected entry, from a vocabulary on the menu of tokens (a token set or a dark block):
      # [text, background], or nil when the vocabulary names neither colour.
      def nav_selected(vocabulary, tokens)
        background, text = NAV_KEYS.map { |key| vocabulary[key] }
        return nil unless background || text

        surface = tokens["menu"] || "#ffffff"
        [text || tokens["primary-deep"], background ? mix(background, surface, NAV_WASH) : tokens["primary-light"]]
      end

      # Whether the set's own selected entry is drawn: always without a menu colour, as before the role existed;
      # with one only when it reads on that menu. Otherwise the contrast rule of #on_selected decides.
      def nav_drawn?(vocabulary, tokens)
        pair = nav_selected(vocabulary, tokens)
        return false unless pair
        return true unless tokens["menu"]

        value = ratio(*pair)
        !value.nil? && value >= MINIMUM
      end

      # The selected entry as the plugin draws it: [text, background].
      def selected_pair(vocabulary, tokens, rule)
        nav_drawn?(vocabulary, tokens) ? nav_selected(vocabulary, tokens) : [rule, tokens["primary-light"]]
      end

      # A share of one opaque colour over another, as a hex colour. nil when either cannot be read.
      def mix(color, over, share)
        top = rgba(color)
        bottom = rgba(over)
        return nil unless top && bottom

        "##{top.first(3).zip(bottom.first(3)).map { |t, b| format('%02x', ((t * share) + (b * (1 - share))).round) }.join}"
      end

      # The text colour the plugin puts on a set's main menu: its ink, or white when ink does not read on it.
      def on_menu(token_set)
        best_on(token_set["menu"], [token_set["ink"], "#ffffff", "#1b1c1d"])
      end

      # { pair name => ratio or nil } for one token set. A set with a menu colour gets one more pair.
      def report(token_set)
        result = PAIRS.transform_values do |foreground, background|
          ratio(resolve(token_set, foreground), resolve(token_set, background))
        end
        result["on-primary"] = ratio(on(token_set, "primary"), token_set["primary"])
        result["on-action"] = ratio(on(token_set, "action"), token_set["action"])
        result["primary-deep-on-primary-light"] = ratio(*selected_pair(token_set.vocabulary, token_set, on_selected(token_set)))
        result["text-on-menu"] = ratio(on_menu(token_set), token_set["menu"]) if token_set["menu"]
        result
      end

      # A dark block is only used when its main text reads on its page background. One that fails that
      # would make every page unreadable, so for such a set the dark theme keeps OpenProject's own colours.
      def dark_usable?(token_set)
        return false unless token_set.dark?

        value = ratio(token_set.dark_tokens["ink"], token_set.dark_tokens["ground"])
        value.nil? || value >= MINIMUM
      end

      # The text on the selected menu item in the dark theme. The dark blocks keep the light theme's
      # primary-deep, a dark colour, on a dark primary-light. So the rule decides: the block's own
      # primary-deep when it reads, else whichever of its ink and white reads best.
      def dark_on_selected(dark)
        best_on(dark["primary-light"], [dark["primary-deep"], dark["ink"], "#ffffff"])
      end

      # The contrast in the dark theme as the plugin draws it, or nil when the set has no dark block.
      # In the dark theme links sit on the ground colour, not on white.
      def dark_report(token_set)
        return nil unless token_set.dark?

        dark = token_set.dark_tokens
        report = { "on-primary" => ratio(on(dark, "primary"), dark["primary"]),
                   "on-action" => ratio(on(dark, "action"), dark["action"]),
                   "ink-on-ground" => ratio(dark["ink"], dark["ground"]),
                   "muted-on-ground" => ratio(dark["muted"], dark["ground"]),
                   "link-on-ground" => ratio(dark["link"], dark["ground"]),
                   "primary-deep-on-primary-light" => ratio(*selected_pair(token_set.dark_vocabulary, dark, dark_on_selected(dark))) }
        # A dark block with a menu colour gets the text on it measured, as the light theme does.
        report["text-on-menu"] = ratio(on_menu(dark), dark["menu"]) if dark["menu"]
        report
      end

      def dark_failures(token_set)
        (dark_report(token_set) || {}).select { |_pair, value| value && value < MINIMUM }.keys
      end

      # The names of the pairs under 4.5:1. A pair that cannot be computed is not listed here, see #unknown.
      def failures(token_set)
        report(token_set).select { |_pair, value| value && value < MINIMUM }.keys
      end

      def unknown(token_set)
        report(token_set).select { |_pair, value| value.nil? }.keys
      end

      # A layer of the text colour over a background, as the top bar draws its search field and its current tile:
      # the strongest one up to max (a share, 0.12 is 12%) that keeps the text above the minimum on it, as a hex
      # colour. Every set generated from thematiq reads on its primary; a light layer can still take it under.
      # nil when either colour cannot be read.
      def tint(background, text, max)
        back = rgba(background)
        fore = rgba(text)
        return nil unless back && fore && back[3] == 1.0 && fore[3] == 1.0

        (max * 100).round.downto(0) do |step|
          share = step / 100.0
          mixed = format("#%02x%02x%02x", *back.first(3).zip(fore.first(3)).map { |b, f| ((b * (1 - share)) + (f * share)).round })
          # Above the minimum after rounding to two places, so a checker that does not round agrees.
          return mixed if step.zero? || (ratio(text, mixed) || 0) > MINIMUM
        end
      end

      def resolve(token_set, reference)
        reference.start_with?("#") ? reference : token_set[reference]
      end

      def luminance(channels)
        r, g, b = channels.map do |channel|
          value = channel / 255.0
          value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
        end
        (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
      end

      # [red, green, blue, alpha] for a hex colour, rgb() or rgba(). nil for any other syntax.
      def rgba(color)
        return nil unless color.is_a?(String)

        case color.strip.downcase
        when /\A#(\h)(\h)(\h)\z/ then [$1, $2, $3].map { |digit| (digit * 2).hex.to_f } + [1.0]
        when /\A#(\h\h)(\h\h)(\h\h)\z/ then [$1, $2, $3].map { |pair| pair.hex.to_f } + [1.0]
        when /\Argba?\(\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*[, ]\s*(\d{1,3})\s*(?:[,\/]\s*(\d?\.?\d+)\s*)?\)\z/
          values = [$1, $2, $3].map(&:to_f)
          alpha = $4 ? $4.to_f : 1.0
          values.all? { |value| value <= 255 } && alpha.between?(0, 1) ? values + [alpha] : nil
        end
      end
    end
  end
end
