# frozen_string_literal: true

require "test_helper"

class GeneratorTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Generator = OpenProject::Thematiq::Variables::Generator

  FULL = {
    "primary" => "#3669a5", "primary-deep" => "#234a78", "primary-light" => "#eaf0f7", "action" => "#3669a5",
    "action-deep" => "#234a78", "link" => "#3669a5", "accent" => "#cc0000", "ink" => "#1b1c1d", "text" => "#3d4047",
    "muted" => "#5e6168", "line" => "#e4e6ea", "soft" => "#f5f6f8", "ground" => "#f5f6f8", "chip" => "#f0f1f3",
    "field" => "#c4c7cb", "radius" => "8px", "radius-lg" => "10px", "font-family" => "'Fira Sans', system-ui, sans-serif"
  }.freeze

  def set(tokens)
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => tokens })
  end

  def blocks(css)
    css.scan(/^([^\n{}\/]+) \{\n(.*?)\n\}/m).to_h { |selector, body| [selector, body] }
  end

  def test_writes_three_blocks
    css = Generator.new(set(FULL)).css

    assert_equal [":root", "[data-color-mode]", Generator::LIGHT_SCOPE], blocks(css).keys
  end

  def test_maps_tokens_to_openproject_and_primer_variables_in_the_light_theme_only
    all = blocks(Generator.new(set(FULL)).css)
    light = all[Generator::LIGHT_SCOPE]

    assert_includes light, "  --header-bg-color: #3669a5;"
    assert_includes light, "  --primary-button-color: #3669a5;"
    assert_includes light, "  --button--primary-border-color: #234a78;"
    assert_includes light, "  --main-menu-bg-selected-background: #eaf0f7;"
    assert_includes light, "  --fgColor-default: #1b1c1d;"
    assert_includes light, "  --control-borderColor-rest: #c4c7cb;"
    assert_includes light, "  --thematiq-accent: #cc0000;"
    assert_includes light, "  --thematiq-chip: #f0f1f3;"

    refute_match(/#3669a5|#1b1c1d/, all[":root"])
    refute_match(/#3669a5|#1b1c1d/, all["[data-color-mode]"])
  end

  def test_radius_and_font_apply_in_every_mode
    all = blocks(Generator.new(set(FULL)).css)

    assert_includes all[":root"], "  --thematiq-radius: 8px;"
    assert_includes all[":root"], "  --body-font-family: 'Fira Sans', system-ui, sans-serif;"
    assert_includes all["[data-color-mode]"], "  --borderRadius-medium: 10px;"
  end

  def test_other_modes_get_the_aliases_from_primer
    other = blocks(Generator.new(set(FULL)).css)["[data-color-mode]"]

    assert_includes other, "  --thematiq-ink: var(--fgColor-default);"
    assert_includes other, "  --thematiq-surface: var(--bgColor-default);"
    Generator::COLOR_ALIASES.each_key { |name| assert_includes other, "  #{name}: var(" }
  end

  def test_a_missing_token_leaves_its_variables_out
    css = Generator.new(TokenSet.fallback).css
    light = blocks(css)[Generator::LIGHT_SCOPE]

    refute_includes light, "--thematiq-accent"
    refute_includes light, "--thematiq-chip"
    assert_includes light, "  --header-bg-color: #1a67a3;"
  end

  def test_the_fallback_set_gives_the_values_the_spike_had
    light = blocks(Generator.new(TokenSet.fallback).css)[Generator::LIGHT_SCOPE]
    spike = File.read(File.expand_path("../../spike/theme.css", __dir__))
    spike_values = spike.scan(/^  (--[\w-]+): ([^;]+);$/).to_h

    Generator::OPENPROJECT_COLORS.merge(Generator::PRIMER_COLORS).each_key do |variable|
      assert_includes light, "  #{variable}: #{spike_values.fetch(variable)};"
    end
  end

  def test_hostile_values_never_reach_the_css
    TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        css = Generator.new(set(FULL.merge(key => value))).css

        assert_safe css, "#{key} = #{value.inspect}"
      end
    end
  end

  def test_all_tokens_hostile_at_once
    hostile = TokenSet::KINDS.keys.to_h { |key| [key, "red; } body { display:none"] }
    css = Generator.new(set(hostile)).css

    assert_safe css, "all hostile"
    assert_equal Generator.new(TokenSet.fallback).css, css
  end

  # Structural check: exactly three rules, every line inside a rule is one "--name: value;" declaration.
  def assert_safe(css, label)
    refute_match(/[<>\\@]|\/\*.*\*\/.*\/\*|url\(|expression|javascript|display|!important/i, css, label)
    assert_equal 3, css.count("{"), label
    assert_equal 3, css.count("}"), label
    blocks(css).each_value do |body|
      body.each_line(chomp: true) do |line|
        assert_match(/\A  --[A-Za-z][A-Za-z0-9-]*: [^;{}]+;\z/, line, label)
      end
    end
  end
end
