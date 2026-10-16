# frozen_string_literal: true

require "zlib"
require "digest"

module OpenProject
  module Thematiq
    module Uploads
      # Decides what an uploaded file is. Every upload is hostile input.
      #
      # The file name and the content type the browser sent are never looked at. The type comes from the
      # first bytes, and then the structure of that type is read far enough to find the size of the picture
      # and to see that the file is whole. A picture is never decoded here, so a file that unpacks to
      # something huge costs nothing: its declared size is over the limit and it is refused.
      module Inspector
        Result = Struct.new(:kind, :format, :bytes, :width, :height, :cleaned, keyword_init: true) do
          def byte_size = bytes.bytesize
          def sha256 = Digest::SHA256.hexdigest(bytes)
          def content_type = FORMATS.fetch(format)[:content_type]
        end

        PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b
        MAX_ICO_IMAGES = 20
        MAX_FONT_TABLES = 200

        module_function

        # Returns a Result, or raises Refused with a code the admin page translates.
        # For an SVG file the bytes in the result are the rebuilt file, not what was uploaded.
        def inspect_upload(kind_name, data)
          kind = Uploads.kind(kind_name)
          raise Refused, "unknown_kind" unless kind
          raise Refused, "empty" unless data.is_a?(String) && !data.empty?
          raise Refused, "too_large" if data.bytesize > kind.max_bytes

          bytes = data.b
          format = sniff(bytes)
          raise Refused, "unknown_type" unless format
          raise Refused, "wrong_type" unless kind.formats.include?(format)

          result = read(kind, format, bytes)
          check_dimensions(kind, result)
          raise Refused, "interlaced" if kind.pdf? && format == "png" && png_interlaced?(bytes)

          result
        end

        # The interlace byte of the header. Prawn cannot embed an interlaced PNG file in a PDF.
        def png_interlaced?(bytes)
          bytes.getbyte(PNG_SIGNATURE.bytesize + 8 + 12) != 0
        end

        # The type of a file by its first bytes. nil when it is none the plugin knows.
        def sniff(bytes)
          return "png" if bytes.start_with?(PNG_SIGNATURE)
          return "jpeg" if bytes.start_with?("\xFF\xD8\xFF".b)
          return "webp" if bytes[0, 4] == "RIFF" && bytes[8, 4] == "WEBP"
          return "ico" if bytes.start_with?("\x00\x00\x01\x00".b)
          return "woff2" if bytes.start_with?("wOF2")
          return "woff" if bytes.start_with?("wOFF")
          return "otf" if bytes.start_with?("OTTO")
          return "ttf" if bytes.start_with?("\x00\x01\x00\x00".b) || bytes.start_with?("true")
          return "svg" if Svg.looks_like_svg?(bytes)

          nil
        end

        def read(kind, format, bytes)
          case format
          when "svg"
            svg = Svg.sanitise(bytes)
            Result.new(kind: kind.name, format:, bytes: svg.text.b, cleaned: svg.removed.positive?)
          when "png", "jpeg", "webp", "ico"
            width, height = public_send(:"#{format}_size", bytes)
            raise Refused, "broken" unless width.is_a?(Integer) && height.is_a?(Integer) && width.positive? && height.positive?

            Result.new(kind: kind.name, format:, bytes:, width:, height:, cleaned: false)
          else
            raise Refused, "broken" unless public_send(:"#{format}_whole?", bytes)

            Result.new(kind: kind.name, format:, bytes:, cleaned: false)
          end
        end

        def check_dimensions(kind, result)
          return unless result.width

          raise Refused, "too_small" if [result.width, result.height].min < kind.min_side
          raise Refused, "too_wide" if result.width > kind.max_width || result.height > kind.max_height
        end

        # --- raster images: [width, height], or nil when the file is not whole ---

        # Walks every chunk. The first must be IHDR, the last IEND, each checksum must fit and nothing may follow.
        def png_size(bytes)
          position = PNG_SIGNATURE.bytesize
          size = nil
          loop do
            return nil if position + 12 > bytes.bytesize

            length = bytes[position, 4].unpack1("N")
            type = bytes[position + 4, 4]
            return nil if position + 12 + length > bytes.bytesize
            return nil unless Zlib.crc32(bytes[position + 4, 4 + length]) == bytes[position + 8 + length, 4].unpack1("N")

            if size.nil?
              return nil unless type == "IHDR" && length == 13

              size = bytes[position + 8, 8].unpack("NN")
            end
            position += 12 + length
            return (position == bytes.bytesize ? size : nil) if type == "IEND"
          end
        end

        # Walks the segments up to the frame header, which holds the size.
        def jpeg_size(bytes)
          position = 2
          while position + 4 <= bytes.bytesize
            return nil unless bytes.getbyte(position) == 0xFF

            marker = bytes.getbyte(position + 1)
            if marker == 0xFF
              position += 1
            elsif marker == 0x01 || (0xD0..0xD7).cover?(marker)
              position += 2
            elsif marker == 0xDA || marker == 0xD9 || marker.zero?
              return nil
            else
              length = bytes[position + 2, 2].unpack1("n")
              return nil if length < 2 || position + 2 + length > bytes.bytesize

              if (0xC0..0xCF).cover?(marker) && ![0xC4, 0xC8, 0xCC].include?(marker)
                return nil if length < 7

                height, width = bytes[position + 5, 4].unpack("nn")
                return [width, height]
              end
              position += 2 + length
            end
          end
          nil
        end

        def webp_size(bytes)
          return nil if bytes.bytesize < 30

          declared = bytes[4, 4].unpack1("V") + 8
          return nil unless [declared, declared + 1].include?(bytes.bytesize)

          case bytes[12, 4]
          when "VP8 "
            return nil unless bytes[23, 3] == "\x9D\x01\x2A".b

            bytes[26, 4].unpack("vv").map { |value| value & 0x3FFF }
          when "VP8L"
            return nil unless bytes.getbyte(20) == 0x2F

            bits = bytes[21, 4].unpack1("V")
            [(bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1]
          when "VP8X"
            [bytes[24, 3], bytes[27, 3]].map { |three| (three + "\x00".b).unpack1("V") + 1 }
          end
        end

        # An icon file is a list of pictures. Each one must lie inside the file and be a PNG or a bitmap.
        # The size is that of the largest picture.
        def ico_size(bytes)
          return nil if bytes.bytesize < 22

          count = bytes[4, 2].unpack1("v")
          return nil unless (1..MAX_ICO_IMAGES).cover?(count)

          directory_end = 6 + (16 * count)
          return nil if directory_end > bytes.bytesize

          sizes = (0...count).map do |index|
            entry = bytes[6 + (16 * index), 16]
            width, height = entry.unpack("CC").map { |side| side.zero? ? 256 : side }
            length, offset = entry[8, 8].unpack("VV")
            return nil if offset < directory_end || length < 16 || offset + length > bytes.bytesize

            picture = bytes[offset, length]
            return nil unless picture.start_with?(PNG_SIGNATURE) || picture[0, 4].unpack1("V") == 40

            [width, height]
          end
          sizes.max_by { |width, height| width * height }
        end

        # --- fonts: true when the file holds together ---

        def woff_whole?(bytes)
          return false if bytes.bytesize < 44

          flavour = bytes[4, 4]
          known = flavour == "OTTO" || flavour == "true" || flavour == "\x00\x01\x00\x00".b
          known && bytes[8, 4].unpack1("N") == bytes.bytesize && bytes[12, 2].unpack1("n").positive?
        end

        def woff2_whole?(bytes)
          bytes.bytesize >= 48 && bytes[8, 4].unpack1("N") == bytes.bytesize && bytes[12, 2].unpack1("n").positive?
        end

        # The table directory must fit, and every table it names must lie inside the file.
        def ttf_whole?(bytes)
          return false if bytes.bytesize < 12

          tables = bytes[4, 2].unpack1("n")
          return false unless (1..MAX_FONT_TABLES).cover?(tables) && 12 + (16 * tables) <= bytes.bytesize

          (0...tables).all? do |index|
            entry = bytes[12 + (16 * index), 16]
            offset, length = entry[8, 8].unpack("NN")
            entry[0, 4].match?(/\A[\x20-\x7E]{4}\z/n) && offset + length <= bytes.bytesize
          end
        end

        def otf_whole?(bytes)
          ttf_whole?(bytes)
        end
      end
    end
  end
end
