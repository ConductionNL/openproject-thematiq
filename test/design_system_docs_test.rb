# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/transfer"
require "open_project/thematiq/bundle"
require "open_project/thematiq/design_systems"

# cat-design-system-docs: a link from the settings page to a design system's own documentation.
class DesignSystemDocsTest < Minitest::Test
  Validator = OpenProject::Thematiq::Tokens::Validator
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  CustomDraft = OpenProject::Thematiq::CustomDraft
  Transfer = OpenProject::Thematiq::Transfer
  Bundle = OpenProject::Thematiq::Bundle
  DesignSystems = OpenProject::Thematiq::DesignSystems
  ROOT = File.expand_path("..", __dir__)

  def set_hash(extra = {})
    { "id" => "house-style", "name" => "House style", "tokens" => { "primary" => "#aa0055" } }.merge(extra)
  end

  def test_only_an_http_or_https_address_with_a_host_is_a_web_address
    %w[https://nldesignsystem.nl http://docs.example.org/a?b=c https://example.org:8443/path#part].each do |url|
      assert_equal url, Validator.web_address(url), url
    end
    assert_equal "https://example.org", Validator.web_address("  https://example.org  ")
    ["javascript:alert(1)", "data:text/html,<b>x</b>", "ftp://example.org", "//example.org", "https://", "https:///path",
     "https://user:secret@example.org", "https://example.org/a b", "https://example.org/\"onmouseover", "https://example.org/<x>",
     "https://example.org/\nx", "mailto:a@example.org", "example.org", "", " ", nil, 42, ["https://example.org"],
     "https://example.org/#{'a' * 500}"].each do |value|
      assert_nil Validator.web_address(value), value.inspect
    end
  end

  def test_the_design_systems_of_thematiq_name_their_documentation
    assert_equal "https://nldesignsystem.nl", DesignSystems.documentation_url("nldesign")
    assert_equal "https://github.com/suitenumerique/cunningham", DesignSystems.documentation_url("lasuite")
    assert_nil DesignSystems.documentation_url("high-contrast")
    assert_nil DesignSystems.documentation_url("unknown")
    DesignSystems.documentation.each do |id, url|
      assert DesignSystems.known?(id), id
      assert_equal url, Validator.web_address(url)
    end
  end

  def test_a_set_links_to_the_documentation_of_its_design_system
    set_id, system = OpenProject::Thematiq::IconPacks.token_sets.find { |_id, ds| ds == "nldesign" }
    token_set = TokenSet.new(id: set_id, name: "A set", tokens: {})

    assert_equal DesignSystems.documentation_url(system), DesignSystems.documentation_for(token_set)
    assert_nil DesignSystems.documentation_for(TokenSet.new(id: "not-in-thematiq", name: "x", tokens: {}))
  end

  def test_an_own_address_comes_before_that_of_the_design_system
    set_id, = OpenProject::Thematiq::IconPacks.token_sets.find { |_id, ds| ds == "nldesign" }
    token_set = TokenSet.new(id: "custom", name: "Mine", tokens: {}, documentation_url: "https://house.example.org/style")

    assert_equal "https://house.example.org/style", DesignSystems.documentation_for(token_set, base_id: set_id)
    assert_equal "https://nldesignsystem.nl", DesignSystems.documentation_for(TokenSet.new(id: "custom", name: "Mine", tokens: {}), base_id: set_id)
  end

  def test_a_token_set_drops_an_address_that_is_not_a_web_address
    assert_nil TokenSet.new(id: "x", name: "x", tokens: {}, documentation_url: "javascript:alert(1)").documentation_url
    assert_nil TokenSet.from_set(set_hash("documentation_url" => "javascript:alert(1)")).documentation_url
  end

  def test_the_address_travels_in_the_export_file_and_back
    token_set = TokenSet.from_set(set_hash("documentation_url" => "https://house.example.org"))
    file = Transfer.export(token_set)

    assert_equal "https://house.example.org", JSON.parse(file)["documentation_url"]
    assert_equal "https://house.example.org", Transfer.import(file).documentation_url
  end

  def test_a_set_without_an_address_exports_without_the_key
    refute_includes Transfer.export(TokenSet.from_set(set_hash)), "documentation_url"
  end

  def test_an_import_with_an_address_that_is_not_a_web_address_is_refused
    ["javascript:alert(1)", "ftp://example.org", 42, ""].each do |value|
      code = assert_raises(Transfer::Refused) { Transfer.import(JSON.generate(set_hash("documentation_url" => value))) }.code

      assert_equal "documentation_url_invalid", code, value.inspect
    end
  end

  def test_a_draft_keeps_a_valid_address_and_refuses_another
    base = TokenSet.fallback
    draft = CustomDraft.new(base:, name: "Mine", overrides: {}, documentation_url: " https://house.example.org ")

    assert draft.valid?
    assert_equal "https://house.example.org", draft.documentation_url
    assert_equal "https://house.example.org", draft.definition["documentation_url"]
    assert_equal "https://house.example.org", draft.token_set.documentation_url

    refused = CustomDraft.new(base:, name: "Mine", overrides: {}, documentation_url: "javascript:alert(1)")

    refute refused.valid?
    assert refused.error?("documentation_url")
    assert_equal "javascript:alert(1)", refused.documentation_field_value
    refute refused.definition.key?("documentation_url")
  end

  def test_an_empty_address_is_none
    draft = CustomDraft.new(base: TokenSet.fallback, name: "Mine", overrides: {}, documentation_url: "")

    assert draft.valid?
    assert_nil draft.documentation_url
    assert_equal "", draft.documentation_field_value
    refute draft.definition.key?("documentation_url")
  end

  def test_the_store_keeps_the_address_of_a_custom_design_system
    store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new)
    draft = CustomDraft.new(base: store.catalogue.default, name: "Mine", overrides: {}, documentation_url: "https://house.example.org")

    assert store.save_custom(draft)
    assert_equal "https://house.example.org", store.custom_draft.documentation_url
    assert_equal "https://house.example.org", store.custom_set.documentation_url
  end

  def test_a_configuration_file_carries_the_address_and_refuses_a_bad_one
    catalogue = OpenProject::Thematiq::Catalogue.bundled
    custom = { "name" => "Town hall", "based_on" => "cunningham", "overrides" => {}, "documentation_url" => "https://town.example.org" }
    bundle = Bundle.build(settings: { "customs" => { "custom" => custom } }, scopes: [])

    assert_equal "https://town.example.org", Bundle.read(Bundle.dump(bundle), catalogue:).settings["customs"]["custom"]["documentation_url"]

    bad = Bundle.build(settings: { "customs" => { "custom" => custom.merge("documentation_url" => "javascript:alert(1)") } }, scopes: [])
    assert_equal "custom_invalid", assert_raises(Bundle::Refused) { Bundle.read(Bundle.dump(bad), catalogue:) }.code
  end

  def test_every_documentation_link_opens_in_a_new_tab_without_the_opener
    show = File.read(File.join(ROOT, "app/views/thematiq/admin/show.html.erb"))
    links = show.lines.select { |line| line.include?('link_to t("thematiq.design_systems.docs') }

    assert_equal 3, links.size
    links.each { |line| assert_includes line, %(target: "_blank", rel: "noopener noreferrer") }
  end

  def test_the_editor_has_a_field_for_the_address
    edit = File.read(File.join(ROOT, "app/views/thematiq/admin/edit.html.erb"))

    assert_includes edit, %(name="documentation_url")
    assert_includes edit, "@draft.documentation_field_value"
  end
end
