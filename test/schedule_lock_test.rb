# frozen_string_literal: true

require "test_helper"
require "time"
require "open_project/thematiq/bundle"

class ScheduleLockTest < Minitest::Test
  Store = OpenProject::Thematiq::Store
  NOW = Time.utc(2026, 10, 14, 12)

  def store
    @store ||= Store.new(backend: MemoryBackend.new("active_id" => "cunningham"), env: {})
  end

  def teardown
    Store.on_switch = nil
  end

  def test_a_planned_switch_is_made_by_the_first_read_after_its_time
    made = []
    Store.on_switch = ->(token_set, _store) { made << token_set.id }
    assert_nil store.plan_switch(set_id: "zuiddrecht", at: NOW + 3600, now: NOW)
    assert_equal ["zuiddrecht"], store.planned_switches.map { |entry| entry["set_id"] }

    assert_nil store.apply_due_switch(now: NOW + 60)
    assert_equal "cunningham", store.active_id
    assert_equal "zuiddrecht", store.apply_due_switch(now: NOW + 3601).id
    assert_equal "zuiddrecht", store.active_id
    assert_empty store.planned_switches
    assert_equal ["zuiddrecht"], made
  end

  def test_two_due_switches_make_the_later_one
    store.plan_switch(set_id: "zuiddrecht", at: NOW + 60, now: NOW)
    store.plan_switch(set_id: "amsterdam", at: NOW + 120, now: NOW)
    assert_equal "amsterdam", store.apply_due_switch(now: NOW + 300).id
  end

  def test_the_rules_of_a_switch
    assert_equal "unknown_set", store.plan_switch(set_id: "nope", at: NOW + 60, now: NOW)
    assert_equal "time", store.plan_switch(set_id: "zuiddrecht", at: NOW - 60, now: NOW)
    assert_equal "time", store.plan_switch(set_id: "zuiddrecht", at: "tomorrow", now: NOW)
    store.plan_switch(set_id: "zuiddrecht", at: NOW + 60, now: NOW)
    store.cancel_switch(0)
    assert_empty store.planned_switches
  end

  def test_locks
    assert store.lock_project("demo-project", true)
    assert store.locked?("demo-project")
    refute store.lock_project("../evil", true)
    store.lock_project("demo-project", false)
    refute store.locked?("demo-project")
  end

  def test_the_bundle_carries_and_checks_both
    store.lock_project("demo-project", true)
    store.plan_switch(set_id: "zuiddrecht", at: Time.now + 3600)
    bundle = OpenProject::Thematiq::Bundle.build(settings: store.settings_snapshot, scopes: [])
    catalogue = OpenProject::Thematiq::Catalogue.bundled
    assert OpenProject::Thematiq::Bundle.read(bundle, catalogue:)
    bundle["settings"]["planned_switches"] = [{ "set_id" => "nope", "at" => "2030-01-01T00:00:00Z" }]
    assert_raises(OpenProject::Thematiq::Bundle::Refused) { OpenProject::Thematiq::Bundle.read(bundle, catalogue:) }
    bundle["settings"]["planned_switches"] = nil
    bundle["settings"]["locked_projects"] = ["<script>"]
    assert_raises(OpenProject::Thematiq::Bundle::Refused) { OpenProject::Thematiq::Bundle.read(bundle, catalogue:) }
  end
end
