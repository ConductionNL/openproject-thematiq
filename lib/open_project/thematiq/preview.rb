# frozen_string_literal: true

require "open_project/thematiq/tokens"
require "open_project/thematiq/contrast"

module OpenProject
  module Thematiq
    # Inline styles for a small picture of a design system: a top bar, a primary button and a row.
    # No images. Every colour, length and font comes out of a TokenSet, so it has passed the Validator.
    # A token the set does not have gets the last resort value, never a value from outside.
    class Preview
      NEUTRAL = Tokens::Defaults::TOKENS

      def initialize(token_set)
        @token_set = token_set
      end

      # The small picture in the list of design systems.
      def thumbnail
        {
          frame: css("background" => "#ffffff", "border" => "1px solid #{value('line')}", "border-radius" => value("radius-lg")),
          top_bar: css("background" => value("primary")),
          top_bar_mark: css("background" => on("primary")),
          top_bar_search: css("border" => "1px solid #{on('primary')}", "border-radius" => value("radius")),
          sidebar: css("background" => @token_set["menu"] || "#ffffff", "border-right" => "1px solid #{value('line')}"),
          button: css("background" => value("action"), "border" => "1px solid #{value('action-deep')}", "border-radius" => value("radius")),
          active_item: css("background" => value("primary-light"), "border-radius" => value("radius")),
          item: css("background" => value("soft"), "border-radius" => value("radius")),
          content: css("background" => value("ground")),
          title: css("background" => value("ink"), "border-radius" => value("radius")),
          row: css("background" => "#ffffff", "border" => "1px solid #{value('field')}", "border-radius" => value("radius"))
        }
      end

      PREFIX = "--tqp-"

      # The larger picture of the shared shell in the editor: one custom property per token, and the
      # colours the plugin works out itself. The static CSS of the picture reads them, and the script of
      # the editor writes the same properties while an administrator types. One style attribute, no rules.
      def shell_variables
        css(shell_variable_map)
      end

      # The same properties as a hash, for the script: it writes the instance's values on the top bar and the menu
      # of the picture when the editor shows a module's design system, which reaches the content area only.
      def shell_variable_map
        values = Tokens::TokenSet::ALL_KINDS.each_key.to_h { |key| ["#{PREFIX}#{key}", value(key)] }
        derived.each { |name, colour| values["#{PREFIX}#{name}"] = colour }
        values
      end

      # The colours the plugin picks by contrast. The script of the editor follows the same rules.
      #   on-primary   the text on the top bar
      #   on-action    the text on the main button
      #   on-menu      the text on the main menu: the ink on a white menu
      #   on-selected  the text on the selected menu item
      def derived
        { "on-primary" => on("primary"),
          "on-action" => on("action"),
          "on-menu" => (@token_set["menu"] ? Contrast.on_menu(@token_set) : value("ink")),
          "on-selected" => (Contrast.on_selected(@token_set) || value("primary-deep")) }
      end

      # The squares behind a colour, so a colour with transparency shows as such. The script of the editor uses the same.
      CHECKERBOARD = "repeating-conic-gradient(#c8c8c8 0% 25%, #ffffff 0% 50%) 0 0 / 10px 10px"

      # A square in one colour over a checkerboard, next to a colour field.
      def swatch(key)
        swatch_of(value(key))
      end

      # The square next to a dark field: the set's dark value, or the bare checkerboard when it has none.
      def dark_swatch(key)
        swatch_of(@token_set.dark_tokens[key] || @token_set.dark_vocabulary[key])
      end

      def swatch_of(colour)
        layers = colour ? "linear-gradient(#{colour}, #{colour}), #{CHECKERBOARD}" : CHECKERBOARD
        css("background" => layers, "border" => "1px solid #{value('field')}")
      end

      private

      # The text colour on one of the set's colours, as the page will have it.
      def on(role)
        Contrast.best_on(value(role), ["#ffffff", value("ink"), "#1b1c1d"])
      end

      # An optional role, such as "menu", has no last resort value. A set without it shows white,
      # which is what the page does. Without this the editor failed for every set that has no menu role.
      def value(key)
        @token_set[key] || NEUTRAL.fetch(key, "#ffffff")
      end

      def css(declarations)
        declarations.map { |property, value| "#{property}: #{value}" }.join("; ")
      end
    end
  end
end
