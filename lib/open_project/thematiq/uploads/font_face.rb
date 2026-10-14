# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Uploads
      # The family, weight and style an uploaded font is served under. An administrator types them,
      # and they end up in an @font-face rule, so each one is matched against a fixed shape.
      module FontFace
        FAMILY = /\A[A-Za-z0-9][A-Za-z0-9 _.-]{0,59}\z/
        WEIGHTS = (%w[100 200 300 400 500 600 700 800 900] + ["100 900"]).freeze
        STYLES = %w[normal italic].freeze

        Face = Struct.new(:family, :weight, :style, keyword_init: true)

        # Families whose licence reserves them for an entitled organisation. An upload of one asks for a confirmation.
        GATED = %w[marianne].freeze

        module_function

        def gated?(family)
          GATED.include?(family.to_s.strip.downcase)
        end


        # Returns a Face, or raises Refused.
        def clean(family:, weight:, style:)
          name = family.is_a?(String) && !family.match?(/[[:cntrl:]]/) ? family.strip.squeeze(" ") : ""
          raise Refused, "font_family_invalid" unless FAMILY.match?(name)
          raise Refused, "font_weight_invalid" unless WEIGHTS.include?(weight.to_s)
          raise Refused, "font_style_invalid" unless STYLES.include?(style.to_s)

          Face.new(family: name, weight: weight.to_s, style: style.to_s).freeze
        end

        # One @font-face rule for a stored font. Empty when the record is not a usable font.
        def css(record, root: "")
          face = record.kind == "font" ? record.face : nil
          hint = FORMATS.dig(record.format, :css)
          return "" unless face && hint

          "@font-face { font-family: '#{face.family}'; font-style: #{face.style}; font-weight: #{face.weight}; " \
            "font-display: swap; src: url(#{record.url(root:)}) format('#{hint}'); }"
        end
      end
    end
  end
end
