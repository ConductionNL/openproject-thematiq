# frozen_string_literal: true

require "test_helper"
require "open_project/thematiq/preview"

class PreviewTest < Minitest::Test
  TokenSet = OpenProject::Thematiq::Tokens::TokenSet
  Preview = OpenProject::Thematiq::Preview

  # One style attribute: "property: value" pairs, nothing that could leave the attribute or load anything.
  SAFE_STYLE = /\A(?:[a-z-]+: [#A-Za-z0-9 .,%()'\/_-]+(?:; |\z))+\z/

  def set(tokens)
    TokenSet.from_set({ "id" => "t", "name" => "T", "tokens" => tokens })
  end

  def all_styles(token_set)
    preview = Preview.new(token_set)
    preview.thumbnail.values + [preview.shell_variables] + Preview::NEUTRAL.keys.map { |key| preview.swatch(key) }
  end

  def assert_safe(styles, label)
    styles.each do |style|
      assert_match SAFE_STYLE, style, label
      refute_match(/url|expression|javascript|import|display|position|["<>{}\\@]/i, style, label)
    end
  end

  def test_the_thumbnail_uses_the_tokens
    thumbnail = Preview.new(set("primary" => "#aa0055", "action" => "#00aa55", "radius" => "9px")).thumbnail

    assert_equal "background: #aa0055", thumbnail[:top_bar]
    assert_includes thumbnail[:button], "background: #00aa55"
    assert_includes thumbnail[:button], "border-radius: 9px"
  end

  def test_the_shell_uses_the_tokens
    shell = Preview.new(set("primary" => "#aa0055", "font-family" => "'Fira Sans', sans-serif", "ink" => "#111111")).shell_variables

    assert_includes shell, "--tqp-primary: #aa0055"
    assert_includes shell, "--tqp-font-family: 'Fira Sans', sans-serif"
    assert_includes shell, "--tqp-ink: #111111"
    assert_includes shell, "--tqp-on-primary: #ffffff"
  end

  def test_the_shell_has_a_property_for_every_token_and_every_worked_out_colour
    shell = Preview.new(TokenSet.fallback).shell_variables

    TokenSet::ALL_KINDS.each_key { |key| assert_includes shell, "--tqp-#{key}: " }
    %w[on-primary on-action on-menu on-selected].each { |name| assert_includes shell, "--tqp-#{name}: " }
  end

  def test_the_text_on_a_dark_menu_is_readable
    preview = Preview.new(set("menu" => "#101010", "ink" => "#111111"))

    assert_equal "#ffffff", preview.derived["on-menu"]
    assert_equal "#111111", Preview.new(set("ink" => "#111111")).derived["on-menu"]
  end

  def test_a_set_without_a_token_gets_a_neutral_value
    preview = Preview.new(TokenSet.fallback)

    assert_safe all_styles(TokenSet.fallback), "fallback"
    assert_equal "background: #{OpenProject::Thematiq::Tokens::Defaults::TOKENS['primary']}", preview.thumbnail[:top_bar]
  end

  def test_every_style_of_every_bundled_set_is_safe
    OpenProject::Thematiq::Catalogue.bundled.sets.each { |token_set| assert_safe all_styles(token_set), token_set.id }
  end

  def test_hostile_values_never_reach_a_style
    TokenSet::KINDS.each_key do |key|
      HOSTILE_VALUES.each do |value|
        assert_safe all_styles(set(key => value)), "#{key} = #{value.inspect}"
      end
    end
  end

  def test_all_tokens_hostile_at_once
    hostile = TokenSet::KINDS.keys.to_h { |key| [key, 'red" onmouseover="alert(1); } body { display:none'] }

    assert_equal all_styles(TokenSet.fallback), all_styles(set(hostile))
  end

  def test_a_swatch_for_an_optional_role_the_set_does_not_have_is_white
    cunningham = OpenProject::Thematiq::Catalogue.bundled.default

    assert_nil cunningham["menu"]
    OpenProject::Thematiq::Tokens::TokenSet::ALL_KINDS.each_key { |key| assert_match(/\Abackground: /, Preview.new(cunningham).swatch(key)) }
    assert_includes Preview.new(cunningham).swatch("menu"), "background: linear-gradient(#ffffff, #ffffff)"
  end

  # The colour lies over a checkerboard, so a colour with transparency shows as such.
  def test_swatch
    assert_equal "background: linear-gradient(#aa0055, #aa0055), #{Preview::CHECKERBOARD}; " \
                 "border: 1px solid #{OpenProject::Thematiq::Tokens::Defaults::TOKENS['field']}",
                 Preview.new(set("primary" => "#aa0055")).swatch("primary")
  end

  def test_a_dark_swatch_shows_the_dark_value_or_the_bare_checkerboard
    night = OpenProject::Thematiq::Tokens::TokenSet.from_set({ "id" => "n", "name" => "N", "tokens" => {},
                                                               "dark" => { "tokens" => { "primary" => "#8fb8e6" } } })

    assert_includes Preview.new(night).dark_swatch("primary"), "linear-gradient(#8fb8e6, #8fb8e6)"
    assert_match(/\Abackground: #{Regexp.escape(Preview::CHECKERBOARD)};/, Preview.new(night).dark_swatch("link"))
  end

  def test_the_variable_map_is_what_the_style_attribute_holds
    preview = Preview.new(set("primary" => "#aa0055"))

    assert_equal preview.shell_variables, preview.shell_variable_map.map { |name, value| "#{name}: #{value}" }.join("; ")
    assert(preview.shell_variable_map.keys.all? { |name| name.start_with?(Preview::PREFIX) })
  end
end
