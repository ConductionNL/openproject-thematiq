# frozen_string_literal: true

require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # What changes when one design system replaces another: every value that differs, light and dark.
    # The apply dialog shows these rows, and an administrator may keep any of them (choose what changes).
    module Diff
      # layer: "light" or "dark". from and to: the values, nil where a design system leaves the key to OpenProject.
      Row = Struct.new(:key, :layer, :from, :to, keyword_init: true) do
        # The name the form sends for this row.
        def id
          layer == "dark" ? "dark.#{key}" : key
        end

        # A value can only be kept when the current design system has one. "OpenProject's own" cannot be written
        # on top of a design system that fills the key.
        def keepable?
          !from.nil?
        end

        def role?
          Tokens::TokenSet::ALL_KINDS.key?(key)
        end
      end

      module_function

      def between(current, chosen)
        light = keys.filter_map do |key|
          from = current[key]
          to = chosen[key]
          Row.new(key:, layer: "light", from:, to:) if from != to
        end
        dark = keys.filter_map do |key|
          from = dark_value(current, key)
          to = dark_value(chosen, key)
          Row.new(key:, layer: "dark", from:, to:) if from != to
        end
        light + dark
      end

      def keys
        Tokens::TokenSet::ALL_KINDS.keys + Tokens::Vocabulary.keys
      end

      def dark_value(token_set, key)
        token_set.dark_tokens[key] || token_set.dark_vocabulary[key]
      end

      # The values to keep from the current design system: the rows the administrator did not tick, that can be kept.
      # taken: the row ids that were ticked. Returns [light values, dark values], key to value.
      def kept(rows, taken)
        taken = Array(taken).map(&:to_s)
        left = rows.reject { |row| taken.include?(row.id) }.select(&:keepable?)
        [left.select { |row| row.layer == "light" }.to_h { |row| [row.key, row.from] },
         left.select { |row| row.layer == "dark" }.to_h { |row| [row.key, row.from] }]
      end
    end
  end
end
