# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/health"

class OperationsTest < Minitest::Test
  Store = OpenProject::Thematiq::Store
  Health = OpenProject::Thematiq::Health

  def store(env = {}, data = {})
    Store.new(backend: MemoryBackend.new(data), env:)
  end

  def test_the_environment_names_the_design_system_and_wins
    s = store({ "THEMATIQ_DESIGN_SYSTEM" => "zuiddrecht" }, { "active_id" => "amsterdam" })

    assert_equal "zuiddrecht", s.environment_id
    assert_equal "zuiddrecht", s.active_token_set.id
    assert_equal "amsterdam", store({}, { "active_id" => "amsterdam" }).active_token_set.id
  end

  def test_an_unknown_or_hostile_value_in_the_environment_is_ignored
    ["nothing-like-this", "red; } body {", "../../etc/passwd", "custom-7"].each do |value|
      s = store({ "THEMATIQ_DESIGN_SYSTEM" => value }, { "active_id" => "amsterdam" })

      assert_nil s.environment_id, value
      assert_equal value[0, 64], s.environment_value
      assert_equal "amsterdam", s.active_token_set.id, value
    end
    assert_nil store({ "THEMATIQ_DESIGN_SYSTEM" => "  " }).environment_value
  end

  def test_the_environment_may_name_a_custom_design_system
    s = store({ "THEMATIQ_DESIGN_SYSTEM" => "custom-2" },
              { "customs" => { "custom-2" => { "name" => "Town hall", "based_on" => "cunningham", "overrides" => { "primary" => "#aa0055" } } } })

    assert_equal "#aa0055", s.active_token_set["primary"]
  end

  def tables(ready = true)
    { "uploads" => ready, "scopes" => true, "changes" => true }
  end

  def test_a_healthy_report
    report = Health.report(store: store, tables: tables, core_changed: [])

    assert_equal "ok", report["status"]
    assert_empty report["problems"]
    assert_equal OpenProject::Thematiq::VERSION, report["version"]
    assert_operator report["catalogue"]["sets"], :>=, 60
    assert_equal false, report["active"]["from_environment"]
  end

  def test_a_degraded_report_names_each_problem
    report = Health.report(store: store({ "THEMATIQ_DESIGN_SYSTEM" => "nope" }), tables: tables(false),
                           core_changed: ["app/views/layouts/base.html.erb"])

    assert_equal "degraded", report["status"]
    assert_equal %w[table_missing:uploads core_changed environment_unknown], report["problems"]
  end

  def test_the_report_holds_no_value_an_administrator_typed
    s = store({}, { "customs" => { "custom" => { "name" => "<script>", "based_on" => "cunningham", "overrides" => {} } }, "active_custom" => "custom",
                    "nextcloud_url" => "https://secret.example.org" })
    json = JSON.generate(Health.report(store: s, tables: tables, core_changed: []))

    refute_includes json, "secret.example.org"
  end
end
