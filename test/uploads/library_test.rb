# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq"

# The font library: fonts uploaded once, used by every design system whose stack names the family.
class FontLibraryTest < Minitest::Test
  Thematiq = OpenProject::Thematiq
  Assets = Thematiq::Assets
  Uploads = Thematiq::Uploads

  def font(character, set_id:, family: "House Sans")
    Uploads::Record.build(token: character * 64, set_id:, kind: "font", format: "woff2", byte_size: 10, sha256: "0f" * 32,
                          font_family: family, font_weight: "400", font_style: "normal")
  end

  def teardown
    Assets.upload_source = nil
  end

  def house(base = "cunningham")
    Thematiq::Tokens::TokenSet.from_set({ "id" => base, "name" => "X", "tokens" => { "font-family" => "'House Sans', sans-serif" } })
  end

  def test_a_library_font_reaches_any_design_system_that_names_it
    Assets.upload_source = ->(set_id) { set_id == "library" ? [font("a", set_id: "library"), font("b", set_id: "library", family: "Other")] : [] }

    css = Assets.bundled.font_face_css(house)
    assert_includes css, "font-family: 'House Sans'"
    assert_includes css, "/thematiq/files/#{'a' * 64}"
    refute_includes css, "/thematiq/files/#{'b' * 64}", "a family the stack does not name is not loaded"
  end

  def test_a_design_systems_own_upload_wins_over_the_library
    Assets.upload_source = ->(set_id) { set_id == "library" ? [font("a", set_id: "library")] : [font("c", set_id: "custom")] }
    custom = Thematiq::Tokens::TokenSet.from_set({ "id" => "custom", "name" => "X", "tokens" => { "font-family" => "'House Sans', sans-serif" } })

    css = Assets.bundled.font_face_css(custom)
    assert_includes css, "/thematiq/files/#{'c' * 64}"
    refute_includes css, "/thematiq/files/#{'a' * 64}"
  end

  def test_only_fonts_of_the_library_count
    Assets.upload_source = ->(_set_id) { [font("a", set_id: "custom"), "x", nil] }
    assert_empty Assets.library_fonts
    Assets.upload_source = ->(_set_id) { raise "away" }
    assert_empty Assets.library_fonts
  end
end
