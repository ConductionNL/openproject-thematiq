# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"
require "open_project/thematiq/uploads"

module OpenProject
  module Thematiq
    # Export and import of one design system as a JSON file in the set shape,
    # so an admin can move a custom design system between installations.
    #
    # Uploaded files do not travel in the file: logos, icons and fonts stay on the installation they were
    # uploaded to. A font file is often not free to pass on, and the file would grow from a few KB to many MB.
    # The export says so in an "uploads" entry that names the kinds left behind, and the import reads that
    # entry only to tell the administrator which files to upload again.
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

      UPLOADS_NOTE = "This design system has uploaded files. They are not in this file. " \
                     "Upload them again after you import it."

      # uploads: the Uploads::Record list of the design system. Only their kinds are written.
      def export(token_set, uploads: [])
        set = token_set.to_set
        kinds = left_behind_kinds(uploads.map(&:kind))
        set["uploads"] = { "included" => false, "note" => UPLOADS_NOTE, "kinds" => kinds } if kinds.any?
        "#{JSON.pretty_generate(set)}\n"
      end

      # The kinds of file an export file says it left behind. Empty for a file without the note, and for
      # anything that cannot be read: this only feeds a message, import decides about the file.
      def left_behind(text)
        set = JSON.parse(text.to_s.dup.force_encoding(Encoding::UTF_8), max_nesting: MAX_NESTING)
        set.is_a?(Hash) && set["uploads"].is_a?(Hash) ? left_behind_kinds(set["uploads"]["kinds"]) : []
      rescue JSON::ParserError, JSON::NestingError, ArgumentError, EncodingError
        []
      end

      def left_behind_kinds(kinds)
        kinds.is_a?(Array) ? Uploads::KINDS.keys & kinds : []
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
