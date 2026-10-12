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

    assert_equal "#1b1c1d", Contrast.on(token_set, "primary"), "white does not read on yellow, so the text goes dark"
    refute_includes Contrast.failures(token_set), "on-primary"
    assert_includes Contrast.failures(token_set), "muted-on-ground"
    refute_includes Contrast.failures(token_set), "on-action"
  end

  # --- the rule for text on a background ---

  def test_best_on_keeps_the_first_candidate_when_it_reads
    assert_equal "#ffffff", Contrast.best_on("#1a67a3", ["#ffffff", "#000000"])
    assert_equal "#000000", Contrast.best_on("#fafafa", ["#ffffff", "#000000"])
    assert_equal "#ffffff", Contrast.best_on("#0e2045", ["#1f2328", "#ffffff"])
    assert_equal "#ffffff", Contrast.best_on("not a colour", ["#ffffff", "#000000"]), "unknown background: the first candidate"
  end

  def test_every_set_generated_from_thematiq_keeps_white_text_on_primary_and_action
    (Catalogue.bundled.sets.map(&:id) - Catalogue.own_ids).each do |id|
      token_set = Catalogue.bundled.find(id)

      assert_equal "#ffffff", Contrast.on(token_set, "primary"), id
      assert_equal "#ffffff", Contrast.on(token_set, "action"), id
      assert_equal token_set["primary-deep"], Contrast.on_selected(token_set), id
    end
  end

  def test_the_text_on_a_menu_colour_reads_for_every_set_that_has_one
    Catalogue.own_ids.each do |id|
      report = Contrast.report(Catalogue.bundled.find(id))

      assert_operator report["text-on-menu"], :>=, Contrast::MINIMUM, id
      assert_operator report["on-primary"], :>=, Contrast::MINIMUM, id
      assert_operator report["primary-deep-on-primary-light"], :>=, Contrast::MINIMUM, id
    end
  end

  # --- the dark theme ---

  # The bundled sets whose dark block is not used, because its main text does not read on its page
  # background. For these the dark theme keeps OpenProject's own colours. Measured on the vendored catalogue.
  # Seven until the catalogue of 13 October 2026, which corrected the dark blocks. Now none.
  DARK_NOT_USED = %w[].freeze

  def test_the_dark_blocks_that_are_not_used_are_exactly_the_known_ones
    not_used = Catalogue.bundled.sets.select(&:dark?).reject { |token_set| Contrast.dark_usable?(token_set) }.map(&:id)

    assert_equal DARK_NOT_USED, not_used.sort
  end

  def test_every_dark_block_that_is_used_reaches_the_minimum_on_every_pair
    Catalogue.bundled.sets.select { |token_set| Contrast.dark_usable?(token_set) }.each do |token_set|
      assert_empty Contrast.dark_failures(token_set), "#{token_set.id}: #{Contrast.dark_report(token_set)}"
    end
  end

  # 59 sets failed here until the catalogue corrected its dark blocks. The rule stays for an imported file.
  def test_the_catalogues_own_selected_item_colours_read_in_the_dark_theme_since_the_corrected_blocks
    raw_failures = Catalogue.bundled.sets.select(&:dark?).count do |token_set|
      dark = token_set.dark_tokens
      (Contrast.ratio(dark["primary-deep"], dark["primary-light"]) || 99) < Contrast::MINIMUM
    end

    assert_equal 0, raw_failures
  end

  def test_a_set_without_a_dark_block_has_no_dark_report
    assert_nil Contrast.dark_report(Catalogue.bundled.find("nextcloud"))
    refute Contrast.dark_usable?(Catalogue.bundled.find("nextcloud"))
  end
end
