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
    assert_equal({ "active_id" => "zuiddrecht", "use_custom" => false }, @backend.data)
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

    assert_equal({ "something_else" => 1, "active_id" => "zuiddrecht", "use_custom" => false }, @backend.data)
  end
end
