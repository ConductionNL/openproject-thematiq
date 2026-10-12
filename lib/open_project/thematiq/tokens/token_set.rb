# frozen_string_literal: true

require "open_project/thematiq/tokens/validator"
require "open_project/thematiq/tokens/defaults"

module OpenProject
  module Thematiq
    module Tokens
      # One validated design system. Every value in #tokens has passed the Validator,
      # so the variable layer can write them to CSS as they are.
      #
      # The set shape, shared by the bundled catalogue, the export file and the import file:
      #   { "id": "...", "name": "...", "tokens": { eighteen roles },
      #     "logo": { "file": "...", "inverse_file": "...", "licence": "...", "redistributable": true } }
      class TokenSet
        class InvalidSet < StandardError; end

        # The eighteen roles and the kind of value each one takes.
        KINDS = {
          "primary" => :color, "primary-deep" => :color, "primary-light" => :color,
          "action" => :color, "action-deep" => :color, "link" => :color, "accent" => :color,
          "ink" => :color, "text" => :color, "muted" => :color, "line" => :color, "soft" => :color,
          "ground" => :color, "chip" => :color, "field" => :color,
          "radius" => :length, "radius-lg" => :length,
          "font-family" => :font_family
        }.freeze

        SET_KEYS = %w[id name tokens logo].freeze
        LOGO_KEYS = %w[file inverse_file licence redistributable].freeze
        ID = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/

        attr_reader :id, :name, :tokens, :logo_file, :logo_inverse_file, :logo_licence, :rejected

        # The last resort: the values in Defaults. Used when the catalogue cannot be read.
        def self.fallback
          @fallback ||= new(id: Defaults::ID, name: Defaults::NAME, tokens: Defaults::TOKENS)
        end

        # Builds a token set from a hash in the set shape.
        #
        # Default mode, for the bundled catalogue and the stored custom set: a value that fails
        # validation falls back to the value in +base+ and its key is listed in #rejected.
        #
        # Strict mode, for an imported file: an unknown key or a value that fails validation
        # refuses the whole set.
        #
        # Raises InvalidSet with a short code when the hash does not have the set shape.
        def self.from_set(set, strict: false, base: Defaults::TOKENS)
          raise InvalidSet, "not_an_object" unless set.is_a?(Hash)

          tokens = set["tokens"]
          logo = set["logo"].nil? ? {} : set["logo"]
          raise InvalidSet, "id_invalid" unless set["id"].is_a?(String) && ID.match?(set["id"])
          raise InvalidSet, "tokens_missing" unless tokens.is_a?(Hash)
          raise InvalidSet, "logo_invalid" unless logo.is_a?(Hash)

          if strict
            unknown = (set.keys - SET_KEYS) + (tokens.keys - KINDS.keys) + (logo.keys - LOGO_KEYS)
            raise InvalidSet, "unknown_keys" if unknown.any?
            raise InvalidSet, "name_invalid" unless Validator.label(set["name"])
          end

          token_set = new(id: set["id"], name: Validator.label(set["name"]) || set["id"], tokens:, base:,
                          logo_file: logo["redistributable"] == true ? Validator.file_name(logo["file"]) : nil,
                          logo_inverse_file: logo["redistributable"] == true ? Validator.file_name(logo["inverse_file"]) : nil,
                          logo_licence: Validator.label(logo["licence"]))
          raise InvalidSet, "token_invalid" if strict && token_set.rejected.any?

          token_set
        end

        def initialize(id:, name:, tokens:, base: Defaults::TOKENS, logo_file: nil, logo_inverse_file: nil, logo_licence: nil)
          @id = id
          @name = name
          @logo_file = logo_file
          @logo_inverse_file = logo_inverse_file
          @logo_licence = logo_licence
          @rejected = []
          @tokens = clean(tokens, base).freeze
          @rejected.freeze
        end

        def [](key)
          tokens[key]
        end

        # The set shape. This is what an export file holds.
        def to_set
          { "id" => id, "name" => name, "tokens" => tokens.dup,
            "logo" => { "file" => logo_file, "inverse_file" => logo_inverse_file, "licence" => logo_licence,
                        "redistributable" => !logo_file.nil? } }
        end

        private

        def clean(raw, base)
          KINDS.each_with_object({}) do |(key, kind), result|
            given = raw[key]
            value = Validator.public_send(kind, given)
            @rejected << key if !given.nil? && value.nil?
            value ||= Validator.public_send(kind, base[key])
            result[key] = value if value
          end
        end
      end
    end
  end
end
