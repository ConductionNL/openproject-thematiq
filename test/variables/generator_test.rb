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
    partial = TokenSet.new(id: "t", name: "T", tokens: { "primary" => "#1a67a3" }, base: {})
    light = blocks(Generator.new(partial).css)[Generator::LIGHT_SCOPE]

    refute_includes light, "--thematiq-accent"
    refute_includes light, "--thematiq-chip"
    refute_includes light, "--primary-button-color"
    assert_includes light, "  --header-bg-color: #1a67a3;"
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

  # --- the optional menu colour ---

  def test_a_set_without_a_menu_colour_generates_what_it_did_before_the_role_existed
    css = Generator.new(set(FULL)).css

    assert_includes css, "  --main-menu-bg-color: #ffffff;"
    assert_includes css, "  --header-item-font-color: #ffffff;"
    assert_includes css, "  --main-menu-selected-font-color: #234a78;"
    refute_includes css, "#main-menu"
    assert_equal 3, css.count("{")
  end

  def test_a_dark_menu_gets_light_text_and_its_own_block
    css = Generator.new(set(FULL.merge("menu" => "#0e2045", "primary-light" => "#3270db", "primary-deep" => "#0e2045"))).css
    light = blocks(css)[Generator::LIGHT_SCOPE]
    menu = css[/#{Regexp.escape(Generator::LIGHT_SCOPE)} #main-menu \{\n(.*?)\n\}/m, 1]

    assert_operator light.rindex("--main-menu-bg-color: #0e2045;"), :>, light.index("--main-menu-bg-color: #ffffff;"), "the later declaration decides"
    assert_includes light, "  --thematiq-on-menu: #ffffff;"
    assert_includes menu, "  --thematiq-ink: #ffffff;"
    assert_includes menu, "  --thematiq-surface: #0e2045;"
    assert_includes menu, "  --thematiq-primary-deep: #ffffff;", "the selected item's text is white on the blue item"
  end

  def test_a_light_header_gets_dark_text
    light = blocks(Generator.new(set(FULL.merge("primary" => "#fafafa"))).css)[Generator::LIGHT_SCOPE]

    assert_includes light, "  --header-item-font-color: #1b1c1d;"
    assert_includes light, "  --thematiq-on-primary: #1b1c1d;"
  end

  def test_a_hostile_menu_colour_is_dropped
    HOSTILE_VALUES.each do |value|
      token_set = set(FULL.merge("menu" => value))

      assert_nil token_set["menu"]
      assert_safe Generator.new(token_set).css, value.inspect
    end
  end

  # --- the early variant, for the top of the head ---

  def test_the_early_variant_puts_everything_that_depends_on_order_on_the_body
    all = blocks(Generator.new(set(FULL), early: true).css)

    assert_equal [":root", "body[data-color-mode]", Generator::LIGHT_SCOPE], all.keys
    refute_includes all[":root"], "--body-font-family", "OpenProject sets this on :root later in the page, so :root would lose"
    assert_includes all[":root"], "  --thematiq-radius: 8px;"
    assert_includes all["body[data-color-mode]"], "  --body-font-family: 'Fira Sans', system-ui, sans-serif;"
    assert_includes all["body[data-color-mode]"], "  --borderRadius-medium: 10px;"
  end

  def test_the_early_and_the_late_variant_declare_the_same_variables
    names = ->(css) { css.scan(/^  (--[\w-]+):/).flatten.sort }

    assert_equal names.call(Generator.new(set(FULL)).css), names.call(Generator.new(set(FULL), early: true).css)
    assert_safe Generator.new(set(FULL), early: true).css, "early"
  end

  # --- the optional dark block ---

  def dark_set(dark)
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => FULL, "dark" => dark })
  end

  def test_without_a_dark_block_the_dark_theme_gets_nothing
    css = Generator.new(set(FULL)).css

    refute_includes css, Generator::DARK_SCOPE
    refute set(FULL).dark?
  end

  def test_a_dark_block_writes_its_colours_to_the_dark_theme_only
    css = Generator.new(dark_set("primary" => "#0b1f33", "ink" => "#f0f6fc", "action" => "#2ea043")).css
    dark = css[/#{Regexp.escape(Generator::DARK_SCOPE)} \{\n(.*?)\n\}/m, 1]

    assert_includes dark, "  --header-bg-color: #0b1f33;"
    assert_includes dark, "  --fgColor-default: #f0f6fc;"
    assert_includes dark, "  --primary-button-color: #2ea043;"
    assert_includes dark, "  --thematiq-ink: #f0f6fc;"
    refute_includes dark, "--button--background-color", "white surfaces of the light theme do not leak into the dark theme"
    refute_includes dark, "--thematiq-surface"
    assert_includes dark, "  --header-item-font-color: #ffffff;", "the text on the top bar follows the contrast rule"
    assert_includes dark, "  --button--primary-font-color: #1b1c1d;", "white does not read on this green, so the text goes dark"
    refute_includes dark, "--main-menu-bg-color", "what the dark block does not name stays OpenProject's"
    refute_includes blocks(css)[Generator::LIGHT_SCOPE], "#0b1f33"
  end

  def test_hostile_dark_values_are_dropped_and_listed
    token_set = dark_set("primary" => "red; } body { display:none", "ink" => "#f0f6fc", "radius" => "9px", "junk" => "#fff")
    css = Generator.new(token_set).css

    assert_equal({ "ink" => "#f0f6fc" }, token_set.dark_tokens)
    assert_equal %w[dark.primary], token_set.rejected
    refute_match(/display|[<>\\@]|url\(/, css)
    assert_equal 4, css.count("{")
    assert_equal 4, css.count("}")
  end

  def test_every_hostile_value_in_every_dark_role
    TokenSet::DARK_KEYS.each do |key|
      HOSTILE_VALUES.each do |value|
        token_set = dark_set(key => value)

        assert_nil token_set.dark_tokens[key], "dark #{key} took #{value.inspect}"
        refute_match(/display|[<>\\@]|url\(|expression/i, Generator.new(token_set).css)
      end
    end
  end

  def test_a_dark_block_that_is_not_an_object_refuses_the_set
    ["x", [], 7].each { |dark| assert_raises(TokenSet::InvalidSet) { dark_set(dark) } }
  end

  def test_the_dark_block_survives_the_set_shape_and_strict_mode
    token_set = dark_set("primary" => "#0b1f33")
    copy = TokenSet.from_set(token_set.to_set, strict: true)

    assert_equal({ "primary" => "#0b1f33" }, copy.dark_tokens)
    assert_equal "unknown_keys", assert_raises(TokenSet::InvalidSet) {
      TokenSet.from_set(token_set.to_set.merge("dark" => { "tokens" => { "shadow" => "9px" } }), strict: true)
    }.message
    refute_includes set(FULL).to_set.keys, "dark"
  end

  def test_the_dark_block_reads_in_the_shape_the_catalogue_writes_and_ignores_radius_and_font
    token_set = dark_set("tokens" => { "primary" => "#0b1f33", "radius" => "9px", "font-family" => "Arial" })

    assert_equal({ "primary" => "#0b1f33" }, token_set.dark_tokens)
    assert_empty token_set.rejected
    assert_equal({ "tokens" => { "primary" => "#0b1f33" } }, token_set.to_set["dark"])
    assert_equal "unknown_keys", assert_raises(TokenSet::InvalidSet) {
      TokenSet.from_set(token_set.to_set.merge("dark" => { "tokens" => {}, "script" => "x" }), strict: true)
    }.message
  end

  def test_a_dark_block_whose_text_does_not_read_on_its_ground_is_not_used
    unreadable = dark_set("ink" => "#222222", "ground" => "#292b2f", "primary" => "#0b1f33")

    assert unreadable.dark?
    refute OpenProject::Thematiq::Contrast.dark_usable?(unreadable)
    refute_includes Generator.new(unreadable).css, Generator::DARK_SCOPE
  end

  def test_the_selected_item_in_the_dark_theme_gets_text_that_reads
    css = Generator.new(dark_set("primary-light" => "#0c1c32", "primary-deep" => "#203c63", "ink" => "#e2e3e4", "ground" => "#292b2f")).css
    dark = css[/#{Regexp.escape(Generator::DARK_SCOPE)} \{\n(.*?)\n\}/m, 1]

    assert_operator dark.rindex("--thematiq-primary-deep: #ffffff;"), :>, dark.index("--thematiq-primary-deep: #203c63;"), "the rule comes last, so it decides"
    assert_includes dark, "  --main-menu-selected-font-color: #ffffff;"
  end

  def test_a_custom_set_keeps_the_dark_block_of_its_base
    draft = OpenProject::Thematiq::CustomDraft.new(base: dark_set("primary" => "#0b1f33"), name: "Mine", overrides: {})

    assert_equal({ "primary" => "#0b1f33" }, draft.token_set.dark_tokens)
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
