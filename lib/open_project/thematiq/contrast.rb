# frozen_string_literal: true

module OpenProject
  module Thematiq
    # WCAG 2 contrast between two colours, for the text the plugin puts on a design system's colours.
    # It reads hex colours and rgb(). For any other syntax it answers nil: unknown, not "fine".
    module Contrast
      MINIMUM = 4.5

      # The pairs the shell draws: white text on the top bar and on the main button,
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

      # { pair name => ratio or nil } for one token set.
      def report(token_set)
        PAIRS.transform_values do |foreground, background|
          ratio(resolve(token_set, foreground), resolve(token_set, background))
        end
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
