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
      # Only a set with a menu colour gets this rule. The other sets keep the colour they were given.
      def on_selected(token_set)
        return token_set["primary-deep"] unless token_set["menu"]

        best_on(token_set["primary-light"], [token_set["primary-deep"], "#ffffff", "#1b1c1d"])
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
        result["primary-deep-on-primary-light"] = ratio(on_selected(token_set), token_set["primary-light"])
        result["text-on-menu"] = ratio(on_menu(token_set), token_set["menu"]) if token_set["menu"]
        result
      end

      # The names of the pairs under 4.5:1. A pair that cannot be computed is not listed here, see #unknown.
      def failures(token_set)
        report(token_set).select { |_pair, value| value && value < MINIMUM }.keys
      end

      def unknown(token_set)
        report(token_set).select { |_pair, value| value.nil? }.keys
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
