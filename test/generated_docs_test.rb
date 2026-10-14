# frozen_string_literal: true

require "test_helper"
require "yaml"
require "open_project/thematiq/compliance"

# The two generated documents are living documentation: they must say what the code says.
# After a change to the catalogue or the vocabulary, run script/generate-docs.rb.
class GeneratedDocsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  Compliance = OpenProject::Thematiq::Compliance

  def test_the_contrast_report_is_current
    assert_equal Compliance.contrast_document(OpenProject::Thematiq::Catalogue.bundled), File.read(File.join(ROOT, "docs/contrast-report.md")),
                 "run script/generate-docs.rb"
  end

  def test_the_token_reference_is_current
    labels = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).dig("en", "thematiq", "tokens").transform_values { |entry| entry["hint"] }

    assert_equal Compliance.token_document(labels), File.read(File.join(ROOT, "docs/token-reference.md")), "run script/generate-docs.rb"
  end

  def test_the_report_marks_failures_and_names_where_a_design_system_is_used
    catalogue = OpenProject::Thematiq::Catalogue.bundled
    weak = OpenProject::Thematiq::Tokens::TokenSet.from_set({ "id" => "weak", "name" => "Weak", "tokens" => { "muted" => "#dddddd" } })
    report = Compliance.report([[catalogue.default, "instance"], [weak, "project demo-project"], [weak, "project other"]], generated_at: "now")

    refute report["passes"]
    weak_entry = report["design_systems"].find { |system| system["id"] == "weak" }
    assert_equal ["project demo-project", "project other"], weak_entry["used_by"]
    assert_equal "fail", weak_entry["light"].find { |pair| pair["pair"] == "muted-on-ground" }["verdict"]
    assert_equal 2, report["design_systems"].size
  end
end
