# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Tokens
      # The last resort values: what a token falls back to when its value is refused,
      # and the whole set when the catalogue cannot be read.
      # They are the Cunningham based example set the spike used (spike/theme.css).
      # The spike had no value for "accent", "text" and "chip", so those are left out here.
      module Defaults
        ID = "cunningham"
        NAME = "Cunningham"

        TOKENS = {
          "primary" => "#1a67a3",
          "primary-deep" => "#124872",
          "primary-light" => "#ebf3f7",
          "action" => "#1f883d",
          "action-deep" => "#197032",
          "link" => "#175a8e",
          "ink" => "#1f2328",
          "muted" => "#59636e",
          "line" => "#eaeaea",
          "soft" => "#f6f8fa",
          "ground" => "#f6f8fa",
          "field" => "#d1d9e0",
          "radius" => "3px",
          "radius-lg" => "6px",
          "font-family" => "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif"
        }.freeze
      end
    end
  end
end
