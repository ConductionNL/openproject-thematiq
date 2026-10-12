# frozen_string_literal: true

require "test_helper"

class TokenSetTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Defaults = OpenProject::Thematiq::Tokens::Defaults

  def set_hash(tokens = {}, extra = {})
    { "id" => "zuiddrecht", "name" => "Zuiddrecht",
      "tokens" => { "primary" => "#3669a5", "radius" => "8px", "font-family" => "'Fira Sans', sans-serif" }.merge(tokens),
      "logo" => { "file" => "zuiddrecht.svg", "inverse_file" => nil, "licence" => "CC0-1.0", "redistributable" => true } }.merge(extra)
  end

  def test_reads_a_valid_set
    set = TokenSet.from_set(set_hash("accent" => "#cc0000"))

    assert_equal "zuiddrecht", set.id
    assert_equal "Zuiddrecht", set.name
    assert_equal "#3669a5", set["primary"]
    assert_equal "8px", set["radius"]
    assert_equal "#cc0000", set["accent"]
    assert_equal "zuiddrecht.svg", set.logo_file
    assert_nil set.logo_inverse_file
    assert_equal "CC0-1.0", set.logo_licence
    assert_empty set.rejected
  end

  def test_missing_tokens_fall_back_without_being_rejected
    set = TokenSet.from_set(set_hash)

    assert_equal Defaults::TOKENS["action"], set["action"]
    assert_empty set.rejected
  end

  def test_missing_tokens_fall_back_to_the_given_base
    set = TokenSet.from_set(set_hash, base: { "action" => "#000000", "chip" => "url(x)" })

    assert_equal "#000000", set["action"]
    assert_nil set["chip"], "a hostile base value is refused as well"
  end

  def test_hostile_tokens_fall_back_and_are_listed
    set = TokenSet.from_set(set_hash("primary" => "red; } body { display:none", "radius" => "3px; } * {",
                                     "font-family" => "Arial</style>", "chip" => "url(x)"))

    assert_equal Defaults::TOKENS["primary"], set["primary"]
    assert_equal Defaults::TOKENS["radius"], set["radius"]
    assert_equal Defaults::TOKENS["font-family"], set["font-family"]
    assert_nil set["chip"], "chip has no last resort value, so it is left out"
    assert_equal %w[primary chip radius font-family], set.rejected
  end

  def test_every_hostile_value_in_every_token_is_refused
    TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        set = TokenSet.from_set(set_hash(key => value))
        expected = Defaults::TOKENS[key]
        expected.nil? ? assert_nil(set[key]) : assert_equal(expected, set[key], "#{key} took #{value.inspect}")
      end
    end
  end

  def test_unknown_token_keys_are_ignored_by_default
    set = TokenSet.from_set(set_hash("evil } body {" => "#fff", "shadow" => "0 0 1px red"))

    assert_equal TokenSet::KINDS.keys & set.tokens.keys, set.tokens.keys
  end

  def test_refuses_hashes_outside_the_set_shape
    [nil, [], "x", set_hash({}, "tokens" => "x"), set_hash({}, "id" => nil), set_hash({}, "id" => ""),
     set_hash({}, "id" => "a b"), set_hash({}, "id" => "../x"), set_hash({}, "id" => "<script>"),
     set_hash({}, "id" => "x" * 65), set_hash({}, "logo" => "x")].each do |hash|
      assert_raises(TokenSet::InvalidSet) { TokenSet.from_set(hash) }
    end
  end

  def test_a_logo_is_only_kept_when_it_is_redistributable_and_has_a_plain_file_name
    not_free = TokenSet.from_set(set_hash({}, "logo" => { "file" => "a.svg", "redistributable" => false }))
    truthy = TokenSet.from_set(set_hash({}, "logo" => { "file" => "a.svg", "redistributable" => "true" }))

    assert_nil not_free.logo_file
    assert_nil truthy.logo_file

    ["../a.svg", "/etc/passwd", "a/../b.svg", "a.svg/..", "a..svg", "a.exe", "A.svg", "a.svg\n", "https://x/a.svg",
     "a.svg?x", %(a".svg), 7, nil].each do |file|
      set = TokenSet.from_set(set_hash({}, "logo" => { "file" => file, "inverse_file" => file, "redistributable" => true }))

      assert_nil set.logo_file, "kept logo file #{file.inspect}"
      assert_nil set.logo_inverse_file
    end
  end

  def test_a_set_without_a_logo_is_fine
    assert_nil TokenSet.from_set(set_hash({}, "logo" => nil)).logo_file
    assert_nil TokenSet.from_set(set_hash.except("logo")).logo_file
  end

  def test_round_trips_through_the_set_shape
    set = TokenSet.from_set(set_hash)
    copy = TokenSet.from_set(set.to_set, strict: true)

    assert_equal set.tokens, copy.tokens
    assert_equal set.logo_file, copy.logo_file
    assert_equal set.name, copy.name
  end

  def test_strict_mode_refuses_unknown_keys
    [set_hash({}, "version" => 1), set_hash("shadow" => "#fff"), set_hash({}, "logo" => { "url" => "https://x/y.svg" }),
     set_hash({}, "__proto__" => {})].each do |hash|
      error = assert_raises(TokenSet::InvalidSet) { TokenSet.from_set(hash, strict: true) }

      assert_equal "unknown_keys", error.message
    end
  end

  def test_strict_mode_refuses_any_invalid_value
    TokenSet::KINDS.each_key do |key|
      error = assert_raises(TokenSet::InvalidSet) { TokenSet.from_set(set_hash(key => "red; } body { display:none"), strict: true) }

      assert_equal "token_invalid", error.message
    end
    assert_equal "name_invalid", assert_raises(TokenSet::InvalidSet) { TokenSet.from_set(set_hash({}, "name" => ""), strict: true) }.message
  end

  def test_fallback_set
    set = TokenSet.fallback

    assert_equal "cunningham", set.id
    assert_equal Defaults::TOKENS, set.tokens
    assert_empty set.rejected
  end
end
