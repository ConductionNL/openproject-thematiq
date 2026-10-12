# frozen_string_literal: true

require "test_helper"

class TokenSetTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Defaults = OpenProject::Thematiq::Tokens::Defaults

  def payload(tokens = {}, extra = {})
    { "version" => 1, "id" => "zuiddrecht", "name" => "Zuiddrecht", "revision" => "r42",
      "tokens" => { "primary" => "#3669a5", "radius" => "8px", "font-family" => "'Fira Sans', sans-serif" }.merge(tokens),
      "logo" => { "url" => "https://cloud.example.org/logo.svg", "inverse_url" => nil } }.merge(extra)
  end

  def test_reads_a_valid_payload
    set = TokenSet.from_payload(payload("accent" => "#cc0000"))

    assert_equal "zuiddrecht", set.id
    assert_equal "Zuiddrecht", set.name
    assert_equal "r42", set.revision
    assert_equal "#3669a5", set["primary"]
    assert_equal "8px", set["radius"]
    assert_equal "#cc0000", set["accent"]
    assert_equal "https://cloud.example.org/logo.svg", set.logo_url
    assert_nil set.logo_inverse_url
    assert_empty set.rejected
    refute set.bundled?
  end

  def test_missing_tokens_fall_back_to_the_bundled_value_without_being_rejected
    set = TokenSet.from_payload(payload)

    assert_equal Defaults::TOKENS["action"], set["action"]
    assert_empty set.rejected
  end

  def test_hostile_tokens_fall_back_and_are_listed
    set = TokenSet.from_payload(payload("primary" => "red; } body { display:none", "radius" => "3px; } * {",
                                        "font-family" => "Arial</style>", "chip" => "url(x)"))

    assert_equal Defaults::TOKENS["primary"], set["primary"]
    assert_equal Defaults::TOKENS["radius"], set["radius"]
    assert_equal Defaults::TOKENS["font-family"], set["font-family"]
    assert_nil set["chip"], "chip has no bundled value, so it is left out"
    assert_equal %w[primary chip radius font-family], set.rejected
  end

  def test_every_hostile_value_in_every_token_is_refused
    TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        set = TokenSet.from_payload(payload(key => value))
        expected = Defaults::TOKENS[key]
        expected.nil? ? assert_nil(set[key]) : assert_equal(expected, set[key], "#{key} took #{value.inspect}")
      end
    end
  end

  def test_unknown_token_keys_are_ignored
    set = TokenSet.from_payload(payload("evil } body {" => "#fff", "shadow" => "0 0 1px red"))

    assert_equal TokenSet::KINDS.keys & set.tokens.keys, set.tokens.keys
  end

  def test_refuses_documents_outside_the_contract
    [nil, [], "x", payload({}, "version" => 2), payload({}, "tokens" => "x"), payload({}, "id" => nil),
     payload({}, "revision" => ""), payload({}, "revision" => 7)].each do |document|
      assert_raises(TokenSet::InvalidPayload) { TokenSet.from_payload(document) }
    end
  end

  def test_hostile_logo_urls_become_nil
    set = TokenSet.from_payload(payload({}, "logo" => { "url" => "javascript:alert(1)", "inverse_url" => %(https://x/"><script>) }))

    assert_nil set.logo_url
    assert_nil set.logo_inverse_url
  end

  def test_round_trips_through_the_stored_shape
    set = TokenSet.from_payload(payload)
    copy = TokenSet.from_payload(set.to_payload)

    assert_equal set.tokens, copy.tokens
    assert_equal set.revision, copy.revision
  end

  def test_the_stored_shape_remembers_which_tokens_were_refused
    set = TokenSet.from_payload(payload("action" => "red; } body { display:none"))
    copy = TokenSet.from_payload(set.to_payload)

    assert_equal %w[action], copy.rejected
    assert_equal Defaults::TOKENS["action"], copy["action"]
  end

  def test_a_hostile_rejected_list_is_reduced_to_known_keys
    set = TokenSet.from_payload(payload({}, "rejected" => ["action", "<script>", 7, "action"]))

    assert_equal %w[action], set.rejected
  end

  def test_bundled_set
    set = TokenSet.bundled

    assert set.bundled?
    assert_equal Defaults::TOKENS, set.tokens
    assert_empty set.rejected
  end
end
