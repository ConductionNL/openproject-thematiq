# frozen_string_literal: true

require "test_helper"

class CustomDraftTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  CustomDraft = OpenProject::Thematiq::CustomDraft
  Catalogue = OpenProject::Thematiq::Catalogue
  Store = OpenProject::Thematiq::Store

  def base
    @base ||= TokenSet.from_set({ "id" => "zuiddrecht", "name" => "Zuiddrecht",
                                  "tokens" => { "primary" => "#3669a5", "radius" => "8px", "accent" => "#cc0000" } })
  end

  def draft(overrides = {}, name = "House style")
    CustomDraft.new(base:, name:, overrides:)
  end

  def test_valid_overrides_win_over_the_base
    d = draft("primary" => "#AA0055", "radius" => "12px", "font-family" => %("Fira Sans", sans-serif))

    assert d.valid?
    assert_equal({ "primary" => "#aa0055", "radius" => "12px", "font-family" => "'Fira Sans', sans-serif" }, d.overrides)
    assert_equal "#aa0055", d.token_set["primary"]
    assert_equal "#cc0000", d.token_set["accent"], "tokens without an override come from the base"
    assert_equal "custom", d.token_set.id
    assert_equal "House style", d.token_set.name
  end

  def test_empty_fields_are_not_overrides
    d = draft("primary" => "", "radius" => "   ", "link" => nil)

    assert d.valid?
    assert_empty d.overrides
    assert_equal base.tokens, d.token_set.tokens
  end

  def test_a_value_equal_to_the_base_is_not_an_override
    d = draft("primary" => "#3669A5", "radius" => "8px")

    assert_empty d.overrides
    refute d.overridden?("primary")
  end

  def test_an_invalid_value_is_an_error_and_never_reaches_the_token_set
    d = draft("primary" => "red; } body { display:none", "radius" => "12px")

    refute d.valid?
    assert_equal %w[primary], d.errors
    assert d.error?("primary")
    assert_equal({ "radius" => "12px" }, d.overrides)
    assert_equal "#3669a5", d.token_set["primary"]
    assert_equal "red; } body { display:none", d.field_value("primary"), "the field shows what was typed, to correct it"
    assert_equal "12px", d.field_value("radius")
    assert_equal "", d.field_value("link")
  end

  def test_every_hostile_value_in_every_token
    TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        d = draft(key => value)
        css = OpenProject::Thematiq::Variables::Generator.new(d.token_set).css

        refute d.overridden?(key), "#{key} took #{value.inspect}"
        refute_match(/[<>\\@]|url\(|expression|display|!important/i, css)
        assert_equal base.tokens, d.token_set.tokens
      end
    end
  end

  def test_unknown_keys_and_wrong_shapes_are_ignored
    assert_empty draft("shadow" => "#fff", "evil } body {" => "#fff").overrides
    assert_empty CustomDraft.new(base:, name: "x", overrides: "primary=#fff").overrides
    assert_empty CustomDraft.new(base:, name: "x", overrides: nil).overrides
    assert_empty CustomDraft.new(base:, name: "x", overrides: [["primary", "#fff"]]).overrides
  end

  def test_a_value_over_the_length_limit_is_an_error
    d = draft("font-family" => "Arial, " * 100)

    assert_equal %w[font-family], d.errors
    assert_operator d.field_value("font-family").length, :<=, CustomDraft::MAX_INPUT
  end

  def test_the_name_is_required_and_cleaned
    assert_equal %w[name], draft({}, "").errors
    assert_equal %w[name], draft({}, nil).errors
    assert_equal %w[name], draft({}, "x" * 81).errors
    assert_equal "a b", draft({}, "a\nb").name
    assert_equal base.name, draft({}, "").token_set.name
  end

  def test_definition_is_what_the_store_keeps
    assert_equal({ "name" => "House style", "based_on" => "zuiddrecht", "overrides" => { "radius" => "12px" } },
                 draft("radius" => "12px").definition)
  end

  # --- the store ---

  def catalogue
    @catalogue ||= Catalogue.from_document(
      { "version" => 1,
        "sets" => [{ "id" => "cunningham", "name" => "Cunningham", "tokens" => { "primary" => "#1a67a3" } },
                   base.to_set, { "id" => "custom", "name" => "Reserved", "tokens" => {} }] }
    )
  end

  def store(data = {})
    @backend = MemoryBackend.new(data)
    Store.new(backend: @backend, catalogue:)
  end

  def test_the_catalogue_cannot_take_the_custom_id
    assert_nil catalogue.find("custom")
    assert_equal 1, catalogue.skipped
  end

  def test_save_and_activate_the_custom_set
    s = store
    assert s.save_custom(CustomDraft.new(base: catalogue.find("zuiddrecht"), name: "House style", overrides: { "primary" => "#aa0055" }))

    assert_equal "cunningham", s.active_token_set.id, "saving does not apply"
    assert_equal "custom", s.activate("custom").id
    assert s.custom_active?
    assert_equal "#aa0055", s.active_token_set["primary"]
    assert_equal "8px", s.active_token_set["radius"], "the rest comes from the base"
    assert_equal "House style", s.active_token_set.name
  end

  def test_an_invalid_draft_is_not_stored
    s = store

    refute s.save_custom(CustomDraft.new(base: catalogue.default, name: "x", overrides: { "primary" => "url(x)" }))
    refute s.save_custom(CustomDraft.new(base: catalogue.default, name: "", overrides: {}))
    assert_nil s.custom_draft
    assert_empty @backend.data
  end

  def test_activate_custom_without_a_custom_set_does_nothing
    s = store("active_id" => "zuiddrecht")

    assert_nil s.activate("custom")
    assert_equal "zuiddrecht", s.active_token_set.id
  end

  def test_picking_a_catalogue_set_turns_the_custom_set_off_but_keeps_it
    s = store
    s.save_custom(CustomDraft.new(base: catalogue.default, name: "Mine", overrides: { "primary" => "#aa0055" }))
    s.activate("custom")
    s.activate("zuiddrecht")

    refute s.custom_active?
    assert_equal "zuiddrecht", s.active_token_set.id
    assert_equal "Mine", s.custom_draft.name
  end

  def test_delete_custom_falls_back_to_the_chosen_set
    s = store("active_id" => "zuiddrecht")
    s.save_custom(CustomDraft.new(base: catalogue.default, name: "Mine", overrides: {}))
    s.activate("custom")
    s.delete_custom

    assert_nil s.custom_draft
    assert_equal "zuiddrecht", s.active_token_set.id
  end

  def test_stored_overrides_are_checked_again_on_the_way_out
    s = store("use_custom" => true,
              "custom" => { "name" => "Tampered", "based_on" => "zuiddrecht",
                            "overrides" => { "primary" => "red; } body { display:none", "radius" => "12px", "junk" => "x" } })

    assert_equal "#3669a5", s.active_token_set["primary"]
    assert_equal "12px", s.active_token_set["radius"]
  end

  def test_broken_stored_custom_sets_are_ignored
    [nil, "x", [], {}, { "name" => "x" }, { "name" => "x", "overrides" => "y" }, { "name" => "", "overrides" => {} },
     { "name" => 7, "overrides" => {} }].each do |custom|
      s = store("use_custom" => true, "custom" => custom, "active_id" => "zuiddrecht")

      assert_nil s.custom_draft, custom.inspect
      assert_equal "zuiddrecht", s.active_token_set.id
    end
  end

  def test_a_custom_set_whose_base_left_the_catalogue_uses_the_default_as_base
    s = store("use_custom" => true, "custom" => { "name" => "Old", "based_on" => "gone", "overrides" => { "radius" => "12px" } })

    assert_equal "#1a67a3", s.active_token_set["primary"]
    assert_equal "12px", s.active_token_set["radius"]
  end

  # --- several custom design systems ---

  def new_draft(s, name, overrides = {})
    CustomDraft.new(base: catalogue.find("zuiddrecht"), name:, overrides:, id: s.next_custom_id)
  end

  def test_each_new_custom_design_system_gets_its_own_id_and_none_replaces_another
    s = store
    first = new_draft(s, "First", { "primary" => "#aa0055" })
    assert s.save_custom(first)
    second = new_draft(s, "Second", { "primary" => "#00aa55" })
    assert s.save_custom(second)

    assert_equal %w[custom custom-2], [first.id, second.id]
    assert_equal %w[First Second], s.custom_drafts.map(&:name)
    assert_equal "#aa0055", s.custom_set("custom")["primary"]
    assert_equal "#00aa55", s.custom_set("custom-2")["primary"]
    assert_equal "custom-3", s.next_custom_id
  end

  def test_saving_under_an_existing_id_changes_that_one_only
    s = store
    s.save_custom(new_draft(s, "First", { "primary" => "#aa0055" }))
    s.save_custom(new_draft(s, "Second", { "primary" => "#00aa55" }))
    assert s.save_custom(CustomDraft.new(base: catalogue.default, name: "Second, changed", overrides: {}, id: "custom-2"))

    assert_equal ["First", "Second, changed"], s.custom_drafts.map(&:name)
    assert_equal "#aa0055", s.custom_set("custom")["primary"]
  end

  def test_activate_one_of_several_and_delete_it
    s = store("active_id" => "zuiddrecht")
    s.save_custom(new_draft(s, "First", { "primary" => "#aa0055" }))
    s.save_custom(new_draft(s, "Second", { "primary" => "#00aa55" }))

    assert_equal "custom-2", s.activate("custom-2").id
    assert_equal "custom-2", s.active_custom_id
    assert_equal "#00aa55", s.active_token_set["primary"]

    s.delete_custom("custom")
    assert_equal "custom-2", s.active_custom_id, "deleting another one leaves the active one alone"
    s.delete_custom("custom-2")
    assert_nil s.active_custom_id
    assert_equal "zuiddrecht", s.active_token_set.id
    assert_equal "custom", s.next_custom_id, "a freed id is used again"
  end

  def test_the_limit
    s = store
    Store::MAX_CUSTOMS.times { |i| assert s.save_custom(new_draft(s, "Set #{i}")) }

    assert_nil s.next_custom_id
    refute s.save_custom(CustomDraft.new(base: catalogue.default, name: "One more", overrides: {}, id: "custom-9999"))
    assert s.save_custom(CustomDraft.new(base: catalogue.default, name: "Changed", overrides: {}, id: "custom-2")), "changing an existing one still works"
    assert_equal Store::MAX_CUSTOMS, s.custom_drafts.size
  end

  def test_the_shape_of_the_version_with_one_custom_set_still_reads_and_moves_on_the_first_write
    s = store("use_custom" => true, "custom" => { "name" => "Old one", "based_on" => "zuiddrecht", "overrides" => { "radius" => "12px" } })

    assert_equal "custom", s.active_custom_id
    assert_equal "12px", s.active_token_set["radius"]
    assert_equal "custom-2", s.next_custom_id

    s.save_custom(new_draft(s, "New one"))
    assert_equal ["New one", "Old one"], s.custom_drafts.map(&:name)
    assert_nil @backend.data["custom"]
    assert_equal %w[custom custom-2], @backend.data["customs"].keys
    assert_equal "custom", s.active_custom_id, "the old one stays active"
  end

  def test_ids_from_outside_are_not_taken_as_they_are
    assert_equal "custom", CustomDraft.new(base:, name: "x", overrides: {}, id: "../../etc").id
    assert_equal "custom", CustomDraft.new(base:, name: "x", overrides: {}, id: "cunningham").id
    assert_equal "custom", CustomDraft.new(base:, name: "x", overrides: {}, id: nil).id
    assert_equal "custom-12", CustomDraft.new(base:, name: "x", overrides: {}, id: "custom-12").id

    s = store("customs" => { "evil } body {" => { "name" => "x", "overrides" => {} }, "custom-2" => { "name" => "ok", "overrides" => {} } })
    assert_equal %w[custom-2], s.custom_drafts.map(&:id)
    assert_nil s.custom_set("evil } body {")
    assert_nil s.custom_set(nil)
    assert_nil s.activate(["custom-2"])
  end

  def test_the_catalogue_cannot_take_any_custom_id
    c = Catalogue.from_document({ "version" => 1, "sets" => [{ "id" => "custom-2", "name" => "x", "tokens" => {} }, { "id" => "customer", "name" => "ok", "tokens" => {} }] })

    assert_equal %w[customer], c.sets.map(&:id)
  end

  # --- an imported set keeps the logo of the set it came from ---

  def test_a_draft_with_a_logo_reference_shows_that_logo_and_stores_it
    draft = CustomDraft.new(base: catalogue.default, name: "Moved", overrides: {}, logo: { "file" => "zuiddrecht.svg", "inverse_file" => "zuiddrecht-dark.svg" })

    assert_equal "zuiddrecht.svg", draft.token_set.logo_file
    assert_equal "zuiddrecht-dark.svg", draft.token_set.logo_inverse_file
    assert_equal({ "file" => "zuiddrecht.svg", "inverse_file" => "zuiddrecht-dark.svg" }, draft.definition["logo"])

    s = store
    s.save_custom(draft)
    assert_equal "zuiddrecht-dark.svg", s.custom_set("custom").logo_inverse_file
  end

  def test_a_hostile_logo_reference_is_dropped_and_the_base_logo_stays
    draft = CustomDraft.new(base:, name: "Moved", overrides: {}, logo: { "file" => "../../etc/passwd", "inverse_file" => "https://evil.example/x.svg" })

    assert_nil draft.definition["logo"]
    assert_nil draft.token_set.logo_file, "the base in this test has no logo either"
    assert_nil CustomDraft.new(base:, name: "x", overrides: {}, logo: "zuiddrecht.svg").definition["logo"]
  end

  def test_export_then_import_keeps_the_logo_reference
    require "open_project/thematiq/transfer"
    zuiddrecht = OpenProject::Thematiq::Catalogue.bundled.find("zuiddrecht")
    imported = OpenProject::Thematiq::Transfer.import(OpenProject::Thematiq::Transfer.export(zuiddrecht))
    draft = CustomDraft.new(base: OpenProject::Thematiq::Catalogue.bundled.default, name: imported.name, overrides: imported.tokens,
                            logo: { "file" => imported.logo_file, "inverse_file" => imported.logo_inverse_file })

    assert_equal "/thematiq/logos/zuiddrecht-dark.svg", OpenProject::Thematiq::Assets.bundled.logo_url(draft.token_set)
    assert_equal zuiddrecht.tokens, draft.token_set.tokens
  end
end
