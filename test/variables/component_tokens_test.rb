# frozen_string_literal: true

require "test_helper"

class ComponentTokensTest < Minitest::Test
  Generator = OpenProject::Thematiq::Variables::Generator

  def css(vocabulary)
    Generator.new(OpenProject::Thematiq::Tokens::TokenSet.from_set({ "id" => "c", "name" => "C", "tokens" => {}, "vocabulary" => vocabulary })).css
  end

  def test_form_controls_and_the_secondary_button_reach_primer
    out = css("component-textbox-border-color" => "#5b2e91", "component-textbox-invalid-border-color" => "#cc0000",
              "component-textbox-background-color" => "#fdfdfd", "component-button-secondary-action-color" => "#00689e")

    assert_includes out, "--control-borderColor-rest: #5b2e91;"
    assert_includes out, "--control-borderColor-danger: #cc0000;"
    assert_includes out, "--control-bgColor-rest: #fdfdfd;"
    assert_includes out, "--button-outline-fgColor-rest: #00689e;"
    assert_equal 1, out.scan("--control-borderColor-rest:").size, "the role's line gives way to the component token"
  end

  def test_a_set_without_them_keeps_openprojects_values
    refute_includes css({}), "--control-bgColor-rest"
  end
end
