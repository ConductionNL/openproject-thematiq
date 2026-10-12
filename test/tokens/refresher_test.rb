# frozen_string_literal: true

require "test_helper"

class RefresherTest < Minitest::Test
  Tokens = OpenProject::Thematiq::Tokens

  class MemoryStore
    attr_accessor :base_url, :token_set, :fetched_at, :checked_at, :last_error

    def record_success(token_set, at:)
      @checked_at = at
      @last_error = nil
      return unless token_set

      @token_set = token_set
      @fetched_at = at
    end

    def record_failure(error, _detail, at:)
      @checked_at = at
      @last_error = error
    end
  end

  class FakeClient
    attr_reader :calls

    def initialize(*results)
      @results = results
      @calls = []
    end

    def fetch(base_url, known_revision: nil)
      @calls << [base_url, known_revision]
      @results.shift
    end
  end

  NOW = Time.utc(2026, 10, 12, 12, 0, 0)

  def result(**) = Tokens::Client::Result.new(**)

  def payload(revision = "r1", primary = "#3669a5")
    { "version" => 1, "id" => "zuiddrecht", "name" => "Zuiddrecht", "revision" => revision, "tokens" => { "primary" => primary } }
  end

  def refresher(store, client)
    Tokens::Refresher.new(store:, client:, clock: -> { NOW })
  end

  def test_does_nothing_without_a_base_url
    store = MemoryStore.new
    client = FakeClient.new

    assert_equal :not_configured, refresher(store, client).call.status
    assert_empty client.calls
  end

  def test_stores_a_fetched_token_set
    store = MemoryStore.new.tap { |s| s.base_url = "https://cloud.example.org" }
    client = FakeClient.new(result(status: :ok, payload: payload))
    outcome = refresher(store, client).call

    assert_equal :updated, outcome.status
    assert_equal "#3669a5", store.token_set["primary"]
    assert_equal NOW, store.fetched_at
    assert_equal [["https://cloud.example.org", nil]], client.calls
  end

  def test_sends_the_known_revision_and_keeps_the_set_on_not_modified
    store = MemoryStore.new.tap { |s| s.base_url = "https://cloud.example.org" }
    refresher(store, FakeClient.new(result(status: :ok, payload: payload))).call
    earlier = store.token_set
    store.fetched_at = NOW - 600
    client = FakeClient.new(result(status: :not_modified))
    outcome = refresher(store, client).call

    assert_equal :unchanged, outcome.status
    assert_same earlier, store.token_set
    assert_equal NOW - 600, store.fetched_at
    assert_equal NOW, store.checked_at
    assert_equal "r1", client.calls.first.last
  end

  def test_force_leaves_the_revision_out
    store = MemoryStore.new.tap { |s| s.base_url = "https://cloud.example.org" }
    refresher(store, FakeClient.new(result(status: :ok, payload: payload))).call
    client = FakeClient.new(result(status: :ok, payload: payload("r2", "#000000")))
    refresher(store, client).call(force: true)

    assert_nil client.calls.first.last
    assert_equal "r2", store.token_set.revision
  end

  def test_a_failed_fetch_keeps_the_last_good_set
    store = MemoryStore.new.tap { |s| s.base_url = "https://cloud.example.org" }
    refresher(store, FakeClient.new(result(status: :ok, payload: payload))).call
    outcome = refresher(store, FakeClient.new(result(status: :error, error: "timeout"))).call

    assert_equal :failed, outcome.status
    assert_equal "timeout", store.last_error
    assert_equal "r1", store.token_set.revision
  end

  def test_a_document_outside_the_contract_is_a_failure
    store = MemoryStore.new.tap { |s| s.base_url = "https://cloud.example.org" }
    outcome = refresher(store, FakeClient.new(result(status: :ok, payload: { "version" => 9 }))).call

    assert_equal %i[failed], [outcome.status]
    assert_equal "invalid_payload", store.last_error
    assert_nil store.token_set
  end

  def test_not_modified_without_a_stored_set_is_a_failure
    store = MemoryStore.new.tap { |s| s.base_url = "https://cloud.example.org" }
    outcome = refresher(store, FakeClient.new(result(status: :not_modified))).call

    assert_equal :failed, outcome.status
    assert_equal "unexpected_not_modified", store.last_error
  end

  def test_check_stores_nothing
    store = MemoryStore.new
    outcome = refresher(store, FakeClient.new(result(status: :ok, payload: payload))).check("https://cloud.example.org")

    assert outcome.success?
    assert_equal "Zuiddrecht", outcome.token_set.name
    assert_nil store.token_set
    assert_nil store.checked_at
  end

  def test_check_reports_failures
    store = MemoryStore.new
    assert_equal "unreachable", refresher(store, FakeClient.new(result(status: :error, error: "unreachable"))).check("x").error
    assert_equal "invalid_payload", refresher(store, FakeClient.new(result(status: :ok, payload: {}))).check("x").error
  end
end
