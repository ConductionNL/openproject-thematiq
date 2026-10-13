# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/uploads"

class UploadsRecordTest < Minitest::Test
  Uploads = OpenProject::Thematiq::Uploads
  TOKEN = ("ab" * 32).freeze
  SHA = ("0f" * 32).freeze

  def record(**changes)
    Uploads::Record.build(**{ token: TOKEN, set_id: "custom", kind: "logo", format: "svg", byte_size: 10, sha256: SHA }.merge(changes))
  end

  def font(**changes)
    record(**{ kind: "font", format: "woff2", font_family: "House Sans", font_weight: "400", font_style: "normal" }.merge(changes))
  end

  # --- the address ---

  def test_the_address_is_the_token_and_nothing_else
    assert_equal "/thematiq/files/#{TOKEN}", record.url
    assert_equal "/op/thematiq/files/#{TOKEN}", record.url(root: "/op")
  end

  def test_only_64_hex_characters_are_a_token
    ["", "abc", "../../etc/passwd", "#{'ab' * 31}..", "#{TOKEN}/x", "#{TOKEN}\n", TOKEN.upcase, "#{'ab' * 31}g0", nil, 7,
     "%2e%2e%2f#{'a' * 58}", "#{'a' * 63}/"].each do |token|
      assert_nil record(token:), token.inspect
      refute Uploads::TOKEN.match?(token.to_s), token.inspect
    end
  end

  def test_a_record_that_does_not_hold_together_is_not_built
    assert_nil record(kind: "export_logo")
    assert_nil record(kind: "logo", format: "woff2")
    assert_nil record(kind: "touch_icon", format: "svg")
    assert_nil record(format: "exe")
    assert_nil record(sha256: "x")
    assert_nil font(font_family: "x'; } body { display: none")
    assert_nil font(font_weight: "bold; } body { display:none")
    assert_nil font(font_style: "oblique")
  end

  def test_the_download_name_is_fixed_by_kind_and_type
    assert_equal "logo.svg", record.file_name
    assert_equal "logo-inverse.jpg", record(kind: "logo_inverse", format: "jpeg").file_name
    assert_equal "font.woff2", font.file_name
    assert_equal "image/svg+xml", record.content_type
    assert_equal "font/woff2", font.content_type
  end

  # --- font faces ---

  def test_a_font_gives_one_font_face_rule_with_swap
    assert_equal "@font-face { font-family: 'House Sans'; font-style: normal; font-weight: 400; font-display: swap; " \
                 "src: url(/thematiq/files/#{TOKEN}) format('woff2'); }", Uploads::FontFace.css(font)
    assert_includes Uploads::FontFace.css(font(format: "ttf", font_weight: "100 900", font_style: "italic"), root: "/op"),
                    "font-style: italic; font-weight: 100 900; font-display: swap; src: url(/op/thematiq/files/#{TOKEN}) format('truetype')"
    assert_equal "", Uploads::FontFace.css(record)
  end

  def test_hostile_font_names_are_refused
    ["", " ", "x'; } body { display:none", "a\\62", "a\nb", "</style>", "a,b", "a\"b", "a" * 61, "url(x)", nil, 7].each do |family|
      error = assert_raises(Uploads::Refused) { Uploads::FontFace.clean(family:, weight: "400", style: "normal") }
      assert_equal "font_family_invalid", error.code, family.inspect
    end
    assert_equal "font_weight_invalid", assert_raises(Uploads::Refused) { Uploads::FontFace.clean(family: "A", weight: "450", style: "normal") }.code
    assert_equal "font_style_invalid", assert_raises(Uploads::Refused) { Uploads::FontFace.clean(family: "A", weight: "400", style: "x") }.code
    assert_equal "House Sans", Uploads::FontFace.clean(family: "  House   Sans ", weight: 700, style: "italic").family
  end

  # --- the answer of the public endpoint ---

  def test_every_answer_carries_the_locks
    headers = Uploads::Response.headers(record)

    assert_equal "image/svg+xml", headers["Content-Type"]
    assert_equal "nosniff", headers["X-Content-Type-Options"]
    assert_includes headers["Content-Security-Policy"], "default-src 'none'"
    assert_includes headers["Content-Security-Policy"], "sandbox"
    refute_match(/script-src|unsafe-eval|\*/, headers["Content-Security-Policy"])
    assert_equal %(inline; filename="logo.svg"), headers["Content-Disposition"]
    assert_equal "public, max-age=31536000, immutable", headers["Cache-Control"]
    assert_equal %("#{SHA}"), headers["ETag"]
    assert_equal headers.keys, Uploads::Response.headers(font).keys
  end

  def test_a_browser_that_holds_the_file_is_told_so
    assert Uploads::Response.fresh?(record, %("#{SHA}"))
    assert Uploads::Response.fresh?(record, %(W/"#{SHA}", "other"))
    refute Uploads::Response.fresh?(record, %("other"))
    refute Uploads::Response.fresh?(record, nil)
    refute Uploads::Response.fresh?(record, SHA)
  end
end
