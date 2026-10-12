# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # Export and import of one design system as a JSON file in the set shape,
    # so an admin can move a custom design system between installations.
    #
    # An imported file is hostile input. It has a size cap, it must be one JSON object in the set
    # shape with no unknown key, and every value must pass the Validator. One bad value refuses the file.
    module Transfer
      MAX_BYTES = 64 * 1024
      MAX_NESTING = 4

      # code: a short word the admin page translates.
      class Refused < StandardError
        def code = message
      end

      module_function

      def export(token_set)
        "#{JSON.pretty_generate(token_set.to_set)}\n"
      end

      def file_name(token_set)
        "thematiq-#{token_set.id.gsub(/[^A-Za-z0-9_-]/, '-')}.json"
      end

      # Returns a TokenSet, or raises Refused.
      def import(text)
        raise Refused, "empty" unless text.is_a?(String) && !text.strip.empty?
        raise Refused, "too_large" if text.bytesize > MAX_BYTES

        text = text.dup.force_encoding(Encoding::UTF_8)
        raise Refused, "invalid_json" unless text.valid_encoding?

        Tokens::TokenSet.from_set(JSON.parse(text, max_nesting: MAX_NESTING), strict: true)
      rescue JSON::ParserError, JSON::NestingError
        raise Refused, "invalid_json"
      rescue Tokens::TokenSet::InvalidSet => e
        raise Refused, e.message
      end
    end
  end
end
