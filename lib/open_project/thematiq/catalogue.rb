# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"

module OpenProject
  module Thematiq
    # The design systems that ship with the plugin, read from one JSON file in the gem:
    #   { "version": 1, "generated_from": "...", "sets": [ set, ... ], "fonts": [ ... ] }
    #
    # The file is not trusted more than any other input. Every set goes through TokenSet,
    # and so through the Validator. A set that does not have the set shape is skipped.
    # Loading never raises: when the file cannot be used the catalogue holds the last resort set.
    class Catalogue
      DIRECTORY = File.expand_path("../../../data/catalogue", __dir__)
      FILE = File.join(DIRECTORY, "shell-catalogue.json")
      # The logos sit in public/, because the plugin serves them as static files.
      # Design systems written for this plugin, not generated: OpenProject's own colour themes.
      OWN_FILE = File.join(DIRECTORY, "openproject-themes.json")
      LOGO_DIRECTORY = File.expand_path("../../../public/thematiq/logos", __dir__)

      SUPPORTED_VERSION = 1
      DEFAULT_ID = "cunningham"
      RESERVED_ID = "custom"
      MAX_BYTES = 4 * 1024 * 1024
      MAX_SETS = 1000

      # sets: the usable token sets. skipped: how many entries were refused.
      # error: nil, or a short code that says why the file could not be used.
      attr_reader :sets, :skipped, :generated_from, :error

      # The catalogue generated from thematiq, plus the sets of the plugin's own making.
      # The second file can only add sets. An id the first file has already is skipped.
      def self.bundled
        @bundled ||= load(FILE).with(load(OWN_FILE))
      end

      def self.load(path, logo_directory: LOGO_DIRECTORY)
        return failed("missing") unless File.file?(path)
        return failed("too_large") if File.size(path) > MAX_BYTES

        from_document(JSON.parse(File.read(path)), logo_directory:)
      rescue JSON::ParserError, EncodingError
        failed("invalid_json")
      rescue SystemCallError
        failed("unreadable")
      end

      def self.from_document(document, logo_directory: LOGO_DIRECTORY)
        return failed("not_an_object") unless document.is_a?(Hash)
        return failed("unsupported_version") unless document["version"] == SUPPORTED_VERSION
        return failed("sets_missing") unless document["sets"].is_a?(Array)
        return failed("too_many_sets") if document["sets"].size > MAX_SETS

        sets = {}
        skipped = 0
        document["sets"].each do |entry|
          token_set = Tokens::TokenSet.from_set(entry)
          # "custom" is the id of the set an admin makes in the editor.
          sets.key?(token_set.id) || token_set.id == RESERVED_ID ? skipped += 1 : sets[token_set.id] = token_set
        rescue Tokens::TokenSet::InvalidSet
          skipped += 1
        end
        return failed("no_usable_sets") if sets.empty?

        new(sets: sets.values, skipped:, logo_directory:,
            generated_from: Tokens::Validator.label(document["generated_from"], max: 300))
      end

      def self.failed(error)
        new(sets: [Tokens::TokenSet.fallback], error:)
      end

      def initialize(sets:, skipped: 0, generated_from: nil, error: nil, logo_directory: LOGO_DIRECTORY)
        @sets = order(sets).freeze
        @by_id = @sets.to_h { |token_set| [token_set.id, token_set] }.freeze
        @skipped = skipped
        @generated_from = generated_from
        @error = error
        @logo_directory = logo_directory
      end

      # This catalogue with the usable sets of another one added. A failed other catalogue adds nothing.
      def with(other)
        return self if other.error

        added = other.sets.reject { |token_set| @by_id.key?(token_set.id) }
        self.class.new(sets: sets + added, skipped: skipped + other.skipped + (other.sets.size - added.size),
                       generated_from:, error:, logo_directory: @logo_directory)
      end

      # True for a set of the plugin's own making, as opposed to one generated from thematiq.
      def self.own_ids
        @own_ids ||= load(OWN_FILE).then { |own| own.error ? [] : own.sets.map(&:id) }.freeze
      end

      def find(id)
        id.is_a?(String) ? @by_id[id] : nil
      end

      # The set a fresh install uses: Cunningham, or the first set when the catalogue has no Cunningham.
      def default
        find(DEFAULT_ID) || sets.first
      end

      # The sets whose name or id holds every word of the query. An empty query gives every set.
      def search(query)
        words = query.to_s.downcase.split.first(8)
        return sets if words.empty?

        sets.select do |token_set|
          haystack = "#{token_set.name} #{token_set.id}".downcase
          words.all? { |word| haystack.include?(word) }
        end
      end

      # The path of a set's bundled logo, or nil when the set has none. Then OpenProject's own logo stays.
      def logo_path(token_set, inverse: false)
        name = inverse ? token_set.logo_inverse_file : token_set.logo_file
        return nil unless name

        path = File.join(@logo_directory, name)
        File.file?(path) ? path : nil
      end

      private

      # The default first, then by name.
      def order(sets)
        sets.sort_by { |token_set| [token_set.id == DEFAULT_ID ? 0 : 1, token_set.name.downcase, token_set.id] }
      end
    end
  end
end
