# frozen_string_literal: true

require "test_helper"
require "json"
require "yaml"
require "open_project/thematiq/figma"

class FigmaTest < Minitest::Test
  Figma = OpenProject::Thematiq::Figma
  Reader = OpenProject::Thematiq::Figma::Reader
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  CATALOGUE = OpenProject::Thematiq::Catalogue.bundled

  def set(tokens, dark = nil)
    TokenSet.from_set({ "id" => "t", "name" => "Test set", "tokens" => tokens, "dark" => dark }.compact)
  end

  def read(document, name: "file.json")
    Reader.read([[name, document.is_a?(String) ? document : JSON.generate(document)]])
  end

  def refused(document)
    assert_raises(Reader::Refused) { read(document) }.code
  end

  # --- the mapping ---

  def test_every_role_has_a_name_to_write_and_reads_it_back
    assert_equal TokenSet::ALL_KINDS.keys.sort, Figma::WRITE_NAMES.keys.sort
    assert_equal TokenSet::ALL_KINDS.keys.sort, Figma::READ_NAMES.keys.sort
    Figma::WRITE_NAMES.each { |role, name| assert_includes Figma::READ_NAMES.fetch(role), name, role }
    assert_equal Figma::WRITE_NAMES.values.uniq, Figma::WRITE_NAMES.values
  end

  def test_paths_follow_thematiqs_rule
    assert_equal %w[nldesign color primary], Figma.path_of("--nldesign-color-primary")
    assert_equal %w[nldesign color primary-hover], Figma.path_of("--nldesign-color-primary-hover")
    assert_equal %w[nldesign border radius-large], Figma.path_of("--nldesign-border-radius-large")
    assert_equal %w[nldesign font family], Figma.path_of("--nldesign-font-family")
  end

  def test_no_written_path_sits_inside_another
    paths = Figma::WRITE_NAMES.values.map { |name| Figma.path_of(name).join(".") }

    paths.each { |path| refute(paths.any? { |other| other.start_with?("#{path}.") }, path) }
  end

  # --- what a download holds ---

  def test_a_dtcg_download_has_typed_tokens_with_thematiqs_extension
    document = JSON.parse(Figma.export(set("primary" => "#3669a5", "radius" => "8px", "font-family" => "'Fira Sans', sans-serif")))
    primary = document.dig("nldesign", "color", "primary")

    assert_equal "Test set", document["$description"]
    assert_equal "color", primary["$type"]
    assert_equal "srgb", primary.dig("$value", "colorSpace")
    assert_equal "#3669a5", primary.dig("$value", "hex")
    assert_equal [0.2118, 0.4118, 0.6471], primary.dig("$value", "components")
    assert_equal "--nldesign-color-primary", primary.dig("$extensions", "nl.conduction.thematiq", "cssVariable")
    assert_equal({ "value" => 8, "unit" => "px" }, document.dig("nldesign", "border", "radius", "$value"))
    assert_equal "dimension", document.dig("nldesign", "border", "radius", "$type")
    assert_equal ["Fira Sans", "sans-serif"], document.dig("nldesign", "font", "family", "$value")
    assert_equal "t", document.dig("$extensions", "nl.conduction.thematiq", "setId")
  end

  def test_a_value_the_format_has_no_type_for_goes_to_css_only
    document = JSON.parse(Figma.export(set("primary" => "rebeccapurple", "radius" => "0.5em", "link" => "oklch(0.5 0.1 200)")))
    css_only = document.dig("$extensions", "nl.conduction.thematiq", "cssOnly")

    assert_equal "rebeccapurple", css_only["--nldesign-color-primary"]
    assert_equal "0.5em", css_only["--nldesign-border-radius"]
    assert_equal "oklch(0.5 0.1 200)", css_only["--nldesign-color-link"]
    assert_nil document.dig("nldesign", "color", "primary")
  end

  def test_a_see_through_colour_gets_an_alpha
    value = JSON.parse(Figma.export(set("line" => "rgba(0, 0, 0, 0.22)", "soft" => "#11223380"))).dig("nldesign", "color")

    assert_equal 0.22, value.dig("border", "$value", "alpha")
    assert_equal "#000000", value.dig("border", "$value", "hex")
    assert_equal 0.502, value.dig("background-dark", "$value", "alpha")
  end

  def test_a_tokens_studio_download_has_sets_themes_and_metadata
    document = JSON.parse(Figma.export(set({ "primary" => "#3669a5" }, { "tokens" => { "primary" => "#88aadd" } }), format: "tokens-studio"))

    assert_equal %w[thematiq/light thematiq/dark], document.dig("$metadata", "tokenSetOrder")
    assert_equal %w[light dark], document["$themes"].map { |theme| theme["id"] }
    assert_equal({ "thematiq/light" => "enabled", "thematiq/dark" => "enabled" }, document["$themes"].last["selectedTokenSets"])
    assert_equal "#3669a5", document.dig("thematiq/light", "nldesign", "color", "primary", "$value")
    assert_equal "color", document.dig("thematiq/light", "nldesign", "color", "primary", "$type")
    assert_equal "borderRadius", document.dig("thematiq/light", "nldesign", "border", "radius", "$type")
    assert_equal({ "primary" => { "$value" => "#88aadd", "$type" => "color", "$description" => "thematiq role primary",
                                  "$extensions" => { "nl.conduction.thematiq" => { "cssVariable" => "--nldesign-color-primary" } } } },
                 document.dig("thematiq/dark", "nldesign", "color"))
  end

  def test_the_legacy_spelling_has_no_dollar_keys_on_a_token
    token = JSON.parse(Figma.export(set("primary" => "#3669a5"), format: "tokens-studio-legacy")).dig("thematiq/light", "nldesign", "color", "primary")

    assert_equal "#3669a5", token["value"]
    assert_equal "color", token["type"]
    refute token.key?("$value")
  end

  def test_format_and_file_name
    assert_nil Figma.format("zip")
    assert_nil Figma.format(nil)
    assert_equal "dtcg", Figma.format("dtcg")
    assert_equal "thematiq-t.tokens.json", Figma.file_name(set({}), "dtcg")
    assert_equal "thematiq-t.tokens-studio.json", Figma.file_name(set({}), "tokens-studio")
  end

  # --- round trips ---

  def test_every_bundled_set_comes_back_the_same_in_every_format
    CATALOGUE.sets.each do |token_set|
      Figma::FORMATS.each do |format|
        result = read(Figma.export(token_set, format:))

        assert_equal token_set.tokens, result.tokens, "#{token_set.id} #{format}"
        assert_equal token_set.dark_tokens, result.dark, "#{token_set.id} #{format} dark"
        assert_equal 0, result.skipped_count, "#{token_set.id} #{format}: #{result.skipped.first(3)}"
        assert_equal token_set.name[0, 80], result.name, "#{token_set.id} #{format}"
      end
    end
  end

  def test_awkward_values_come_back_the_same
    awkward = set({ "primary" => "#abc", "line" => "rgba(0, 0, 0, 0.22)", "link" => "hsl(210 50% 40%)", "accent" => "rebeccapurple",
                    "soft" => "#11223380", "radius" => "0", "radius-lg" => "0.5em", "font-family" => "'Roboto', system-ui",
                    "menu" => "#102030", "ink" => "rgb(10, 20, 30)" }, { "tokens" => { "ink" => "#fafafa", "ground" => "#101010" } })

    Figma::FORMATS.each do |format|
      result = read(Figma.export(awkward, format:))

      assert_equal awkward.tokens, result.tokens, format
      assert_equal awkward.dark_tokens, result.dark, format
    end
  end

  def test_a_colour_changed_in_figma_wins_over_the_text_the_plugin_kept
    document = JSON.parse(Figma.export(set("primary" => "rgb(10, 20, 30)")))
    document["nldesign"]["color"]["primary"]["$value"] = { "colorSpace" => "srgb", "components" => [1, 0, 0] }

    assert_equal "#ff0000", read(document).tokens["primary"]
  end

  def test_a_file_without_extensions_is_read_by_its_paths
    document = JSON.parse(Figma.export(CATALOGUE.default))
    strip = ->(node) { node.is_a?(Hash) ? node.except("$extensions").transform_values(&strip) : node }
    result = read(strip.call(document))

    hex_only = CATALOGUE.default.tokens.select { |role, _value| result.tokens.key?(role) }
    assert_equal hex_only, result.tokens
    assert_operator result.tokens.size, :>=, 15
  end

  # --- fixtures in both spellings ---

  FIXTURES = File.expand_path("fixtures", __dir__)

  def fixture(name)
    File.read(File.join(FIXTURES, name))
  end

  def test_a_w3c_file_with_groups_types_and_aliases
    result = read(fixture("w3c.tokens.json"))

    assert_equal "dtcg", result.shape
    assert_equal "Fixture brand", result.name
    assert_equal "#0055aa", result.tokens["primary"]
    assert_equal "#0055aa", result.tokens["link"], "an alias takes the value and the type of its target"
    assert_equal "#00000080", result.tokens["line"]
    assert_equal "6px", result.tokens["radius"]
    assert_equal "'Fira Sans', sans-serif", result.tokens["font-family"]
    assert_equal "#112233", result.tokens["ink"], "a display-p3 colour is read from its hex member"
    reasons = result.skipped.to_h { |entry| [entry["path"], entry["reason"]] }
    assert_equal "not_mapped", reasons["shadow.card"]
    assert_equal "reference_cycle", reasons["nldesign.color.accent"]
    assert_equal "reference_missing", reasons["nldesign.color.background"]
    assert_equal "wrong_type", reasons["nldesign.color.text-muted"]
    assert_equal "value_refused", reasons["nldesign.color.border-dark"]
    assert_equal "missing_type", reasons["loose.nldesign.color.action"]
  end

  def test_a_tokens_studio_file_in_the_dollar_spelling
    result = read(fixture("tokens-studio.json"))

    assert_equal "tokens-studio", result.shape
    assert_equal "Fixture brand", result.name
    assert_equal "#0055aa", result.tokens["primary"], "a reference into a source set resolves"
    assert_equal "#003377", result.tokens["primary-deep"], "the later set in tokenSetOrder wins"
    assert_equal "4px", result.tokens["radius"]
    assert_equal({ "primary" => "#88bbff", "action" => "#88bbff" }, result.dark, "action reads the primary colour when the file names no action colour")
    refute result.tokens.key?("accent"), "a token of a source set is not part of the theme"
    refute result.tokens.key?("ink"), "a disabled set gives nothing"
  end

  def test_a_tokens_studio_file_in_the_legacy_spelling
    result = read(fixture("tokens-studio-legacy.json"))

    assert_equal "tokens-studio", result.shape
    assert_equal "#0055aa", result.tokens["primary"]
    assert_equal "#0055aa", result.tokens["link"]
    assert_equal "'Fira Sans', sans-serif", result.tokens["font-family"]
    assert_equal({ "ground" => "#101010" }, result.dark, "a set named dark is the dark block when there are no themes")
    assert_equal "expression_not_supported", result.skipped.find { |entry| entry["path"] == "nldesign.border.radius" }["reason"]
  end

  def test_a_tokens_studio_folder_is_several_files
    single = JSON.parse(fixture("tokens-studio.json"))
    files = single.map { |key, value| ["#{key.split('/').last}.json", JSON.generate(value)] }
    result = Reader.read(files)

    assert_equal read(single).tokens, result.tokens
    assert_equal read(single).dark, result.dark
  end

  def test_a_single_tokens_studio_set_without_themes_resolves_its_references
    document = { "global" => { "brand" => { "blue" => { "value" => "#0055aa", "type" => "color" } },
                               "color" => { "primary" => { "value" => "{brand.blue}", "type" => "color" } } } }

    assert_equal "#0055aa", read(document).tokens["primary"]
  end

  # --- hostile input ---

  def test_refusals
    assert_equal "empty", assert_raises(Reader::Refused) { Reader.read([]) }.code
    assert_equal "empty", refused("  ")
    assert_equal "invalid_json", refused("{ not json")
    assert_equal "invalid_json", refused("\xff\xfe".b)
    assert_equal "not_an_object", refused("[1, 2]")
    assert_equal "nothing_usable", refused({ "a" => { "$value" => "#fff", "$type" => "color" } })
    assert_equal "too_large", refused("{\"a\": \"#{'x' * Reader::MAX_BYTES}\"}")
    assert_equal "too_many_files", assert_raises(Reader::Refused) { Reader.read(Array.new(Reader::MAX_FILES + 1) { |i| ["#{i}.json", "{}"] }) }.code
  end

  def test_a_deep_file_is_refused
    deep = (1..40).reduce({ "$value" => "#fff", "$type" => "color" }) { |node, _| { "g" => node } }
    fairly_deep = (1..(Reader::MAX_DEPTH + 2)).reduce({ "$value" => "#fff", "$type" => "color" }) { |node, _| { "g" => node } }

    assert_equal "too_deep", refused(deep)
    assert_equal "too_deep", refused(fairly_deep)
  end

  def test_a_file_with_too_many_tokens_is_refused
    many = (0..Reader::MAX_TOKENS).to_h { |index| ["t#{index}", { "$value" => "#fff", "$type" => "color" }] }

    assert_equal "too_many_tokens", refused({ "g" => many })
  end

  def test_reference_cycles_are_found
    token = ->(value) { { "$value" => value, "$type" => "color" } }
    document = { "nldesign" => { "color" => { "primary" => token.call("{nldesign.color.primary}"), "link" => token.call("{a.b}"),
                                               "text" => token.call("#111111") } },
                 "a" => { "b" => token.call("{a.c}"), "c" => token.call("{a.b}") } }
    result = read(document)

    assert_equal({ "ink" => "#111111" }, result.tokens)
    assert_equal %w[reference_cycle], result.skipped.select { |entry| entry["path"].start_with?("nldesign") }.map { |entry| entry["reason"] }.uniq
  end

  def test_a_long_chain_of_references_ends
    chain = (0..30).to_h { |index| ["c#{index}", { "$value" => "{chain.c#{index + 1}}", "$type" => "color" }] }
    document = { "chain" => chain, "nldesign" => { "color" => { "primary" => { "$value" => "{chain.c0}", "$type" => "color" },
                                                               "text" => { "$value" => "#111111", "$type" => "color" } } } }

    assert_equal "reference_too_long", read(document).skipped.find { |entry| entry["path"] == "nldesign.color.primary" }["reason"]
  end

  def test_hostile_values_never_come_out
    HOSTILE_VALUES.each do |hostile|
      document = { "nldesign" => { "color" => { "primary" => { "$value" => hostile, "$type" => "color" },
                                                 "text" => { "$value" => "#111111", "$type" => "color" } },
                                   "font" => { "family" => { "$value" => hostile, "$type" => "fontFamily" } },
                                   "border" => { "radius" => { "$value" => hostile, "$type" => "dimension" } } },
                   "$extensions" => { "nl.conduction.thematiq" => { "cssOnly" => { "--nldesign-color-link" => hostile } },
                                      "nl.conduction.openproject-thematiq" => { "dark" => { "ink" => hostile } } } }
      result = read(document)

      assert_equal({ "ink" => "#111111" }, result.tokens, hostile.inspect)
      assert_empty result.dark, hostile.inspect
    end
  end

  def test_the_text_the_plugin_kept_is_checked_like_any_value
    document = JSON.parse(Figma.export(set("primary" => "rgb(10, 20, 30)")))
    document["nldesign"]["color"]["primary"]["$extensions"]["nl.conduction.openproject-thematiq"]["css"] = "red; } body { display: none"

    assert_equal "#0a141e", read(document).tokens["primary"]
  end

  def test_a_token_of_an_unknown_type_never_becomes_a_role
    document = { "nldesign" => { "color" => { "primary" => { "$value" => "#ff0000", "$type" => "shadow" },
                                               "link" => { "$value" => { "evil" => true }, "$type" => "color" },
                                               "text" => { "$value" => "#111111", "$type" => "color" } } } }
    result = read(document)

    assert_equal({ "ink" => "#111111" }, result.tokens)
    assert_equal %w[colour_space_not_supported wrong_type], result.skipped.map { |entry| entry["reason"] }.sort
  end

  def test_the_report_is_capped_and_its_paths_are_plain_text
    junk = (0...400).to_h { |index| ["j#{index}", { "$value" => "#fff", "$type" => "color" }] }
    result = read({ "junk\u0007" => junk, "nldesign" => { "color" => { "text" => { "$value" => "#111111", "$type" => "color" } } } })

    assert_equal 400, result.skipped_count
    assert_equal Reader::MAX_REPORTED, result.skipped.size
    result.skipped.each { |entry| refute_match(/[[:cntrl:]]/, entry["path"]) }
  end

  def test_the_plugin_opens_no_file_and_no_connection_for_a_reference
    document = { "nldesign" => { "color" => { "primary" => { "$ref" => "https://evil.example/x.json#/a", "$value" => "#fff", "$type" => "color" },
                                               "text" => { "$value" => "#111111", "$type" => "color" } } } }

    assert_equal "ref_not_supported", read(document).skipped.first["reason"]
  end
