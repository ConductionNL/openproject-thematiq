# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/transfer"

class TransferTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Transfer = OpenProject::Thematiq::Transfer
  CustomDraft = OpenProject::Thematiq::CustomDraft

  def set_hash(tokens = {}, extra = {})
    { "id" => "house-style", "name" => "House style",
      "tokens" => { "primary" => "#aa0055", "radius" => "12px", "font-family" => "'Fira Sans', sans-serif" }.merge(tokens),
      "logo" => { "file" => nil, "inverse_file" => nil, "licence" => nil, "redistributable" => false } }.merge(extra)
  end

  def refused(text)
    assert_raises(Transfer::Refused) { Transfer.import(text) }.code
  end

  def test_export_then_import_gives_the_same_design_system
    original = TokenSet.from_set(set_hash("accent" => "#cc0000"))
    copy = Transfer.import(Transfer.export(original))

    assert_equal original.tokens, copy.tokens
    assert_equal original.name, copy.name
    assert_equal original.id, copy.id
  end

  def test_every_bundled_set_survives_export_and_import
    OpenProject::Thematiq::Catalogue.bundled.sets.each do |token_set|
      assert_equal token_set.tokens, Transfer.import(Transfer.export(token_set)).tokens, token_set.id
    end
  end

  def test_every_set_entry_of_the_catalogue_files_imports_as_it_is_written_there
    [OpenProject::Thematiq::Catalogue::FILE, OpenProject::Thematiq::Catalogue::OWN_FILE].each do |file|
      JSON.parse(File.read(file))["sets"].each do |entry|
        imported = Transfer.import(JSON.generate(entry))

        assert_equal entry["id"], imported.id
        assert_equal entry["dark"].nil?, !imported.dark?, entry["id"]
      end
    end
  end

  def test_a_custom_design_system_survives_export_and_import
    base = TokenSet.fallback
    draft = CustomDraft.new(base:, name: "Mine", overrides: { "primary" => "#aa0055", "chip" => "#eeeeee" })
    imported = Transfer.import(Transfer.export(draft.token_set))
    again = CustomDraft.new(base:, name: imported.name, overrides: imported.tokens)

    assert again.valid?
    assert_equal draft.token_set.tokens, again.token_set.tokens
    assert_equal draft.overrides, again.overrides, "only the values that differ from the base are overrides again"
  end

  def test_the_export_is_the_set_shape_and_nothing_else
    exported = JSON.parse(Transfer.export(TokenSet.from_set(set_hash)))

    assert_equal %w[id name tokens logo], exported.keys
    assert_equal %w[file inverse_file licence redistributable], exported["logo"].keys
  end

  def test_file_name
    assert_equal "thematiq-house-style.json", Transfer.file_name(TokenSet.from_set(set_hash))
    assert_equal "thematiq-a-b.json", Transfer.file_name(TokenSet.from_set(set_hash({}, "id" => "a.b")))
  end

  def test_refuses_what_is_not_a_file_with_content
    [nil, "", "   \n", 7, []].each { |text| assert_equal "empty", refused(text) }
  end

  def test_refuses_a_file_over_the_size_cap
    padded = JSON.generate(set_hash) + (" " * Transfer::MAX_BYTES)

    assert_equal "too_large", refused(padded)
  end

  def test_refuses_what_is_not_json
    ["{ not json", "<html>", "\xff\xfe{}".b, "{\"id\": \"a\", ", "NaN"].each { |text| assert_equal "invalid_json", refused(text) }
  end

  def test_refuses_json_that_is_not_a_set
    assert_equal "not_an_object", refused("[]")
    assert_equal "not_an_object", refused("\"x\"")
    assert_equal "not_an_object", refused("null")
    assert_equal "id_invalid", refused(JSON.generate(set_hash({}, "id" => "../../etc")))
    assert_equal "id_invalid", refused(JSON.generate(set_hash.except("id")))
    assert_equal "tokens_missing", refused(JSON.generate(set_hash.except("tokens")))
    assert_equal "tokens_missing", refused(JSON.generate(set_hash({}, "tokens" => [])))
    assert_equal "logo_invalid", refused(JSON.generate(set_hash({}, "logo" => "x")))
    assert_equal "name_invalid", refused(JSON.generate(set_hash({}, "name" => "x" * 200)))
  end

  def test_refuses_unknown_keys_at_every_level
    assert_equal "unknown_keys", refused(JSON.generate(set_hash({}, "version" => 1)))
    assert_equal "unknown_keys", refused(JSON.generate(set_hash({}, "script" => "<script>alert(1)</script>")))
    assert_equal "unknown_keys", refused(JSON.generate(set_hash("shadow" => "0 0 1px red")))
    assert_equal "unknown_keys", refused(JSON.generate(set_hash({}, "logo" => { "url" => "https://evil.example/x.svg" })))
  end

  def test_refuses_deep_nesting
    assert_equal "invalid_json", refused(JSON.generate(set_hash({}, "logo" => { "file" => [[[["x"]]]] })))
  end

  def test_one_hostile_value_refuses_the_whole_file
    OpenProject::Thematiq::Tokens::TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.compact.each do |value|
        code = refused(JSON.generate(set_hash(key => value)))

        assert_includes %w[token_invalid invalid_json], code, "#{key} = #{value.inspect}"
      end
    end
  end

  def test_a_null_token_is_a_missing_token
    imported = Transfer.import(JSON.generate(set_hash("accent" => nil)))

    assert_equal OpenProject::Thematiq::Tokens::Defaults::TOKENS["accent"], imported["accent"]
  end

  def test_a_hostile_logo_reference_is_dropped_not_followed
    imported = Transfer.import(JSON.generate(set_hash({}, "logo" => { "file" => "../../../etc/passwd", "inverse_file" => "https://evil.example/x.svg",
                                                                        "licence" => "x", "redistributable" => true })))

    assert_nil imported.logo_file
    assert_nil imported.logo_inverse_file
  end

  def test_a_hostile_name_is_cleaned
    imported = Transfer.import(JSON.generate(set_hash({}, "name" => "<script>alert(1)</script>")))

    assert_equal "<script>alert(1)</script>", imported.name, "the name is plain text; the page escapes it, CSS never sees it"
    refute_includes OpenProject::Thematiq::Variables::Generator.new(imported).css, "script"
  end

  def test_duplicate_keys_cannot_smuggle_a_value_past_the_check
    text = '{"id":"a","name":"A","tokens":{"primary":"#aa0055","primary":"red; } body { display:none"}}'

    assert_equal "token_invalid", refused(text)
  end
end
