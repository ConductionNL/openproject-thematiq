# frozen_string_literal: true

require "json"
require "open_project/thematiq/tokens"
require "open_project/thematiq/catalogue"
require "open_project/thematiq/custom_draft"
require "open_project/thematiq/uploads"

module OpenProject
  module Thematiq
    # The logo, icon and font files of a design system, and the address of each.
    #
    # There are two sources. The files in the plugin's own public/ folder: it only ever names a file that is
    # in that folder and that the catalogue marks redistributable. And the files an administrator uploaded
    # for a custom design system, which come as Uploads::Record and are served by id. An upload wins.
    #
    # A design system with neither keeps OpenProject's logo and icons. A font that is in neither is left
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

      # Where the uploaded files come from: something that answers call(set_id) with a list of Uploads::Record.
      # The engine points it at the plugin's table. Without Rails there are no uploads.
      class << self
        attr_writer :upload_source

        def upload_source
          @upload_source || ->(_set_id) { [] }
        end
      end

      # The uploaded files of a design system. Only a custom design system has any. It never raises:
      # when the table cannot be read, the page is drawn as if nothing was uploaded.
      def self.uploads_for(token_set)
        return [] unless token_set.id.is_a?(String) && CustomDraft::ID_PATTERN.match?(token_set.id)

        records = upload_source.call(token_set.id)
        records.is_a?(Array) ? records.select { |record| record.is_a?(Uploads::Record) && record.set_id == token_set.id && record.usable? } : []
      rescue StandardError
        []
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
      # An uploaded logo wins over a bundled one, and there too the variant for the coloured bar comes first.
      def logo_url(token_set, root: "", uploads: self.class.uploads_for(token_set))
        uploaded = %w[logo_inverse logo].filter_map { |kind| upload(uploads, kind) }.first
        return uploaded.url(root:) if uploaded

        file = [token_set.logo_inverse_file, token_set.logo_file].compact.find do |name|
          File.file?(File.join(Catalogue::LOGO_DIRECTORY, name))
        end
        file ? "#{root}#{URL_PREFIX}/logos/#{file}" : nil
      end

      # The address of the logo for narrow screens, or nil. Only an upload gives one: the catalogue has none.
      def mobile_logo_url(token_set, root: "", uploads: self.class.uploads_for(token_set))
        upload(uploads, "logo_mobile")&.url(root:)
      end

      # --- icons ---

      # The link elements for the page head: the favicon and the touch icon, when they were uploaded.
      # Each is a hash of plain attributes. The address is the plugin's own, the type and size were read from the file.
      def icon_links(token_set, root: "", uploads: self.class.uploads_for(token_set))
        { "favicon" => "icon", "touch_icon" => "apple-touch-icon" }.filter_map do |kind, rel|
          record = upload(uploads, kind)
          next nil unless record

          sizes = record.width && record.height ? "#{record.width.to_i}x#{record.height.to_i}" : "any"
          { rel:, href: record.url(root:), type: record.content_type, sizes: }
        end
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

      # The uploaded font files of a design system, as records.
      def uploaded_fonts(token_set, uploads: self.class.uploads_for(token_set))
        uploads.select { |record| record.kind == "font" && record.face }
      end

      def uploaded_family?(token_set, family, uploads: self.class.uploads_for(token_set))
        uploaded_fonts(token_set, uploads:).any? { |record| record.face.family.casecmp?(family.to_s) }
      end

      # The @font-face rules for a design system: its bundled families, then its uploaded fonts.
      # A family that was uploaded is not loaded from the bundle as well, so the upload wins.
      # Empty when none of its fonts is bundled or uploaded.
      def font_face_css(token_set, root: "", uploads: self.class.uploads_for(token_set))
        uploaded = uploaded_fonts(token_set, uploads:)
        own = uploaded.map { |record| record.face.family.downcase }
        bundled = faces(token_set).reject { |face| own.include?(face.family.downcase) }.map do |face|
          "@font-face { font-family: '#{face.family}'; font-style: #{face.style}; font-weight: #{face.weight}; " \
            "font-display: swap; src: url(#{root}#{URL_PREFIX}/fonts/#{face.file}) format('woff2'); }"
        end
        (bundled + uploaded.map { |record| Uploads::FontFace.css(record, root:) }).reject(&:empty?).join("\n")
      end

      private

      # The one file of a kind among the uploads. The newest, should there ever be two.
      def upload(uploads, kind)
        uploads.reverse.find { |record| record.kind == kind }
      end

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
