# frozen_string_literal: true

require "test_helper"

# The vocabulary on the page: which variables a filled key writes, and that an unfilled key writes nothing.
class VocabularyLayerTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Generator = OpenProject::Thematiq::Variables::Generator
  Vocabulary = OpenProject::Thematiq::Tokens::Vocabulary
  LIGHT = Generator::LIGHT_SCOPE

  def set(vocabulary, tokens = {})
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => tokens, "vocabulary" => vocabulary,
                        "dark" => { "tokens" => { "primary" => "#5b8ac2" } } })
  end

  def blocks(css)
    css.scan(/^([^\n{}\/]+) \{\n(.*?)\n\}/m).to_h { |selector, body| [selector, body] }
  end

  def light(vocabulary, tokens = {})
    blocks(Generator.new(set(vocabulary, tokens)).css).fetch(LIGHT)
  end

  def test_the_drawn_list_is_what_the_layer_draws
    assert_equal Vocabulary::DRAWN.sort, Generator.drawn_keys
  end

  def test_a_set_without_vocabulary_writes_no_variable_of_the_vocabulary
    css = Generator.new(set({})).css

    (Generator::VOCABULARY_COLORS.keys - Generator::PRIMER_COLORS.keys - Generator::OPENPROJECT_COLORS.keys).each do |variable|
      refute_includes css, "#{variable}:", variable
    end
  end

  def test_the_bundled_catalogue_looks_as_before
    OpenProject::Thematiq::Catalogue.bundled.sets.each do |token_set|
      bare = TokenSet.new(id: token_set.id, name: token_set.name, tokens: token_set.tokens, dark: token_set.dark_tokens)

      assert_equal Generator.new(bare).css, Generator.new(token_set).css, token_set.id
    end
  end

  def test_status_colours_reach_primers_scales
    body = light({ "color-error" => "#cc0000", "color-warning" => "#7a4f00", "color-success" => "#1e6b2a",
                   "component-status-badge-error-background-color" => "#fcedec", "component-status-badge-info-background-color" => "#eaf0f7" })

    assert_includes body, "--fgColor-danger: #cc0000;"
    assert_includes body, "--bgColor-danger-emphasis: #cc0000;"
    assert_includes body, "--borderColor-danger-emphasis: #cc0000;"
    assert_includes body, "--bgColor-danger-muted: #fcedec;"
    assert_includes body, "--fgColor-attention: #7a4f00;"
    assert_includes body, "--bgColor-success-emphasis: #1e6b2a;"
    assert_includes body, "--bgColor-accent-muted: #eaf0f7;"
    refute_includes body, "--bgColor-attention-muted:", "a key the set leaves out writes nothing"
  end

  def test_the_badge_text_colour_wins_for_the_text_variable
    body = light({ "color-error" => "#cc0000", "component-status-badge-error-color" => "#a30000" })

    assert_includes body, "--fgColor-danger: #a30000;"
    assert_includes body, "--bgColor-danger-emphasis: #cc0000;"
    assert_equal 1, body.scan("--fgColor-danger:").size
  end

  def test_the_info_colour_is_carried_not_drawn
    refute Vocabulary.drawn?("color-info")
    refute_includes Generator.new(set({ "color-info" => "#123456" })).css, "#123456"
  end

  def test_the_dark_theme_keeps_openprojects_own_status_colours
    css = Generator.new(set({ "color-error" => "#cc0000" })).css
    dark = blocks(css).fetch(Generator::DARK_SCOPE)

    refute_includes dark, "#cc0000"
  end

  def test_text_lines_and_corners
    css = Generator.new(set({ "color-text-light" => "#ffffff", "component-separator-border-color" => "#e4e6ea",
                              "border-radius-small" => "4px", "border-radius-pill" => "100px" }, { "radius-lg" => "12px" })).css
    mode = blocks(css).fetch("[data-color-mode]")

    assert_includes blocks(css).fetch(LIGHT), "--fgColor-onEmphasis: #ffffff;"
    assert_includes blocks(css).fetch(LIGHT), "--borderColor-muted: #e4e6ea;"
    assert_includes mode, "--borderRadius-small: 4px;"
    assert_includes mode, "--borderRadius-full: 100px;"
    assert_includes mode, "--borderRadius-medium: 12px;", "the role still writes its own corner"
  end

  def test_the_focus_ring_is_opaque
    assert_includes light({ "color-focus-rgb" => "54, 105, 165", "color-focus" => "rgba(54, 105, 165, 0.5)" }),
                    "--focus-outlineColor: rgb(54, 105, 165);"
    assert_includes light({ "color-focus" => "#3669a5" }, { "primary" => "#111111" }), "--focus-outlineColor: #3669a5;"
    see_through = light({ "color-focus" => "rgba(54, 105, 165, 0.5)" }, { "primary" => "#111111" })

    assert_includes see_through, "--focus-outlineColor: #111111;", "a see-through focus colour leaves the role's ring"
    assert_equal 1, see_through.scan("--focus-outlineColor:").size
  end

  def test_a_hostile_value_never_reaches_the_layer
    HOSTILE_VALUES.each do |value|
      css = Generator.new(set({ "color-error" => value })).css

      refute_includes css, "--fgColor-danger:", value.inspect
    end
  end
end
