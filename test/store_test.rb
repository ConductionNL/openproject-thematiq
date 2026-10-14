# frozen_string_literal: true

require "test_helper"

class StoreTest < Minitest::Test
  Catalogue = OpenProject::Thematiq::Catalogue
  Store = OpenProject::Thematiq::Store

  def catalogue
    @catalogue ||= Catalogue.from_document(
      { "version" => 1,
        "sets" => [{ "id" => "cunningham", "name" => "Cunningham", "tokens" => { "primary" => "#1a67a3" } },
                   { "id" => "zuiddrecht", "name" => "Zuiddrecht", "tokens" => { "primary" => "#3669a5", "radius" => "8px" } }] }
    )
  end

  def store(data = {})
    @backend = MemoryBackend.new(data)
    Store.new(backend: @backend, catalogue:)
  end

  def test_a_fresh_install_uses_cunningham
    assert_nil store.active_id
    assert_equal "cunningham", store.active_token_set.id
  end

  def test_activate_stores_the_id
    s = store

    assert_equal "zuiddrecht", s.activate("zuiddrecht").id
    assert_equal({ "active_id" => "zuiddrecht", "active_custom" => nil, "use_custom" => false }, @backend.data)
    assert_equal "#3669a5", s.active_token_set["primary"]
  end

  def test_activate_refuses_an_unknown_id_and_changes_nothing
    s = store("active_id" => "zuiddrecht")

    [nil, "", "nope", "../x", 7, ["zuiddrecht"], { "a" => 1 }].each { |id| assert_nil s.activate(id) }
    assert_equal "zuiddrecht", s.active_id
  end

  def test_a_stored_id_that_left_the_catalogue_falls_back_to_the_default
    assert_equal "cunningham", store("active_id" => "gone").active_token_set.id
  end

  def test_broken_settings_fall_back_to_the_default
    [nil, "x", [], { "active_id" => 7 }, { "active_id" => ["zuiddrecht"] }, { "active_id" => { "a" => "b" } }].each do |data|
      assert_equal "cunningham", store(data).active_token_set.id
    end
  end

  def test_activate_keeps_other_keys_in_the_settings
    s = store("something_else" => 1)
    s.activate("zuiddrecht")

    assert_equal({ "something_else" => 1, "active_id" => "zuiddrecht", "active_custom" => nil, "use_custom" => false }, @backend.data)
  end

  # --- the Nextcloud address for the app switcher ---

  def test_no_nextcloud_address_on_a_fresh_install
    assert_nil store.nextcloud_url
  end

  def test_saves_an_http_address_without_its_trailing_slash
    s = store("active_id" => "zuiddrecht")

    assert s.save_nextcloud_url(" https://cloud.example.org/ ")
    assert_equal "https://cloud.example.org", s.nextcloud_url
    assert_equal({ "active_id" => "zuiddrecht", "nextcloud_url" => "https://cloud.example.org" }, @backend.data)
  end

  def test_the_key_is_the_one_the_shell_reads
    shell = File.read(File.expand_path("../lib/open_project/thematiq/shell.rb", __dir__))

    assert_includes shell, %(NEXTCLOUD_URL_SETTING = "#{Store::NEXTCLOUD_URL_KEY}")
  end

  def test_an_empty_address_clears_it
    s = store("nextcloud_url" => "https://cloud.example.org")

    assert s.save_nextcloud_url("  ")
    assert_nil s.nextcloud_url
    assert s.save_nextcloud_url(nil)
  end

  def test_refuses_what_is_not_an_http_address_and_keeps_the_old_one
    s = store("nextcloud_url" => "https://cloud.example.org")

    ["javascript:alert(1)", "cloud.example.org", "ftp://cloud.example.org", 'https://cloud.example.org/"onclick="x',
     "https://cloud.example.org/<script>", "https://a b", "https://#{'a' * 500}.example.org"].each do |value|
      refute s.save_nextcloud_url(value), value
    end
    assert_equal "https://cloud.example.org", s.nextcloud_url
  end

  def test_a_tampered_stored_address_is_not_given_out
    assert_nil store("nextcloud_url" => "javascript:alert(1)").nextcloud_url
    assert_nil store("nextcloud_url" => ["https://cloud.example.org"]).nextcloud_url
  end

  # --- settings left by the version that fetched from thematiq ---

  def test_removes_the_keys_of_the_link_era_and_keeps_the_rest
    s = store("base_url" => "http://cloud.example.org", "token_set" => { "id" => "x" }, "fetched_at" => "2026-10-12T16:46:55Z",
              "checked_at" => "x", "last_error" => nil, "last_error_detail" => nil,
              "active_id" => "zuiddrecht", "nextcloud_url" => "https://cloud.example.org")

    assert_equal Store::LEGACY_KEYS.sort, s.remove_legacy_settings.sort
    assert_equal({ "active_id" => "zuiddrecht", "nextcloud_url" => "https://cloud.example.org" }, @backend.data)
  end

  def test_does_not_write_when_there_is_nothing_to_remove
    s = store("active_id" => "zuiddrecht")
    before = @backend.data

    assert_empty s.remove_legacy_settings
    assert_same before, @backend.data
  end
end
