# frozen_string_literal: true

require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # What an admin typed in the editor: a name, a base design system and some overrides.
    # It sorts the typed values into valid overrides and errors, and builds the token set they give.
    # Nothing is stored here. The preview and the save both go through this class.
    class CustomDraft
      ID = "custom"
      MAX_INPUT = 400

      attr_reader :base, :errors

      def initialize(base:, name:, overrides:)
        @base = base
        @raw_name = name
        @raw = overrides.is_a?(Hash) ? overrides : {}
        @errors = []
        @overrides = clean
        @errors << "name" unless self.name
        @errors.freeze
      end

      def name
        Tokens::Validator.label(@raw_name, max: 80)
      end

      # The valid overrides: token key to cleaned value. A value equal to the base is not an override.
      def overrides
        @overrides
      end

      def valid?
        errors.empty?
      end

      def error?(key)
        errors.include?(key)
      end

      # What goes back into the field: the cleaned override, or the refused text so it can be corrected.
      # A refused value is only ever shown as escaped text in an input. It never reaches CSS.
      def field_value(key)
        return overrides[key] if overrides.key?(key)

        error?(key) ? @raw[key].to_s[0, MAX_INPUT] : ""
      end

      def overridden?(key)
        overrides.key?(key)
      end

      # The design system these overrides give. Invalid values are left out, so this is always safe to draw.
      # It keeps the logo of its base.
      def token_set
        Tokens::TokenSet.new(id: ID, name: name || base.name, tokens: overrides, base: base.tokens, dark: base.dark_tokens,
                             logo_file: base.logo_file, logo_inverse_file: base.logo_inverse_file, logo_licence: base.logo_licence)
      end

      # The shape the store keeps.
      def definition
        { "name" => name, "based_on" => base.id, "overrides" => overrides.dup }
      end

      private

      def clean
        Tokens::TokenSet::ALL_KINDS.each_with_object({}) do |(key, kind), result|
          given = @raw[key]
          next if given.nil? || (given.is_a?(String) && given.strip.empty?)

          value = given.is_a?(String) && given.length <= MAX_INPUT ? Tokens::Validator.public_send(kind, given) : nil
          if value.nil?
            @errors << key
          elsif value != base[key]
            result[key] = value
          end
        end.freeze
      end
    end
  end
end
