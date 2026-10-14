# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/css_tokens"

class CssTokensTest < Minitest::Test
  CssTokens = OpenProject::Thematiq::CssTokens

  FILE = <<~CSS
    /* Gemeente Voorbeeld, written like thematiq's css/tokens/<set>.css */
    :root {
      --voorbeeld-red: #c8102e;
      --nldesign-color-primary: var(--voorbeeld-red);
      --nldesign-color-primary-hover: #960c23;
      --nldesign-color-text: #1b1c1d;
      --nldesign-border-radius: 6px;
      --nldesign-font-family: 'Fira Sans', sans-serif;
      --nldesign-color-error: #d52b1e;
      --nldesign-color-success: var(--missing, #008000);
      --nldesign-color-warning: red; } body { display: none;
      --nldesign-color-info: var(--loop-a);
      --loop-a: var(--loop-b);
      --loop-b: var(--loop-a);
    }
    @media (prefers-color-scheme: dark) {
      :root { --nldesign-color-primary: #ff8099; --nldesign-color-error: #ff7a70; }
    }
    [data-theme-dark] { --nldesign-color-text: #f5f5f5; }
  CSS

  def test_roles_and_vocabulary_light_and_dark_with_references_followed
    result = CssTokens.read(FILE)

    assert_equal "#c8102e", result.tokens["primary"], "a reference is followed to its value"
    assert_equal "#960c23", result.tokens["primary-deep"]
    assert_equal "6px", result.tokens["radius"]
    assert_equal "#d52b1e", result.vocabulary["color-error"]
    assert_equal "#008000", result.vocabulary["color-success"], "a missing reference takes its fallback"
    # The roles read thematiq's names in thematiq's order: action falls back to the primary, accent to the error colour.
    assert_equal({ "primary" => "#ff8099", "action" => "#ff8099", "accent" => "#ff7a70", "ink" => "#f5f5f5" }, result.dark)
    assert_equal({ "color-error" => "#ff7a70" }, result.dark_vocabulary)
  end

  def test_what_cannot_be_used_is_skipped_and_named_and_never_reaches_a_value
    result = CssTokens.read(FILE)

    assert_includes result.skipped, ["--nldesign-color-info", "reference"], "a cycle is skipped"
    assert_includes result.skipped, ["--voorbeeld-red", "unknown"]
    # A semicolon ends a declaration, as in CSS: what follows is no value of the token, and only custom properties are read.
    assert_equal "red", result.vocabulary["color-warning"]
    refute(result.vocabulary.values.any? { |value| value.include?("display") || value.include?("}") })
  end

  def test_refusals
    { "" => "empty", "x" * (CssTokens::MAX_BYTES + 1) => "too_large", ":root { color: red; }" => "nothing_usable",
      ":root { --nldesign-color-error: #fff" => "not_css", "\xff\xfe".b => "not_css" }.each do |text, code|
      error = assert_raises(CssTokens::Refused) { CssTokens.read(text) }
      assert_equal code, error.code, text[0, 40].inspect
    end
  end

  def test_hostile_values_never_pass
    HOSTILE_VALUES.grep(String).each do |value|
      # A semicolon or a brace ends the declaration, and a comment is no part of a value, as in CSS.
      next if value.include?(";") || value.include?("}") || value.include?("/*") || value.strip.empty?

      result = (CssTokens.read(":root { --nldesign-color-primary: #{value}; --nldesign-color-error: #fff; }") rescue nil)
      next unless result

      assert_nil result.tokens["primary"], value
    end
  end
end
