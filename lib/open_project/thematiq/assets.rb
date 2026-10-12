# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"
require "open_project/thematiq/catalogue"

module OpenProject
  module Thematiq
    # The logo and font files the plugin serves from its own public/ folder.
    #
    # It only ever names a file that is in that folder and that the catalogue marks redistributable.
    # A design system whose logo is not there keeps OpenProject's logo. A font that is not there is left
    # to the reader's device, and the page falls through the font stack as usual.
    class Assets
      PUBLIC_DIRECTORY = File.expand_path("../../../public", __dir__)
      FONT_DIRECTORY = File.join(PUBLIC_DIRECTORY, "thematiq", "fonts")
      URL_PREFIX = "/thematiq"

      FONT_FILE = /\A([a-z0-9]+(?:-[a-z0-9]+)*)-latin-(?:(\d{3})-(normal|italic)|(variable))\.woff2\z/
      GENERIC_FAMILIES = %w[serif sans-serif monospace cursive fantasy system-ui ui-serif ui-sans-serif ui-monospace
                            ui-rounded emoji math fangsong -apple-system blinkmacsystemfont].freeze

      Face = Struct.new(:family, :file, :weight, :style, keyword_init: true)

      def self.bundled
        @bundled ||= new(catalogue: Catalogue.bundled, fonts: read_fonts(Catalogue::FILE))
      end

      def self.read_fonts(path)
        document = JSON.parse(File.read(path))
        document.is_a?(Hash) && document["fonts"].is_a?(Array) ? document["fonts"] : []
      rescue JSON::ParserError, SystemCallError
        []
      end

      def initialize(catalogue:, fonts:, font_directory: FONT_DIRECTORY)
        @catalogue = catalogue
        @font_directory = font_directory
        @faces = build_faces(fonts).freeze
      end

      # --- logos ---

      # The address of the logo for the top bar, or nil. The top bar has the primary colour as background,
      # so the variant for dark backgrounds comes first.
      def logo_url(token_set, root: "")
        file = [token_set.logo_inverse_file, token_set.logo_file].compact.find do |name|
          File.file?(File.join(Catalogue::LOGO_DIRECTORY, name))
        end
        file ? "#{root}#{URL_PREFIX}/logos/#{file}" : nil
      end

      # --- fonts ---

      # The families of a font stack, without quotes, in order.
      def families(token_set)
        token_set["font-family"].to_s.split(",").map { |family| family.strip.delete("'\"") }.reject(&:empty?)
      end

      # The first family of the stack that is a real font and not a generic keyword.
      def named_family(token_set)
        families(token_set).find { |family| !GENERIC_FAMILIES.include?(family.downcase) }
      end

      def bundled_family?(family)
        @faces.key?(family.to_s.downcase)
      end

      # The font files to load for a design system: every bundled family in its stack.
      def faces(token_set)
        families(token_set).flat_map { |family| @faces.fetch(family.downcase, []) }
      end

      # The @font-face rules for a design system. Empty when none of its fonts is bundled.
      def font_face_css(token_set, root: "")
        faces(token_set).map do |face|
          "@font-face { font-family: '#{face.family}'; font-style: #{face.style}; font-weight: #{face.weight}; " \
            "font-display: swap; src: url(#{root}#{URL_PREFIX}/fonts/#{face.file}) format('woff2'); }"
        end.join("\n")
      end

      private

      # Only families the catalogue marks redistributable, only files of the expected name that are on disk.
      def build_faces(fonts)
        fonts.each_with_object({}) do |font, result|
          next unless font.is_a?(Hash) && font["redistributable"] == true && font["files"].is_a?(Array)

          family = Tokens::Validator.font_family(font["family"].is_a?(String) ? "'#{font['family']}'" : nil)
          next unless family

          name = family.delete("'")
          faces = font["files"].filter_map { |path| face(name, path) }.uniq(&:file)
          result[name.downcase] = faces.sort_by { |f| [f.style, f.weight.to_s] } if faces.any?
        end
      end

      def face(family, path)
        return nil unless path.is_a?(String)

        file = File.basename(path)
        match = FONT_FILE.match(file)
        return nil unless match && File.file?(File.join(@font_directory, file))

        Face.new(family:, file:, weight: match[4] ? "100 900" : match[2], style: match[3] || "normal")
      end
    end
  end
end
