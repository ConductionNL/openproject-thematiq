# frozen_string_literal: true

require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # What an admin typed in the editor: a name, a base design system and some overrides.
    # It sorts the typed values into valid overrides and errors, and builds the token set they give.
    # Nothing is stored here. The preview and the save both go through this class.
    class CustomDraft
      # The id of the first custom design system. Later ones are custom-2, custom-3 and so on.
      ID = "custom"
      ID_PATTERN = /\Acustom(?:-[1-9]\d{0,3})?\z/
      MAX_INPUT = 400

      attr_reader :base, :errors, :id

      # logo: the logo reference an imported file brought along, { "file" => ..., "inverse_file" => ... }.
      # It only counts when it names a file the plugin has. Without it the draft keeps the logo of its base.
      # dark: colours for the dark theme that an imported file brought along, role to value. They go on top of
      # the dark colours of the base. The editor has no fields for them yet.
      def initialize(base:, name:, overrides:, id: ID, logo: nil, dark: nil)
        @base = base
        @id = id.is_a?(String) && ID_PATTERN.match?(id) ? id : ID
        @logo = logo.is_a?(Hash) ? logo : {}
        @raw_name = name
        @raw = overrides.is_a?(Hash) ? overrides : {}
        @errors = []
        @dark = clean_dark(dark)
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
        Tokens::TokenSet.new(id:, name: name || base.name, tokens: overrides, base: base.tokens, dark: base.dark_tokens.merge(dark),
                             logo_file: logo_file || base.logo_file,
                             logo_inverse_file: logo_file ? logo_inverse_file : base.logo_inverse_file,
                             logo_licence: base.logo_licence)
      end

      # The shape the store keeps.
      def definition
        definition = { "name" => name, "based_on" => base.id, "overrides" => overrides.dup }
        definition["logo"] = { "file" => logo_file, "inverse_file" => logo_inverse_file } if logo_file
        definition["dark"] = dark.dup if dark.any?
        definition
      end

      # The file names of the logo this draft brought along, checked like any other file reference.
      def logo_file
        Tokens::Validator.file_name(@logo["file"])
      end

      def logo_inverse_file
        Tokens::Validator.file_name(@logo["inverse_file"])
      end

      # The valid dark colours this draft brought along. A value that fails is left out.
      attr_reader :dark

      private

      def clean_dark(raw)
        return {}.freeze unless raw.is_a?(Hash)

        Tokens::TokenSet::DARK_KEYS.each_with_object({}) do |key, result|
          given = raw[key]
          value = given.is_a?(String) && given.length <= MAX_INPUT ? Tokens::Validator.color(given) : nil
          result[key] = value if value && value != base.dark_tokens[key]
        end.freeze
      end

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
