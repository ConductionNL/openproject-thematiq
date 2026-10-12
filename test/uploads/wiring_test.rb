# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq"
require "open_project/thematiq/shell/logo"

# How uploaded files reach the page: through Assets, into the one logo rule, the page head and the font faces.
class UploadsWiringTest < Minitest::Test
  Thematiq = OpenProject::Thematiq
  Assets = Thematiq::Assets
  Uploads = Thematiq::Uploads
  Catalogue = Thematiq::Catalogue

  def token(character) = character * 64

  def record(kind, format, character, set_id: "custom", **more)
    Uploads::Record.build(token: token(character), set_id:, kind:, format:, byte_size: 10, sha256: "0f" * 32, **more)
  end

  def font(character, family: "House Sans", weight: "400", style: "normal", format: "woff2")
    record("font", format, character, font_family: family, font_weight: weight, font_style: style)
  end

  def custom(base = "zuiddrecht", id: "custom", overrides: {})
    Thematiq::CustomDraft.new(base: Catalogue.bundled.find(base), name: "Mine", overrides:, id:).token_set
  end

  def assets = Assets.bundled

  def teardown
    Assets.upload_source = nil
  end

  # --- which design systems have uploads ---

  def test_no_catalogue_design_system_has_an_id_that_could_hold_uploads
    Catalogue.bundled.sets.each { |token_set| refute_match Thematiq::CustomDraft::ID_PATTERN, token_set.id }
  end

  def test_uploads_come_from_the_source_and_only_for_a_custom_design_system
    asked = []
    Assets.upload_source = lambda do |set_id|
      asked << set_id
      [record("logo", "svg", "a")]
    end

    assert_equal 1, Assets.uploads_for(custom).size
    assert_empty Assets.uploads_for(Catalogue.bundled.find("zuiddrecht"))
    assert_equal ["custom"], asked
  end

  def test_a_source_that_fails_or_answers_nonsense_gives_no_uploads
    Assets.upload_source = ->(_) { raise "the table is away" }
    assert_empty Assets.uploads_for(custom)
    assert_equal "/thematiq/logos/zuiddrecht-dark.svg", assets.logo_url(custom)

    Assets.upload_source = ->(_) { ["x", nil, { "kind" => "logo" }, record("logo", "svg", "a", set_id: "custom-2")] }
    assert_empty Assets.uploads_for(custom)

    Assets.upload_source = ->(_) { "x" }
    assert_empty Assets.uploads_for(custom)
  end

  # --- the logo ---

  def test_an_uploaded_logo_wins_over_the_bundled_one
    assert_equal "/thematiq/logos/zuiddrecht-dark.svg", assets.logo_url(custom, uploads: [])
    assert_equal "/thematiq/files/#{token('a')}", assets.logo_url(custom, uploads: [record("logo", "png", "a")])
    assert_equal "/op/thematiq/files/#{token('a')}", assets.logo_url(custom, root: "/op", uploads: [record("logo", "png", "a")])
  end

  def test_the_logo_for_the_coloured_bar_comes_first
    uploads = [record("logo", "png", "a"), record("logo_inverse", "svg", "b")]

    assert_equal "/thematiq/files/#{token('b')}", assets.logo_url(custom, uploads:)
  end

  def test_a_custom_design_system_without_a_bundled_logo_gets_its_uploaded_one
    assert_nil assets.logo_url(custom("amsterdam"), uploads: [])
    assert_equal "/thematiq/files/#{token('a')}", assets.logo_url(custom("amsterdam"), uploads: [record("logo", "webp", "a")])
  end

  def test_the_logo_rule_keeps_its_selector_and_takes_the_upload
    Assets.upload_source = ->(_) { [record("logo", "svg", "a")] }

    assert_equal %(.op-app-header .op-logo .op-logo--link { background-image: url("/thematiq/files/#{token('a')}"); }),
                 Thematiq::Shell::Logo.css(custom)
  end

  def test_the_mobile_logo_gets_a_rule_for_the_element_narrow_screens_show
    Assets.upload_source = ->(_) { [record("logo", "svg", "a"), record("logo_mobile", "png", "b")] }
    css = Thematiq::Shell::Logo.css(custom, root: "/op")

    assert_equal 2, css.lines.size
    assert_includes css, %(.op-app-header .op-logo--icon.op-logo--link { background-image: url("/op/thematiq/files/#{token('b')}"); })
    assert_nil assets.mobile_logo_url(custom, uploads: [record("logo", "svg", "a")])
    refute_includes Thematiq::Shell::Logo.css(Catalogue.bundled.find("zuiddrecht")), "op-logo--icon"
  end

  # --- favicon and touch icon ---

  def test_the_icons_become_link_attributes
    uploads = [record("favicon", "png", "a", width: 32, height: 32), record("touch_icon", "png", "b", width: 180, height: 180)]

    assert_equal [{ rel: "icon", href: "/thematiq/files/#{token('a')}", type: "image/png", sizes: "32x32" },
                  { rel: "apple-touch-icon", href: "/thematiq/files/#{token('b')}", type: "image/png", sizes: "180x180" }],
                 assets.icon_links(custom, uploads:)
    assert_equal "any", assets.icon_links(custom, uploads: [record("favicon", "svg", "a")]).first[:sizes]
    assert_equal "image/x-icon", assets.icon_links(custom, uploads: [record("favicon", "ico", "a", width: 32, height: 32)]).first[:type]
    assert_empty assets.icon_links(custom, uploads: [record("logo", "svg", "a")])
    assert_empty assets.icon_links(Catalogue.bundled.find("zuiddrecht"))
  end

  def test_the_plugin_gives_no_icons_when_nothing_can_be_read
    assert_empty Thematiq.icon_links
  end

  # --- fonts ---

  def test_uploaded_fonts_get_font_face_rules_with_swap
    token_set = custom("vng", overrides: { "font-family" => "'House Sans', sans-serif" })
    css = assets.font_face_css(token_set, uploads: [font("a"), font("b", weight: "700", style: "italic", format: "ttf")])

    assert_equal 2, css.lines.size
    assert_includes css, "@font-face { font-family: 'House Sans'; font-style: normal; font-weight: 400; font-display: swap; " \
                         "src: url(/thematiq/files/#{token('a')}) format('woff2'); }"
    assert_includes css, "font-style: italic; font-weight: 700; font-display: swap; src: url(/thematiq/files/#{token('b')}) format('truetype')"
    assert assets.uploaded_family?(token_set, "house sans", uploads: [font("a")])
    refute assets.uploaded_family?(token_set, "House Sans", uploads: [])
  end

  def test_an_uploaded_family_replaces_the_bundled_files_of_that_family
    amsterdam = custom("amsterdam")
    bundled = assets.font_face_css(amsterdam, uploads: [])
    css = assets.font_face_css(amsterdam, uploads: [font("a", family: "Fira Sans")])

    assert_includes bundled, "/thematiq/fonts/fira-sans-latin-400-normal.woff2"
    refute_includes css, "/thematiq/fonts/fira-sans"
    assert_equal 1, css.scan("font-family: 'Fira Sans'").size
  end

  def test_every_font_rule_is_plain
    css = assets.font_face_css(custom, uploads: [font("a"), font("b", weight: "100 900")])

    css.each_line(chomp: true) do |line|
      assert_match(%r{\A@font-face \{ font-family: '[A-Za-z0-9 _.-]+'; font-style: (?:normal|italic); font-weight: (?:\d{3}|100 900); font-display: swap; src: url\(/thematiq/(?:files/\h{64}|fonts/[a-z0-9-]+\.woff2)\) format\('[a-z0-9]+'\); \}\z}, line)
    end
  end

  # --- export and import ---

  def test_an_export_names_the_kinds_it_leaves_behind_and_holds_no_file
    text = Thematiq::Transfer.export(custom, uploads: [font("a"), record("logo", "svg", "b"), font("c", weight: "700")])
    set = JSON.parse(text)

    assert_equal({ "included" => false, "note" => Thematiq::Transfer::UPLOADS_NOTE, "kinds" => %w[logo font] }, set["uploads"])
    refute_includes text, token("a")
    assert_operator text.bytesize, :<, Thematiq::Transfer::MAX_BYTES
    assert_equal %w[logo font], Thematiq::Transfer.left_behind(text)
  end

  def test_an_export_without_uploads_has_no_note
    refute JSON.parse(Thematiq::Transfer.export(custom)).key?("uploads")
    assert_empty Thematiq::Transfer.left_behind(Thematiq::Transfer.export(custom))
  end

  def test_a_file_with_the_note_imports_and_the_note_is_only_read_for_known_kinds
    text = Thematiq::Transfer.export(custom, uploads: [record("logo", "svg", "b")])

    assert_equal custom.tokens, Thematiq::Transfer.import(text).tokens
    hostile = JSON.parse(text).merge("uploads" => { "kinds" => ["logo", "<script>alert(1)</script>", 7, nil, "export_logo"] })
    assert_equal ["logo"], Thematiq::Transfer.left_behind(JSON.generate(hostile))
    assert_empty Thematiq::Transfer.left_behind("not json")
    assert_empty Thematiq::Transfer.left_behind(nil)
    assert_empty Thematiq::Transfer.left_behind(JSON.generate(JSON.parse(text).merge("uploads" => { "kinds" => "logo" })))
    assert_equal "uploads_invalid", assert_raises(Thematiq::Transfer::Refused) { Thematiq::Transfer.import(JSON.generate(JSON.parse(text).merge("uploads" => "x"))) }.code
  end
end
