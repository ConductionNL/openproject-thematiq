# frozen_string_literal: true

module OpenProject
  module Thematiq
    # The files an administrator uploads for a custom design system: logos, icons and fonts.
    #
    #   Uploads::KINDS      what may be uploaded, with the limits of each kind
    #   Uploads::Inspector  decides what a file is by its content, and refuses what it does not know
    #   Uploads::Svg        rebuilds an SVG file from an allow-list
    #   Uploads::FontFace   the family, weight and style an uploaded font is served under
    #   Uploads::Record     one stored file without its bytes, as the rest of the plugin sees it
    #   Uploads::Response   the status and headers the public endpoint answers with
    #
    # Nothing in this namespace needs Rails. The table and its model are in app/models/thematiq/upload.rb.
    module Uploads
      # code: a short word the admin page translates.
      class Refused < StandardError
        def code = message
      end

      KILOBYTE = 1024

      # formats: what the content may be. single: one file per design system, an upload replaces it.
      Kind = Struct.new(:name, :formats, :max_bytes, :min_side, :max_width, :max_height, :single, keyword_init: true) do
        def image? = name != "font"
      end

      KINDS = [
        Kind.new(name: "logo", formats: %w[svg png jpeg webp], max_bytes: 512 * KILOBYTE, min_side: 16, max_width: 2000, max_height: 1000, single: true),
        Kind.new(name: "logo_inverse", formats: %w[svg png jpeg webp], max_bytes: 512 * KILOBYTE, min_side: 16, max_width: 2000, max_height: 1000, single: true),
        Kind.new(name: "logo_mobile", formats: %w[svg png jpeg webp], max_bytes: 256 * KILOBYTE, min_side: 16, max_width: 1000, max_height: 1000, single: true),
        Kind.new(name: "favicon", formats: %w[png ico svg], max_bytes: 128 * KILOBYTE, min_side: 16, max_width: 512, max_height: 512, single: true),
        Kind.new(name: "touch_icon", formats: %w[png], max_bytes: 512 * KILOBYTE, min_side: 120, max_width: 1024, max_height: 1024, single: true),
        Kind.new(name: "font", formats: %w[woff2 woff ttf otf], max_bytes: 2048 * KILOBYTE, single: false)
      ].to_h { |kind| [kind.name, kind.freeze] }.freeze

      # How many font files one design system may hold.
      MAX_FONTS = 12

      FORMATS = {
        "svg" => { content_type: "image/svg+xml", label: "SVG" },
        "png" => { content_type: "image/png", label: "PNG" },
        "jpeg" => { content_type: "image/jpeg", label: "JPEG" },
        "webp" => { content_type: "image/webp", label: "WebP" },
        "ico" => { content_type: "image/x-icon", label: "ICO" },
        "woff2" => { content_type: "font/woff2", label: "WOFF2", css: "woff2" },
        "woff" => { content_type: "font/woff", label: "WOFF", css: "woff" },
        "ttf" => { content_type: "font/ttf", label: "TTF", css: "truetype" },
        "otf" => { content_type: "font/otf", label: "OTF", css: "opentype" }
      }.freeze

      # The public id of a file: 64 hex characters from the system's random source. Nothing else is an id.
      TOKEN = /\A[0-9a-f]{64}\z/
      URL_PREFIX = "/thematiq/files"

      def self.kind(name)
        KINDS[name.to_s]
      end

      require "open_project/thematiq/uploads/record"
      require "open_project/thematiq/uploads/svg"
      require "open_project/thematiq/uploads/inspector"
      require "open_project/thematiq/uploads/font_face"
      require "open_project/thematiq/uploads/response"
    end
  end
end
