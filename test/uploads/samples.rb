# frozen_string_literal: true

require "zlib"

# Builds small binary files for the upload tests: whole ones, and ones broken in one known way.
# The SVG samples are text and sit in test/fixtures/uploads/.
module UploadSamples
  FIXTURES = File.expand_path("../fixtures/uploads", __dir__)

  module_function

  def svg(name)
    File.binread(File.join(FIXTURES, "#{name}.svg"))
  end

  def hostile_svg_names
    Dir[File.join(FIXTURES, "hostile-*.svg")].sort.map { |path| File.basename(path, ".svg") }
  end

  def png_chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end

  # A PNG file that declares the given size. The picture data is one pixel: nothing here decodes it.
  def png(width = 64, height = 64, interlace: 0)
    "\x89PNG\r\n\x1A\n".b + png_chunk("IHDR", [width, height, 8, 6, 0, 0, interlace].pack("NNCCCCC")) +
      png_chunk("IDAT", Zlib.deflate("\x00\x00\x00\x00\x00".b)) + png_chunk("IEND", "".b)
  end

  def jpeg(width = 64, height = 64)
    "\xFF\xD8".b + "\xFF\xE0".b + [16].pack("n") + "JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00".b +
      "\xFF\xC0".b + [17, 8, height, width, 3].pack("nCnnC") + ("\x01\x11\x00".b * 3) + "\xFF\xD9".b
  end

  def webp(width = 64, height = 64)
    body = "WEBP".b + "VP8X".b + [10].pack("V") + "\x00\x00\x00\x00".b + [width - 1].pack("V")[0, 3] + [height - 1].pack("V")[0, 3]
    "RIFF".b + [body.bytesize].pack("V") + body
  end

  # An icon file with one picture of the given size, which is a PNG file.
  def ico(side = 32, picture: png(side, side))
    "\x00\x00\x01\x00".b + [1].pack("v") + [side % 256, side % 256, 0, 0, 1, 32, picture.bytesize, 22].pack("CCCCvvVV") + picture
  end

  def ttf(signature = "\x00\x01\x00\x00".b)
    signature + [1, 16, 0, 16].pack("nnnn") + "head".b + [0, 28, 8].pack("NNN") + ("\x00".b * 8)
  end

  def otf = ttf("OTTO".b)

  # A whole PNG file in one colour, RGB without alpha, that Prawn can embed. hex: "rrggbb".
  def solid_png(width, height, hex)
    rgb = [hex].pack("H*")
    rows = ("\x00".b + (rgb * width)) * height
    "\x89PNG\r\n\x1A\n".b + png_chunk("IHDR", [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
      png_chunk("IDAT", Zlib.deflate(rows)) + png_chunk("IEND", "".b)
  end

  def woff
    header = "wOFF".b + "\x00\x01\x00\x00".b + [64, 1, 0].pack("Nnn") + ("\x00".b * 28)
    header + ("\x00".b * (64 - header.bytesize))
  end

  def woff2
    header = "wOF2".b + "\x00\x01\x00\x00".b + [64, 1, 0].pack("Nnn") + ("\x00".b * 32)
    header + ("\x00".b * (64 - header.bytesize))
  end
end
