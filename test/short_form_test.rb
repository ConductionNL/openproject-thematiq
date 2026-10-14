# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/short_form"

class ShortFormTest < Minitest::Test
  ShortForm = OpenProject::Thematiq::ShortForm
  Contrast = OpenProject::Thematiq::Contrast

  def test_two_colours_give_the_brand_roles
    values = ShortForm.derive(primary: "#C8102E", background: "#FFFFFF")

    assert_equal "#c8102e", values["primary"]
    assert_equal "#c8102e", values["action"]
    assert_equal "#ffffff", values["ground"]
    assert_equal values["primary-deep"], values["action-deep"]
    assert_equal "#960c23", values["primary-deep"]
    assert_operator Contrast.ratio(values["link"], "#ffffff"), :>=, Contrast::MINIMUM
  end

  def test_a_light_main_colour_gets_a_darker_link_that_reads
    values = ShortForm.derive(primary: "#ffdd00", background: "#ffffff")

    refute_equal "#ffdd00", values["link"]
    assert_operator Contrast.ratio(values["link"], "#ffffff"), :>=, Contrast::MINIMUM
  end

  def test_every_value_is_one_the_validator_takes
    values = ShortForm.derive(primary: "#123456", background: "#fafafa")

    values.each { |key, value| assert_equal value, OpenProject::Thematiq::Tokens::Validator.color(value), key }
  end

  def test_anything_but_two_hex_colours_is_refused
    (HOSTILE_VALUES + ["red", "#fff", "rgb(1,2,3)", "#1234567"]).each do |value|
      assert_nil ShortForm.derive(primary: value, background: "#ffffff"), value.inspect
      assert_nil ShortForm.derive(primary: "#ffffff", background: value), value.inspect
    end
  end
end
