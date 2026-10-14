# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/bundle"

class BundleTest < Minitest::Test
  Bundle = OpenProject::Thematiq::Bundle
  Store = OpenProject::Thematiq::Store

  def catalogue
    OpenProject::Thematiq::Catalogue.bundled
  end

  def settings
    { "active_custom" => "custom-2", "active_id" => "cunningham", "projects_may_choose" => true, "project_choices" => ["cunningham"],
      "nextcloud_url" => "https://cloud.example.org", "top_bar_apps" => "files, mail",
      "customs" => { "custom-2" => { "name" => "Town hall", "based_on" => "cunningham", "overrides" => { "primary" => "#aa0055" },
                                     "dark" => { "primary" => "#ff88bb" } } },
      "remembered_elsewhere" => "not part of the setup" }
  end

  def scopes
    [{ project_identifier: "demo-project", module_name: "", design_system_id: "custom-2" },
     { project_identifier: nil, module_name: "meetings", design_system_id: "cunningham" }]
  end

  def bundle
    Bundle.build(settings:, scopes:, plugin_version: "0.1.0")
  end

  def test_a_bundle_carries_the_setup_and_nothing_else
    assert_equal Bundle::FORMAT, bundle["format"]
    refute bundle["settings"].key?("remembered_elsewhere")
    assert_equal "Town hall", bundle["settings"]["customs"]["custom-2"]["name"]
    assert_equal [{ "project" => nil, "module" => "meetings", "design_system" => "cunningham" },
                  { "project" => "demo-project", "module" => "", "design_system" => "custom-2" }], bundle["scopes"]
  end

  def test_a_bundle_reads_back_as_it_was_written
    checked = Bundle.read(Bundle.dump(bundle), catalogue:)

    assert_equal bundle["settings"], checked.settings
    assert_equal scopes.sort_by { |row| row[:project_identifier].to_s }, checked.scopes.sort_by { |row| row[:project_identifier].to_s }
    assert_empty Bundle.changes(bundle, checked)
  end

  def test_the_shape_with_one_custom_design_system_moves_into_customs
    part = Bundle.settings_part("custom" => { "name" => "Old", "overrides" => {} }, "use_custom" => true)

    assert_equal({ "custom" => { "name" => "Old", "overrides" => {} } }, part["customs"])
  end

  def test_a_store_takes_a_bundle_and_keeps_what_is_not_part_of_the_setup
    backend = MemoryBackend.new("remembered_elsewhere" => "stays", "active_id" => "zuiddrecht", "custom" => { "name" => "x", "overrides" => {} })
    store = Store.new(backend:)
    store.replace_setup(Bundle.read(bundle, catalogue:).settings)

    assert_equal "stays", backend.data["remembered_elsewhere"]
    refute backend.data.key?("custom")
    assert_equal "custom-2", store.active_custom_id
    assert_equal "#aa0055", store.active_token_set["primary"]
    assert_equal "#ff88bb", store.active_token_set.dark_tokens["primary"]
  end

  def refused(code, document = nil, **options)
    error = assert_raises(Bundle::Refused) { Bundle.read(document || yield, catalogue:, **options) }
    assert_equal code, error.code
  end

  def test_broken_and_hostile_files_are_refused_whole
    refused("empty", "")
    refused("invalid_json", "{nope")
    refused("not_a_bundle", "[]")
    refused("not_a_bundle", { "format" => "something else" })
    refused("version") { bundle.merge("version" => 2) }
    refused("unknown_keys") { bundle.merge("script" => "alert(1)") }
    refused("settings") { bundle.merge("settings" => bundle["settings"].merge("base_url" => "https://evil.example")) }
    refused("too_large", "{" + (" " * Bundle::MAX_BYTES) + "}")
  end

  def test_a_custom_design_system_with_a_hostile_value_is_refused
    HOSTILE_VALUES.grep(String).reject { |value| value.strip.empty? }.each do |value|
      document = bundle
      document["settings"]["customs"]["custom-2"]["overrides"]["primary"] = value
      refused("custom_invalid", document)

      document = bundle
      document["settings"]["customs"]["custom-2"]["dark"] = { "primary" => value }
      refused("custom_invalid", document)
    end
  end

  def test_names_and_ids_from_outside_are_checked
    refused("customs") { bundle.tap { |b| b["settings"]["customs"] = { "../etc" => { "name" => "x", "overrides" => {} } } } }
    refused("active") { bundle.tap { |b| b["settings"]["active_id"] = "nothing-like-this" } }
    refused("active") { bundle.tap { |b| b["settings"]["active_custom"] = "custom-9" } }
    refused("projects") { bundle.tap { |b| b["settings"]["project_choices"] = ["nothing-like-this"] } }
    refused("nextcloud_url") { bundle.tap { |b| b["settings"]["nextcloud_url"] = "javascript:alert(1)" } }
    refused("scope_design_system") { bundle.tap { |b| b["scopes"] << { "project" => "x", "module" => "", "design_system" => "nope" } } }
    refused("scopes") { bundle.tap { |b| b["scopes"] << { "project" => "x", "module" => "evil", "design_system" => "cunningham" } } }
    refused("scopes") { bundle.tap { |b| b["scopes"] << { "project" => nil, "module" => "", "design_system" => "cunningham" } } }
    refused("scopes") { bundle.tap { |b| b["scopes"] << b["scopes"].first.dup } }
    refused("scope_project", bundle, project_exists: ->(_identifier) { false })
  end

  def test_the_changes_name_what_a_restore_does
    before = Bundle.build(settings: { "active_id" => "cunningham" }, scopes: [])
    changes = Bundle.changes(before, Bundle.read(bundle, catalogue:)).map(&:first)

    assert_equal %w[active custom_added projects_may_choose project_choices nextcloud_url top_bar_apps scope scope], changes
    assert_equal({ from: "cunningham", to: "custom-2" }, Bundle.changes(before, bundle).first.last)
  end
end
