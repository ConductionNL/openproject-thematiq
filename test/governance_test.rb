# frozen_string_literal: true

require "test_helper"
require "date"
require "open_project/thematiq/bundle"

class GovernanceTest < Minitest::Test
  Store = OpenProject::Thematiq::Store
  TODAY = Date.new(2026, 10, 14)

  def store(env = {}, data = {})
    Store.new(backend: MemoryBackend.new(data), env:)
  end

  def test_the_marker_is_saved_cleared_and_checked
    s = store
    assert_nil s.environment_marker
    assert s.save_environment_marker("Test", "#008800")
    assert_equal({ "label" => "Test", "colour" => "#008800", "text" => "#ffffff", "from_environment" => false }, s.environment_marker)
    assert s.save_environment_marker("", "")
    assert_nil s.environment_marker
    ["<script>", "a" * 31, "Test; } body {"].each { |label| refute s.save_environment_marker(label, "#008800"), label }
    refute s.save_environment_marker("Test", "red; } body {")
  end

  def test_the_environment_wins_and_a_bad_value_is_ignored
    assert_equal "Acceptance", store({ "THEMATIQ_ENVIRONMENT_LABEL" => "Acceptance" }, { "environment_label" => "Test" }).environment_marker["label"]
    assert_equal "Test", store({ "THEMATIQ_ENVIRONMENT_LABEL" => "<b>" }, { "environment_label" => "Test" }).environment_marker["label"]
    assert store({ "THEMATIQ_ENVIRONMENT_LABEL" => "Prod" }).environment_marker["from_environment"]
  end

  def test_a_deprecation_is_saved_with_its_rules
    s = store
    assert_nil s.save_deprecation(key: "accent", severity: "warning", replacement: "color-error", removal: "2027-01-01", message: "Use the error colour", today: TODAY)
    entry = s.deprecations(today: TODAY).first
    assert_equal({ "key" => "accent", "severity" => "warning", "replacement" => "color-error", "removal" => "2027-01-01",
                   "message" => "Use the error colour", "due" => false }, entry)
    assert s.deprecations(today: Date.new(2027, 2, 1)).first["due"], "past its date it is due, and nothing else happens"

    assert_equal "unknown_key", s.save_deprecation(key: "nope", severity: "info", today: TODAY)
    assert_equal "severity", s.save_deprecation(key: "accent", severity: "fatal", today: TODAY)
    assert_equal "replacement", s.save_deprecation(key: "accent", severity: "info", replacement: "accent", today: TODAY)
    assert_equal "replacement", s.save_deprecation(key: "accent", severity: "info", replacement: "nope", today: TODAY)
    assert_equal "removal", s.save_deprecation(key: "accent", severity: "info", removal: "2020-01-01", today: TODAY)
    assert_equal "removal", s.save_deprecation(key: "accent", severity: "info", removal: "tomorrow", today: TODAY)
    s.delete_deprecation("accent")
    assert_empty s.deprecations
  end

  def test_a_deprecation_changes_no_value
    s = store
    before = s.active_token_set.tokens
    s.save_deprecation(key: "primary", severity: "critical", today: TODAY)
    assert_equal before, s.active_token_set.tokens
  end

  def test_the_bundle_carries_and_checks_both
    catalogue = OpenProject::Thematiq::Catalogue.bundled
    s = store
    s.save_environment_marker("Test", "#008800")
    s.save_deprecation(key: "accent", severity: "info", today: TODAY)
    bundle = OpenProject::Thematiq::Bundle.build(settings: s.settings_snapshot, scopes: [])
    assert_equal "Test", OpenProject::Thematiq::Bundle.read(bundle, catalogue:).settings["environment_label"]

    hostile = Marshal.load(Marshal.dump(bundle))
    hostile["settings"]["environment_label"] = "<script>"
    assert_raises(OpenProject::Thematiq::Bundle::Refused) { OpenProject::Thematiq::Bundle.read(hostile, catalogue:) }
    hostile = Marshal.load(Marshal.dump(bundle))
    hostile["settings"]["deprecations"] = { "accent" => { "severity" => "fatal" } }
    assert_raises(OpenProject::Thematiq::Bundle::Refused) { OpenProject::Thematiq::Bundle.read(hostile, catalogue:) }
  end
end
