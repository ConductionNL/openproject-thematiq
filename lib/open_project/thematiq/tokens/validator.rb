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
        # A length with up to four digits, for the page widths of the vocabulary such as 1328px.
        SIZE = /\A(?:0|(?:\d{1,4}(?:\.\d{1,3})?|\.\d{1,3})(?:px|rem|em|%))\z/
        # The kinds the vocabulary adds. Each is an allow-list of the whole text, like the three above.
        FONT_WEIGHT = /\A(?:[1-9]\d{0,2}|1000|normal|bold)\z/
        NUMBER = /\A(?:\d{1,4}(?:\.\d{1,4})?|\.\d{1,4})\z/
        DURATION = /\A(?:\d{1,5}(?:\.\d{1,3})?|\.\d{1,3})(?:ms|s)\z/
        RGB_TRIPLET = /\A(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\z/
        FILTER_FUNCTION = /\A(?:(?:brightness|contrast|grayscale|invert|opacity|saturate|sepia)\((?:\d{1,3}(?:\.\d{1,3})?|\.\d{1,3})%?\)|hue-rotate\(-?\d{1,3}(?:\.\d{1,3})?deg\))\z/
        MAX_FILTERS = 6
        BORDER = /\A(\S{1,12})\s+(solid|dashed|dotted|double)\s+(.{1,80})\z/
        TEXT_TRANSFORMS = %w[none uppercase lowercase capitalize].freeze
        QUOTED_FAMILY = /\A(["'])([A-Za-z0-9 _.-]{1,60})\1\z/
        BARE_FAMILY = /\A-?[A-Za-z_][A-Za-z0-9_-]*(?: [A-Za-z_][A-Za-z0-9_-]*)*\z/

        FILE_REFERENCE = %r{\A(?:[a-z0-9][a-z0-9_-]{0,40}/){0,4}[a-z0-9][a-z0-9._-]{0,80}\.(?:svg|png)\z}

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

        MAX_FAMILIES = 20
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

        # --- the kinds of the vocabulary, see Tokens::Vocabulary ---

        # A length that may be wider than a radius: up to 9999px.
        def size(value)
          plain(value, SIZE)
        end

        # 400, 700, normal or bold. A number from 1 to 1000.
        def font_weight(value)
          plain(value, FONT_WEIGHT)
        end

        # A plain number such as 1.15 or 6, for a ratio, an opacity or a line height.
        def number(value)
          plain(value, NUMBER)
        end

        # 100ms or 0.3s.
        def duration(value)
          plain(value, DURATION)
        end

        # A length, or auto, for a position.
        def offset(value)
          return "auto" if value.is_a?(String) && value.strip.downcase == "auto"

          length(value)
        end

        def text_transform(value)
          return nil unless value.is_a?(String)

          text = value.strip.downcase
          TEXT_TRANSFORMS.include?(text) ? text : nil
        end

        # Three channels for rgba(): "204, 0, 0". Rebuilt from the numbers.
        def rgb_triplet(value)
          match = value.is_a?(String) ? RGB_TRIPLET.match(value.strip) : nil
          return nil unless match

          channels = match.captures.map(&:to_i)
          channels.all? { |channel| channel <= 255 } ? channels.join(", ") : nil
        end

        # none, or up to six filter functions from a fixed list, each with one plain number.
        # Rebuilt from the parsed functions, so nothing outside the list survives.
        def filter(value)
          return nil unless value.is_a?(String) && value.length <= 200

          text = value.strip.downcase
          return "none" if text == "none"

          parts = text.split(/\s+/)
          return nil if parts.empty? || parts.size > MAX_FILTERS
          return nil unless parts.all? { |part| FILTER_FUNCTION.match?(part) }

          parts.join(" ")
        end

        # 0, none, or a width, a style and a colour: "1px solid #cfd5dd". Each part goes through its own check.
        def border(value)
          return nil unless value.is_a?(String)

          text = value.strip.downcase
          return text if %w[0 none].include?(text)

          match = BORDER.match(text)
          return nil unless match

          width = length(match[1])
          colour = color(match[3])
          width && colour ? "#{width} #{match[2]} #{colour}" : nil
        end

        def plain(value, pattern)
          return nil unless value.is_a?(String)

          text = value.strip.downcase
          pattern.match?(text) ? text : nil
        end

        # A reference to a bundled file: a plain svg or png name, or a path the catalogue generator wrote,
        # such as "img/logos/zuiddrecht.svg". Returns the file name only. The plugin never opens the path as given,
        # it looks the name up in its own folder.
        def file_name(value)
          return nil unless value.is_a?(String) && FILE_REFERENCE.match?(value) && !value.include?("..")

          File.basename(value)
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
