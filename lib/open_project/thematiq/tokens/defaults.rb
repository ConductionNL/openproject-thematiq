# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Tokens
      # The last resort values: what a token falls back to when its value is refused,
      # and the whole set when the catalogue cannot be read.
      # They are the values of Cunningham in the bundled catalogue. test/catalogue_test.rb keeps the two the same.
      module Defaults
        ID = "cunningham"
        NAME = "Cunningham (blue base)"

        TOKENS = {
          "primary" => "#1a509f",
          "primary-deep" => "#203c63",
          "primary-light" => "#eaf1fb",
          "action" => "#1f883d",
          "action-deep" => "#197032",
          "link" => "#1a509f",
          "accent" => "#d80000",
          "ink" => "#1b1c1d",
          "text" => "#484a4d",
          "muted" => "#74777c",
          "line" => "#c4c7cb",
          "soft" => "#e1e2e5",
          "ground" => "#ffffff",
          "chip" => "#f0f1f2",
          "field" => "#74777c",
          "radius" => "8px",
          "radius-lg" => "8px",
          "font-family" => "Marianne, Inter, sans-serif"
        }.freeze
      end
    end
  end
end
