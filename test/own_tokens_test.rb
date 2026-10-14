# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/bundle"

class OwnTokensTest < Minitest::Test
  Store = OpenProject::Thematiq::Store

  def store
    @store ||= Store.new(backend: MemoryBackend.new, env: {})
  end

  def test_an_own_token_is_written_light_and_dark
    assert_nil store.save_own_token(name: "brand-ribbon", label: "Ribbon", kind: "color", value: "#C8102E", dark: "#ff8099")
    assert_nil store.save_own_token(name: "card-gap", label: "", kind: "length", value: "12px")

    assert_equal ["brand-ribbon", "card-gap"], store.own_tokens.map { |token| token["name"] }
    css = store.own_tokens_css
    assert_includes css, ":root {\n  --thematiq-org-brand-ribbon: #c8102e;\n  --thematiq-org-card-gap: 12px;\n}"
    assert_includes css, %(#{OpenProject::Thematiq::Variables::Generator::DARK_SCOPE} {\n  --thematiq-org-brand-ribbon: #ff8099;\n})
  end

  def test_the_rules
    assert_equal "name", store.save_own_token(name: "Bad Name", label: "", kind: "color", value: "red")
    assert_equal "name", store.save_own_token(name: "x" * 42, label: "", kind: "color", value: "red")
    assert_equal "kind", store.save_own_token(name: "x", label: "", kind: "url", value: "red")
    assert_equal "dark", store.save_own_token(name: "x", label: "", kind: "color", value: "red", dark: "url(x)")
    HOSTILE_VALUES.each do |value|
      next if value.is_a?(String) && OpenProject::Thematiq::Tokens::Validator.color(value)

      assert_equal "value", store.save_own_token(name: "x", label: "", kind: "color", value:), value.inspect
    end
    assert_nil store.own_tokens_css
  end

  def test_the_bundle_checks_them
    store.save_own_token(name: "brand-ribbon", label: "Ribbon", kind: "color", value: "#c8102e")
    bundle = OpenProject::Thematiq::Bundle.build(settings: store.settings_snapshot, scopes: [])
    catalogue = OpenProject::Thematiq::Catalogue.bundled
    assert OpenProject::Thematiq::Bundle.read(bundle, catalogue:)
    bundle["settings"]["own_tokens"]["brand-ribbon"]["value"] = "red; } body { display: none"
    assert_raises(OpenProject::Thematiq::Bundle::Refused) { OpenProject::Thematiq::Bundle.read(bundle, catalogue:) }
  end
end
