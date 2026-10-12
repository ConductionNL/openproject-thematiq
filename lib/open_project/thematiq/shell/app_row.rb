# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Shell
      # The row of apps and modules in the top bar. The row itself is rendered in Shell::TopBar.
      # This holds the two decisions that need no view: how many icons, and which one is current.
      module AppRow
        DEFAULT_COUNT = 7
        MAX_COUNT = 12

        # The stored value as a number of icons. Nothing stored, or nonsense, gives the default.
        def self.count(value)
          text = value.to_s.strip
          return DEFAULT_COUNT unless text.match?(/\A\d{1,3}\z/)

          text.to_i.clamp(0, MAX_COUNT)
        end

        # Whether the page at `path` belongs to the module that lives at `href`.
        # The home page only matches itself. Every other module also matches the pages below it.
        def self.current?(path, href)
          here = path.to_s.sub(%r{/+\z}, "")
          there = href.to_s.sub(/[?#].*\z/, "").sub(%r{\Ahttps?://[^/]+}i, "").sub(%r{/+\z}, "")
          return here.empty? if there.empty?

          here == there || here.start_with?("#{there}/")
        end
      end
    end
  end
end
