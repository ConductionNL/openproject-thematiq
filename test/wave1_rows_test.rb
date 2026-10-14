# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq"

class WaveOneRowsTest < Minitest::Test
  Thematiq = OpenProject::Thematiq
  ROOT = File.expand_path("..", __dir__)

  def test_marianne_asks_for_a_confirmation_and_other_families_do_not
    assert Thematiq::Uploads::FontFace.gated?("Marianne")
    assert Thematiq::Uploads::FontFace.gated?(" marianne ")
    refute Thematiq::Uploads::FontFace.gated?("Fira Sans")
  end

  def test_the_contrast_report_names_the_status_colours
    set = Thematiq::Tokens::TokenSet.from_set({ "id" => "s", "name" => "S", "tokens" => { "ground" => "#ffffff" },
                                                "vocabulary" => { "color-error" => "#d52b1e", "color-warning" => "#f5b82e" } })
    report = Thematiq::Compliance.status_report(set)

    assert_operator report["error-on-white"], :>=, 4.5
    assert_operator report["warning-on-white"], :<, 4.5
    refute report.key?("success-on-white"), "a status colour the set leaves out is not measured"
    entry = Thematiq::Compliance.report([[set, "instance"]], generated_at: "now")["design_systems"].first
    assert_equal "fail", entry["light"].find { |pair| pair["pair"] == "warning-on-white" }["verdict"]
  end

  def test_selected_text_takes_the_brand_colour_and_forced_colours_keep_the_system
    css = File.read(File.join(ROOT, "stylesheets/geometry/70-selection.css"))
    assert_includes css, "::selection { background: color-mix(in srgb, var(--thematiq-primary, Highlight) 28%, transparent); }"
    assert_includes css, "@media (forced-colors: active)"
  end
end
