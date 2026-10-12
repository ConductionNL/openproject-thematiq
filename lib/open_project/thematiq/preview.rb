# frozen_string_literal: true

require "open_project/thematiq/tokens"

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
          top_bar_mark: css("background" => "#ffffff"),
          top_bar_search: css("border" => "1px solid #ffffff", "border-radius" => value("radius")),
          sidebar: css("background" => "#ffffff", "border-right" => "1px solid #{value('line')}"),
          button: css("background" => value("action"), "border" => "1px solid #{value('action-deep')}", "border-radius" => value("radius")),
          active_item: css("background" => value("primary-light"), "border-radius" => value("radius")),
          item: css("background" => value("soft"), "border-radius" => value("radius")),
          content: css("background" => value("ground")),
          title: css("background" => value("ink"), "border-radius" => value("radius")),
          row: css("background" => "#ffffff", "border" => "1px solid #{value('field')}", "border-radius" => value("radius"))
        }
      end

      # The larger picture of the shared shell in the editor.
      def shell
        font = value("font-family")
        {
          frame: css("background" => value("ground"), "border" => "1px solid #{value('line')}",
                     "border-radius" => value("radius-lg"), "font-family" => font, "color" => value("ink")),
          top_bar: css("background" => value("primary"), "color" => "#ffffff"),
          search: css("border" => "1px solid #ffffff", "border-radius" => value("radius-lg"), "color" => "#ffffff"),
          sidebar: css("background" => "#ffffff", "border-right" => "1px solid #{value('line')}"),
          action_button: css("background" => value("action"), "border" => "1px solid #{value('action-deep')}",
                             "border-radius" => value("radius"), "color" => "#ffffff"),
          secondary_button: css("background" => "#ffffff", "border" => "1px solid #{value('field')}",
                                "border-radius" => value("radius"), "color" => value("ink")),
          nav_item: css("border-radius" => value("radius"), "color" => value("ink")),
          nav_item_active: css("background" => value("primary-light"), "border-radius" => value("radius"),
                               "color" => value("primary-deep")),
          table: css("background" => "#ffffff", "border" => "1px solid #{value('line')}", "border-radius" => value("radius-lg")),
          table_head: css("color" => value("muted"), "border-bottom" => "1px solid #{value('line')}"),
          table_row: css("border-top" => "1px solid #{value('line')}"),
          link: css("color" => value("link")),
          muted: css("color" => value("muted")),
          input: css("background" => "#ffffff", "border" => "1px solid #{value('field')}",
                     "border-radius" => value("radius-lg"), "color" => value("ink"))
        }
      end

      # A square in one colour, next to a colour field.
      def swatch(key)
        css("background" => value(key), "border" => "1px solid #{value('field')}")
      end

      private

      def value(key)
        @token_set[key] || NEUTRAL.fetch(key)
      end

      def css(declarations)
        declarations.map { |property, value| "#{property}: #{value}" }.join("; ")
      end
    end
  end
end
