# frozen_string_literal: true

require "test_helper"
require "json"
require "open_project/thematiq/transfer"
require "open_project/thematiq/figma"

# The vocabulary of the dark theme: kept, carried and drawn where the light value is drawn.
class DarkVocabularyTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Generator = OpenProject::Thematiq::Variables::Generator
  CustomDraft = OpenProject::Thematiq::CustomDraft
  Transfer = OpenProject::Thematiq::Transfer

  DARK_ROLES = { "ink" => "#e2e3e4", "ground" => "#171a20", "primary" => "#5b8ac2" }.freeze

  def set(dark_vocabulary, vocabulary = {})
    TokenSet.from_set({ "id" => "d", "name" => "D", "tokens" => {}, "vocabulary" => vocabulary,
                        "dark" => { "tokens" => DARK_ROLES, "vocabulary" => dark_vocabulary } })
  end

  def blocks(css)
    css.scan(/^([^\n{}\/]+) \{\n(.*?)\n\}/m).to_h { |selector, body| [selector, body] }
  end

  def test_a_set_keeps_its_dark_vocabulary_and_drops_what_fails
    token_set = set({ "color-error" => "#F43535", "color-warning" => "red; } x {", "nope" => "#fff" })

    assert_equal({ "color-error" => "#f43535" }, token_set.dark_vocabulary)
    assert_includes token_set.rejected, "dark.vocabulary.color-warning"
  end

  def test_the_dark_theme_draws_the_dark_values_where_the_light_ones_are_drawn
    css = Generator.new(set({ "color-error" => "#f43535", "component-table-header-background-color" => "#1d2026",
                              "color-info" => "#5b8ac2" }, { "color-error" => "#cc0000" })).css
    dark = blocks(css).fetch(Generator::DARK_SCOPE)
    light = blocks(css).fetch(Generator::LIGHT_SCOPE)

    assert_includes dark, "--fgColor-danger: #f43535;"
    assert_includes dark, "--thematiq-v-table-head: #1d2026;"
    refute_includes dark, "#cc0000"
    assert_includes light, "--fgColor-danger: #cc0000;"
    refute_includes light, "#f43535"
    refute_includes css, "--fgColor-accent: #5b8ac2;\n  --fgColor-danger", "info stays carried"
  end

  def test_a_dark_vocabulary_value_replaces_the_dark_roles_line
    dark = blocks(Generator.new(set({ "color-focus-rgb" => "91, 138, 194" })).css).fetch(Generator::DARK_SCOPE)

    assert_equal 1, dark.scan("--focus-outlineColor:").size
    assert_includes dark, "--focus-outlineColor: rgb(91, 138, 194);"
  end

  def test_export_import_and_every_figma_format_keep_it
    original = set({ "color-error" => "#f43535", "component-navigation-active-color" => "#ff5c5c" }, { "color-error" => "#cc0000" })

    assert_equal original.dark_vocabulary, Transfer.import(Transfer.export(original)).dark_vocabulary
    OpenProject::Thematiq::Figma::FORMATS.each do |format|
      result = OpenProject::Thematiq::Figma::Reader.read([["f.json", OpenProject::Thematiq::Figma.export(original, format:)]])

      assert_equal original.dark_vocabulary, result.dark_vocabulary, format
      assert_equal original.vocabulary, result.vocabulary, format
      assert_equal 0, result.skipped_count, format
    end
  end

  def test_an_import_refuses_an_unknown_key_in_the_dark_vocabulary
    file = JSON.generate({ "id" => "d", "name" => "D", "tokens" => {}, "dark" => { "tokens" => {}, "vocabulary" => { "made-up" => "#fff" } } })

    assert_raises(Transfer::Refused) { Transfer.import(file) }
  end

  def test_a_custom_design_system_keeps_its_bases_dark_vocabulary_and_its_own
    base = set({ "color-error" => "#f43535" })
    draft = CustomDraft.new(base:, name: "Mine", overrides: {}, dark_vocabulary: { "color-success" => "#94e1a0", "color-error" => "#f43535" })

    assert_equal({ "color-success" => "#94e1a0" }, draft.dark_vocabulary)
    assert_equal({ "color-error" => "#f43535", "color-success" => "#94e1a0" }, draft.token_set.dark_vocabulary)
    assert_equal draft.dark_vocabulary, draft.definition["dark_vocabulary"]
  end

  def test_the_bundled_catalogue_carries_dark_vocabulary_and_every_value_passes
    sets = OpenProject::Thematiq::Catalogue.bundled.sets

    assert_operator sets.count { |token_set| token_set.dark_vocabulary.any? }, :>, 60
    sets.each { |token_set| assert_empty token_set.rejected, token_set.id }
    zuiddrecht = OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
    assert_equal "#f43535", zuiddrecht.dark_vocabulary["color-error"]
  end
end
