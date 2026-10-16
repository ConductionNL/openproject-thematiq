# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/uploads"
require_relative "samples"

class UploadsInspectorTest < Minitest::Test
  Uploads = OpenProject::Thematiq::Uploads
  Inspector = Uploads::Inspector

  def inspect_upload(kind, data) = Inspector.inspect_upload(kind, data)

  def refused(kind, data)
    assert_raises(Uploads::Refused) { inspect_upload(kind, data) }.code
  end

  # --- the kinds ---

  def test_the_kinds_are_the_fourteen_the_admin_page_offers
    assert_equal %w[logo logo_inverse logo_mobile favicon touch_icon login_background font export_logo export_cover export_footer
                    export_font_regular export_font_bold export_font_italic export_font_bold_italic], Uploads::KINDS.keys
    assert(Uploads::KINDS.values.all? { |kind| kind.max_bytes.between?(64 * 1024, 2 * 1024 * 1024) })
    assert(Uploads::KINDS.values.all? { |kind| (kind.formats - Uploads::FORMATS.keys).empty? })
    assert_equal ["font"], Uploads::KINDS.values.reject(&:single).map(&:name)
  end

  # Prawn embeds PNG and JPEG pictures and TrueType fonts, nothing else.
  def test_the_pdf_kinds_take_only_what_a_pdf_can_embed
    pdf = Uploads::KINDS.values.select(&:pdf?)
    assert_equal %w[export_logo export_cover export_footer], pdf.select(&:image?).map(&:name)
    pdf.select(&:image?).each { |kind| assert_equal %w[png jpeg], kind.formats, kind.name }
    pdf.reject(&:image?).each { |kind| assert_equal %w[ttf], kind.formats, kind.name }
    assert(pdf.all?(&:single))
    refute Uploads.kind("logo").pdf?
  end

  def test_a_pdf_picture_takes_png_and_jpeg_and_refuses_the_rest
    assert_equal "png", inspect_upload("export_logo", UploadSamples.png(200, 50)).format
    assert_equal "jpeg", inspect_upload("export_cover", UploadSamples.jpeg(800, 600)).format
    assert_equal "png", inspect_upload("export_footer", UploadSamples.png(100, 20)).format
    assert_equal "wrong_type", refused("export_logo", UploadSamples.svg("clean-logo"))
    assert_equal "wrong_type", refused("export_logo", UploadSamples.webp)
    assert_equal "too_small", refused("export_cover", UploadSamples.png(100, 100))
    assert_equal "too_wide", refused("export_footer", UploadSamples.png(2000, 600))
  end

  def test_an_interlaced_png_is_refused_for_a_pdf_only
    interlaced = UploadSamples.png(200, 50, interlace: 1)
    assert_equal "interlaced", refused("export_logo", interlaced)
    assert_equal "png", inspect_upload("logo", interlaced).format
  end

  def test_a_pdf_font_is_truetype_only
    assert_equal "ttf", inspect_upload("export_font_regular", UploadSamples.ttf).format
    assert_equal "ttf", inspect_upload("export_font_bold_italic", UploadSamples.ttf("true".b)).format
    %w[woff2 woff otf].each { |format| assert_equal "wrong_type", refused("export_font_bold", UploadSamples.public_send(format)), format }
    assert_equal "too_large", refused("export_font_italic", UploadSamples.ttf + ("\x00".b * (2048 * 1024)))
  end

  def test_sizes_are_stated_in_units_of_1024
    assert_equal ["512 KB", "256 KB", "128 KB", "2 MB"], [512, 256, 128, 2048].map { |kb| Uploads.human_size(kb * 1024) }
    assert_equal ["900 bytes", "1.2 KB", "1.5 MB"], [900, 1234, 1_572_864].map { |bytes| Uploads.human_size(bytes) }
  end

  def test_an_unknown_kind_is_refused
    ["", "export_banner", "../logo", nil, 7].each { |kind| assert_equal "unknown_kind", refused(kind, UploadSamples.png) }
  end

  # --- the type comes from the content ---

  def test_each_whole_file_is_recognised_by_its_content
    { "png" => UploadSamples.png, "jpeg" => UploadSamples.jpeg, "webp" => UploadSamples.webp, "ico" => UploadSamples.ico,
      "ttf" => UploadSamples.ttf, "otf" => UploadSamples.otf, "woff" => UploadSamples.woff, "woff2" => UploadSamples.woff2,
      "svg" => UploadSamples.svg("clean-logo") }.each do |format, data|
      assert_equal format, Inspector.sniff(data.b), format
    end
  end

  def test_raster_images_give_their_size
    assert_equal [300, 80], inspect_upload("logo", UploadSamples.png(300, 80)).then { |r| [r.width, r.height] }
    assert_equal [300, 80], inspect_upload("logo", UploadSamples.jpeg(300, 80)).then { |r| [r.width, r.height] }
    assert_equal [300, 80], inspect_upload("logo", UploadSamples.webp(300, 80)).then { |r| [r.width, r.height] }
    assert_equal [32, 32], inspect_upload("favicon", UploadSamples.ico(32)).then { |r| [r.width, r.height] }
    assert_equal "image/png", inspect_upload("logo", UploadSamples.png).content_type
  end

  def test_an_svg_upload_comes_back_rebuilt
    result = inspect_upload("logo", UploadSamples.svg("hostile-script"))

    assert_equal "svg", result.format
    assert result.cleaned
    refute_includes result.bytes, "script"
    refute inspect_upload("logo", UploadSamples.svg("clean-logo")).cleaned
    assert_match(/\A\h{64}\z/, result.sha256)
  end

  def test_fonts_are_recognised_by_their_first_bytes
    %w[ttf otf woff woff2].each do |format|
      assert_equal format, inspect_upload("font", UploadSamples.public_send(format)).format
    end
  end

  def test_what_the_plugin_does_not_know_is_refused
    ["GIF89a#{'x' * 100}", "BM#{'x' * 100}", "%PDF-1.7\n", "MZ\x90\x00".b, "PK\x03\x04".b, "<html><script>alert(1)</script></html>",
     "#!/bin/sh\nrm -rf /", "ttcf\x00\x01\x00\x00".b, "plain text", UploadSamples.svg("not-svg-html")].each do |data|
      assert_equal "unknown_type", refused("logo", data), data[0, 12].inspect
    end
  end

  def test_a_known_type_in_the_wrong_field_is_refused
    assert_equal "wrong_type", refused("logo", UploadSamples.woff2)
    assert_equal "wrong_type", refused("logo", UploadSamples.ico)
    assert_equal "wrong_type", refused("font", UploadSamples.png)
    assert_equal "wrong_type", refused("font", UploadSamples.svg("clean-logo"))
    assert_equal "wrong_type", refused("touch_icon", UploadSamples.jpeg(180, 180))
    assert_equal "wrong_type", refused("touch_icon", UploadSamples.svg("clean-logo"))
    assert_equal "wrong_type", refused("favicon", UploadSamples.webp)
  end

  def test_a_file_with_a_borrowed_first_line_is_refused_as_broken
    script = "<script>alert(1)</script>"

    assert_equal "broken", refused("logo", "\x89PNG\r\n\x1A\n".b + script)
    assert_equal "broken", refused("logo", "\xFF\xD8\xFF".b + script)
    assert_equal "broken", refused("logo", "RIFF\x00\x00\x00\x00WEBP".b + script)
    assert_equal "broken", refused("favicon", "\x00\x00\x01\x00".b + script)
    assert_equal "broken", refused("font", "wOF2" + script)
    assert_equal "broken", refused("font", "wOFF" + script)
    assert_equal "broken", refused("font", "OTTO" + script)
    assert_equal "broken", refused("font", "\x00\x01\x00\x00".b + script)
  end

  def test_a_png_with_something_after_its_end_is_refused
    assert_equal "broken", refused("logo", UploadSamples.png + "<script>alert(1)</script>")
    assert_equal "broken", refused("logo", UploadSamples.png[0..-5] + "abcd")
    assert_equal "broken", refused("logo", UploadSamples.png[0, 40])
  end

  def test_an_icon_file_whose_picture_lies_outside_the_file_is_refused
    whole = UploadSamples.ico(32)

    assert_equal "broken", refused("favicon", whole[0, 40])
    assert_equal "broken", refused("favicon", UploadSamples.ico(32, picture: "<script>alert(1)</script>".b))
    assert_equal "broken", refused("favicon", "\x00\x00\x01\x00".b + [500].pack("v") + ("\x00".b * 64))
  end

  def test_a_font_whose_tables_lie_outside_the_file_is_refused
    assert_equal "broken", refused("font", UploadSamples.ttf[0, 30])
    assert_equal "broken", refused("font", UploadSamples.woff + "extra")
    assert_equal "broken", refused("font", UploadSamples.woff2[0, 50])
  end

  # --- limits ---

  def test_each_kind_has_a_size_cap
    Uploads::KINDS.each_value do |kind|
      assert_equal "too_large", refused(kind.name, "x" * (kind.max_bytes + 1)), kind.name
    end
    assert_equal "empty", refused("logo", "")
    assert_equal "empty", refused("logo", nil)
  end

  def test_a_picture_that_declares_a_huge_size_is_refused_without_being_decoded
    bomb = UploadSamples.png(60_000, 60_000)

    assert_operator bomb.bytesize, :<, 200
    assert_equal "too_wide", refused("logo", bomb)
    assert_equal "too_wide", refused("logo", UploadSamples.jpeg(65_000, 65_000))
    assert_equal "too_wide", refused("logo", UploadSamples.webp(16_000_000, 16_000_000))
    assert_equal "too_wide", refused("favicon", UploadSamples.png(513, 16))
    assert_equal "too_wide", refused("logo", UploadSamples.png(2000, 1001))
    assert_equal "broken", refused("logo", UploadSamples.png(0, 10))
  end

  def test_a_picture_that_is_too_small_is_refused
    assert_equal "too_small", refused("touch_icon", UploadSamples.png(119, 119))
    assert_equal "too_small", refused("favicon", UploadSamples.png(8, 8))
    assert_equal 180, inspect_upload("touch_icon", UploadSamples.png(180, 180)).width
  end

  def test_the_limit_itself_is_accepted
    assert_equal 2000, inspect_upload("logo", UploadSamples.png(2000, 1000)).width
    assert_equal 512, inspect_upload("favicon", UploadSamples.png(512, 512)).width
  end
end
