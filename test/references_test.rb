# frozen_string_literal: true

require "test_helper"

class ReferencesTest < Minitest::Test
  CustomDraft = OpenProject::Thematiq::CustomDraft

  def base
    OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
  end

  def draft(overrides)
    CustomDraft.new(base:, name: "Refs", overrides:)
  end

  def test_a_reference_is_kept_and_follows_its_token
    d = draft("primary" => "#aa0055", "link" => "{primary}", "color-error" => "{accent}")

    assert d.valid?, d.errors.inspect
    assert_equal "{primary}", d.overrides["link"], "the reference itself is what is stored"
    assert_equal "#aa0055", d.token_set["link"]
    assert_equal base["accent"], d.token_set["color-error"], "a reference to a value of the base"
    assert_equal "{primary}", d.definition["overrides"]["link"]
    assert_equal "#00aa55", draft("primary" => "#00aa55", "link" => "{primary}").token_set["link"], "change the primary and the link follows"
  end

  def test_chains_end_and_circles_kinds_and_unknown_names_are_refused
    assert_equal "#aa0055", draft("primary" => "#aa0055", "accent" => "{primary}", "link" => "{accent}").token_set["link"]
    refute draft("link" => "{accent}", "accent" => "{link}").valid?, "a circle"
    refute draft("link" => "{link}").valid?, "itself"
    refute draft("link" => "{radius}").valid?, "another kind"
    refute draft("link" => "{nothing-like-this}").valid?, "an unknown name"
    refute draft("link" => "{ primary }").valid?, "only the exact form"
  end

  def test_a_stored_reference_survives_the_store
    store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new, env: {})
    assert store.save_custom(CustomDraft.new(base: store.catalogue.default, name: "Refs", overrides: { "primary" => "#aa0055", "link" => "{primary}" }))
    assert_equal "#aa0055", store.custom_set["link"]
    assert_equal "{primary}", store.custom_draft.field_value("link")
  end
end
