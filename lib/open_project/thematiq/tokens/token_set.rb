# frozen_string_literal: true

require "open_project/thematiq/tokens/validator"
require "open_project/thematiq/tokens/defaults"
require "open_project/thematiq/tokens/vocabulary"

module OpenProject
  module Thematiq
    module Tokens
      # One validated design system. Every value in #tokens has passed the Validator,
      # so the variable layer can write them to CSS as they are.
      #
      # The set shape, shared by the bundled catalogue, the export file and the import file:
      #   { "id": "...", "name": "...", "tokens": { eighteen roles },
      #     "logo": { "file": "...", "inverse_file": "...", "licence": "...", "redistributable": true },
      #     "dark": { "tokens": { colour roles for the dark theme },
      #               "vocabulary": { vocabulary values for the dark theme } },   optional
      #     "vocabulary": { thematiq names without "--nldesign-" => value },   optional, see Vocabulary
      #     "documentation_url": "https://..." }   optional, the design system's own documentation
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

        # Roles a set may have on top of the eighteen. They have no last resort value:
        # a set without one keeps what the plugin did before the role existed.
        #   menu            the background of the main menu. Without it the menu is white.
        #   pdf-cover-text  the text on the cover page of a PDF export. Without it the export keeps OpenProject's colour.
        OPTIONAL_KINDS = { "menu" => :color, "pdf-cover-text" => :color }.freeze
        ALL_KINDS = KINDS.merge(OPTIONAL_KINDS).freeze

        # Roles that only reach a printed page, which has no dark theme.
        PRINT_KEYS = %w[pdf-cover-text].freeze

        # "uploads" is a note an export file carries when the design system had uploaded files. They do not
        # travel in the file. Transfer writes and reads the note. A token set does not keep it.
        SET_KEYS = %w[id name tokens logo dark uploads vocabulary documentation_url].freeze
        LOGO_KEYS = %w[file inverse_file licence redistributable basis].freeze
        DARK_KEYS = (ALL_KINDS.select { |_key, kind| kind == :color }.keys - PRINT_KEYS).freeze
        ID = /\A[A-Za-z0-9][A-Za-z0-9._-]{0,63}\z/

        attr_reader :id, :name, :tokens, :dark_tokens, :vocabulary, :dark_vocabulary, :logo_file, :logo_inverse_file, :logo_licence,
                    :documentation_url, :rejected

        # The dark block as the catalogue writes it is { "tokens" => { roles } }. The roles on their own are
        # read as well. Either way only the colour roles count: radius and font do not change with the theme.
        def self.dark_roles(dark)
          dark.is_a?(Hash) && dark["tokens"].is_a?(Hash) ? dark["tokens"] : dark
        end

        # For an imported file: what is in its dark block that is not a role.
        def self.unknown_dark_keys(dark)
          return [] unless dark.is_a?(Hash)

          vocabulary = dark["vocabulary"]
          extra = dark.key?("tokens") ? dark.keys - %w[tokens vocabulary] : []
          extra += vocabulary.is_a?(Hash) ? vocabulary.keys - Vocabulary.keys : ["vocabulary"] if dark.key?("tokens") && dark.key?("vocabulary")
          extra + ((dark_roles(dark) || {}).keys - ALL_KINDS.keys)
        end

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
          raise InvalidSet, "dark_invalid" unless set["dark"].nil? || set["dark"].is_a?(Hash)
          raise InvalidSet, "uploads_invalid" unless set["uploads"].nil? || set["uploads"].is_a?(Hash)
          raise InvalidSet, "vocabulary_invalid" unless set["vocabulary"].nil? || set["vocabulary"].is_a?(Hash)

          if strict
            unknown = (set.keys - SET_KEYS) + (tokens.keys - ALL_KINDS.keys) + (logo.keys - LOGO_KEYS) +
                      unknown_dark_keys(set["dark"]) + ((set["vocabulary"] || {}).keys - Vocabulary.keys)
            raise InvalidSet, "unknown_keys" if unknown.any?
            raise InvalidSet, "name_invalid" unless Validator.label(set["name"])
            raise InvalidSet, "documentation_url_invalid" unless set["documentation_url"].nil? || Validator.web_address(set["documentation_url"])
          end

          token_set = new(id: set["id"], name: Validator.label(set["name"]) || set["id"], tokens:, base:, dark: set["dark"],
                          vocabulary: set["vocabulary"],
                          logo_file: logo["redistributable"] == true ? Validator.file_name(logo["file"]) : nil,
                          logo_inverse_file: logo["redistributable"] == true ? Validator.file_name(logo["inverse_file"]) : nil,
                          logo_licence: Validator.label(logo["licence"], max: 300),
                          documentation_url: Validator.web_address(set["documentation_url"]))
          raise InvalidSet, "token_invalid" if strict && token_set.rejected.any?

          token_set
        end

        def initialize(id:, name:, tokens:, base: Defaults::TOKENS, dark: nil, vocabulary: nil, logo_file: nil, logo_inverse_file: nil,
                       logo_licence: nil, documentation_url: nil)
          @id = id
          @documentation_url = Validator.web_address(documentation_url)
          @name = name
          @logo_file = logo_file
          @logo_inverse_file = logo_inverse_file
          @logo_licence = logo_licence
          @rejected = []
          @tokens = clean(tokens, base).freeze
          @dark_tokens = clean_dark(dark).freeze
          @vocabulary = clean_vocabulary(vocabulary).freeze
          @dark_vocabulary = clean_vocabulary(dark.is_a?(Hash) && dark.key?("tokens") ? dark["vocabulary"] : nil, prefix: "dark.").freeze
          @rejected.freeze
        end

        # The value of a role, or of a vocabulary key. The two sets of names never overlap.
        def [](key)
          tokens[key] || vocabulary[key]
        end

        # True when the design system brings its own colours for the dark theme.
        def dark?
          !dark_tokens.empty?
        end

        # The set shape. This is what an export file holds.
        def to_set
          set = { "id" => id, "name" => name, "tokens" => tokens.dup,
                  "logo" => { "file" => logo_file, "inverse_file" => logo_inverse_file, "licence" => logo_licence,
                              "redistributable" => !logo_file.nil? } }
          set["dark"] = { "tokens" => dark_tokens.dup } if dark?
          (set["dark"] ||= { "tokens" => {} })["vocabulary"] = dark_vocabulary.dup if dark_vocabulary.any?
          # Only when there is one, so a set without a vocabulary exports exactly as before.
          set["vocabulary"] = vocabulary.dup if vocabulary.any?
          set["documentation_url"] = documentation_url if documentation_url
          set
        end

        private

        # The optional vocabulary: no fallback and nothing derived. A key it does not name keeps
        # OpenProject's own value. A value that fails is left out and listed in #rejected.
        # Unknown keys are left out here; strict mode has refused them already.
        def clean_vocabulary(raw, prefix: "")
          return {} unless raw.is_a?(Hash)

          Vocabulary::KINDS.each_with_object({}) do |(key, kind), result|
            given = raw[key]
            next if given.nil?

            value = given.is_a?(String) && given.length <= Validator::MAX_FONT_STACK_LENGTH ? Validator.public_send(kind, given) : nil
            value ? result[key] = value : @rejected << "#{prefix}vocabulary.#{key}"
          end
        end

        # The optional dark block: colour roles only, no fallback. A role it does not name, or names with
        # a value that fails, stays OpenProject's own dark colour.
        def clean_dark(raw)
          raw = self.class.dark_roles(raw)
          return {} unless raw.is_a?(Hash)

          DARK_KEYS.each_with_object({}) do |key, result|
            given = raw[key]
            value = Validator.color(given)
            @rejected << "dark.#{key}" if !given.nil? && value.nil?
            result[key] = value if value
          end
        end

        def clean(raw, base)
          ALL_KINDS.each_with_object({}) do |(key, kind), result|
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