end

# The reasons and the error codes are built at run time, so the scan of the locale test does not see them.
class FigmaLocaleTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  EN = YAML.load_file(File.join(ROOT, "config/locales/en.yml")).fetch("en").fetch("thematiq").fetch("figma")
  Reader = OpenProject::Thematiq::Figma::Reader

  def test_every_format_has_a_label_and_a_hint
    OpenProject::Thematiq::Figma::FORMATS.each do |format|
      assert_kind_of String, EN.dig("formats", format, "label"), format
      assert_kind_of String, EN.dig("formats", format, "hint"), format
    end
  end

  def test_every_reason_the_reader_gives_is_listed_and_has_a_sentence
    source = File.read(File.join(ROOT, "lib/open_project/thematiq/figma/reader.rb"))
    given = source.scan(/skip\([^,\n]+, "([a-z_]+)"\)/).flatten + source.scan(/return "([a-z_]+)"/).flatten +
            source.scan(/^\s*"(reference_too_long)"$/).flatten + source.scan(/:([a-z_]+_(?:type|refused|supported))\b/).flatten

    assert_operator given.uniq.size, :>=, 12
    assert_empty given.uniq - Reader::REASONS
    (Reader::REASONS + ["other"]).each { |reason| assert_kind_of String, EN.dig("reasons", reason), reason }
  end

  def test_every_refusal_has_a_message_and_the_controller_passes_it_on
    reader = File.read(File.join(ROOT, "lib/open_project/thematiq/figma/reader.rb"))
    controller = File.read(File.join(ROOT, "app/controllers/thematiq/admin_controller.rb"))
    codes = reader.scan(/Refused, "([a-z_]+)"/).flatten.uniq + controller.scan(/figma_refused\("([a-z_]+)"\)/).flatten
    passed_on = controller[/FIGMA_ERRORS = %w\[(.*?)\]/m, 1].split

    assert_empty codes - passed_on
    passed_on.each { |code| assert_kind_of String, EN.dig("errors", code), code }
  end

  def test_the_numbers_in_the_text_are_the_caps
    assert_includes EN.dig("errors", "too_large"), "#{Reader::MAX_BYTES / 1024} KB"
    assert_includes EN.dig("errors", "too_many_files"), Reader::MAX_FILES.to_s
    assert_includes EN.dig("errors", "too_deep"), Reader::MAX_DEPTH.to_s
    assert_includes EN.dig("errors", "too_many_tokens"), Reader::MAX_TOKENS.to_s
    assert_includes EN.dig("reasons", "reference_too_long"), Reader::MAX_HOPS.to_s
  end
end

class CustomDraftDarkTest < Minitest::Test
  CustomDraft = OpenProject::Thematiq::CustomDraft

  def test_a_draft_carries_dark_colours_through_the_store
    store = OpenProject::Thematiq::Store.new(backend: MemoryBackend.new)
    base = store.catalogue.default
    draft = CustomDraft.new(base:, name: "From Figma", overrides: { "primary" => "#123456" },
                            dark: { "ink" => "#fafafa", "radius" => "4px", "link" => "red; } body { display: none" })

    assert_equal({ "ink" => "#fafafa" }.reject { |key, value| base.dark_tokens[key] == value }, draft.dark)
    assert store.save_custom(draft)
    assert_equal "#fafafa", store.custom_set(draft.id).dark_tokens["ink"]
    assert_equal draft.dark, store.custom_draft(draft.id).dark
  end

  def test_a_draft_without_dark_colours_stores_none
    base = OpenProject::Thematiq::Catalogue.bundled.default

    refute CustomDraft.new(base:, name: "Plain", overrides: {}).definition.key?("dark")
  end
end
