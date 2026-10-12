# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Tokens
      # Allow-list validation for token values. Token values end up inside a <style> tag,
      # so a value is only accepted when its whole text matches a known safe syntax.
      # Every method returns the cleaned value, or nil when the value is refused.
      module Validator
        module_function

        HEX_COLOR = /\A#(?:\h{3}|\h{4}|\h{6}|\h{8})\z/
        COLOR_FUNCTION = /\A(rgba?|hsla?|hwb|lab|lch|oklab|oklch)\(([0-9a-z.,%\/\s-]{1,60})\)\z/
        COLOR_ARGUMENT = /\A(?:-?(?:\d{1,4}(?:\.\d{1,4})?|\.\d{1,4})(?:%|deg|turn|rad|grad)?|none)\z/
        LENGTH = /\A(?:0|(?:\d{1,3}(?:\.\d{1,3})?|\.\d{1,3})(?:px|rem|em|%))\z/
        QUOTED_FAMILY = /\A(["'])([A-Za-z0-9 _.-]{1,60})\1\z/
        BARE_FAMILY = /\A-?[A-Za-z_][A-Za-z0-9_-]*(?: [A-Za-z_][A-Za-z0-9_-]*)*\z/

        NAMED_COLORS = %w[
          aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown
          burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan
          darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid
          darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet
          deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro
          ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki
          lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow
          lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray
          lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine
          mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise
          mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab
          orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru
          pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown
          seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan
          teal thistle tomato transparent turquoise violet wheat white whitesmoke yellow yellowgreen
        ].freeze

        MAX_FAMILIES = 12
        MAX_FONT_STACK_LENGTH = 400

        def color(value)
          return nil unless value.is_a?(String)

          text = value.strip.downcase
          return text if HEX_COLOR.match?(text) || NAMED_COLORS.include?(text)

          match = COLOR_FUNCTION.match(text)
          return nil unless match

          arguments = match[2].strip.split(/\s*[,\/]\s*|\s+/)
          return nil unless (3..4).cover?(arguments.size)
          return nil unless arguments.all? { |argument| COLOR_ARGUMENT.match?(argument) }

          text
        end

        def length(value)
          return nil unless value.is_a?(String)

          text = value.strip.downcase
          LENGTH.match?(text) ? text : nil
        end

        # Returns the stack rebuilt from its parsed families, so nothing outside the allow-list survives.
        def font_family(value)
          return nil unless value.is_a?(String) && value.length <= MAX_FONT_STACK_LENGTH

          families = value.split(",", -1).map(&:strip)
          return nil if families.empty? || families.size > MAX_FAMILIES

          cleaned = families.map do |family|
            if (match = QUOTED_FAMILY.match(family))
              "'#{match[2]}'"
            elsif family.length <= 60 && BARE_FAMILY.match?(family)
              family
            else
              return nil
            end
          end
          cleaned.join(", ")
        end

        def absolute_http_url(value)
          return nil unless value.is_a?(String) && value.length <= 2000 && value.match?(/\Ahttps?:\/\/[^\s<>"'`\\]+\z/)

          uri = URI.parse(value)
          uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty? && uri.userinfo.nil? ? value : nil
        rescue URI::InvalidURIError
          nil
        end

        # Plain text shown on the admin page. Never written into CSS.
        def label(value, max: 120)
          return nil unless value.is_a?(String)

          text = value.gsub(/[[:cntrl:]]/, " ").strip
          text.empty? || text.length > max ? nil : text
        end
      end
    end
  end
end
