# frozen_string_literal: true

require "test_helper"
require "json"
require "open_project/thematiq/transfer"

class VocabularyTest < Minitest::Test
  Vocabulary = OpenProject::Thematiq::Tokens::Vocabulary
  Validator = OpenProject::Thematiq::Tokens::Validator
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  CustomDraft = OpenProject::Thematiq::CustomDraft
  Transfer = OpenProject::Thematiq::Transfer
  FIXTURE = File.expand_path("../fixtures/transfer/zuiddrecht-exported-2026-10-13.json", __dir__)

  # One valid value per kind, as thematiq's token files write them.
  SAMPLES = {
    color: "rgba(54, 105, 165, 0.5)", length: "1.75rem", size: "1328px", font_family: "'Red Hat Display', sans-serif",
    font_weight: "600", number: "1.15", duration: "100ms", offset: "auto", rgb_triplet: "204, 0, 0",
    filter: "brightness(0) invert(1)", border: "1px solid rgba(138, 146, 158, 0.25)", text_transform: "uppercase"
  }.freeze

  def full_vocabulary
    Vocabulary::KINDS.to_h { |key, kind| [key, SAMPLES.fetch(kind)] }
  end

  def test_every_kind_has_a_validator_and_a_sample_it_accepts
    Vocabulary::KINDS.values.uniq.each do |kind|
      assert_respond_to Validator, kind
      assert_equal SAMPLES.fetch(kind), Validator.public_send(kind, SAMPLES.fetch(kind)), kind
    end
  end

  def test_no_key_is_a_role_or_a_role_name
    assert_empty Vocabulary.keys & TokenSet::ALL_KINDS.keys
    assert_empty Vocabulary.keys & Vocabulary::ROLE_NAMES
  end

  def test_no_key_takes_an_address
    Vocabulary.keys.each { |key| refute_match(/url|image|clip-path/, key) }
  end

  # A Figma path is the CSS name cut at its first two dashes. Every key has a dash, so no key is a group of another.
  def test_every_key_makes_a_path_of_three_parts
    Vocabulary.keys.each { |key| assert_includes key, "-", key }
  end

  def test_css_names_go_both_ways
    assert_equal "--nldesign-color-error", Vocabulary.css_name("color-error")
    assert_equal "color-error", Vocabulary.key_of("--nldesign-color-error")
    assert_nil Vocabulary.key_of("--nldesign-color-primary"), "a role name is not a vocabulary key"
    assert_nil Vocabulary.key_of("--nldesign-logo-url")
    assert_nil Vocabulary.key_of("color-error")
    assert_nil Vocabulary.key_of(nil)
  end

  def test_every_drawn_key_is_a_key
    assert_empty Vocabulary::DRAWN - Vocabulary.keys
  end

  def test_no_hostile_value_passes_any_kind
    Vocabulary::KINDS.values.uniq.each do |kind|
      HOSTILE_VALUES.each { |value| assert_nil Validator.public_send(kind, value), "#{kind} accepted #{value.inspect}" }
    end
  end

  def test_the_new_kinds_refuse_near_misses
    { font_weight: ["0", "1001", "450.5", "heavy", "700;"], number: ["-1", "1e3", "1.2.3", "one"],
      duration: ["100", "-1s", "1min", "100 ms"], offset: ["auto auto", "calc(100% - 4px)"],
      rgb_triplet: ["256, 0, 0", "1, 2", "1, 2, 3, 4", "a, b, c"],
      filter: ["blur(4px)", "url(#x)", "brightness(0) invert(1) " * 4, "brightness(1;)", "drop-shadow(0 0 1px red)"],
      border: ["1px solid", "1px groove red", "1px solid red; color: red", "9999px solid red", "1px solid url(x)"],
      text_transform: ["full-width", "upper"], size: ["99999px", "3vw"] }.each do |kind, values|
      values.each { |value| assert_nil Validator.public_send(kind, value), "#{kind} accepted #{value.inspect}" }
    end
  end

  def test_the_new_kinds_clean_what_they_accept
    assert_equal "204, 0, 0", Validator.rgb_triplet("204,0 ,0")
    assert_equal "brightness(0) invert(1)", Validator.filter("Brightness(0)   INVERT(1)")
    assert_equal "none", Validator.filter("none")
    assert_equal "hue-rotate(-90deg)", Validator.filter("hue-rotate(-90deg)")
    assert_equal "1px solid #cfd5dd", Validator.border("1px   solid #CFD5DD")
    assert_equal "0", Validator.border("0")
    assert_equal "bold", Validator.font_weight("Bold")
  end

  def test_a_set_keeps_its_vocabulary_and_drops_what_fails
    token_set = TokenSet.from_set({ "id" => "v", "name" => "V", "tokens" => {},
                                    "vocabulary" => { "color-error" => "#D52B1E", "color-info" => "red; } x {", "nope" => "#fff" } })

    assert_equal({ "color-error" => "#d52b1e" }, token_set.vocabulary)
    assert_equal "#d52b1e", token_set["color-error"]
    assert_includes token_set.rejected, "vocabulary.color-info"
  end

  def test_nothing_is_derived_for_a_key_a_set_leaves_out
    token_set = TokenSet.from_set({ "id" => "v", "name" => "V", "tokens" => { "accent" => "#cc0000" } })

    assert_empty token_set.vocabulary
    assert_nil token_set["color-error"]
  end

  def test_a_set_without_vocabulary_exports_as_before
    assert_equal File.read(FIXTURE), Transfer.export(Transfer.import(File.read(FIXTURE)))
  end

  def test_a_file_exported_before_the_vocabulary_imports
    imported = Transfer.import(File.read(FIXTURE))

    assert_equal "zuiddrecht", imported.id
    assert_empty imported.vocabulary
    assert_equal "#3669a5", imported["primary"]
  end

  def test_the_whole_vocabulary_survives_export_and_import
    original = TokenSet.from_set({ "id" => "full", "name" => "Full", "tokens" => {}, "vocabulary" => full_vocabulary })
    copy = Transfer.import(Transfer.export(original))

    assert_equal Vocabulary.keys.size, original.vocabulary.size
    assert_equal original.vocabulary, copy.vocabulary
  end

  def test_an_import_refuses_an_unknown_key_a_role_name_or_a_bad_value_in_the_vocabulary
    base = JSON.parse(File.read(FIXTURE))
    [{ "color-made-up" => "#fff" }, { "color-primary" => "#fff" }, { "logo-url" => "url(x)" },
     { "color-error" => "#fff}</style>" }, { "color-error" => ["#fff"] }].each do |vocabulary|
      assert_raises(Transfer::Refused, vocabulary.inspect) { Transfer.import(JSON.generate(base.merge("vocabulary" => vocabulary))) }
    end
    assert_raises(Transfer::Refused) { Transfer.import(JSON.generate(base.merge("vocabulary" => ["color-error"]))) }
  end

  def test_a_vocabulary_key_in_tokens_refuses_an_import
    base = JSON.parse(File.read(FIXTURE))
    base["tokens"]["color-error"] = "#d52b1e"

    assert_raises(Transfer::Refused) { Transfer.import(JSON.generate(base)) }
  end

  def test_a_custom_design_system_keeps_the_values_that_differ_from_its_base
    base = TokenSet.from_set({ "id" => "b", "name" => "B", "tokens" => {}, "vocabulary" => { "color-error" => "#d52b1e" } })
    draft = CustomDraft.new(base:, name: "Mine", overrides: { "color-warning" => "#7A4F00", "color-error" => "#d52b1e" },
                            vocabulary: { "color-success" => "#1e6b2a", "nope" => "#fff" })

    assert draft.valid?
    assert_equal({ "color-warning" => "#7a4f00", "color-success" => "#1e6b2a" }, draft.vocabulary)
    assert_empty draft.overrides
    assert_equal 2, draft.changed_count
    assert draft.overridden?("color-warning")
    assert_equal "#d52b1e", draft.token_set["color-error"], "the base's value stays"
    assert_equal draft.vocabulary, draft.definition["vocabulary"]
  end

  def test_a_bad_vocabulary_value_in_the_editor_is_an_error_on_its_key
    draft = CustomDraft.new(base: TokenSet.fallback, name: "Mine", overrides: { "color-error" => "red; } x {" })

    refute draft.valid?
    assert draft.error?("color-error")
    assert_equal "red; } x {", draft.field_value("color-error")
  end

  def test_the_store_keeps_the_vocabulary_of_a_custom_design_system
    store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new)
    draft = CustomDraft.new(base: store.catalogue.default, name: "Mine", overrides: { "primary" => "#aa0055" }, id: "custom",
                            vocabulary: { "color-error" => "#d52b1e" })

    assert store.save_custom(draft)
    assert_equal({ "color-error" => "#d52b1e" }, store.custom_draft("custom").vocabulary)
    assert_equal "#d52b1e", store.custom_set("custom")["color-error"]
  end
end
