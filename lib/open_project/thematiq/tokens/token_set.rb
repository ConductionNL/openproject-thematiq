# frozen_string_literal: true

require "uri"
require "open_project/thematiq/tokens/validator"
require "open_project/thematiq/tokens/defaults"

module OpenProject
  module Thematiq
    module Tokens
      # One validated token set. Every value in #tokens has passed the Validator,
      # so the variable layer can write them to CSS as they are.
      class TokenSet
        class InvalidPayload < StandardError; end

        SUPPORTED_VERSION = 1

        # The contract of GET <nextcloud>/apps/thematiq/api/shell-tokens.
        KINDS = {
          "primary" => :color, "primary-deep" => :color, "primary-light" => :color,
          "action" => :color, "action-deep" => :color, "link" => :color, "accent" => :color,
          "ink" => :color, "text" => :color, "muted" => :color, "line" => :color, "soft" => :color,
          "ground" => :color, "chip" => :color, "field" => :color,
          "radius" => :length, "radius-lg" => :length,
          "font-family" => :font_family
        }.freeze

        attr_reader :id, :name, :revision, :tokens, :logo_url, :logo_inverse_url, :rejected

        def self.bundled
          @bundled ||= new(id: Defaults::ID, name: Defaults::NAME, revision: Defaults::REVISION,
                           tokens: Defaults::TOKENS, bundled: true)
        end

        # Builds a token set from the JSON thematiq returned, or from the copy the plugin stored.
        # A value that fails validation falls back to the bundled value and its key is listed in #rejected.
        # Raises InvalidPayload when the document itself does not follow the contract.
        def self.from_payload(payload)
          raise InvalidPayload, "not_an_object" unless payload.is_a?(Hash)
          raise InvalidPayload, "unsupported_version" unless payload["version"] == SUPPORTED_VERSION
          raise InvalidPayload, "tokens_missing" unless payload["tokens"].is_a?(Hash)

          id = Validator.label(payload["id"])
          revision = Validator.label(payload["revision"], max: 200)
          raise InvalidPayload, "id_missing" unless id
          raise InvalidPayload, "revision_missing" unless revision

          logo = payload["logo"].is_a?(Hash) ? payload["logo"] : {}
          new(id:, revision:,
              name: Validator.label(payload["name"]) || id,
              tokens: payload["tokens"],
              logo_url: Validator.absolute_http_url(logo["url"]),
              logo_inverse_url: Validator.absolute_http_url(logo["inverse_url"]))
        end

        def initialize(id:, name:, revision:, tokens:, logo_url: nil, logo_inverse_url: nil, bundled: false)
          @id = id
          @name = name
          @revision = revision
          @logo_url = logo_url
          @logo_inverse_url = logo_inverse_url
          @bundled = bundled
          @rejected = []
          @tokens = clean(tokens).freeze
          @rejected.freeze
        end

        def bundled?
          @bundled
        end

        def [](key)
          tokens[key]
        end

        # The shape that is stored and that .from_payload reads back.
        def to_payload
          { "version" => SUPPORTED_VERSION, "id" => id, "name" => name, "revision" => revision,
            "tokens" => tokens.dup, "logo" => { "url" => logo_url, "inverse_url" => logo_inverse_url } }
        end

        private

        def clean(raw)
          KINDS.each_with_object({}) do |(key, kind), result|
            value = raw.key?(key) ? Validator.public_send(kind, raw[key]) : nil
            @rejected << key if raw.key?(key) && !raw[key].nil? && value.nil?
            value ||= Defaults::TOKENS[key]
            result[key] = value if value
          end
        end
      end
    end
  end
end
