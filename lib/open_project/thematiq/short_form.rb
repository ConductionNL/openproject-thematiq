# frozen_string_literal: true

require "open_project/thematiq/contrast"

module OpenProject
  module Thematiq
    # "Start from your colours": a house style from a primary and a background colour, like thematiq's short form.
    # The other brand values are worked out from the two; the rest comes from the default design system. The result
    # opens in the editor, unsaved, so the administrator sees every value and its contrast before saving.
    #
    # This is the one place the plugin derives values, because a short form cannot work without it. It only
    # derives roles of the brand: the vocabulary is left to the base design system, as everywhere else.
    module ShortForm
      HEX = /\A#\h{6}\z/
      DEEP = 0.25   # the hover and border shade: the primary with a quarter black
      LIGHT = 0.85  # the selected menu item: the primary with 85% white
      WHITE = "#ffffff"

      module_function

      # The overrides for the editor, from two hex colours. nil when either is not a six digit hex colour.
      def derive(primary:, background:)
        primary = primary.to_s.strip.downcase
        background = background.to_s.strip.downcase
        return nil unless HEX.match?(primary) && HEX.match?(background)

        deep = mix(primary, "#000000", DEEP)
        { "primary" => primary, "primary-deep" => deep, "primary-light" => mix(primary, WHITE, LIGHT),
          "action" => primary, "action-deep" => deep, "link" => readable_link(primary),
          "accent" => primary, "ground" => background }
      end

      # The primary when links in it read on white, else the primary darkened step by step until they do.
      def readable_link(primary)
        0.step(1.0, 0.05) do |share|
          shade = mix(primary, "#000000", share.round(2))
          return shade if (Contrast.ratio(shade, WHITE) || 0) >= Contrast::MINIMUM
        end
        "#000000"
      end

      def mix(from, to, share)
        a = Contrast.rgba(from)
        b = Contrast.rgba(to)
        format("#%02x%02x%02x", *a.first(3).zip(b.first(3)).map { |x, y| ((x * (1 - share)) + (y * share)).round })
      end
    end
  end
end
