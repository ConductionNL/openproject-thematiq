# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/diff"
require "open_project/thematiq/trial"

class DiffTest < Minitest::Test
  Diff = OpenProject::Thematiq::Diff
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet

  def set(tokens, dark: nil, vocabulary: nil)
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => tokens, "dark" => dark, "vocabulary" => vocabulary }.compact)
  end

  def test_only_the_values_that_differ_light_and_dark
    now = set({ "primary" => "#111111" }, dark: { "tokens" => { "primary" => "#222222" } }, vocabulary: { "color-error" => "#cc0000" })
    chosen = set({ "primary" => "#333333" }, vocabulary: { "color-error" => "#cc0000", "color-success" => "#008800" })
    rows = Diff.between(now, chosen)

    assert_equal [%w[primary light], %w[color-success light], %w[primary dark]], rows.map { |row| [row.key, row.layer] }
    assert_equal ["#111111", "#333333"], [rows[0].from, rows[0].to]
    assert_nil rows[1].from, "the design system of now leaves it to OpenProject"
    assert_equal ["#222222", nil], [rows[2].from, rows[2].to]
    assert_empty Diff.between(now, now)
  end

  def test_kept_values_are_the_unticked_rows_that_can_be_kept
    now = set({ "primary" => "#111111", "link" => "#121212" }, dark: { "tokens" => { "primary" => "#222222" } })
    chosen = set({ "primary" => "#333333", "link" => "#343434" }, vocabulary: { "color-success" => "#008800" })
    rows = Diff.between(now, chosen)

    assert_equal [{}, {}], Diff.kept(rows, rows.map(&:id))
    assert_equal [{ "primary" => "#111111", "link" => "#121212" }, { "primary" => "#222222" }], Diff.kept(rows, [])
    assert_equal [{ "link" => "#121212" }, {}], Diff.kept(rows, %w[primary dark.primary])
    refute rows.find { |row| row.key == "color-success" }.keepable?
    assert_equal [{}, {}], Diff.kept(rows, rows.map(&:id) - ["color-success"]), "OpenProject's own cannot be kept"
  end

  def test_ids_from_outside_only_ever_untick
    rows = Diff.between(set({ "primary" => "#111111" }), set({ "primary" => "#333333" }))

    assert_equal [{ "primary" => "#111111" }, {}], Diff.kept(rows, ["<script>", nil, 42, ["primary"]])
  end
end

class TrialTest < Minitest::Test
  Trial = OpenProject::Thematiq::Trial
  Admin = Struct.new(:admin?)

  def store
    OpenProject::Thematiq::Store.new(backend: MemoryBackend.new)
  end

  def test_a_trial_is_for_an_admin_in_their_own_session_and_ends_after_a_day
    session = {}
    Trial.start(session, "zuiddrecht", now: Time.at(1000))

    assert_equal "zuiddrecht", Trial.id(session, now: Time.at(1001))
    assert_nil Trial.id(session, now: Time.at(1000 + Trial::SECONDS))
    assert_nil Trial.id({}, now: Time.at(1001)), "another session has no trial"
    Trial.stop(session)
    assert_nil Trial.id(session)
  end

  def test_only_an_administrator_sees_it_and_only_a_design_system_that_exists
    session = {}
    Trial.start(session, "zuiddrecht")

    assert_equal "zuiddrecht", Trial.token_set(session:, user: Admin.new(true), store:).id
    assert_nil Trial.token_set(session:, user: Admin.new(false), store:), "a former administrator sees what everyone sees"
    assert_nil Trial.token_set(session:, user: nil, store:)
    Trial.start(session, "nothing-like-this")
    assert_nil Trial.token_set(session:, user: Admin.new(true), store:)
  end

  def test_a_broken_session_value_is_no_trial
    [nil, "zuiddrecht", { "id" => 1, "until" => 9_999_999_999 }, { "id" => "x", "until" => "later" }, []].each do |value|
      assert_nil Trial.id({ Trial::KEY => value }), value.inspect
    end
  end
end
