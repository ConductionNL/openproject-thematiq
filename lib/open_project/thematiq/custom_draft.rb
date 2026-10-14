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
      # A value may name another token of the same kind, {primary} or {color-error} (aut-semantic-aliases). It is kept
      # as the reference and follows that token: change the primary, and every value that names it changes with it.
      REFERENCE = /\A\{([a-z0-9-]{1,80})\}\z/
      MAX_HOPS = 8

      attr_reader :base, :errors, :id

      # logo: the logo reference an imported file brought along, { "file" => ..., "inverse_file" => ... }.
      # It only counts when it names a file the plugin has. Without it the draft keeps the logo of its base.
      # dark: colours for the dark theme, role to value, from an imported file or the editor's dark fields. They go
      # on top of the dark colours of the base. A role with no dark value keeps the base's, else OpenProject's own.
      # overrides may hold roles and vocabulary keys alike: the two sets of names never overlap.
      # vocabulary: vocabulary values given apart, as an import or a stored definition holds them.
      # dark_vocabulary: vocabulary values for the dark theme, from an imported file or the editor. They go on top of
      # the dark vocabulary of the base.
      # dark_errors: true for the editor's dark fields. Then a dark value that fails is an error under "dark.<key>",
      # like a light one under its key. Without it such a value is left out, as before the fields existed.
      # Nothing is derived from a light value.
      # lock_primary: the main button follows the primary colour (thematiq's primary lock). Then action and action-deep
      # take primary and primary-deep, whatever they hold, and the stored overrides of the two are kept for when it is off.
      def initialize(base:, name:, overrides:, id: ID, logo: nil, dark: nil, vocabulary: nil, dark_vocabulary: nil, dark_errors: false,
                     lock_primary: false)
        @base = base
        @id = id.is_a?(String) && ID_PATTERN.match?(id) ? id : ID
        @logo = logo.is_a?(Hash) ? logo : {}
        @raw_name = name
        @raw = (vocabulary.is_a?(Hash) ? vocabulary.select { |key, _| Tokens::Vocabulary.key?(key) } : {})
               .merge(overrides.is_a?(Hash) ? overrides : {})
        @errors = []
        @lock_primary = lock_primary == true
        @raw_dark = {}
        @dark_errors = dark_errors
        @dark = clean_dark(dark)
        @dark_vocabulary = clean_dark_vocabulary(dark_vocabulary)
        @overrides = clean(Tokens::TokenSet::ALL_KINDS)
        @vocabulary = clean(Tokens::Vocabulary::KINDS)
        @errors << "name" unless self.name
        @errors.freeze
      end

      def name
        Tokens::Validator.label(@raw_name, max: 80)
      end

      def lock_primary?
        @lock_primary
      end

      LOCKED = { "action" => "primary", "action-deep" => "primary-deep" }.freeze

      # The valid overrides of the roles: token key to cleaned value. A value equal to the base is not an override.
      attr_reader :overrides

      # The valid vocabulary values that differ from the base: key to cleaned value.
      attr_reader :vocabulary

      # How many values differ from the base, roles and vocabulary together, light and dark.
      def changed_count
        overrides.size + vocabulary.size + dark.size + dark_vocabulary.size
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
        return vocabulary[key] if vocabulary.key?(key)

        error?(key) ? @raw[key].to_s[0, MAX_INPUT] : ""
      end

      def overridden?(key)
        overrides.key?(key) || vocabulary.key?(key)
      end

      # True when the key has a dark value of its own in this draft.
      def dark_overridden?(key)
        dark.key?(key) || dark_vocabulary.key?(key)
      end

      # What goes back into a dark field, like #field_value.
      def dark_field_value(key)
        return dark[key] if dark.key?(key)
        return dark_vocabulary[key] if dark_vocabulary.key?(key)

        error?(self.class.dark_error(key)) ? @raw_dark[key].to_s[0, MAX_INPUT] : ""
      end

      # The dark value of the base for a key, or nil when the base has none and OpenProject's own stays.
      def base_dark(key)
        base.dark_tokens[key] || base.dark_vocabulary[key]
      end

      # The error name of a dark value.
      def self.dark_error(key)
        "dark.#{key}"
      end

      # The design system these overrides give. Invalid values are left out, so this is always safe to draw.
      # It keeps the logo of its base.
      def token_set
        Tokens::TokenSet.new(id:, name: name || base.name, tokens: locked(resolved(overrides)), base: base.tokens,
                             dark: { "tokens" => base.dark_tokens.merge(dark), "vocabulary" => base.dark_vocabulary.merge(dark_vocabulary) },
                             vocabulary: base.vocabulary.merge(resolved(vocabulary)),
                             logo_file: logo_file || base.logo_file,
                             logo_inverse_file: logo_file ? logo_inverse_file : base.logo_inverse_file,
                             logo_licence: base.logo_licence)
      end

      # The shape the store keeps.
      def definition
        definition = { "name" => name, "based_on" => base.id, "overrides" => overrides.dup }
        definition["logo"] = { "file" => logo_file, "inverse_file" => logo_inverse_file } if logo_file
        definition["dark"] = dark.dup if dark.any?
        definition["vocabulary"] = vocabulary.dup if vocabulary.any?
        definition["dark_vocabulary"] = dark_vocabulary.dup if dark_vocabulary.any?
        definition["lock_primary"] = true if lock_primary?
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

      # The valid dark vocabulary values this draft brought along, that differ from the base's.
      attr_reader :dark_vocabulary

      private

      # The values with every reference followed to a value, through this draft's own values and its base's.
      # A reference that leads nowhere or in a circle was refused in #clean, so this always ends.
      def resolved(values)
        values.transform_values { |value| follow(value) }.compact
      end

      def follow(value, hops = 0)
        match = REFERENCE.match(value.to_s)
        return value unless match
        return nil if hops > MAX_HOPS

        target = match[1]
        follow(@raw_values.fetch(target) { base[target] }, hops + 1)
      end

      # The overrides with the main button on the primary colour, when the lock is on.
      def locked(values)
        return values unless lock_primary?

        values.merge(LOCKED.to_h { |key, source| [key, values[source] || base[source]] }.compact)
      end

      # Every value this draft gives, cleaned or a reference, by key: what a reference is followed through.
      def reference_targets
        all = Tokens::TokenSet::ALL_KINDS.merge(Tokens::Vocabulary::KINDS)
        all.each_with_object({}) do |(key, kind), result|
          given = @raw[key]
          next unless given.is_a?(String) && !given.strip.empty? && given.length <= MAX_INPUT

          result[key] = REFERENCE.match?(given.strip) ? given.strip : Tokens::Validator.public_send(kind, given)
        end.compact
      end

      # A reference names another key of the same kind, and following it ends in a value within MAX_HOPS steps.
      def reference_ok?(key, kind, reference)
        all = Tokens::TokenSet::ALL_KINDS.merge(Tokens::Vocabulary::KINDS)
        seen = [key]
        current = reference
        (MAX_HOPS + 1).times do
          target = REFERENCE.match(current)[1]
          return false unless all[target] == kind && !seen.include?(target)

          seen << target
          current = @raw_values.fetch(target) { base[target] }
          return false if current.nil?
          return true unless REFERENCE.match?(current.to_s)
        end
        false
      end

      def clean_dark(raw)
        return {}.freeze unless raw.is_a?(Hash)

        Tokens::TokenSet::DARK_KEYS.each_with_object({}) do |key, result|
          value = clean_dark_value(raw[key], key, :color)
          result[key] = value if value && value != base.dark_tokens[key]
        end.freeze
      end

      def clean_dark_vocabulary(raw)
        return {}.freeze unless raw.is_a?(Hash)

        Tokens::Vocabulary::KINDS.each_with_object({}) do |(key, kind), result|
          value = clean_dark_value(raw[key], key, kind)
          result[key] = value if value && value != base.dark_vocabulary[key]
        end.freeze
      end

      # A dark value: nil for an empty one, the cleaned value, or nil with an error for one that fails.
      def clean_dark_value(given, key, kind)
        return nil if given.nil? || (given.is_a?(String) && given.strip.empty?)

        value = given.is_a?(String) && given.length <= MAX_INPUT ? Tokens::Validator.public_send(kind, given) : nil
        if value.nil? && @dark_errors
          @raw_dark[key] = given
          @errors << self.class.dark_error(key)
        end
        value
      end

      def clean(kinds)
        @raw_values ||= reference_targets
        kinds.each_with_object({}) do |(key, kind), result|
          given = @raw[key]
          next if given.nil? || (given.is_a?(String) && given.strip.empty?)

          if given.is_a?(String) && REFERENCE.match?(given.strip)
            reference_ok?(key, kind, given.strip) ? result[key] = given.strip : @errors << key
            next
          end
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
