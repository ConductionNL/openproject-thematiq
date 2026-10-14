# frozen_string_literal: true

require "test_helper"
require "json"
require "open_project/thematiq/figma"

# The vocabulary in Figma files: written under thematiq's own names, read back from thematiq's files and the plugin's.
class VocabularyFigmaTest < Minitest::Test
  Figma = OpenProject::Thematiq::Figma
  Reader = OpenProject::Thematiq::Figma::Reader
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Vocabulary = OpenProject::Thematiq::Tokens::Vocabulary

  # The values thematiq's token files write, one or more per kind, including the awkward ones.
  SAMPLES = {
    color: ["#d52b1e", "rgba(54, 105, 165, 0.5)", "#ebebeb38", "transparent"], length: ["1.75rem", "0", "17px", "50%"],
    size: ["1328px"], font_family: ["'Red Hat Display', 'Red Hat Text', system-ui, sans-serif"], font_weight: ["600", "bold"],
    number: ["1.15", "6", "0.06"], duration: ["100ms", "0.3s"], offset: ["auto", "12px"], rgb_triplet: ["204, 0, 0"],
    filter: ["brightness(0) invert(1)", "none"], border: ["1px solid rgba(138, 146, 158, 0.25)", "0"], text_transform: ["uppercase"]
  }.freeze

  def full_set(tokens = {})
    vocabulary = Vocabulary::KINDS.each_with_index.to_h { |(key, kind), index| [key, SAMPLES.fetch(kind)[index % SAMPLES.fetch(kind).size]] }
    TokenSet.from_set({ "id" => "full", "name" => "Full", "tokens" => tokens, "vocabulary" => vocabulary,
                        "dark" => { "tokens" => { "primary" => "#5b8ac2" } } })
  end

  def read(document)
    Reader.read([["file.json", document.is_a?(String) ? document : JSON.generate(document)]])
  end

  def test_the_whole_vocabulary_comes_back_the_same_in_every_format
    original = full_set("primary" => "#3669a5", "ground" => "#ffffff")

    assert_equal Vocabulary.keys.size, original.vocabulary.size
    Figma::FORMATS.each do |format|
      result = read(Figma.export(original, format:))

      assert_equal original.vocabulary, result.vocabulary, format
      assert_equal original.tokens, result.tokens, format
      assert_equal original.dark_tokens, result.dark, format
      assert_equal 0, result.skipped_count, "#{format}: #{result.skipped.first(3)}"
    end
  end

  def test_the_w3c_file_writes_thematiqs_names_and_types
    set = TokenSet.from_set({ "id" => "s", "name" => "S", "tokens" => {},
                              "vocabulary" => { "color-error" => "#d52b1e", "animation-quick" => "100ms", "website-button-font-weight" => "600",
                                                "website-page-title-line-height" => "1.15", "header-icon-filter" => "brightness(0) invert(1)",
                                                "color-error-rgb" => "204, 0, 0" } })
    document = JSON.parse(Figma.export(set))

    assert_equal "--nldesign-color-error", document.dig("nldesign", "color", "error", "$extensions", "nl.conduction.thematiq", "cssVariable")
    assert_equal({ "value" => 100, "unit" => "ms" }, document.dig("nldesign", "animation", "quick", "$value"))
    assert_equal "duration", document.dig("nldesign", "animation", "quick", "$type")
    assert_equal({ "$type" => "fontWeight", "$value" => 600 }, document.dig("nldesign", "website", "button-font-weight").slice("$type", "$value"))
    assert_equal({ "$type" => "number", "$value" => 1.15 }, document.dig("nldesign", "website", "page-title-line-height").slice("$type", "$value"))
    css_only = document.dig("$extensions", "nl.conduction.thematiq", "cssOnly")
    assert_equal({ "--nldesign-header-icon-filter" => "brightness(0) invert(1)", "--nldesign-color-error-rgb" => "204, 0, 0" }, css_only)
  end

  # The ground role is written at --nldesign-color-background, and thematiq reads the ground from the content surface
  # first. In a file the plugin wrote, the plugin's own name wins, so neither value takes the other's place.
  def test_a_content_surface_in_the_vocabulary_does_not_replace_the_ground_on_the_way_back
    original = TokenSet.from_set({ "id" => "s", "name" => "S", "tokens" => { "ground" => "#ffffff" },
                                   "vocabulary" => { "component-content-surface-background-color" => "#f5f6f8" } })

    Figma::FORMATS.each do |format|
      result = read(Figma.export(original, format:))

      assert_equal "#ffffff", result.tokens["ground"], format
      assert_equal "#f5f6f8", result.vocabulary["component-content-surface-background-color"], format
    end
  end

  def test_a_file_from_thematiq_gives_its_vocabulary
    document = {
      "nldesign" => {
        "color" => { "primary" => { "$type" => "color", "$value" => "#3669a5" }, "error" => { "$type" => "color", "$value" => "#cc0000" },
                     "error-rgb" => { "$type" => "color", "$value" => "#cc0000" } },
        "component" => { "table-header-font-weight" => { "$type" => "fontWeight", "$value" => 400 },
                         "heading-1-font-size" => { "$type" => "dimension", "$value" => { "value" => 1.75, "unit" => "rem" } },
                         "content-surface-background-color" => { "$type" => "color", "$value" => "#f5f6f8" } },
        "animation" => { "slow" => { "$type" => "duration", "$value" => { "value" => 300, "unit" => "ms" } } }
      },
      "zuiddrecht" => { "color" => { "red" => { "$type" => "color", "$value" => "#cc0000" } } },
      "$extensions" => { "nl.conduction.thematiq" => { "cssOnly" => { "--nldesign-header-icon-filter" => "brightness(0) invert(1)",
                                                                      "--nldesign-color-focus-rgb" => "54, 105, 165" } } }
    }
    result = read(document)

    assert_equal({ "color-error" => "#cc0000", "component-table-header-font-weight" => "400", "component-heading-1-font-size" => "1.75rem",
                   "component-content-surface-background-color" => "#f5f6f8", "animation-slow" => "300ms",
                   "header-icon-filter" => "brightness(0) invert(1)", "color-focus-rgb" => "54, 105, 165" }, result.vocabulary)
    assert_equal "#cc0000", result.tokens["accent"], "the error colour still feeds the accent, as in thematiq"
    assert_equal "#f5f6f8", result.tokens["ground"], "thematiq reads the ground from the content surface first"
    skipped = result.skipped.to_h { |entry| [entry["path"], entry["reason"]] }
    assert_equal "wrong_type", skipped["nldesign.color.error-rgb"], "a colour is not three channels"
    assert_equal "not_mapped", skipped["zuiddrecht.color.red"]
    assert(result.imported.any? { |entry| entry["vocabulary"] && entry["role"] == "color-error" })
  end

  def test_a_file_without_extensions_is_read_by_its_paths
    strip = ->(node) { node.is_a?(Hash) ? node.except("$extensions").transform_values(&strip) : node }
    original = full_set
    result = read(strip.call(JSON.parse(Figma.export(original))))

    # A see-through colour comes back as eight digit hex: the text the plugin kept was in the extension.
    assert_operator result.vocabulary.size, :>, 100, "everything with a W3C type comes back without the extension"
    assert_empty result.vocabulary.keys - original.vocabulary.keys
    assert_equal original.vocabulary["animation-quick"], result.vocabulary["animation-quick"]
    assert_equal "#3669a580", result.vocabulary[original.vocabulary.key("rgba(54, 105, 165, 0.5)")]
  end

  def test_hostile_vocabulary_values_never_come_out
    css_only = { "--nldesign-header-icon-filter" => "url(https://evil.example/x)", "--nldesign-header-border-bottom" => "1px solid red; color: red",
                 "--nldesign-color-error" => "#fff}</style>", "--nldesign-website-date-month-text-transform" => "expression(alert(1))" }
    document = { "nldesign" => { "color" => { "primary" => { "$type" => "color", "$value" => "#3669a5" } },
                                 "animation" => { "quick" => { "$type" => "duration", "$value" => { "value" => 1, "unit" => "min" } } } },
                 "$extensions" => { "nl.conduction.thematiq" => { "cssOnly" => css_only } } }
    HOSTILE_VALUES.grep(String).reject(&:empty?).each_with_index do |value, index|
      document["nldesign"]["component"] ||= {}
      document["nldesign"]["component"]["heading-#{(index % 6) + 1}-font-size"] = { "$type" => "dimension", "$value" => value }
    end
    result = read(document)

    assert_empty result.vocabulary
    assert(result.skipped.any? { |entry| entry["reason"] == "value_refused" })
  end

  def test_the_dark_set_gives_no_vocabulary
    original = full_set
    document = JSON.parse(Figma.export(original, format: "tokens-studio"))
    document["thematiq/dark"]["nldesign"]["color"]["error"] = { "$value" => "#ff5c5c", "$type" => "color" }
    result = read(document)

    assert_equal original.vocabulary["color-error"], result.vocabulary["color-error"]
    refute_includes result.vocabulary.values, "#ff5c5c"
  end
end
