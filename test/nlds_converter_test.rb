# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/nlds_converter"

class NldsConverterTest < Minitest::Test
  Converter = OpenProject::Thematiq::NldsConverter

  THEME_CSS = <<~CSS
    .voorbeeld-theme {
      --voorbeeld-color-primary: #c8102e;
      --voorbeeld-color-grey-97: #f7f7f7;
      --utrecht-button-primary-action-background-color: var(--voorbeeld-color-primary);
      --utrecht-button-primary-action-color: #ffffff;
      --utrecht-link-color: #9b0c23;
      --utrecht-document-color: #1b1c1d;
      --utrecht-document-font-family: 'Fira Sans', sans-serif;
      --utrecht-page-max-inline-size: 1200px;
      --utrecht-alert-error-icon-color: #d52b1e;
    }
  CSS

  def test_a_built_theme_css_converts_by_thematiqs_table
    result = Converter.convert(THEME_CSS)

    assert_equal "voorbeeld", result.prefix, "the brand prefix is guessed from the names"
    assert_equal "css", result.format
    assert_equal "#c8102e", result.tokens["primary"]
    assert_equal "#9b0c23", result.tokens["link"]
    assert_equal "#1b1c1d", result.tokens["ink"]
    assert_equal "'Fira Sans', sans-serif", result.tokens["font-family"]
    assert_equal "#d52b1e", result.vocabulary["color-error"]
    assert_equal "213, 43, 30", result.vocabulary["color-error-rgb"], "worked out by the table's rgbTriplet"
    assert_equal "#b40e29", result.tokens["primary-deep"], "the hover: the primary 10% darker"
    assert_equal "#c8102e80", result.vocabulary["color-focus"], "the focus colour: the primary at half opacity"
    assert_includes result.skipped, ["--utrecht-page-max-inline-size", "layout-fixed-by-nextcloud"]
    assert(result.report.any? { |entry| entry.target == "--nldesign-color-primary" && entry.how == "applied" })
  end

  def test_a_style_dictionary_and_a_dtcg_document
    style_dictionary = { "utrecht" => { "link" => { "color" => { "value" => "{voorbeeld.color.primary}" } } },
                         "voorbeeld" => { "color" => { "primary" => { "value" => "#00689e" } } } }
    result = Converter.convert(JSON.generate(style_dictionary))
    assert_equal "style-dictionary", result.format
    assert_equal "#00689e", result.tokens["link"]
    assert_equal "#00689e", result.tokens["primary"], "--voorbeeld-color-primary is a source of the primary"

    dtcg = { "utrecht" => { "document" => { "color" => { "$value" => "#222222", "$type" => "color" } } } }
    result = Converter.convert(JSON.generate(dtcg), prefix: "x")
    assert_equal "dtcg", result.format
    assert_equal "#222222", result.tokens["ink"]
  end

  def test_hostile_input
    error = assert_raises(OpenProject::Thematiq::CssTokens::Refused) { Converter.convert("{not json") }
    assert_equal "not_css", error.code
    assert_raises(OpenProject::Thematiq::CssTokens::Refused) { Converter.convert(THEME_CSS, prefix: "../etc") }
    deep = 20.times.reduce({ "value" => "#fff" }) { |node, _| { "a" => node } }
    assert_raises(OpenProject::Thematiq::CssTokens::Refused) { Converter.convert(JSON.generate(deep)) }
    result = Converter.convert(".t { --utrecht-link-color: red; } body { display: none } .u { --utrecht-document-color: url(x); }")
    assert_equal "red", result.tokens["link"]
    assert_equal "#333333", result.tokens["ink"], "a value that fails falls to the table's default"
  end

  def test_the_vendored_table_is_thematiqs
    assert_equal 1, Converter.mapping["version"]
    assert_operator Converter.mapping["rules"].size, :>=, 40
  end
end
