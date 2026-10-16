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

  # First full test, findings 16 and 17: white on the search field (white at 12% over Zuiddrecht's #3669a5,
  # #4e7bb0) was 4.38 to 1, and the name under the current tile (16%, #5681b3) 4.04 to 1.
  def test_the_bar_tints_keep_the_text_readable
    light = blocks(Generator.new(set(FULL)).css)['body[data-color-mode="light"][data-light-theme="light"]']
    field = light[/--thematiq-bar-field: (#\h{6});/, 1]
    current = light[/--thematiq-bar-current: (#\h{6});/, 1]

    assert_operator OpenProject::Thematiq::Contrast.ratio("#ffffff", field), :>, 4.5
    assert_operator OpenProject::Thematiq::Contrast.ratio("#ffffff", current), :>, 4.5
    refute_equal "#3669a5", field, "still a layer, only a lighter one"
  end

  def test_other_modes_keep_the_canons_layer_on_the_bar
    css = Generator.new(set(FULL)).css

    assert_includes blocks(css)["[data-color-mode]"], "--thematiq-bar-field: rgba(255, 255, 255, .12);"
    assert_includes blocks(css)["[data-color-mode]"], "--thematiq-bar-current: color-mix(in srgb, var(--thematiq-on-primary) 16%, transparent);"
  end

  def test_every_bundled_set_keeps_its_bar_text_readable_in_light_and_dark
    OpenProject::Thematiq::Catalogue.bundled.sets.each do |token_set|
      blocks(Generator.new(token_set).css).each do |selector, body|
        next unless selector.include?("-theme=")

        bar = body[/--header-bg-color: (#\h{6});/, 1]
        text = body[/--header-item-font-color: (#\h{6});/, 1]
        next unless bar && text

        %w[field current].each do |part|
          tint = body[/--thematiq-bar-#{part}: (#\h{6});/, 1]
          ratio = OpenProject::Thematiq::Contrast.ratio(text, tint)
          # A bar that is itself under the minimum gets no layer at all, and is known to the contrast report.
          next if tint == bar

          assert_operator ratio, :>, 4.5, "#{token_set.id}, #{selector}: #{part} #{tint}"
        end
      end
    end
  end

  def test_tint_takes_the_strongest_layer_that_reads
    assert_equal "#3669a5", OpenProject::Thematiq::Contrast.tint("#3669a5", "#ffffff", 0)
    # A dark bar can take the whole layer: 10% of white over #151515.
    assert_equal "#2c2c2c", OpenProject::Thematiq::Contrast.tint("#151515", "#ffffff", 0.1)
    # Zuiddrecht: the canon's 12% gives #4e7bb0, 4.38 to 1. The layer stops where white still reads.
    field = OpenProject::Thematiq::Contrast.tint("#3669a5", "#ffffff", 0.12)
    assert_operator OpenProject::Thematiq::Contrast.ratio("#ffffff", field), :>, 4.5
    refute_equal "#4e7bb0", field
    assert_nil OpenProject::Thematiq::Contrast.tint("red", "#ffffff", 0.12)
  end

  # The shell's top bar is the dossiq bar: thematiq's header colours where the set has them, so Zuiddrecht's bar is
  # white with ink, its fill the ground and its lines the line colour.
  def test_the_bar_takes_the_header_colours_of_the_vocabulary
    token_set = TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => FULL,
                                    "vocabulary" => { "color-header-background" => "#ffffff", "color-header-text" => "#1b1c1d" } })
    light = blocks(Generator.new(token_set).css)[Generator::LIGHT_SCOPE]

    assert_includes light, "  --thematiq-bar: #ffffff;"
    assert_includes light, "  --thematiq-on-bar: #1b1c1d;"
    assert_includes light, "  --thematiq-bar-fill: #f5f6f8;"
    assert_includes light, "  --thematiq-bar-line: #e4e6ea;"
    assert_includes light, "  --thematiq-bar-edge: #e4e6ea;"
    assert_includes light, "  --thematiq-bar-muted: #5e6168;"
    assert_includes light, "  --header-bg-color: #3669a5;", "core's variable keeps the primary"
  end

  def test_without_header_colours_the_bar_is_the_primary_with_a_layer_of_its_text
    light = blocks(Generator.new(set(FULL)).css)[Generator::LIGHT_SCOPE]

    assert_includes light, "  --thematiq-bar: #3669a5;"
    assert_includes light, "  --thematiq-on-bar: #ffffff;"
    fill = light[/--thematiq-bar-fill: (#\h{6});/, 1]
    assert_operator OpenProject::Thematiq::Contrast.ratio("#ffffff", fill), :>, 4.5
    assert_includes light, "  --thematiq-bar-edge: #3669a5;"
    assert_includes light, "  --thematiq-bar-muted: #ffffff;", "muted grey does not read on the blue bar"
  end

  def test_a_header_text_that_does_not_read_is_replaced
    token_set = TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => FULL,
                                    "vocabulary" => { "color-header-background" => "#ffffff", "color-header-text" => "#eeeeee" } })
    light = blocks(Generator.new(token_set).css)[Generator::LIGHT_SCOPE]

    assert_includes light, "  --thematiq-on-bar: #1b1c1d;"
  end

  def test_other_modes_take_the_bar_from_cores_header
    assert_includes blocks(Generator.new(set(FULL)).css)["[data-color-mode]"], "--thematiq-bar: var(--header-bg-color);"
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

  # thematiq's dark blocks carry a menu colour (thematiq #1300). The dark theme draws it, with the text by the same rule.
  def test_a_dark_menu_colour_is_drawn_in_the_dark_theme_with_its_own_block
    css = Generator.new(dark_set("primary" => "#0b1f33", "ink" => "#f0f6fc", "ground" => "#0d1117", "menu" => "#141414",
                                 "primary-light" => "#13202e", "primary-deep" => "#84aad7")).css
    dark = css[/#{Regexp.escape(Generator::DARK_SCOPE)} \{\n(.*?)\n\}/m, 1]
    menu = css[/#{Regexp.escape(Generator::DARK_SCOPE)} #main-menu \{\n(.*?)\n\}/m, 1]

    assert_includes dark, "  --main-menu-bg-color: #141414;"
    assert_includes dark, "  --main-menu-font-color: #f0f6fc;", "the dark ink reads on the dark menu"
    assert_includes menu, "  --thematiq-surface: #141414;"
    assert_includes menu, "  --main-menu-selected-font-color: #84aad7;"
    refute_includes blocks(css)[Generator::LIGHT_SCOPE], "#141414"
    refute_includes Generator.new(dark_set("primary" => "#0b1f33", "ink" => "#f0f6fc", "menu" => "#141414"), content: true).css, "#main-menu"
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
