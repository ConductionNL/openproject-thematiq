# frozen_string_literal: true

module OpenProject
  module Thematiq
    module Uploads
      # One stored file without its bytes. The model builds these, and so do the tests.
      # A record that does not hold together is never built: Record.build returns nil for it.
      Record = Struct.new(:token, :set_id, :kind, :format, :byte_size, :width, :height, :sha256,
                          :font_family, :font_weight, :font_style, :label, keyword_init: true) do
        def self.build(**attributes)
          record = new(**attributes)
          record.usable? ? record.freeze : nil
        end

        # Checked again on the way out of the database, like everything else the plugin stores.
        def usable?
          kind_rules = Uploads.kind(kind)
          return false unless kind_rules && token.is_a?(String) && TOKEN.match?(token)
          return false unless kind_rules.formats.include?(format)
          return false unless sha256.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(sha256)

          kind == "font" ? !face.nil? : true
        end

        def content_type
          FORMATS.fetch(format)[:content_type]
        end

        # The address of the file. It is built from the token only, which is 64 hex characters.
        def url(root: "")
          "#{root}#{URL_PREFIX}/#{token}"
        end

        # A fixed name for the download header. It never holds text an uploader chose.
        def file_name
          "#{kind.tr('_', '-')}.#{format == 'jpeg' ? 'jpg' : format}"
        end

        # The family, weight and style of a font, cleaned again. nil when they do not pass.
        def face
          FontFace.clean(family: font_family, weight: font_weight, style: font_style)
        rescue Refused
          nil
        end
      end
    end
  end
end
