# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/contrast"

class ContrastTest < Minitest::Test
  Contrast = OpenProject::Thematiq::Contrast
  Catalogue = OpenProject::Thematiq::Catalogue

  # The bundled sets with a text pair under 4.5:1, measured on the vendored catalogue.
  # The plugin does not change their colours. It marks them in the picker.
  # When the catalogue changes this list changes with it: update it here and in docs/accessibility.md.
  KNOWN_FAILURES = {
    "cunningham" => { "muted-on-ground" => 4.49 },
    "haarlemmermeer" => { "primary-deep-on-primary-light" => 4.23 },
    "noordoostpolder" => { "primary-deep-on-primary-light" => 4.3 },
    "vught" => { "primary-deep-on-primary-light" => 4.35 }
  }.freeze

  def test_known_ratios
    assert_equal 21.0, Contrast.ratio("#000000", "#ffffff")
    assert_equal 21.0, Contrast.ratio("#fff", "#000")
    assert_equal 1.0, Contrast.ratio("#777777", "#777777")
    assert_equal 4.54, Contrast.ratio("#767676", "#ffffff")
    assert_equal 4.54, Contrast.ratio("rgb(118, 118, 118)", "#ffffff")
  end

  def test_a_see_through_text_colour_is_mixed_with_its_background
    assert_in_delta Contrast.ratio("#525252", "#ffffff"), Contrast.ratio("rgba(0, 0, 0, 0.68)", "#ffffff"), 0.1
    assert_equal 1.0, Contrast.ratio("rgba(0, 0, 0, 0)", "#ffffff")
  end

  def test_what_cannot_be_computed_is_nil_not_fine
    assert_nil Contrast.ratio("red", "#ffffff")
    assert_nil Contrast.ratio("#000000", "rgba(0, 0, 0, 0.5)"), "a see-through background has no contrast of its own"
    assert_nil Contrast.ratio("hsl(0 0% 0%)", "#ffffff")
    assert_nil Contrast.ratio(nil, "#ffffff")
    assert_nil Contrast.ratio("rgb(300, 0, 0)", "#ffffff")
  end

  def test_white_on_primary_and_on_action_passes_for_every_bundled_set
    Catalogue.bundled.sets.each do |token_set|
      report = Contrast.report(token_set)

      assert_operator report["on-primary"], :>=, Contrast::MINIMUM, "#{token_set.id}: white on primary"
      assert_operator report["on-action"], :>=, Contrast::MINIMUM, "#{token_set.id}: white on action"
    end
  end

  def test_every_pair_of_every_bundled_set_can_be_computed
    Catalogue.bundled.sets.each { |token_set| assert_empty Contrast.unknown(token_set), token_set.id }
  end

  def test_the_bundled_sets_under_the_minimum_are_exactly_the_known_ones
    measured = Catalogue.bundled.sets.to_h { |token_set| [token_set.id, Contrast.report(token_set).slice(*Contrast.failures(token_set))] }
                        .reject { |_id, pairs| pairs.empty? }

    assert_equal KNOWN_FAILURES, measured
  end

  def test_failures_lists_the_pairs_under_the_minimum
    token_set = OpenProject::Thematiq::Tokens::TokenSet.from_set(
      { "id" => "pale", "name" => "Pale", "tokens" => { "primary" => "#ffee00", "action" => "#1f883d", "muted" => "#bbbbbb", "ground" => "#ffffff" } }
    )

    assert_includes Contrast.failures(token_set), "on-primary"
    assert_includes Contrast.failures(token_set), "muted-on-ground"
    refute_includes Contrast.failures(token_set), "on-action"
  end
end
